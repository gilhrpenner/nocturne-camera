import SwiftUI
import AppKit

@MainActor
final class CameraModel: ObservableObject {
    @Published var preview: CGImage?
    @Published var trackingStatus = "Camera off"
    @Published var performanceStatus = ""
    @Published private(set) var character: SceneCharacter = .vampire
    @Published var status = "Preparing the castle…"
    @Published var error: String?
    @Published var running = false
    @Published var starting = false
    @Published var vampire = true { didSet { state.update { $0.vampire = vampire } } }
    @Published var costume = true { didSet { state.update { $0.costume = costume } } }
    @Published var blood = true { didSet { state.update { $0.blood = blood } } }
    @Published var hairStyle: HairStyle = .white { didSet { state.update { $0.hairStyle = hairStyle } } }
    @Published var hairAmount = 1.0 { didSet { state.update { $0.hairAmount = hairAmount } } }
    @Published var castle = true { didSet { state.update { $0.castle = castle; if !castle { $0.cancelPerformance() } } } }
    @Published var cinematic = true { didSet { state.update { $0.cinematic = cinematic } } }
    @Published var sceneDepth = 0.65 { didSet { state.update { $0.sceneDepth = sceneDepth } } }
    @Published var rainAmount = 0.18 { didSet { state.update { $0.rainAmount = rainAmount } } }
    @Published var relighting = 0.45 { didSet { state.update { $0.relighting = relighting } } }
    @Published private(set) var characterFits = CharacterFits.load() {
        didSet {
            state.update { $0.characterFits = characterFits }
            characterFits.save()
        }
    }
    var outfitAdjustment: OutfitAdjustments { characterFits[character] }
    var costumeWidth: Double {
        get { outfitAdjustment.width }
        set { updateFit(\.width, to: newValue) }
    }
    var costumeHeight: Double {
        get { outfitAdjustment.height }
        set { updateFit(\.height, to: newValue) }
    }
    var costumeLift: Double {
        get { outfitAdjustment.lift }
        set { updateFit(\.lift, to: newValue) }
    }
    @Published var preserveHands = true { didSet { state.update { $0.preserveHands = preserveHands } } }
    @Published var animateScene = true { didSet { state.update { $0.animateScene = animateScene } } }
    @Published var hauntedWindows = true { didSet { state.update { $0.hauntedWindows = hauntedWindows } } }
    @Published var bats = true { didSet { state.update { $0.bats = bats } } }
    @Published var lightning = true { didSet { state.update { $0.autoLightning = lightning } } }
    @Published var fogAmount = 0.55 { didSet { state.update { $0.fogAmount = fogAmount } } }
    @Published var normal = false { didSet { state.update { $0.normal = normal; if normal { $0.cancelPerformance() } } } }
    @Published var intensity = 0.85 { didSet { state.update { $0.intensity = intensity } } }
    @Published var distance = 0.0 { didSet { state.update { $0.distance = distance } } }
    @Published var shortcutStatus = "Shortcuts work while Teams has focus."
    let state = SceneState()
    let pipeline: CameraPipeline
    let hotkeys = Hotkeys()

