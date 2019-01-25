import UIKit

class App {
    class func loadSetting<T>(key: String, def: T) -> T {
        guard let object = UserDefaults.standard.object(forKey: key) else {
            return def
        }
        return object as! T
    }

    class func saveSetting<T>(key: String, value: T) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    class var keepAwake: Bool {
        get {
            return UIApplication.shared.isIdleTimerDisabled
        }
        set {
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
    }
    
    class var documentDirectory: String {
        get {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            return paths[0]
        }
    }
    
    class var ipv4Address: String? {
        get {
            return App.getIpAddress(afFamily: AF_INET)
        }
    }

    class var ipv6Address: String? {
        get {
            return App.getIpAddress(afFamily: AF_INET6)
        }
    }
    
    class var currentDateTimeString: String {
        get {
            let datetime = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
            return formatter.string(from: datetime)
        }
    }
    
    private class func getIpAddress(afFamily: Int32) -> String? {
        var address : String? = nil
        
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            return nil
        }
        guard let firstIfaddr = ifaddr else {
            return nil
        }
        for ptr in sequence(first: firstIfaddr, next: {$0.pointee.ifa_next}) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(afFamily) {
                    let name = String(cString: ptr.pointee.ifa_name)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                            address = String(cString: hostname)
                        }
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
}
