import SwiftUI

struct ContentView: View {
    @StateObject private var store = MeasurementStore()
    @StateObject private var locationContext = LocationContext()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            MeterView()
                .tabItem {
                    Label("メーター", systemImage: "gauge.with.dots.needle.50percent")
                }
            TankView()
                .tabItem {
                    Label("水槽", systemImage: "drop.fill")
                }
            HistoryTab()
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
        }
        .environmentObject(store)
        .environmentObject(locationContext)
        .onAppear {
            if locationContext.location == nil {
                locationContext.refresh()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // フォアグラウンド復帰時、未取得 or 1時間以上経過していれば再取得
                if locationContext.location == nil || locationContext.isStale {
                    locationContext.refresh()
                }
            }
        }
    }
}

private struct HistoryTab: View {
    @EnvironmentObject var store: MeasurementStore
    var body: some View {
        NavigationStack {
            HistoryView(store: store)
        }
    }
}

#Preview {
    ContentView()
}
