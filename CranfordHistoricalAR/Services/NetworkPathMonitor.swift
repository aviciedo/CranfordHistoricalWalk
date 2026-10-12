import Foundation
import Network

/// Process-wide path monitor so Geospatial can refuse to start offline.
/// Not a location source.
@MainActor
final class NetworkPathMonitor {
    static let shared = NetworkPathMonitor()

    private(set) var isSatisfied: Bool = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isSatisfied = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.cranford.historicalar.network"))
    }
}
