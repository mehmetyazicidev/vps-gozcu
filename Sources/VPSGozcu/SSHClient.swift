import Foundation

struct SSHClient: Sendable {
    func probe(_ profile: ServerProfile) async throws -> String {
        let remoteCommand = RemoteProbeScript.make(for: profile)
        var lastError: Error?

        for attempt in 1...2 {
            do {
                return try await Task.detached(priority: .utility) {
                    try Self.runSSH(target: profile.sshTarget, remoteCommand: remoteCommand)
                }.value
            } catch {
                lastError = error
                if attempt == 1 {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }

        throw lastError ?? SSHError.commandFailed(status: -1, message: "SSH bağlantısı iki denemede kurulamadı")
    }

    func runMaintenanceCommand(_ command: String, target: String) async throws -> String {
        try await Task.detached(priority: .utility) {
            try Self.runSSH(target: target, remoteCommand: command)
        }.value
    }

    private static func runSSH(target: String, remoteCommand: String) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectTimeout=8",
            "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=2",
            target,
            "bash -lc \(shellQuote(remoteCommand))"
        ]
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let error = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            let safeMessage = error
                .split(whereSeparator: \.isNewline)
                .last
                .map(String.init) ?? "SSH bağlantısı başarısız"
            throw SSHError.commandFailed(status: process.terminationStatus, message: safeMessage)
        }
        return output
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    enum SSHError: LocalizedError {
        case commandFailed(status: Int32, message: String)

        var errorDescription: String? {
            switch self {
            case let .commandFailed(status, message):
                "SSH komutu başarısız (\(status)): \(message)"
            }
        }
    }
}

