# Contributing to Setpiece

Thanks for looking. Setpiece is maintained by one person in Hong Kong (UTC+8), unfunded, in
spare time. That single fact shapes everything below — contributions are genuinely welcome,
but the project can only absorb them at one reviewer's speed, so this guide exists to keep
your effort from being wasted.

> English is the working language of the repository. 中文版：[CONTRIBUTING.zh-HK.md](CONTRIBUTING.zh-HK.md)

**The short version:** bug fixes can go straight to a pull request. Anything that adds a
feature, changes the UI, or touches persisted data should start as an issue, and wait for a
reply before you write the code.

## Ways to help that aren't code

Not everything useful is a patch:

- **Report bugs precisely.** A reproducible multi-display bug report is worth more than most
  patches — those are the hardest defects to find alone, because they need hardware.
- **Improve the translations.** Setpiece ships English, 繁中（香港）and 繁中（台灣）. Native-speaker
  corrections are always accepted, and a fix to one awkward string is a perfectly good first
  contribution.
- **Answer someone else's issue.** Half of them are "how do I…", and you may already know.
- **Tell people.** A star, a blog post, a video, a mention to a colleague who keeps dragging
  windows by hand. Discovery is the hard part of a free menu bar app.

## Reporting a bug

Search the existing issues first, **including closed ones** — several known macOS quirks are
documented there and closed as "not a Setpiece bug".

Then open an issue with:

- **Setpiece version** — Settings → About.
- **macOS version and chip** (Apple Silicon or Intel).
- **Your display setup** — how many displays, their arrangement, scaling, and which one the
  pointer was on. A surprising share of layout bugs are multi-display bugs, and this line is
  usually what makes them reproducible.
- **Which layout or workspace**, what you expected, and what actually happened.
- **A screen recording**, if the bug is about windows moving. Window geometry is close to
  impossible to describe accurately in prose; five seconds of video ends the guessing.
- **A diagnostics export**, if the bug involves activation, triggers or the updater. Settings
  → About → turn on **Enable diagnostic logging**, reproduce the bug, then
  **Export Diagnostics for Bug Report**. Nothing leaves your Mac until you attach it.

**Security bugs do not go in a public issue.** See [SECURITY.md](SECURITY.md) for the private
advisory route.

## Requesting a feature

