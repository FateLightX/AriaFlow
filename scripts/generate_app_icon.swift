import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = root.appending(path: "docs/assets/AppIcon.png")
let size = 1024
let canvas = NSRect(x: 0, y: 0, width: size, height: size)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fillGradient(_ path: NSBezierPath, colors: [NSColor], angle: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(colors: colors)?.draw(in: canvas, angle: angle)
    NSGraphicsContext.restoreGraphicsState()
}

func fillGold(_ path: NSBezierPath, angle: CGFloat = 72) {
    fillGradient(
        path,
        colors: [
            color(0xfff3bd),
            color(0xe1bd67),
            color(0x9f7026),
            color(0xf5d987)
        ],
        angle: angle
    )
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.stroke()
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create bitmap")
}

let context = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current = context
context?.imageInterpolation = .high

NSColor.clear.setFill()
canvas.fill()

let outer = rounded(NSRect(x: 38, y: 38, width: 948, height: 948), 230)
let frameShadow = NSShadow()
frameShadow.shadowOffset = NSSize(width: 0, height: -18)
frameShadow.shadowBlurRadius = 34
frameShadow.shadowColor = color(0x000000, 0.42)
frameShadow.set()
fillGold(outer)
NSShadow().set()

stroke(outer, color: color(0xfff0bd, 0.85), width: 5)

let frameInset = rounded(NSRect(x: 66, y: 66, width: 892, height: 892), 208)
stroke(frameInset, color: color(0x704b16, 0.30), width: 6)

let panel = rounded(NSRect(x: 106, y: 106, width: 812, height: 812), 165)
let panelShadow = NSShadow()
panelShadow.shadowOffset = NSSize(width: 0, height: -8)
panelShadow.shadowBlurRadius = 20
panelShadow.shadowColor = color(0x000000, 0.45)
panelShadow.set()
color(0x111418).setFill()
panel.fill()
NSShadow().set()
fillGradient(panel, colors: [color(0x1d2025), color(0x0d0f12), color(0x171a1f)], angle: -42)

stroke(panel, color: color(0xffe6a6, 0.42), width: 3)
stroke(rounded(NSRect(x: 125, y: 125, width: 774, height: 774), 146), color: color(0x000000, 0.34), width: 5)

let topSheen = rounded(NSRect(x: 144, y: 710, width: 736, height: 92), 46)
color(0xffffff, 0.055).setFill()
topSheen.fill()

let grainColor = color(0xffffff, 0.020)
grainColor.setStroke()
for i in 0..<30 {
    let y = CGFloat(155 + i * 24)
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 148, y: y))
    line.line(to: NSPoint(x: 876, y: y + CGFloat((i % 4) - 2)))
    line.lineWidth = 1
    line.stroke()
}

let symbolShadow = NSShadow()
symbolShadow.shadowOffset = NSSize(width: 0, height: -10)
symbolShadow.shadowBlurRadius = 15
symbolShadow.shadowColor = color(0x000000, 0.46)
symbolShadow.set()

let leftLeg = NSBezierPath()
leftLeg.move(to: NSPoint(x: 300, y: 300))
leftLeg.curve(to: NSPoint(x: 321, y: 286), controlPoint1: NSPoint(x: 289, y: 292), controlPoint2: NSPoint(x: 297, y: 280))
leftLeg.line(to: NSPoint(x: 372, y: 316))
leftLeg.line(to: NSPoint(x: 474, y: 592))
leftLeg.curve(to: NSPoint(x: 442, y: 657), controlPoint1: NSPoint(x: 487, y: 629), controlPoint2: NSPoint(x: 470, y: 658))
leftLeg.line(to: NSPoint(x: 410, y: 657))
leftLeg.close()
fillGold(leftLeg, angle: 58)

let rightLeg = NSBezierPath()
rightLeg.move(to: NSPoint(x: 724, y: 300))
rightLeg.curve(to: NSPoint(x: 703, y: 286), controlPoint1: NSPoint(x: 735, y: 292), controlPoint2: NSPoint(x: 727, y: 280))
rightLeg.line(to: NSPoint(x: 652, y: 316))
rightLeg.line(to: NSPoint(x: 550, y: 592))
rightLeg.curve(to: NSPoint(x: 582, y: 657), controlPoint1: NSPoint(x: 537, y: 629), controlPoint2: NSPoint(x: 554, y: 658))
rightLeg.line(to: NSPoint(x: 614, y: 657))
rightLeg.close()
fillGold(rightLeg, angle: 112)

let topStem = rounded(NSRect(x: 477, y: 638, width: 70, height: 168), 35)
fillGold(topStem, angle: 88)

let crossbar = rounded(NSRect(x: 382, y: 390, width: 260, height: 48), 22)
fillGold(crossbar, angle: 72)

NSShadow().set()

stroke(leftLeg, color: color(0xfff0bd, 0.48), width: 3)
stroke(rightLeg, color: color(0xfff0bd, 0.48), width: 3)
stroke(crossbar, color: color(0xfff0bd, 0.38), width: 2)

let hubShadow = NSShadow()
hubShadow.shadowOffset = NSSize(width: 0, height: -8)
hubShadow.shadowBlurRadius = 12
hubShadow.shadowColor = color(0x000000, 0.45)
hubShadow.set()
let hubOuter = NSBezierPath(ovalIn: NSRect(x: 419, y: 574, width: 186, height: 186))
fillGold(hubOuter, angle: 76)
NSShadow().set()

let hubInner = NSBezierPath(ovalIn: NSRect(x: 463, y: 618, width: 98, height: 98))
fillGradient(hubInner, colors: [color(0x0c0e12), color(0x24272d)], angle: -42)
stroke(hubInner, color: color(0x000000, 0.30), width: 3)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 512, y: 548))
arrow.line(to: NSPoint(x: 512, y: 488))
arrow.lineWidth = 22
arrow.lineCapStyle = .round
color(0xe9eaeb, 0.92).setStroke()
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 512, y: 442))
arrowHead.line(to: NSPoint(x: 467, y: 493))
arrowHead.line(to: NSPoint(x: 557, y: 493))
arrowHead.close()
fillGradient(arrowHead, colors: [color(0xffffff), color(0xbfc2c5)], angle: 90)

let statusShadow = NSShadow()
statusShadow.shadowOffset = NSSize(width: 0, height: -5)
statusShadow.shadowBlurRadius = 8
statusShadow.shadowColor = color(0x000000, 0.45)
statusShadow.set()
let statusBar = rounded(NSRect(x: 306, y: 205, width: 412, height: 34), 17)
fillGradient(statusBar, colors: [color(0xffffff), color(0xc9c9c9), color(0xf3f3f3)], angle: 90)
NSShadow().set()
stroke(statusBar, color: color(0xffffff, 0.55), width: 2)

let lowerAccent = rounded(NSRect(x: 354, y: 253, width: 316, height: 8), 4)
color(0xffdf91, 0.16).setFill()
lowerAccent.fill()

NSGraphicsContext.current = nil

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}

try data.write(to: outputURL)
print(outputURL.path)
