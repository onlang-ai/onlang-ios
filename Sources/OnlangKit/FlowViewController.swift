#if canImport(UIKit)
import DivKit
import OnlangContract
import OnlangCore
import UIKit
import VGSL

/// How a flow ended.
public struct FlowResult {
  /// `.failed`: no flow could load. `.killed`: a kill switch is on for the placement (ADR-0012).
  /// Show the app's own screen for both.
  public enum Outcome: Sendable { case purchased, restored, closed, completed, failed, killed }

  public let placement: String
  public let outcome: Outcome
  /// Product bought or last selected.
  public let product: String?
  /// Quiz answers: question → answer.
  public let answers: [String: String]
  public let releaseId: String?
  public let source: LoadedFlow.Source?
}

public protocol OnlangFlowDelegate: AnyObject {
  func flowDidFinish(_ flow: OnlangFlowViewController, result: FlowResult)
  func flow(_ flow: OnlangFlowViewController, didShowScreen screen: String, at index: Int)
}

public extension OnlangFlowDelegate {
  func flow(_: OnlangFlowViewController, didShowScreen _: String, at _: Int) {}
}

/// Shows a placement's flow: loads it (network → cache → bundled fallback), renders each
/// screen through DivKit with the app's registry, routes onlang:// actions and records one
/// `ScreenSession` per screen (events go to the queue, ADR-0003).
public final class OnlangFlowViewController: UIViewController, ScreenEvents {
  public weak var delegate: OnlangFlowDelegate?

  private let globals = DivVariableStorage()
  private lazy var components = DivKitComponents(
    divCustomBlockFactory: RegistryBlockFactory(registry: Onlang.registry, dispatch: { [weak self] logId, url in self?.dispatch(logId, url) }),
    reporter: SessionReporter(target: { [weak self] in self }),
    urlHandler: ActionRouter(target: { [weak self] in self }),
    variablesStorage: DivVariablesStorage(outerStorage: globals)
  )

  // Event clock: wall time at start, advanced monotonically.
  private let wallStart = Int(Date().timeIntervalSince1970 * 1000)
  private let uptimeStart = ProcessInfo.processInfo.systemUptime
  private func now() -> Int { wallStart + Int((ProcessInfo.processInfo.systemUptime - uptimeStart) * 1000) }

  private var placement: String?
  private var locale: String?
  private var assign: [String: String]?
  private var flow: LoadedFlow?
  private var store: StoreValues = [:]
  private var sessionId = UUID().uuidString.lowercased()
  private var index = -1
  private(set) var screen: ScreenView?
  private var session: ScreenSession?
  private var selected: String?
  private var answers: [String: String] = [:]
  private var finished = false
  private var purchasing = false
  private var notificationTokens: [NSObjectProtocol] = []
  /// Called after each screen's first layout with its cold render time in ms (show → first layout).
  var onScreenRendered: ((_ screen: String, _ ms: Double) -> Void)?

  /// Loads a placement when the view appears; `assign` pins hypothesis arms (QA / preview only).
  public init(placement: String, locale: String? = nil, assign: [String: String]? = nil) {
    self.placement = placement
    self.locale = locale
    self.assign = assign
    super.init(nibName: nil, bundle: nil)
  }

  /// Shows an already-loaded flow with the given store values.
  public init(flow: LoadedFlow, store: StoreValues) {
    super.init(nibName: nil, bundle: nil)
    self.flow = flow
    self.store = store
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError("init(coder:) is not supported") }

  deinit { notificationTokens.forEach { NotificationCenter.default.removeObserver($0) } }

