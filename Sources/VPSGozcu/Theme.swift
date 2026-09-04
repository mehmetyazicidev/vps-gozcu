import SwiftUI

enum AppTheme {
    // Obsidian Telemetry palette: deep chassis surfaces with luminous status signals.
    static let background = Color(hex: 0x080B11)
    static let surface = Color(hex: 0x10141A)
    static let panel = Color(hex: 0x131924)
    static let panelElevated = Color(hex: 0x1A2232)
    static let border = Color(hex: 0x232B3E)
    static let borderLight = Color(hex: 0x303B54)
    static let textSecondary = Color(hex: 0x94A3B8)
    static let textMuted = Color(hex: 0x64748B)
    static let accent = Color(hex: 0xFF8800)
    static let accentGlow = Color(hex: 0xFB923C)
    static let healthy = Color(hex: 0x10B981)
    static let info = Color(hex: 0x06B6D4)
    static let warning = Color(hex: 0xF59E0B)
    static let critical = Color(hex: 0xF43F5E)

    static func color(for health: ServerHealth) -> Color {
        switch health {
        case .unknown: textMuted
        case .healthy: healthy
        case .warning: warning
        case .critical: critical
        }
    }

    static func metricColor(for title: String) -> Color {
        switch title {
        case "CPU": info
        case "Bellek": healthy
        case "Disk": accentGlow
        case "Load", "Uptime", "Kernel": textSecondary
        default: textSecondary
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
