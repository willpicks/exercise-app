import RunTogetherKit
import SwiftUI

struct WatchSessionView: View {

    @State private var model = WatchSessionModel()

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if model.handoff == nil {
                waiting
            } else {
                running
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.activityTitle)
        .onAppear { model.activate() }
    }

    private var waiting: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Start a session on your phone")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var running: some View {
        VStack(spacing: 4) {
            Text(model.activityTitle)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .tracking(1)

            Text(model.countdown)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            if let stage = model.handoff?.stage {
                Text(stage.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .foregroundStyle(.white)
    }

    private var background: some View {
        let colors: [Color] = model.isRunning
            ? [Color(red: 0.85, green: 0.28, blue: 0.20), Color(red: 0.45, green: 0.10, blue: 0.08)]
            : [Color(red: 0.11, green: 0.35, blue: 0.52), Color(red: 0.05, green: 0.15, blue: 0.26)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

#Preview {
    WatchSessionView()
}
