import Foundation

struct MonitoringArchive: Codable, Sendable {
    struct ServerHistory: Codable, Sendable {
        let serverID: UUID
        let samples: [MetricSample]
    }

    let histories: [ServerHistory]
    let events: [MonitorEvent]

    static let empty = MonitoringArchive(histories: [], events: [])

    var historyByServer: [UUID: [MetricSample]] {
        Dictionary(uniqueKeysWithValues: histories.map { ($0.serverID, $0.samples) })
    }
}

enum MonitoringStore {
    static func load(from fileURL: URL = defaultFileURL) -> MonitoringArchive {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .empty
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(MonitoringArchive.self, from: data)) ?? .empty
    }

    static func save(
        history: [UUID: [MetricSample]],
        events: [MonitorEvent],
        to fileURL: URL = defaultFileURL
    ) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let archive = MonitoringArchive(
            histories: history
                .map { MonitoringArchive.ServerHistory(serverID: $0.key, samples: Array($0.value.suffix(720))) }
                .sorted { $0.serverID.uuidString < $1.serverID.uuidString },
            events: Array(events.prefix(250))
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: fileURL, options: [.atomic])
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("VPSGozcu", isDirectory: true)
            .appendingPathComponent("monitoring-state.json")
    }
}
