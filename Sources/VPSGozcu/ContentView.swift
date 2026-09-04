import Charts
import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let profile = model.selectedProfile {
                ServerDetailView(
                    profile: profile,
                    snapshot: model.snapshots[profile.id],
                    lastSuccessfulAt: model.lastSuccessfulRefresh[profile.id],
                    samples: model.history[profile.id] ?? [],
                    events: model.events.filter { $0.serverID == profile.id }
                )
            } else {
                ContentUnavailableView("Sunucu seçilmedi", systemImage: "server.rack")
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.showingAddServer = true
                } label: {
                    Label("Sunucu Ekle", systemImage: "plus")
                }

                Button {
                    model.editingProfile = model.selectedProfile
                } label: {
                    Label("Sunucuyu Düzenle", systemImage: "pencil")
                }
                .disabled(model.selectedProfile == nil)

                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Label("Şimdi Tara", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshing || model.enabledProfiles.isEmpty)
            }
        }
        .preferredColorScheme(.dark)
        .background(AppTheme.background)
        .sheet(isPresented: $model.showingAddServer) {
            ServerEditorView { profile in
                model.addProfile(profile)
            }
        }
        .sheet(item: $model.editingProfile) { profile in
            ServerEditorView(profile: profile) { updatedProfile in
                model.updateProfile(updatedProfile)
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            SidebarBrandHeader()

            List(selection: $model.selectedServerID) {
                Section("Sunucular") {
                    ForEach(model.profiles) { profile in
                        ServerSidebarRow(profile: profile, snapshot: model.snapshots[profile.id])
                            .tag(profile.id)
                            .contextMenu {
                                Button("Düzenle") {
                                    model.editingProfile = profile
                                }
                                Button(profile.isEnabled ? "İzlemeyi Durdur" : "İzlemeyi Başlat") {
                                    model.setEnabled(profile, enabled: !profile.isEnabled)
                                }
                                Divider()
                                Button("Sil", role: .destructive) {
                                    model.deleteProfile(profile)
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface)

            Divider()

            HStack {
                StatusCount(color: .red, value: model.criticalCount, label: "kritik")
                Spacer()
                StatusCount(color: .orange, value: model.warningCount, label: "uyarı")
                Spacer()
                StatusCount(color: .secondary, value: model.unknownCount, label: "bilinmiyor")
            }
            .background(AppTheme.surface)
            .padding(12)
        }
        .background(AppTheme.surface)
    }
}

private struct SidebarBrandHeader: View {
    private var icon: NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "server.rack")
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .frame(width: 38, height: 38)
            .background(AppTheme.panelElevated, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppTheme.borderLight.opacity(0.75), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("VPSGözcü")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("0.2")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppTheme.accentGlow)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                }
                Text("Sunucu Telemetri Kalkanı")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border.opacity(0.8)).frame(height: 1)
        }
    }
}

private struct ServerSidebarRow: View {
    let profile: ServerProfile
    let snapshot: ServerSnapshot?

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(profile.isEnabled ? AppTheme.color(for: snapshot?.health ?? .unknown) : .secondary.opacity(0.35))
                .frame(width: 9, height: 9)
                .shadow(color: profile.isEnabled ? AppTheme.color(for: snapshot?.health ?? .unknown).opacity(0.65) : .clear, radius: 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(profile.sshTarget)
                        .font(.caption2.monospaced())
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Text(profile.isEnabled ? (snapshot?.summary ?? "Henüz taranmadı") : "İzleme kapalı")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct StatusCount: View {
    let color: Color
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(value) \(label)").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ServerDetailView: View {
    @EnvironmentObject private var model: AppModel
    let profile: ServerProfile
    let snapshot: ServerSnapshot?
    let lastSuccessfulAt: Date?
    let samples: [MetricSample]
    let events: [MonitorEvent]
    @State private var showingMaintenancePlan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let snapshot {
                    metrics(snapshot)
                    HealthChecksPanel(checks: snapshot.checks)
                    MetricsChart(samples: samples)
                    UpdatesAndBackups(snapshot: snapshot) {
                        showingMaintenancePlan = true
                    }
                    ContainersPanel(containers: snapshot.containers)
                    EventTimeline(events: events)
                } else {
                    ContentUnavailableView(
                        profile.isEnabled ? "İlk tarama bekleniyor" : "İzleme kapalı",
                        systemImage: "waveform.path.ecg",
                        description: Text(profile.isEnabled ? "Şimdi Tara ile ilk durumu alabilirsiniz." : "Sunucu menüsünden izlemeyi başlatın.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
        }
        .background(AppTheme.background)
        .navigationTitle(profile.name)
        .sheet(isPresented: $showingMaintenancePlan) {
            if let snapshot {
                MaintenancePlanView(
                    profile: profile,
                    plan: MaintenancePlanner.make(profile: profile, snapshot: snapshot)
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot?.hostname ?? profile.sshTarget)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(snapshot?.summary ?? "Sunucu henüz sorgulanmadı")
                    .font(.callout)
                    .foregroundStyle(AppTheme.textSecondary)
                if let lastSuccessfulAt {
                    HStack(spacing: 6) {
                        Text("Son başarılı tarama")
                        Text(lastSuccessfulAt.formatted(date: .abbreviated, time: .standard))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.textMuted)
                }
            }
            Spacer()
            HealthBadge(health: snapshot?.health ?? .unknown)
        }
        .padding(.bottom, 2)
    }

    private func metrics(_ snapshot: ServerSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
            MetricCard(title: "CPU", value: snapshot.cpuPercent, suffix: "%", systemImage: "cpu")
            MetricCard(title: "Bellek", value: snapshot.memoryPercent, suffix: "%", systemImage: "memorychip")
            MetricCard(title: "Disk", value: snapshot.diskPercent, suffix: "%", systemImage: "internaldrive")
            MetricCard(title: "Load", value: snapshot.loadOneMinute, suffix: "", systemImage: "gauge.with.dots.needle.67percent")
            LiveUptimeCard(snapshot: snapshot)
            TextMetricCard(title: "Kernel", value: snapshot.kernel, systemImage: "shippingbox")
        }
    }
}

private struct LiveUptimeCard: View {
    let snapshot: ServerSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            TextMetricCard(
                title: "Uptime",
                value: formattedUptime(at: context.date),
                systemImage: "clock"
            )
        }
    }

