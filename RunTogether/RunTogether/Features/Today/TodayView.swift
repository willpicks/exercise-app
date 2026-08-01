import RunTogetherKit
import SwiftUI

/// The home screen: both ladders side by side, and the two ways to start.
struct TodayView: View {

    @State private var store = RunnerStore()
    @State private var pending: PendingSession?
    /// Debug only. Off in release; at 60 a full session plays out in seconds.
    @State private var accelerate = false

    private var pairedStage: PlanStage {
        SessionComposer.compose(store.dad.currentStage, store.me.currentStage)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Together") {
                    stageRow(
                        title: "Shared lane",
                        subtitle: pairedStage.summary,
                        detail: "\(PlanStage.minutes(pairedStage.totalRunSeconds)) running · "
                            + "\(PlanStage.minutes(pairedStage.totalSeconds)) total"
                    )
                    Button {
                        pending = PendingSession(
                            plan: SessionComposer.pairedPlan(for: (store.dad, store.me)),
                            runnerID: store.me.id
                        )
                    } label: {
                        Label("Start paired session", systemImage: "figure.run.motion")
                    }

                    Text("Both phones start this by hand for now. Automatic start "
                         + "sync arrives with the shared feed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Solo") {
                    Button {
                        pending = PendingSession(
                            plan: SessionComposer.soloPlan(for: store.me),
                            runnerID: store.me.id
                        )
                    } label: {
                        Label("Start my session", systemImage: "figure.run")
                    }
                }

                ladderSection(for: store.me, title: "My ladder")
                ladderSection(for: store.dad, title: "Dad's ladder")

                #if DEBUG
                Section("Debug") {
                    Toggle("Run at 60x speed", isOn: $accelerate)
                }
                #endif
            }
            .navigationTitle("Run Together")
        }
        .fullScreenCover(item: $pending) { session in
            SessionRunnerView(
                plan: session.plan,
                runnerID: session.runnerID,
                speedMultiplier: accelerate ? 60 : 1
            )
        }
    }

    // MARK: Pieces

    private func ladderSection(for runner: Runner, title: String) -> some View {
        Section(title) {
            stageRow(
                title: "Stage \(runner.currentStage.index + 1) of \(runner.spec.stageCount)",
                subtitle: runner.currentStage.summary,
                detail: "\(PlanStage.minutes(runner.currentStage.totalRunSeconds)) running"
            )

            if let attribution = runner.spec.governance.attribution() {
                Label(attribution, systemImage: "cross.case")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Back a stage") { store.stepBack(runner.id) }
                    .disabled(runner.currentStageIndex == 0)
                Spacer()
                Button("Advance") { store.advance(runner.id) }
                    .disabled(runner.currentStageIndex >= runner.spec.stageCount - 1)
            }
            .buttonStyle(.bordered)
            .font(.callout)

            if runner.spec.governance.requiresExplicitAdvance {
                Text("Advance only when the previous week was symptom-free.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stageRow(title: String, subtitle: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).monospacedDigit()
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Wrapper so `fullScreenCover(item:)` has something `Identifiable` to hold.
private struct PendingSession: Identifiable {
    let id = UUID()
    let plan: PairedPlan
    let runnerID: RunnerID
}

private extension PlanStage {
    static func minutes(_ seconds: Int) -> String {
        "\(Int((Double(seconds) / 60).rounded())) min"
    }
}

#Preview {
    TodayView()
}
