import Foundation

enum ServerHealth: String, Codable, CaseIterable, Sendable {
    case unknown
    case healthy
    case warning
    case critical

    var title: String {
        switch self {
        case .unknown: "Bilinmiyor"
        case .healthy: "Sağlıklı"
        case .warning: "Uyarı"
        case .critical: "Kritik"
        }
    }
}

struct HealthCheck: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let health: ServerHealth
    let detail: String
    var isInformational: Bool = false
}

struct MonitoringThresholds: Codable, Hashable, Sendable {
    var diskWarningPercent: Double
    var diskCriticalPercent: Double
    var backupWarningHours: Double
    var backupCriticalHours: Double
    var tlsWarningDays: Double
    var tlsCriticalDays: Double

    static let `default` = MonitoringThresholds(
        diskWarningPercent: 80,
        diskCriticalPercent: 90,
        backupWarningHours: 26,
        backupCriticalHours: 48,
        tlsWarningDays: 30,
        tlsCriticalDays: 7
    )

    init(
        diskWarningPercent: Double,
        diskCriticalPercent: Double,
        backupWarningHours: Double = 26,
        backupCriticalHours: Double = 48,
        tlsWarningDays: Double = 30,
        tlsCriticalDays: Double = 7
    ) {
        self.diskWarningPercent = diskWarningPercent
        self.diskCriticalPercent = diskCriticalPercent
        self.backupWarningHours = backupWarningHours
        self.backupCriticalHours = backupCriticalHours
        self.tlsWarningDays = tlsWarningDays
        self.tlsCriticalDays = tlsCriticalDays
    }

    var isValid: Bool {
        (1..<100).contains(diskWarningPercent)
            && (1...100).contains(diskCriticalPercent)
            && diskWarningPercent < diskCriticalPercent
            && backupWarningHours > 0
            && backupWarningHours < backupCriticalHours
            && tlsCriticalDays > 0
            && tlsCriticalDays < tlsWarningDays
    }

    private enum CodingKeys: String, CodingKey {
        case diskWarningPercent
        case diskCriticalPercent
        case backupWarningHours
        case backupCriticalHours
        case tlsWarningDays
        case tlsCriticalDays
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        diskWarningPercent = try values.decode(Double.self, forKey: .diskWarningPercent)
        diskCriticalPercent = try values.decode(Double.self, forKey: .diskCriticalPercent)
        backupWarningHours = try values.decodeIfPresent(Double.self, forKey: .backupWarningHours) ?? 26
        backupCriticalHours = try values.decodeIfPresent(Double.self, forKey: .backupCriticalHours) ?? 48
        tlsWarningDays = try values.decodeIfPresent(Double.self, forKey: .tlsWarningDays) ?? 30
        tlsCriticalDays = try values.decodeIfPresent(Double.self, forKey: .tlsCriticalDays) ?? 7
    }
}

struct ServerProfile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var sshTarget: String
    var appDirectory: String
    var healthURL: String
    var fullBackupRoot: String
    var dataBackupRoot: String
    var thresholds: MonitoringThresholds?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        sshTarget: String,
        appDirectory: String = "/opt/app",
        healthURL: String = "",
        fullBackupRoot: String = "",
        dataBackupRoot: String = "",
        thresholds: MonitoringThresholds = .default,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.sshTarget = sshTarget
        self.appDirectory = appDirectory
        self.healthURL = healthURL
        self.fullBackupRoot = fullBackupRoot
        self.dataBackupRoot = dataBackupRoot
        self.thresholds = thresholds
        self.isEnabled = isEnabled
    }

    static let example = ServerProfile(
        name: "Örnek VPS",
        sshTarget: "vps-example",
        healthURL: "https://example.com/health",
        fullBackupRoot: "/opt/app/backups",
        dataBackupRoot: "/opt/app/data-backups",
        isEnabled: false
    )
}

struct ContainerStatus: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let status: String

    var looksHealthy: Bool {
        let value = status.lowercased()
        return value.contains("up") && !value.contains("unhealthy") && !value.contains("restarting")
    }
}

struct ServerSnapshot: Codable, Hashable, Sendable {
    let capturedAt: Date
    let health: ServerHealth
    let checks: [HealthCheck]
    let hostname: String
    let kernel: String
    let uptimeSeconds: Int?
    let loadOneMinute: Double?
    let cpuPercent: Double?
    let memoryPercent: Double?
    let diskPercent: Double?
    let updatesTotal: Int?
    let securityUpdates: Int?
    let rebootRequired: Bool?
    let failedServices: Int?
    let healthHTTPCode: Int?
    let latestFullBackup: String?
    let latestDataBackup: String?
    let latestFullBackupDate: Date?
    let latestDataBackupDate: Date?
    let tlsExpiresAt: Date?
    let tlsDaysRemaining: Int?
    let containers: [ContainerStatus]
    let summary: String

    static func unreachable(message: String) -> ServerSnapshot {
        ServerSnapshot(
            capturedAt: .now,
            health: .critical,
            checks: [
                HealthCheck(
                    id: "ssh",
                    title: "SSH bağlantısı",
                    health: .critical,
                    detail: message
                )
            ],
            hostname: "Bilinmiyor",
            kernel: "Bilinmiyor",
            uptimeSeconds: nil,
            loadOneMinute: nil,
            cpuPercent: nil,
            memoryPercent: nil,
            diskPercent: nil,
            updatesTotal: nil,
            securityUpdates: nil,
            rebootRequired: nil,
            failedServices: nil,
            healthHTTPCode: nil,
            latestFullBackup: nil,
            latestDataBackup: nil,
            latestFullBackupDate: nil,
            latestDataBackupDate: nil,
            tlsExpiresAt: nil,
            tlsDaysRemaining: nil,
            containers: [],
            summary: message
        )
    }
}

struct MetricSample: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let cpuPercent: Double?
    let memoryPercent: Double?
    let diskPercent: Double?

    init(snapshot: ServerSnapshot) {
        id = UUID()
        date = snapshot.capturedAt
        cpuPercent = snapshot.cpuPercent
        memoryPercent = snapshot.memoryPercent
        diskPercent = snapshot.diskPercent
    }
}

struct MonitorEvent: Identifiable, Codable, Hashable, Sendable {
    enum Level: String, Codable, Sendable {
        case info
        case unknown
        case warning
        case critical
    }

    let id: UUID
    let date: Date
    let serverID: UUID
    let serverName: String
    let level: Level
    let message: String

    init(server: ServerProfile, level: Level, message: String) {
        id = UUID()
        date = .now
        serverID = server.id
        serverName = server.name
        self.level = level
        self.message = message
    }
}
