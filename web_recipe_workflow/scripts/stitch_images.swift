import Foundation
import AppKit
import CoreGraphics
import Vision

// Usage: swift stitch_images.swift <output_dir> <img1> <img2> ...
guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: swift stitch_images.swift <output_dir> <img1> <img2> ...\n", stderr)
    exit(1)
}

let outDir = CommandLine.arguments[1]
let imgPaths = Array(CommandLine.arguments.dropFirst(2))
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let totalImgs = imgPaths.count
let cols = totalImgs <= 4 ? 2 : 3
let rows = Int(ceil(Double(totalImgs) / Double(cols)))

let thumbW: CGFloat = 360
let thumbH: CGFloat = 480
let canvasW = Int(thumbW) * cols
let canvasH = Int(thumbH) * rows

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: canvasW,
    height: canvasH,
    bitsPerComponent: 8,
    bytesPerRow: canvasW * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create CGContext\n", stderr)
    exit(1)
}

ctx.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1.0).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))

var logLines: [String] = []
logLines.append("Type: Multi-Image Photo Note (图文菜谱笔记)")
logLines.append("Total Images: \(totalImgs)")
logLines.append("--- OCR LOG ---")

for (idx, path) in imgPaths.enumerated() {
    guard let nsImg = NSImage(contentsOfFile: path),
          let cgImg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        continue
    }
    
    let col = idx % cols
    let row = idx / cols
    let x = CGFloat(col) * thumbW
    let y = CGFloat(rows - 1 - row) * thumbH
    
    ctx.draw(cgImg, in: CGRect(x: x, y: y, width: thumbW, height: thumbH))
    
    // Draw badge #01, #02...
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = nsCtx
    
    let label = String(format: "#%02d 图", idx + 1) as NSString
    let bgRect = CGRect(x: x + 8, y: y + 8, width: 64, height: 24)
    NSColor.black.withAlphaComponent(0.75).setFill()
    NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
    
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 13),
        .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
    ]
    label.draw(at: CGPoint(x: x + 12, y: y + 11), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    
    // OCR
    let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
    var frameOcrTexts: [String] = []
    let ocrReq = VNRecognizeTextRequest { req, _ in
        guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
        for o in obs {
            if let top = o.topCandidates(1).first, top.confidence > 0.4 {
                frameOcrTexts.append(top.string)
            }
        }
    }
    ocrReq.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
    try? handler.perform([ocrReq])
    
    let ocrJoined = frameOcrTexts.isEmpty ? "无文字" : frameOcrTexts.joined(separator: " | ")
    logLines.append("图 #\(String(format: "%02d", idx + 1)): \(ocrJoined)")
}

if let finalImg = ctx.makeImage() {
    let rep = NSBitmapImageRep(cgImage: finalImg)
    if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.90]) {
        let sheetPath = "\(outDir)/sheet_1.jpg"
        try? jpg.write(to: URL(fileURLWithPath: sheetPath))
        print("Generated image sheet: \(sheetPath)")
    }
}

let timelinePath = "\(outDir)/timeline.txt"
try? logLines.joined(separator: "\n").write(to: URL(fileURLWithPath: timelinePath), atomically: true, encoding: .utf8)

let metaObj: [String: Any] = [
    "type": "images",
    "totalImages": totalImgs,
    "sheets": ["sheet_1.jpg"],
    "generatedAt": ISO8601DateFormatter().string(from: Date())
]

if let jsonData = try? JSONSerialization.data(withJSONObject: metaObj, options: [.prettyPrinted]) {
    try? jsonData.write(to: URL(fileURLWithPath: "\(outDir)/meta.json"))
}

