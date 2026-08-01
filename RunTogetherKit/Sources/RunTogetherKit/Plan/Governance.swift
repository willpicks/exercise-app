import Foundation

/// Where a plan's authority comes from.
///
/// This is the type that keeps the app honest. A `.physioProtocol` plan is a
/// record of what a clinician prescribed — the app executes it and shows its
/// attribution, but never advances it on its own and never invents rungs beyond
/// the caps it was given. A `.selfDirected` plan is an ordinary training build
/// with no medical constraint behind it.
public enum Governance: Hashable, Sendable, Codable {
    /// Prescribed by a clinician. `source` is who, `recordedOn` is when — both
    /// are surfaced next to any proposed stage advance so it is always obvious
    /// the plan came from them and not from us.
    case physioProtocol(source: String, recordedOn: Date)
    /// Self-directed training with no clinical constraint.
    case selfDirected

    /// Protocol-governed plans never auto-advance; the user must confirm each
    /// stage. Self-directed plans may advance on a normal weekly cadence.
    public var requiresExplicitAdvance: Bool {
        switch self {
        case .physioProtocol: return true
        case .selfDirected: return false
        }
    }

    /// Display string for the plan's provenance, e.g. "Physio, 14 July 2026".
    public func attribution(dateStyle: DateFormatter.Style = .long) -> String? {
        switch self {
        case let .physioProtocol(source, recordedOn):
            let formatter = DateFormatter()
            formatter.dateStyle = dateStyle
            formatter.timeStyle = .none
            return "\(source), \(formatter.string(from: recordedOn))"
        case .selfDirected:
            return nil
        }
    }
}
