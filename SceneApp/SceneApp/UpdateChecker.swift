import AppKit
import Combine
import Foundation
import SceneCore
import os

/// Passive update nudge: polls the GitHub `releases/latest` endpoint at most
/// once every 24 hours per device and, when the remote tag is newer than the
/// running bundle version, publishes the pair so `MenuBarContentView` can
/// show an "Update available" menu item that opens the release page in the
/// browser.
///
/// Deliberately *not* Sparkle (and not silent auto-install):
/// - Keeping the user in the DMG install path preserves the same install
///   ritual across Homebrew and direct-download users — no divergence in
///   support flows.
/// - No signature verification here; Gatekeeper runs on the downloaded DMG
///   (notarized v0.5.0+, so no prompt).
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?
    @Published private(set) var releasePageURL: URL?
    /// V0.5.6: direct URL to the `.dmg` asset attached to the GitHub release,
    /// surfaced so the in-app `UpdateInstaller` can download + install in one
    /// click. `nil` if the release has no DMG asset (defensive — every Scene
    /// release since v0.4.x has shipped one).
    @Published private(set) var dmgURL: URL?

    /// The full release listing, **not** `releases/latest`.
    ///
    /// GitHub defines `releases/latest` as the most recent non-prerelease,
    /// non-draft release sorted by `created_at` — where `created_at` is the
    /// date of the commit the tag points at, not the publish date. A hotfix
    /// cut from an older commit therefore sorts *below* the release it
    /// supersedes, and `releases/latest` hands back the older one. A user on a
    /// much older build would be offered that, install it, and be offered the
    /// next one on relaunch: updating one version at a time instead of
    /// jumping straight to newest.
    ///
    /// Listing and picking the highest tag ourselves makes "always offer the
    /// newest" true by construction. One page of 100 covers Scene's history
    /// many times over; if it ever overflows, GitHub returns newest-created
    /// first, so page 1 still holds every recent release.
    private let apiURL = URL(string:
        "https://api.github.com/repos/ChiFungHillmanChan/scene-macos/releases?per_page=100"
    )!
    private let lastCheckKey = "com.scene.UpdateChecker.lastCheckedAt"
    private let minInterval: TimeInterval = 24 * 60 * 60

    private let log = Logger(subsystem: "com.scene.app", category: "update-checker")

    private var periodicTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    /// Immediate check + recurring hourly checks + wake-from-sleep trigger.
    /// V0.5.5: the launch-time check now bypasses the 24-hour debounce —
    /// previously, if Scene had cached `lastCheckedAt` while the user was on
    /// version N (before N+1 was published) and the user relaunched after
    /// N+1 shipped but inside the 24-hour window, the check was skipped and
    /// the user never saw the update menu item until tomorrow. An explicit
    /// quit + relaunch is a strong user signal that they want fresh state.
    /// The hourly timer and wake-from-sleep trigger keep the 24h debounce
    /// (those fire automatically without user intent — protecting the GitHub
    /// rate limit on long-running instances).
    func startPeriodicChecks() {
        forceCheck()

        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }

        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }
    }

    /// Bypass the 24-hour debounce. Used by `startPeriodicChecks()` so an
    /// explicit launch always re-asks GitHub. GitHub's unauthenticated rate
    /// limit (60 req/hr per IP) leaves plenty of headroom even for users who
    /// relaunch many times per session.
    func forceCheck() {
        Task { [weak self] in await self?.performCheck() }
    }

    deinit {
        periodicTimer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    /// Kick off a non-blocking check. Safe to call on every launch — the
    /// 24-hour per-device debounce (persisted in `UserDefaults`) keeps us
    /// well inside GitHub's 60 req/hr unauthenticated rate limit even if
    /// the user relaunches many times per day.
    func checkIfDue() {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < minInterval {
            return
        }
        Task { [weak self] in await self?.performCheck() }
    }

    private func performCheck() async {
        do {
            var request = URLRequest(url: apiURL)
            request.timeoutInterval = 10
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let releases = try JSONDecoder().decode([Release].self, from: data)
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)

            // Drafts aren't public and prereleases aren't for the update
            // channel — a prerelease at the top of the list must not become
            // everyone's "latest".
            let installable = releases.filter { !$0.draft && !$0.prerelease }
            guard let idx = indexOfHighestVersion(tags: installable.map(\.tagName)) else {
                clearAvailableUpdate()
                return
            }
            let release = installable[idx]

            guard let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                  isVersionTag(release.tagName, newerThan: bundleVersion),
                  let url = URL(string: release.htmlURL)
            else {
                // Already current (or the bundle version is unreadable).
                // Clear rather than leave a stale banner pointing at a
                // version the user has since installed by hand.
                clearAvailableUpdate()
                return
            }

            self.availableVersion = Self.normalizeTag(release.tagName)
            self.releasePageURL = url
            // First .dmg asset wins. Releases bundling multiple DMGs (e.g.
            // separate Apple Silicon / Intel slices) would need extra
            // routing here, but v0.5.3+ ships a single universal DMG.
            // A release with no DMG leaves this nil and the menu falls back
            // to opening the release page in the browser.
            self.dmgURL = release.assets
                .first(where: { $0.name.lowercased().hasSuffix(".dmg") })
                .flatMap { URL(string: $0.browserDownloadURL) }
        } catch {
            log.debug("update check failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func normalizeTag(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private func clearAvailableUpdate() {
        availableVersion = nil
        releasePageURL = nil
        dmgURL = nil
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        let assets: [Asset]
        let draft: Bool
        let prerelease: Bool
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
            case draft
            case prerelease
        }
    }

    private struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}
