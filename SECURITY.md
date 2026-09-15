# Security Policy

Scene runs **unsandboxed** and requires the macOS **Accessibility (AX)** permission in
order to move other applications' windows. That is a high-trust position on a user's
machine, and security reports are taken seriously here.

## Supported versions

Only the latest release receives security fixes. Scene ships an in-app updater, so
users on older builds are prompted to update.

| Version | Supported |
| ------- | --------- |
| Latest release ([releases](https://github.com/ChiFungHillmanChan/scene-macos/releases/latest)) | ✅ |
| Any earlier version | ❌ |

Minimum platform: macOS 14 (Sonoma).

## Reporting a vulnerability

**Do not open a public issue for a security bug.**

Preferred: [**Report a vulnerability**](https://github.com/ChiFungHillmanChan/scene-macos/security/advisories/new)
via GitHub's private security advisories.

Alternative, if you cannot use GitHub advisories: `hillmanchan709@gmail.com` with
`[Scene security]` in the subject.

Please include the Scene version, macOS version, chip (Apple Silicon / Intel), and the
smallest reproduction you can manage. A proof-of-concept `scene://` URL, a crafted
calendar invite, or a diagnostic bundle is more useful than a description.

### What to expect

Scene is maintained by one person in Hong Kong (UTC+8), unfunded. These are honest
targets, not an SLA:

| Stage | Target |
| ----- | ------ |
| Acknowledgement | within 72 hours |
| Initial triage and severity assessment | within 7 days |
| Fix released, or a public timeline if it needs longer | within 90 days |

You will be credited in the release notes and the advisory unless you ask not to be.
There is no bug bounty — Scene has no funding.

## Areas of highest concern

These are the parts of the codebase where a bug has the widest blast radius. Reports
here get priority.

**Accessibility / window control** (`Sources/SceneCore/AX/`, `AXWindowLookup`)
Scene holds an AX grant, which is effectively full UI control of the machine. Anything
that lets an untrusted input reach the AX layer, or that causes Scene to act on a window
it did not intend to target, is in scope.

**`scene://` URL scheme** (`Sources/SceneCore/Automation/URLRouter.swift`)
Any process — including a web page via `open scene://…` — can invoke this scheme.
Activating a workspace launches applications, so this is a remote-triggerable action
surface. Of particular interest: workspace/layout name resolution (matching is
case-insensitive), the `?force=1` parameter, and any route that performs an action
without the Free Mode or AX-permission guards applying.

**In-app updater** (`SceneApp/SceneApp/UpdateChecker.swift`, `UpdateInstaller.swift`)
Scene downloads a DMG, verifies the `codesign` Team Identifier, then hands off to a
detached shell script that mounts and installs it. Reports about time-of-check /
time-of-use gaps on the temporary DMG path, the `hdiutil attach -noverify` mount, the
`ditto --noqtn` quarantine handling, the rollback path, or anything that could cause an
unverified bundle to be installed in place of a verified one are high severity — a
compromised update inherits Scene's existing Accessibility grant.

**Calendar triggers** (`SceneApp/SceneApp/Workspace/Triggers/CalendarTriggerWatcher.swift`)
Workspace activation can be driven by matching calendar event titles. Event titles are
attacker-influenceable by anyone who can send the user an invitation, which makes this a
path from remote untrusted input to local automation.

**Distribution** (`ChiFungHillmanChan/homebrew-tap`, release assets, CI)
Cask checksum handling, release artifact integrity, and workflow permissions.

## Out of scope

- The Accessibility permission requirement itself. Scene cannot move other apps' windows
  without it; this is a documented design constraint, not a vulnerability.
- The app being unsandboxed. Same reason — App Sandbox forbids the AX APIs Scene needs.
- Attacks that require the attacker to already have code execution as the user, or
  physical access to an unlocked machine.
- Missing hardening that has no demonstrated impact (e.g. "flag X is not set") without a
  concrete exploitation path.
- Findings from automated scanners pasted without a working reproduction.
- Social engineering of the maintainer, and reports about third-party services.

## Existing mitigations

For context when assessing a report, Scene already does the following:

- Releases are signed with a Developer ID and **notarized by Apple**.
- The updater verifies the downloaded DMG's `codesign` Team Identifier (`22K6G3HH9G`)
  before mounting it.
- `URLRouter.parse` is pure — it performs no I/O and reads no stores; identifier
  resolution happens later, behind the coordinator's guards.
- CI runs build and tests on every pull request with `permissions: contents: read`, and
  no repository secret is exposed to pull request workflows.

## Disclosure

Coordinated disclosure. Please give a fix a reasonable window before going public. If a
report is still unfixed after 90 days, or if the issue is already being exploited, you
are free to disclose — tell me first so users can be warned in the same breath.
