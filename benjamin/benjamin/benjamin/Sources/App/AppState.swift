import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var showSnapshotEntry = false
}
