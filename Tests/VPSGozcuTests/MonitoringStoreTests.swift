import Foundation
import Testing
@testable import VPSGozcu

struct MonitoringStoreTests {
    @Test func archiveRoundTripPreservesHistoryAndEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VPSGozcuTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("monitoring-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let server = ServerProfile(name: "Test VPS", sshTarget: "test-vps")
        let snapshot = try ProbeParser.parse("""
        hostname=test-vps
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
        failed_services=0
        health_configured=no
        full_backup_configured=no
        data_backup_configured=no
        docker_available=no
        docker_query_ok=no
        containers_begin
        containers_end
        """)
        let sample = MetricSample(snapshot: snapshot)
        let event = MonitorEvent(server: server, level: .info, message: "Test olayı")

        try MonitoringStore.save(history: [server.id: [sample]], events: [event], to: fileURL)
        let loaded = MonitoringStore.load(from: fileURL)

        let loadedSample = try #require(loaded.historyByServer[server.id]?.first)
        let loadedEvent = try #require(loaded.events.first)
        #expect(loadedSample.id == sample.id)
        #expect(loadedSample.cpuPercent == sample.cpuPercent)
        #expect(abs(loadedSample.date.timeIntervalSince(sample.date)) < 1)
        #expect(loadedEvent.id == event.id)
        #expect(loadedEvent.message == event.message)
        #expect(abs(loadedEvent.date.timeIntervalSince(event.date)) < 1)
    }

    @Test func corruptArchiveFailsClosedToEmptyState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VPSGozcuTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("monitoring-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: fileURL)

        let loaded = MonitoringStore.load(from: fileURL)
        #expect(loaded.histories.isEmpty)
        #expect(loaded.events.isEmpty)
    }
}
