import Foundation
import Network

class PortScanService {
    private let maxConcurrentConnections = 10
    private var activeConnections = 0
    private let connectionSemaphore = DispatchSemaphore(value: 1)
    
    func execute(address: String, port: Int, timeOut: Double) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String = ""
        
        portScan(address: address, port: port, timeOut: timeOut) { scanResult in
            result = scanResult
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    private func portScan(address: String, port: Int, timeOut: Double, completion: @escaping (String) -> Void) {
        connectionSemaphore.wait()
        defer {
            connectionSemaphore.signal()
        }
        
//        guard activeConnections < maxConcurrentConnections else {
//            completion("")
//            return
//        }
        
        activeConnections += 1
        
        let queue = DispatchQueue.global(qos: .background)
        queue.async {
            let host = NWEndpoint.Host(address)
            let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let connection = NWConnection(host: host, port: nwPort, using: parameters)
            
            var hasCompleted = false
            
            // Start timeout timer
            let timeoutWorkItem = DispatchWorkItem {
                if !hasCompleted {
                    hasCompleted = true
                    connection.cancel()
                    completion("")
                }
            }
            queue.asyncAfter(deadline: .now() + timeOut, execute: timeoutWorkItem)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !hasCompleted {
                        hasCompleted = true
                        completion("\(port)")
                        connection.cancel()
                        timeoutWorkItem.cancel()
                    }
                case .failed, .cancelled:
                    if !hasCompleted {
                        hasCompleted = true
                        completion("")
                        timeoutWorkItem.cancel()
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
        }
    }
}
