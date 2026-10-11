import Foundation

/// Turns raw touches into taps (ADR-0003, conformance requirement 2): a tap is a single-touch
/// down/up pair that stays within `slop`. The hit is taken **at touch-down** (before the tap
/// can change the tree); the tap is reported at touch-up. Scrolls, drags, multi-touch and
/// cancels are not taps. The platform layer feeds events; `onTap` receives the result.
public final class TapClassifier<Hit> {
  private let slop: Double
  private let onTap: (_ x: Double, _ y: Double, _ hit: Hit) -> Void
  private var pending: (x: Double, y: Double, hit: Hit)?

  public init(slop: Double, onTap: @escaping (_ x: Double, _ y: Double, _ hit: Hit) -> Void) {
    self.slop = slop
    self.onTap = onTap
  }

  /// First touch down; `hitTest` runs now, against the tree as the user saw it.
  public func down(x: Double, y: Double, hitTest: () -> Hit) { pending = (x, y, hitTest()) }

  public func move(x: Double, y: Double) {
    guard let d = pending else { return }
    if hypot(x - d.x, y - d.y) > slop { pending = nil }
  }

  /// A second touch makes it a gesture, not a tap.
  public func secondTouch() { pending = nil }

  public func cancel() { pending = nil }

  public func up(x: Double, y: Double) {
    guard let d = pending else { return }
    pending = nil
    if hypot(x - d.x, y - d.y) <= slop { onTap(d.x, d.y, d.hit) }
  }
}
