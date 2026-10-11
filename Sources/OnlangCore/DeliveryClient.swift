import Foundation
import OnlangContract

/// Minimal HTTP port, so tests (and apps with their own networking) can replace URLSession.
public protocol HTTPTransport: Sendable {
  func request(method: String, url: URL, body: Data?, headers: [String: String], timeout: TimeInterval) async throws -> (status: Int, body: Data)
}

public extension HTTPTransport {
  func request(method: String, url: URL, body: Data?, timeout: TimeInterval) async throws -> (status: Int, body: Data) {
    try await request(method: method, url: url, body: body, headers: [:], timeout: timeout)
  }
}

public struct URLSessionTransport: HTTPTransport {
  public let session: URLSession
  public init(session: URLSession = .shared) { self.session = session }

  public func request(method: String, url: URL, body: Data?, headers: [String: String], timeout: TimeInterval) async throws -> (status: Int, body: Data) {
    var req = URLRequest(url: url, timeoutInterval: timeout)
    req.httpMethod = method
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
    if let body {
      req.httpBody = body
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await session.data(for: req)
    return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
  }
}

public struct LoadedFlow: Sendable {
  public enum Source: String, Sendable { case network, cache, fallback }

  public let placement: String
  public let locale: String
  public let releaseId: String?
  public let assignment: [String: String]
  public let screens: [LoadedBundle]
  public let source: Source

  public init(placement: String, locale: String, releaseId: String?, assignment: [String: String], screens: [LoadedBundle], source: Source) {
    self.placement = placement
    self.locale = locale
    self.releaseId = releaseId
    self.assignment = assignment
    self.screens = screens
    self.source = source
  }
}

public struct DeliveryError: Error, CustomStringConvertible {
  public let description: String
  public init(_ description: String) { self.description = description }
}

/// Delivery answered 410: a kill switch is on for this placement (ADR-0012). The app shows its
/// own screen; the SDK shows no Onlang flow for the placement, cached or bundled, until a later
/// request gets one.
public struct FlowKilled: Error, CustomStringConvertible {
  public let placement: String
  public let reason: String
  public var description: String { "Onlang is switched off for \(placement): \(reason)" }
}

/// Bundled fallback flows: (placement, locale) → bundles, or nil.
public typealias FallbackProvider = @Sendable (_ placement: String, _ locale: String) -> [JSONValue]?

/// Delivery API v1 client (docs/api/delivery-v1.md): flow → bundles, each verified against
/// its content address and cached. Falls back to the last good flow (only if every bundle is
/// still cached and intact), then to the app's bundled fallback. A 410 (kill switch) skips both
/// fallbacks and is remembered on disk until the next flow arrives, so a killed placement stays
/// off while the device is offline.
public final class DeliveryClient: @unchecked Sendable {
  private let baseUrl: URL
  private let app: String
  private let installId: String
  private let bundlesDir: URL
  private let flowsDir: URL
  private let fallback: FallbackProvider
  private let transport: HTTPTransport
  private let timeout: TimeInterval
  private let headers: [String: String]

