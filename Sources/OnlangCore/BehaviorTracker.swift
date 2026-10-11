import Foundation
import OnlangContract

/// Kind/screen/node of an `onl.<kind>:<screen>/<node>` log id (ADR-0002).
public struct LogId: Equatable, Sendable {
  public let kind: String
  public let screen: String
  public let node: String

  private static let pattern = try! NSRegularExpression(pattern: OnlangConstants.logIdPattern)
  private static let depthPattern = try! NSRegularExpression(pattern: #"^__depth_(\d+)of(\d+)$"#)

  public static func parse(_ id: String) -> LogId? {
    let ns = id as NSString
    guard let m = pattern.firstMatch(in: id, range: NSRange(location: 0, length: ns.length)) else { return nil }
    return LogId(kind: ns.substring(with: m.range(at: 1)), screen: ns.substring(with: m.range(at: 2)), node: ns.substring(with: m.range(at: 3)))
  }

  /// `__depth_<i>of<n>` → (i, n).
  public static func depth(_ node: String) -> (Int, Int)? {
    let ns = node as NSString
    guard let m = depthPattern.firstMatch(in: node, range: NSRange(location: 0, length: ns.length)),
          let i = Int(ns.substring(with: m.range(at: 1))), let n = Int(ns.substring(with: m.range(at: 2))) else { return nil }
    return (i, n)
  }
}

/// Result of hit-testing a tap at touch-down (ADR-0003).
public struct TapHit: Equatable, Sendable {
  public let node: String?
  public let interactive: Bool
  public init(node: String?, interactive: Bool) {
    self.node = node
    self.interactive = interactive
  }
}

/// Behavior tracker: Swift port of the reference `BehaviorTracker`
/// (packages/contract/src/tracker.ts). Must reproduce every vector in conformance/sessions.
/// Time (ms) is passed in by the caller, so it is deterministic and testable.
public final class BehaviorTracker {
  private struct Tap { let t: Int; let x: Double; let y: Double }

  private let screen: String
  private let ctaNode: String?
  private let shownAt: Int
  private var last: Int
  private var hiddenSince: Int?
  private var hiddenMs = 0
  private var depthMax = 0
  private var depthTotal = 0
  private var impressions: [String: Int] = [:]
  private var dwellOpen: [(id: String, start: Int)] = []
  private var paused: [String] = []
  private var dwell: [String: Int] = [:]
  private var dead: [String: Int] = [:]
  private var recent: [Tap] = []
  private var rage = 0
  private var firstInteraction: Int?
  private var ctaSeenAt: Int?
  private var ctaHesitation: Int?
  private var planSwitches = 0
  private var converted = false
  private var ended: BehaviorVector?

  public init(screen: String, ctaNode: String?, now: Int) {
    self.screen = screen
    self.ctaNode = ctaNode
    shownAt = now
    last = now
  }

  private func tick(_ now: Int) {
    precondition(now >= last, "time went backwards: \(now) < \(last)")
    last = now
  }

  private func closeDwell(_ id: String, _ now: Int) {
    guard let i = dwellOpen.firstIndex(where: { $0.id == id }) else { return }
    dwell[id, default: 0] += now - dwellOpen[i].start
    dwellOpen.remove(at: i)
  }

  /// A DivKit sight or click stat. Unknown or foreign log ids are ignored.
  public func stat(_ now: Int, logId: String) {
    tick(now)
    guard let p = LogId.parse(logId), p.screen == screen else { return }
    let id = "\(p.screen)/\(p.node)"
    switch p.kind {
    case "imp":
      impressions[id, default: 0] += 1
      if !dwellOpen.contains(where: { $0.id == id }) { dwellOpen.append((id: id, start: now - OnlangConstants.impressionDurationMs)) }
      if id == ctaNode, ctaSeenAt == nil { ctaSeenAt = now }
    case "out":
      paused.removeAll { $0 == id }
      closeDwell(id, now)
    case "depth":
      if case let (i, total)? = LogId.depth(p.node) {
        depthTotal = total
        depthMax = max(depthMax, i)
      }
    default:
      break
    }
  }

  /// Returns whether the tap was a dead click and whether it completed a rage burst.
  public func tap(_ now: Int, x: Double, y: Double, hit: TapHit) -> (dead: Bool, rage: Bool) {
    tick(now)
    if firstInteraction == nil { firstInteraction = now - shownAt }
    let deadNode = hit.interactive ? nil : hit.node
    if let deadNode { dead[deadNode, default: 0] += 1 }
    recent = recent.filter {
      now - $0.t <= OnlangConstants.rageWindowMs && hypot(x - $0.x, y - $0.y) <= Double(OnlangConstants.rageRadiusPt)
    } + [Tap(t: now, x: x, y: y)]
    let isRage = recent.count == OnlangConstants.rageTaps
    if isRage { rage += 1 }
    return (deadNode != nil, isRage)
  }

  public func action(_ now: Int, verb: String) {
    tick(now)
    if verb == "select" { planSwitches += 1 }
    if verb == "purchase", let seen = ctaSeenAt, ctaHesitation == nil { ctaHesitation = now - seen }
  }

  public func purchaseResult(_ now: Int, purchased: Bool) -> BehaviorVector? {
    tick(now)
    guard purchased else { return nil }
    converted = true
    return end(now)
  }

  /// Backgrounded / covered: pauses open dwell intervals (background time is not dwell).
  public func hidden(_ now: Int) {
    tick(now)
    guard hiddenSince == nil else { return }
    hiddenSince = now
    for (id, start) in dwellOpen {
      dwell[id, default: 0] += now - start
      paused.append(id)
    }
    dwellOpen.removeAll()
  }

  public func visible(_ now: Int) {
    tick(now)
    guard let since = hiddenSince else { return }
    hiddenMs += now - since
    hiddenSince = nil
    for id in paused where !dwellOpen.contains(where: { $0.id == id }) { dwellOpen.append((id: id, start: now)) }
    paused = []
  }

  /// Closes open dwell and freezes the vector. Idempotent.
  @discardableResult
  public func end(_ now: Int) -> BehaviorVector {
    if let ended { return ended }
    tick(now)
    if hiddenSince != nil { visible(now) }
    for (id, start) in dwellOpen { dwell[id, default: 0] += now - start }
    dwellOpen.removeAll()
    let v = vector(now)
    ended = v
    return v
  }

  public func vector(_ now: Int) -> BehaviorVector {
    BehaviorVector(
      converted: converted,
      ctaHesitationMS: ctaHesitation,
      deadClicks: dead,
      dwellMS: dwell,
      impressions: impressions,
      planSwitches: planSwitches,
      rageClicks: rage,
      screen: screen,
      scrollDepth: depthTotal == 0 ? 0 : (Double(depthMax) / Double(depthTotal) * 1000).rounded() / 1000,
      timeOnScreenMS: now - shownAt - hiddenMs,
      timeToFirstInteractionMS: firstInteraction
    )
  }
}
