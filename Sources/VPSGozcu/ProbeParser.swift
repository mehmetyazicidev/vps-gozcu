import Foundation

enum ProbeParser {
    static func parse(
        _ output: String,
        thresholds: MonitoringThresholds = .default
    ) throws -> ServerSnapshot {
        var values: [String: String] = [:]
        var containers: [ContainerStatus] = []
        var inContainers = false

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)

            if line == "containers_begin" {
                inContainers = true
                continue
            }
            if line == "containers_end" {
                inContainers = false
                continue
            }

            if inContainers {
                let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    containers.append(ContainerStatus(name: parts[0], status: parts[1]))
                }
                continue
            }

            guard let separator = line.firstIndex(of: "=") else { continue }
            values[String(line[..<separator])] = String(line[line.index(after: separator)...])
        }

        guard let hostname = values["hostname"], !hostname.isEmpty else {
            throw ParseError.missingHostname
        }

        let uptime = int(values["uptime_seconds"])
        let load = double(values["load_1m"])
        let cpu = double(values["cpu_percent"])
        let memory = double(values["memory_percent"])
        let disk = double(values["disk_percent"])
        let updates = int(values["updates_total"])
        let securityUpdates = int(values["security_updates"])
        let rebootRequired = bool(values["reboot_required"])
        let rawFailedServices = int(values["failed_services"])
        let failedServiceNames = list(values["failed_service_names"])
        let httpCode = int(values["health_http"])
        let latestFullBackup = optional(values["latest_full_backup"])
        let latestDataBackup = optional(values["latest_data_backup"])
        let capturedAt = Date()
        let probeDate = epochDate(values["probe_epoch"]) ?? capturedAt
        let latestFullBackupDate = epochDate(values["latest_full_backup_epoch"])
        let latestDataBackupDate = epochDate(values["latest_data_backup_epoch"])
        let tlsExpiresAt = epochDate(values["tls_expiry_epoch"])
        var tlsDaysRemaining: Int?

        var checks: [HealthCheck] = []

        let missingMetrics = [
            uptime == nil ? "uptime" : nil,
            load == nil ? "load" : nil,
            cpu == nil ? "CPU" : nil,
            memory == nil ? "bellek" : nil
        ].compactMap { $0 }
        checks.append(HealthCheck(
            id: "metrics",
            title: "Sistem ölçümleri",
            health: missingMetrics.isEmpty ? .healthy : .unknown,
            detail: missingMetrics.isEmpty ? "CPU, bellek, load ve uptime okunuyor" : "Okunamayan değerler: \(missingMetrics.joined(separator: ", "))"
        ))

        if let disk {
            checks.append(HealthCheck(
                id: "disk",
                title: "Disk kullanımı",
                health: disk >= thresholds.diskCriticalPercent ? .critical : disk >= thresholds.diskWarningPercent ? .warning : .healthy,
                detail: "Root disk kullanımı %\(format(disk))"
            ))
        } else {
            checks.append(HealthCheck(id: "disk", title: "Disk kullanımı", health: .unknown, detail: "Disk kullanımı okunamadı"))
        }

        let updatesQuerySucceeded = bool(values["updates_query_ok"]) ?? (updates != nil && securityUpdates != nil)
        if updatesQuerySucceeded, let updates, let securityUpdates {
            let health: ServerHealth = updates > 0 ? .warning : .healthy
            let detail = updates == 0
                ? "Bekleyen paket yok"
                : "\(updates) paket bekliyor, \(securityUpdates) güvenlik güncellemesi"
            checks.append(HealthCheck(id: "updates", title: "Paket güncellemeleri", health: health, detail: detail))
        } else {
            checks.append(HealthCheck(id: "updates", title: "Paket güncellemeleri", health: .unknown, detail: "Paket bilgisi okunamadı"))
        }

        if let rebootRequired {
            checks.append(HealthCheck(
                id: "reboot",
                title: "Yeniden başlatma",
                health: rebootRequired ? .warning : .healthy,
                detail: rebootRequired ? "Yeni kernel veya sistem bileşeni için gerekli" : "Yeniden başlatma gerekmiyor"
            ))
        } else {
            checks.append(HealthCheck(id: "reboot", title: "Yeniden başlatma", health: .unknown, detail: "Reboot gereksinimi okunamadı"))
        }

        let servicesQuerySucceeded = bool(values["services_query_ok"]) ?? (rawFailedServices != nil)
        var actionableFailedServices = rawFailedServices
        if servicesQuerySucceeded, let rawFailedServices {
            let informationalServiceNames = failedServiceNames.filter(isInformationalService)
            let actionableServiceNames = failedServiceNames.filter { !isInformationalService($0) }
            let actionableCount = failedServiceNames.isEmpty ? rawFailedServices : actionableServiceNames.count
            actionableFailedServices = actionableCount
            let criticalServiceNames = actionableServiceNames.filter(isCriticalService)
            let serviceHealth: ServerHealth = actionableCount == 0
                ? .healthy
                : criticalServiceNames.isEmpty ? .warning : .critical
            let serviceDetail: String
            if actionableCount == 0 {
                serviceDetail = "Başarısız servis yok"
            } else if actionableServiceNames.isEmpty {
                serviceDetail = "\(actionableCount) servis başarısız"
            } else {
                serviceDetail = "Başarısız: \(actionableServiceNames.joined(separator: ", "))"
            }
            checks.append(HealthCheck(
                id: "services",
                title: "Systemd servisleri",
                health: serviceHealth,
                detail: serviceDetail
            ))
            if !informationalServiceNames.isEmpty {
                checks.append(HealthCheck(
                    id: "services-info",
                    title: "Systemd bakım notu",
                    health: .healthy,
                    detail: "Üretim sağlığına etkisiz: \(informationalServiceNames.joined(separator: ", "))",
                    isInformational: true
                ))
            }
        } else {
            checks.append(HealthCheck(id: "services", title: "Systemd servisleri", health: .unknown, detail: "Servis durumu okunamadı"))
        }

        let healthConfigured = bool(values["health_configured"]) ?? (values["health_http"].map { !$0.isEmpty } ?? false)
        if healthConfigured {
            if let httpCode {
                checks.append(HealthCheck(
                    id: "health-url",
                    title: "Health endpoint",
                    health: httpCode == 200 ? .healthy : .critical,
                    detail: httpCode == 200 ? "HTTP 200 yanıtı alındı" : "HTTP \(httpCode) yanıtı alındı"
                ))
            } else {
                checks.append(HealthCheck(id: "health-url", title: "Health endpoint", health: .unknown, detail: "HTTP yanıtı alınamadı"))
            }
        }

        let tlsConfigured = bool(values["tls_configured"]) ?? false
        if tlsConfigured {
            let tlsQuerySucceeded = bool(values["tls_query_ok"]) ?? (tlsExpiresAt != nil)
            if tlsQuerySucceeded, let tlsExpiresAt {
                let remainingSeconds = tlsExpiresAt.timeIntervalSince(probeDate)
                let remainingDays = Int(floor(remainingSeconds / 86_400))
                tlsDaysRemaining = remainingDays
                let tlsHealth: ServerHealth
                if remainingDays <= 0 {
                    tlsHealth = .critical
                } else if Double(remainingDays) <= thresholds.tlsCriticalDays {
                    tlsHealth = .critical
                } else if Double(remainingDays) <= thresholds.tlsWarningDays {
                    tlsHealth = .warning
                } else {
                    tlsHealth = .healthy
                }
                checks.append(HealthCheck(
                    id: "tls",
                    title: "TLS sertifikası",
                    health: tlsHealth,
                    detail: remainingDays <= 0
                        ? "Sertifikanın süresi dolmuş"
                        : "Sertifikanın bitmesine \(remainingDays) gün var"
                ))
            } else {
                checks.append(HealthCheck(
                    id: "tls",
                    title: "TLS sertifikası",
                    health: .unknown,
                    detail: "Sertifika bitiş tarihi okunamadı"
                ))
            }
        }

        appendBackupCheck(
            to: &checks,
            id: "full-backup",
            title: "Full yedek",
            configured: bool(values["full_backup_configured"]) ?? (values["latest_full_backup"] != nil),
            latest: latestFullBackup,
            latestDate: latestFullBackupDate,
            probeDate: probeDate,
            thresholds: thresholds
        )
        appendBackupCheck(
            to: &checks,
            id: "data-backup",
            title: "Veri yedeği",
            configured: bool(values["data_backup_configured"]) ?? (values["latest_data_backup"] != nil),
            latest: latestDataBackup,
            latestDate: latestDataBackupDate,
            probeDate: probeDate,
            thresholds: thresholds
        )

        let dockerAvailable = bool(values["docker_available"]) ?? !containers.isEmpty
        if dockerAvailable {
            let dockerQuerySucceeded = bool(values["docker_query_ok"]) ?? true
            if dockerQuerySucceeded {
                let unhealthyCount = containers.filter { !$0.looksHealthy }.count
                checks.append(HealthCheck(
                    id: "docker",
                    title: "Docker",
                    health: unhealthyCount > 0 ? .critical : .healthy,
                    detail: unhealthyCount > 0 ? "\(unhealthyCount) container sağlıksız" : "\(containers.count) container çalışır durumda"
                ))
            } else {
                checks.append(HealthCheck(id: "docker", title: "Docker", health: .unknown, detail: "Container durumu okunamadı"))
            }
        }

        let health = overallHealth(for: checks)

        return ServerSnapshot(
            capturedAt: capturedAt,
            health: health,
            checks: checks,
            hostname: hostname,
            kernel: optional(values["kernel"]) ?? "Bilinmiyor",
            uptimeSeconds: uptime,
            loadOneMinute: load,
            cpuPercent: cpu,
            memoryPercent: memory,
            diskPercent: disk,
            updatesTotal: updates,
            securityUpdates: securityUpdates,
            rebootRequired: rebootRequired,
            failedServices: actionableFailedServices,
            healthHTTPCode: httpCode,
            latestFullBackup: latestFullBackup,
            latestDataBackup: latestDataBackup,
            latestFullBackupDate: latestFullBackupDate,
            latestDataBackupDate: latestDataBackupDate,
            tlsExpiresAt: tlsExpiresAt,
            tlsDaysRemaining: tlsDaysRemaining,
            containers: containers,
            summary: summary(for: checks, health: health)
        )
    }

    private static func appendBackupCheck(
        to checks: inout [HealthCheck],
        id: String,
        title: String,
        configured: Bool,
        latest: String?,
        latestDate: Date?,
        probeDate: Date,
        thresholds: MonitoringThresholds
    ) {
        guard configured else { return }
        guard let latest else {
            checks.append(HealthCheck(id: id, title: title, health: .warning, detail: "Yedek bulunamadı"))
            return
        }
        guard let latestDate else {
            checks.append(HealthCheck(id: id, title: title, health: .unknown, detail: "Yedek yaşı okunamadı: \(latest)"))
            return
        }
        let ageHours = max(0, probeDate.timeIntervalSince(latestDate) / 3_600)
        let health: ServerHealth = ageHours >= thresholds.backupCriticalHours
            ? .critical
            : ageHours >= thresholds.backupWarningHours ? .warning : .healthy
        checks.append(HealthCheck(
            id: id,
            title: title,
            health: health,
            detail: "\(formatAge(hours: ageHours)) önce: \(latest)"
        ))
    }

    private static func overallHealth(for checks: [HealthCheck]) -> ServerHealth {
        if checks.contains(where: { $0.health == .critical }) { return .critical }
        if checks.contains(where: { $0.health == .warning }) { return .warning }
        if checks.contains(where: { $0.health == .unknown }) { return .unknown }
        return .healthy
    }

    private static func summary(for checks: [HealthCheck], health: ServerHealth) -> String {
        if let first = checks.first(where: { $0.health == health && health != .healthy }) {
            let additional = checks.filter { $0.health == health }.count - 1
            return additional > 0 ? "\(first.detail) ve \(additional) ek bulgu" : first.detail
        }
        return "Tüm zorunlu kontroller temiz"
    }

    private static func int(_ value: String?) -> Int? {
        guard let value, !value.isEmpty else { return nil }
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func double(_ value: String?) -> Double? {
        guard let value, !value.isEmpty else { return nil }
        return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func epochDate(_ value: String?) -> Date? {
        guard let seconds = double(value), seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func bool(_ value: String?) -> Bool? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "yes": true
        case "no": false
        default: nil
        }
    }

    private static func optional(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value != "none" else { return nil }
        return value
    }

    private static func list(_ value: String?) -> [String] {
        guard let value else { return [] }
        return value.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private static func isCriticalService(_ name: String) -> Bool {
        ["docker.service", "containerd.service", "ssh.service", "sshd.service"].contains(name)
    }

    private static func isInformationalService(_ name: String) -> Bool {
        ["fwupd-refresh.service"].contains(name)
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private static func formatAge(hours: Double) -> String {
        let totalHours = Int(hours.rounded(.down))
        if totalHours < 24 { return "\(totalHours) saat" }
        return "\(totalHours / 24) gün \(totalHours % 24) saat"
    }

    enum ParseError: LocalizedError {
        case missingHostname

        var errorDescription: String? {
            "Sunucu çıktısında hostname bulunamadı."
        }
    }
}
