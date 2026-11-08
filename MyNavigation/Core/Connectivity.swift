import Foundation
import Network

/// B0-11 断网感知（ConnectivityManager → NWPathMonitor）
enum Connectivity {
    private static let monitor = NWPathMonitor()
    private static var handler: ((Bool) -> Void)?
    private(set) static var isOnline = true

    static func observe(_ onChange: @escaping (Bool) -> Void) {
        handler = onChange
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                isOnline = online
                onChange(online)
            }
        }
        monitor.start(queue: DispatchQueue(label: "connectivity"))
    }
}
