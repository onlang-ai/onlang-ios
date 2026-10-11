#if canImport(UIKit)
import UIKit

/// What a registered component receives besides its props: its node id
/// (`<screen>/<section>.<slot>`) and a way to fire onlang:// actions (e.g. a plan picker's
/// `onlang://select?product=monthly`). Fired actions are recorded and routed by the SDK
/// (ADR-0003): DivKit has no public way to dispatch them from native code.
public struct ComponentContext {
  public let node: String
  let dispatch: (_ logId: String, _ url: URL) -> Void

  public func fire(_ url: URL) { dispatch("onl.tap:\(node)", url) }
}

/// The app's design-system registry: register each native component once, under the name
/// used in `onlang/registry.json`. `interactive` components handle their own taps and report
/// them through `ComponentContext.fire`; others get taps from DivKit wrappers.
public final class OnlangRegistry {
  public typealias Factory = (_ props: [String: Any], _ context: ComponentContext) -> UIView

  private var entries: [String: (factory: Factory, interactive: Bool)] = [:]

  public init() {}

  @discardableResult
  public func register(_ type: String, interactive: Bool = false, factory: @escaping Factory) -> OnlangRegistry {
    entries[type] = (factory, interactive)
    return self
  }

  public func has(_ type: String) -> Bool { entries[type] != nil }
  public func isInteractive(_ type: String) -> Bool { entries[type]?.interactive ?? false }
  public var types: [String] { Array(entries.keys) }

  func make(_ type: String, props: [String: Any], context: ComponentContext) -> UIView? {
    entries[type]?.factory(props, context)
  }
}
#endif