  override public func viewDidLoad() {
    super.viewDidLoad()
    precondition(Onlang.isConfigured, "call Onlang.configure() first")
    view.backgroundColor = .systemBackground
    let center = NotificationCenter.default
    notificationTokens = [
      center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.appHidden() },
      center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in self?.appVisible() },
    ]
    if let flow {
      show(flow, store: store)
    } else if let placement {
      load(placement)
    }
  }

  private func load(_ placement: String) {
    let locale = locale ?? Onlang.config.defaultLocale
    let assign = assign
    Task { @MainActor [weak self] in
      do {
        let flow = try await Onlang.delivery.load(placement: placement, locale: locale, assign: assign)
        let products = Array(Set(flow.screens.flatMap(\.header.products))).sorted()
        var store: StoreValues = [:]
        if !products.isEmpty { store = await Onlang.store.storeValues(products: products) }
        self?.show(flow, store: store)
      } catch let killed as FlowKilled {
        Onlang.config.log("flow \(placement) is switched off: \(killed.reason)")
        self?.finish(FlowResult(placement: placement, outcome: .killed, product: nil, answers: [:], releaseId: nil, source: nil))
      } catch {
        Onlang.config.log("flow \(placement) failed to load: \(error)")
        self?.finish(FlowResult(placement: placement, outcome: .failed, product: nil, answers: [:], releaseId: nil, source: nil))
      }
    }
  }

  /// Replaces whatever is on display with `flow`.
  public func show(_ flow: LoadedFlow, store: StoreValues) {
    endScreen(.dropOff)
    self.flow = flow
    self.store = store
    sessionId = UUID().uuidString.lowercased()
    selected = nil
    answers = [:]
    finished = false
    purchasing = false
    index = -1
    guard !flow.screens.isEmpty else { return finish(result(.failed)) }
    for bundle in flow.screens {
      for (name, value) in Bundles.globalValues(bundle.header, store: store) {
        globals.put(name: DivVariableName(rawValue: name), value: .string(value))
      }
    }
    showScreen(0)
  }

  private func showScreen(_ i: Int) {
    guard let flow else { return }
    let bundle = flow.screens[i]
    let h = bundle.header
    let card = Bundles.prepass(bundle.card, store: store).foundation as? [String: Any] ?? [:]
    let templates = bundle.templates.foundation as? [String: Any] ?? [:]
    let started = ProcessInfo.processInfo.systemUptime
    let next = ScreenView(components: components, bundle: bundle, card: card, templates: templates) { [weak self] x, y, hit in
      guard let self else { return }
      self.session?.tap(self.now(), x: x, y: y, hit: hit)
    }
    next.onFirstLayout = { [weak self] in self?.onScreenRendered?(h.screen, (ProcessInfo.processInfo.systemUptime - started) * 1000) }
    index = i
    session = ScreenSession(
      SessionContext(sessionId: sessionId, installId: Onlang.installId, app: Onlang.config.app, registryHash: h.registry.hash,
                     bundleId: h.bundleID, assignment: flow.assignment, screen: h.screen, ctaNode: h.ctaNode),
      now: now(),
      sink: Onlang.queue
    )
    screen?.removeFromSuperview()
    next.frame = view.bounds
    next.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(next)
    screen = next
    delegate?.flow(self, didShowScreen: h.screen, at: i)
  }

  private func endScreen(_ reason: Reason) {
    if let session, !session.ended { session.end(now(), reason: reason) }
    session = nil
    Onlang.flush()
  }

  private func result(_ outcome: FlowResult.Outcome, product: String? = nil) -> FlowResult {
    FlowResult(placement: flow?.placement ?? placement ?? "", outcome: outcome, product: product ?? selected, answers: answers,
               releaseId: flow?.releaseId, source: flow?.source)
  }

  private func finish(_ result: FlowResult) {
    guard !finished else { return }
    finished = true
    endScreen(.close)
    delegate?.flowDidFinish(self, result: result)
  }

  // MARK: ScreenEvents (DivKit callbacks for the screen on display)

  func stat(logId: String) {
    session?.stat(now(), logId: logId)
  }

  func route(_ url: URL, logId _: String?) {
    guard let session, !finished, let verb = url.host else { return }
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let params = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })
    session.action(now(), verb: verb, params: params)
    switch verb {
    case "select":
      if let p = params["product"] { selected = p }
    case "answer":
      if let q = params["q"], let a = params["a"] { answers[q] = a }
    case "next":
      endScreen(.next)
      if let flow, index + 1 < flow.screens.count { showScreen(index + 1) } else { finish(result(.completed)) }
    case "close":
      finish(result(.closed))
    case "open":
      if let doc = params["doc"], let target = Onlang.config.legalUrls[doc] { UIApplication.shared.open(target) }
    case "purchase":
      purchase(params["product"] ?? selected)
    case "restore":
      Onlang.purchases.restore(from: self) { [weak self] restored in
        DispatchQueue.main.async {
          guard restored, let self, !self.finished else { return }
          self.finish(self.result(.restored))
        }
      }
    default:
      Onlang.config.log("unknown action \(url)")
    }
  }

  func error(_ message: String) {
    Onlang.config.log("DivKit error: \(message)")
  }

  private func dispatch(_ logId: String, _ url: URL) {
    stat(logId: logId)
    route(url, logId: logId)
  }

  private func purchase(_ product: String?) {
    guard let product else { return Onlang.config.log("purchase without a product") }
    guard !purchasing else { return }
    purchasing = true
    let s = session
    Onlang.purchases.purchase(product: product, from: self) { [weak self] outcome in
      DispatchQueue.main.async {
        guard let self else { return }
        self.purchasing = false
        guard let s, s === self.session, !self.finished else { return }
        let bought = outcome == .purchased
        s.purchaseResult(self.now(), purchased: bought)
        if bought { self.finish(self.result(.purchased, product: product)) }
      }
    }
  }

  // MARK: Visibility: dwell pauses while hidden (ADR-0003)

  private func appHidden() {
    session?.hidden(now())
    Onlang.flush() // the background session finishes the upload while the app is suspended
  }
  private func appVisible() { session?.visible(now()) }

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    session?.visible(now())
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Dismissed without closing, buying or finishing the flow: a drop-off. Covered: paused.
    if isBeingDismissed || isMovingFromParent || navigationController?.isBeingDismissed == true {
      if !finished { endScreen(.dropOff) }
    } else {
      session?.hidden(now())
    }
  }

  // MARK: Test hooks

  /// Routes an action exactly as a DivKit tap on it would (tests; see ScreenView.simulateTap).
  func perform(_ url: URL, logId: String) { dispatch(logId, url) }
}
#endif
