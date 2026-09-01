import Foundation

// MARK: - Stock API Service
actor StockAPIService {
    static let shared = StockAPIService()

    private var cache: [String: (price: Double, timestamp: Date)] = [:]
    private var exchangeCache: [String: String] = [:]
    private let defaultCacheDuration: TimeInterval = 3600 // 1 hour
    private let intradayCacheDuration: TimeInterval = 60 // 1 minute while TW market is open

    // MARK: - Fetch Price

    func fetchPrice(symbol: String, market: MarketType, forceRefresh: Bool = false) async throws -> Double {
        let cacheKey = "\(market.rawValue):\(symbol)"

        // Check cache (skipped when the user explicitly pulls to refresh)
        if !forceRefresh,
           let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheDuration(for: market) {
            return cached.price
        }

        let price: Double
        switch market {
        case .tw:
            price = try await fetchTWStockPrice(symbol: symbol)
        case .us:
            price = try await fetchUSStockPrice(symbol: symbol)
        }

        cache[cacheKey] = (price, Date())
        return price
    }

    // MARK: - Cache Duration

    private func cacheDuration(for market: MarketType) -> TimeInterval {
        (market == .tw && isTWMarketOpen()) ? intradayCacheDuration : defaultCacheDuration
    }

    /// TW market hours: Mon–Fri 09:00–13:45 Asia/Taipei (buffer past the 13:30
    /// close so the final auction price settles). Holidays are not special-cased —
    /// a false positive only shortens the cache, returning the same closed price.
    private func isTWMarketOpen(now: Date = Date()) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        guard let taipei = TimeZone(identifier: "Asia/Taipei") else { return false }
        calendar.timeZone = taipei

        let weekday = calendar.component(.weekday, from: now)
        guard (2...6).contains(weekday) else { return false }

        let minutes = calendar.component(.hour, from: now) * 60
                    + calendar.component(.minute, from: now)
        return minutes >= 9 * 60 && minutes <= 13 * 60 + 45
    }

    // MARK: - Taiwan Stocks (TWSE + TPEx auto-detect)

    private func fetchTWStockPrice(symbol: String) async throws -> Double {
        // Use cached exchange type if available
        if let exchange = exchangeCache[symbol],
           let price = try? await fetchRealtimePrice(symbol: symbol, exchange: exchange) {
            return price
        }

        // Try TSE realtime
        if let price = try? await fetchRealtimePrice(symbol: symbol, exchange: "tse") {
            exchangeCache[symbol] = "tse"
            return price
        }

        // Try OTC realtime
        if let price = try? await fetchRealtimePrice(symbol: symbol, exchange: "otc") {
            exchangeCache[symbol] = "otc"
            return price
        }

        throw StockAPIError.noData
    }

    private func fetchRealtimePrice(symbol: String, exchange: String) async throws -> Double {
        let urlString = "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=\(exchange)_\(symbol).tw"
        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msgArray = json["msgArray"] as? [[String: Any]],
              let first = msgArray.first else {
            throw StockAPIError.noData
        }

        // z = current price (trading hours), y = previous close (fallback)
        let priceStr = (first["z"] as? String).flatMap { $0 != "-" ? $0 : nil }
                    ?? (first["y"] as? String)
        guard let priceStr, let price = Double(priceStr) else {
            throw StockAPIError.noData
        }

        return price
    }

    // MARK: - Yahoo Finance (US Stocks)

    private func fetchUSStockPrice(symbol: String) async throws -> Double {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d"
        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let first = results.first,
              let meta = first["meta"] as? [String: Any],
              let price = meta["regularMarketPrice"] as? Double else {
            throw StockAPIError.parseError
        }

        return price
    }

    // MARK: - Clear Cache

    func clearCache() {
        cache.removeAll()
        exchangeCache.removeAll()
    }
}

// MARK: - Errors
enum StockAPIError: LocalizedError {
    case invalidURL
    case parseError
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .parseError: return "Failed to parse stock data"
        case .noData: return "No stock data available"
        }
    }
}
