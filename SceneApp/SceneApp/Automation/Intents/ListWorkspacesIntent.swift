import AppIntents
import AppKit

struct ListWorkspacesIntent: AppIntent {
    static var title: LocalizedStringResource = "List Workspaces"
    static var description = IntentDescription("Return the names of all configured Setpiece Workspaces.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog {
        guard let dispatcher = (NSApp.delegate as? AppDelegate)?.automationDispatcher else {
            return .result(value: [], dialog: "Setpiece is not ready.")
        }
        let names = await dispatcher.workspaceNames()
        return .result(value: names, dialog: "Found \(names.count) Setpiece workspace(s).")
    }
}
