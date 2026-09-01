import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var portfolioVM: PortfolioViewModel
    @EnvironmentObject var lang: LanguageViewModel

    private var hidden: Bool { portfolioVM.hideAssets }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Total Assets Card
                    totalAssetsCard

                    // Pie Chart
                    if !portfolioVM.chartSegments.isEmpty {
                        pieChartSection
                    }

                    // Rebalance Status
                    rebalanceStatusCard

                    // Deviation Cards
                    deviationSection

                    // Rebalance Suggestions
                    if portfolioVM.summary.needsRebalance {
                        rebalanceSuggestionsSection
                    }
                }
                .padding()
            }
            .refreshable {
                await portfolioVM.refreshPrices(force: true)
            }
            .navigationTitle(lang.tabDashboard)
            .overlay {
                if portfolioVM.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Total Assets Card

    private var totalAssetsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Text(lang.totalAssets)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        portfolioVM.hideAssets.toggle()
                    }
                } label: {
                    Image(systemName: hidden ? "eye.slash" : "eye")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(hidden
                 ? "NT$ \(PortfolioViewModel.maskedText)"
                 : Rebalancer.formatCurrency(portfolioVM.summary.totalValueTWD))
                .font(.system(size: 36, weight: .bold, design: .rounded))

            if portfolioVM.isRefreshing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(lang.pullToRefresh)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Pie Chart

    private var pieChartSection: some View {
        VStack(spacing: 16) {
            Text(lang.currentAllocation)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            PieChartView(
                segments: portfolioVM.chartSegments,
                centerText: hidden
                    ? "NT$ \(PortfolioViewModel.maskedText)"
                    : Rebalancer.formatCurrency(portfolioVM.summary.totalValueTWD)
            )
            .frame(height: 220)

            // Legend
            HStack(spacing: 24) {
                ForEach(AssetCategory.allCases) { category in
                    let percentage = portfolioVM.summary.categoryPercentages[category] ?? 0
                    let name = lang.localized(category.displayName)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(category.swiftUIColor)
                            .frame(width: 10, height: 10)
                        Text("\(name) \(Rebalancer.formatPercentage(percentage))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Rebalance Status

    private var rebalanceStatusCard: some View {
        HStack {
            Image(systemName: portfolioVM.summary.needsRebalance
                  ? "exclamationmark.triangle.fill"
                  : "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(portfolioVM.summary.needsRebalance ? .orange : .green)

            Text(portfolioVM.summary.needsRebalance
                 ? lang.rebalanceNeeded
                 : lang.balanced)
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(
            (portfolioVM.summary.needsRebalance ? Color.orange : Color.green)
                .opacity(0.1)
        )
        .cornerRadius(12)
    }

    // MARK: - Deviation Section

    private var deviationSection: some View {
        VStack(spacing: 12) {
            Text("\(lang.currentAllocation) vs \(lang.targetAllocation)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(AssetCategory.allCases) { category in
                DeviationRow(
                    category: category,
                    current: portfolioVM.summary.categoryPercentages[category] ?? 0,
                    target: portfolioVM.targetAllocation.percentage(for: category),
                    deviation: portfolioVM.summary.deviations[category] ?? 0,
                    threshold: portfolioVM.deviationThreshold,
                    language: lang.language
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Rebalance Suggestions

    private var rebalanceSuggestionsSection: some View {
        VStack(spacing: 12) {
            Text(lang.rebalanceSuggestions)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(portfolioVM.rebalanceActions) { action in
                if action.action != .hold {
                    HStack {
                        Circle()
                            .fill(action.category.swiftUIColor)
                            .frame(width: 10, height: 10)

                        Text(lang.localized(action.category.displayName))
                            .font(.subheadline)

                        Spacer()

                        Text(action.action == .buy ? lang.buy : lang.sell)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(action.action == .buy ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (action.action == .buy ? Color.green : Color.red)
                                    .opacity(0.15)
                            )
                            .cornerRadius(6)

                        Text(hidden
                             ? "NT$ \(PortfolioViewModel.maskedText)"
                             : Rebalancer.formatCurrency(action.amountTWD))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

}
