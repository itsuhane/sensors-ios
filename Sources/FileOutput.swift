import Foundation

class FileOutput : NSObject, PipelineOutput {
    private var _description: String = ""
    override var description: String {
        get {
            return _description
        }
        set {
            _description = newValue
        }
    }
    
    private let outputStream: OutputStream
        
    init?(path: String) {
        guard let outputStream = OutputStream(toFileAtPath: path, append: false) else {
            return nil
        }
        self.outputStream = outputStream
        super.init()
        self.outputStream.open()
    }
    
    deinit {
        self.outputStream.close()
    }
    
    func pipelineDidOutput(data: Data) {
        _ = data.withUnsafeBytes {
            self.outputStream.write($0, maxLength: data.count)
        }
    }
    
    func pipelineDidDrop() {
    }
}
