import SwiftUI
import AppKit

@MainActor
final class CameraModel: ObservableObject {
    @Published var preview: CGImage?
    @Published var status = "Preparing the castle…"
    @Published var error: String?
    @Published var running = false
    @Published var starting = false
    @Published var vampire = true { didSet { state.update { $0.vampire = vampire } } }
    @Published var costume = true { didSet { state.update { $0.costume = costume } } }
    @Published var blood = true { didSet { state.update { $0.blood = blood } } }
    @Published var castle = true { didSet { state.update { $0.castle = castle } } }
    @Published var bats = true { didSet { state.update { $0.bats = bats } } }
    @Published var lightning = true { didSet { state.update { $0.autoLightning = lightning } } }
    @Published var normal = false { didSet { state.update { $0.normal = normal } } }
    @Published var intensity = 0.85 { didSet { state.update { $0.intensity = intensity } } }
    @Published var distance = 0.0 { didSet { state.update { $0.distance = distance } } }
    @Published var shortcutStatus = "Shortcuts work while Teams has focus."
    let state = SceneState()
    let pipeline: CameraPipeline
    let hotkeys = Hotkeys()

    init() {
        pipeline = CameraPipeline(state: state)
        state.update { $0.intensity = 0.85 }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            bats = false; lightning = false
            state.update { $0.bats = false; $0.autoLightning = false; $0.animateBlood = false }
        }
        pipeline.onFrame = { [weak self] image, status in self?.preview = image; self?.status = status }
        pipeline.onError = { [weak self] message in self?.error = message; self?.running = false; self?.starting = false }
        pipeline.onRunning = { [weak self] running in self?.running = running; self?.starting = false }
        hotkeys.action = { [weak self] id in self?.trigger(Int(id)) }
        if !hotkeys.register() { shortcutStatus = "Some shortcuts are already in use. Use the buttons below." }
        pipeline.prepare()
    }
    func toggleCamera() {
        error = nil
        if running { pipeline.stop(); running = false } else { starting = true; pipeline.start() }
    }
    func trigger(_ id: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        switch id {
        case 0: state.update { $0.lightningAt = now }
        case 1: state.update { $0.swarmAt = now }
        case 2: vampire.toggle()
        case 3: normal.toggle()
        case 4: state.update { $0.vanishAt = now; $0.swarmAt = now }
        default: break
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: CameraModel
    @ObservedObject var camera: ExtensionManager
    @State private var confirmRemoval = false

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Nocturne").font(.custom("Baskerville", size: 36))
                Text("YOUR AFTER-DARK CAMERA").font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2).foregroundStyle(Theme.muted)
                Spacer()
                Label(model.running ? "Camera on" : "Camera off", systemImage: model.running ? "video.fill" : "video.slash")
                    .font(.callout).foregroundStyle(model.running ? Theme.success : Theme.muted)
            }
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Rectangle().fill(Theme.panel)
                        if let image = model.preview {
                            Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                        } else { ProgressView().controlSize(.large) }
                    }.aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(model.status).font(.callout).foregroundStyle(Theme.muted)
                        .frame(height: 20, alignment: .leading).accessibilityLabel("Camera status: \(model.status)")
                    HStack {
                        Button(model.starting ? "Starting…" : model.running ? "Stop camera" : "Start camera", systemImage: model.running ? "stop.fill" : "video.fill") {
                            model.toggleCamera()
                        }.buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(Theme.background).controlSize(.large).disabled(model.starting)
                        Spacer()
                        Toggle("Normal camera", isOn: $model.normal).toggleStyle(.switch)
                            .help("Bypasses the castle and every effect. Control–Option–N.")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Distance").font(.callout)
                            Text("\(Int((1 - model.distance * 0.45) * 100))% size").font(.caption).monospacedDigit().foregroundStyle(Theme.muted)
                            Spacer()
                            Button("Reset") { model.distance = 0 }.buttonStyle(.link).disabled(model.distance == 0)
                        }
                        HStack(spacing: 10) {
                            Text("Original").font(.caption).foregroundStyle(Theme.muted)
                            Slider(value: $model.distance, in: 0...1).accessibilityLabel("Distance")
                                .help("Move right to appear farther away. Your makeup and costume follow you.")
                            Text("Farther").font(.caption).foregroundStyle(Theme.muted)
                        }
                        if !model.castle { Text("Turn on Castle & person cutout to adjust distance.").font(.caption).foregroundStyle(Theme.muted) }
                    }.disabled(!model.castle || model.normal)
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.triangle").font(.callout)
                            .foregroundStyle(Theme.accent).textSelection(.enabled)
                    }
                    Divider().overlay(Theme.muted.opacity(0.2))
                    Text("ON CUE").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(Theme.muted)
                    HStack(spacing: 10) {
                        cue("Lightning", symbol: "bolt.fill", keys: "⌃⌥L", id: 0)
                        cue("Bat swarm", symbol: "wind", keys: "⌃⌥B", id: 1)
                        cue("Vanish · 3s", symbol: "sparkles", keys: "⌃⌥G", id: 4)
                    }
                    Text(model.shortcutStatus).font(.caption).foregroundStyle(Theme.muted)
                }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 14) {
                    Text("The vampire").font(.custom("Baskerville", size: 23))
                    Toggle("Theatrical makeup", isOn: $model.vampire).help("Control–Option–V")
                    Text("Sunken eyes, dark veins, pale skin, and long fangs.").font(.callout).foregroundStyle(Theme.muted)
                    Toggle("Blood trails", isOn: $model.blood).disabled(!model.vampire || model.normal)
                    Toggle("Vampire attire", isOn: $model.costume).disabled(model.normal)
                        .help("A textured black cape, swept collar, brocade waistcoat, and silk cravat.")
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("Intensity"); Spacer(); Text(model.intensity, format: .percent.precision(.fractionLength(0))).monospacedDigit() }
                        Slider(value: $model.intensity, in: 0...1).accessibilityLabel("Vampire intensity")
                    }.disabled(!model.vampire || model.normal)
                    Divider()
                    Text("The grounds").font(.custom("Baskerville", size: 23))
                    Toggle("Castle & person cutout", isOn: $model.castle)
                    Toggle("Flying bats", isOn: $model.bats)
                    Toggle("Restless lightning storm", isOn: $model.lightning)
                    Text("Even light on your face helps the cutout. A plain wall is ideal.").font(.caption).foregroundStyle(Theme.muted)
                    Divider()
                    Button("Enable Teams camera", systemImage: "video.badge.checkmark") { camera.activate() }
                        .disabled(camera.pending).controlSize(.large)
                    Text(camera.status).font(.caption).foregroundStyle(Theme.muted).textSelection(.enabled)
                    Button("Remove camera extension…") { confirmRemoval = true }.buttonStyle(.link).disabled(camera.pending)
                    Text("Local processing. No uploads or recordings.").font(.caption2).foregroundStyle(Theme.muted)
                }.toggleStyle(.switch).frame(width: 260).padding(20).background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            }
        }.padding(24)
      }.foregroundStyle(Theme.text).background(Theme.background).tint(Theme.accent)
            .frame(minWidth: 1040, minHeight: 680).preferredColorScheme(.dark)
            .confirmationDialog("Remove Nocturne Camera?", isPresented: $confirmRemoval) {
                Button("Remove camera extension", role: .destructive) { model.pipeline.stop(); model.running = false; camera.deactivate() }
            } message: { Text("Teams will no longer see this camera. After removal finishes, quit Nocturne and move the app to the Trash.") }
    }

    private func cue(_ title: String, symbol: String, keys: String, id: Int) -> some View {
        Button { model.trigger(id) } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack { Image(systemName: symbol); Spacer(); Text(keys).font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.muted) }
                Text(title).font(.callout.weight(.medium))
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.bordered).disabled(model.normal).help("Trigger \(title) — \(keys)")
    }
}

@main
struct NocturneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = CameraModel()
    @StateObject private var extensionManager = ExtensionManager()
    var body: some Scene {
        WindowGroup { ContentView(model: model, camera: extensionManager) }
            .windowResizability(.contentMinSize)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
