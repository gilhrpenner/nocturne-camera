import CoreGraphics
import CoreImage

@main struct CharacterTests {
    static func main() throws {
        var options = SceneOptions()
        options.hairStyle = .silverTemples
        options.hairAmount = 0.73
        options.intensity = 0.62
        options.blood = false
        options.costume = false
        for cycle in 0..<6 {
            let time = 100 + Double(cycle) * 10
            let from: SceneCharacter = cycle % 2 == 0 ? .vampire : .batman
            precondition(options.character(at: time) == from)
            precondition(options.beginPerformance(.vanish, at: time))
            precondition(!options.beginPerformance(.vanish, at: time + 0.2), "A duplicate cue cannot switch twice")
            precondition(
                options.character(at: time + 2.99) == from, "Outgoing fragments must retain the outgoing character")
            precondition(options.isVanished(at: time + 3))
            precondition(
                options.character(at: time + 3) == from.other, "Incoming fragment capture must use the next character")
            precondition(
                options.character(at: time + 6.1) == from.other, "The returned character must persist after the cue")
            precondition(options.performanceLabel(at: time + 4).contains(from.other.rawValue))
            let render = options.renderingOptions(at: time + 6.1)
            if from.other == .batman {
                precondition(!render.vampire && !render.blood && render.hairStyle == .natural && render.costume)
            } else {
                precondition(render.vampire && !render.blood && render.hairStyle == .silverTemples && !render.costume)
                precondition(
                    render.hairAmount == 0.73 && render.intensity == 0.62, "Vampire preferences must survive the swap")
            }
        }
        options.selectCharacter(.vampire, at: 200)
        precondition(options.beginPerformance(.vanish, at: 201))
        options.cancelPerformance(at: 202)
        precondition(
            options.character(at: 210) == .vampire, "Cancel before the hidden switch keeps the outgoing character")
        precondition(options.beginPerformance(.vanish, at: 211))
        options.cancelPerformance(at: 214.1)
        precondition(
            options.character(at: 220) == .batman, "Cancel after the hidden switch keeps the incoming character")
        precondition(options.beginPerformance(.entrance, at: 221))
        precondition(options.character(at: 225) == .batman, "Grand entrance must not alternate characters")
        options.selectCharacter(.vampire, at: 226)
        options.normal = true
        precondition(!options.beginPerformance(.vanish, at: 227) && options.character(at: 230) == .vampire)

        let pose = CowlPose(
            leftEye: CGPoint(x: 121, y: 290), rightEye: CGPoint(x: 237, y: 310), chin: CGPoint(x: 202, y: 167))
        for (source, target) in [
            (HeroArtwork.leftEye, pose.leftEye), (HeroArtwork.rightEye, pose.rightEye), (HeroArtwork.chin, pose.chin),
        ] {
            precondition(
                distance(source.applying(pose.transform), target) < 0.001,
                "Cowl holes and jaw must register to the live landmarks, including tilt")
        }
        let bounds = HeroArtwork.headBounds
        let context = CIContext()
        func rgba(_ image: CIImage, _ x: CGFloat, _ y: CGFloat) -> [UInt8] {
            var p = [UInt8](repeating: 0, count: 4)
            context.render(
                image, toBitmap: &p, rowBytes: 4, bounds: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1),
                format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            return p
        }
        let cowl = HeroArtwork.cowl()
        let holes = HeroArtwork.faceMask()
        for p in [HeroArtwork.leftEye, HeroArtwork.rightEye, CGPoint(x: 384, y: 290)] {
            precondition(
                rgba(cowl, p.x, p.y)[3] < 5 && rgba(holes, p.x, p.y)[0] > 245,
                "Eyes and mouth must stay transparent in the cowl")
        }
        precondition(rgba(cowl, 384, 690)[3] > 245 && rgba(cowl, 30, 900)[3] == 0)
        let hero = HeroCostume()
        let identity = CowlPose(leftEye: HeroArtwork.leftEye, rightEye: HeroArtwork.rightEye, chin: HeroArtwork.chin)
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: bounds)
        let empty = CIImage(color: .clear).cropped(to: bounds)
        let white = CIImage(color: .white).cropped(to: bounds)
        let actor = hero.dressed(
            subject: red, personMask: white, garment: empty, pose: identity, placement: .identity, bounds: bounds)
        precondition(
            rgba(actor, 252, 512)[0] > 245 && rgba(actor, 384, 290)[0] > 245,
            "The real eyes and lower face must remain live")
        precondition(
            rgba(actor, 30, 900)[3] == 0 && rgba(actor, 30, 100)[3] == 0,
            "Hair, room and real torso must not leak outside the cowl")
        let absent = hero.dressed(
            subject: red, personMask: CIImage(color: .black).cropped(to: bounds), garment: empty, pose: identity,
            placement: .identity, bounds: bounds)
        precondition(rgba(absent, 252, 512)[3] == 0, "A failed person mask cannot expose the original camera")
        _ = hero.stabilized(identity, at: 100)
        let shifted = CowlPose(
            leftEye: CGPoint(x: 262, y: 512), rightEye: CGPoint(x: 526, y: 512), chin: CGPoint(x: 394, y: 195.2))
        let followed = hero.stabilized(shifted, at: 100.04)
        precondition(
            followed.leftEye.x > 258 && followed.leftEye.x < 262,
            "The cowl must smooth noise without sticking to the old head position")
        hero.reset()
        precondition(hero.stabilized(shifted, at: 101).leftEye == shifted.leftEye)
        print(
            "PASS: six alternating transformations, hidden appearance switch, persistent return, preserved vampire preferences, cancel/entrance semantics, cowl landmark registration, real face openings and camera privacy"
        )
    }
}
