import Foundation
import SwiftUI

// MARK: - Asset Category
enum AssetCategory: String, Codable, CaseIterable, Identifiable {
    case stock = "stock"
    case bond = "bond"
    case cash = "cash"

    var id: String { rawValue }

    var displayName: (zh: String, en: String) {
        switch self {
        case .stock: return ("股票", "Stocks")
        case .bond: return ("債券", "Bonds")
        case .cash: return ("現金", "Cash")
        }
    }

    var color: String {
        switch self {
        case .stock: return "StockColor"
        case .bond: return "BondColor"
        case .cash: return "CashColor"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .stock: return .blue
        case .bond: return .green
        case .cash: return .orange
        }
    }
}

// MARK: - Market Type
enum MarketType: String, Codable, CaseIterable {
    case tw = "TW"
    case us = "US"

    var displayName: (zh: String, en: String) {
        switch self {
        case .tw: return ("台股", "TW Stock")
        case .us: return ("美股", "US Stock")
        }
    }
}

// MARK: - Asset Model
struct Asset: Identifiable, Codable {
    var id: String
    var category: AssetCategory
    var symbol: String              // Stock symbol or custom name
    var name: String                // Display name
    var shares: Double              // Number of shares (0 for cash/bond amounts)
    var manualPrice: Double?        // Manual price override
    var marketType: MarketType?     // TW or US (for stocks)
    var marketPrice: Double?        // Fetched market price
    var marketValueTWD: Double?     // Calculated value in TWD

    // displayValue is TWD-correct only for TW stocks and cash.
    // For US stocks use marketValueTWD (which includes exchange rate).
    var displayValue: Double {
        if category == .cash {
            return shares
        }
        if let price = marketPrice ?? manualPrice {
            return shares * price
        }
        return 0
    }

    init(id: String = UUID().uuidString,
         category: AssetCategory,
         symbol: String,
         name: String = "",
         shares: Double,
         manualPrice: Double? = nil,
         marketType: MarketType? = nil) {
        self.id = id
        self.category = category
        self.symbol = symbol
        self.name = name.isEmpty ? symbol : name
        self.shares = shares
        self.manualPrice = manualPrice
        self.marketType = marketType
        self.marketPrice = nil
        self.marketValueTWD = nil
    }
}

// MARK: - Target Allocation
struct TargetAllocation: Codable {
    var stock: Double = 60.0
    var bond: Double = 30.0
    var cash: Double = 10.0

    func percentage(for category: AssetCategory) -> Double {
        switch category {
        case .stock: return stock
        case .bond: return bond
        case .cash: return cash
        }
    }

    mutating func setPercentage(_ value: Double, for category: AssetCategory) {
        switch category {
        case .stock: stock = value
        case .bond: bond = value
        case .cash: cash = value
        }
    }

    var isValid: Bool {
        abs(stock + bond + cash - 100.0) < 0.01
    }
}

// MARK: - Allocation Template
enum AllocationTemplate: CaseIterable, Identifiable {
    case aggressive
    case balanced
    case conservative

    var id: Self { self }

    var displayName: (zh: String, en: String) {
        switch self {
        case .aggressive: return ("積極型", "Aggressive")
        case .balanced: return ("穩健型", "Balanced")
        case .conservative: return ("保守型", "Conservative")
        }
    }

    var allocation: TargetAllocation {
        switch self {
        case .aggressive: return TargetAllocation(stock: 80, bond: 15, cash: 5)
        case .balanced: return TargetAllocation(stock: 60, bond: 30, cash: 10)
        case .conservative: return TargetAllocation(stock: 40, bond: 40, cash: 20)
        }
    }

    /// Whether the given target matches this template's ratios
    func matches(_ target: TargetAllocation) -> Bool {
        abs(target.stock - allocation.stock) < 0.01 &&
        abs(target.bond - allocation.bond) < 0.01 &&
        abs(target.cash - allocation.cash) < 0.01
    }
}
