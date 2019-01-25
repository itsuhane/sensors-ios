import CoreMotion
import CoreMedia

protocol PipelineOutput: class {
    var description: String { get set }
    func pipelineDidOutput(data: Data)
    func pipelineDidDrop()
}

class Pipeline : NSObject, CameraDelegate, MotionDelegate, EncoderDelegate {
    static let imageData = UInt8(0)
    static let gyroscopeData = UInt8(1)
    static let accelerometerData = UInt8(2)
    static let magnetometerData = UInt8(3)
    static let altimeterData = UInt8(4)
    static let deviceMotionData = UInt8(5)
    static let encoderData = UInt8(8)
    
    private weak var camera: Camera?
    private weak var motion: Motion?
    private weak var output: PipelineOutput?
    private let encoder: Encoder?
    private let saveRawImage: Bool

    init?(camera: Camera, motion: Motion, output: PipelineOutput? = nil, encode: Bool = true, saveRawImage: Bool = false) {
        if encode {
            guard let encoder = Encoder(width: camera.imageWidth, height: camera.imageHeight, fps: 30) else {
                return nil
            }
            self.encoder = encoder
        } else {
            self.encoder = nil
        }
        
        self.camera = camera
        self.motion = motion
        self.output = output
        self.saveRawImage = (self.encoder == nil) || saveRawImage

        super.init()
        
        self.motion?.delegate = self
        self.encoder?.delegate = self
        self.camera?.delegate = self
    }
    
    deinit {
        self.camera?.delegate = nil
        self.encoder?.delegate = nil
        self.motion?.delegate = nil
        self.motion = nil
        self.camera = nil
    }
    
    func cameraDidOutput(timestamp: CMTime, sampleBuffer: CMSampleBuffer) {
        encoder?.encodeFrame(timestamp, sampleBuffer: sampleBuffer)
        
        guard saveRawImage else {
            return
        }
        
        var data = Data(repeating: Pipeline.imageData, count: 1)
        [timestamp.seconds].withUnsafeBufferPointer {
            data.append($0)
        }
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            output?.pipelineDidDrop()
            return
        }
        imageBuffer.lockBaseAddress([])
        let width = imageBuffer.width
        let height = imageBuffer.height
        [UInt32(width), UInt32(height)].withUnsafeBufferPointer {
            data.append($0)
        }
        let bytePerRow = imageBuffer.getBytesPerRow(ofPlane: 0)
        let pointer = imageBuffer.getBaseAddress(ofPlane: 0)
        data.append(pointer!.assumingMemoryBound(to: UInt8.self), count: bytePerRow*height)
        imageBuffer.unlockBaseAddress([])
        
        output?.pipelineDidOutput(data: data)
    }
    
    func motionDidGyroscopeUpdate(timestamp: Double, rotationRateX: Double, rotationRateY: Double, rotationRateZ: Double) {
        var data = Data(repeating: Pipeline.gyroscopeData, count: 1)
        [timestamp, rotationRateX, rotationRateY, rotationRateZ].withUnsafeBufferPointer {
            data.append($0)
        }
        output?.pipelineDidOutput(data: data)
    }
    
    func motionDidAccelerometerUpdate(timestamp: Double, accelerationX: Double, accelerationY: Double, accelerationZ: Double) {
        var data = Data(repeating: Pipeline.accelerometerData, count: 1)
        [timestamp, accelerationX, accelerationY, accelerationZ].withUnsafeBufferPointer {
            data.append($0)
        }
        output?.pipelineDidOutput(data: data)
    }
    
    func motionDidMagnetometerUpdate(timestamp: Double, magnetFieldX: Double, magnetFieldY: Double, magnetFieldZ: Double) {
        var data = Data(repeating: Pipeline.magnetometerData, count: 1)
        [timestamp, magnetFieldX, magnetFieldY, magnetFieldZ].withUnsafeBufferPointer {
            data.append($0)
        }
        output?.pipelineDidOutput(data: data)
    }
    
    func motionDidAltimeterUpdate(timestamp: Double, pressure: Double, relativeAltitude: Double) {
        var data = Data(repeating: Pipeline.altimeterData, count: 1)
        [timestamp, pressure, relativeAltitude].withUnsafeBufferPointer {
            data.append($0)
        }
        output?.pipelineDidOutput(data: data)
    }
    
    func motionDidDeviceMotionUpdate(deviceMotion: CMDeviceMotion) {
    }
    
    func encoderDidOutput(timestamp: CMTime, sampleBuffer: CMSampleBuffer) {
        var data = Data(repeating: Pipeline.encoderData, count: 1)
        [timestamp.seconds].withUnsafeBufferPointer {
            data.append($0)
        }
        
        guard let sampleAttachmentsArray = sampleBuffer.sampleAttachmentsArray else {
            output?.pipelineDidDrop()
            return
        }
        let dictionary = sampleAttachmentsArray[0] as! Dictionary<String, AnyObject>
        let notSync = dictionary[String(kCMSampleAttachmentKey_NotSync)]
        
        let isKeyframe: Bool = !(notSync as? Bool ?? false)
        
        if isKeyframe {
            let formatDescription = sampleBuffer.formatDescription
            
            let spsData = formatDescription?.getH264ParameterSet(at: 0)
            let spsSize = spsData?.count ?? 0
            [UInt32(spsSize)].withUnsafeBufferPointer {
                data.append($0)
            }
            if spsData != nil {
                data.append(spsData!)
            }
            
            let ppsData = formatDescription?.getH264ParameterSet(at: 1)
            let ppsSize = ppsData?.count ?? 0
            [UInt32(ppsSize)].withUnsafeBufferPointer {
                data.append($0)
            }
            if ppsData != nil {
                data.append(ppsData!)
            }
        } else {
            [UInt32(0), UInt32(0)].withUnsafeBufferPointer {
                data.append($0)
            }
        }
        
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            output?.pipelineDidDrop()
            return
        }
        
        var bufferData = Data()
        var offset: Int = 0
        var lengthAtOffset = Int()
        var totalLength = Int()
        var dataPointer: UnsafeMutablePointer<Int8>? = nil
        repeat {
            guard dataBuffer.getDataPointer(offset, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr else {
                output?.pipelineDidDrop()
                return
            }
            dataPointer?.withMemoryRebound(to: UInt8.self, capacity: lengthAtOffset) {
                bufferData.append($0, count: lengthAtOffset)
            }
            offset += lengthAtOffset
        } while offset < totalLength
        
        bufferData.withUnsafeBytes {
            (bytes: UnsafePointer<UInt8>) in
            let avccHeaderLength: Int = 4
            var bufferOffset: Int = 0
            while bufferOffset + avccHeaderLength < bufferData.count {
                let nalLength = bytes.advanced(by: bufferOffset).withMemoryRebound(to: UInt32.self, capacity: 1) {
                    Int(CFSwapInt32BigToHost($0.pointee))
                }
                [UInt32(nalLength)].withUnsafeBufferPointer {
                    data.append($0)
                }
                bufferOffset += avccHeaderLength
                data.append(bytes.advanced(by: bufferOffset), count: nalLength)
                bufferOffset += nalLength
            }
        }
        [UInt32(0)].withUnsafeBufferPointer {
            data.append($0)
        }
        
        output?.pipelineDidOutput(data: data)
    }
    
    func cameraDidDrop() {
        output?.pipelineDidDrop()
    }
    
    func encoderDidDrop() {
        output?.pipelineDidDrop()
    }
}
