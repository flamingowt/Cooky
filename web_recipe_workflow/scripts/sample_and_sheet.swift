import Foundation
import AVFoundation
import Vision
import AppKit
import CoreGraphics

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: swift sample_and_sheet.swift <video_path> <output_dir> [max_sheets]\n", stderr)
    exit(1)
}

let videoPath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
let maxSheets = CommandLine.arguments.count >= 4 ? (Int(CommandLine.arguments[3]) ?? 3) : 3

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
let durationSeconds = CMTimeGetSeconds(asset.duration)

if durationSeconds.isNaN || durationSeconds <= 0 {
    fputs("Error: Could not determine video duration\n", stderr)
    exit(1)
}

// Layout config
let cols = 5
let rows = 10
let perSheet = cols * rows
let maxTotalFrames = maxSheets * perSheet

// Calculate sampling interval
var sampleStep: Double = 1.0
if durationSeconds > Double(maxTotalFrames) {
    sampleStep = durationSeconds / Double(maxTotalFrames)
}

let totalSamples = min(maxTotalFrames, Int(floor(durationSeconds / sampleStep)))
let numSheets = max(1, Int(ceil(Double(totalSamples) / Double(perSheet))))

let thumbW: CGFloat = 270
let thumbH: CGFloat = 360

var logLines: [String] = []
logLines.append("Video: \(URL(fileURLWithPath: videoPath).lastPathComponent)")
logLines.append(String(format: "Duration: %.2f seconds", durationSeconds))
logLines.append("Sampling step: \(String(format: "%.2f", sampleStep))s | Total frames: \(totalSamples) | Sheets: \(numSheets)")
logLines.append("--- TIMELINE OCR LOG ---")

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
generator.maximumSize = CGSize(width: 960, height: 1280)

var sheetContexts: [CGContext] = []
for _ in 0..<numSheets {
    let width = Int(thumbW) * cols
    let height = Int(thumbH) * rows
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) {
        ctx.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        sheetContexts.append(ctx)
    }
}

var previousFeaturePrint: VNFeaturePrintObservation? = nil
var sheetNames: [String] = []

for idx in 0..<totalSamples {
    let sec = (Double(idx) * sampleStep) + (sampleStep * 0.5)
    if sec >= durationSeconds { break }
    
    let time = CMTime(seconds: sec, preferredTimescale: 600)
    var actualTime = CMTime.zero
    guard let cgImage = try? generator.copyCGImage(at: time, actualTime: &actualTime) else {
        continue
    }
    
    // Draw into contact sheet
    let sheetIdx = idx / perSheet
    let localIdx = idx % perSheet
    if sheetIdx < sheetContexts.count {
        let ctx = sheetContexts[sheetIdx]
        let col = localIdx % cols
        let row = localIdx / cols
        let x = CGFloat(col) * thumbW
        let y = CGFloat(rows - 1 - row) * thumbH
        
        ctx.draw(cgImage, in: CGRect(x: x, y: y, width: thumbW, height: thumbH))
        
        // Render timestamp badge
        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsCtx
        
        let label = String(format: "#%02d | %.1fs", idx + 1, sec) as NSString
        let bgRect = CGRect(x: x + 6, y: y + 6, width: 84, height: 22)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        ]
        label.draw(at: CGPoint(x: x + 10, y: y + 9), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }
    
    // OCR + Scene Change Recognition
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    var frameOcrTexts: [String] = []
    
    let ocrReq = VNRecognizeTextRequest { req, _ in
        guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
        for o in obs {
            if let top = o.topCandidates(1).first, top.confidence > 0.4 {
                let y = o.boundingBox.origin.y
                frameOcrTexts.append(String(format: "[%.2f] %@", y, top.string))
            }
        }
    }
    ocrReq.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
    ocrReq.recognitionLevel = .accurate
    
    let fpReq = VNGenerateImageFeaturePrintRequest()
    try? handler.perform([ocrReq, fpReq])
    
    var distStr = ""
    if let fp = fpReq.results?.first as? VNFeaturePrintObservation {
        if let prev = previousFeaturePrint {
            var dist: Float = 0
            if (try? fp.computeDistance(&dist, to: prev)) != nil {
                distStr = String(format: " | dist=%.2f", dist)
            }
        }
        previousFeaturePrint = fp
    }
    
    let ocrJoined = frameOcrTexts.isEmpty ? "" : ": " + frameOcrTexts.joined(separator: " | ")
    let logLine = String(format: "t=%05.1fs (frame %02d%@)%@", sec, idx + 1, distStr, ocrJoined)
    logLines.append(logLine)
}

// Save Contact Sheets
for (idx, ctx) in sheetContexts.enumerated() {
    if let cgImg = ctx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: cgImg)
        if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) {
            let name = "sheet_\(idx + 1).jpg"
            let path = "\(outDir)/\(name)"
            try? jpg.write(to: URL(fileURLWithPath: path))
            sheetNames.append(name)
            print("Generated sheet: \(name)")
        }
    }
}

// Write Timeline log
let timelinePath = "\(outDir)/timeline.txt"
try? logLines.joined(separator: "\n").write(to: URL(fileURLWithPath: timelinePath), atomically: true, encoding: .utf8)
print("Saved timeline: \(timelinePath)")

// Write Metadata JSON
let metaObj: [String: Any] = [
    "video": URL(fileURLWithPath: videoPath).lastPathComponent,
    "duration": durationSeconds,
    "sampleStep": sampleStep,
    "totalFrames": totalSamples,
    "sheets": sheetNames,
    "generatedAt": ISO8601DateFormatter().string(from: Date())
]

if let jsonData = try? JSONSerialization.data(withJSONObject: metaObj, options: [.prettyPrinted]) {
    try? jsonData.write(to: URL(fileURLWithPath: "\(outDir)/meta.json"))
}

