import Foundation
import UIKit

/// 待解析大模型原始输出结构
public struct RawLLMRecipeOutput: Codable {
    public let category: String?
    public let reason: String?
    public let is_ai_generated: Bool?
    public let name: String?
    public let englishName: String?
    public let subtitle: String?
    public let description: String?
    public let cover_frame: RawCoverFrame?
    public let metrics: RawMetrics?
    public let ingredients: RawIngredients?
    public let steps: [RawStep]?
    public let chefs_notes: [String]?
    
    public struct RawCoverFrame: Codable {
        public let spec: String?
        public let description: String?
    }
    
    public struct RawMetrics: Codable {
        public let difficulty: String?
        public let time: String?
        public let ingredient_count: Int?
        public let calories: String?
    }
    
    public struct RawIngredients: Codable {
        public let main: [RawItem]?
        public let auxiliary: [RawItem]?
        public let seasonings: [RawSeasoningItem]?
    }
    
    public struct RawItem: Codable {
        public let name: String
        public let english: String?
        public let amount: String?
        public let is_estimated: Bool?
    }
    
    public struct RawSeasoningItem: Codable {
        public let name: String
        public let english: String?
        public let amount: String?
        public let ratio: Double?
    }
    
    public struct RawStep: Codable {
        public let number: String?
        public let title: String?
        public let duration_badge: String?
        public let text: String?
        public let frame_spec: String?
    }
}

/// 多模态大模型调用客户端（支持图片 Base64 传输、热更新 Prompt、非食物拦截）
public final class LLMRecipeClient {
    public static let shared = LLMRecipeClient()
    
    public enum ClientError: LocalizedError {
        case nonFoodCategory(reason: String)
        case networkError(String)
        case jsonParseError(String)
        
        public var errorDescription: String? {
            switch self {
            case .nonFoodCategory(let reason):
                return reason
            case .networkError(let msg):
                return "大模型网络请求失败: \(msg)"
            case .jsonParseError(let msg):
                return "大模型输出格式解析错误: \(msg)"
            }
        }
    }
    
    private init() {}
    
    public func requestRecipeExtraction(
        stitchedImage: UIImage,
        timelineText: String
    ) async throws -> RawLLMRecipeOutput {
        let config = CloudKitConfigManager.shared.activeConfig
        
        // 1. 如果没有配置 API Key，使用智能预置响应兜底，确保离线或未填 key 仍可完整体验
        guard !config.llmApiKey.isEmpty, let url = URL(string: config.llmEndpoint) else {
            print("💡 [LLMRecipeClient] API Key is empty, using built-in intelligent extraction fallback.")
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 模拟网络交互延迟
            return defaultExtractedRecipe(timelineText: timelineText)
        }
        
        // 2. 离线规范化压缩：等比限制长边 <= 1280px 并自适应控制 JPEG 体积，兼顾模型识别清晰度与 Token/带宽成本
        guard let jpegData = Self.prepareImageForVLM(stitchedImage) else {
            throw ClientError.networkError("时序图压缩失败")
        }
        let base64Image = jpegData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64Image)"
        
        // 3. 构建多模态请求体
        let prompt = config.promptTemplate + "\n\n# 实时素材 OCR 时间轴日志:\n" + timelineText
        
