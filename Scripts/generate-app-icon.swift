#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let size = 1_024
private let defaultOutput = "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [red, green, blue, alpha])!
}

private func spadePath() -> CGPath {
    let path = CGMutablePath()

    // A broad, deliberately simple spade silhouette holds up at Spotlight and
    // notification sizes while retaining an elegant narrow stem.
    path.move(to: CGPoint(x: 512, y: 826))
    path.addCurve(
        to: CGPoint(x: 274, y: 492),
        control1: CGPoint(x: 477, y: 761),
        control2: CGPoint(x: 274, y: 625)
    )
    path.addCurve(
        to: CGPoint(x: 422, y: 326),
        control1: CGPoint(x: 274, y: 391),
        control2: CGPoint(x: 343, y: 326)
    )
    path.addCurve(
        to: CGPoint(x: 478, y: 353),
        control1: CGPoint(x: 446, y: 326),
        control2: CGPoint(x: 465, y: 336)
    )
    path.addCurve(
        to: CGPoint(x: 454, y: 241),
        control1: CGPoint(x: 478, y: 310),
        control2: CGPoint(x: 472, y: 268)
    )
    path.addCurve(
        to: CGPoint(x: 415, y: 210),
        control1: CGPoint(x: 441, y: 222),
        control2: CGPoint(x: 428, y: 215)
    )
    path.addLine(to: CGPoint(x: 609, y: 210))
    path.addCurve(
        to: CGPoint(x: 570, y: 241),
        control1: CGPoint(x: 596, y: 215),
        control2: CGPoint(x: 583, y: 222)
    )
    path.addCurve(
        to: CGPoint(x: 546, y: 353),
        control1: CGPoint(x: 552, y: 268),
        control2: CGPoint(x: 546, y: 310)
    )
    path.addCurve(
        to: CGPoint(x: 602, y: 326),
        control1: CGPoint(x: 559, y: 336),
        control2: CGPoint(x: 578, y: 326)
    )
    path.addCurve(
        to: CGPoint(x: 750, y: 492),
        control1: CGPoint(x: 681, y: 326),
        control2: CGPoint(x: 750, y: 391)
    )
    path.addCurve(
        to: CGPoint(x: 512, y: 826),
        control1: CGPoint(x: 750, y: 625),
        control2: CGPoint(x: 547, y: 761)
    )
    path.closeSubpath()

    return path
}

private func drawRiverLines(in context: CGContext) {
    context.saveGState()
    context.setLineCap(.round)
    context.setStrokeColor(color(0.84, 0.69, 0.40, 0.19))

    let upper = CGMutablePath()
    upper.move(to: CGPoint(x: 142, y: 466))
    upper.addCurve(
        to: CGPoint(x: 882, y: 495),
        control1: CGPoint(x: 323, y: 535),
        control2: CGPoint(x: 633, y: 400)
    )
    context.setLineWidth(9)
    context.addPath(upper)
    context.strokePath()

    let lower = CGMutablePath()
    lower.move(to: CGPoint(x: 164, y: 426))
    lower.addCurve(
        to: CGPoint(x: 860, y: 450),
        control1: CGPoint(x: 348, y: 484),
        control2: CGPoint(x: 628, y: 383)
    )
    context.setLineWidth(3)
    context.addPath(lower)
    context.strokePath()
    context.restoreGState()
}

private func renderIcon() throws -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            color(0.075, 0.190, 0.145),
            color(0.035, 0.090, 0.068),
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 512, y: 1_024),
        end: CGPoint(x: 512, y: 0),
        options: []
    )

    let softHighlight = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0.20, 0.42, 0.31, 0.23), color(0.02, 0.05, 0.04, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        softHighlight,
        startCenter: CGPoint(x: 512, y: 610),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 610),
        endRadius: 540,
        options: []
    )

    let gold = color(0.84, 0.69, 0.40)
    let outerFrame = CGPath(
        roundedRect: CGRect(x: 62, y: 62, width: 900, height: 900),
        cornerWidth: 126,
        cornerHeight: 126,
        transform: nil
    )
    context.setStrokeColor(gold.copy(alpha: 0.88)!)
    context.setLineWidth(9)
    context.addPath(outerFrame)
    context.strokePath()

    let innerFrame = CGPath(
        roundedRect: CGRect(x: 84, y: 84, width: 856, height: 856),
        cornerWidth: 108,
        cornerHeight: 108,
        transform: nil
    )
    context.setStrokeColor(gold.copy(alpha: 0.24)!)
    context.setLineWidth(2)
    context.addPath(innerFrame)
    context.strokePath()

    drawRiverLines(in: context)

    let spade = spadePath()
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: color(0, 0, 0, 0.48))
    context.setFillColor(color(0.956, 0.939, 0.878))
    context.setStrokeColor(gold)
    context.setLineWidth(11)
    context.setLineJoin(.round)
    context.addPath(spade)
    context.drawPath(using: .fillStroke)
    context.restoreGState()

    guard let image = context.makeImage() else {
        throw CocoaError(.fileWriteUnknown)
    }
    return image
}

private func writePNG(_ image: CGImage, to outputURL: URL) throws {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGCompressionFilter: 5,
        kCGImagePropertyHasAlpha: false,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let outputPath = CommandLine.arguments.dropFirst().first ?? defaultOutput
let outputURL = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

do {
    try writePNG(renderIcon(), to: outputURL)
    print("Generated Riverline app icon at \(outputURL.path)")
} catch {
    FileHandle.standardError.write(Data("Failed to generate app icon: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
