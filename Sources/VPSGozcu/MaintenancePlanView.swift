import SwiftUI

struct MaintenancePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    let profile: ServerProfile
    let plan: MaintenancePlan
    @State private var pendingAction: MaintenanceAction?
    @State private var isExecuting = false
    @State private var executionMessage: String?
    private let executor = MaintenanceExecutor()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Bakım planı", systemImage: "wrench.and.screwdriver")
                    .font(.title2.weight(.semibold))
                Spacer()
                Label(plan.isReady ? "Ön koşullar hazır" : "Bekletiliyor", systemImage: plan.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(plan.isReady ? .green : .orange)
            }

            Text("Hedef: \(plan.targetName) · \(plan.sshTarget)")
                .foregroundStyle(.secondary)

            GroupBox("Kapsam") {
                VStack(alignment: .leading, spacing: 8) {
                    row("Bekleyen paket", "\(plan.packageCount)")
                    row("Güvenlik paketi", "\(plan.securityPackageCount)")
                    row("Reboot", plan.rebootRequired ? "Gerekli" : "Gerekmiyor")
                }
                .padding(4)
            }

            GroupBox("Güvenlik kapısı") {
                if plan.requiresMaintenance, plan.blockers.isEmpty {
                    Label("Güncel ölçüm ve yedek koşulları sağlandı.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(4)
                } else if !plan.blockers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.blockers, id: \.self) { blocker in
                            Label(blocker, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(4)
                } else {
                    Label("Güncelleme veya reboot gerekmiyor.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(4)
                }
            }

            Text("Güncelleme ve reboot ayrı işlemlerdir. Her işlem öncesinde yedek yaşı uzakta yeniden doğrulanır.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let executionMessage {
                Text(executionMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Kapat") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if plan.packageCount > 0 {
                    Button("Paketleri güncelle") { pendingAction = .updatePackages }
                        .disabled(!plan.isReady || isExecuting)
                }
                if plan.rebootRequired {
                    Button("Yeniden başlat") { pendingAction = .reboot }
                        .disabled(!plan.isReady || isExecuting)
                }
            }
        }
        .padding(24)
        .frame(width: 540)
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text("\(action.title) çalıştırılsın mı?"),
                message: Text("Hedef: \(profile.name) (\(profile.sshTarget))\nBu işlem üretim sunucusunda değişiklik yapar. Yedek ön koşulu uzakta yeniden doğrulanacaktır."),
                primaryButton: .destructive(Text("Onayla")) {
                    execute(action)
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout.monospacedDigit())
        }
    }

    private func execute(_ action: MaintenanceAction) {
        isExecuting = true
        executionMessage = "\(action.title) çalıştırılıyor..."
        Task {
            do {
                _ = try await executor.execute(profile: profile, plan: plan, action: action)
                executionMessage = "\(action.title) tamamlandı. Yeni durumu doğrulamak için tekrar tarayın."
                if action == .updatePackages {
                    await model.refreshAll()
                }
            } catch {
                executionMessage = error.localizedDescription
            }
            isExecuting = false
        }
    }
}
