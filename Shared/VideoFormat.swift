import Foundation
import CoreMedia
import CoreVideo

enum VideoFormat {
    static let width = 1280
    static let height = 720
    static let fps: Int32 = 24
    static let cameraName = "Nocturne Camera"
    static let deviceID = UUID(uuidString: "9839F017-7211-4F78-88A2-280A28EB981A")!
    static let sourceID = UUID(uuidString: "9839F017-7211-4F78-88A2-280A28EB981B")!
    static let sinkID = UUID(uuidString: "9839F017-7211-4F78-88A2-280A28EB981C")!
    static let extensionID = "com.gilpenner.Nocturne.CameraExtension"

    static func description() -> CMVideoFormatDescription {
        var value: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA,
            width: Int32(width), height: Int32(height), extensions: nil, formatDescriptionOut: &value)
        return value!
    }

    static func sample(_ buffer: CVPixelBuffer) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: fps),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer,
            dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: description(),
            sampleTiming: &timing, sampleBufferOut: &sample)
        return sample
    }
}
