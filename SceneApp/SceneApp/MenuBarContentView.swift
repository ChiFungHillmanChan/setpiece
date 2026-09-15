import SwiftUI
import AppKit
import SceneCore

struct MenuBarContentView: View {
    private static let repositoryURL = URL(string: "https://github.com/ChiFungHillmanChan/scene-macos")!

    // Observe the coordinator directly rather than via @EnvironmentObject.
    // MenuBarExtra's menu (like its label — see MenuBarLabel) does NOT reliably
    // re-subscribe to @Published changes from environment objects, so toggling
    // Free Mode from the menu could leave the menu showing stale state (the
    // "Free Mode won't toggle back" report). A direct @ObservedObject binding
    // makes freeMode changes invalidate the menu the same way the icon updates.
    @ObservedObject var coordinator: Coordinator
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var updateChecker: UpdateChecker
    @EnvironmentObject var updateInstaller: UpdateInstaller
    @ObservedObject var workspaceStore: WorkspaceStoreViewModel
    @ObservedObject var layoutStore: LayoutStoreViewModel
    @ObservedObject var starPrompt: StarPromptTracker

    /// Hosting NSWindow of the window-style panel, captured via
    /// PanelWindowAccessor so actions can dismiss the panel explicitly
    /// (update-banner alert, Settings, onboarding, Escape). Layout,
    /// workspace, and Free Mode clicks deliberately do NOT dismiss —
    /// that is the point of the window-style panel.
    @State private var panelWindow: NSWindow?

    var body: some View {
        Group {
            if coordinator.permissionGranted {
                grantedPanel
            } else {
                ungrantedPanel
            }
        }
        .frame(width: 280)
        .background(PanelWindowAccessor(window: $panelWindow))
        .onExitCommand { closePanel() }
    }

    // MARK: - Granted

