import SwiftUI
import NetworkExtension
import Network
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import NetDiagnosis
import RxSwift
import RxNetDiagnosis
import PTNetFramework

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

struct MainView: View {
    var body: some View {
        TabView {
            PingView()
                .tabItem {
                    Label("Ping", systemImage: "waveform.path.ecg")
                }.gesture(
                    TapGesture()
                        .onEnded { _ in
                            UIApplication.shared.endEditing()
                        }
                )
            
            TracerouteView()
                .tabItem {
                    Label("Traceroute", systemImage: "arrow.triangle.branch")
                }.gesture(
                    TapGesture()
                        .onEnded { _ in
                            UIApplication.shared.endEditing()
                        }
                )
            
            DNSLookUpView()
                .tabItem {
                    Label("DNS Lookup", systemImage: "magnifyingglass.circle")
                }.gesture(
                    TapGesture()
                        .onEnded { _ in
                            UIApplication.shared.endEditing()
                        }
                )
            PageLoadView()
                .tabItem{
                    Label("Page Load", systemImage: "arrow.clockwise")
                }.gesture(
                    TapGesture()
                        .onEnded {_ in
                            UIApplication.shared.endEditing()
                        }
                )
            PortScanView()
                .tabItem{
                    Label("Port Scan", systemImage: "network")
                }.gesture(
                    TapGesture()
                        .onEnded {_ in
                            UIApplication.shared.endEditing()
                        }
                )
        }
    }
}
let libraryHandler = LibraryHandler()
struct PingView: View {
    @State private var txtHost = "Facebook.com"
    @State private var lblPingResult = ""
    let ipConfigService = IpConfigService()
    let locationManager = CLLocationManager()
    @State private var ssid = ""
    @State private var bssid = ""
    @State private var defaultGateway = ""
    @State private var subnetMask = ""
    @State private var ipAddress = ""
    @State private var externalIpAddress = ""
    
    var body: some View {
        VStack {
            TextField("Host", text: $txtHost)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Launch") {
                DispatchSerialQueue.main.async {
                    let pinger = PingICMP()
                    pinger.execute(address: txtHost) { pingDTO in
                        let result = "\(pingDTO.address) - \(pingDTO.ip) - \(pingDTO.time)ms"
                        
                        lblPingResult += result + "\n"
                    }
                    libraryHandler.pingAddress(address: txtHost, completion: { callback in
                        print(callback)
                    })
                }
            }
            .padding()
            
            TextEditor(text: $lblPingResult)
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding()
            
            VStack {
                Button(action: {
                    reloadNetworkInfo()
                }) {
                    Text("Reload")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Text("IP Address: \(ipAddress)")
                Text("Subnet Mask: \(subnetMask)")
                Text("Default Gateway: \(defaultGateway)")
                Text("External IP Address: \(externalIpAddress)")
                Text("SSID: \(ssid)")
                Text("BSSID: \(bssid)")
            }
            .onAppear {
                reloadNetworkInfo()
            }
        }
        .padding()
    }
    
    func reloadNetworkInfo() {
        locationManager.requestAlwaysAuthorization()
        
        let service = IpConfigService()
        ipAddress = service.getIPAddress()
        subnetMask = service.getSubnetMask()
        defaultGateway = "N/A"
        service.getExternalIpAddress(completion: { callback in
            externalIpAddress = callback
        })
        service.getDefaultGateway(completion: { callbackString in
            defaultGateway = callbackString
        })
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse, .authorizedAlways:
            let ssid = ipConfigService.getWiFiSSID()
            let bssid = ipConfigService.getWiFiBSSID()
            print("SSID: \(ssid), BSSID: \(bssid)")
        case .denied, .restricted:
            // Không có quyền truy cập vị trí
            print("Không có quyền truy cập vị trí chính xác.")
            // Bạn có thể hiển thị một thông báo yêu cầu người dùng cấp quyền trong trường hợp này
        case .notDetermined:
            // Chưa xác định được trạng thái quyền, yêu cầu quyền truy cập
            locationManager.requestWhenInUseAuthorization() // hoặc requestAlwaysAuthorization() tùy vào yêu cầu của ứng dụng
        @unknown default:
            break
        }
        
