import AudioToolbox

/// Subtle in-app audio cues. Built on `AudioServicesPlaySystemSound` so we
/// don't have to ship any audio assets or manage an AVAudioSession. The
/// system handles routing — sound plays through the active audio output and
/// is mixed politely with whatever else is going on.
enum Chime {
    /// Plays when the timer advances to a new step.
    static func stepEntered() {
        AudioServicesPlaySystemSound(1003) // TritoneSent — gentle ascending three-note
    }

    /// Plays 10 seconds before a step ends, as a heads-up.
    static func stepEndingSoon() {
        AudioServicesPlaySystemSound(1306) // soft attention ping
    }

    /// Plays when the final step of a session finishes (the recipe is done).
    static func stepFinished() {
        AudioServicesPlaySystemSound(1025) // brighter "complete" tone
    }

    /// Plays when an agitation cycle begins.
    static func agitationStart() {
        AudioServicesPlaySystemSound(1057) // Tink — soft single tap
    }

    /// Plays when an agitation cycle ends.
    static func agitationEnd() {
        AudioServicesPlaySystemSound(1103) // Tock — slightly softer counterpart
    }
}
