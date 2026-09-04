import SwiftUI

@main
struct VPSGozcuApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("VPS Gözcü", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 700)
                .task {
                    model.start()
                }
        }
        .defaultSize(width: 1180, height: 780)

        MenuBarExtra("VPS Gözcü", systemImage: menuBarSymbol) {
            MenuBarView().environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbol: String {
        if model.criticalCount > 0 { return "exclamationmark.octagon.fill" }
        if model.warningCount > 0 { return "exclamationmark.triangle.fill" }
        return "server.rack"
    }
}
