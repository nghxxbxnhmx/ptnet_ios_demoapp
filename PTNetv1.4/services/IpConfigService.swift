import Foundation
import Network
import SystemConfiguration.CaptiveNetwork
import NetworkExtension
import CoreLocation

class IpConfigService {
    
    func getIPAddress() -> String {
        var address: String? = ""
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "N/A" }
        defer { freeifaddrs(ifaddr) }
        
        guard let firstAddr = ifaddr else { return "N/A" }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                             &hostname, socklen_t(hostname.count),
                                             nil, socklen_t(0), NI_NUMERICHOST)
                    if result == 0 {
                        address = String(cString: hostname)
                        break
                    }
                }
            }
        }
        
        return address ?? "N/A"
    }

    func getSubnetMask() -> String {
        var subnetMask: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "N/A" }
        defer { freeifaddrs(ifaddr) }
        
        guard let firstAddr = ifaddr else { return "N/A" }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var netmask = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(interface.ifa_netmask, socklen_t(interface.ifa_netmask.pointee.sa_len),
                                             &netmask, socklen_t(netmask.count),
                                             nil, socklen_t(0), NI_NUMERICHOST)
                    if result == 0 {
                        subnetMask = String(cString: netmask)
                        break
                    }
                }
            }
        }
        
        return subnetMask ?? "N/A"
    }
    
    func getWiFiSSID() -> String {
        var ssid: String?
        
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? {
                    ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
                    break
                }
            }
        }
        
        return ssid ?? "N/A"
    }
    
    func getWiFiBSSID() -> String {
        var bssid: String?
        
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? {
                    bssid = interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
                    break
                }
            }
        }
        
        return bssid ?? "N/A"
    }
    
    func getExternalIpAddress(completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://api.ipify.org") else {
            completion("N/A")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                completion("N/A")
                return
            }
            
            if let data = data, let ipAddress = String(data: data, encoding: .utf8) {
                completion(ipAddress)
            } else {
                completion("N/A")
            }
        }
        
        task.resume()
    }
    
    func getDefaultGateway(completion: @escaping (String) -> Void) {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { path in
            let gateways = path.gateways.map { $0.debugDescription }.joined(separator: ", ")
            completion(gateways)
            monitor.cancel()
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
}
