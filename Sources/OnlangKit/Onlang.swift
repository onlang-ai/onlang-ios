#if canImport(UIKit)
import Foundation
import OnlangContract
import OnlangCore
import UIKit

/// Static SDK configuration.
public struct OnlangConfig {
  /// App id, as in `onlang.config.ts`.
  public var app: String
  /// Delivery API base URL (control API, or `onlang dev-server` in development).
  public var baseUrl: URL
  /// The app's publishable token (onl_pk_…): sent to delivery and ingest, which require it in production.
  public var sdkKey: String?
  public var defaultLocale: String
  /// `onlang://open?doc=<key>` targets, e.g. `["terms": URL(...)]`.
  public var legalUrls: [String: URL]
  /// Bundled fallback flows: `<fallbackDirectory>/<placement>.<locale>.json` (array of bundles).
  public var fallbackBundle: Bundle
  public var fallbackDirectory: String
  public var timeout: TimeInterval
  /// Upload consent until the app calls `Onlang.setConsent(_:)`; the stored choice wins after
  /// that. `.pending` keeps events on the device (bounded by `eventRetention`) and sends nothing.
  public var consent: Consent
  /// Queued events older than this are deleted, sent or not.
  public var eventRetention: TimeInterval
  /// Upload through a background URLSession (finishes while the app is suspended; needs
  /// `Onlang.handleEventsForBackgroundURLSession` in the app delegate). Off: an in-process upload.
  public var backgroundUpload: Bool
  /// Debug hook: every event as it is recorded (in-process only, whatever the consent).
  public var onEvent: ((Event) -> Void)?
  public var log: (String) -> Void

  public init(app: String, baseUrl: URL, sdkKey: String? = nil, defaultLocale: String = Locale.current.languageCode ?? "en", legalUrls: [String: URL] = [:],
              fallbackBundle: Bundle = .main, fallbackDirectory: String = "onlang", timeout: TimeInterval = 1.5,
              consent: Consent = .pending, eventRetention: TimeInterval = EventQueue.defaultRetention, backgroundUpload: Bool = true,
              onEvent: ((Event) -> Void)? = nil, log: @escaping (String) -> Void = { print("Onlang: \($0)") }) {
    self.app = app
    self.baseUrl = baseUrl
    self.sdkKey = sdkKey
    self.defaultLocale = defaultLocale
    self.legalUrls = legalUrls
    self.fallbackBundle = fallbackBundle
    self.fallbackDirectory = fallbackDirectory
    self.timeout = timeout
    self.consent = consent
    self.eventRetention = eventRetention
    self.backgroundUpload = backgroundUpload
    self.onEvent = onEvent
    self.log = log
  }
}

public enum PurchaseOutcome: Sendable { case purchased, cancelled, pending, failed }

/// Billing stays in the app (or an adapter such as `OnlangStoreKit`): Onlang asks to buy a
/// product id from the registry's `products` and records the outcome.
public protocol PurchaseHandler: AnyObject {
  func purchase(product: String, from controller: UIViewController?, completion: @escaping (PurchaseOutcome) -> Void)
  func restore(from controller: UIViewController?, completion: @escaping (_ restored: Bool) -> Void)
}

/// Store data for `{{price|period|trial.<product>}}`: `["price": ["annual": "$59.99"]]`, …
public protocol StoreProvider: AnyObject {
  func storeValues(products: [String]) async -> StoreValues
}

/// SDK entry point: configure once (e.g. in `application(_:didFinishLaunchingWithOptions:)`),
/// then present an `OnlangFlowViewController`.
public enum Onlang {
  public private(set) static var config: OnlangConfig!
  static var registry: OnlangRegistry!
  static var purchases: PurchaseHandler!
  static var store: StoreProvider!
  static var delivery: DeliveryClient!
  static var events: EventQueue!
  /// This install's id: a random lowercase UUID, persisted, sent with every request and event.
  /// The purchase adapters hand it to the store (StoreKit `appAccountToken`, the RevenueCat
  /// attribute `onlang_install_id`) so store conversions reach the optimizer; pass it the same
  /// way if you run purchases outside Onlang. Empty until `configure`.
  public internal(set) static var installId = ""
  private static var uploader: BackgroundUploader?
  // Storage keys keep the original `ai.onlang` prefix: renaming them would give every existing
  // install a new id and forget its consent.
  private static let consentKey = "ai.onlang.consent"

