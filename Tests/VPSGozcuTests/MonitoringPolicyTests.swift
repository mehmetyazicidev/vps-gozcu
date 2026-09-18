import Foundation
import Testing
@testable import VPSGozcu

struct MonitoringPolicyTests {
    @Test func invalidIntervalsFallBackToFiveMinutes() {
        #expect(MonitoringPolicy.validInterval(0) == 300)
        #expect(MonitoringPolicy.validInterval(-10) == 300)
        #expect(MonitoringPolicy.validInterval(60) == 60)
    }

    @Test func oldOrFutureMeasurementsAreNotFresh() {
        let now = Date()
        #expect(MonitoringPolicy.isFresh(now.addingTimeInterval(-360), now: now))
        #expect(!MonitoringPolicy.isFresh(now.addingTimeInterval(-361), now: now))
        #expect(!MonitoringPolicy.isFresh(now.addingTimeInterval(61), now: now))
    }

    @Test func obsoleteProfileResultsAreRejected() {
        var profile = ServerProfile.example
        profile.isEnabled = true
        #expect(MonitoringPolicy.accepts(profile, currentProfiles: [profile]))
        #expect(!MonitoringPolicy.accepts(profile, currentProfiles: []))
        var changed = profile
        changed.name = "Changed profile"
        #expect(!MonitoringPolicy.accepts(profile, currentProfiles: [changed]))
        changed = profile
        changed.isEnabled = false
        #expect(!MonitoringPolicy.accepts(profile, currentProfiles: [changed]))
    }
}
