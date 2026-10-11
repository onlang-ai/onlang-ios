import Foundation
import OnlangContract

/// Upload consent (plan §8.1: a consent flag gates upload).
public enum Consent: String, Sendable {
  /// Not decided yet: events stay on the device (bounded by retention); nothing is sent.
  case pending
  /// Events are uploaded.
  case granted
  /// Nothing is recorded, and queued events are deleted.
  case denied
}

/// A batch handed to an out-of-process uploader (a background URLSession): the request body
/// and the event ids to settle with `complete(_:status:)` when the response arrives.
public struct PendingUpload: Sendable {
  public let url: URL
  public let body: Data
  public let eventIds: [String]
}

/// Durable event queue: events are appended to a JSON-lines file and sent in batches to
/// `POST /v1/apps/{app}/events`. Ingest is idempotent on event_id, so a batch is retried until
/// it gets a 2xx; on a 4xx (other than 408/429) the batch is dropped. Sent events are removed by
/// event_id, so the foreground flush and a background upload can't remove each other's lines.
///
/// Privacy (plan §8.1): nothing is recorded while consent is `.denied` and nothing is sent
/// unless it is `.granted`. Events older than `retention` are deleted, and the file is capped
/// at `maxEvents` (oldest dropped). Thread-safe.
public final class EventQueue: @unchecked Sendable {
  /// Queued events older than this are deleted (plan §8.1: retention is configurable).
  public static let defaultRetention: TimeInterval = 30 * 24 * 60 * 60

  private let file: URL
  public let endpoint: URL
  private let consent: @Sendable () -> Consent
  private let transport: HTTPTransport
  private let batchSize: Int
  private let maxEvents: Int
  private let retention: TimeInterval
  private let timeout: TimeInterval
  private let clock: @Sendable () -> Int
  private let log: @Sendable (String) -> Void
  /// Sent with every batch: the SDK key (`Authorization`) and `X-Onlang-Install` (ingest throttles by install).
  public let headers: [String: String]
  private let lock = NSLock()
  private var flushing = false

  public init(file: URL, baseUrl: URL, app: String, consent: @escaping @Sendable () -> Consent,
              transport: HTTPTransport = URLSessionTransport(), batchSize: Int = 100, maxEvents: Int = 5000,
              retention: TimeInterval = EventQueue.defaultRetention, timeout: TimeInterval = 10,
              clock: @escaping @Sendable () -> Int = { Int(Date().timeIntervalSince1970 * 1000) },
              headers: [String: String] = [:],
              log: @escaping @Sendable (String) -> Void = { _ in }) {
    self.headers = headers
    self.file = file
    endpoint = baseUrl.appendingPathComponent("v1").appendingPathComponent("apps").appendingPathComponent(app).appendingPathComponent("events")
    self.consent = consent
    self.transport = transport
    self.batchSize = batchSize
    self.maxEvents = maxEvents
    self.retention = retention
    self.timeout = timeout
    self.clock = clock
    self.log = log
    try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
  }

  private func locked<T>(_ f: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try f()
  }

  private func lines() -> [String] {
    guard let data = try? Data(contentsOf: file) else { return [] }
    return String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
  }

  private func write(_ lines: [String]) {
    try? Data(lines.map { $0 + "\n" }.joined().utf8).write(to: file, options: .atomic)
  }

  private func decode(_ line: String) -> Event? { try? JSONDecoder().decode(Event.self, from: Data(line.utf8)) }

  /// Drops expired and unreadable lines and writes the rest back. Call with the lock held.
  private func prune() -> [String] {
    let all = lines()
    let cutoff = clock() - Int(retention * 1000)
    let kept = all.filter { decode($0).map { $0.tsClientMS >= cutoff } ?? false }
    if kept.count != all.count {
      log("dropping \(all.count - kept.count) events past retention")
      write(kept)
    }
    return kept
  }

  public func enqueue(_ event: Event) {
    guard consent() != .denied, let data = try? JSONEncoder().encode(event) else { return }
    locked {
      var all = lines()
      all.append(String(decoding: data, as: UTF8.self))
      if all.count > maxEvents {
        log("event queue over \(maxEvents); dropping \(all.count - maxEvents) oldest")
        all = Array(all.suffix(maxEvents))
      }
      write(all)
    }
  }

  public var count: Int { locked { lines().count } }

  public func peek() -> [Event] { locked { lines().compactMap(decode) } }

  /// Deletes everything queued (consent withdrawn).
  public func clear() { locked { try? FileManager.default.removeItem(at: file) } }

  /// The next batch for an out-of-process upload, or nil when there is nothing to send or no consent.
  public func prepareUpload(excluding inFlight: Set<String> = []) -> PendingUpload? {
    locked {
      let kept = prune()
      guard consent() == .granted else { return nil }
      let batch = Array(kept.filter { line in decode(line).map { !inFlight.contains($0.eventID) } ?? false }.prefix(batchSize))
      guard !batch.isEmpty else { return nil }
      return PendingUpload(url: endpoint, body: Data("{\"events\":[\(batch.joined(separator: ","))]}".utf8),
                           eventIds: batch.compactMap { decode($0)?.eventID })
    }
  }

  /// Settles an uploaded batch: removes its events on 2xx and on non-retryable 4xx, keeps them
  /// for retry otherwise (`status` nil = transport error). Returns whether they left the queue.
  @discardableResult
  public func complete(_ eventIds: [String], status: Int?, response: Data = Data()) -> Bool {
    guard let status else {
      log("event upload failed; will retry")
      return false
    }
    switch status {
    case 200 ..< 300:
      if let r = try? JSONValue.parse(response), let rejected = r["rejected"]?.arrayValue {
        for x in rejected { log("ingest rejected event \(x["index"]?.doubleValue.map { Int($0) } ?? -1): \(x["error"]?.stringValue ?? "")") }
      }
    case 408, 429, 500...:
      log("event upload got \(status); will retry")
      return false
    default:
      log("event upload got \(status); dropping \(eventIds.count) events: \(String(decoding: response, as: UTF8.self))")
    }
    let sent = Set(eventIds)
    locked { write(lines().filter { decode($0).map { !sent.contains($0.eventID) } ?? false }) }
    return true
  }

  /// Sends everything queued if consent is granted. Returns how many events left the queue (sent or dropped).
  @discardableResult
  public func flush() async -> Int {
    let started: Bool = locked {
      if flushing { return false }
      flushing = true
      return true
    }
    guard started else { return 0 }
    defer { locked { flushing = false } }

    var removed = 0
    while let upload = prepareUpload() {
      var status: Int?
      var response = Data()
      do {
        (status, response) = try await transport.request(method: "POST", url: upload.url, body: upload.body, headers: headers, timeout: timeout)
      } catch {
        log("event upload failed (\(error)); will retry")
      }
      guard complete(upload.eventIds, status: status, response: response) else { return removed }
      removed += upload.eventIds.count
    }
    return removed
  }
}
