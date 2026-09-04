import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Kullanım: extract-icon-background.swift input.png output.png\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = NSImage(contentsOf: inputURL) else {
    fputs("Girdi görseli okunamadı\n", stderr)
    exit(1)
}

var proposedRect = NSRect.zero
guard let source = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
      let providerData = source.dataProvider?.data else {
    fputs("Girdi görseli bitmap'e dönüştürülemedi\n", stderr)
    exit(1)
}

let width = source.width
let height = source.height
let bytesPerRow = source.bytesPerRow
let bytesPerPixel = 4
var pixels = [UInt8](providerData as Data)

func isCheckerCandidate(_ index: Int) -> Bool {
    let red = Int(pixels[index])
    let green = Int(pixels[index + 1])
    let blue = Int(pixels[index + 2])
    let brightness = (red + green + blue) / 3
    let chroma = max(red, max(green, blue)) - min(red, min(green, blue))
    return brightness >= 205 && chroma <= 14
}

var background = Array(repeating: false, count: width * height)
var queue: [(Int, Int)] = []
for x in 0..<width {
    queue.append((x, 0))
    queue.append((x, height - 1))
}
for y in 1..<(height - 1) {
    queue.append((0, y))
    queue.append((width - 1, y))
}

var cursor = 0
while cursor < queue.count {
    let (x, y) = queue[cursor]
    cursor += 1
    guard x >= 0, x < width, y >= 0, y < height else { continue }
    let pixelIndex = y * width + x
    guard !background[pixelIndex] else { continue }
    let byteIndex = y * bytesPerRow + x * bytesPerPixel
    guard isCheckerCandidate(byteIndex) else { continue }
    background[pixelIndex] = true
    for dy in -1...1 {
        for dx in -1...1 where dx != 0 || dy != 0 {
            queue.append((x + dx, y + dy))
        }
    }
}

for y in 0..<height {
    for x in 0..<width where background[y * width + x] {
        let index = y * bytesPerRow + x * bytesPerPixel
        pixels[index] = 0
        pixels[index + 1] = 0
        pixels[index + 2] = 0
        pixels[index + 3] = 0
    }
}

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let outputImage = context.makeImage() else {
    fputs("Şeffaf bitmap oluşturulamadı\n", stderr)
    exit(1)
}

let outputRep = NSBitmapImageRep(cgImage: outputImage)
guard let pngData = outputRep.representation(using: .png, properties: [:]) else {
    fputs("PNG çıktısı oluşturulamadı\n", stderr)
    exit(1)
}
try pngData.write(to: outputURL, options: .atomic)
