import CoreImage
import CoreGraphics

@main struct FogTests {
    static func main() {
        let fog = Fog(), context = CIContext()
        let width = 1280, height = 720
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        func pixels(amount: Double, time: Double, animated: Bool = true) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            context.render(fog.image(amount: amount, time: time, animated: animated, bounds: bounds),
                toBitmap: &bytes, rowBytes: width * 4, bounds: bounds, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            return bytes
        }
        func alpha(_ image: [UInt8], rows: Range<Int>) -> Double {
            var total = 0
            for y in rows { for x in 0..<width { total += Int(image[(y * width + x) * 4 + 3]) } }
            return Double(total) / Double(rows.count * width)
        }
        let thick = pixels(amount: 1, time: 0)
        // Bitmap rows run top to bottom, opposite Core Image world-space y.
        let bottom = alpha(thick, rows: 640..<720), middle = alpha(thick, rows: 390..<470), upper = alpha(thick, rows: 0..<230)
        precondition(bottom > middle * 1.7 && bottom > 90, "Fog must be thickest along the bottom")
        precondition(upper == 0, "Fog must disappear above two-thirds height")
        precondition(alpha(pixels(amount: 0.25, time: 0), rows: 640..<720) < bottom * 0.4, "Amount must control opacity")
        precondition(pixels(amount: 0, time: 0).allSatisfy { $0 == 0 }, "Zero fog must be transparent")
        precondition(thick != pixels(amount: 1, time: 5), "Fog must drift over time")
        precondition(pixels(amount: 1, time: 0, animated: false) == pixels(amount: 1, time: 5, animated: false), "Reduce Motion must keep fog still")
        print("PASS: dense bottom, two-thirds cutoff, amount control, zero-fog transparency, animation, reduced motion")
    }
}
