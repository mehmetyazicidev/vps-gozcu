import Foundation

struct MaintenancePlan: Sendable {
    let targetName: String
    let sshTarget: String
    let packageCount: Int
    let securityPackageCount: Int
    let rebootRequired: Bool
    let requiresMaintenance: Bool
    let blockers: [String]

    var isReady: Bool { blockers.isEmpty }
}

enum MaintenancePlanner {
    static func make(
        profile: ServerProfile,
        snapshot: ServerSnapshot,
        now: Date = .now
    ) -> MaintenancePlan {
        let packageCount = snapshot.updatesTotal ?? 0
        let securityPackageCount = snapshot.securityUpdates ?? 0
        let rebootRequired = snapshot.rebootRequired ?? false
        let requiresMaintenance = packageCount > 0 || rebootRequired
        var blockers: [String] = []

        guard requiresMaintenance else {
            return MaintenancePlan(
                targetName: profile.name,
                sshTarget: profile.sshTarget,
                packageCount: packageCount,
                securityPackageCount: securityPackageCount,
                rebootRequired: rebootRequired,
                requiresMaintenance: false,
                blockers: []
            )
        }

        if snapshot.health == .critical {
            blockers.append("Sunucu kritik durumda; önce mevcut arıza giderilmeli")
        }
        if snapshot.health == .unknown {
            blockers.append("Sunucu sağlık durumu belirsiz; önce yeni tarama yapılmalı")
        }
        if snapshot.updatesTotal == nil {
            blockers.append("Paket durumu okunamadı")
        }
        if snapshot.rebootRequired == nil {
            blockers.append("Reboot gereksinimi okunamadı")
        }
        if profile.fullBackupRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append("Full yedek yolu yapılandırılmamış")
        } else {
            appendBackupBlocker(
                &blockers,
                title: "Full yedek",
                date: snapshot.latestFullBackupDate,
                now: now,
                maxAgeHours: profile.thresholds?.backupWarningHours ?? MonitoringThresholds.default.backupWarningHours
            )
        }
        if profile.dataBackupRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append("Veri yedeği yolu yapılandırılmamış")
        } else {
            appendBackupBlocker(
                &blockers,
                title: "Veri yedeği",
                date: snapshot.latestDataBackupDate,
                now: now,
                maxAgeHours: profile.thresholds?.backupWarningHours ?? MonitoringThresholds.default.backupWarningHours
            )
        }

        return MaintenancePlan(
            targetName: profile.name,
            sshTarget: profile.sshTarget,
            packageCount: packageCount,
            securityPackageCount: securityPackageCount,
            rebootRequired: rebootRequired,
            requiresMaintenance: true,
            blockers: blockers
        )
    }

    private static func appendBackupBlocker(
        _ blockers: inout [String],
        title: String,
        date: Date?,
        now: Date,
        maxAgeHours: Double
    ) {
        guard let date else {
            blockers.append("\(title) bulunamadı")
            return
        }
        let ageHours = max(0, now.timeIntervalSince(date) / 3_600)
        if ageHours >= maxAgeHours {
            blockers.append("\(title) çok eski (\(Int(ageHours)) saat)")
        }
    }
}
