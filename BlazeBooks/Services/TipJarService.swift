import Foundation
import Observation
import StoreKit

/// Manages a single non-consumable "Show Support" in-app purchase.
///
/// Follows the same `@Observable` + environment injection pattern as `SyncMonitorService`.
/// StoreKit 2's `Transaction.currentEntitlements` handles persistence across launches/devices
/// — no SwiftData storage needed.
///
/// Usage:
/// - Create an instance and inject via `.environment(tipJar)`
/// - Call `start()` from a `.task` modifier
/// - Read `hasPurchased` in views for gold star visibility
@MainActor
@Observable
final class TipJarService {
    static let productID = "BlazeBooksSupportStar"

    /// Whether the user has purchased the tip. Drives gold star visibility.
    var hasPurchased: Bool = false

    /// The loaded product from the App Store. Provides `displayPrice`.
    var product: Product?

    /// True while a purchase is in progress.
    var isPurchasing: Bool = false

    /// True if the product could not be loaded from the App Store.
    var loadFailed: Bool = false

    @ObservationIgnored
    private nonisolated(unsafe) var updateTask: Task<Void, Never>?

    /// Load product, check existing entitlements, and listen for transaction updates.
    func start() {
        Task {
            // Load the product
            do {
                let products = try await Product.products(for: [Self.productID])
                if let loaded = products.first {
                    product = loaded
                } else {
                    loadFailed = true
                }
            } catch {
                loadFailed = true
            }

            // Check existing entitlements
            for await result in Transaction.currentEntitlements {
                if case .verified(let tx) = result, tx.productID == Self.productID {
                    hasPurchased = true
                    break
                }
            }
        }

        // Listen for transaction updates (purchases from other devices, restores)
        updateTask = Task {
            for await result in Transaction.updates {
                if case .verified(let tx) = result, tx.productID == Self.productID {
                    hasPurchased = true
                    await tx.finish()
                }
            }
        }
    }

    /// Purchase the support product.
    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let tx) = verification {
                hasPurchased = true
                await tx.finish()
            }
        } catch {
            // User cancelled or purchase failed — no action needed
        }
    }

    /// Restores previous purchases by syncing with the App Store.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                if case .verified(let tx) = result, tx.productID == Self.productID {
                    hasPurchased = true
                    break
                }
            }
        } catch {
            // Sync failed — no action needed
        }
    }

    deinit {
        updateTask?.cancel()
    }
}
