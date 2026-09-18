import Foundation
import Testing
@testable import VPSGozcu

struct HealthTransitionTests {
    @Test func unchangedFindingDoesNotCreateRepeatedEvent() {
        let previous = snapshot(
            health: .critical,
            checks: [HealthCheck(id: "disk", title: "Disk", health: .critical, detail: "Root disk %91")],
            summary: "Root disk %91"
        )
        let current = snapshot(
            health: .critical,
            checks: [HealthCheck(id: "disk", title: "Disk", health: .critical, detail: "Root disk %92")],
            summary: "Root disk %92"
        )

        let transition = HealthTransitionEvaluator.evaluate(previous: previous, current: current)

        #expect(transition.shouldRecordEvent == false)
        #expect(transition.shouldNotify == false)
    }

    @Test func changedFindingAndRecoveryAreRecorded() {
        let previous = snapshot(
            health: .critical,
            checks: [HealthCheck(id: "disk", title: "Disk", health: .critical, detail: "Disk dolu")]
        )
        let differentFinding = snapshot(
            health: .critical,
            checks: [HealthCheck(id: "services", title: "Servisler", health: .critical, detail: "Docker kapalı")]
        )
        let recovered = snapshot(
            health: .healthy,
            checks: [HealthCheck(id: "metrics", title: "Ölçümler", health: .healthy, detail: "Tamam")]
        )

        let changed = HealthTransitionEvaluator.evaluate(previous: previous, current: differentFinding)
        let recovery = HealthTransitionEvaluator.evaluate(previous: differentFinding, current: recovered)

        #expect(changed.shouldRecordEvent)
        #expect(changed.shouldNotify)
        #expect(recovery.shouldRecordEvent)
        #expect(recovery.shouldNotify == false)
    }

    @Test func unreachableIsCriticalButAvailabilityIsExplicit() {
        let reachable = snapshot(
            health: .healthy,
            checks: [HealthCheck(id: "metrics", title: "Ölçümler", health: .healthy, detail: "Tamam")]
        )
        let unreachable = ServerSnapshot.unreachable(message: "SSH zaman aşımı")

        let transition = HealthTransitionEvaluator.evaluate(previous: reachable, current: unreachable)

        #expect(unreachable.health == .critical)
        #expect(unreachable.isReachable == false)
        #expect(unreachable.availabilityTitle == "SSH erişilemiyor")
        #expect(transition.shouldRecordEvent)
        #expect(transition.shouldNotify == false)
        #expect(transition.eventLevel == .unknown)

        let confirmed = HealthTransitionEvaluator.evaluate(
            previous: unreachable,
            current: unreachable,
            consecutiveConnectionFailures: 2
        )
        #expect(confirmed.shouldRecordEvent)
        #expect(confirmed.shouldNotify)
        #expect(confirmed.eventLevel == .critical)

        let continued = HealthTransitionEvaluator.evaluate(
            previous: unreachable,
            current: unreachable,
            consecutiveConnectionFailures: 3
        )
        #expect(continued.shouldRecordEvent == false)
        #expect(continued.shouldNotify == false)
    }

    private func snapshot(
        health: ServerHealth,
        checks: [HealthCheck],
        summary: String = "Test"
    ) -> ServerSnapshot {
        ServerSnapshot(
            capturedAt: .now,
            health: health,
            checks: checks,
            hostname: "test-vps",
            kernel: "test-kernel",
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
            summary: summary
        )
    }
}
