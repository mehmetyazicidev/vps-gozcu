import Foundation
import Testing
@testable import VPSGozcu

struct MaintenancePlannerTests {
    @Test func noMaintenanceNeededHasNoBlockers() throws {
        let now = Date()
        let profile = profile()
        let snapshot = try ProbeParser.parse(probe(epoch: Int(now.timeIntervalSince1970), updates: 0, reboot: "no"))

        let plan = MaintenancePlanner.make(profile: profile, snapshot: snapshot, now: now)
        #expect(plan.requiresMaintenance == false)
        #expect(plan.isReady)
    }

    @Test func maintenanceRequiresFreshBackups() throws {
        let now = Date()
        let epoch = Int(now.timeIntervalSince1970)
        let profile = profile()
        let snapshot = try ProbeParser.parse(probe(
            epoch: epoch,
            updates: 4,
            reboot: "yes",
            fullBackupEpoch: epoch - 3_600,
            dataBackupEpoch: epoch - 3_600
        ))

        let plan = MaintenancePlanner.make(profile: profile, snapshot: snapshot, now: now)
        #expect(plan.requiresMaintenance)
        #expect(plan.isReady)
        #expect(plan.packageCount == 4)
        #expect(plan.rebootRequired)
    }

    @Test func staleBackupBlocksMaintenance() throws {
        let now = Date()
        let epoch = Int(now.timeIntervalSince1970)
        let profile = profile()
        let snapshot = try ProbeParser.parse(probe(
            epoch: epoch,
            updates: 1,
            reboot: "no",
            fullBackupEpoch: epoch - 100_000,
            dataBackupEpoch: epoch - 3_600
        ))

        let plan = MaintenancePlanner.make(profile: profile, snapshot: snapshot, now: now)
        #expect(!plan.isReady)
        #expect(plan.blockers.contains { $0.contains("Full yedek çok eski") })
    }

    private func profile() -> ServerProfile {
        ServerProfile(
            name: "Test VPS",
            sshTarget: "test-vps",
            fullBackupRoot: "/opt/backups",
            dataBackupRoot: "/opt/data-backups"
        )
    }

    private func probe(
        epoch: Int,
        updates: Int,
        reboot: String,
        fullBackupEpoch: Int? = nil,
        dataBackupEpoch: Int? = nil
    ) -> String {
        """
        probe_epoch=\(epoch)
        hostname=test-server
        uptime_seconds=300
        load_1m=0.1
        cpu_percent=2
        memory_percent=10
        disk_percent=20
        updates_query_ok=yes
        updates_total=\(updates)
        security_updates=0
        reboot_required=\(reboot)
        services_query_ok=yes
        failed_services=0
        health_configured=no
        full_backup_configured=\(fullBackupEpoch == nil ? "no" : "yes")
        latest_full_backup=\(fullBackupEpoch == nil ? "none" : "full-backup")
        latest_full_backup_epoch=\(fullBackupEpoch.map(String.init) ?? "")
        data_backup_configured=\(dataBackupEpoch == nil ? "no" : "yes")
        latest_data_backup=\(dataBackupEpoch == nil ? "none" : "data-backup")
        latest_data_backup_epoch=\(dataBackupEpoch.map(String.init) ?? "")
        docker_available=no
        docker_query_ok=no
        containers_begin
        containers_end
        """
    }
}
