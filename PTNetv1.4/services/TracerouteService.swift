import Foundation
import NetDiagnosis
import SystemConfiguration.CaptiveNetwork
import CoreLocation

class TracerouteService {
    func execute(address: String, traceHopCallBack: @escaping (TraceHopDTO) -> Void) {
        // Perform DNS lookup to get the IP address
        if let ipAddress = DnsLookUpService().execute(domain: address).first {
            
            // Validate the retrieved IP address
            if let ipAddr = IPAddr.create(ipAddress, addressFamily: .ipv4) {
                do {
                    // Create Pinger instance
                    let pinger = try Pinger(remoteAddr: ipAddr)
                    
                    // Start tracing
                    pinger.trace(
                        packetSize: nil,
                        initHop: 1,
                        maxHop: 64,
                        packetCount: 1,
                        timeOut: 1.0,
                        tracePacketCallback: { packetResult, stopTrace in
                            var traceResult = TraceHopDTO(hopNumber: 0, domain: "", ipAddress: ipAddress, time: 0, status: false)
                            
                            // Handle different ping results
                            switch packetResult.pingResult {
                            case .failed(let error):
                                traceResult.time = -1
                                traceResult.status = false
                                print("Failed with error: \(error)")
                            case .hopLimitExceeded(let response):
                                traceResult.time = round(response.rtt * 1000000) / 1000
                                traceResult.ipAddress = String("\(response.from)")
                                traceResult.status = true
                                print("Hop limit exceeded at \(response.from)")
                            case .pong(let response):
                                traceResult.time = round(response.rtt * 1000000) / 1000
                                traceResult.ipAddress = String("\(response.from)")
                                traceResult.status = true
                                print("Received pong from \(response.from)")
                            case .timeout(let sequence, let identifier):
                                traceResult.time = -1
                                traceResult.status = false
                                print("Timeout for sequence \(sequence) and identifier \(identifier)")
                            }
                            
                            // Set hop number
                            traceResult.hopNumber = Int(packetResult.hop)
                            
                            // Perform reverse DNS lookup
                            self.getHostByIP(ipAddress: traceResult.ipAddress) { callBackDomain in
                                DispatchQueue.main.async {
                                    // Update domain in trace result
                                    traceResult.domain = callBackDomain ?? ""
                                    if ipAddress == "192.168.1.1" {
                                        traceResult.domain = "Gateway"
                                    }
                                    // Execute callback with trace result
                                    traceHopCallBack(traceResult)
                                }
                            }
                        },
                        onTraceComplete: { result, status in
                            DispatchQueue.main.async {
                                print("Trace complete with status: \(status)")
                                // Handle completion if needed
                            }
                        }
                    )
                } catch {
                    DispatchQueue.main.async {
                        print("Error creating Pinger: \(error)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("Error creating IPAddr from \(ipAddress)")
                }
            }
        } else {
            DispatchQueue.main.async {
                print("DNS lookup failed for \(address)")
            }
        }
    }
    
    private func getHostByIP(ipAddress: String, completion: @escaping (String?) -> Void) {
        let host = CFHostCreateWithName(nil, ipAddress as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
           let theAddress = addresses.firstObject as? NSData {
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(theAddress.bytes.bindMemory(to: sockaddr.self, capacity: theAddress.length),
                           socklen_t(theAddress.length),
                           &hostname,
                           socklen_t(hostname.count),
                           nil,
                           0,
                           NI_NAMEREQD) == 0 {
                let name = String(cString: hostname)
                completion(name)
                return
            }
        }
        completion(nil)
    }
}
