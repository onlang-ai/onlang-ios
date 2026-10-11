import Foundation
import OnlangContract

/// Identity of one screen view; every event carries it.
public struct SessionContext: Equatable, Sendable {
  public var sessionId: String
  public var installId: String
  public var app: String
  public var registryHash: String
  public var bundleId: String
  public var assignment: [String: String]
  public var screen: String
  public var ctaNode: String?

  public init(sessionId: String, installId: String, app: String, registryHash: String, bundleId: String,
              assignment: [String: String], screen: String, ctaNode: String?) {
    self.sessionId = sessionId
    self.installId = installId
    self.app = app
    self.registryHash = registryHash
    self.bundleId = bundleId
    self.assignment = assignment
    self.screen = screen
    self.ctaNode = ctaNode
  }
}

extension Payload {
  static func make(interactive: Bool? = nil, logID: String? = nil, params: [String: String]? = nil, purchased: Bool? = nil,
                   reason: Reason? = nil, stat: Stat? = nil, vector: BehaviorVector? = nil, verb: Verb? = nil,
                   x: Double? = nil, y: Double? = nil) -> Payload {
    Payload(interactive: interactive, logID: logID, params: params, purchased: purchased, reason: reason, stat: stat,
            vector: vector, verb: verb, x: x, y: y)
  }
}

/// Swift port of the reference `ScreenSession` (packages/contract/src/session.ts): drives the
/// tracker and emits event envelopes. Must reproduce conformance/sessions/<name>.events.json
/// (except `event_id`) — event parity with web and Android.
public final class ScreenSession {
  private let ctx: SessionContext
  private let tracker: BehaviorTracker
  private let newEventId: () -> String
  private let sink: (Event) -> Void
  private var seq = 0
  public private(set) var events: [Event] = []
  public private(set) var ended = false

  public init(_ ctx: SessionContext, now: Int, newEventId: @escaping () -> String = { UUID().uuidString.lowercased() },
              sink: @escaping (Event) -> Void = { _ in }) {
    self.ctx = ctx
    self.newEventId = newEventId
    self.sink = sink
    tracker = BehaviorTracker(screen: ctx.screen, ctaNode: ctx.ctaNode, now: now)
    emit(now, .screenStart, nil, .make())
  }

  private func emit(_ t: Int, _ type: EventType, _ node: String?, _ payload: Payload) {
    let e = Event(app: ctx.app, assignment: ctx.assignment, bundleID: ctx.bundleId, eventID: newEventId(),
                  installID: ctx.installId, node: node, payload: payload, registryHash: ctx.registryHash,
                  screen: ctx.screen, seq: seq, sessionID: ctx.sessionId, tsClientMS: t, type: type)
    seq += 1
    events.append(e)
    sink(e)
  }

  /// A DivKit sight/click stat (or a component-fired click).
  public func stat(_ t: Int, logId: String, stat: Stat? = nil) {
    guard !ended else { return }
    tracker.stat(t, logId: logId)
    let p = LogId.parse(logId)
    emit(t, .stat, p.map { "\($0.screen)/\($0.node)" }, .make(logID: logId, stat: stat ?? Self.statKind(p?.kind)))
  }

  private static func statKind(_ kind: String?) -> Stat {
    switch kind {
    case "out": return .disappear
    case "tap": return .click
    default: return .visible
    }
  }

  public func tap(_ t: Int, x: Double, y: Double, hit: TapHit) {
    guard !ended else { return }
    let (dead, rage) = tracker.tap(t, x: x, y: y, hit: hit)
    emit(t, .tap, hit.node, .make(interactive: hit.interactive, x: x, y: y))
    if dead { emit(t, .deadClick, hit.node, .make()) }
    if rage { emit(t, .rageClick, hit.node, .make()) }
  }

  public func action(_ t: Int, verb: String, params: [String: String]) {
    guard !ended else { return }
    tracker.action(t, verb: verb)
    emit(t, .action, nil, .make(params: params, verb: Verb(rawValue: verb)))
  }

  public func purchaseResult(_ t: Int, purchased: Bool) {
    guard !ended else { return }
    let vector = tracker.purchaseResult(t, purchased: purchased)
    emit(t, .purchaseResult, nil, .make(purchased: purchased))
    if let vector { close(t, .converted, vector) }
  }

  public func hidden(_ t: Int) { if !ended { tracker.hidden(t) } }
  public func visible(_ t: Int) { if !ended { tracker.visible(t) } }

  /// Ends the screen (no-op if already ended) and returns the final vector.
  @discardableResult
  public func end(_ t: Int, reason: Reason) -> BehaviorVector {
    if !ended { close(t, reason, tracker.end(t)) }
    return tracker.end(t)
  }

  public func vector(_ t: Int) -> BehaviorVector { tracker.vector(t) }

  private func close(_ t: Int, _ reason: Reason, _ vector: BehaviorVector) {
    ended = true
    emit(t, .screenEnd, nil, .make(reason: reason, vector: vector))
  }
}
