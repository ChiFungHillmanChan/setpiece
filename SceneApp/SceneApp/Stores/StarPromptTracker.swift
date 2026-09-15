import Combine
import Foundation
import SceneCore

/// Owns persistence for `StarPromptState` and republishes its gate so the menu
/// bar panel can show the one-shot "star Scene" nudge.
///
/// Backed by `UserDefaults` rather than `settings.json` on purpose. This
/// counter ticks on every successful layout apply — a hotkey-rate hot path —
/// and `SettingsStore.persist()` does an atomic whole-file write. `UserDefaults`
/// coalesces writes for us, and the value is a one-shot UI gate rather than a
/// user-tunable setting, so it does not belong in the settings schema. Same
/// reasoning as the `hasShownFirstLaunchWelcomeV1` flag (V0.5.2).
///
/// Writes stop entirely once the user answers: `recordSuccessfulApply()`
/// early-outs on a resolved state, so a long-lived install pays nothing.
@MainActor
final class StarPromptTracker: ObservableObject {
    private static let defaultsKey = "starPromptStateV1"

    /// True only while the user has earned the nudge and has not answered it.
    @Published private(set) var shouldPrompt: Bool

    private var state: StarPromptState
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.load(from: defaults)
        self.state = loaded
        self.shouldPrompt = loaded.shouldPrompt
    }

    /// Call once per layout that actually landed on screen.
    func recordSuccessfulApply() {
        guard state.resolution == .pending else { return }
        state.recordSuccessfulApply()
        persist()
    }

    /// Records the user's answer. Permanent — Scene never asks again.
    func resolve(_ resolution: StarPromptState.Resolution) {
        state.resolve(resolution)
        persist()
    }

    private func persist() {
        shouldPrompt = state.shouldPrompt
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> StarPromptState {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(StarPromptState.self, from: data)
        else { return StarPromptState() }
        return decoded
    }
}