    @ViewBuilder
    private var grantedPanel: some View {
        // Touch layoutListVersion so SwiftUI rebuilds when LayoutStore mutates.
        let _ = coordinator.layoutListVersion

        VStack(alignment: .leading, spacing: 2) {
            if let version = updateChecker.availableVersion,
               let releaseURL = updateChecker.releasePageURL {
                Button(action: {
                    // Close first — runModal over an open panel fights for focus.
                    closePanel()
                    handleUpdateClick(version: version, releaseURL: releaseURL)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.tint)
                        Text(String(format: String(localized: "menu.update.available"), version))
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(MenuRowButtonStyle())
                PanelDivider()
            }

            sectionHeader("menu.section.workspaces")
            if workspaceStore.workspaces.isEmpty {
                Text("menu.workspaces.empty")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            } else {
                ForEach(workspaceStore.workspaces) { workspace in
                    workspaceRow(workspace)
                }
            }

            PanelDivider()

            ForEach(layoutStore.layouts) { layout in
                layoutRow(layout)
            }

            PanelDivider()

            Button(action: { coordinator.freeMode.toggle() }) {
                HStack(spacing: 6) {
                    checkmarkColumn(coordinator.freeMode)
                    Text("menu.free_mode")
                    Spacer()
                }
            }
            .buttonStyle(MenuRowButtonStyle())

            PanelDivider()

            if starPrompt.shouldPrompt {
                starPromptRow
                PanelDivider()
            }

            Button(action: {
                closePanel()
                appDelegate.openSettings()
            }) {
                HStack { Text("menu.settings"); Spacer() }
            }
            .buttonStyle(MenuRowButtonStyle())
            .keyboardShortcut(",")

            Button(action: { NSApp.terminate(nil) }) {
                HStack { Text("menu.quit"); Spacer() }
            }
            .buttonStyle(MenuRowButtonStyle())
            .keyboardShortcut("q")
        }
        .padding(6)
    }

    // MARK: - Ungranted

    @ViewBuilder
    private var ungrantedPanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                closePanel()
                coordinator.openOnboarding()
            }) {
                HStack { Text("menu.grant_accessibility"); Spacer() }
            }
            .buttonStyle(MenuRowButtonStyle())

            PanelDivider()

            Button(action: { NSApp.terminate(nil) }) {
                HStack { Text("menu.quit"); Spacer() }
            }
            .buttonStyle(MenuRowButtonStyle())
        }
        .padding(6)
    }

    // MARK: - Rows

    /// One-shot nudge shown once `StarPromptState.promptThreshold` layouts have
    /// actually landed. Either half answers it for good, so this row can never
    /// become a recurring nag.
    private var starPromptRow: some View {
        HStack(spacing: 0) {
            Button(action: {
                starPrompt.resolve(.starred)
                NSWorkspace.shared.open(Self.repositoryURL)
                closePanel()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("menu.star_prompt")
                    Spacer()
                }
            }
            .buttonStyle(MenuRowButtonStyle())

            Button(action: { starPrompt.resolve(.dismissed) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // `.help` only sets the tooltip; without an explicit label
            // VoiceOver reads the SF Symbol's generic name ("Close") instead
            // of what the button actually does.
            .accessibilityLabel(Text("menu.star_prompt.dismiss"))
            .help(Text("menu.star_prompt.dismiss"))
            .padding(.trailing, 6)
        }
    }

    private func workspaceRow(_ workspace: Workspace) -> some View {
        Button(action: { activate(workspace: workspace) }) {
            HStack(spacing: 6) {
                checkmarkColumn(workspaceStore.activeWorkspaceID == workspace.id)
                if let layout = layoutStore.layouts.first(where: { $0.id == workspace.layoutID }) {
                    LayoutThumbnail(layout: layout, size: CGSize(width: 24, height: 16))
                } else {
                    Rectangle()
                        .fill(.red.opacity(0.3))
                        .frame(width: 24, height: 16)
                }
                Text(workspace.name)
                    .fontWeight(
                        workspaceStore.activeWorkspaceID == workspace.id ? .semibold : .regular
                    )
                Spacer()
                if let chord = workspace.hotkey {
                    hotkeyLabel(chord.displayString)
                }
            }
        }
        .buttonStyle(MenuRowButtonStyle())
        .disabled(coordinator.freeMode)
    }

    private func layoutRow(_ layout: CustomLayout) -> some View {
        let isActive = coordinator.activeLayoutID == layout.id
        return Button(action: { coordinator.applyLayout(layout) }) {
            HStack(spacing: 6) {
                LayoutThumbnail(layout: layout, size: CGSize(width: 24, height: 16))
                Text(layout.name)
                    .fontWeight(isActive ? .semibold : .regular)
                Spacer()
                if let h = layout.hotkey {
                    hotkeyLabel(h.displayString)
                }
                // Trailing tick for the layout applied most recently. Always
                // occupies its column so hotkey chords stay aligned whether or
                // not the row is ticked.
                checkmarkColumn(isActive)
            }
        }
        .buttonStyle(MenuRowButtonStyle())
        .disabled(coordinator.freeMode)
    }

    // MARK: - Small pieces

    @ViewBuilder
    private func checkmarkColumn(_ on: Bool) -> some View {
        if on {
            Image(systemName: "checkmark")
                .foregroundStyle(.tint)
        } else {
            Spacer().frame(width: 14)
        }
    }

    private func hotkeyLabel(_ s: String) -> some View {
        Text(s)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 4)
    }

    private func closePanel() {
        panelWindow?.orderOut(nil)
    }

    /// Confirmation flow before kicking off the in-app installer (V0.5.6).
    /// Three-button NSAlert: **Install and Restart** (default), **Release
    /// Notes** (opens GitHub in browser like the pre-V0.5.6 behavior),
    /// **Later** (dismiss). When `dmgURL` is missing — an unusual GitHub
    /// release with no `.dmg` asset — we silently fall back to opening the
    /// release page so the user can still find the install path.
    private func handleUpdateClick(version: String, releaseURL: URL) {
        guard let dmgURL = updateChecker.dmgURL else {
            NSWorkspace.shared.open(releaseURL)
            return
        }
        let alert = NSAlert()
        alert.messageText = String(
            format: String(localized: "update.install.alert.title"),
            version
        )
        alert.informativeText = String(localized: "update.install.alert.body")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "update.install.alert.install_and_restart"))
        alert.addButton(withTitle: String(localized: "update.install.alert.release_notes"))
        alert.addButton(withTitle: String(localized: "update.install.alert.later"))
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            Task { @MainActor in
                await updateInstaller.install(dmgURL: dmgURL, version: version)
            }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(releaseURL)
        default:
            break
        }
    }

    private func activate(workspace: Workspace) {
        let id = workspace.id
        Task { @MainActor in
            await coordinator.applyWorkspace(id: id)
        }
    }
}

/// Grabs the NSWindow hosting the panel content so actions can dismiss it.
private struct PanelWindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { window = nsView.window }
    }
}

private struct PanelDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
    }
}
