import AVFoundation
import Foundation

/// Speaks session cues over whatever else is playing.
///
/// The audio session is configured to duck rather than interrupt, so music
/// keeps playing and drops in volume for the cue. `.playback` combined with the
/// target's `audio` background mode is what allows cues to keep firing with the
/// phone pocketed and the screen locked.
///
/// One caveat worth knowing: iOS keeps the app alive in the background while an
/// audio session is active and producing output, but a long silent gap between
/// cues can still let it suspend. Sessions here have a cue at least every couple
/// of minutes, which in practice holds it open — but this is exactly what the
/// real-world pocket test is for, and it is the first thing to suspect if cues
/// stop landing mid-run.
final class SpokenCueEngine {

    private let synthesizer = AVSpeechSynthesizer()
    private var isActive = false

    /// Rate slightly below default — cue text is short and easily missed at
    /// speed with road noise.
    var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.95

    func activate() {
        guard !isActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
            isActive = true
        } catch {
            // A failed audio session should not take the session down with it —
            // the on-screen timer stays correct either way.
            print("SpokenCueEngine: could not activate audio session — \(error)")
        }
    }

    func deactivate() {
        synthesizer.stopSpeaking(at: .immediate)
        guard isActive else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        isActive = false
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }
}
