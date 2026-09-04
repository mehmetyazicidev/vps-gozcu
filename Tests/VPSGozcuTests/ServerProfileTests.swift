import Foundation
import Testing
@testable import VPSGozcu

struct ServerProfileTests {
    @Test func legacyProfileWithoutThresholdsStillDecodes() throws {
        let data = Data("""
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Eski Profil",
          "sshTarget": "legacy-vps",
          "appDirectory": "/opt/app",
          "healthURL": "",
          "fullBackupRoot": "",
          "dataBackupRoot": "",
          "isEnabled": true
        }
        """.utf8)

        let profile = try JSONDecoder().decode(ServerProfile.self, from: data)
        #expect(profile.thresholds == nil)
        #expect((profile.thresholds ?? .default).diskWarningPercent == 80)
    }

    @Test func rejectsOverlappingThresholds() {
        let thresholds = MonitoringThresholds(diskWarningPercent: 90, diskCriticalPercent: 80)
        #expect(!thresholds.isValid)
    }

    @Test func legacyDiskOnlyThresholdsGainSafeDefaults() throws {
        let data = Data("""
        {
          "diskWarningPercent": 75,
          "diskCriticalPercent": 90
        }
        """.utf8)

        let thresholds = try JSONDecoder().decode(MonitoringThresholds.self, from: data)
        #expect(thresholds.backupWarningHours == 26)
        #expect(thresholds.backupCriticalHours == 48)
        #expect(thresholds.tlsWarningDays == 30)
        #expect(thresholds.tlsCriticalDays == 7)
        #expect(thresholds.isValid)
    }
}