    init() {
        pipeline = CameraPipeline(state: state)
        state.update { $0.intensity = 0.85; $0.characterFits = characterFits }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            bats = false; lightning = false; animateScene = false
            state.update { $0.bats = false; $0.autoLightning = false; $0.animateBlood = false; $0.animateFog = false; $0.animateScene = false }
        }
        pipeline.onFrame = { [weak self] image, status, tracking, performance in
            guard let self else { return }
            self.preview = image; self.status = status; self.trackingStatus = tracking; self.performanceStatus = performance
            self.character = self.state.read().character(at: ProcessInfo.processInfo.systemUptime)
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
    func selectCharacter(_ selected: SceneCharacter) {
        let now = ProcessInfo.processInfo.systemUptime
        guard state.read().performance(at: now) == nil else { return }
        state.update { $0.selectCharacter(selected, at: now) }
        character = selected
    }
    private func updateFit(_ key: WritableKeyPath<OutfitAdjustments, Double>, to value: Double) {
        var fits = characterFits
        var adjustment = fits[character]
        adjustment[keyPath: key] = value
        fits[character] = adjustment
        characterFits = fits
    }
    func resetFit() {
        var fits = characterFits
        fits.reset(character)
        characterFits = fits
    }
    func trigger(_ id: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        switch id {
        case 0: if !normal { state.update { $0.lightningAt = now } }
        case 1: if !normal { state.update { $0.swarmAt = now } }
        case 2: if character == .vampire { vampire.toggle() }
        case 3: normal.toggle()
        case 4, 5:
            guard running else { return }
            state.update { $0.beginPerformance(id == 4 ? .vanish : .entrance, at: now) }
            performanceStatus = state.read().performanceLabel(at: now)
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
                        cue("Vanish & return", symbol: "sparkles", keys: "⌃⌥G", id: 4)
                        cue("Grand entrance", symbol: "theatermasks.fill", keys: "⌃⌥E", id: 5)
                    }
                    Text(cueHint).font(.caption).foregroundStyle(model.performanceStatus.isEmpty ? Theme.muted : Theme.accent)
                        .frame(minHeight: 30, alignment: .topLeading).accessibilityLabel("Cue status: \(cueHint)")
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
            Text(model.character == .vampire ? "The vampire" : "The dark knight").font(.custom("Baskerville", size: 23))
            Picker("Character", selection: Binding(get: { model.character }, set: { model.selectCharacter($0) })) {
                ForEach(SceneCharacter.allCases) { character in Text(character.rawValue).tag(character) }
            }.pickerStyle(.segmented).disabled(model.normal || !model.performanceStatus.isEmpty)
                .help("Choose your character directly. Vanish & return alternates between the two.")
            if model.character == .vampire {
                Toggle("Theatrical makeup", isOn: $model.vampire).disabled(model.normal).help("Control–Option–V")
                Toggle("Blood trails", isOn: $model.blood).disabled(!model.vampire || model.normal)
                amount("Intensity", value: $model.intensity).disabled(!model.vampire || model.normal)
                Picker("Hair", selection: $model.hairStyle) {
                    ForEach(HairStyle.allCases) { style in Text(style.rawValue).tag(style) }
                }.disabled(model.normal)
                amount("Hair strength", value: $model.hairAmount).disabled(model.hairStyle == .natural || model.normal)
            } else {
                Text("A fitted cowl, armored suit and cape. Your eyes and lower face stay live.")
                    .font(.callout).foregroundStyle(Theme.muted)
                Text("Vanish again to return to your vampire look.").font(.caption).foregroundStyle(Theme.muted)
                if !model.castle {
                    Text("Turn on Castle & person cutout to replace your full silhouette.").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Divider()
            if model.character == .vampire {
                Toggle("Vampire attire", isOn: $model.costume).disabled(model.normal)
                    .help("Replace your real torso with the costume, keeping your head, neck and detected hands.")
            }
            Text(model.running ? model.trackingStatus : "Shoulder and torso tracking").font(.caption).foregroundStyle(Theme.muted)
                .accessibilityLabel("Outfit tracking: \(model.trackingStatus)")
            DisclosureGroup("\(model.character.rawValue) fit", isExpanded: $fitting) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Width"); Spacer()
                        Text(model.costumeWidth, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                    }
                    Slider(value: $model.costumeWidth, in: OutfitAdjustments.sizeRange).accessibilityLabel("Outfit width")
                    HStack {
                        Text("Height"); Spacer()
                        Text(model.costumeHeight, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                    }
                    Slider(value: $model.costumeHeight, in: OutfitAdjustments.sizeRange).accessibilityLabel("Outfit height")
                        .help("Stretch or shorten this outfit while keeping its neckline in place.")
                    HStack { Text("Collar height"); Spacer(); Text(model.costumeLift == 0 ? "Auto" : model.costumeLift > 0 ? "Higher" : "Lower").foregroundStyle(Theme.muted) }
                    Slider(value: $model.costumeLift, in: OutfitAdjustments.liftRange).accessibilityLabel("Collar height")
                    Toggle("Hands in front", isOn: $model.preserveHands)
                    HStack { Spacer(); Button("Reset \(model.character.rawValue) fit") { model.resetFit() }.buttonStyle(.link)
                        .disabled(model.outfitAdjustment == OutfitAdjustments()) }
                    Text("Saved separately for each character.").font(.caption).foregroundStyle(Theme.muted)
                }.padding(.top, 10)
            }.disabled((model.character == .vampire && !model.costume) || model.normal || !model.performanceStatus.isEmpty)
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
                    .help("Freeze the layered scenery, rain and ambient bats, and stop window appearances. Fog and lightning have separate controls.")
                Toggle("Haunted windows", isOn: $model.hauntedWindows).disabled(!model.animateScene)
                    .help("A distant figure occasionally crosses a lit castle window.")
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
        }.buttonStyle(.bordered).disabled(model.normal || (id >= 4 && (!model.running || !model.castle || !model.performanceStatus.isEmpty)))
            .help(id == 4 ? "Transform into bats and return as \(model.character.other.rawValue) in six seconds. \(keys). Requires camera and castle cutout." :
                id == 5 ? "Gather a flock into your silhouette with a coordinated lightning reveal. \(keys). Requires camera and castle cutout." :
                "Trigger \(title) — \(keys)")
    }

    private var cueHint: String {
        if model.normal { return "Normal camera bypasses every effect." }
        if !model.running { return "Start camera for Vanish & return and Grand entrance." }
        if !model.castle { return "Turn on Castle & person cutout for Vanish & return and Grand entrance." }
        return model.performanceStatus.isEmpty ? "Next vanish: return as \(model.character.other.rawValue). \(model.shortcutStatus)" : model.performanceStatus
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
