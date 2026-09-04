import SwiftUI

struct ServerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var sshTarget: String
    @State private var appDirectory: String
    @State private var healthURL: String
    @State private var fullBackupRoot: String
    @State private var dataBackupRoot: String
    @State private var diskWarningPercent: String
    @State private var diskCriticalPercent: String
    @State private var backupWarningHours: String
    @State private var backupCriticalHours: String
    @State private var tlsWarningDays: String
    @State private var tlsCriticalDays: String
    @State private var isEnabled: Bool

    private let profileID: UUID
    private let isEditing: Bool
    let onSave: (ServerProfile) -> Void

    init(profile: ServerProfile? = nil, onSave: @escaping (ServerProfile) -> Void) {
        let source = profile ?? ServerProfile(name: "", sshTarget: "")
        let thresholds = source.thresholds ?? .default
        profileID = source.id
        isEditing = profile != nil
        self.onSave = onSave
        _name = State(initialValue: source.name)
        _sshTarget = State(initialValue: source.sshTarget)
        _appDirectory = State(initialValue: source.appDirectory)
        _healthURL = State(initialValue: source.healthURL)
        _fullBackupRoot = State(initialValue: source.fullBackupRoot)
        _dataBackupRoot = State(initialValue: source.dataBackupRoot)
        _diskWarningPercent = State(initialValue: Self.format(thresholds.diskWarningPercent))
        _diskCriticalPercent = State(initialValue: Self.format(thresholds.diskCriticalPercent))
        _backupWarningHours = State(initialValue: Self.format(thresholds.backupWarningHours))
        _backupCriticalHours = State(initialValue: Self.format(thresholds.backupCriticalHours))
        _tlsWarningDays = State(initialValue: Self.format(thresholds.tlsWarningDays))
        _tlsCriticalDays = State(initialValue: Self.format(thresholds.tlsCriticalDays))
        _isEnabled = State(initialValue: source.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(isEditing ? "Sunucuyu Düzenle" : "Sunucu Ekle")
                .font(.title2.weight(.semibold))

            Form {
                Section("Bağlantı") {
                    TextField("Görünen ad", text: $name)
                    TextField("SSH hedefi / alias", text: $sshTarget)
                    TextField("Uygulama dizini", text: $appDirectory)
                    TextField("Health URL", text: $healthURL)
                }

                Section("Yedek yolları") {
                    TextField("Full backup kökü", text: $fullBackupRoot)
                    TextField("Veri backup kökü", text: $dataBackupRoot)
                }

                Section("Disk eşikleri") {
                    LabeledContent("Uyarı yüzdesi") {
                        TextField("80", text: $diskWarningPercent)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Kritik yüzde") {
                        TextField("90", text: $diskCriticalPercent)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Yedek ve TLS eşikleri") {
                    thresholdField("Yedek uyarısı (saat)", text: $backupWarningHours, placeholder: "26")
                    thresholdField("Yedek kritik (saat)", text: $backupCriticalHours, placeholder: "48")
                    thresholdField("TLS uyarısı (gün)", text: $tlsWarningDays, placeholder: "30")
                    thresholdField("TLS kritik (gün)", text: $tlsCriticalDays, placeholder: "7")
                    if !thresholdsAreValid {
                        Text("Disk ve yedek uyarı eşikleri kritik eşikten düşük; TLS kritik eşiği uyarı eşiğinden düşük olmalı.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Toggle("İzlemeyi etkinleştir", isOn: $isEnabled)
            }
            .formStyle(.grouped)

            HStack {
                Text("SSH parolası veya private key uygulamaya kaydedilmez.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("İptal") { dismiss() }
                Button(isEditing ? "Güncelle" : "Kaydet") {
                    onSave(makeProfile())
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 580)
    }

    private var parsedThresholds: MonitoringThresholds? {
        guard let warning = Double(diskWarningPercent.replacingOccurrences(of: ",", with: ".")),
              let critical = Double(diskCriticalPercent.replacingOccurrences(of: ",", with: ".")),
              let backupWarning = Double(backupWarningHours.replacingOccurrences(of: ",", with: ".")),
              let backupCritical = Double(backupCriticalHours.replacingOccurrences(of: ",", with: ".")),
              let tlsWarning = Double(tlsWarningDays.replacingOccurrences(of: ",", with: ".")),
              let tlsCritical = Double(tlsCriticalDays.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        return MonitoringThresholds(
            diskWarningPercent: warning,
            diskCriticalPercent: critical,
            backupWarningHours: backupWarning,
            backupCriticalHours: backupCritical,
            tlsWarningDays: tlsWarning,
            tlsCriticalDays: tlsCritical
        )
    }

    private var thresholdsAreValid: Bool {
        parsedThresholds?.isValid == true
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sshTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && thresholdsAreValid
    }

    private func makeProfile() -> ServerProfile {
        ServerProfile(
            id: profileID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sshTarget: sshTarget.trimmingCharacters(in: .whitespacesAndNewlines),
            appDirectory: appDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
            healthURL: healthURL.trimmingCharacters(in: .whitespacesAndNewlines),
            fullBackupRoot: fullBackupRoot.trimmingCharacters(in: .whitespacesAndNewlines),
            dataBackupRoot: dataBackupRoot.trimmingCharacters(in: .whitespacesAndNewlines),
            thresholds: parsedThresholds ?? .default,
            isEnabled: isEnabled
        )
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func thresholdField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        LabeledContent(title) {
            TextField(placeholder, text: text)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
        }
    }
}