  /// The consent the queue reads from any thread.
  private final class ConsentBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Consent.pending
    var current: Consent {
      get { lock.lock(); defer { lock.unlock() }; return value }
      set { lock.lock(); value = newValue; lock.unlock() }
    }
  }

  private static let consentBox = ConsentBox()

  /// Current upload consent (see `OnlangConfig.consent`).
  public static var consent: Consent { consentBox.current }

  public static var isConfigured: Bool { config != nil }

  public static func configure(_ config: OnlangConfig, registry: OnlangRegistry, purchases: PurchaseHandler, store: StoreProvider) {
    self.config = config
    self.registry = registry
    self.purchases = purchases
    self.store = store
    let defaults = UserDefaults.standard
    if let id = defaults.string(forKey: "ai.onlang.install_id") {
      installId = id
    } else {
      installId = UUID().uuidString.lowercased()
      defaults.set(installId, forKey: "ai.onlang.install_id")
    }
    let fm = FileManager.default
    let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("onlang", isDirectory: true)
    let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("onlang", isDirectory: true)
    let bundle = config.fallbackBundle
    let dir = config.fallbackDirectory
    delivery = DeliveryClient(baseUrl: config.baseUrl, app: config.app, installId: installId, cacheDir: caches, fallback: { placement, locale in
      guard let url = bundle.url(forResource: "\(placement).\(locale)", withExtension: "json", subdirectory: dir),
            let data = try? Data(contentsOf: url) else { return nil }
      return (try? JSONValue.parse(data))?.arrayValue
    }, timeout: config.timeout, sdkKey: config.sdkKey)
    let log = config.log
    let sendableLog: @Sendable (String) -> Void = { message in DispatchQueue.main.async { log(message) } }
    consentBox.current = defaults.string(forKey: consentKey).flatMap(Consent.init(rawValue:)) ?? config.consent
    let box = consentBox
    let queue = EventQueue(file: support.appendingPathComponent("events.jsonl"), baseUrl: config.baseUrl, app: config.app,
                           consent: { box.current }, retention: config.eventRetention,
                           headers: (config.sdkKey.map { ["Authorization": "Bearer \($0)"] } ?? [:]).merging(["X-Onlang-Install": installId]) { a, _ in a },
                           log: sendableLog)
    events = queue
    if config.backgroundUpload {
      if let uploader { uploader.use(queue) } else {
        uploader = BackgroundUploader(queue: queue, dir: support.appendingPathComponent("uploads", isDirectory: true), log: sendableLog)
      }
    }
    flush()
  }

  /// Records the user's choice (persisted). `.granted` sends what is queued; `.denied` deletes
  /// the queue and stops recording; `.pending` keeps events on the device.
  public static func setConsent(_ consent: Consent) {
    precondition(isConfigured, "call Onlang.configure() first")
    consentBox.current = consent
    UserDefaults.standard.set(consent.rawValue, forKey: consentKey)
    switch consent {
    case .denied:
      let events = self.events
      DispatchQueue.global(qos: .utility).async { events?.clear() }
    case .granted:
      flush()
    case .pending:
      break
    }
  }

  /// Sends queued events (also done after every screen and when the app goes to the background).
  public static func flush() {
    guard let events, consent == .granted else { return }
    if config.backgroundUpload, let uploader {
      uploader.upload()
    } else {
      Task.detached { await events.flush() }
    }
  }

  /// Forward `application(_:handleEventsForBackgroundURLSession:completionHandler:)` here.
  /// Returns false for sessions that aren't Onlang's.
  @discardableResult
  public static func handleEventsForBackgroundURLSession(_ identifier: String, completionHandler: @escaping () -> Void) -> Bool {
    guard identifier == BackgroundUploader.identifier else { return false }
    // Relaunched in the background: the app's launch path configures Onlang first.
    guard let uploader else {
      completionHandler()
      return true
    }
    uploader.handleEvents(completion: completionHandler)
    return true
  }

  static func queue(_ event: Event) {
    config.onEvent?(event)
    let events = self.events
    DispatchQueue.global(qos: .utility).async { events?.enqueue(event) }
  }
}
#endif