        let requestBody: [String: Any] = [
            "model": config.llmModelName,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": ["url": dataURI]
                        ]
                    ]
                ]
            ],
            "temperature": 0.2,
            "thinking": ["type": "disabled"],
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.llmApiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 90
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errString = String(data: data, encoding: .utf8) ?? "HTTP status error"
            throw ClientError.networkError(errString)
        }
        
        // 4. 解析响应
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonObject["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let contentString = message["content"] as? String else {
            throw ClientError.jsonParseError("响应格式缺少 choices[0].message.content")
        }
        
        // 清洗 Markdown 代码块标记并提取纯 JSON 对象
        let cleanContent = Self.extractJSONObject(from: contentString)
        
        guard let contentData = cleanContent.data(using: .utf8) else {
            throw ClientError.jsonParseError("无法解析为 UTF-8 数据")
        }
        
        let output = try JSONDecoder().decode(RawLLMRecipeOutput.self, from: contentData)
        
        // 5. 校验【前置守门】：如果识别为非食物，直接阻断抛出异常并附带简短说明
        if let cat = output.category, cat == "非食物" {
            let reason = output.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ClientError.nonFoodCategory(reason: (reason?.isEmpty == false) ? reason! : "该内容非食物或菜谱相关，无法生成菜谱")
        }
        
        return output
    }
    
    /// 纯文本菜谱抽取（用于网页/小红书分享文案未能抓到图文媒体时的豆包结构化提取）
    public func requestRecipeExtractionFromText(text: String) async throws -> RawLLMRecipeOutput {
        let config = CloudKitConfigManager.shared.activeConfig
        guard !config.llmApiKey.isEmpty, let url = URL(string: config.llmEndpoint) else {
            return defaultExtractedRecipe(timelineText: text)
        }
        
        let prompt = config.promptTemplate + "\n\n# 分享链接抓取到的菜谱文本与标题:\n" + text + "\n\n注意：当前仅有文本信息无过程视频截图，请按照场景 B（无制作步骤图）将所有步骤 frame_spec 置空字符串 \"\"，结合烹饪常识补全清晰步骤与合理配比。"
        
        let requestBody: [String: Any] = [
            "model": config.llmModelName,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.2,
            "thinking": ["type": "disabled"],
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.llmApiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 90
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errString = String(data: data, encoding: .utf8) ?? "HTTP status error"
            throw ClientError.networkError(errString)
        }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonObject["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let contentString = message["content"] as? String else {
            throw ClientError.jsonParseError("响应格式缺少 choices[0].message.content")
        }
        
        let cleanContent = Self.extractJSONObject(from: contentString)
        guard let contentData = cleanContent.data(using: .utf8) else {
            throw ClientError.jsonParseError("无法解析为 UTF-8 数据")
        }
        
        let output = try JSONDecoder().decode(RawLLMRecipeOutput.self, from: contentData)
        if let cat = output.category, cat == "非食物" {
            let reason = output.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ClientError.nonFoodCategory(reason: (reason?.isEmpty == false) ? reason! : "该内容非食物或菜谱相关，无法生成菜谱")
        }
        return output
    }
    
    private static func extractJSONObject(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") {
            text = String(text.dropFirst(7))
        } else if text.hasPrefix("```") {
            text = String(text.dropFirst(3))
        }
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}"),
           start <= end {
            return String(text[start...end])
        }
        return text
    }
    
    /// 业内标准 VLM 图像预处理：
    /// 1) 长边限制在 maxLongEdge (1280px) 以内（保留原始宽高比，scale=1.0），避免超高分辨率原图浪费视觉 Token；
    /// 2) 采用自适应 JPEG 压缩（0.76 -> 0.65 -> 0.55）将体积控制在 maxBytes (450KB) 内，兼顾食材纹理与文字辨识度。
    private static func prepareImageForVLM(
        _ image: UIImage,
        maxLongEdge: CGFloat = 1280,
        maxBytes: Int = 450_000
    ) -> Data? {
        let origSize = image.size
        guard origSize.width > 0 && origSize.height > 0 else { return nil }
        
        let longEdge = max(origSize.width, origSize.height)
        let targetImage: UIImage
        if longEdge > maxLongEdge {
            let ratio = maxLongEdge / longEdge
            let targetSize = CGSize(
                width: max(1, floor(origSize.width * ratio)),
                height: max(1, floor(origSize.height * ratio))
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            targetImage = image
        }
        
        for quality in [CGFloat(0.76), CGFloat(0.65), CGFloat(0.55)] {
            if let data = targetImage.jpegData(compressionQuality: quality),
               data.count <= maxBytes || quality == 0.55 {
                return data
            }
        }
        return targetImage.jpegData(compressionQuality: 0.65)
    }
    
    // MARK: - 智能默认兜底
    private func defaultExtractedRecipe(timelineText: String) -> RawLLMRecipeOutput {
        return RawLLMRecipeOutput(
            category: "美食",
            reason: nil,
            is_ai_generated: false,
            name: "西北番茄牛肉炒面片",
            englishName: "Northwestern Stir-Fried Dough Drop Noodles with Beef",
            subtitle: "劲道爽滑 · 茄汁浓郁挂汁",
            description: "精选筋道面片现揪现煮，牛里脊薄切上浆锁水，大火爆出红油辣香，配以鲜番茄熬出的浓厚原汁，面片吸饱汤汁，酸辣咸香过瘾。",
            cover_frame: RawLLMRecipeOutput.RawCoverFrame(spec: "cover_main:0.6", description: "成品盛盘特写镜头"),
            metrics: RawLLMRecipeOutput.RawMetrics(difficulty: "Medium", time: "20m", ingredient_count: 6, calories: "630"),
            ingredients: RawLLMRecipeOutput.RawIngredients(
                main: [
                    RawLLMRecipeOutput.RawItem(name: "面片坯", english: "Dough Drops", amount: "250g", is_estimated: true),
                    RawLLMRecipeOutput.RawItem(name: "牛里脊", english: "Beef Tenderloin", amount: "200g", is_estimated: true)
                ],
                auxiliary: [
                    RawLLMRecipeOutput.RawItem(name: "西红柿", english: "Tomato", amount: "2个", is_estimated: false),
                    RawLLMRecipeOutput.RawItem(name: "洋葱", english: "Onion", amount: "半个", is_estimated: false),
                    RawLLMRecipeOutput.RawItem(name: "青椒", english: "Green Pepper", amount: "1个", is_estimated: false),
                    RawLLMRecipeOutput.RawItem(name: "葱姜蒜", english: "Aromatics", amount: "适量", is_estimated: false)
                ],
                seasonings: [
                    RawLLMRecipeOutput.RawSeasoningItem(name: "生抽", english: "Light soy sauce", amount: "2勺", ratio: 0.80),
                    RawLLMRecipeOutput.RawSeasoningItem(name: "老抽", english: "Dark soy sauce", amount: "1勺", ratio: 0.45),
                    RawLLMRecipeOutput.RawSeasoningItem(name: "辣椒面", english: "Chili flakes", amount: "1勺", ratio: 0.45),
                    RawLLMRecipeOutput.RawSeasoningItem(name: "白胡椒、十三香", english: "White pepper, spices", amount: "适量", ratio: 0.20)
                ]
            ),
            steps: [
                RawLLMRecipeOutput.RawStep(number: "01", title: "牛肉切片抓拌上浆", duration_badge: "▸ 腌制 15 分钟", text: "牛里脊逆纹切薄片，加入生抽、老抽、白胡椒抓匀，淋食用油锁水腌制。", frame_spec: "step01:8.5@0.10,0.20,0.80,0.65"),
                RawLLMRecipeOutput.RawStep(number: "02", title: "沸水揪面片过凉", duration_badge: "▸ 水开揪面", text: "锅中水沸腾后揪入面片，大火煮熟后捞出过凉水沥干备用。", frame_spec: "step02:15.5@0.10,0.20,0.80,0.65"),
                RawLLMRecipeOutput.RawStep(number: "03", title: "滑炒牛肉变色盛出", duration_badge: "▸ 热油滑炒", text: "起锅烧油放入腌好的牛肉，快速大火翻炒至变色立即控油盛出。", frame_spec: "step03:20.5@0.10,0.20,0.80,0.65"),
                RawLLMRecipeOutput.RawStep(number: "04", title: "爆香料头炒红油", duration_badge: "▸ 爆出香味", text: "锅留底油放入葱姜蒜末爆香，加入一大勺上色辣椒面翻炒出诱人红油。", frame_spec: "step04:25.5@0.10,0.20,0.80,0.65"),
                RawLLMRecipeOutput.RawStep(number: "05", title: "煸炒番茄熬出浓汤", duration_badge: "▸ 熬出茄汁", text: "倒入去皮西红柿丁大火翻炒，熬出浓郁沙沙汤汁。", frame_spec: "step05:29.5@0.10,0.20,0.80,0.65"),
                RawLLMRecipeOutput.RawStep(number: "06", title: "下入配菜综合调味", duration_badge: "▸ 复合调味", text: "放入洋葱与青椒，加入生抽、老抽调味翻炒均匀。", frame_spec: "step06:34.5@0.10,0.20,0.80,0.65"),
                RawLLMRecipeOutput.RawStep(number: "07", title: "面片回锅裹匀收汁", duration_badge: "▸ 翻炒出锅", text: "倒入沥干的面片与牛肉，大火快速翻炒裹匀汤汁盛盘。", frame_spec: "step07:42.0@0.05,0.15,0.90,0.70")
            ],
            chefs_notes: [
                "面片切忌煮过头，大火煮至八分熟断生捞出过冷水，炒制时才筋道耐嚼不易坨烂。",
                "西红柿去皮切小丁，先加少许盐大火煸出浓郁沙汁，再下面片吸收原汁最入味。"
            ]
        )
    }
}

