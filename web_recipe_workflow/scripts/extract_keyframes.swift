import Foundation
import AVFoundation
import AppKit
import CoreGraphics

// Usage: swift extract_keyframes.swift <video_path> <output_dir> <spec1> <spec2> ...
// Spec: name:seconds[@x,y,w,h]
guard CommandLine.arguments.count >= 4 else {
    fputs("Usage: swift extract_keyframes.swift <video_path> <output_dir> <name:sec[@x,y,w,h]> ...\n", stderr)
    exit(1)
}

let videoPath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

for arg in CommandLine.arguments.dropFirst(3) {
    let parts = arg.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { continue }
    let name = parts[0]
    let timeAndCrop = parts[1].split(separator: "@", maxSplits: 1).map(String.init)
    guard let sec = Double(timeAndCrop[0]) else { continue }
    
    var cropRectNormalized: CGRect? = nil
    if timeAndCrop.count == 2 {
        let nums = timeAndCrop[1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if nums.count == 4 {
            cropRectNormalized = CGRect(x: nums[0], y: nums[1], width: nums[2], height: nums[3])
        }
    }
    
    let time = CMTime(seconds: sec, preferredTimescale: 600)
    var actual = CMTime.zero
    guard var cgImg = try? generator.copyCGImage(at: time, actualTime: &actual) else {
        fputs("Failed to extract frame for \(name) at \(sec)s\n", stderr)
        continue
    }
    
    if let norm = cropRectNormalized {
        let w = CGFloat(cgImg.width)
        let h = CGFloat(cgImg.height)
        let pixelRect = CGRect(
            x: max(0, min(w - 1, norm.origin.x * w)),
            y: max(0, min(h - 1, norm.origin.y * h)),
            width: max(1, min(w, norm.size.width * w)),
            height: max(1, min(h, norm.size.height * h))
        ).integral
        if let cropped = cgImg.cropping(to: pixelRect) {
            cgImg = cropped
        }
    }
    
    let rep = NSBitmapImageRep(cgImage: cgImg)
    if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.94]) {
        let dest = "\(outDir)/\(name).jpg"
        try? jpg.write(to: URL(fileURLWithPath: dest))
        print("Saved crop: \(name).jpg (time=\(sec)s)")
    }
}

