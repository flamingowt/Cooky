import Foundation
import AVFoundation
import Vision
import UIKit

/// 视频采样与时序网格大图端侧处理器（纯原生 AVFoundation + Vision，硬件加速）
public final class VideoSamplingProcessor {
    public struct Result {
        public let contactSheetImage: UIImage
        public let timelineText: String
        public let durationSeconds: Double
        public let sampledFramesCount: Int
    }
    
    public static func process(videoURL: URL, maxSheets: Int = 1) async throws -> Result {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard durationSeconds > 0 && !durationSeconds.isNaN else {
            throw NSError(domain: "VideoSampling", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析视频时长"])
        }
        
        let cols = 5
        let maxRows = 10
        let perSheet = cols * maxRows
        let maxFrames = maxSheets * perSheet
        
        var sampleStep: Double = 1.0
        if durationSeconds > Double(maxFrames) {
            sampleStep = durationSeconds / Double(maxFrames)
        }
        
        let totalSamples = min(maxFrames, max(1, Int(floor(durationSeconds / sampleStep))))
        let actualRows = max(1, Int(ceil(Double(totalSamples) / Double(cols))))
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: 720, height: 1280)
        
        let thumbW: CGFloat = 240
        let thumbH: CGFloat = 320
        let canvasW = thumbW * CGFloat(cols)
        let canvasH = thumbH * CGFloat(actualRows)
        
        // 渲染画布（必须在后台线程 + scale=1.0 下执行，避免在 3x 屏幕上分配 ~168MB 位图及阻塞主线程）
        return await Task.detached(priority: .userInitiated) {
            var ocrLogs: [String] = []
            ocrLogs.append("Duration: \(String(format: "%.1f", durationSeconds))s | Sampled: \(totalSamples) frames")
            
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasW, height: canvasH), format: format)
            
            let contactSheet = renderer.image { ctx in
                // 背景黑底
                UIColor(white: 0.08, alpha: 1.0).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
                
                for idx in 0..<totalSamples {
                    autoreleasepool {
                        let sec = (Double(idx) * sampleStep) + (sampleStep * 0.5)
                        if sec >= durationSeconds { return }
                        
                        let time = CMTime(seconds: sec, preferredTimescale: 600)
                        guard let cgImg = try? generator.copyCGImage(at: time, actualTime: nil) else {
                            return
                        }
                        
                        let col = idx % cols
                        let row = idx / cols
                        let x = CGFloat(col) * thumbW
                        let y = CGFloat(row) * thumbH
                        let cellRect = CGRect(x: x, y: y, width: thumbW, height: thumbH)
                        
                        // 等比缩放居中绘制（对齐 ffmpeg scale+pad）
                        let uiImg = UIImage(cgImage: cgImg)
                        let imgSize = uiImg.size
                        if imgSize.width > 0 && imgSize.height > 0 {
                            let scale = min(thumbW / imgSize.width, thumbH / imgSize.height)
                            let drawW = imgSize.width * scale
                            let drawH = imgSize.height * scale
                            let drawRect = CGRect(
                                x: x + (thumbW - drawW) * 0.5,
                                y: y + (thumbH - drawH) * 0.5,
                                width: drawW,
                                height: drawH
                            )
                            uiImg.draw(in: drawRect)
                        } else {
                            uiImg.draw(in: cellRect)
                        }
                        
                        // 绘制时间戳胶囊徽章 #01 | 1.5s
                        let badgeRect = CGRect(x: x + 6, y: y + 6, width: 84, height: 22)
                        UIColor.black.withAlphaComponent(0.75).setFill()
                        UIBezierPath(roundedRect: badgeRect, cornerRadius: 4).fill()
                        
                        let label = String(format: "#%02d | %.1fs", idx + 1, sec) as NSString
                        let textAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.boldSystemFont(ofSize: 11),
                            .foregroundColor: UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
                        ]
                        label.draw(at: CGPoint(x: x + 10, y: y + 9), withAttributes: textAttrs)
                        
                        // 端侧 Vision OCR 识别文字
                        let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
                        var texts: [String] = []
                        let req = VNRecognizeTextRequest { request, _ in
                            guard let obs = request.results as? [VNRecognizedTextObservation] else { return }
                            for o in obs {
                                if let top = o.topCandidates(1).first, top.confidence > 0.4 {
                                    let yNorm = o.boundingBox.origin.y
                                    texts.append(String(format: "[%.2f] %@", yNorm, top.string))
                                }
                            }
                        }
                        req.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
                        req.recognitionLevel = .accurate
                        try? handler.perform([req])
                        
                        if !texts.isEmpty {
                            ocrLogs.append("t=\(String(format: "%.1f", sec))s: \(texts.joined(separator: " | "))")
                        }
                    }
                }
            }
            
            return Result(
                contactSheetImage: contactSheet,
                timelineText: ocrLogs.joined(separator: "\n"),
                durationSeconds: durationSeconds,
                sampledFramesCount: totalSamples
            )
        }.value
    }
}
