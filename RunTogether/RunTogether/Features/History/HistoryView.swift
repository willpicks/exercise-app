import RunTogetherKit
import SwiftUI

/// Sessions you've done, with the recorded workout attached where one matched.
struct HistoryView: View {

    @Environment(SessionLog.self) private var log
    @Environment(RunnerStore.self) private var runners
    @State private var importer = WorkoutImporter()

    var body: some View {
        List {
            if !importer.isAvailable {
                Text("Health data isn't available on this device.")
                    .foregroundStyle(.secondary)
            }

            switch importer.status {
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            case .importing:
                Label("Checking Health…", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }

            if log.sessions.isEmpty {
                Text("No sessions yet. Start one from Today and it'll appear here.")
                    .foregroundStyle(.secondary)
            }

            ForEach(log.sessionsNewestFirst) { session in
                row(for: session)
            }
        }
        .navigationTitle("History")
        .refreshable {
            await importer.importWorkouts(into: log, runnerID: runners.me.id)
        }
        .task {
            await importer.requestAccess()
            await importer.importWorkouts(into: log, runnerID: runners.me.id)
            importer.observeChanges(into: log, runnerID: runners.me.id)
        }
    }

    @ViewBuilder
    private func row(for session: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer()
                Text(session.kind == .paired ? "Together" : "Solo")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }

            Text(session.stage.summary)
                .font(.subheadline)
                .monospacedDigit()

            if !session.ranToCompletion && session.endedAt != nil {
                Label("Stopped early", systemImage: "stop.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let run = log.run(forSession: session.id) {
                Label(summary(of: run), systemImage: "heart.text.square")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if session.endedAt != nil {
                Label("No workout matched", systemImage: "questionmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func summary(of run: CompletedRun) -> String {
        var parts: [String] = []
        if let metres = run.distanceMeters {
            parts.append(String(format: "%.2f km", metres / 1_000))
        }
        parts.append("\(Int(run.duration / 60)) min")
        if let heartRate = run.averageHeartRate {
            parts.append("\(Int(heartRate.rounded())) bpm")
        }
        return parts.joined(separator: "  ·  ")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(SessionLog())
    .environment(RunnerStore())
}