enum RemoteProbeScript {
    static func make(for profile: ServerProfile) -> String {
        let healthURL = SSHClient.shellQuote(profile.healthURL)
        let fullBackupRoot = SSHClient.shellQuote(profile.fullBackupRoot)
        let dataBackupRoot = SSHClient.shellQuote(profile.dataBackupRoot)

        return """
        export LC_ALL=C
        set +e
        printf 'probe_epoch=%s\\n' "$(date +%s)"
        printf 'hostname=%s\\n' "$(hostname)"
        printf 'kernel=%s\\n' "$(uname -r)"
        printf 'uptime_seconds=%s\\n' "$(awk '{print int($1)}' /proc/uptime 2>/dev/null)"
        printf 'load_1m=%s\\n' "$(awk '{print $1}' /proc/loadavg 2>/dev/null)"
        printf 'cpu_percent=%s\\n' "$(vmstat 1 2 2>/dev/null | tail -1 | awk '{print 100-$15}')"
        printf 'memory_percent=%s\\n' "$(awk '/MemTotal/ {total=$2} /MemAvailable/ {available=$2} END {if (total>0) printf \"%.1f\", (total-available)*100/total; else print 0}' /proc/meminfo 2>/dev/null)"
        printf 'disk_percent=%s\\n' "$(df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,\"\",$5); print $5}')"
        if command -v apt >/dev/null 2>&1; then
          updates_raw="$(apt list --upgradable 2>/dev/null)"
          updates_status=$?
          updates="$(printf '%s\\n' "$updates_raw" | grep -E '^[^/[:space:]]+/')"
          if [ "$updates_status" -eq 0 ]; then printf 'updates_query_ok=yes\\n'; else printf 'updates_query_ok=no\\n'; fi
          printf 'updates_total=%s\\n' "$(printf '%s\\n' "$updates" | grep -c .)"
          printf 'security_updates=%s\\n' "$(printf '%s\\n' "$updates" | grep -c -- '-security')"
        else
          printf 'updates_query_ok=no\\nupdates_total=\\nsecurity_updates=\\n'
        fi
        if [ -f /var/run/reboot-required ]; then printf 'reboot_required=yes\\n'; else printf 'reboot_required=no\\n'; fi
        if command -v systemctl >/dev/null 2>&1; then
          failed_output="$(systemctl --failed --no-legend 2>/dev/null)"
          services_status=$?
          if [ "$services_status" -eq 0 ]; then printf 'services_query_ok=yes\\n'; else printf 'services_query_ok=no\\n'; fi
          printf 'failed_services=%s\\n' "$(printf '%s\\n' "$failed_output" | grep -c .)"
          printf 'failed_service_names=%s\\n' "$(printf '%s\\n' "$failed_output" | awk '{for (i=1; i<=NF; i++) if ($i ~ /\\.service$/) {print $i; break}}' | paste -sd, -)"
        else
          printf 'services_query_ok=no\\nfailed_services=\\nfailed_service_names=\\n'
        fi
        health_url=\(healthURL)
        if [ -n "$health_url" ]; then
          printf 'health_configured=yes\\n'
          printf 'health_http=%s\\n' "$(curl --max-time 8 -sS -o /dev/null -w '%{http_code}' "$health_url" 2>/dev/null)"
        else
          printf 'health_configured=no\\n'
          printf 'health_http=\\n'
        fi
        case "$health_url" in
          https://*)
            printf 'tls_configured=yes\\n'
            tls_authority="${health_url#https://}"
            tls_authority="${tls_authority%%/*}"
            tls_host="${tls_authority%%:*}"
            if [ "$tls_host" = "$tls_authority" ]; then tls_port=443; else tls_port="${tls_authority##*:}"; fi
            tls_end="$(timeout 10 openssl s_client -connect "$tls_host:$tls_port" -servername "$tls_host" </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null)"
            tls_epoch="$(date -d "${tls_end#notAfter=}" +%s 2>/dev/null)"
            if [ -n "$tls_epoch" ]; then printf 'tls_query_ok=yes\\n'; else printf 'tls_query_ok=no\\n'; fi
            printf 'tls_expiry_epoch=%s\\n' "$tls_epoch"
            ;;
          *)
            printf 'tls_configured=no\\ntls_query_ok=no\\ntls_expiry_epoch=\\n'
            ;;
        esac
        full_backup_root=\(fullBackupRoot)
        if [ -n "$full_backup_root" ]; then printf 'full_backup_configured=yes\\n'; else printf 'full_backup_configured=no\\n'; fi
        if [ -n "$full_backup_root" ] && [ -d "$full_backup_root" ]; then
          full_backup_record="$(find "$full_backup_root" -maxdepth 1 -mindepth 1 -type d -name '*-full-backup' -printf '%T@|%f\\n' 2>/dev/null | sort -nr | head -1)"
          printf 'latest_full_backup=%s\\n' "${full_backup_record#*|}"
          printf 'latest_full_backup_epoch=%s\\n' "${full_backup_record%%|*}"
        else
          printf 'latest_full_backup=none\\nlatest_full_backup_epoch=\\n'
        fi
        data_backup_root=\(dataBackupRoot)
        if [ -n "$data_backup_root" ]; then printf 'data_backup_configured=yes\\n'; else printf 'data_backup_configured=no\\n'; fi
        if [ -n "$data_backup_root" ] && [ -d "$data_backup_root" ]; then
          data_backup_record="$(find "$data_backup_root" -maxdepth 1 -mindepth 1 -type d -name '*-data-backup' -printf '%T@|%f\\n' 2>/dev/null | sort -nr | head -1)"
          printf 'latest_data_backup=%s\\n' "${data_backup_record#*|}"
          printf 'latest_data_backup_epoch=%s\\n' "${data_backup_record%%|*}"
        else
          printf 'latest_data_backup=none\\nlatest_data_backup_epoch=\\n'
        fi
        if command -v docker >/dev/null 2>&1; then
          printf 'docker_available=yes\\n'
          docker_output="$(docker ps -a --format '{{.Names}}|{{.Status}}' 2>/dev/null)"
          docker_status=$?
          if [ "$docker_status" -eq 0 ]; then printf 'docker_query_ok=yes\\n'; else printf 'docker_query_ok=no\\n'; fi
        else
          printf 'docker_available=no\\ndocker_query_ok=no\\n'
          docker_output=''
        fi
        printf 'containers_begin\\n'
        printf '%s\\n' "$docker_output"
        printf 'containers_end\\n'
        """
    }
}
