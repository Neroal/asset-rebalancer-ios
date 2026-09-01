import SwiftUI

struct AssetsView: View {
    @EnvironmentObject var portfolioVM: PortfolioViewModel
    @EnvironmentObject var lang: LanguageViewModel
    @State private var showAddSheet = false
    @State private var editingAsset: Asset?
    @State private var assetToDelete: Asset?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(AssetCategory.allCases) { category in
                    let categoryAssets = portfolioVM.assets.filter { $0.category == category }
                    if !categoryAssets.isEmpty {
                        Section {
                            ForEach(categoryAssets) { asset in
                                AssetRowView(asset: asset, hideAssets: portfolioVM.hideAssets)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingAsset = asset
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            assetToDelete = asset
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label(lang.delete, systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack {
                                Text(lang.localized(category.displayName))
                                Spacer()
                                let subtotal = categoryAssets.reduce(0) {
                                    $0 + ($1.marketValueTWD ?? $1.displayValue)
                                }
                                Text(portfolioVM.hideAssets
                                     ? "NT$ \(PortfolioViewModel.maskedText)"
                                     : Rebalancer.formatCurrency(subtotal))
                                    .font(.caption)
                            }
                        }
                    }
                }

                if portfolioVM.assets.isEmpty && !portfolioVM.isLoading {
                    ContentUnavailableView {
                        Label(lang.addAsset, systemImage: "plus.circle")
                    } description: {
                        Text(lang.emptyAssetHint)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showAddSheet = true
                    }
                }
            }
            .navigationTitle(lang.tabAssets)
            .alert(lang.deleteConfirmTitle, isPresented: $showDeleteConfirmation) {
                Button(lang.cancel, role: .cancel) {
                    assetToDelete = nil
                }
                Button(lang.delete, role: .destructive) {
                    if let asset = assetToDelete {
                        Task {
                            await portfolioVM.deleteAsset(asset.id)
                        }
                        assetToDelete = nil
                    }
                }
            } message: {
                Text(lang.deleteConfirmMessage)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAssetView()
            }
            .sheet(item: $editingAsset) { asset in
                EditAssetView(asset: asset)
            }
            .refreshable {
                await portfolioVM.refreshPrices(force: true)
            }
        }
    }
}
