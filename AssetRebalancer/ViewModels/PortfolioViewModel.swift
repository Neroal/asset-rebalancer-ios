import Foundation
import Combine

// MARK: - Portfolio ViewModel
@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var assets: [Asset] = []
    @Published var targetAllocation = TargetAllocation()
    @Published var deviationThreshold: Double = 5.0
    @Published var summary: PortfolioSummary = .empty
    @Published var rebalanceActions: [RebalanceAction] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hideAssets: Bool {
        didSet {
            UserDefaults.standard.set(hideAssets, forKey: "hide_assets")
        }
    }

    private let firestore = FirestoreService.shared

    /// Masked placeholder for hidden values
    static let maskedText = "••••••"

    init() {
        self.hideAssets = UserDefaults.standard.bool(forKey: "hide_assets")
    }

    // MARK: - Load Data

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedAssets = firestore.fetchAssets()
            async let fetchedSettings = firestore.fetchSettings()

            let (assetsResult, settingsResult) = try await (fetchedAssets, fetchedSettings)
            assets = assetsResult
            targetAllocation = settingsResult.target
            deviationThreshold = settingsResult.threshold
            errorMessage = nil

            await refreshPrices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh Prices

    func refreshPrices(force: Bool = false) async {
        isRefreshing = true
        defer { isRefreshing = false }

        let exchangeRate: Double
        do {
            exchangeRate = try await ExchangeRateService.shared.getUSDToTWD()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to fetch exchange rate"
            recalculate()
            return
        }

        var updatedAssets = assets
        var failedSymbols: [String] = []

        for i in updatedAssets.indices {
            let asset = updatedAssets[i]

            if (asset.category == .stock || asset.category == .bond), let market = asset.marketType {
                do {
                    let price = try await StockAPIService.shared.fetchPrice(
                        symbol: asset.symbol, market: market, forceRefresh: force
                    )
                    updatedAssets[i].marketPrice = price

                    switch market {
                    case .tw:
                        updatedAssets[i].marketValueTWD = price * asset.shares
                    case .us:
                        updatedAssets[i].marketValueTWD = price * asset.shares * exchangeRate
                    }
                } catch {
                    failedSymbols.append(asset.symbol)
                    // Use manual price as fallback
                    if let manual = asset.manualPrice {
                        updatedAssets[i].marketPrice = manual
                        switch market {
                        case .tw:
                            updatedAssets[i].marketValueTWD = manual * asset.shares
                        case .us:
                            updatedAssets[i].marketValueTWD = manual * asset.shares * exchangeRate
                        }
                    }
                }
            } else if asset.category == .cash {
                updatedAssets[i].marketValueTWD = asset.shares
            }
        }

        assets = updatedAssets

        if !failedSymbols.isEmpty {
            errorMessage = "Failed to fetch prices for: \(failedSymbols.joined(separator: ", "))"
        } else {
            errorMessage = nil
        }

        recalculate()
    }

    // MARK: - Recalculate

    func recalculate() {
        let s = Rebalancer.calculateSummary(
            assets: assets, target: targetAllocation, threshold: deviationThreshold
        )
        summary = s
        rebalanceActions = Rebalancer.calculateActions(
            summary: s, target: targetAllocation, threshold: deviationThreshold
        )
    }

    // MARK: - CRUD

    func addAsset(_ asset: Asset) async {
        assets.append(asset)
        recalculate()

        do {
            try await firestore.saveAsset(asset)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        await refreshPrices()
    }

    func updateAsset(_ asset: Asset) async {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        assets[index] = asset
        recalculate()

        do {
            try await firestore.saveAsset(asset)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        if asset.marketType != nil {
            await refreshPrices()
        }
    }

    func deleteAsset(_ assetID: String) async {
        assets.removeAll { $0.id == assetID }
        recalculate()

        do {
            try await firestore.deleteAsset(assetID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Target Allocation

    func saveTarget() async {
        guard targetAllocation.isValid else {
            errorMessage = "Target allocation must sum to 100%"
            return
        }

        recalculate()

        do {
            try await firestore.saveTargetAllocation(targetAllocation)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveThreshold() async {
        recalculate()
        do {
            try await firestore.saveDeviationThreshold(deviationThreshold)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Chart Data

    var chartSegments: [ChartSegment] {
        AssetCategory.allCases.compactMap { category in
            let value = summary.categoryValues[category] ?? 0
            let percentage = summary.categoryPercentages[category] ?? 0
            guard value > 0 else { return nil }
            return ChartSegment(category: category, value: value, percentage: percentage)
        }
    }
}
