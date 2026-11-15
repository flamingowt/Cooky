import Foundation
import UIKit
import Vision

/// 多图/图文端侧拼接处理器（苹果原生 Vision + UIKit 硬件加速）
public final class PhotoStitchProcessor {
    public struct Result {
        public let stitchedImage: UIImage
        public let ocrText: String
        public let imagesCount: Int
    }
    
    public static func process(images: [UIImage]) throws -> Result {
        guard !images.isEmpty else {
            throw NSError(domain: "PhotoStitch", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片列表为空"])
        }
        
        let count = images.count
        let cols = count <= 2 ? count : (count <= 4 ? 2 : 3)
        let rows = Int(ceil(Double(count) / Double(cols)))
        
        let thumbW: CGFloat = 300
        let thumbH: CGFloat = 400
        let canvasW = thumbW * CGFloat(cols)
        let canvasH = thumbH * CGFloat(rows)
        
        var ocrLogs: [String] = []
        ocrLogs.append("Photo Count: \(count)")
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasW, height: canvasH), format: format)
        let stitched = renderer.image { ctx in
            UIColor(white: 0.08, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
            
            for (idx, img) in images.enumerated() {
                autoreleasepool {
                    let col = idx % cols
                    let row = idx / cols
                    let x = CGFloat(col) * thumbW
                    let y = CGFloat(row) * thumbH
                    let rect = CGRect(x: x, y: y, width: thumbW, height: thumbH)
                    
                    let imgSize = img.size
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
                        img.draw(in: drawRect)
                    } else {
                        img.draw(in: rect)
                    }
                    
                    // 绘制 #01 图 徽章
                    let badgeRect = CGRect(x: x + 8, y: y + 8, width: 68, height: 24)
                    UIColor.black.withAlphaComponent(0.75).setFill()
                    UIBezierPath(roundedRect: badgeRect, cornerRadius: 4).fill()
                    
                    let label = String(format: "#%02d 图", idx + 1) as NSString
                    let textAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 12),
                        .foregroundColor: UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
                    ]
                    label.draw(at: CGPoint(x: x + 12, y: y + 12), withAttributes: textAttrs)
                    
                    // OCR
                    if let cgImg = img.cgImage {
                        let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
                        var texts: [String] = []
                        let req = VNRecognizeTextRequest { request, _ in
                            guard let obs = request.results as? [VNRecognizedTextObservation] else { return }
                            for o in obs {
                                if let top = o.topCandidates(1).first, top.confidence > 0.4 {
                                    texts.append(top.string)
                                }
                            }
                        }
                        req.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
                        try? handler.perform([req])
                        
                        let line = texts.isEmpty ? "无文字" : texts.joined(separator: " | ")
                        ocrLogs.append("图 #\(String(format: "%02d", idx + 1)): \(line)")
                    }
                }
            }
        }
        
        return Result(
            stitchedImage: stitched,
            ocrText: ocrLogs.joined(separator: "\n"),
            imagesCount: count
        )
    }
}

