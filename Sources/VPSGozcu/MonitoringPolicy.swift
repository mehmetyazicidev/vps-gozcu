import Foundation

enum MonitoringPolicy {
    static func validInterval(_ interval: TimeInterval) -> TimeInterval {
        [30.0, 60.0, 300.0].contains(interval) ? interval : 300
    }

    static func isFresh(_ capturedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(capturedAt)
        return age >= -60 && age <= 360
    }

    static func accepts(_ profile: ServerProfile, currentProfiles: [ServerProfile]) -> Bool {
        profile.isEnabled && currentProfiles.contains(profile)
    }
}
