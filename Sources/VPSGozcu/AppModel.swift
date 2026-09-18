import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [ServerProfile]
    @Published var selectedServerID: UUID?
    @Published private(set) var snapshots: [UUID: ServerSnapshot] = [:]
    @Published private(set) var lastSuccessfulRefresh: [UUID: Date] = [:]
    @Published private(set) var history: [UUID: [MetricSample]] = [:]
    @Published private(set) var events: [MonitorEvent] = []
    @Published private(set) var isRefreshing = false
    @Published var pollingInterval: TimeInterval = 300
    private let preferences = UserDefaults.standard
    @Published var showingAddServer = false
    @Published var editingProfile: ServerProfile?

    private let sshClient = SSHClient()
    private let notificationService = NotificationService()
    private var pollingTask: Task<Void, Never>?
    private var consecutiveConnectionFailures: [UUID: Int] = [:]

    init() {
        let loaded = ConfigurationStore.loadProfiles()
        let archive = MonitoringStore.load()
        profiles = loaded
        history = archive.historyByServer
        events = archive.events
        lastSuccessfulRefresh = archive.historyByServer.compactMapValues { samples in
            samples.last?.date
        }
        selectedServerID = loaded.first?.id
        pollingInterval = MonitoringPolicy.validInterval(preferences.double(forKey: "monitoring.pollingSeconds"))
    }

    var selectedProfile: ServerProfile? {
        profiles.first { $0.id == selectedServerID }
    }

    var enabledProfiles: [ServerProfile] {
        profiles.filter(\.isEnabled)
    }

    var criticalCount: Int {
        snapshots.values.filter { $0.health == .critical }.count
    }

    var warningCount: Int {
        snapshots.values.filter { $0.health == .warning }.count
    }

    var unknownCount: Int {
        snapshots.values.filter { $0.health == .unknown }.count
    }

    func start() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await notificationService.requestAuthorization()
            await refreshAll()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollingInterval))
                guard !Task.isCancelled else { return }
                await refreshAll()
            }
        }
    }

    func setPollingInterval(_ interval: TimeInterval) {
        pollingInterval = MonitoringPolicy.validInterval(interval)
        preferences.set(pollingInterval, forKey: "monitoring.pollingSeconds")
        restartPolling()
    }

    func restartPolling() {
        start()
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        let targets = enabledProfiles
        guard !targets.isEmpty else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: ProbeOutcome.self) { group in
            for profile in targets {
                group.addTask { [sshClient] in
                    do {
                        let output = try await sshClient.probe(profile)
                        let snapshot = try ProbeParser.parse(output, thresholds: profile.thresholds ?? .default)
                        return .success(profile, snapshot)
                    } catch {
                        return .failure(profile, error.localizedDescription)
                    }
                }
            }

            for await outcome in group {
                apply(outcome)
            }
        }
        persistMonitoringState()
    }

    func addProfile(_ profile: ServerProfile) {
        profiles.append(profile)
        selectedServerID = profile.id
        persistProfiles()
        events.insert(MonitorEvent(server: profile, level: .info, message: "Sunucu profili eklendi"), at: 0)
        persistMonitoringState()
        restartPolling()
    }

    func updateProfile(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        selectedServerID = profile.id
        persistProfiles()
        events.insert(MonitorEvent(server: profile, level: .info, message: "Sunucu profili güncellendi"), at: 0)
        persistMonitoringState()
        restartPolling()
    }

    func deleteProfile(_ profile: ServerProfile) {
        profiles.removeAll { $0.id == profile.id }
        snapshots[profile.id] = nil
        history[profile.id] = nil
        lastSuccessfulRefresh[profile.id] = nil
        consecutiveConnectionFailures[profile.id] = nil
        if selectedServerID == profile.id {
            selectedServerID = profiles.first?.id
        }
        persistProfiles()
        persistMonitoringState()
    }

    func setEnabled(_ profile: ServerProfile, enabled: Bool) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].isEnabled = enabled
        persistProfiles()
        restartPolling()
    }

    private func apply(_ outcome: ProbeOutcome) {
        // A deleted, disabled or edited profile must not receive an obsolete probe result.
        guard MonitoringPolicy.accepts(outcome.profile, currentProfiles: profiles) else { return }
        switch outcome {
        case let .success(profile, snapshot):
            let previous = snapshots[profile.id]
            consecutiveConnectionFailures[profile.id] = nil
            snapshots[profile.id] = snapshot
            lastSuccessfulRefresh[profile.id] = snapshot.capturedAt
            history[profile.id, default: []].append(MetricSample(snapshot: snapshot))
            history[profile.id] = Array(history[profile.id, default: []].suffix(720))

            let transition = HealthTransitionEvaluator.evaluate(previous: previous, current: snapshot)
            if transition.shouldRecordEvent {
                events.insert(MonitorEvent(server: profile, level: transition.eventLevel, message: snapshot.summary), at: 0)
                if transition.shouldNotify {
                    Task { await notificationService.notifyCritical(server: profile, snapshot: snapshot) }
                }
            }

        case let .failure(profile, message):
            let snapshot = ServerSnapshot.unreachable(message: message)
            let previous = snapshots[profile.id]
            let failureCount = (consecutiveConnectionFailures[profile.id] ?? 0) + 1
            consecutiveConnectionFailures[profile.id] = failureCount
            snapshots[profile.id] = snapshot
            let transition = HealthTransitionEvaluator.evaluate(
                previous: previous,
                current: snapshot,
                consecutiveConnectionFailures: failureCount
            )
            if transition.shouldRecordEvent {
                let eventMessage = failureCount == 1
                    ? "SSH bağlantısı doğrulanıyor: \(message)"
                    : message
                events.insert(MonitorEvent(server: profile, level: transition.eventLevel, message: eventMessage), at: 0)
                if transition.shouldNotify {
                    Task { await notificationService.notifyCritical(server: profile, snapshot: snapshot) }
                }
            }
        }

        events = Array(events.prefix(250))
    }

    private func persistProfiles() {
        do {
            try ConfigurationStore.saveProfiles(profiles)
        } catch {
            let fallback = profiles.first ?? .example
            events.insert(MonitorEvent(server: fallback, level: .critical, message: "Sunucu ayarları kaydedilemedi: \(error.localizedDescription)"), at: 0)
        }
    }

    private func persistMonitoringState() {
        do {
            try MonitoringStore.save(history: history, events: events)
        } catch {
            let fallback = profiles.first ?? .example
            events.insert(MonitorEvent(server: fallback, level: .critical, message: "İzleme geçmişi kaydedilemedi: \(error.localizedDescription)"), at: 0)
        }
    }
}

private enum ProbeOutcome: Sendable {
    case success(ServerProfile, ServerSnapshot)
    case failure(ServerProfile, String)

    var profile: ServerProfile {
        switch self {
        case let .success(profile, _), let .failure(profile, _): return profile
        }
    }
}
