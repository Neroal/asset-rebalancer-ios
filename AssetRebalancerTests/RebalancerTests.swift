import Testing
import Foundation

// The test target compiles Rebalancer.swift, Asset.swift, and Portfolio.swift
// directly (no app host), so tests run without launching the app or Firebase.

// MARK: - Helpers

private func makeAsset(
    category: AssetCategory,
    symbol: String = "TEST",
    shares: Double = 0,
    marketType: MarketType? = nil,
    manualPrice: Double? = nil,
    marketPrice: Double? = nil,
    marketValueTWD: Double? = nil
) -> Asset {
    var asset = Asset(
        category: category,
        symbol: symbol,
        shares: shares,
        manualPrice: manualPrice,
        marketType: marketType
    )
    asset.marketPrice = marketPrice
    asset.marketValueTWD = marketValueTWD
    return asset
}

private func approxEqual(_ a: Double, _ b: Double, epsilon: Double = 0.0001) -> Bool {
    abs(a - b) < epsilon
}

// MARK: - calculateSummary

@Suite struct CalculateSummaryTests {

    @Test func cashUsesSharesAsTWDAmount() {
        let assets = [makeAsset(category: .cash, shares: 50_000)]
        let summary = Rebalancer.calculateSummary(assets: assets, target: TargetAllocation())

        #expect(approxEqual(summary.totalValueTWD, 50_000))
        #expect(approxEqual(summary.categoryValues[.cash] ?? 0, 50_000))
    }

    @Test func usesMarketValueTWDWhenPresent() {
        let assets = [
            makeAsset(category: .stock, marketType: .tw, marketValueTWD: 600_000),
            makeAsset(category: .bond, marketType: .us, marketValueTWD: 300_000),
            makeAsset(category: .cash, shares: 100_000),
        ]
        let summary = Rebalancer.calculateSummary(assets: assets, target: TargetAllocation())

        #expect(approxEqual(summary.totalValueTWD, 1_000_000))
        #expect(approxEqual(summary.categoryValues[.stock] ?? 0, 600_000))
        #expect(approxEqual(summary.categoryValues[.bond] ?? 0, 300_000))
        #expect(approxEqual(summary.categoryValues[.cash] ?? 0, 100_000))
    }

    @Test func usStockWithoutTWDValueCountsAsZero() {
        // displayValue would be in USD; it must not leak into the TWD total
        let assets = [
            makeAsset(category: .stock, shares: 10, marketType: .us, marketPrice: 500),
            makeAsset(category: .cash, shares: 100_000),
        ]
        let summary = Rebalancer.calculateSummary(assets: assets, target: TargetAllocation())

        #expect(approxEqual(summary.categoryValues[.stock] ?? 0, 0))
        #expect(approxEqual(summary.totalValueTWD, 100_000))
    }

    @Test func twStockWithoutTWDValueFallsBackToDisplayValue() {
        let assets = [
            makeAsset(category: .stock, shares: 1000, marketType: .tw, marketPrice: 100)
        ]
        let summary = Rebalancer.calculateSummary(assets: assets, target: TargetAllocation())

        #expect(approxEqual(summary.categoryValues[.stock] ?? 0, 100_000))
    }

    @Test func percentagesAndDeviations() {
        let assets = [
            makeAsset(category: .stock, marketValueTWD: 700_000),
            makeAsset(category: .bond, marketValueTWD: 200_000),
            makeAsset(category: .cash, shares: 100_000),
        ]
        // target 60/30/10 → actual 70/20/10 → deviations +10/-10/0
        let summary = Rebalancer.calculateSummary(assets: assets, target: TargetAllocation())

        #expect(approxEqual(summary.categoryPercentages[.stock] ?? 0, 70))
        #expect(approxEqual(summary.categoryPercentages[.bond] ?? 0, 20))
        #expect(approxEqual(summary.categoryPercentages[.cash] ?? 0, 10))
        #expect(approxEqual(summary.deviations[.stock] ?? 0, 10))
        #expect(approxEqual(summary.deviations[.bond] ?? 0, -10))
        #expect(approxEqual(summary.deviations[.cash] ?? 0, 0))
        #expect(summary.needsRebalance)
    }

    @Test func deviationExactlyAtThresholdDoesNotNeedRebalance() {
        let assets = [
            makeAsset(category: .stock, marketValueTWD: 650_000),
            makeAsset(category: .bond, marketValueTWD: 250_000),
            makeAsset(category: .cash, shares: 100_000),
        ]
        // deviations +5/-5/0 with threshold 5 → strictly greater is required
        let summary = Rebalancer.calculateSummary(
            assets: assets, target: TargetAllocation(), threshold: 5
        )

        #expect(!summary.needsRebalance)
    }

    @Test func deviationJustAboveThresholdNeedsRebalance() {
        let assets = [
            makeAsset(category: .stock, marketValueTWD: 651_000),
            makeAsset(category: .bond, marketValueTWD: 249_000),
            makeAsset(category: .cash, shares: 100_000),
        ]
        let summary = Rebalancer.calculateSummary(
            assets: assets, target: TargetAllocation(), threshold: 5
        )

        #expect(summary.needsRebalance)
    }

