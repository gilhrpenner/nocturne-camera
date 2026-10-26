import SwiftUI
import AppKit

@MainActor
final class CameraModel: ObservableObject {
    @Published var preview: CGImage?
    @Published var trackingStatus = "Camera off"
    @Published var status = "Preparing the castle…"
    @Published var error: String?
    @Published var running = false
    @Published var starting = false
    @Published var vampire = true { didSet { state.update { $0.vampire = vampire } } }
    @Published var costume = true { didSet { state.update { $0.costume = costume } } }
    @Published var blood = true { didSet { state.update { $0.blood = blood } } }
    @Published var hairStyle: HairStyle = .white { didSet { state.update { $0.hairStyle = hairStyle } } }
    @Published var hairAmount = 1.0 { didSet { state.update { $0.hairAmount = hairAmount } } }
    @Published var castle = true { didSet { state.update { $0.castle = castle } } }
    @Published var cinematic = true { didSet { state.update { $0.cinematic = cinematic } } }
    @Published var sceneDepth = 0.65 { didSet { state.update { $0.sceneDepth = sceneDepth } } }
    @Published var rainAmount = 0.18 { didSet { state.update { $0.rainAmount = rainAmount } } }
    @Published var relighting = 0.45 { didSet { state.update { $0.relighting = relighting } } }
    @Published var costumeWidth = 1.0 { didSet { state.update { $0.costumeWidth = costumeWidth } } }
    @Published var costumeLift = 0.0 { didSet { state.update { $0.costumeLift = costumeLift } } }
    @Published var preserveHands = true { didSet { state.update { $0.preserveHands = preserveHands } } }
    @Published var animateScene = true { didSet { state.update { $0.animateScene = animateScene } } }
    @Published var bats = true { didSet { state.update { $0.bats = bats } } }
    @Published var lightning = true { didSet { state.update { $0.autoLightning = lightning } } }
    @Published var fogAmount = 0.55 { didSet { state.update { $0.fogAmount = fogAmount } } }
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
            bats = false; lightning = false; animateScene = false
            state.update { $0.bats = false; $0.autoLightning = false; $0.animateBlood = false; $0.animateFog = false; $0.animateScene = false }
        }
        pipeline.onFrame = { [weak self] image, status, tracking in
            self?.preview = image; self?.status = status; self?.trackingStatus = tracking
        }
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
    @State private var panel = "Look"
    @State private var fitting = true

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
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Controls", selection: $panel) {
                        Text("Look").tag("Look")
                        Text("Scene").tag("Scene")
                        Text("Setup").tag("Setup")
                    }.pickerStyle(.segmented)
                    if panel == "Look" { lookControls }
                    else if panel == "Scene" { sceneControls }
                    else { setupControls }
                }.toggleStyle(.switch).frame(width: 260).padding(20)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            }
        }.padding(24)
      }.foregroundStyle(Theme.text).background(Theme.background).tint(Theme.accent)
            .frame(minWidth: 1040, minHeight: 680).preferredColorScheme(.dark)
            .confirmationDialog("Remove Nocturne Camera?", isPresented: $confirmRemoval) {
                Button("Remove camera extension", role: .destructive) { model.pipeline.stop(); model.running = false; camera.deactivate() }
            } message: { Text("Teams will no longer see this camera. After removal finishes, quit Nocturne and move the app to the Trash.") }
    }

    private var lookControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The vampire").font(.custom("Baskerville", size: 23))
            Toggle("Theatrical makeup", isOn: $model.vampire).help("Control–Option–V")
            Toggle("Blood trails", isOn: $model.blood).disabled(!model.vampire || model.normal)
            amount("Intensity", value: $model.intensity).disabled(!model.vampire || model.normal)
            Picker("Hair", selection: $model.hairStyle) {
                ForEach(HairStyle.allCases) { style in Text(style.rawValue).tag(style) }
            }.disabled(model.normal)
            amount("Hair strength", value: $model.hairAmount).disabled(model.hairStyle == .natural || model.normal)
            Divider()
            Toggle("Vampire attire", isOn: $model.costume).disabled(model.normal)
                .help("Replace your real torso with the costume, keeping your head, neck and detected hands.")
            Text(model.running ? model.trackingStatus : "Shoulder and torso tracking").font(.caption).foregroundStyle(Theme.muted)
                .accessibilityLabel("Outfit tracking: \(model.trackingStatus)")
            DisclosureGroup("Adjust the fit", isExpanded: $fitting) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Width"); Spacer()
                        Text(model.costumeWidth, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                    }
                    Slider(value: $model.costumeWidth, in: 0.8...1.2).accessibilityLabel("Outfit width")
                    HStack { Text("Collar height"); Spacer(); Text(model.costumeLift == 0 ? "Auto" : model.costumeLift > 0 ? "Higher" : "Lower").foregroundStyle(Theme.muted) }
                    Slider(value: $model.costumeLift, in: -0.3...0.3).accessibilityLabel("Collar height")
                    Toggle("Hands in front", isOn: $model.preserveHands)
                    HStack { Spacer(); Button("Reset fit") { model.costumeWidth = 1; model.costumeLift = 0 }.buttonStyle(.link)
                        .disabled(model.costumeWidth == 1 && model.costumeLift == 0) }
                }.padding(.top, 10)
            }.disabled(!model.costume || model.normal)
            Text("Keep both shoulders visible. Lean or turn gently; the outfit follows your torso.").font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var sceneControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The grounds").font(.custom("Baskerville", size: 23))
            Toggle("Castle & person cutout", isOn: $model.castle)
            Toggle("Living scene", isOn: $model.cinematic)
                .help("Layered mountains, castle and terrace with perspective, drifting mist and matched light. Turn off for the classic backdrop.")
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Scene motion", isOn: $model.animateScene)
                    .help("Freeze the layered scenery, rain and ambient bats. Fog and lightning have separate controls.")
                amount("Depth", value: $model.sceneDepth).disabled(!model.animateScene)
                amount("Moonlight", value: $model.relighting)
                amount("Rain", value: $model.rainAmount)
            }.disabled(!model.cinematic)
            Divider()
            Toggle("Flying bats", isOn: $model.bats)
            Toggle("Restless lightning storm", isOn: $model.lightning)
            amount("Fog amount", value: $model.fogAmount)
                .help("Rising fog fades out two-thirds up. Set to zero to turn it off.")
            Text("Even light on your face helps the cutout. A plain wall is ideal.").font(.caption).foregroundStyle(Theme.muted)
        }.disabled(model.normal)
    }

    private var setupControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Into the call").font(.custom("Baskerville", size: 23))
            Button("Enable Teams camera", systemImage: "video.badge.checkmark") { camera.activate() }
                .disabled(camera.pending).controlSize(.large)
            Text(camera.status).font(.caption).foregroundStyle(Theme.muted).textSelection(.enabled)
            Text("In Teams, select Nocturne Camera and turn off Teams’ background effects.").font(.callout).foregroundStyle(Theme.muted)
            Divider()
            Text("Local processing. No uploads or recordings.").font(.caption).foregroundStyle(Theme.muted)
            Button("Remove camera extension…") { confirmRemoval = true }.buttonStyle(.link).disabled(camera.pending)
        }
    }

    private func amount(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text(value.wrappedValue, format: .percent.precision(.fractionLength(0))).monospacedDigit() }
            Slider(value: value, in: 0...1).accessibilityLabel(title)
        }
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
