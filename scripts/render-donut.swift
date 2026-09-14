import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let columns = 80
let rows = 22
let width = 1200
let height = 420
let glyphs = Array(".,-~:;=!*#$@")
let fontSize = 14.2
let characterWidth = 8.52

func donutFrame(angleA: Double, angleB: Double) -> [String] {
    var depth = Array(repeating: 0.0, count: columns * rows)
    var screen = Array(repeating: Character(" "), count: columns * rows)
    let sinA = sin(angleA)
    let cosA = cos(angleA)
    let cosB = cos(angleB)
    let sinB = sin(angleB)
    var j = 0.0

    while j < 6.28 {
        let cosJ = cos(j)
        let sinJ = sin(j)
        let h = cosJ + 2.0
        var i = 0.0

        while i < 6.28 {
            let sinI = sin(i)
            let cosI = cos(i)
            let inverseDepth = 1.0 / (sinI * h * sinA + sinJ * cosA + 5.0)
            let t = sinI * h * cosA - sinJ * sinA
            let x = Int(Double(columns / 2) + 30.0 * inverseDepth * (cosI * h * cosB - t * sinB))
            let y = Int(Double(rows / 2) + 15.0 * inverseDepth * (cosI * h * sinB + t * cosB))
            let offset = x + columns * y
            let luminance = Int(8.0 * ((sinJ * sinA - sinI * cosJ * cosA) * cosB - cosJ * sinI * sinA - sinJ * cosA - cosI * cosJ * sinB))

            if x >= 0 && x < columns && y >= 0 && y < rows && inverseDepth > depth[offset] {
                depth[offset] = inverseDepth
                screen[offset] = glyphs[max(0, min(glyphs.count - 1, luminance))]
            }

            i += 0.02
        }

        j += 0.07
    }

    return (0..<rows).map { row in
        var line = String(screen[(row * columns)..<((row + 1) * columns)])
        while line.last == " " {
            line.removeLast()
        }
        return line
    }
}

func writePNG(lines: [String], to url: URL) {
    var pixels = Array(repeating: UInt8(0), count: width * height * 4)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create bitmap context")
    }

    context.setFillColor(CGColor(red: 0.05, green: 0.055, blue: 0.063, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
    let color = CGColor(red: 1, green: 0.33, blue: 0.02, alpha: 1)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
    ]

    for (row, line) in lines.enumerated() {
        let leadingSpaces = line.prefix { $0 == " " }.count
        let content = String(line.dropFirst(leadingSpaces))
        guard !content.isEmpty else { continue }
        let attributed = NSAttributedString(string: content, attributes: attributes)
        let textLine = CTLineCreateWithAttributedString(attributed)
        let x = 138.0 + CGFloat(leadingSpaces) * characterWidth
        let top = 80.0 + CGFloat(row) * fontSize
        context.textPosition = CGPoint(x: x, y: CGFloat(height) - top - fontSize)
        CTLineDraw(textLine, context)
    }

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write PNG")
    }
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: render-donut <output-directory>")
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try! FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for frame in 0..<60 {
    let lines = donutFrame(angleA: Double(frame) * 0.04, angleB: Double(frame) * 0.02)
    let filename = String(format: "frame-%03d.png", frame)
    writePNG(lines: lines, to: outputDirectory.appendingPathComponent(filename))
}
