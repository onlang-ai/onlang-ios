#if canImport(UIKit)
import Foundation
import OnlangCore

/// Event upload through a background URLSession (plan §8.2): the system finishes an upload
/// even if the app is suspended or killed, and relaunches the app in the background to report
/// the result (`Onlang.handleEventsForBackgroundURLSession`). One batch is in flight at a time;
/// each batch's body and event ids are files, so a relaunch can still settle it by id.
final class BackgroundUploader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  // Kept as `ai.onlang.upload` (not onlang.io): a new identifier would orphan uploads in flight.
  static let identifier = "ai.onlang.upload"

  private let lock = NSLock()
  private var queue: EventQueue
  private let dir: URL
  private var responses: [Int: Data] = [:]
  private var finishEvents: (() -> Void)?
  private let log: @Sendable (String) -> Void
  private lazy var session: URLSession = {
    let c = URLSessionConfiguration.background(withIdentifier: Self.identifier)
    c.isDiscretionary = false // started from the foreground: send now, not when convenient
    c.sessionSendsLaunchEvents = true
    return URLSession(configuration: c, delegate: self, delegateQueue: nil)
  }()

  init(queue: EventQueue, dir: URL, log: @escaping @Sendable (String) -> Void) {
    self.queue = queue
    self.dir = dir
    self.log = log
    super.init()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }

  private func locked<T>(_ f: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return f()
  }

  /// The app reconfigured Onlang: settle later results against the new queue.
  func use(_ queue: EventQueue) { locked { self.queue = queue } }

  /// Called from the app delegate after a background relaunch; also reattaches the session.
  func handleEvents(completion: @escaping () -> Void) {
    locked { finishEvents = completion }
    _ = session
  }

  /// Starts the next batch unless one is already in flight.
  func upload() {
    session.getAllTasks { [self] tasks in
      guard tasks.allSatisfy({ $0.state == .completed }) else { return }
      guard let batch = locked({ queue }).prepareUpload() else { return }
      let name = UUID().uuidString
      let body = dir.appendingPathComponent("\(name).json")
      do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) // may have been cleared
        try batch.body.write(to: body, options: .atomic)
        try Data(batch.eventIds.joined(separator: "\n").utf8).write(to: dir.appendingPathComponent("\(name).ids"), options: .atomic)
      } catch {
        return log("cannot stage an upload: \(error)")
      }
      var request = URLRequest(url: batch.url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "content-type")
      for (k, v) in locked({ queue }).headers { request.setValue(v, forHTTPHeaderField: k) }
      let task = session.uploadTask(with: request, fromFile: body)
      task.taskDescription = name
      task.resume()
    }
  }

  func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    locked { responses[dataTask.taskIdentifier, default: Data()].append(data) }
  }

  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let response = locked { responses.removeValue(forKey: task.taskIdentifier) } ?? Data()
    guard let name = task.taskDescription else { return }
    let idsFile = dir.appendingPathComponent("\(name).ids")
    let ids = (try? String(contentsOf: idsFile, encoding: .utf8))?.split(separator: "\n").map(String.init) ?? []
    try? FileManager.default.removeItem(at: idsFile)
    try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(name).json"))
    if let error { log("background upload failed: \(error.localizedDescription)") }
    let status = error == nil ? (task.response as? HTTPURLResponse)?.statusCode : nil
    // Sent (or dropped as invalid): go on with the rest. A retryable failure waits for the next flush.
    if locked({ queue }).complete(ids, status: status, response: response) { upload() }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
    let done = locked { () -> (() -> Void)? in
      defer { finishEvents = nil }
      return finishEvents
    }
    if let done { DispatchQueue.main.async(execute: done) }
  }
}
#endif
