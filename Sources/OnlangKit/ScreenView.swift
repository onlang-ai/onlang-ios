#if canImport(UIKit)
import DivKit
import OnlangContract
import OnlangCore
import UIKit
import VGSL

/// One screen: a `DivView` in a host scroll view, plus what DivKit lacks (ADR-0003): a touch
/// observer for rage/dead clicks (never consumes touches) and visible-bounds reporting while
/// the host scrolls (DivKit evaluates sight actions only when the host reports them).
final class ScreenView: UIView, UIScrollViewDelegate {
  let bundle: LoadedBundle
  let divView: DivView
  let scroll = UIScrollView()
  private let observer: TouchObserver
  private var sizeObservation: Disposable?
  /// Called once, when the card has its first size (render latency).
  var onFirstLayout: (() -> Void)?

  init(components: DivKitComponents, bundle: LoadedBundle, card: [String: Any], templates: [String: Any],
       onTap: @escaping (_ x: Double, _ y: Double, _ hit: TapHit) -> Void) {
    self.bundle = bundle
    divView = DivView(divKitComponents: components)
    observer = TouchObserver(interactive: Set(bundle.header.interactiveIDS), onTap: onTap)
    super.init(frame: .zero)
    scroll.delegate = self
    scroll.addSubview(divView)
    addSubview(scroll)
    addGestureRecognizer(observer)
    sizeObservation = divView.addObserver { [weak self] _ in
      DispatchQueue.main.async { self?.setNeedsLayout() }
    }
    let source = DivViewSource(kind: .json(["templates": templates, "card": card]), cardId: DivCardID(rawValue: bundle.header.bundleID))
    Task { @MainActor [weak self] in
      guard let self else { return }
      await self.divView.setSource(source)
      self.divView.setParentScrollView(self.scroll) // only after setSource (stored on the block provider)
      self.setNeedsLayout()
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError("init(coder:) is not supported") }

  override func layoutSubviews() {
    super.layoutSubviews()
    scroll.frame = bounds
    guard divView.cardSize != nil, bounds.width > 0 else { return }
    let size = divView.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
    divView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: size.height))
    scroll.contentSize = divView.frame.size
    updateVisibleBounds()
    if let first = onFirstLayout {
      onFirstLayout = nil
      first()
    }
  }

  func scrollViewDidScroll(_: UIScrollView) { updateVisibleBounds() }

  private func updateVisibleBounds() {
    divView.onVisibleBoundsChanged(to: scroll.convert(scroll.bounds, to: divView).intersection(divView.bounds))
  }

  /// Smallest view under the point (in this view's coordinates) carrying a div id.
  func hitTest(at p: CGPoint) -> TapHit { observer.hitTest(self, p) }

  /// The view whose accessibilityIdentifier is `id`, if rendered.
  func view(withId id: String) -> UIView? {
    func find(_ v: UIView) -> UIView? {
      if v.accessibilityIdentifier == id { return v }
      for s in v.subviews { if let f = find(s) { return f } }
      return nil
    }
    return find(divView)
  }

  /// Feeds a synthetic tap through the classifier (tests; UIKit has no public touch injection).
  func simulateTap(at p: CGPoint) { observer.simulateTap(in: self, at: p) }
}

/// Observes touches without consuming them; hit-tests by accessibilityIdentifier (= div id)
/// at touch-down. Never recognizes, so it cannot interfere with DivKit or the scroll view.
final class TouchObserver: UIGestureRecognizer {
  private let interactive: Set<String>
  private lazy var classifier = TapClassifier<TapHit>(slop: Double(OnlangConstants.tapSlopPt), onTap: onTap)
  private let onTap: (Double, Double, TapHit) -> Void

  init(interactive: Set<String>, onTap: @escaping (Double, Double, TapHit) -> Void) {
    self.interactive = interactive
    self.onTap = onTap
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let view, let touch = touches.first else { return }
    if (event.allTouches?.count ?? touches.count) > 1 {
      classifier.secondTouch()
      return
    }
    let p = touch.location(in: view)
    classifier.down(x: p.x, y: p.y) { hitTest(view, p) }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent) {
    guard let view, let p = touches.first?.location(in: view) else { return }
    classifier.move(x: p.x, y: p.y)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let view, let p = touches.first?.location(in: view) else { return }
    classifier.up(x: p.x, y: p.y)
    if (event.allTouches ?? touches).allSatisfy({ $0.phase == .ended || $0.phase == .cancelled }) { state = .failed }
  }

  override func touchesCancelled(_: Set<UITouch>, with _: UIEvent) {
    classifier.cancel()
    state = .failed
  }

  override func reset() { classifier.cancel() }

  func simulateTap(in view: UIView, at p: CGPoint) {
    classifier.down(x: p.x, y: p.y) { hitTest(view, p) }
    classifier.up(x: p.x, y: p.y)
  }

  func hitTest(_ root: UIView, _ p: CGPoint) -> TapHit {
    var chain: [(id: String, area: CGFloat)] = []
    func walk(_ v: UIView) {
      guard !v.isHidden, v.alpha > 0 else { return }
      let frame = v.convert(v.bounds, to: root)
      guard frame.contains(p) else { return }
      if let id = v.accessibilityIdentifier, !id.isEmpty { chain.append((id, frame.width * frame.height)) }
      v.subviews.forEach(walk)
    }
    walk(root)
    return TapHit(node: chain.min { $0.area < $1.area }?.id, interactive: chain.contains { interactive.contains($0.id) })
  }
}
#endif
