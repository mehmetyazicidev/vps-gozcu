import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VPS Gözcü")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Label("İzleme açık", systemImage: "circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.healthy)
            }
            Text("\(model.enabledProfiles.count) sunucu, \(model.criticalCount) kritik, \(model.warningCount) uyarı, \(model.unknownCount) bilinmiyor")
                .foregroundStyle(AppTheme.textSecondary)
            Divider()
            ForEach(model.enabledProfiles.prefix(8)) { profile in
                let health = model.snapshots[profile.id]?.health ?? .unknown
                HStack {
                    Circle()
                        .fill(AppTheme.color(for: health))
                        .frame(width: 8, height: 8)
                    Text(profile.name).foregroundStyle(.white)
                    Spacer()
                    Text(model.snapshots[profile.id]?.health.title ?? "Bekliyor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.color(for: health))
                }
                .padding(.vertical, 2)
            }
            Divider()
            HStack {
                Button("Ana Pencereyi Aç") {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .buttonStyle(MenuBarActionButtonStyle())
                Spacer()
                Button("Şimdi Tara") {
                    Task { await model.refreshAll() }
                }
                .disabled(model.isRefreshing || model.enabledProfiles.isEmpty)
                .buttonStyle(MenuBarActionButtonStyle(accent: true))
            }
            Divider()
            Button("VPS Gözcü'den Çık") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.critical)
        }
        .padding(14)
        .frame(width: 330)
        .background(AppTheme.surface)
        .preferredColorScheme(.dark)
    }
}

private struct MenuBarActionButtonStyle: ButtonStyle {
    var accent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(accent ? AppTheme.accentGlow : .white)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                (configuration.isPressed ? AppTheme.accent.opacity(0.22) : AppTheme.panelElevated),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent ? AppTheme.accent.opacity(0.52) : AppTheme.borderLight.opacity(0.8), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}
