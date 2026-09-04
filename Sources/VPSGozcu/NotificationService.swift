import Foundation
import UserNotifications

struct NotificationService: Sendable {
    func requestAuthorization() async {
        guard isAppBundle else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func notifyCritical(server: ServerProfile, snapshot: ServerSnapshot) async {
        guard isAppBundle else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(server.name) kritik durumda"
        content.body = snapshot.summary
        content.sound = .default
        let request = UNNotificationRequest(identifier: "critical-\(server.id.uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }
}
