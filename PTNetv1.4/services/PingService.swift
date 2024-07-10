import Foundation
import NetDiagnosis

class PingService {
    func execute(address: String, completion: @escaping (PingDTO) -> Void) {
        if let ipAddress = DnsLookUpService().execute(domain: address).first {
            guard let remoteAddr = IPAddr.create(ipAddress, addressFamily: .ipv4) else {
                completion(PingDTO(address: ipAddress, ip: "", time: -1))
                return
            }
            
            do {
                let pinger = try Pinger(remoteAddr: remoteAddr)
                pinger.ping { result in
                    DispatchQueue.main.async {
                        let pingResult = self.parsePingResult(result, address: address)
                        completion(pingResult)
                    }
                }
            } catch {
                completion(PingDTO(address: address, ip: "", time: -1))
            }

        }
    }
    
    private func parsePingResult(_ result: Pinger.PingResult, address: String) -> PingDTO {
        switch result {
        case .pong(let response):
            let roundedRTT = Double(round(1000 * response.rtt * 1000) / 1000)
            return PingDTO(address: address, ip: response.from.description, time: roundedRTT)
        case .hopLimitExceeded(let response):
            let roundedRTT = Double(round(1000 * response.rtt * 1000) / 1000)
            return PingDTO(address: address, ip: response.from.description, time: roundedRTT)
        case .timeout:
            return PingDTO(address: address, ip: "", time: -1)
        case .failed:
            return PingDTO(address: address, ip: "", time: -1)
        }
    }
}
