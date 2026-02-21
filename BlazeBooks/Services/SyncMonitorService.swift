import Foundation
import Observation
import SwiftData
import CoreData

/// Monitors CloudKit sync state for UI display purposes.
///
/// Observes `NSPersistentStoreRemoteChange` notifications posted by
/// the underlying NSPersistentCloudKitContainer when remote changes
/// arrive. Exposes a simple `isSyncing` boolean that pulses true
/// briefly (1.5 seconds) each time remote data is received.
///
/// Usage:
/// - Create an instance and inject via `.environment(syncMonitor)`
/// - Call `startMonitoring(container:)` from a `.task` modifier
/// - Read `isSyncing` in views for sync indicator visibility
@MainActor
@Observable
final class SyncMonitorService {
    /// Whether sync activity is currently happening.
    /// Shows true briefly when remote changes are detected, then resets after a short delay.
    var isSyncing: Bool = false

    private nonisolated(unsafe) var notificationObserver: NSObjectProtocol?

    /// Start monitoring CloudKit sync events for the given container.
    func startMonitoring(container: ModelContainer) {
        // Observe remote change notifications posted by NSPersistentCloudKitContainer
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isSyncing = true
                // Reset after a brief visual indicator period (1.5 seconds)
                try? await Task.sleep(for: .seconds(1.5))
                self?.isSyncing = false
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