Read the **Roadmap** section of the [README](README.md#roadmap) first. Items already listed as
deferred are known and tracked; re-requesting them doesn't move them up.

A good request leads with the use case, not the implementation — "I want my editor and
terminal to swap sides when I plug in at the office" tells me more than "add a swap-sides
button". The use case sometimes turns out to be reachable with what already ships.

Setpiece says no fairly often, and the biases behind that are worth knowing up front. It intends
to stay a small menu bar app that does layouts and workspaces well: no plugin system, no
accounts, no cloud sync, no telemetry, and no external dependencies.

## Pull requests

**Issue first, then PR.** Concretely:

**Send a PR directly** for a typo, a documentation fix, a translation correction, a test that
covers existing behavior, or a small self-evident bug fix.

**Open an issue and wait for a green light** before writing code that:

- adds a feature or a new setting,
- changes any UI or any user-facing string,
- changes the shape of persisted JSON (`layouts.json`, `settings.json`, `workspaces.json`),
- adds a new workspace trigger type, URL route, or App Intent,
- changes default hotkeys or the preset seeds.

This isn't gatekeeping for its own sake. Schema changes need a migration path for people who
already have data on disk, every new string costs three locales, and a rejected PR after a
weekend of work is a bad experience for both of us. A five-line issue first avoids it.

**Likely to be declined without prior discussion:** adding an external dependency; adding a
build-time code generation step; repo-wide reformatting; broad refactors that touch many files
at once; and changes that cut across the architecture boundaries below.

## Development setup

**Prerequisites:** macOS 14+, Xcode 16+, Swift 5.9+ (bundled with Xcode). No package manager
step — Setpiece has zero external dependencies, by design.

```bash
git clone https://github.com/ChiFungHillmanChan/setpiece.git
cd setpiece

swift build      # compiles SceneCore, the framework-neutral logic library
swift test       # runs the full SceneCore unit suite, no Xcode needed

# build the app itself
xcodebuild -project SceneApp/SceneApp.xcodeproj -scheme SceneApp \
  -configuration Debug CODE_SIGNING_REQUIRED=NO build
```

Or open `SceneApp/SceneApp.xcodeproj` and run the `SceneApp` scheme with ⌘R. The app runs as a
menu bar extra with no Dock icon.

Two things that will cost you an hour if nobody warns you:

**`errSecInternalComponent` on a clean machine.** Add `CODE_SIGNING_REQUIRED=NO` to the
`xcodebuild` invocation. This is normal, not a broken checkout.

**Accessibility permission dies on every rebuild.** macOS binds the AX grant to the binary's
code signature hash, so each local build is a different app as far as TCC is concerned. The
toggle in System Settings will still *look* on while `AXIsProcessTrusted()` returns false —
Setpiece will behave as if it has no permission. Fix it with either:

```bash
tccutil reset Accessibility com.hillman.SceneApp    # then relaunch and re-grant
```

or by toggling Setpiece off and on in **System Settings → Privacy & Security → Accessibility**.

## Architecture rules a PR must respect

These are the load-bearing constraints. A patch that breaks one will be sent back even if it
works, so they're worth reading before you start.

**SceneCore stays framework-neutral.** No `import SwiftUI`, no `import Combine`, no
`ObservableObject` anywhere under `Sources/SceneCore/`. Stores expose closure-based observation
(`onChange { … } -> Cancellable`); the SwiftUI adapters live in `SceneApp/SceneApp/Stores/`.
This is what keeps `swift test` runnable without Xcode.

**No external dependencies.** Both in `Package.swift` and in the app target.

**`TilingFrame.forScreen(_:)` is the tiling authority.** Never pass a raw `screen.visibleFrame`
into `Slot.absoluteRect(in:)` or `LayoutEngine.plan`. `visibleFrame` reserves Dock space only on
the display the Dock currently occupies, and the Dock follows the pointer between displays — so
the same layout applied twice on the same screen would land ~70pt apart. `screen.frame` is
correct for exactly one thing: deciding which display a window belongs to.

**Unit rects are top-left origin.** Every `Slot.rect` is authored with y=0 at the top, matching
the SwiftUI renderers. `slot.absoluteRect(in:)` flips into AppKit's bottom-left space exactly
once; `LayoutReflow` is the inverse. If you add a new conversion between the two spaces, it has
to agree with those two, or asymmetric layouts come out mirrored.

**Permission gating belongs to the orchestration layer.** `LayoutEngine` never sees
`.noPermission`; `Coordinator` catches `.permissionDenied` and reopens onboarding.

**`plan()` is pure.** Side effects live in `apply()`, `WindowAnimator` and `WorkspaceActivator`.
That purity is what makes the layout math testable.

For the longer tour, see the **Architecture** section of the [README](README.md#architecture).

## Tests

`swift test` must be green before you open a PR. CI runs it plus a full Xcode build of SceneApp
on every pull request, so a red suite will be caught anyway.

- **Logic goes in SceneCore, with tests.** Layout math, stores, hotkey conflicts, animation
  state, persistence, triggers — all of it is unit-testable without a running app, and new
  logic is expected to arrive with coverage.
- **When fixing a bug, write the failing test first.** A test that reproduces the bug, then the
  fix that turns it green, is the most reviewable shape a bugfix PR can have.
- **The AppKit/SwiftUI layer isn't unit tested.** If you change it, add or update a scenario in
  [`docs/TESTING.md`](docs/TESTING.md) and say in the PR description that you ran it.

## Localization

User-facing strings live in `SceneApp/SceneApp/Resources/Localizable.xcstrings` (Xcode String
Catalog), in three locales: `en`, `zh-HK`, `zh-TW`. Never hardcode a display string in a view.

**Interpolation is strict.** Use `String(format: String(localized: "key"), arg)` — never
`String(localized: "key \(arg)")`. A dynamic key fails the catalog lookup silently and ships
the raw key to users. Catalog values for interpolated keys must carry `%@` (or `%lld` for Int).

**zh-HK is 粵語, not 書面語.** Use 撳 (not 按), 嘅 (not 的), 係 (not 是), 咁 (not 這樣),
喺 (not 在), 啲 (not 些), 你哋 (not 你們), 冇 (not 沒有). zh-TW is standard written Chinese.

If you add a string but don't write Chinese, supply `en` and say so in the PR — the Chinese can
be filled in during review. That's much better than a machine translation nobody can vouch for.

## Commit messages

Conventional Commits, matching the existing log:

```
feat(layout): sticky slot re-apply
fix(update): offer the newest release, not GitHub's "latest"
refactor(layout): Placement carries explicit slotIndex
docs(readme): v0.7.0 — Automation surface
i18n: add 6 automation notification keys (en / zh-HK / zh-TW)
ci: add SceneCore and SceneApp build checks on PRs
```

Scopes in use include `layout`, `workspace`, `settings`, `menubar`, `interaction`, `intents`,
`automation`, `update`, `readme`. Imperative mood, one logical change per commit. `release:`
commits are maintainer-only — don't bump `MARKETING_VERSION` or edit `CHANGELOG.md` in a PR.

## AI-assisted contributions

Allowed, and used in this repository already. The conditions are about the result, not the
tool:

- **You are the author.** You should understand every line you submit and be able to explain
  why it's written that way in review. A PR its own author can't explain gets closed, however
  it was produced.
- **Build it and run it on a real Mac.** Compiling is not evidence of working when the
  Accessibility API and live windows are involved. Say in the PR what you actually exercised.
- **Respect the architecture rules above.** Generated Swift reaches for SwiftUI and third-party
  packages by default; both are wrong here.
- **Don't file generated bug reports.** An issue describing symptoms nobody observed costs real
  hours to chase. Report what you saw.
- **Keep the diff to the task.** Unrequested refactors, reformatting, and comment rewrites
  sprayed across untouched files make a patch unreviewable.

## What not to commit

Already covered by `.gitignore`; don't force-add past it:

- `.DS_Store`, `/build/`, `/dist/`, `.build/`, `.swiftpm/`, `Package.resolved`
- AI and agent session artifacts: `docs/superpowers/`, `.superpowers/`, `.claude/`, `.cursor/`,
  `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`
- `.env`, signing identities, provisioning profiles, or anything holding a Developer ID

## Pull request checklist

- [ ] There's a linked issue, unless this is a typo, doc, translation or small obvious fix.
- [ ] `swift test` passes locally.
- [ ] The app builds and you ran it on a real Mac.
- [ ] New logic has SceneCore tests; UI changes have a `docs/TESTING.md` scenario.
- [ ] New user-facing strings are in the String Catalog, not hardcoded.
- [ ] No new external dependencies.
- [ ] The diff contains only what the change needs.

## License

By contributing to Setpiece, you agree that your contributions will be licensed under the project's
[MIT License](LICENSE). There is no CLA and no copyright assignment — you keep your copyright,
and the license is what lets the project ship it.

## Code of conduct

Participation is covered by the [Code of Conduct](CODE_OF_CONDUCT.md).
