import Testing
@testable import VPSGozcu

struct ProbeParserTests {
    @Test func parsesHealthyProbe() throws {
        let output = """
        hostname=test-vps
        probe_epoch=2000000000
        kernel=6.8.0-138-generic
        uptime_seconds=86461
        load_1m=0.42
        cpu_percent=12
        memory_percent=37.5
        disk_percent=51
        updates_query_ok=yes
        updates_total=0
        security_updates=0
        reboot_required=no
        services_query_ok=yes
        failed_services=0
        health_configured=yes
        health_http=200
        full_backup_configured=yes
        latest_full_backup=2026-09-04-023001-full-backup
        latest_full_backup_epoch=1999996400
        data_backup_configured=yes
        latest_data_backup=2026-09-04-031501-data-backup
        latest_data_backup_epoch=1999998200
        tls_configured=yes
        tls_query_ok=yes
        tls_expiry_epoch=2007776000
        docker_available=yes
        docker_query_ok=yes
        containers_begin
        app_api|Up 2 days (healthy)
        app_web|Up 2 days
        containers_end
        """

        let snapshot = try ProbeParser.parse(output)
        #expect(snapshot.health == .healthy)
        #expect(snapshot.hostname == "test-vps")
        #expect(snapshot.memoryPercent == 37.5)
        #expect(snapshot.containers.count == 2)
        #expect(snapshot.tlsDaysRemaining == 90)
    }

    @Test func marksMaintenanceAsWarning() throws {
        let output = """
        hostname=test-server
        kernel=6.8.0
        uptime_seconds=120
        load_1m=0.10
        cpu_percent=3
        memory_percent=20
        disk_percent=42
        updates_query_ok=yes
        updates_total=4
        security_updates=1
        reboot_required=yes
        services_query_ok=yes
        failed_services=0
        health_configured=yes
        health_http=200
        full_backup_configured=no
        latest_full_backup=none
        data_backup_configured=no
        latest_data_backup=none
        docker_available=no
        docker_query_ok=no
        containers_begin
        containers_end
        """

        let snapshot = try ProbeParser.parse(output)
        #expect(snapshot.health == .warning)
        #expect(snapshot.rebootRequired == true)
        #expect(snapshot.securityUpdates == 1)
        #expect(snapshot.summary.contains("4 paket bekliyor"))
    }

    @Test func marksUnhealthyContainerAsCritical() throws {
        let output = """
        hostname=test-server
        disk_percent=20
        updates_total=0
        security_updates=0
        reboot_required=no
        failed_services=0
        health_http=200
        containers_begin
        api|Restarting (1) 5 seconds ago
        containers_end
        """

        let snapshot = try ProbeParser.parse(output)
        #expect(snapshot.health == .critical)
    }

    @Test func informationalFailedServiceDoesNotChangeOverallHealth() throws {
        let output = minimalProbe(
            failedServices: 1,
            failedServiceNames: "fwupd-refresh.service"
        )

        let snapshot = try ProbeParser.parse(output)
        let information = snapshot.checks.first { $0.id == "services-info" }
        #expect(snapshot.checks.first { $0.id == "services" }?.health == .healthy)
        #expect(snapshot.health == .healthy)
        #expect(snapshot.failedServices == 0)
        #expect(information?.isInformational == true)
        #expect(information?.detail.contains("fwupd-refresh.service") == true)
    }

    @Test func essentialFailedServiceIsCritical() throws {
        let output = minimalProbe(
            failedServices: 1,
            failedServiceNames: "docker.service"
        )

        let snapshot = try ProbeParser.parse(output)
        #expect(snapshot.checks.first { $0.id == "services" }?.health == .critical)
        #expect(snapshot.health == .critical)
    }

    @Test func missingMeasurementsNeverLookHealthy() throws {
        let output = """
        hostname=test-server
        kernel=6.8.0
        updates_query_ok=no
        reboot_required=no
        services_query_ok=no
        health_configured=no
        full_backup_configured=no
        data_backup_configured=no
        docker_available=no
        docker_query_ok=no
        containers_begin
        containers_end
        """

        let snapshot = try ProbeParser.parse(output)
        #expect(snapshot.health == .unknown)
        #expect(snapshot.cpuPercent == nil)
        #expect(snapshot.diskPercent == nil)
        #expect(snapshot.checks.contains { $0.health == .unknown })
        #expect(snapshot.summary.contains("Okunamayan değerler"))
    }

    @Test func unreachableSnapshotIsExplicitlyCritical() {
        let snapshot = ServerSnapshot.unreachable(message: "SSH zaman aşımı")

        #expect(snapshot.health == .critical)
        #expect(snapshot.cpuPercent == nil)
        #expect(snapshot.checks == [
            HealthCheck(id: "ssh", title: "SSH bağlantısı", health: .critical, detail: "SSH zaman aşımı")
        ])
    }

    @Test func appliesServerSpecificDiskThresholds() throws {
        let output = """
        hostname=test-server
        kernel=6.8.0
        uptime_seconds=30
        load_1m=0.1
        cpu_percent=2
        memory_percent=10
        disk_percent=72
        updates_query_ok=yes
        updates_total=0
        security_updates=0
        reboot_required=no
        services_query_ok=yes
        failed_services=0
        health_configured=no
        full_backup_configured=no
        data_backup_configured=no
        docker_available=no
        docker_query_ok=no
        containers_begin
        containers_end
        """

        let thresholds = MonitoringThresholds(diskWarningPercent: 70, diskCriticalPercent: 85)
        let snapshot = try ProbeParser.parse(output, thresholds: thresholds)
        #expect(snapshot.health == .warning)
        #expect(snapshot.checks.first { $0.id == "disk" }?.health == .warning)
    }

    @Test func staleBackupIsCritical() throws {
        let output = minimalProbe(failedServices: 0, failedServiceNames: "") + """

        probe_epoch=2000000000
        full_backup_configured=yes
        latest_full_backup=old-full-backup
        latest_full_backup_epoch=1999784000
        """

        let snapshot = try ProbeParser.parse(output)
        #expect(snapshot.checks.first { $0.id == "full-backup" }?.health == .critical)
        #expect(snapshot.health == .critical)
    }

    @Test func approachingTLSExpiryIsWarning() throws {
        let output = minimalProbe(failedServices: 0, failedServiceNames: "") + """

        probe_epoch=2000000000
        tls_configured=yes
        tls_query_ok=yes
        tls_expiry_epoch=2001728000
        """

        let snapshot = try ProbeParser.parse(output)
        #expect(snapshot.tlsDaysRemaining == 20)
        #expect(snapshot.checks.first { $0.id == "tls" }?.health == .warning)
        #expect(snapshot.health == .warning)
    }

    private func minimalProbe(failedServices: Int, failedServiceNames: String) -> String {
        """
        hostname=test-server
        kernel=6.8.0
        uptime_seconds=30
        load_1m=0.1
        cpu_percent=2
        memory_percent=10
        disk_percent=20
        updates_query_ok=yes
        updates_total=0
        security_updates=0
        reboot_required=no
        services_query_ok=yes
        failed_services=\(failedServices)
        failed_service_names=\(failedServiceNames)
        health_configured=no
        full_backup_configured=no
        data_backup_configured=no
        docker_available=no
        docker_query_ok=no
        containers_begin
        containers_end
        """
    }
}
