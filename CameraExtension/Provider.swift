import Foundation
import CoreMediaIO
import IOKit.audio
import CoreImage

final class Provider: NSObject, CMIOExtensionProviderSource {
    var provider: CMIOExtensionProvider!
    let camera = CameraDevice()
    override init() {
        super.init()
        provider = CMIOExtensionProvider(source: self, clientQueue: camera.work)
        try! provider.addDevice(camera.device)
    }
    var availableProperties: Set<CMIOExtensionProperty> { [.providerManufacturer] }
    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let p = CMIOExtensionProviderProperties(dictionary: [:]); p.manufacturer = "Nocturne"; return p
    }
    func setProviderProperties(_ properties: CMIOExtensionProviderProperties) throws {}
    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) { camera.disconnect(client) }
}

final class CameraDevice: NSObject, CMIOExtensionDeviceSource {
    var device: CMIOExtensionDevice!
    var output: CameraStream!
    var input: CameraStream!
    let work = DispatchQueue(label: "Nocturne.extension")
    private var timer: DispatchSourceTimer?
    private var consumers = 0
    private var producer: CMIOExtensionClient?
    private var consuming = false
    private var latest: CVPixelBuffer?
    private var lastReceived: Double = 0
    private var standby: CVPixelBuffer!

    override init() {
        super.init()
        device = CMIOExtensionDevice(localizedName: VideoFormat.cameraName, deviceID: VideoFormat.deviceID, legacyDeviceID: nil, source: self)
        output = CameraStream(owner: self, direction: .source)
        input = CameraStream(owner: self, direction: .sink)
        try! device.addStream(output.stream); try! device.addStream(input.stream)
        CVPixelBufferCreate(nil, VideoFormat.width, VideoFormat.height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &standby)
        CIContext().render(CIImage(color: CIColor(red: 0.025, green: 0.035, blue: 0.06)), to: standby)
    }

    var availableProperties: Set<CMIOExtensionProperty> { [.deviceTransportType, .deviceModel] }
    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let p = CMIOExtensionDeviceProperties(dictionary: [:])
        p.transportType = kIOAudioDeviceTransportTypeVirtual; p.model = "Nocturne Camera"; return p
    }
    func setDeviceProperties(_ properties: CMIOExtensionDeviceProperties) throws {}

    func startOutput() { consumers += 1; ensureTimer() }
    func stopOutput() { consumers = max(0, consumers - 1); stopTimerIfIdle() }
    func startInput(_ client: CMIOExtensionClient) { producer = client; ensureTimer() }
    func stopInput() {
        producer = nil; latest = nil; lastReceived = 0
        stopTimerIfIdle()
    }
    func disconnect(_ client: CMIOExtensionClient) {
        if producer?.clientID == client.clientID { stopInput() }
    }

    private func stopTimerIfIdle() {
        if consumers == 0 && producer == nil { timer?.cancel(); timer = nil }
    }
    private func ensureTimer() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: work)
        timer.schedule(deadline: .now(), repeating: 1.0 / Double(VideoFormat.fps))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer; timer.resume()
    }
    private func tick() {
        if let producer, !consuming {
            consuming = true
            input.stream.consumeSampleBuffer(from: producer) { [weak self] sample, sequence, _, _, _ in
                guard let self else { return }
                self.work.async {
                    self.consuming = false
                    guard self.producer?.clientID == producer.clientID else { return }
                    if let sample, let image = CMSampleBufferGetImageBuffer(sample) {
                        self.latest = image
                        self.lastReceived = ProcessInfo.processInfo.systemUptime
                        self.input.stream.notifyScheduledOutputChanged(CMIOExtensionScheduledOutput(sequenceNumber: sequence,
                            hostTimeInNanoseconds: UInt64(CMClockGetTime(CMClockGetHostTimeClock()).seconds * 1_000_000_000)))
                    }
                }
            }
        }
        guard consumers > 0 else { return }
        let image = ProcessInfo.processInfo.systemUptime - lastReceived < 0.75 ? latest ?? standby! : standby!
        guard let sample = VideoFormat.sample(image) else { return }
        output.stream.send(sample, discontinuity: [],
            hostTimeInNanoseconds: UInt64(CMSampleBufferGetPresentationTimeStamp(sample).seconds * 1_000_000_000))
    }
}

final class CameraStream: NSObject, CMIOExtensionStreamSource {
    unowned let owner: CameraDevice
    let direction: CMIOExtensionStream.Direction
    var stream: CMIOExtensionStream!
    var client: CMIOExtensionClient?
    init(owner: CameraDevice, direction: CMIOExtensionStream.Direction) {
        self.owner = owner; self.direction = direction; super.init()
        stream = CMIOExtensionStream(localizedName: direction == .source ? "Nocturne video" : "Nocturne input",
            streamID: direction == .source ? VideoFormat.sourceID : VideoFormat.sinkID,
            direction: direction, clockType: .hostTime, source: self)
    }
    var formats: [CMIOExtensionStreamFormat] {
        [CMIOExtensionStreamFormat(formatDescription: VideoFormat.description(),
            maxFrameDuration: CMTime(value: 1, timescale: VideoFormat.fps),
            minFrameDuration: CMTime(value: 1, timescale: VideoFormat.fps), validFrameDurations: nil)]
    }
    var availableProperties: Set<CMIOExtensionProperty> {
        direction == .source ? [.streamActiveFormatIndex, .streamFrameDuration] :
            [.streamActiveFormatIndex, .streamFrameDuration, .streamSinkBufferQueueSize, .streamSinkBuffersRequiredForStartup, .streamSinkEndOfData]
    }
    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let p = CMIOExtensionStreamProperties(dictionary: [:])
        p.activeFormatIndex = 0; p.frameDuration = CMTime(value: 1, timescale: VideoFormat.fps)
        if direction == .sink { p.sinkBufferQueueSize = 3; p.sinkBuffersRequiredForStartup = 1; p.sinkEndOfData = 0 }
        return p
    }
    func setStreamProperties(_ properties: CMIOExtensionStreamProperties) throws {
        if let index = properties.activeFormatIndex, index != 0 {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kCMIOHardwareUnsupportedOperationError))
        }
    }
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        self.client = client; return true
    }
    func startStream() throws {
        if direction == .source { owner.startOutput() }
        else if let client { owner.startInput(client) }
    }
    func stopStream() throws {
        if direction == .source { owner.stopOutput() } else { owner.stopInput(); client = nil }
    }
}