    private func formattedUptime(at date: Date) -> String {
        guard let measuredSeconds = snapshot.uptimeSeconds else { return "Bilinmiyor" }
        let elapsed = max(0, Int(date.timeIntervalSince(snapshot.capturedAt)))
        let total = measuredSeconds + elapsed
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if days > 0 {
            return String(format: "%dg %02dsa %02ddk", days, hours, minutes)
        }
        if hours > 0 {
            return String(format: "%dsa %02ddk %02dsn", hours, minutes, seconds)
        }
        return String(format: "%ddk %02dsn", minutes, seconds)
    }
}

private struct HealthBadge: View {
    let health: ServerHealth

    var body: some View {
        Label(health.title, systemImage: symbol)
            .font(.callout.weight(.semibold))
            .foregroundStyle(AppTheme.color(for: health))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(AppTheme.color(for: health).opacity(0.12), in: Capsule())
    }

    private var symbol: String {
        switch health {
        case .healthy: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Double?
    let suffix: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(AppTheme.textSecondary)
            if let value {
                Text("\(value, specifier: value.rounded() == value ? "%.0f" : "%.1f")\(suffix)")
                    .font(.system(size: 27, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.metricColor(for: title))
            } else {
                Text("Bilinmiyor")
                    .font(.title3.monospaced().weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.metricColor(for: title).opacity(0.75))
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.horizontal, 12)
        }
    }
}

private struct TextMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.metricColor(for: title))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct HealthChecksPanel: View {
    let checks: [HealthCheck]

