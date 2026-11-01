import SwiftUI

struct ContentView: View {
    enum AppTab: Hashable {
        case calculator
        case history
        case settings
    }

    @StateObject private var viewModel = TradeViewModel()
    @State private var selectedTab: AppTab = .calculator

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CalculatorView()
            }
            .tabItem {
                Label("计算器", systemImage: "plus.forwardslash.minus")
            }
            .tag(AppTab.calculator)

            NavigationStack {
                HistoryView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("历史", systemImage: "clock.arrow.2.circlepath")
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
        .environmentObject(viewModel)
        .preferredColorScheme(viewModel.effectiveColorScheme)
        .environment(\.locale, viewModel.effectiveLocale)
        .tabViewStyle(.sidebarAdaptable)
    }
}
