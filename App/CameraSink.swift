import Foundation
import CoreMediaIO

/// Delivers frames to the extension's CMIO sink. No recording, network, or shared image files.
final class CameraSink {
    private var device: CMIODeviceID = 0
    private var stream: CMIOStreamID = 0
    private var queue: CMSimpleQueue?
    private var lastAttempt = Date.distantPast
    private(set) var status = "Virtual camera not connected"

    func connect() {
        guard queue == nil, Date().timeIntervalSince(lastAttempt) > 2 else { return }
        lastAttempt = Date()
        var allow: UInt32 = 1
        var allowAddress = CMIOObjectPropertyAddress(mSelector: UInt32(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: UInt32(kCMIOObjectPropertyScopeGlobal), mElement: UInt32(kCMIOObjectPropertyElementMain))
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &allowAddress, 0, nil, 4, &allow)
        for id in objects(CMIOObjectID(kCMIOObjectSystemObject), selector: UInt32(kCMIOHardwarePropertyDevices)) {
            var address = CMIOObjectPropertyAddress(mSelector: UInt32(kCMIOObjectPropertyName),
                mScope: UInt32(kCMIOObjectPropertyScopeGlobal), mElement: UInt32(kCMIOObjectPropertyElementMain))
            var name: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard CMIOObjectGetPropertyData(id, &address, 0, nil, size, &size, &name) == noErr,
                let name, name.takeUnretainedValue() as String == VideoFormat.cameraName else { continue }
            for candidate in objects(id, selector: UInt32(kCMIODevicePropertyStreams)) {
                var directionAddress = CMIOObjectPropertyAddress(mSelector: UInt32(kCMIOStreamPropertyDirection),
                    mScope: UInt32(kCMIOObjectPropertyScopeGlobal), mElement: UInt32(kCMIOObjectPropertyElementMain))
                var direction: UInt32 = 99
                size = 4
                guard CMIOObjectGetPropertyData(candidate, &directionAddress, 0, nil, size, &size, &direction) == noErr,
                    direction == 0 else { continue } // Output from the app into the device.
                var q: Unmanaged<CMSimpleQueue>?
                let result = CMIOStreamCopyBufferQueue(candidate, { _, _, _ in }, nil, &q)
                guard result == noErr, let q else { status = "Camera queue unavailable (\(result))"; continue }
                let retained = q.takeRetainedValue()
                let started = CMIODeviceStartStream(id, candidate)
                guard started == noErr else { status = "Camera start failed (\(started))"; continue }
                device = id; stream = candidate; queue = retained
                status = "Sending to Nocturne Camera"
                return
            }
        }
        status = "Enable the camera extension to connect Teams"
    }

    func send(_ pixelBuffer: CVPixelBuffer) {
        connect()
        guard let queue, CMSimpleQueueGetCount(queue) < CMSimpleQueueGetCapacity(queue),
            let sample = VideoFormat.sample(pixelBuffer) else { return }
        let pointer = Unmanaged.passRetained(sample).toOpaque()
        let result = CMSimpleQueueEnqueue(queue, element: pointer)
        if result != noErr { Unmanaged<CMSampleBuffer>.fromOpaque(pointer).release() }
    }

    func stop() {
        if stream != 0 { CMIODeviceStopStream(device, stream) }
        if let queue {
            while let pointer = CMSimpleQueueDequeue(queue) {
                Unmanaged<CMSampleBuffer>.fromOpaque(pointer).release()
            }
        }
        queue = nil; stream = 0; device = 0
        lastAttempt = .distantPast
        status = "Virtual camera stopped"
    }

    private func objects(_ object: CMIOObjectID, selector: CMIOObjectPropertySelector) -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(mSelector: selector, mScope: UInt32(kCMIOObjectPropertyScopeGlobal),
            mElement: UInt32(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return [] }
        var values = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        guard CMIOObjectGetPropertyData(object, &address, 0, nil, size, &size, &values) == noErr else { return [] }
        return values
    }
}