  /// `sdkKey`: the app's publishable token (onl_pk_…), sent as `Authorization: Bearer`.
  public init(baseUrl: URL, app: String, installId: String, cacheDir: URL, fallback: @escaping FallbackProvider = { _, _ in nil },
              transport: HTTPTransport = URLSessionTransport(), timeout: TimeInterval = 1.5, sdkKey: String? = nil) {
    headers = sdkKey.map { ["Authorization": "Bearer \($0)"] } ?? [:]
    self.baseUrl = baseUrl
    self.app = app
    self.installId = installId
    bundlesDir = cacheDir.appendingPathComponent("bundles", isDirectory: true)
    flowsDir = cacheDir.appendingPathComponent("flows", isDirectory: true)
    self.fallback = fallback
    self.transport = transport
    self.timeout = timeout
    for d in [bundlesDir, flowsDir] { try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
  }

  public func load(placement: String, locale: String, assign: [String: String]? = nil) async throws -> LoadedFlow {
    let networkError: Error
    do {
      return try await fromNetwork(placement, locale, assign)
    } catch let killed as FlowKilled {
      throw killed
    } catch {
      networkError = error
    }
    if let reason = try? String(contentsOf: killFile(placement), encoding: .utf8) { throw FlowKilled(placement: placement, reason: reason) }
    if let cached = fromCache(placement, locale) { return cached }
    if let raw = fallback(placement, locale) {
      let screens = try raw.map { try LoadedBundle($0) }
      return LoadedFlow(placement: placement, locale: locale, releaseId: nil, assignment: screens.first?.header.assignment ?? [:],
                        screens: screens, source: .fallback)
    }
    throw DeliveryError("no flow for \(placement)/\(locale): \(networkError)")
  }

  private func url(_ path: [String], query: [URLQueryItem] = []) -> URL {
    var c = URLComponents(url: path.reduce(baseUrl) { $0.appendingPathComponent($1) }, resolvingAgainstBaseURL: false)!
    if !query.isEmpty { c.queryItems = query }
    return c.url!
  }

  private func fromNetwork(_ placement: String, _ locale: String, _ assign: [String: String]?) async throws -> LoadedFlow {
    var query = [URLQueryItem(name: "locale", value: locale), URLQueryItem(name: "install_id", value: installId)]
    if let assign {
      let data = try JSONSerialization.data(withJSONObject: assign, options: [.sortedKeys])
      query.append(URLQueryItem(name: "assign", value: String(decoding: data, as: UTF8.self)))
    }
    let (status, body) = try await transport.request(method: "GET", url: url(["v1", "apps", app, "placements", placement], query: query),
                                                     body: nil, headers: headers, timeout: timeout)
    if status == 410 {
      let reason = (try? JSONValue.parse(body))?["reason"]?.stringValue ?? "kill switch"
      try? Data(reason.utf8).write(to: killFile(placement), options: .atomic)
      throw FlowKilled(placement: placement, reason: reason)
    }
    guard status == 200 else { throw DeliveryError("flow request failed: \(status) \(String(decoding: body, as: UTF8.self))") }
    try? FileManager.default.removeItem(at: killFile(placement))
    let flow = try JSONDecoder().decode(FlowResponse.self, from: body)
    var screens: [LoadedBundle] = []
    for s in flow.manifest.screens { screens.append(try await bundle(s.bundleID)) }
    try body.write(to: flowFile(placement, locale), options: .atomic)
    return LoadedFlow(placement: placement, locale: locale, releaseId: flow.releaseID, assignment: flow.assignment, screens: screens, source: .network)
  }

  private func bundleFile(_ id: String) -> URL { bundlesDir.appendingPathComponent(id.replacingOccurrences(of: ":", with: "_") + ".json") }
  private func flowFile(_ placement: String, _ locale: String) -> URL { flowsDir.appendingPathComponent("\(placement)__\(locale).json") }
  private func killFile(_ placement: String) -> URL { flowsDir.appendingPathComponent("\(placement).killed") }

  private func bundle(_ id: String) async throws -> LoadedBundle {
    let file = bundleFile(id)
    if let data = try? Data(contentsOf: file) {
      if let cached = try? LoadedBundle(data: data), cached.verify(), cached.header.bundleID == id { return cached }
      try? FileManager.default.removeItem(at: file)
    }
    let (status, body) = try await transport.request(method: "GET", url: url(["v1", "bundles", id]), body: nil, headers: headers, timeout: timeout)
    guard status == 200 else { throw DeliveryError("bundle \(id): \(status)") }
    let b = try LoadedBundle(data: body)
    guard b.header.bundleID == id, b.verify() else { throw DeliveryError("bundle \(id) failed its integrity check") }
    try body.write(to: file, options: .atomic)
    return b
  }

  private func fromCache(_ placement: String, _ locale: String) -> LoadedFlow? {
    guard let data = try? Data(contentsOf: flowFile(placement, locale)),
          let flow = try? JSONDecoder().decode(FlowResponse.self, from: data) else { return nil }
    var screens: [LoadedBundle] = []
    for s in flow.manifest.screens {
      guard let d = try? Data(contentsOf: bundleFile(s.bundleID)), let b = try? LoadedBundle(data: d),
            b.verify(), b.header.bundleID == s.bundleID else { return nil }
      screens.append(b)
    }
    return LoadedFlow(placement: placement, locale: locale, releaseId: flow.releaseID, assignment: flow.assignment, screens: screens, source: .cache)
  }
}
