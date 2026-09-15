import Foundation

/// Gates the one-shot "enjoying Scene? star it" nudge in the menu bar panel.
///
/// The nudge is earned, not scheduled: it appears only after the user has
/// successfully applied `promptThreshold` layouts, so someone who installed
/// Scene an hour ago and has not used it yet is never asked. Once the user
/// answers — either way — the state is resolved and Scene never asks again.
///
/// Pure value type with no I/O so the gating rules stay unit-testable;
/// `StarPromptTracker` in SceneApp owns persistence.
public struct StarPromptState: Codable, Equatable, Sendable {
    public enum Resolution: String, Codable, Sendable {
        /// The user has not answered yet.
        case pending
        /// The user opened the GitHub page from the nudge.
        case starred
        /// The user waved the nudge away.
        case dismissed
    }

    /// Successful layout applies required before Scene asks. Twenty is roughly
    /// a week of real use — enough that the user has formed an opinion.
    public static let promptThreshold = 20

    public private(set) var successfulApplyCount: Int
    public private(set) var resolution: Resolution

    public init() {
        successfulApplyCount = 0
        resolution = .pending
    }

    public var shouldPrompt: Bool {
        resolution == .pending && successfulApplyCount >= Self.promptThreshold
    }

    /// Counts one layout that actually landed. Saturates at the threshold:
    /// past that the exact number carries no meaning, and a counter that stops
    /// growing cannot overflow on a long-lived install.
    public mutating func recordSuccessfulApply() {
        guard resolution == .pending else { return }
        successfulApplyCount = min(successfulApplyCount + 1, Self.promptThreshold)
    }

    public mutating func resolve(_ resolution: Resolution) {
        self.resolution = resolution
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case successfulApplyCount, resolution
    }

    /// Hand-rolled so a hand-edited or future-written file can never crash the
    /// app or re-arm a prompt the user already answered.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let storedCount = try c.decodeIfPresent(Int.self, forKey: .successfulApplyCount) ?? 0
        successfulApplyCount = min(max(0, storedCount), Self.promptThreshold)

        let storedResolution = try c.decodeIfPresent(String.self, forKey: .resolution)
            ?? Resolution.pending.rawValue
        // An unrecognized resolution was written by a build that knows
        // something this one does not. Treat it as answered rather than
        // nagging a user who has already dealt with the nudge.
        resolution = Resolution(rawValue: storedResolution) ?? .dismissed
    }
}
