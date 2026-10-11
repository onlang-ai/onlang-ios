#if canImport(UIKit)
import DivKit
import LayoutKit
import UIKit
import VGSL

/// Receives everything DivKit reports for the screen currently on display.
protocol ScreenEvents: AnyObject {
  func stat(logId: String)
  func route(_ url: URL, logId: String?)
  func error(_ message: String)
}

/// Registry → DivKit `custom` divs. The component view's accessibilityIdentifier is its node
/// id, the same key DivKit uses for its own views, so taps hit-test uniformly.
struct RegistryBlockFactory: DivCustomBlockFactory {
  let registry: OnlangRegistry
  let dispatch: (_ logId: String, _ url: URL) -> Void

  func makeBlock(data: DivCustomData, context _: DivBlockModelingContext) -> Block {
    let node = data.data["onl_node"] as? String ?? data.name
    guard let view = registry.make(data.name, props: data.data, context: ComponentContext(node: node, dispatch: dispatch))
    else { return EmptyBlock() }
    view.accessibilityIdentifier = node
    let intrinsic = ViewIntrinsicSize(view)
    return GenericViewBlock(content: .view(view), width: trait(data.widthTrait, intrinsic), height: trait(data.heightTrait, intrinsic))
  }

  private func trait(_ t: LayoutTrait, _ intrinsic: ViewIntrinsicSize) -> GenericViewBlock.Trait {
    switch t {
    case let .fixed(value): return .fixed(value)
    case .intrinsic: return .intrinsic(intrinsic) // wrap_content: Auto Layout fitting size
    case .weighted: return .resizable // match_parent
    }
  }
}

/// wrap_content for registry views: their Auto Layout fitting size.
final class ViewIntrinsicSize: IntrinsicCalculator {
  private let view: UIView
  init(_ view: UIView) { self.view = view }

  func calculateWidth() -> CGFloat {
    view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
  }

  func calculateHeight(width: CGFloat) -> CGFloat {
    view.systemLayoutSizeFitting(
      CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
  }
}

/// DivKit sight/click stats and errors → the current screen (log_id convention, ADR-0003).
final class SessionReporter: DivReporter {
  private let target: () -> ScreenEvents?
  init(target: @escaping () -> ScreenEvents?) { self.target = target }

  func reportError(cardId: DivCardID, error: DivError) {
    target()?.error("\(cardId.rawValue): \(error)")
  }

  func reportAction(cardId _: DivCardID, info: DivActionInfo) {
    switch info.source {
    case .visibility, .disappear, .tap: target()?.stat(logId: info.logId)
    default: break
    }
  }
}

/// Routes onlang:// actions to the flow; other URLs open in the system.
final class ActionRouter: DivUrlHandler {
  static let scheme = "onlang"
  private let target: () -> ScreenEvents?
  init(target: @escaping () -> ScreenEvents?) { self.target = target }

  func handle(_ url: URL, info: DivActionInfo, sender _: AnyObject?) {
    route(url, logId: info.logId)
  }

  func handle(_ url: URL, sender _: AnyObject?) {
    route(url, logId: nil)
  }

  private func route(_ url: URL, logId: String?) {
    if url.scheme == Self.scheme {
      target()?.route(url, logId: logId)
    } else if url.scheme == "http" || url.scheme == "https" {
      UIApplication.shared.open(url)
    }
  }
}
#endif
