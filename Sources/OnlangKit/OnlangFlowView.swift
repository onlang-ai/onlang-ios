#if canImport(UIKit) && canImport(SwiftUI)
import OnlangCore
import SwiftUI
import UIKit

/// SwiftUI host for a placement's flow (plan §8.2):
///
/// ```
/// OnlangFlowView(placement: "onboarding_paywall") { result in
///   if result.outcome == .purchased { unlock() }
///   showPaywall = false
/// }
/// ```
///
/// The flow loads once, when the view first appears; `onFinished` gets the latest closure.
@available(iOS 15.0, *)
public struct OnlangFlowView: UIViewControllerRepresentable {
  private let make: () -> OnlangFlowViewController
  private let onFinished: (FlowResult) -> Void

  /// Loads `placement` (network → cache → bundled fallback); `assign` pins hypothesis arms (QA only).
  public init(placement: String, locale: String? = nil, assign: [String: String]? = nil, onFinished: @escaping (FlowResult) -> Void) {
    make = { OnlangFlowViewController(placement: placement, locale: locale, assign: assign) }
    self.onFinished = onFinished
  }

  /// Shows an already-loaded flow (previews, tests).
  public init(flow: LoadedFlow, store: StoreValues, onFinished: @escaping (FlowResult) -> Void) {
    make = { OnlangFlowViewController(flow: flow, store: store) }
    self.onFinished = onFinished
  }

  public func makeCoordinator() -> Coordinator { Coordinator(onFinished: onFinished) }

  public func makeUIViewController(context: Context) -> OnlangFlowViewController {
    let controller = make()
    controller.delegate = context.coordinator
    return controller
  }

  public func updateUIViewController(_: OnlangFlowViewController, context: Context) {
    context.coordinator.onFinished = onFinished
  }

  public final class Coordinator: OnlangFlowDelegate {
    var onFinished: (FlowResult) -> Void
    init(onFinished: @escaping (FlowResult) -> Void) { self.onFinished = onFinished }
    public func flowDidFinish(_: OnlangFlowViewController, result: FlowResult) { onFinished(result) }
  }
}
#endif
