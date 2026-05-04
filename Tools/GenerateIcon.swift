#!/usr/bin/env swift
//
// GenerateIcon.swift — renders Devvy's 1024×1024 app icon to PNG.
//
//   swift Tools/GenerateIcon.swift
//
// Coral squircle with a centered white SF Symbol. Pure Core Graphics + AppKit,
// no run-loop dependency — runs cleanly from the command line.

import AppKit
import CoreGraphics
import Foundation

let outputPath = "Devvy/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size: CGFloat = 1024

let symbolName = "film.fill"
let symbolPointSize: CGFloat = 580
let symbolWeight: NSFont.Weight = .semibold

// MARK: - Colors

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

let bgTop = rgb(250, 132, 95)
let bgBot = rgb(230, 60, 95)

// MARK: - CGContext setup

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
let pixels = Int(size)
guard let ctx = CGContext(
    data: nil,
    width: pixels,
    height: pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: bitmapInfo
) else {
    fatalError("Failed to create CGContext")
}
ctx.setShouldAntialias(true)

// MARK: - Background gradient

let bgGradient = CGGradient(
    colorsSpace: cs,
    colors: [bgTop, bgBot] as CFArray,
    locations: [0, 1]
)!
ctx.saveGState()
ctx.addRect(CGRect(x: 0, y: 0, width: size, height: size))
ctx.clip()
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: size, y: size),
    options: []
)
ctx.restoreGState()

// MARK: - Soft top-left highlight

let highlightGradient = CGGradient(
    colorsSpace: cs,
    colors: [rgb(255, 255, 255, 0.28), rgb(255, 255, 255, 0)] as CFArray,
    locations: [0, 1]
)!
ctx.saveGState()
ctx.drawRadialGradient(
    highlightGradient,
    startCenter: CGPoint(x: size * 0.22, y: size * 0.78),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.22, y: size * 0.78),
    endRadius: size * 0.7,
    options: []
)
ctx.restoreGState()

// MARK: - SF Symbol

let baseConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: symbolWeight)
let coloredConfig = NSImage.SymbolConfiguration(paletteColors: [.white])
let config = baseConfig.applying(coloredConfig)

guard let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
    fatalError("Symbol '\(symbolName)' not found")
}
guard let symbol = baseSymbol.withSymbolConfiguration(config) else {
    fatalError("Failed to apply symbol configuration")
}

let symbolSize = symbol.size
let dx = (size - symbolSize.width) / 2
let dy = (size - symbolSize.height) / 2

ctx.saveGState()
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx
symbol.draw(
    in: CGRect(x: dx, y: dy, width: symbolSize.width, height: symbolSize.height),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)
NSGraphicsContext.restoreGraphicsState()
ctx.restoreGState()

// MARK: - Save PNG

guard let cgImage = ctx.makeImage() else {
    fatalError("Failed to make CGImage")
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode PNG")
}
let cwd = FileManager.default.currentDirectoryPath
let url = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: cwd))
try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: url)
print("Wrote \(url.path) (\(png.count) bytes)")
