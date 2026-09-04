import Testing
@testable import VPSGozcu

struct MaintenanceExecutorTests {
    @Test func updateCommandIsFixedAndBackupFirst() {
        let profile = ServerProfile(
            name: "Test VPS",
            sshTarget: "test-vps",
            fullBackupRoot: "/opt/backups",
            dataBackupRoot: "/opt/data-backups"
        )
        let command = MaintenanceCommandScript.make(
            profile: profile,
            action: .updatePackages,
            maxBackupAgeHours: 26
        )

        #expect(command.contains("find \"$backup_root\"") == true)
        #expect(command.contains("apt-get update") == true)
        #expect(command.contains("apt-get upgrade -y") == true)
        #expect(command.range(of: "apt-get update")!.lowerBound > command.range(of: "backup_record")!.lowerBound)
        #expect(command.contains("systemctl reboot") == false)
    }

    @Test func rebootCommandDoesNotContainPackageUpdate() {
        let profile = ServerProfile(name: "Test VPS", sshTarget: "test-vps")
        let command = MaintenanceCommandScript.make(
            profile: profile,
            action: .reboot,
            maxBackupAgeHours: 26
        )

        #expect(command.contains("systemctl reboot") == true)
        #expect(command.contains("apt-get") == false)
    }
}
