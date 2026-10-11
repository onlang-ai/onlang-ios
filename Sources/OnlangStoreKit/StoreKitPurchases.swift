#if canImport(UIKit)
import Foundation
import OnlangCore
import OnlangKit
import StoreKit
import UIKit

/// StoreKit 2 (auto-renewable subscriptions) for Onlang. Registry product ids map to App Store
/// product ids through `productIds` (identity by default). Verified transactions are finished;
/// pass `finishTransactions: false` when your backend finishes them after validation. Purchases
/// carry the install id as their `appAccountToken`, which is how App Store Server Notifications
/// are attributed to the experiment that showed the paywall.
///
/// ```
/// let storeKit = StoreKitPurchases()
/// Onlang.configure(config, registry: registry, purchases: storeKit, store: storeKit)
/// ```
public final class StoreKitPurchases: PurchaseHandler, StoreProvider {
  private let productIds: [String: String]
  private let finishTransactions: Bool
  private let formatPeriod: (Product.SubscriptionPeriod) -> String
  private let installId: () -> String
  private let lock = NSLock()
  private var cache: [String: Product] = [:]

  public init(productIds: [String: String] = [:], finishTransactions: Bool = true,
              formatPeriod: @escaping (Product.SubscriptionPeriod) -> String = StoreKitPurchases.englishPeriod,
              installId: @escaping () -> String = { Onlang.installId }) {
    self.productIds = productIds
    self.finishTransactions = finishTransactions
    self.formatPeriod = formatPeriod
    self.installId = installId
  }

  /// `appAccountToken` = the install id (a UUID); none before `Onlang.configure`.
  static func purchaseOptions(installId: String) -> Set<Product.PurchaseOption> {
    UUID(uuidString: installId).map { [.appAccountToken($0)] } ?? []
  }

  private func storeId(_ product: String) -> String { productIds[product] ?? product }

  private func cached(_ id: String) -> Product? {
    lock.lock()
    defer { lock.unlock() }
    return cache[id]
  }

  private func remember(_ products: [Product]) {
    lock.lock()
    defer { lock.unlock() }
    for p in products { cache[p.id] = p }
  }

  public func storeValues(products: [String]) async -> StoreValues {
    let loaded = (try? await Product.products(for: products.map(storeId))) ?? []
    remember(loaded)
    let byId = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    var price: [String: String] = [:], period: [String: String] = [:], trial: [String: String] = [:]
    for product in products {
      guard let p = byId[storeId(product)] else { continue }
      price[product] = p.displayPrice
      if let sub = p.subscription {
        period[product] = formatPeriod(sub.subscriptionPeriod)
        if let intro = sub.introductoryOffer, intro.paymentMode == .freeTrial { trial[product] = formatPeriod(intro.period) }
      }
    }
    return ["price": price, "period": period, "trial": trial]
  }

  public func purchase(product: String, from _: UIViewController?, completion: @escaping (PurchaseOutcome) -> Void) {
    let id = storeId(product)
    Task {
      var found = cached(id)
      if found == nil {
        let loaded = (try? await Product.products(for: [id])) ?? []
        remember(loaded)
        found = loaded.first
      }
      guard let product = found else { return completion(.failed) }
      do {
        switch try await product.purchase(options: Self.purchaseOptions(installId: installId())) {
        case let .success(verification):
          guard case let .verified(transaction) = verification else { return completion(.failed) }
          if finishTransactions { await transaction.finish() }
          completion(.purchased)
        case .userCancelled:
          completion(.cancelled)
        case .pending:
          completion(.pending)
        @unknown default:
          completion(.failed)
        }
      } catch {
        completion(.failed)
      }
    }
  }

  public func restore(from _: UIViewController?, completion: @escaping (Bool) -> Void) {
    Task {
      // Entitlements already on the device need no App Store sign-in; sync (which may prompt
      // for the Apple ID) only when there are none.
      if await Self.hasEntitlement() { return completion(true) }
      try? await AppStore.sync()
      completion(await Self.hasEntitlement())
    }
  }

  private static func hasEntitlement() async -> Bool {
    for await entitlement in Transaction.currentEntitlements {
      if case let .verified(t) = entitlement, t.revocationDate == nil { return true }
    }
    return false
  }

  /// One year → "year", 3 months → "3 months", 7 days → "7 days". Localize with your own formatter.
  public static func englishPeriod(_ period: Product.SubscriptionPeriod) -> String {
    let unit: String
    switch period.unit {
    case .day: unit = "day"
    case .week: unit = "week"
    case .month: unit = "month"
    case .year: unit = "year"
    @unknown default: unit = "period"
    }
    return period.value == 1 ? unit : "\(period.value) \(unit)s"
  }
}
#endif
