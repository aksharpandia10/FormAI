import Foundation
import RevenueCat

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    #if DEBUG
    @Published var isSubscribed = false
    #else
    @Published var isSubscribed = false
    #endif
    @Published var isLoading = false
    @Published var offerings: Offerings?

    private let entitlementID = "Form AI Pro"

    private init() {}

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: "appl_eblRGQMrjQSODsnGBzRmYNjIocs")
        Task {
            #if !DEBUG
            await checkEntitlement()
            #endif
            await fetchOfferings()
        }
        #if !DEBUG
        Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                isSubscribed = customerInfo.entitlements[entitlementID]?.isActive == true
            }
        }
        #endif
    }

    func checkEntitlement() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            #if !DEBUG
            isSubscribed = info.entitlements[entitlementID]?.isActive == true
            #endif
        } catch {
            print("[RC] entitlement check failed: \(error)")
        }
    }

    func fetchOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            print("[RC] offerings fetch failed: \(error)")
        }
    }

    func purchaseYearly() async throws -> Bool {
        guard let package = offerings?.current?.annual else { throw SubscriptionError.packageNotFound }
        return try await purchase(package)
    }

    func purchaseMonthly() async throws -> Bool {
        guard let package = offerings?.current?.monthly else { throw SubscriptionError.packageNotFound }
        return try await purchase(package)
    }

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        isSubscribed = info.entitlements[entitlementID]?.isActive == true
    }

    // MARK: - Display prices (fall back to hardcoded until offerings load)

    var yearlyDisplayPrice: String  { offerings?.current?.annual?.localizedPriceString ?? "$39.99" }
    var monthlyDisplayPrice: String { offerings?.current?.monthly?.localizedPriceString ?? "$9.99" }

    // MARK: - Private

    private func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        isSubscribed = result.customerInfo.entitlements[entitlementID]?.isActive == true
        if isSubscribed {
            let plan = package.packageType == .annual ? "yearly" : "monthly"
            AnalyticsService.subscriptionPurchased(plan: plan)
        }
        return isSubscribed
    }

    enum SubscriptionError: LocalizedError {
        case packageNotFound
        var errorDescription: String? { "Subscription package not found. Please try again." }
    }
}