        // =======================================================
        
    }
}
private func formatPingResult(_ result: Pinger.PingResult) -> String {
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 3
    
    switch result {
    case .pong(let response):
        let roundedRTT = formatter.string(for: response.rtt) ?? "\(response.rtt)"
        return "pong(len: \(response.len), from: \(response.from), hopLimit: \(response.hopLimit), sequence: \(response.sequence), identifier: \(response.identifier), rtt: \(roundedRTT)s)"
    case .hopLimitExceeded(let response):
        let roundedRTT = formatter.string(for: response.rtt) ?? "\(response.rtt)"
        return "hopLimitExceeded(len: \(response.len), from: \(response.from), hopLimit: \(response.hopLimit), sequence: \(response.sequence), identifier: \(response.identifier), rtt: \(roundedRTT)s)"
    case .timeout(let sequence, let identifier):
        return "timeout(sequence: \(sequence), identifier: \(identifier))"
    case .failed(let error):
        return "failed(error: \(error.localizedDescription))"
    }
}

struct TracerouteView: View {
    @State private var txtHost = "Facebook.com"
    @State private var lblPingResult = ""
    
    var body: some View {
        VStack {
            TextField("Host", text: $txtHost)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Launch") {
                performTrace()
            }.padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            
            TextEditor(text: $lblPingResult)
                .frame(height: 400)
                .border(Color.gray, width: 1)
                .padding()
        }
        .padding()
    }
    
    //        private func performTrace() {
    //            if let ipAddress = DnsLookUpService().execute(domain: txtHost).first {
    //                if let ipAddr = IPAddr.create(ipAddress, addressFamily: .ipv4) {
    //                    do {
    //                        let pinger = try Pinger(remoteAddr: ipAddr)
    //                        lblPingResult = ""
    //                        pinger.trace(
    //                            packetSize: nil,
    //                            initHop: 1,
    //                            maxHop: 64,
    //                            packetCount: 1,
    //                            timeOut: 1.0,
    //                            tracePacketCallback: { packetResult, stopTrace in
    //                                // Handle each packet result here
    //                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    //                                    lblPingResult += "Packet result for hop \(packetResult.hop): \(packetResult.pingResult)\n"
    //    //                                Thread.sleep(forTimeInterval: 1)
    //                                }
    //                                // You can use stopTrace(true) to stop tracing if needed
    //                            },
    //                            onTraceComplete: { result, status in
    //    //                            DispatchQueue.main.async {
    //    //                                for (hop, responses) in result {
    //    //                                    //                                    lblPingResult += "\n"
    //    //                                    for response in responses {
    //    //                                        lblPingResult += "Hop: \(hop): \(response)\n"
    //    //                                    }
    //    //                                }
    //    //                                //                                lblPingResult += "Complete Status: \(status)\n"
    //    //                            }
    //                            }
    //                        )
    //                    } catch {
    //                        DispatchQueue.main.async {
    //                            lblPingResult += "Failed to initialize Pinger: \(error)\n"
    //                        }
    //                    }
    //                } else {
    //                    DispatchQueue.main.async {
    //                        lblPingResult += "Failed to create IPAddr from ipAddress: \(ipAddress)\n"
    //                    }
    //                }
    //            } else {
    //                DispatchQueue.main.async {
    //                    lblPingResult += "Dns Resolving error\n"
    //                }
    //            }
    //        }
    
    
    
    
    private func performTrace() {
        let tracerouteService = TracerouteService()
        var lastTraceIpAddress = ""
        
        lblPingResult = ""
        
        let traceHopCallback: (TraceHopDTO) -> Void = { traceHop in
            if traceHop.ipAddress == lastTraceIpAddress {
                print("Reached same IP address, stopping trace.")
                return
            }
            
            print(traceHop)
            lblPingResult += "\(traceHop)\n\n"
            //            lblPingResult += "IpAddress: \(traceHop.ipAddress)\nDomain: \(traceHop.domain)\nTime \(traceHop.time)ms\nStatus: \(traceHop.status)\n\n"
            lastTraceIpAddress = traceHop.ipAddress
        }
        
        tracerouteService.execute(address: txtHost, traceHopCallBack: traceHopCallback)
    }
}

