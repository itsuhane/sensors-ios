import CoreMotion
import CoreLocation

protocol MotionDelegate : class {
    func motionDidGyroscopeUpdate(timestamp: Double, rotationRateX: Double, rotationRateY: Double, rotationRateZ: Double)
    func motionDidAccelerometerUpdate(timestamp: Double, accelerationX: Double, accelerationY: Double, accelerationZ: Double)
    func motionDidMagnetometerUpdate(timestamp: Double, magnetFieldX: Double, magnetFieldY: Double, magnetFieldZ: Double)
    func motionDidAltimeterUpdate(timestamp: Double, pressure: Double, relativeAltitude: Double)
    func motionDidDeviceMotionUpdate(deviceMotion: CMDeviceMotion)
    func motionDidLocationUpdate(timestamp: Double, longitude: Double, latitude: Double, altitude: Double, horizontalAccuracy: Double, verticalAccuracy: Double)
}

extension MotionDelegate {
    func motionDidMagnetometerUpdate(timestamp: Double, magnetFieldX: Double, magnetFieldY: Double, magnetFieldZ: Double) {
    }
    
    func motionDidAltimeterUpdate(timestamp: Double, pressure: Double, relativeAltitude: Double) {
    }
    
    func motionDidDeviceMotionUpdate(deviceMotion: CMDeviceMotion) {
    }
    
    func motionDidLocationUpdate(timestamp: Double, longitude: Double, latitude: Double, altitude: Double, horizontalAccuracy: Double, verticalAccuracy: Double) {
    }
}

class Motion: NSObject, CLLocationManagerDelegate {
    weak var delegate: MotionDelegate? = nil

    init?(updateInterval: TimeInterval = 0.01, queue: OperationQueue? = nil) {
        guard updateInterval > 0 else {
            return nil
        }

        super.init()

        self.motionManager.gyroUpdateInterval = updateInterval
        self.motionManager.accelerometerUpdateInterval = updateInterval
        self.motionManager.magnetometerUpdateInterval = updateInterval
        self.motionManager.deviceMotionUpdateInterval = updateInterval
        
        let q = queue ?? .main

        if self.motionManager.isGyroAvailable {
            self.motionManager.startGyroUpdates(to: q) {
                [weak self] (data, error) in
                guard let delegate = self?.delegate, let record = data, error == nil else {
                        return
                }
                delegate.motionDidGyroscopeUpdate(timestamp: record.timestamp, rotationRateX: record.rotationRate.x, rotationRateY: record.rotationRate.y, rotationRateZ: record.rotationRate.z)
            }
        }

        if self.motionManager.isAccelerometerAvailable {
            self.motionManager.startAccelerometerUpdates(to: q) {
                [weak self] (data, error) in
                guard let delegate = self?.delegate, let record = data, error == nil else {
                        return
                }
                delegate.motionDidAccelerometerUpdate(timestamp: record.timestamp, accelerationX: record.acceleration.x, accelerationY: record.acceleration.y, accelerationZ: record.acceleration.z)
            }
        }
        
        if self.motionManager.isMagnetometerAvailable {
            self.motionManager.startMagnetometerUpdates(to: q) {
                [weak self] (data, error) in
                guard let delegate = self?.delegate, let record = data, error == nil else {
                    return
                }
                delegate.motionDidMagnetometerUpdate(timestamp: record.timestamp, magnetFieldX: record.magneticField.x, magnetFieldY: record.magneticField.y, magnetFieldZ: record.magneticField.z)
            }
        }
        
        if self.motionManager.isDeviceMotionAvailable {
            self.motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: q) {
                [weak self] (data, error) in
                guard let delegate = self?.delegate, let record = data, error == nil else {
                    return
                }
                delegate.motionDidDeviceMotionUpdate(deviceMotion: record)
            }
        }
        
        if CMAltimeter.isRelativeAltitudeAvailable() {
            self.altimeter.startRelativeAltitudeUpdates(to: q) {
                [weak self] (data, error) in
                guard let delegate = self?.delegate, let record = data, error == nil else {
                    return
                }
                delegate.motionDidAltimeterUpdate(timestamp: record.timestamp, pressure: record.pressure.doubleValue, relativeAltitude: record.relativeAltitude.doubleValue)
            }
        }
        

        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.startUpdatingLocation()
        }
    }

    deinit {
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.stopUpdatingLocation()
            self.locationManager.delegate = nil
        }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            self.altimeter.stopRelativeAltitudeUpdates()
        }
        if self.motionManager.isDeviceMotionActive {
            self.motionManager.stopDeviceMotionUpdates()
        }
        if self.motionManager.isMagnetometerActive {
            self.motionManager.stopMagnetometerUpdates()
        }
        if self.motionManager.isAccelerometerActive {
            self.motionManager.stopAccelerometerUpdates()
        }
        if self.motionManager.isGyroActive {
            self.motionManager.stopGyroUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let delegate = self.delegate else {
            return
        }
        for location in locations {
            delegate.motionDidLocationUpdate(timestamp: location.timestamp.timeIntervalSince1970 - App.systemBootTime,  longitude: location.coordinate.longitude, latitude: location.coordinate.latitude, altitude: location.altitude, horizontalAccuracy: location.horizontalAccuracy, verticalAccuracy: location.verticalAccuracy)
        }
    }
    
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()
}
