import Foundation
import MacCleanKit

/// Single source of truth for "user clicked Clean."
///
/// Every view that has a Clean button MUST route through here. By centralizing
/// the call to `CleaningEngine` we guarantee:
///   1. The mode is always `.trash` (files recoverable from Trash, never silently
///      `.dryRun` which would report success without deleting anything).
///   2. Item-filtering logic (intersect scan results with user selection) is
///      identical across every module, so behavior can't drift per-view.
///   3. There's exactly one place to audit when reviewing the deletion path.
///
/// This existed to fix the regression where every view was passing `.dryRun`
/// — see `CleanIsNotDryRunRegressionTests` for the static guard that prevents
/// the bug from coming back, and `CleanActionsTests` for the behavioral
/// verification that the engine actually moves files.
public enum CleanActions {

    /// Execute a user-initiated Clean operation against the given engine.
    /// Used by views that display `[ScanResult]` with per-item selection.
    @discardableResult
    public static func executeUserClean(
        results: [ScanResult],
        selectedItems: Set<URL>,
        engine: CleaningEngine
    ) async -> CleaningEngine.CleanResult {
        let items = results
            .flatMap(\.items)
            .filter { selectedItems.contains($0.url) }
        return await engine.clean(items: items, mode: .trash)
    }

    /// Execute a user-initiated Clean operation against a flat list of items.
    /// Used by the Uninstaller, which surfaces `[FileItem]` (associated files
    /// for a single app) rather than `[ScanResult]`.
    @discardableResult
    public static func executeUserClean(
        items: [FileItem],
        selectedItems: Set<URL>,
        engine: CleaningEngine
    ) async -> CleaningEngine.CleanResult {
        let filtered = items.filter { selectedItems.contains($0.url) }
        return await engine.clean(items: filtered, mode: .trash)
    }
}
