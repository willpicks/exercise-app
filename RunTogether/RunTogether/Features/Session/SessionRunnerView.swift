import RunTogetherKit
import SwiftUI
import UIKit

/// The in-run screen. Readable at arm's length, mid-stride, in sunlight — so
/// one enormous word, one enormous number, and nothing else competing.
struct SessionRunnerView: View {

    @State private var model: SessionRunnerModel
    @Environment(\.dismiss) private var dismiss

    init(plan: PairedPlan, runnerID: RunnerID, speedMultiplier: Double = 1) {
        _model = State(
            initialValue: SessionRunnerModel(
                plan: plan,
                runnerID: runnerID,
                speedMultiplier: speedMultiplier
            )
        )
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 24) {
                header

                Spacer()

                Text(model.currentActivityTitle.uppercased())
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .tracking(2)

                Text(model.countdownText)
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if let next = model.nextUpText {
                    Text("Next  ·  \(next)")
                        .font(.headline)
                        .opacity(0.7)
                }

                Spacer()

                progressBar
                footer
            }
            .padding(28)
            .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.25), value: model.currentActivityTitle)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            model.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.stop()
        }
    }

    private var background: some View {
        let isRunning = model.progress?.current?.activity == .run
        return LinearGradient(
            colors: isRunning
                ? [Color(red: 0.85, green: 0.28, blue: 0.20), Color(red: 0.55, green: 0.12, blue: 0.10)]
                : [Color(red: 0.11, green: 0.35, blue: 0.52), Color(red: 0.06, green: 0.18, blue: 0.30)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var header: some View {
        HStack {
            Text(model.stage.summary)
                .font(.subheadline.weight(.medium))
                .opacity(0.8)
            Spacer()
            Button {
                model.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .opacity(0.7)
            }
            .accessibilityLabel("End session")
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(.white)
                    .frame(width: geometry.size.width * model.fractionComplete)
            }
        }
        .frame(height: 6)
    }

    private var footer: some View {
        HStack {
            Text(model.elapsedText).monospacedDigit()
            Spacer()
            Text(model.totalText).monospacedDigit().opacity(0.6)
        }
        .font(.callout.weight(.medium))
    }
}

#Preview {
    SessionRunnerView(
        plan: SessionComposer.soloPlan(for: RunnerStore.defaultMe),
        runnerID: RunnerStore.defaultMe.id,
        speedMultiplier: 60
    )
}