    @Test func emptyPortfolioHasZeroTotals() {
        let summary = Rebalancer.calculateSummary(assets: [], target: TargetAllocation())

        #expect(approxEqual(summary.totalValueTWD, 0))
        #expect(approxEqual(summary.categoryPercentages[.stock] ?? -1, 0))
        // Documents current behavior: with no assets every deviation equals
        // -target, so an empty portfolio reports needsRebalance == true
        // (calculateActions still returns [] because total is 0).
        #expect(summary.needsRebalance)
    }
}

// MARK: - calculateActions

@Suite struct CalculateActionsTests {

    private func summary(stock: Double, bond: Double, cash: Double,
                         threshold: Double = 5) -> PortfolioSummary {
        let assets = [
            makeAsset(category: .stock, marketValueTWD: stock),
            makeAsset(category: .bond, marketValueTWD: bond),
            makeAsset(category: .cash, shares: cash),
        ]
        return Rebalancer.calculateSummary(
            assets: assets, target: TargetAllocation(), threshold: threshold
        )
    }

    @Test func zeroTotalReturnsNoActions() {
        let actions = Rebalancer.calculateActions(
            summary: .empty, target: TargetAllocation()
        )
        #expect(actions.isEmpty)
    }

    @Test func balancedPortfolioHoldsEverything() {
        let s = summary(stock: 600_000, bond: 300_000, cash: 100_000)
        let actions = Rebalancer.calculateActions(summary: s, target: TargetAllocation())

        #expect(actions.count == 3)
        #expect(actions.allSatisfy { $0.action == .hold })
        #expect(actions.allSatisfy { approxEqual($0.amountTWD, 0) })
    }

    @Test func overweightCategorySellsByDeviationAmount() {
        // stock 70% vs target 60% → sell 10% of 1,000,000 = 100,000
        let s = summary(stock: 700_000, bond: 200_000, cash: 100_000)
        let actions = Rebalancer.calculateActions(summary: s, target: TargetAllocation())

        let stockAction = actions.first { $0.category == .stock }
        #expect(stockAction?.action == .sell)
        #expect(approxEqual(stockAction?.amountTWD ?? 0, 100_000))
    }

    @Test func underweightCategoryBuysByDeviationAmount() {
        // bond 20% vs target 30% → buy 10% of 1,000,000 = 100,000
        let s = summary(stock: 700_000, bond: 200_000, cash: 100_000)
        let actions = Rebalancer.calculateActions(summary: s, target: TargetAllocation())

        let bondAction = actions.first { $0.category == .bond }
        #expect(bondAction?.action == .buy)
        #expect(approxEqual(bondAction?.amountTWD ?? 0, 100_000))
    }

    @Test func deviationExactlyAtThresholdEmitsAction() {
        // Documents current behavior: calculateActions uses abs(dev) < threshold
        // for hold, so a deviation of exactly the threshold produces a buy/sell —
        // while needsRebalance (strictly >) stays false for the same portfolio.
        let s = summary(stock: 650_000, bond: 250_000, cash: 100_000)
        let actions = Rebalancer.calculateActions(
            summary: s, target: TargetAllocation(), threshold: 5
        )

        let stockAction = actions.first { $0.category == .stock }
        #expect(stockAction?.action == .sell)
    }
}

// MARK: - Formatting

@Suite struct FormattingTests {

    @Test func formatCurrencyGroupsThousands() {
        #expect(Rebalancer.formatCurrency(1_234_567) == "NT$1,234,567")
    }

    @Test func formatCurrencyZero() {
        #expect(Rebalancer.formatCurrency(0) == "NT$0")
    }

    @Test func formatCurrencyRoundsToInteger() {
        #expect(Rebalancer.formatCurrency(999_999.6) == "NT$1,000,000")
    }

    @Test func formatCurrencyCustomSymbol() {
        #expect(Rebalancer.formatCurrency(100, symbol: "$") == "$100")
    }

    @Test func formatPercentageOneDecimal() {
        #expect(Rebalancer.formatPercentage(12.34) == "12.3%")
        #expect(Rebalancer.formatPercentage(0) == "0.0%")
    }
}

// MARK: - TargetAllocation & Templates

@Suite struct AllocationTests {

    @Test func defaultAllocationIsValid() {
        #expect(TargetAllocation().isValid)
    }

    @Test func allocationNotSummingTo100IsInvalid() {
        #expect(!TargetAllocation(stock: 50, bond: 30, cash: 10).isValid)
    }

    @Test func allTemplatesSumTo100() {
        for template in AllocationTemplate.allCases {
            #expect(template.allocation.isValid)
        }
    }

    @Test func matchesIdentifiesCurrentTemplate() {
        let target = TargetAllocation(stock: 60, bond: 30, cash: 10)
        #expect(AllocationTemplate.balanced.matches(target))
        #expect(!AllocationTemplate.aggressive.matches(target))
        #expect(!AllocationTemplate.conservative.matches(target))
    }
}
