#!/bin/bash
# Generate a clean placeholder app icon for "Yahoo KeyKey 2" and emit App/AppIcon.icns.
#
# Renders a simple, tasteful icon — the Cangjie glyph 倉 in white on a rounded-rect blue
# gradient — at every standard iconset size via CoreGraphics (a tiny inline Swift script),
# then assembles them with `iconutil -c icns`. Self-contained and reproducible: re-run to
# regenerate App/AppIcon.icns. Teddy can swap in a designed icon later.
#
# Requires: swift (Xcode toolchain), iconutil.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
trap 'rm -rf "$WORK"' EXIT

# Render a single square PNG of the icon at the requested pixel size.
render() {
  local size="$1" out="$2"
  swift - "$size" "$out" <<'SWIFT'
import AppKit

let px = Int(CommandLine.arguments[1])!
let outPath = CommandLine.arguments[2]
let size = CGFloat(px)

guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("could not create CGContext")
}

// Rounded-rect background with a vertical blue gradient (macOS app-icon proportions:
// a ~10% inset and ~22% corner radius read well at small sizes too).
let inset = size * 0.10
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = rect.width * 0.225
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path)
ctx.clip()

let colors = [CGColor(red: 0.27, green: 0.52, blue: 0.96, alpha: 1.0),
              CGColor(red: 0.13, green: 0.32, blue: 0.78, alpha: 1.0)] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                          locations: [0.0, 1.0])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: 0, y: 0), options: [])
ctx.resetClip()

// Draw the glyph 倉 (Cangjie) centred in white.
let nsImage = NSImage(size: NSSize(width: px, height: px))
nsImage.lockFocusFlipped(false)
NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
let glyph = "倉" as NSString
let fontSize = size * 0.56
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "PingFang TC", size: fontSize)
        ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold),
    .foregroundColor: NSColor.white,
]
let textSize = glyph.size(withAttributes: attrs)
let origin = NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2)
glyph.draw(at: origin, withAttributes: attrs)
nsImage.unlockFocus()

if let tiff = nsImage.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let glyphCG = rep.cgImage {
    ctx.draw(glyphCG, in: CGRect(x: 0, y: 0, width: size, height: size))
}

guard let cgImage = ctx.makeImage() else { fatalError("could not render image") }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
try! png.write(to: URL(fileURLWithPath: outPath))
SWIFT
}

echo "==> Rendering iconset PNGs"
# Standard macOS iconset: 16/32/128/256/512 at @1x and @2x.
for base in 16 32 128 256 512; do
  render "$base"            "$ICONSET/icon_${base}x${base}.png"
  render "$((base * 2))"    "$ICONSET/icon_${base}x${base}@2x.png"
done

echo "==> Assembling AppIcon.icns"
iconutil -c icns "$ICONSET" -o "$ROOT/App/AppIcon.icns"
echo "==> Done: $ROOT/App/AppIcon.icns"
