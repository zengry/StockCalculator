import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TradeViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CalculatorView()
                .tabItem {
                    Label("Calculator", systemImage: "yensign.circle.fill")
                }
                .tag(0)

            HistoryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .environmentObject(viewModel)
        // 外观（浅色/深色/跟随系统）与语言覆盖
        .preferredColorScheme(viewModel.effectiveColorScheme)
        .environment(\.locale, viewModel.effectiveLocale)
        // iPad 上自动切换为侧边栏标签样式，iPhone 保持标签栏
        .tabViewStyle(.sidebarAdaptable)
    }
}
