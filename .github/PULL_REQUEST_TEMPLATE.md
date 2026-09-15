## What this changes

<!-- One or two sentences. What behaviour is different after this PR? -->

Closes #

<!--
  No linked issue? That's fine for a typo, documentation, translation correction, a test
  covering existing behaviour, or a small self-evident bug fix. Anything that adds a
  feature, changes UI or user-facing strings, or changes the shape of persisted JSON
  should have had an issue first — see CONTRIBUTING.md. Opening one now is quicker than
  having the PR sit unreviewed.
-->

## Why

<!-- The problem this solves. For a bug fix, what went wrong and why. -->

## How you tested it

<!--
  Compiling is not evidence of working when the Accessibility API and live windows are
  involved. Say what you actually exercised: which layout, how many windows, how many
  displays, which macOS version and chip. If you changed the AppKit/SwiftUI layer, name
  the docs/TESTING.md scenario you ran.
-->

## Checklist

- [ ] There's a linked issue, unless this is a typo, doc, translation or small obvious fix.
- [ ] `swift test` passes locally.
- [ ] The app builds and I ran it on a real Mac.
- [ ] New logic has SceneCore tests; UI changes have a `docs/TESTING.md` scenario.
- [ ] New user-facing strings are in the String Catalog, not hardcoded.
- [ ] No new external dependencies.
- [ ] The diff contains only what the change needs.
