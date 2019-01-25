import Foundation

class NetworkOutput : NSObject, PipelineOutput {
    private var _description: String = ""
    override var description: String {
        get {
            return _description
        }
        set {
            _description = newValue
        }
    }
    
    private let server: NetworkOutputServer
    
    init?(address: String) {
        guard let server = NetworkOutputServer(address) else {
            return nil
        }
        self.server = server
        super.init()
        self.description = address
    }
        
    func pipelineDidOutput(data: Data) {
        _ = data.withUnsafeBytes {
            self.server.send($0, maxLength: data.count)
        }
    }
    
    func pipelineDidDrop() {
    }
}
