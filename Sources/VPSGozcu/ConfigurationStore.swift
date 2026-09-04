import Foundation

enum ConfigurationStore {
    static func loadProfiles() -> [ServerProfile] {
        guard let data = try? Data(contentsOf: fileURL),
              let profiles = try? JSONDecoder().decode([ServerProfile].self, from: data),
              !profiles.isEmpty else {
            return [.example]
        }
        return profiles
    }

    static func saveProfiles(_ profiles: [ServerProfile]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: fileURL, options: [.atomic])
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("VPSGozcu", isDirectory: true)
            .appendingPathComponent("servers.json")
    }
}