    private var findings: [HealthCheck] {
        checks.filter { $0.health != .healthy || $0.isInformational }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Kontrol Sonuçları", systemImage: "checklist.checked")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(checks.filter { $0.health == .healthy }.count)/\(checks.count) temiz")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1)
                    }
            }

            if findings.isEmpty {
                Label("Tüm zorunlu kontroller başarılı", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.healthy)
            } else {
                ForEach(findings) { check in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: symbol(for: check))
                            .foregroundStyle(color(for: check))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(check.title).fontWeight(.medium)
                            Text(check.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        Text(check.isInformational ? "Bilgi" : check.health.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: check))
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(18)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func symbol(for check: HealthCheck) -> String {
        if check.isInformational { return "info.circle.fill" }
        return switch check.health {
        case .healthy: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private func color(for check: HealthCheck) -> Color {
        check.isInformational ? .accentColor : AppTheme.color(for: check.health)
    }
}

private struct MetricsChart: View {
    let samples: [MetricSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Kaynak Kullanımı").font(.headline.weight(.semibold))
                Text("(Son 1 Saat)")
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
            }
            Chart(samples) { sample in
                if let cpu = sample.cpuPercent {
                    LineMark(x: .value("Zaman", sample.date), y: .value("CPU", cpu), series: .value("Metrik", "CPU"))
                        .foregroundStyle(by: .value("Metrik", "CPU"))
                }
                if let memory = sample.memoryPercent {
                    LineMark(x: .value("Zaman", sample.date), y: .value("Bellek", memory), series: .value("Metrik", "Bellek"))
                        .foregroundStyle(by: .value("Metrik", "Bellek"))
                }
                if let disk = sample.diskPercent {
                    LineMark(x: .value("Zaman", sample.date), y: .value("Disk", disk), series: .value("Metrik", "Disk"))
                        .foregroundStyle(by: .value("Metrik", "Disk"))
                }
            }
            .chartYScale(domain: 0...100)
            .chartForegroundStyleScale([
                "CPU": AppTheme.info,
                "Bellek": AppTheme.healthy,
                "Disk": AppTheme.accentGlow
            ])
            .chartLegend(position: .top, alignment: .trailing, spacing: 14)
            .chartPlotStyle { plot in
                plot
                    .background(AppTheme.surface.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(height: 220)
        }
        .padding(18)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct UpdatesAndBackups: View {
    let snapshot: ServerSnapshot
    let onMaintenancePlan: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            panel(title: "Güncellemeler", icon: "arrow.down.circle") {
                row("Toplam paket", snapshot.updatesTotal.map(String.init) ?? "Bilinmiyor")
                row("Güvenlik", snapshot.securityUpdates.map(String.init) ?? "Bilinmiyor")
                row("Reboot", snapshot.rebootRequired.map { $0 ? "Gerekli" : "Gerekmiyor" } ?? "Bilinmiyor")
                row("Başarısız servis", snapshot.failedServices.map(String.init) ?? "Bilinmiyor")
                row("Health HTTP", snapshot.healthHTTPCode.map(String.init) ?? "Bilinmiyor")
            }

            panel(title: "Yedekler ve TLS", icon: "externaldrive.badge.timemachine") {
                row("Son full", snapshot.latestFullBackup ?? "Bulunamadı")
                row("Full yaşı", ageText(snapshot.latestFullBackupDate, relativeTo: snapshot.capturedAt))
                row("Son veri", snapshot.latestDataBackup ?? "Bulunamadı")
                row("Veri yaşı", ageText(snapshot.latestDataBackupDate, relativeTo: snapshot.capturedAt))
                row("TLS kalan", snapshot.tlsDaysRemaining.map { "\($0) gün" } ?? "Bilinmiyor")
                Text("Bakım eylemleri yedek-first ve kullanıcı onayıyla çalışır.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 5)
                Button("Bakım planını gözden geçir", action: onMaintenancePlan)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding(.top, 3)
            }
        }
    }

    private func panel<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout.monospacedDigit()).lineLimit(1)
        }
    }

    private func ageText(_ date: Date?, relativeTo referenceDate: Date) -> String {
        guard let date else { return "Bilinmiyor" }
        let hours = max(0, Int(referenceDate.timeIntervalSince(date) / 3_600))
        if hours < 24 { return "\(hours) saat" }
        return "\(hours / 24) gün \(hours % 24) saat"
    }
}

private struct ContainersPanel: View {
    let containers: [ContainerStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Docker Container’ları", systemImage: "shippingbox.fill").font(.headline)
            if containers.isEmpty {
                Text("Container bulunamadı veya Docker erişimi yok.").foregroundStyle(.secondary)
            } else {
                ForEach(containers) { container in
                    HStack {
                        Circle()
                            .fill(container.looksHealthy ? AppTheme.healthy : AppTheme.critical)
                            .frame(width: 8, height: 8)
                            .shadow(color: (container.looksHealthy ? AppTheme.healthy : AppTheme.critical).opacity(0.6), radius: 4)
                        Text(container.name)
                            .font(.callout.monospaced())
                            .fontWeight(.medium)
                        Spacer()
                        Text(container.status)
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct EventTimeline: View {
    let events: [MonitorEvent]
    @State private var isExpanded = false

    private let collapsedLimit = 3

    private var visibleEvents: [MonitorEvent] {
        isExpanded ? events : Array(events.prefix(collapsedLimit))
    }

    private var hiddenEventCount: Int {
        max(0, events.count - collapsedLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Olay Akışı", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.headline.weight(.semibold))
                Spacer()
                if !events.isEmpty {
                    Text("\(events.count) kayıt")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            if events.isEmpty {
                Text("Henüz olay yok.")
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                if isExpanded {
                    ScrollView(.vertical) {
                        eventRows
                    }
                    .frame(maxHeight: 240)
                    .scrollIndicators(.automatic)
                } else {
                    eventRows
                }

                if hiddenEventCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    label: {
                        Label(
                            isExpanded ? "Olay akışını daralt" : "Tüm olayları göster (\(hiddenEventCount))",
                            systemImage: isExpanded ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accentGlow)
                    .padding(.top, 2)
                }
            }
        }
        .padding(18)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var eventRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleEvents) { event in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(color(for: event.level))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.message)
                            .font(.callout)
                        Text(event.date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                if event.id != visibleEvents.last?.id {
                    Divider()
                        .overlay(AppTheme.border.opacity(0.65))
                }
            }
        }
    }

    private func color(for level: MonitorEvent.Level) -> Color {
        switch level {
        case .critical: .red
        case .warning: .orange
        case .unknown: .secondary
        case .info: .blue
        }
    }
}
