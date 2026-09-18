import Foundation

/// Describes whether a new probe result is meaningful enough to enter the
/// event timeline or trigger a local critical notification.
struct HealthTransition: Equatable, Sendable {
    let shouldRecordEvent: Bool
    let shouldNotify: Bool
    let eventLevel: MonitorEvent.Level
}

enum HealthTransitionEvaluator {
    static func evaluate(
        previous: ServerSnapshot?,
        current: ServerSnapshot,
        consecutiveConnectionFailures: Int = 0
    ) -> HealthTransition {
        guard let previous else {
            return HealthTransition(
                shouldRecordEvent: true,
                shouldNotify: shouldNotify(
                    current: current,
                    changed: true,
                    consecutiveConnectionFailures: consecutiveConnectionFailures
                ),
                eventLevel: eventLevel(
                    for: current,
                    consecutiveConnectionFailures: consecutiveConnectionFailures
                )
            )
        }

        let changed = fingerprint(for: previous) != fingerprint(for: current)
        let confirmedConnectionFailure = !current.isReachable
            && consecutiveConnectionFailures == 2
        return HealthTransition(
            shouldRecordEvent: changed || confirmedConnectionFailure,
            shouldNotify: shouldNotify(
                current: current,
                changed: changed,
                consecutiveConnectionFailures: consecutiveConnectionFailures
            ),
            eventLevel: eventLevel(
                for: current,
                consecutiveConnectionFailures: consecutiveConnectionFailures
            )
        )
    }

    private static func shouldNotify(
        current: ServerSnapshot,
        changed: Bool,
        consecutiveConnectionFailures: Int
    ) -> Bool {
        guard current.health == .critical else { return false }
        if current.isReachable { return changed }
        return consecutiveConnectionFailures >= 2 && (changed || consecutiveConnectionFailures == 2)
    }

    private static func eventLevel(
        for snapshot: ServerSnapshot,
        consecutiveConnectionFailures: Int
    ) -> MonitorEvent.Level {
        if !snapshot.isReachable && consecutiveConnectionFailures < 2 {
            return .unknown
        }
        switch snapshot.health {
        case .critical: return .critical
        case .warning: return .warning
        case .unknown: return .unknown
        case .healthy: return .info
        }
    }

    /// Probe details such as backup age and captured timestamps change on every
    /// poll. The timeline should react to a changed finding, not to that clock.
    /// Check identifiers and severities are stable across repeated scans and
    /// still capture recovery, new failures, and SSH availability changes.
    static func fingerprint(for snapshot: ServerSnapshot) -> String {
        let checks = snapshot.checks
            .filter { !$0.isInformational }
            .map { "\($0.id)=\($0.health.rawValue)" }
            .joined(separator: "|")
        return "overall=\(snapshot.health.rawValue)|\(checks)"
    }
}
