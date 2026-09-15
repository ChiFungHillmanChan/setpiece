import Foundation

/// Persists user-tunable runtime settings (`AnimationConfig`, `DragSwapConfig`)
/// as JSON at `fileURL`. First launch seeds defaults. Loading a v1 file (V0.2
/// shape, no `dragSwap` field) auto-migrates to v2 with `DragSwapConfig.default`
/// and atomically rewrites the file. Observers registered via `onChange` fire
/// after every successful mutation.
public final class SettingsStore {
    public private(set) var animation: AnimationConfig
    public private(set) var dragSwap: DragSwapConfig
    /// V0.6 diagnostic-logging master switch. Default `true` so users
    /// who upgrade silently keep diagnostic coverage; the AboutTab
    /// toggle lets them opt out (which drains the writer + deletes the
    /// `diagnostics/` directory).
    public private(set) var diagnosticsEnabled: Bool
    /// V0.7.6. When `true` (the default, and V0.7.4's behaviour) the Dock's
    /// thickness is reserved on every display so the tiling rect cannot move
    /// when the Dock hops screens. Turning it off restores raw `visibleFrame`:
    /// windows reach the bottom edge of a display the Dock is not on, and a
    /// re-apply can shift them when the Dock moves. See `TilingFrame`.
    public private(set) var dockReserveAllDisplays: Bool
    private let fileURL: URL
    private var observers: [UUID: () -> Void] = [:]

    public static let currentVersion = 4

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let decoded = try Self.decodeWithMigration(data: data)
            self.animation = decoded.animation
            self.dragSwap = decoded.dragSwap
            self.diagnosticsEnabled = decoded.diagnosticsEnabled
            self.dockReserveAllDisplays = decoded.dockReserveAllDisplays
            if decoded.needsRewrite { try persist() }
        } else {
            self.animation = .default
            self.dragSwap = .default
            self.diagnosticsEnabled = true
            self.dockReserveAllDisplays = true
            try persist()
        }
    }

    public func setAnimation(_ config: AnimationConfig) throws {
        animation = config
        try persist()
        for h in observers.values { h() }
    }

    public func setDragSwap(_ config: DragSwapConfig) throws {
        dragSwap = config
        try persist()
        for h in observers.values { h() }
    }

    public func setDiagnosticsEnabled(_ value: Bool) throws {
        diagnosticsEnabled = value
        try persist()
        for h in observers.values { h() }
    }

    public func setDockReserveAllDisplays(_ value: Bool) throws {
        dockReserveAllDisplays = value
        try persist()
        for h in observers.values { h() }
    }

    public func onChange(_ handler: @escaping () -> Void) -> Cancellable {
        let token = UUID()
        observers[token] = handler
        return Cancellable { [weak self] in self?.observers[token] = nil }
    }

    private func persist() throws {
        let file = StoredFile(
            version: Self.currentVersion,
            animation: animation,
            dragSwap: dragSwap,
            diagnosticsEnabled: diagnosticsEnabled,
            dockReserveAllDisplays: dockReserveAllDisplays
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    /// Decodes whatever schema version is on disk; returns `needsRewrite=true`
    /// if the file must be upgraded and persisted back.
    private static func decodeWithMigration(data: Data) throws -> Decoded {
        let versionProbe = try JSONDecoder().decode(VersionProbe.self, from: data)
        switch versionProbe.version {
        case 4:
            let v4 = try JSONDecoder().decode(StoredFile.self, from: data)
            return Decoded(animation: v4.animation, dragSwap: v4.dragSwap,
                           diagnosticsEnabled: v4.diagnosticsEnabled,
                           dockReserveAllDisplays: v4.dockReserveAllDisplays,
                           needsRewrite: false)
        case 3:
            let v3 = try JSONDecoder().decode(StoredFileV3.self, from: data)
            // V0.7.6: default the escape hatch OFF for upgraders, i.e. keep
            // reserving on every display. Someone upgrading already has the
            // stable-tiling behaviour and must not have it changed under them.
            return Decoded(animation: v3.animation, dragSwap: v3.dragSwap,
                           diagnosticsEnabled: v3.diagnosticsEnabled,
                           dockReserveAllDisplays: true, needsRewrite: true)
        case 2:
            let v2 = try JSONDecoder().decode(StoredFileV2.self, from: data)
            // Default V0.6 diagnostics ON for upgraded users — they can
            // still opt out via the AboutTab toggle.
            return Decoded(animation: v2.animation, dragSwap: v2.dragSwap,
                           diagnosticsEnabled: true, dockReserveAllDisplays: true,
                           needsRewrite: true)
        case 1:
            let v1 = try JSONDecoder().decode(StoredFileV1.self, from: data)
            return Decoded(animation: v1.animation, dragSwap: .default,
                           diagnosticsEnabled: true, dockReserveAllDisplays: true,
                           needsRewrite: true)
        default:
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unsupported settings schema version \(versionProbe.version)"
            ))
        }
    }

    private struct VersionProbe: Codable { let version: Int }

    /// Whatever `decodeWithMigration` managed to read, plus whether the file
    /// on disk has to be upgraded and written back.
    private struct Decoded {
        let animation: AnimationConfig
        let dragSwap: DragSwapConfig
        let diagnosticsEnabled: Bool
        let dockReserveAllDisplays: Bool
        let needsRewrite: Bool
    }

    private struct StoredFile: Codable {
        let version: Int
        let animation: AnimationConfig
        let dragSwap: DragSwapConfig
        let diagnosticsEnabled: Bool
        let dockReserveAllDisplays: Bool
    }

    private struct StoredFileV3: Codable {
        let version: Int
        let animation: AnimationConfig
        let dragSwap: DragSwapConfig
        let diagnosticsEnabled: Bool
    }

    private struct StoredFileV2: Codable {
        let version: Int
        let animation: AnimationConfig
        let dragSwap: DragSwapConfig
    }

    private struct StoredFileV1: Codable {
        let version: Int
        let animation: AnimationConfig
    }
}
