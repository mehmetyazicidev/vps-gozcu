import Foundation

enum MaintenanceAction: String, Identifiable, Sendable {
    case updatePackages
    case reboot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .updatePackages: "Paket güncellemesi"
        case .reboot: "Yeniden başlatma"
        }
    }
}

struct MaintenanceExecutionResult: Sendable {
    let action: MaintenanceAction
    let output: String
}

struct MaintenanceExecutor: Sendable {
    private let sshClient = SSHClient()

    func execute(
        profile: ServerProfile,
        plan: MaintenancePlan,
        action: MaintenanceAction
    ) async throws -> MaintenanceExecutionResult {
        guard plan.isReady else {
            throw ExecutionError.blocked(plan.blockers.joined(separator: ", "))
        }
        guard plan.requiresMaintenance else {
            throw ExecutionError.blocked("Güncelleme veya reboot gerekmiyor")
        }
        if action == .updatePackages && plan.packageCount == 0 {
            throw ExecutionError.blocked("Bekleyen paket yok")
        }
        if action == .reboot && !plan.rebootRequired {
            throw ExecutionError.blocked("Reboot gerekmiyor")
        }

        let command = MaintenanceCommandScript.make(
            profile: profile,
            action: action,
            maxBackupAgeHours: profile.thresholds?.backupWarningHours ?? MonitoringThresholds.default.backupWarningHours
        )
        let output = try await sshClient.runMaintenanceCommand(command, target: profile.sshTarget)
        return MaintenanceExecutionResult(action: action, output: output)
    }

    enum ExecutionError: LocalizedError {
        case blocked(String)

        var errorDescription: String? {
            switch self {
            case let .blocked(reason): "Bakım güvenlik kapısı: \(reason)"
            }
        }
    }
}

enum MaintenanceCommandScript {
    static func make(
        profile: ServerProfile,
        action: MaintenanceAction,
        maxBackupAgeHours: Double
    ) -> String {
        let fullRoot = SSHClient.shellQuote(profile.fullBackupRoot)
        let dataRoot = SSHClient.shellQuote(profile.dataBackupRoot)
        let maxAgeSeconds = Int(maxBackupAgeHours * 3_600)

        switch action {
        case .updatePackages:
            return """
            set -eu
            now=$(date +%s)
            full_root=\(fullRoot)
            data_root=\(dataRoot)
            max_age=\(maxAgeSeconds)
            for backup_spec in "$full_root|*-full-backup" "$data_root|*-data-backup"; do
              backup_root="${backup_spec%%|*}"
              backup_pattern="${backup_spec#*|}"
              [ -d "$backup_root" ] || { echo "Gerekli yedek yolu yok: $backup_root" >&2; exit 20; }
              backup_record="$(find "$backup_root" -maxdepth 1 -mindepth 1 -type d -name "$backup_pattern" -printf '%T@|%f\\n' 2>/dev/null | sort -nr | head -1)"
              [ -n "$backup_record" ] || { echo "Gerekli yedek bulunamadı: $backup_root" >&2; exit 21; }
              backup_epoch="${backup_record%%|*}"
              backup_epoch="$(printf '%s' "$backup_epoch" | cut -d. -f1)"
              [ $((now - backup_epoch)) -le "$max_age" ] || { echo "Yedek çok eski: $backup_root" >&2; exit 22; }
            done
            timeout 900 sudo -n apt-get update
            timeout 1800 sudo -n env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
            """
        case .reboot:
            return """
            set -eu
            timeout 30 sudo -n systemctl reboot
            """
        }
    }
}