struct DNSLookUpView: View {
    @State private var txtHost = "hi.fpt.vn"
    @State private var lblPingResult = ""
    
    var body: some View {
        VStack {
            TextField("Domain", text: $txtHost)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Launch") {
                lblPingResult = ""
                do {
                    let ipAddresses = DnsLookUpService().execute(domain: txtHost)
                    if ipAddresses.isEmpty {
                        lblPingResult = "Error resolving DNS of this IP"
                    } else {
                        for ip in ipAddresses {
                            lblPingResult += "\(ip)\r\n"
                        }
                    }
                }
            }
            .padding()
            
            TextEditor(text: $lblPingResult)
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding()
        }
        .padding()
    }
}

struct PageLoadView: View {
    @State private var txtHost = "https://hi.fpt.vn/"
    @State private var lblPingResult = ""
    let jsonEncoder = JSONEncoder()
    @State private var pageLoadDTO = PageLoadDTO(data: "", status: "", statusCode: 0, responseTime: 0, message: "")
    var body: some View {
        VStack {
            TextField("Domain", text: $txtHost)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Launch") {
                lblPingResult = ""
                pageLoadDTO = PageLoadService().pageLoadTimer(address: txtHost)
                //                    let jsonData = try JSONEncoder().encode(pageLoadDTO)
                //                    if let json = String(data: jsonData, encoding: .utf8) {
                //                        lblPingResult = "\(json)\n"
                //                    }
                lblPingResult = "Status: \(pageLoadDTO.status)\nStatus Code: \(pageLoadDTO.statusCode)\nResponse Time: \(pageLoadDTO.responseTime)\nMessage: \(pageLoadDTO.message)\nData: \(pageLoadDTO.data)"
                
            }
            .padding()
            
            
            TextEditor(text: $lblPingResult)
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding()
        }
        .padding()
    }
}

struct PortScanView: View {
    @State private var txtHost = "hi.fpt.vn"
    @State private var startPortText = "1"
    @State private var endPortText = "1023"
    @State private var lblScanResult = ""
    @State private var currentPort = 0
    @State private var progress: Float = 0.0
    
    var body: some View {
        VStack {
            TextField("Host", text: $txtHost)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                TextField("Start Port", text: $startPortText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                TextField("End Port", text: $endPortText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }
            
            Button("Scan") {
                guard let startPort = Int(startPortText),
                      let endPort = Int(endPortText) else {
                    lblScanResult += "Invalid port numbers\n"
                    return
                }
                
                let portScanService = PortScanService()
                lblScanResult = ""
                currentPort = startPort
                progress = 0.0
                
                let timeOut: TimeInterval = 0.05
                let totalPorts = endPort - startPort + 1
                
                DispatchQueue.global().async {
                    for port in startPort...endPort {
                        let scanningPort = portScanService.execute(address: txtHost, port: port, timeOut: timeOut)
                        if !scanningPort.isEmpty {
                            lblScanResult += "Port \(port) is open\n"
                        } else {
                            //                            lblScanResult += "Port \(port) is closed or unreachable\n"
                        }
                        currentPort = port
                        progress = Float(port - startPort + 1) / Float(totalPorts)
                        
                    }
                }
            }
            .padding()
            
            ProgressView(value: progress)
                .padding()
            
            Text("Scanning port: \(currentPort)")
                .padding()
            
            TextEditor(text: $lblScanResult)
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding()
        }
        .padding()
    }
}
