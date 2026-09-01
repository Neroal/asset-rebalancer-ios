import SwiftUI
import StoreKit

struct MainTabView: View {
    @EnvironmentObject var portfolioVM: PortfolioViewModel
    @EnvironmentObject var lang: LanguageViewModel
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text(lang.tabDashboard)
                }

            AssetsView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text(lang.tabAssets)
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(lang.tabSettings)
                }
        }
        .tint(.blue)
        .task {
            await portfolioVM.loadAll()
        }
        .onChange(of: portfolioVM.shouldRequestReview) { _, newValue in
            if newValue {
                requestReview()
            }
        }
    }
}
