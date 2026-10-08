import AppKit

/// Picks a vivid accent color from album artwork.
enum ArtworkColors {
    /// Shrinks the image to 24×24, groups the pixels by hue, and returns the most prominent
    /// colorful hue, brightened so it stands out on black. Gray artwork gives a soft white.
    static func accent(from image: NSImage) -> NSColor {
        let fallback = NSColor(white: 0.85, alpha: 1)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return fallback }

        let size = 24
        let bucketCount = 12
        var weights = [Double](repeating: 0, count: bucketCount)
        var sums = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: bucketCount)

        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drew else { return fallback }

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
            NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
                .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
            // Skip grays and near-black pixels; favor colorful, bright ones.
            guard saturation > 0.2, brightness > 0.2 else { continue }
            let bucket = min(Int(hue * CGFloat(bucketCount)), bucketCount - 1)
            let weight = Double(saturation * brightness)
            weights[bucket] += weight
            sums[bucket].r += r * weight
            sums[bucket].g += g * weight
            sums[bucket].b += b * weight
        }

        guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }),
              weights[best] > 1 else { return fallback }
        let total = weights[best]
        let average = NSColor(srgbRed: sums[best].r / total, green: sums[best].g / total,
                              blue: sums[best].b / total, alpha: 1)

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        return NSColor(hue: hue, saturation: min(max(saturation, 0.45), 0.85),
                       brightness: max(brightness, 0.85), alpha: 1)
    }
}
