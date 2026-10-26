import AppKit
import AVFoundation
import Combine

final class CameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let state: SceneState
    let work = DispatchQueue(label: "Nocturne.render", qos: .userInitiated)
    private let session = AVCaptureSession()
    private var renderer: SceneRenderer?
    private let sink = CameraSink()
    private var demoTimer: DispatchSourceTimer?
    private var running = false
    private var lastFrame = 0.0
    private var lastUI = 0.0
    var onFrame: ((CGImage, String, String, String) -> Void)?
    var onError: ((String) -> Void)?
    var onRunning: ((Bool) -> Void)?

    init(state: SceneState) { self.state = state; super.init() }

    func prepare() {
        work.async {
            do {
                guard let url = Bundle.main.url(forResource: "castle", withExtension: "png") else {
                    throw NSError(domain: "Nocturne", code: 3, userInfo: [NSLocalizedDescriptionKey: "Castle artwork is missing."])
                }
                self.renderer = try SceneRenderer(assetURL: url)
                self.startDemo()
            } catch { self.report(error.localizedDescription) }
        }
    }

    private func startDemo() {
        demoTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: work)
        timer.schedule(deadline: .now(), repeating: 1.0 / 15)
        timer.setEventHandler { [weak self] in self?.process(nil, publish: false) }
        demoTimer = timer; timer.resume()
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            guard let self else { return }
            guard allowed else { self.report("Camera access is off. Enable Nocturne in System Settings → Privacy & Security → Camera, then try again."); return }
            self.work.async {
                guard !self.running else { return }
                do {
                    if self.session.inputs.isEmpty {
                        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external],
                            mediaType: .video, position: .unspecified)
                        guard let device = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) ??
                            discovery.devices.first(where: { !$0.localizedName.contains("Nocturne") }) else {
                            throw NSError(domain: "Nocturne", code: 4, userInfo: [NSLocalizedDescriptionKey: "No physical camera found. Connect a camera and try again."])
                        }
                        let input = try AVCaptureDeviceInput(device: device)
                        self.session.beginConfiguration()
                        self.session.sessionPreset = .hd1280x720
                        guard self.session.canAddInput(input) else {
                            self.session.commitConfiguration()
                            throw NSError(domain: "Nocturne", code: 5, userInfo: [NSLocalizedDescriptionKey: "This camera is unavailable. Close other camera apps and try again."])
                        }
                        self.session.addInput(input)
                        let output = AVCaptureVideoDataOutput()
                        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                        output.alwaysDiscardsLateVideoFrames = true
                        output.setSampleBufferDelegate(self, queue: self.work)
                        guard self.session.canAddOutput(output) else {
                            self.session.removeInput(input); self.session.commitConfiguration()
                            throw NSError(domain: "Nocturne", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not create camera output."])
                        }
                        self.session.addOutput(output)
                        self.session.commitConfiguration()
                        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 24 && $0.maxFrameRate >= 24 }) {
                            try device.lockForConfiguration()
                            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 24)
                            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 24)
                            device.unlockForConfiguration()
                        }
                    }
                    self.demoTimer?.cancel(); self.demoTimer = nil
                    self.running = true
                    self.session.startRunning()
                    if !self.session.isRunning { self.running = false; self.startDemo(); self.report("The camera could not start. Check camera access and try again.") }
                    else { DispatchQueue.main.async { self.onRunning?(true) } }
                } catch { self.report(error.localizedDescription) }
            }
        }
    }

    func stop() {
        state.update { $0.cancelPerformance() }
        work.async {
            self.running = false; self.session.stopRunning(); self.sink.stop(); self.startDemo()
            DispatchQueue.main.async { self.onRunning?(false) }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard running, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = ProcessInfo.processInfo.systemUptime
        guard time - lastFrame >= 1.0 / 26 else { return }
        lastFrame = time
        process(buffer, publish: true)
    }

    private func process(_ input: CVPixelBuffer?, publish: Bool) {
        guard let renderer else { return }
        autoreleasepool {
            do {
                let time = ProcessInfo.processInfo.systemUptime
                let options = state.read()
                let buffer = try renderer.render(input: input, options: options, time: time)
                if publish { sink.send(buffer) }
                if time - lastUI > 1.0 / 15,
                   let cg = renderer.context.createCGImage(CIImage(cvPixelBuffer: buffer), from: renderer.bounds) {
                    lastUI = time
                    let status = renderer.segmentationFailed ? "Cutout unavailable — showing castle for privacy" :
                        (publish ? sink.status : "Scene preview · camera off")
                    let tracking = renderer.trackingStatus
                    let cue = publish ? options.performance(at: time)?.label ?? "" : ""
                    DispatchQueue.main.async { self.onFrame?(cg, status, tracking, cue) }
                }
            } catch {
                if running { running = false; session.stopRunning(); sink.stop() }
                report(error.localizedDescription)
            }
        }
    }

    private func report(_ message: String) {
        state.update { $0.cancelPerformance() }
        DispatchQueue.main.async { self.onError?(message) }
    }
}
