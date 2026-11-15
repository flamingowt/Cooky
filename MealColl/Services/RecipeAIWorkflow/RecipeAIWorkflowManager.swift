import Foundation
import UIKit
import AVFoundation
import SwiftUI

/// 菜谱 AI 工作流调度主引擎（单例，负责三路径输入统一调度、端侧算力采样、模型交互与结果入队）
@MainActor
public final class RecipeAIWorkflowManager: ObservableObject {
    public static let shared = RecipeAIWorkflowManager()
    
    @Published public var isProcessing: Bool = false
    @Published public var showParsingOverlay: Bool = false
    @Published public var activeTaskId: String? = nil
    @Published public var statusMessage: String = ""
    @Published public var errorMessage: String? = nil
    @Published public var lastCreatedPendingItem: PendingRecipeItem? = nil
    @Published public var retryingItemIds: Set<String> = []
    
    private var queueWorkerTask: Task<Void, Never>? = nil
    private var bgTaskId: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.ensureQueueWorkerRunning()
        }
    }
    
    // MARK: - Serial Background Queue Worker
    public func ensureQueueWorkerRunning() {
        guard queueWorkerTask == nil else { return }
        guard PendingRecipeQueueManager.shared.nextQueuedItem() != nil else { return }
        
        queueWorkerTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.queueWorkerTask = nil
                self.isProcessing = false
                self.activeTaskId = nil
                self.endBackgroundTaskIfNeeded()
                if PendingRecipeQueueManager.shared.nextQueuedItem() == nil {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        self.showParsingOverlay = false
                    }
                }
            }
            
            while let nextItem = PendingRecipeQueueManager.shared.nextQueuedItem() {
                self.beginBackgroundTaskIfNeeded()
                self.isProcessing = true
                self.activeTaskId = nextItem.id
                self.errorMessage = nil
                self.retryingItemIds.insert(nextItem.id)
                PendingRecipeQueueManager.shared.updateItemStatus(id: nextItem.id, status: .processing)
                
                await self.executeQueuedItem(nextItem)
                
                self.retryingItemIds.remove(nextItem.id)
                self.endBackgroundTaskIfNeeded()
            }
        }
    }
    
    private func beginBackgroundTaskIfNeeded() {
        guard bgTaskId == .invalid else { return }
        bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "MealCollRecipeParsing") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTaskIfNeeded()
            }
        }
    }
    
    private func endBackgroundTaskIfNeeded() {
        guard bgTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTaskId)
        bgTaskId = .invalid
    }
    
    private func executeQueuedItem(_ item: PendingRecipeItem) async {
        guard let payload = item.retryPayload else {
            let fallbackText = [item.title, item.subtitle, item.descriptionText]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0 != "非食物内容" && !$0.contains("解析中") }
                .joined(separator: "\n")
            guard !fallbackText.isEmpty else {
                PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .failed, errorReason: "缺少原始素材，请重新导入")
                return
            }
            do {
                try await processTextRecipe(
                    text: fallbackText,
                    coverImage: item.coverImageData.flatMap { UIImage(data: $0) },
                    sourceTag: item.sourceTag,
                    replacingItemId: item.id,
                    retryPayloadOverride: nil
                )
            } catch {
                PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .failed, errorReason: error.localizedDescription)
            }
            return
        }
        
        switch payload.kind {
        case .link:
            if let text = payload.textInput {
                await runLinkExtraction(urlString: text, replacingItemId: item.id, retryPayloadOverride: payload)
            } else {
                PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .failed, errorReason: "链接内容为空")
            }
        case .video:
            if let videoName = payload.videoFileName,
               let videoURL = PendingRetryStorage.videoURL(fileName: videoName) {
                await runVideoExtraction(url: videoURL, sourceTag: payload.sourceTag, replacingItemId: item.id, retryPayloadOverride: payload)
            } else {
                PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .failed, errorReason: "本地视频缓存已清理，请重新导入")
            }
        case .images:
            if let names = payload.imageFileNames {
                let imgs = PendingRetryStorage.loadImages(fileNames: names)
                if !imgs.isEmpty {
                    await runImagesExtraction(
                        images: imgs,
                        sourceTag: payload.sourceTag,
                        extraContextText: payload.extraContextText,
                        replacingItemId: item.id,
                        retryPayloadOverride: payload
                    )
                    return
                }
            }
            PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .failed, errorReason: "本地图片缓存已清理，请重新导入")
        case .text:
            if let text = payload.textInput {
                do {
                    try await processTextRecipe(
                        text: text,
                        coverImage: item.coverImageData.flatMap { UIImage(data: $0) },
                        sourceTag: payload.sourceTag,
                        replacingItemId: item.id,
                        retryPayloadOverride: payload
                    )
                } catch {
                    PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .failed, errorReason: error.localizedDescription)
                }
            } else {
                PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .failed, errorReason: "文本内容为空")
            }
        }
    }
    
    // MARK: - Reprocess Pending Item (待入库「重新识别」入口，走同一串行队列)
    public func reprocessPendingItem(_ item: PendingRecipeItem) async {
        guard !item.isPendingOrActive else {
            showParsingOverlay = true
            return
        }
        PendingRecipeQueueManager.shared.updateItemStatus(id: item.id, status: .queued, errorReason: nil)
        ensureQueueWorkerRunning()
    }
    
    // MARK: - Path 1: 视频处理 (立即入队并串行执行)
    public func processVideo(
        url: URL,
        sourceTag: String = "本地视频",
        replacingItemId: String? = nil,
        retryPayloadOverride: PendingRetryPayload? = nil
    ) async {
        if let replacingItemId {
            await runVideoExtraction(url: url, sourceTag: sourceTag, replacingItemId: replacingItemId, retryPayloadOverride: retryPayloadOverride)
            return
        }
        let payload = retryPayloadOverride ?? PendingRetryStorage.saveVideo(from: url).map {
            PendingRetryPayload(kind: .video, videoFileName: $0, sourceTag: sourceTag)
        }
        let thumbData = await extractFirstVideoFrameData(videoURL: url)
        let placeholder = makeQueuedPendingItem(
            title: "视频菜谱解析中...",
            subtitle: "正在排队等待解析",
            coverImageData: thumbData,
            sourceTag: sourceTag,
            retryPayload: payload
        )
        PendingRecipeQueueManager.shared.enqueue(placeholder)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            showParsingOverlay = true
        }
        ensureQueueWorkerRunning()
    }
    
    private func runVideoExtraction(
        url: URL,
        sourceTag: String,
        replacingItemId: String,
        retryPayloadOverride: PendingRetryPayload?
    ) async {
        statusMessage = "🚀 正在调用本地算力 (AVFoundation & Vision) 对视频进行采样..."
        let payload = retryPayloadOverride ?? PendingRetryStorage.saveVideo(from: url).map {
            PendingRetryPayload(kind: .video, videoFileName: $0, sourceTag: sourceTag)
        }
        
        do {
            // 1. 端侧抽帧、打时间戳、5x10 时序大图拼接与逐秒 OCR
            let sampleResult = try await VideoSamplingProcessor.process(videoURL: url)
            
            statusMessage = "🤖 正在提交时序大图至大模型进行结构化抽取..."
            // 2. 请求大模型
            let rawOutput = try await LLMRecipeClient.shared.requestRecipeExtraction(
                stitchedImage: sampleResult.contactSheetImage,
                timelineText: sampleResult.timelineText
            )
            
            statusMessage = "📸 正在根据关键帧规范精准提取步骤配图..."
            // 3. 端侧精准截取关键帧与封面
            let pendingItem = try await buildPendingItem(
                from: rawOutput,
                videoURL: url,
                sourceTag: sourceTag,
                retryPayload: payload,
                existingId: replacingItemId
            )
            
            // 4. 替换队列中对应条目为完成状态
            enqueueOrReplace(pendingItem, replacingItemId: replacingItemId)
            self.lastCreatedPendingItem = pendingItem
            
            statusMessage = "✅ 菜谱提取成功！已加入待入库队列"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let LLMRecipeClient.ClientError.nonFoodCategory(reason) {
            let thumbData = await extractFirstVideoFrameData(videoURL: url)
            let nonFoodItem = makeNonFoodPendingItem(
                reason: reason,
                coverImageData: thumbData,
                sourceTag: sourceTag,
                retryPayload: payload,
                existingId: replacingItemId
            )
            enqueueOrReplace(nonFoodItem, replacingItemId: replacingItemId)
            self.errorMessage = reason
            self.statusMessage = "⚠️ \(reason)"
            RecipeDataManager.shared.showToast("⚠️ 非食物内容：\(reason)")
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } catch {
            print("❌ [RecipeAIWorkflowManager] Video processing failed: \(error)")
            self.errorMessage = error.localizedDescription
            PendingRecipeQueueManager.shared.updateItemStatus(id: replacingItemId, status: .failed, errorReason: error.localizedDescription)
            RecipeDataManager.shared.showToast("❌ \(error.localizedDescription)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    // MARK: - Path 2: 图片处理 (立即入队并串行执行)
    public func processImages(
        images: [UIImage],
        sourceTag: String = "相册导入",
        extraContextText: String? = nil,
        replacingItemId: String? = nil,
        retryPayloadOverride: PendingRetryPayload? = nil
    ) async {
        guard !images.isEmpty else { return }
        if let replacingItemId {
            await runImagesExtraction(images: images, sourceTag: sourceTag, extraContextText: extraContextText, replacingItemId: replacingItemId, retryPayloadOverride: retryPayloadOverride)
            return
        }
        let payload = retryPayloadOverride ?? PendingRetryPayload(
            kind: .images,
            imageFileNames: PendingRetryStorage.saveImages(images),
            extraContextText: extraContextText,
            sourceTag: sourceTag
        )
        let thumbData = images.first?.jpegData(compressionQuality: 0.72)
        let placeholder = makeQueuedPendingItem(
            title: "图文菜谱解析中...",
            subtitle: "共 \(images.count) 张图片 · 正在排队解析",
            coverImageData: thumbData,
            sourceTag: sourceTag,
            retryPayload: payload
        )
        PendingRecipeQueueManager.shared.enqueue(placeholder)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            showParsingOverlay = true
        }
        ensureQueueWorkerRunning()
    }
    
    private func runImagesExtraction(
        images: [UIImage],
        sourceTag: String,
        extraContextText: String?,
        replacingItemId: String,
        retryPayloadOverride: PendingRetryPayload?
    ) async {
        guard !images.isEmpty else { return }
        statusMessage = "🖼️ 正在进行端侧图片拼接与文字识别（共 \(images.count) 张）..."
        
        let payload = retryPayloadOverride ?? PendingRetryPayload(
            kind: .images,
            imageFileNames: PendingRetryStorage.saveImages(images),
            extraContextText: extraContextText,
            sourceTag: sourceTag
        )
        
        do {
            // 1. 端侧网格拼图与 OCR（后台线程）
            let stitchResult = try await Task.detached(priority: .userInitiated) {
                try PhotoStitchProcessor.process(images: images)
            }.value
            
            var timelineWithContext = stitchResult.ocrText
            if let extra = extraContextText?.trimmingCharacters(in: .whitespacesAndNewlines), !extra.isEmpty {
                timelineWithContext += "\n\n# 链接页面标题与正文补充:\n" + extra
            }
            
            statusMessage = "🤖 正在分析画面食材与烹饪步骤..."
            // 2. 大模型结构化提取
            let rawOutput = try await LLMRecipeClient.shared.requestRecipeExtraction(
                stitchedImage: stitchResult.stitchedImage,
                timelineText: timelineWithContext
            )
            
            statusMessage = "✨ 正在规整菜谱与配比..."
            // 3. 构建待入库对象
            let pendingItem = buildPendingItemFromPhotos(
                from: rawOutput,
                images: images,
                sourceTag: sourceTag,
                retryPayload: payload,
                existingId: replacingItemId
            )
            
            // 4. 替换队列中对应条目为完成状态
            enqueueOrReplace(pendingItem, replacingItemId: replacingItemId)
            self.lastCreatedPendingItem = pendingItem
            
            statusMessage = "✅ 菜谱提取成功！已加入待入库队列"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let LLMRecipeClient.ClientError.nonFoodCategory(reason) {
            let thumbData = images.first?.jpegData(compressionQuality: 0.75)
            let nonFoodItem = makeNonFoodPendingItem(
                reason: reason,
                coverImageData: thumbData,
                sourceTag: sourceTag,
                retryPayload: payload,
                existingId: replacingItemId
            )
            enqueueOrReplace(nonFoodItem, replacingItemId: replacingItemId)
            self.errorMessage = reason
            self.statusMessage = "⚠️ \(reason)"
            RecipeDataManager.shared.showToast("⚠️ 非食物内容：\(reason)")
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } catch {
            print("❌ [RecipeAIWorkflowManager] Images processing failed: \(error)")
            self.errorMessage = error.localizedDescription
            PendingRecipeQueueManager.shared.updateItemStatus(id: replacingItemId, status: .failed, errorReason: error.localizedDescription)
            RecipeDataManager.shared.showToast("❌ \(error.localizedDescription)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    // MARK: - Path 3: 粘贴链接处理 (立即入队并串行执行)
    public func processLink(
        urlString: String,
        replacingItemId: String? = nil,
        retryPayloadOverride: PendingRetryPayload? = nil
    ) async {
        let trimmedInput = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            self.errorMessage = "请输入有效的分享链接或菜谱文案"
            RecipeDataManager.shared.showToast("❌ \(self.errorMessage!)")
            return
        }
        
        if let replacingItemId {
            await runLinkExtraction(urlString: trimmedInput, replacingItemId: replacingItemId, retryPayloadOverride: retryPayloadOverride)
            return
        }
        
        let isURL = extractFirstURL(from: trimmedInput) != nil
        let payload = retryPayloadOverride ?? PendingRetryPayload(
            kind: isURL ? .link : .text,
            textInput: trimmedInput,
            sourceTag: isURL ? "链接解析" : "文本导入"
        )
        let placeholder = makeQueuedPendingItem(
            title: isURL ? "链接菜谱解析中..." : "文本菜谱解析中...",
            subtitle: trimmedInput,
            coverImageData: nil,
            sourceTag: payload.sourceTag,
            retryPayload: payload
        )
        PendingRecipeQueueManager.shared.enqueue(placeholder)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            showParsingOverlay = true
        }
        ensureQueueWorkerRunning()
    }
    
    private func runLinkExtraction(
        urlString: String,
        replacingItemId: String,
        retryPayloadOverride: PendingRetryPayload?
    ) async {
        statusMessage = "🔗 正在解析分享链接..."
        let trimmedInput = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkPayload = retryPayloadOverride ?? PendingRetryPayload(
            kind: .link,
            textInput: trimmedInput,
            sourceTag: "链接解析"
        )
        
        if let rawURL = extractFirstURL(from: trimmedInput) {
            let targetURL = upgradeToHTTPSIfNeeded(rawURL)
            do {
                let result = try await fetchAndInspectLink(targetURL)
                switch result {
                case .video(let localURL):
                    await runVideoExtraction(url: localURL, sourceTag: "链接解析", replacingItemId: replacingItemId, retryPayloadOverride: linkPayload)
                    return
                case .images(let images, let contextText):
                    let combinedContext = [stripURLs(from: trimmedInput), contextText]
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: "\n")
                    await runImagesExtraction(images: images, sourceTag: "链接解析", extraContextText: combinedContext, replacingItemId: replacingItemId, retryPayloadOverride: linkPayload)
                    return
                case .webContent(let extractedText, let coverImage):
                    let combinedText = [trimmedInput, extractedText]
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: "\n")
                    try await processTextRecipe(text: combinedText, coverImage: coverImage, sourceTag: "链接解析", replacingItemId: replacingItemId, retryPayloadOverride: linkPayload)
                    return
                }
            } catch {
                print("⚠️ [RecipeAIWorkflowManager] Link fetch error: \(error)")
                let nonURLText = stripURLs(from: trimmedInput)
                if nonURLText.count >= 4 {
                    do {
                        try await processTextRecipe(text: trimmedInput, coverImage: nil, sourceTag: "链接解析", replacingItemId: replacingItemId, retryPayloadOverride: linkPayload)
                        return
                    } catch let llmErr {
                        self.errorMessage = llmErr.localizedDescription
                        PendingRecipeQueueManager.shared.updateItemStatus(id: replacingItemId, status: .failed, errorReason: llmErr.localizedDescription)
                        RecipeDataManager.shared.showToast("❌ \(llmErr.localizedDescription)")
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        return
                    }
                }
                self.errorMessage = "链接解析失败：\(error.localizedDescription)"
                PendingRecipeQueueManager.shared.updateItemStatus(id: replacingItemId, status: .failed, errorReason: self.errorMessage)
                RecipeDataManager.shared.showToast("❌ \(self.errorMessage!)")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
        } else {
            let textPayload = retryPayloadOverride ?? PendingRetryPayload(kind: .text, textInput: trimmedInput, sourceTag: "文本导入")
            do {
                try await processTextRecipe(text: trimmedInput, coverImage: nil, sourceTag: "文本导入", replacingItemId: replacingItemId, retryPayloadOverride: textPayload)
            } catch {
                self.errorMessage = error.localizedDescription
                PendingRecipeQueueManager.shared.updateItemStatus(id: replacingItemId, status: .failed, errorReason: error.localizedDescription)
                RecipeDataManager.shared.showToast("❌ \(error.localizedDescription)")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    private func processTextRecipe(
        text: String,
        coverImage: UIImage?,
        sourceTag: String,
        replacingItemId: String? = nil,
        retryPayloadOverride: PendingRetryPayload? = nil
    ) async throws {
        statusMessage = "🤖 正在通过豆包大模型整理菜谱步骤与配料..."
        let payload = retryPayloadOverride ?? PendingRetryPayload(kind: .text, textInput: text, sourceTag: sourceTag)
        do {
            let raw = try await LLMRecipeClient.shared.requestRecipeExtractionFromText(text: text)
            let imgs = coverImage.map { [$0] } ?? []
            let pendingItem = buildPendingItemFromPhotos(
                from: raw,
                images: imgs,
                sourceTag: sourceTag,
                retryPayload: payload,
                existingId: replacingItemId
            )
            enqueueOrReplace(pendingItem, replacingItemId: replacingItemId)
            self.lastCreatedPendingItem = pendingItem
            self.statusMessage = "✅ 菜谱提取成功！已加入待入库队列"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let LLMRecipeClient.ClientError.nonFoodCategory(reason) {
            let thumbData = coverImage?.jpegData(compressionQuality: 0.75)
            let nonFoodItem = makeNonFoodPendingItem(
                reason: reason,
                coverImageData: thumbData,
                sourceTag: sourceTag,
                retryPayload: payload,
                existingId: replacingItemId
            )
            enqueueOrReplace(nonFoodItem, replacingItemId: replacingItemId)
            self.errorMessage = reason
            self.statusMessage = "⚠️ \(reason)"
            RecipeDataManager.shared.showToast("⚠️ 非食物内容：\(reason)")
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    
    private func makeQueuedPendingItem(
        title: String,
        subtitle: String,
        coverImageData: Data?,
        sourceTag: String,
        retryPayload: PendingRetryPayload?
    ) -> PendingRecipeItem {
        PendingRecipeItem(
            title: title,
            englishTitle: "Parsing Recipe...",
            subtitle: subtitle,
            descriptionText: subtitle,
            cookingTime: "--",
            calories: "--",
            difficulty: "AI 解析",
            ingredientCount: 0,
            coverImageData: coverImageData,
            mainIngredients: [],
            auxiliaryIngredients: [],
            seasonings: [],
            steps: [],
            chefNotes: [],
            sourceTag: sourceTag,
            retryPayload: retryPayload,
            status: .queued
        )
    }
    
    private func enqueueOrReplace(_ item: PendingRecipeItem, replacingItemId: String?) {
        if let targetId = replacingItemId {
            PendingRecipeQueueManager.shared.replaceItem(id: targetId, with: item)
        } else {
            PendingRecipeQueueManager.shared.enqueue(item)
        }
    }
    
    private func makeNonFoodPendingItem(
        reason: String,
        coverImageData: Data?,
        sourceTag: String,
        retryPayload: PendingRetryPayload?,
        existingId: String?
    ) -> PendingRecipeItem {
        PendingRecipeItem(
            id: existingId ?? UUID().uuidString,
            title: "非食物内容",
            englishTitle: "Non-Food Content",
            subtitle: reason,
            descriptionText: reason,
            cookingTime: "--",
            calories: "--",
            difficulty: "--",
            ingredientCount: 0,
            coverImageData: coverImageData,
            mainIngredients: [],
            auxiliaryIngredients: [],
            seasonings: [],
            steps: [],
            chefNotes: [],
            sourceTag: sourceTag,
            isNotFood: true,
            errorReason: reason,
            retryPayload: retryPayload
        )
    }
    
    private func extractFirstVideoFrameData(videoURL: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 640)
            guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72)
        }.value
    }
    
    // MARK: - Private Helpers
    private func buildPendingItem(
        from raw: RawLLMRecipeOutput,
        videoURL: URL,
        sourceTag: String,
        retryPayload: PendingRetryPayload? = nil,
        existingId: String? = nil
    ) async throws -> PendingRecipeItem {
        let coverSpec = raw.cover_frame?.spec
        let rawSteps = Array((raw.steps ?? []).prefix(15))
        let stepSpecs = rawSteps.map { $0.frame_spec }
        
        // 在后台线程执行视频帧解码与 ROI 裁剪，并限制 maximumSize 防止 4K 视频爆内存
        let (coverData, stepImageDatas): (Data?, [Data?]) = await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.15, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.15, preferredTimescale: 600)
            generator.maximumSize = CGSize(width: 1280, height: 1280)
            
            func extractVideoFrame(spec: String?, fallbackSec: Double?) -> Data? {
                return autoreleasepool {
                    var targetSec: Double? = fallbackSec
                    var roiCoords: [Double]? = nil
                    
                    if let spec = spec?.trimmingCharacters(in: .whitespacesAndNewlines), !spec.isEmpty {
                        let parts = spec.split(separator: ":", maxSplits: 1).map(String.init)
                        let timeAndROI = (parts.count >= 2 ? parts[1] : parts[0]).split(separator: "@", maxSplits: 1).map(String.init)
                        if let parsedSec = Double(timeAndROI[0].trimmingCharacters(in: .whitespaces)) {
                            targetSec = parsedSec
                        }
                        if timeAndROI.count == 2 {
                            let coords = timeAndROI[1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                            if coords.count == 4 {
                                roiCoords = coords
                            }
                        }
                    }
                    
                    guard let sec = targetSec, sec >= 0 else { return nil }
                    let time = CMTime(seconds: sec, preferredTimescale: 600)
                    guard var cgImg = try? generator.copyCGImage(at: time, actualTime: nil) else {
                        return nil
                    }
                    
                    if let coords = roiCoords {
                        let w = CGFloat(cgImg.width)
                        let h = CGFloat(cgImg.height)
                        let pixelRect = CGRect(
                            x: max(0, min(w - 1, coords[0] * w)),
                            y: max(0, min(h - 1, coords[1] * h)),
                            width: max(1, min(w, coords[2] * w)),
                            height: max(1, min(h, coords[3] * h))
                        ).integral
                        if let cropped = cgImg.cropping(to: pixelRect) {
                            cgImg = cropped
                        }
                    }
                    return UIImage(cgImage: cgImg).jpegData(compressionQuality: 0.85)
                }
            }
            
            let cover = extractVideoFrame(spec: coverSpec, fallbackSec: 0.6)
            let steps = stepSpecs.map { extractVideoFrame(spec: $0, fallbackSec: nil) }
            return (cover, steps)
        }.value
        
        // 2. 映射主辅料
        let mainList = (raw.ingredients?.main ?? []).map { item in
            PendingRecipeItem.RecipeIngredientItem(
                name: item.name,
                english: item.english ?? "Main Cut",
                amount: item.amount ?? "200g",
                isEstimated: item.is_estimated ?? false
            )
        }
        
        let auxList = (raw.ingredients?.auxiliary ?? []).map { item in
            PendingRecipeItem.RecipeIngredientItem(
                name: item.name,
                english: item.english ?? "Side",
                amount: item.amount ?? "适量",
                isEstimated: item.is_estimated ?? false
            )
        }
        
        // 3. 映射调料
        let seasoningsList = (raw.ingredients?.seasonings ?? []).map { item in
            PendingRecipeItem.RecipeSeasoningItem(
                name: item.name,
                english: item.english ?? "Seasoning",
                amount: item.amount ?? "1勺",
                ratio: item.ratio ?? 0.45
            )
        }
        
        // 4. 组装步骤
        var stepItems: [PendingRecipeItem.RecipeStepItem] = []
        for (idx, st) in rawSteps.enumerated() {
            let stepImgData = idx < stepImageDatas.count ? stepImageDatas[idx] : nil
            stepItems.append(PendingRecipeItem.RecipeStepItem(
                number: st.number ?? String(format: "%02d", idx + 1),
                title: st.title ?? "步骤 \(idx + 1)",
                durationBadge: st.duration_badge ?? "▸ 制作工序",
                text: st.text ?? "",
                stepImageData: stepImgData
            ))
        }
        if stepItems.isEmpty {
            stepItems = fallbackSteps(for: raw.name ?? "这道菜", mainIngredients: mainList)
        }
        
        let hasAnyFrameSpec = rawSteps.contains { !($0.frame_spec ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let resolvedIsAIGenerated = raw.is_ai_generated ?? (!hasAnyFrameSpec && (mainList.isEmpty || mainList.allSatisfy { $0.isEstimated }))
        let ingredientCount = mainList.count + auxList.count
        
        return PendingRecipeItem(
            id: existingId ?? UUID().uuidString,
            title: raw.name ?? "精选美味",
            englishTitle: raw.englishName ?? "Gourmet Dish",
            subtitle: raw.subtitle ?? "原汁原味 · 经典可口",
            descriptionText: raw.description ?? "精挑细选的食材搭配，制作流程科学考究。",
            cookingTime: raw.metrics?.time ?? "20m",
            calories: raw.metrics?.calories ?? "630",
            difficulty: raw.metrics?.difficulty ?? "Medium",
            ingredientCount: ingredientCount,
            coverImageData: coverData,
            mainIngredients: mainList,
            auxiliaryIngredients: auxList,
            seasonings: seasoningsList,
            steps: stepItems,
            chefNotes: raw.chefs_notes ?? ["注意火候控制，出锅前翻炒均匀更入味。"],
            sourceTag: sourceTag,
            retryPayload: retryPayload,
            isAIGenerated: resolvedIsAIGenerated
        )
    }
    
    private func buildPendingItemFromPhotos(
        from raw: RawLLMRecipeOutput,
        images: [UIImage],
        sourceTag: String,
        retryPayload: PendingRetryPayload? = nil,
        existingId: String? = nil
    ) -> PendingRecipeItem {
        let coverData = extractPhotoData(spec: raw.cover_frame?.spec, images: images, fallbackIndex: 0)
        
        let mainList = (raw.ingredients?.main ?? []).map { item in
            PendingRecipeItem.RecipeIngredientItem(
                name: item.name,
                english: item.english ?? "Main Cut",
                amount: item.amount ?? "200g",
                isEstimated: item.is_estimated ?? true
            )
        }
        
        let auxList = (raw.ingredients?.auxiliary ?? []).map { item in
            PendingRecipeItem.RecipeIngredientItem(
                name: item.name,
                english: item.english ?? "Side",
                amount: item.amount ?? "适量",
                isEstimated: item.is_estimated ?? true
            )
        }
        
        let seasoningsList = (raw.ingredients?.seasonings ?? []).map { item in
            PendingRecipeItem.RecipeSeasoningItem(
                name: item.name,
                english: item.english ?? "Seasoning",
                amount: item.amount ?? "1勺",
                ratio: item.ratio ?? 0.45
            )
        }
        
        var stepItems: [PendingRecipeItem.RecipeStepItem] = []
        let rawSteps = Array((raw.steps ?? []).prefix(15))
        for (idx, st) in rawSteps.enumerated() {
            let fallbackIdx: Int? = (images.count > 1 && idx + 1 < images.count) ? (idx + 1) : nil
            let stepData = extractPhotoData(spec: st.frame_spec, images: images, fallbackIndex: fallbackIdx)
            stepItems.append(PendingRecipeItem.RecipeStepItem(
                number: st.number ?? String(format: "%02d", idx + 1),
                title: st.title ?? "步骤 \(idx + 1)",
                durationBadge: st.duration_badge ?? "▸ 制作工序",
                text: st.text ?? "",
                stepImageData: stepData
            ))
        }
        if stepItems.isEmpty {
            stepItems = fallbackSteps(for: raw.name ?? "这道菜", mainIngredients: mainList)
        }
        
        let hasAnyFrameSpec = rawSteps.contains { !($0.frame_spec ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let resolvedIsAIGenerated = raw.is_ai_generated ?? (!hasAnyFrameSpec && (mainList.isEmpty || mainList.allSatisfy { $0.isEstimated }))
        let ingredientCount = mainList.count + auxList.count
        
        return PendingRecipeItem(
            id: existingId ?? UUID().uuidString,
            title: raw.name ?? "精选菜谱",
            englishTitle: raw.englishName ?? "Gourmet Dish",
            subtitle: raw.subtitle ?? "色香味俱佳",
            descriptionText: raw.description ?? "精细食材搭配，地道风味传承。",
            cookingTime: raw.metrics?.time ?? "20m",
            calories: raw.metrics?.calories ?? "630",
            difficulty: raw.metrics?.difficulty ?? "Medium",
            ingredientCount: ingredientCount,
            coverImageData: coverData,
            mainIngredients: mainList,
            auxiliaryIngredients: auxList,
            seasonings: seasoningsList,
            steps: stepItems,
            chefNotes: raw.chefs_notes ?? ["掌握好调料下锅顺序，口感更佳。"],
            sourceTag: sourceTag,
            retryPayload: retryPayload,
            isAIGenerated: resolvedIsAIGenerated
        )
    }
    
    private func fallbackSteps(for dishName: String, mainIngredients: [PendingRecipeItem.RecipeIngredientItem]) -> [PendingRecipeItem.RecipeStepItem] {
        let firstMain = mainIngredients.first?.name ?? "主料"
        return [
            PendingRecipeItem.RecipeStepItem(
                number: "01",
                title: "准备与处理食材",
                durationBadge: "▸ 备菜约 5 分钟",
                text: "将\(firstMain)与所需配菜清洗改刀备好，调料按比例提前分装备用。",
                stepImageData: nil
            ),
            PendingRecipeItem.RecipeStepItem(
                number: "02",
                title: "下锅烹制入味",
                durationBadge: "▸ 烹饪约 10 分钟",
                text: "热锅下油，依次放入食材与调味料翻炒或焖煮至熟透入味。",
                stepImageData: nil
            ),
            PendingRecipeItem.RecipeStepItem(
                number: "03",
                title: "收汁装盘出锅",
                durationBadge: "▸ 装盘完成",
                text: "大火收浓汤汁后盛出装盘，即可享用这道「\(dishName)」。",
                stepImageData: nil
            )
        ]
    }
    
    private func extractPhotoData(spec: String?, images: [UIImage], fallbackIndex: Int?) -> Data? {
        guard !images.isEmpty else { return nil }
        var chosenImage: UIImage? = nil
        var roiRect: CGRect? = nil
        
        if let spec = spec?.trimmingCharacters(in: .whitespacesAndNewlines), !spec.isEmpty {
            let mainAndROI = spec.split(separator: "@", maxSplits: 1).map(String.init)
            let specCore = mainAndROI[0]
            if let range = specCore.range(of: #"img_(\d+)"#, options: .regularExpression) {
                let digits = specCore[range].replacingOccurrences(of: "img_", with: "")
                if let oneBased = Int(digits), oneBased >= 1, oneBased <= images.count {
                    chosenImage = images[oneBased - 1]
                }
            }
            if mainAndROI.count == 2 {
                let parts = mainAndROI[1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                if parts.count == 4 {
                    let x = max(0, min(1, parts[0]))
                    let y = max(0, min(1, parts[1]))
                    let w = max(0.05, min(1 - x, parts[2]))
                    let h = max(0.05, min(1 - y, parts[3]))
                    roiRect = CGRect(x: x, y: y, width: w, height: h)
                }
            }
        }
        
        if chosenImage == nil, let fb = fallbackIndex, fb >= 0, fb < images.count {
            chosenImage = images[fb]
        }
        guard let target = chosenImage else { return nil }
        
        if let roi = roiRect, let cg = target.cgImage {
            let pxRect = CGRect(
                x: roi.origin.x * CGFloat(cg.width),
                y: roi.origin.y * CGFloat(cg.height),
                width: roi.size.width * CGFloat(cg.width),
                height: roi.size.height * CGFloat(cg.height)
            ).integral
            if let cropped = cg.cropping(to: pxRect) {
                return UIImage(cgImage: cropped, scale: target.scale, orientation: target.imageOrientation).jpegData(compressionQuality: 0.85)
            }
        }
        return target.jpegData(compressionQuality: 0.85)
    }
    
    private func extractFirstURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first?.url
    }
    
    private enum LinkInspectionResult {
        case video(URL)
        case images([UIImage], contextText: String)
        case webContent(text: String, coverImage: UIImage?)
    }
    
    private func upgradeToHTTPSIfNeeded(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.scheme?.lowercased() == "http" else {
            return url
        }
        comps.scheme = "https"
        return comps.url ?? url
    }
    
    private func stripURLs(from text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let nsRange = NSRange(location: 0, length: text.utf16.count)
        let stripped = detector.stringByReplacingMatches(in: text, options: [], range: nsRange, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func makeBrowserRequest(url: URL, referer: String? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/*,video/*;q=0.8,*/*;q=0.7", forHTTPHeaderField: "Accept")
        req.setValue("zh-CN,zh-Hans;q=0.9", forHTTPHeaderField: "Accept-Language")
        if let referer {
            req.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return req
    }
    
    private func fetchAndInspectLink(_ targetURL: URL) async throws -> LinkInspectionResult {
        let req = makeBrowserRequest(url: targetURL)
        let (data, response) = try await URLSession.shared.data(for: req)
        let mime = response.mimeType?.lowercased() ?? ""
        let finalURL = response.url ?? targetURL
        let ext = finalURL.pathExtension.lowercased()
        
        // 1. 直链视频
        if mime.contains("video") || ext == "mp4" || ext == "mov" || ext == "m4v" {
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("link_download_\(UUID().uuidString).mp4")
            try data.write(to: dest)
            return .video(dest)
        }
        
        // 2. 直链图片
        if mime.contains("image") || ["jpg", "jpeg", "png", "webp", "heic"].contains(ext),
           let img = UIImage(data: data) {
            return .images([img], contextText: "")
        }
        
        // 3. 网页 HTML 解析（小红书 / 抖音 / B站 / 菜谱网页）
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii),
              !html.isEmpty else {
            throw NSError(domain: "LinkParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "未能读取链接页面内容"])
        }
        
        let referer = finalURL.scheme.map { "\($0)://\(finalURL.host ?? "")/" }
        
        // 先提取标题与正文描述（无论图文或纯文都可用于补充上下文）
        let ogTitle = extractFirstMatch(in: html, patterns: [
            #"<meta[^>]+(?:property|name)=["']og:title["'][^>]+content=["']([^"']+)["']"#,
            #"<title[^>]*>([^<]+)</title>"#
        ]) ?? ""
        let ogDesc = extractFirstMatch(in: html, patterns: [
            #"<meta[^>]+(?:property|name)=["'](?:og:description|description)["'][^>]+content=["']([^"']+)["']"#,
            #""desc"\s*:\s*"([^"]{8,})""#
        ]) ?? ""
        let combinedMeta = [ogTitle, ogDesc]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "小红书" && !$0.contains("安全验证") && !$0.contains("你的生活指南") }
            .joined(separator: "\n")
        
        // 3a. 尝试提取视频地址 (og:video / masterUrl / h264)
        if let videoURLString = extractFirstMatch(in: html, patterns: [
            #"<meta[^>]+(?:property|name)=["']og:video["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:video["']"#,
            #""masterUrl"\s*:\s*"([^"]+)""#,
            #"(https?:\\?(?:/|\\u002[fF]){2}[^"'\s<>\\]+\.mp4[^"'\s<>\\]*)"#
        ]), let videoURL = URL(string: upgradeURLString(unescapeJSONURL(videoURLString))) {
            if let (vData, vResp) = try? await URLSession.shared.data(for: makeBrowserRequest(url: videoURL, referer: referer)),
               (vResp as? HTTPURLResponse)?.statusCode ?? 500 < 400,
               vData.count > 10_000 {
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("link_video_\(UUID().uuidString).mp4")
                try vData.write(to: dest)
                return .video(dest)
            }
        }
        
        // 3b. 优先从小红书 imageList / __INITIAL_STATE__ / 多条 og:image 提取完整组图（修复 \u002F 转义与仅取首图问题）
        var rawImageCandidates: [String] = []
        if let imageListChunk = extractFirstMatch(in: html, patterns: [#""imageList"\s*:\s*(\[[\s\S]{10,20000}?\])\s*,\s*"[a-zA-Z_]+""#]) {
            rawImageCandidates.append(contentsOf: extractAllMatches(in: imageListChunk, pattern: #""urlDefault"\s*:\s*"([^"]+)""#))
            rawImageCandidates.append(contentsOf: extractAllMatches(in: imageListChunk, pattern: #""urlPre"\s*:\s*"([^"]+)""#))
            rawImageCandidates.append(contentsOf: extractAllMatches(in: imageListChunk, pattern: #""url"\s*:\s*"([^"]+)""#))
        }
        rawImageCandidates.append(contentsOf: extractAllMatches(in: html, pattern: #""urlDefault"\s*:\s*"([^"]+)""#))
        rawImageCandidates.append(contentsOf: extractAllMatches(in: html, pattern: #""urlPre"\s*:\s*"([^"]+)""#))
        rawImageCandidates.append(contentsOf: extractAllMatches(in: html, pattern: #"<meta[^>]+(?:property|name)=["']og:image["'][^>]+content=["']([^"']+)["']"#))
        rawImageCandidates.append(contentsOf: extractAllMatches(in: html, pattern: #"<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:image["']"#))
        rawImageCandidates.append(contentsOf: extractAllMatches(in: html, pattern: #"(https?:(?:\\/|\\u002[fF]|/){2}[^"'\s<>]*?(?:xhscdn\.com|sns-webpic)[^"'\s<>]*)"#))
        
        var seenAssetKeys = Set<String>()
        var targetImageURLs: [URL] = []
        for rawStr in rawImageCandidates {
            let clean = upgradeURLString(unescapeJSONURL(rawStr))
            guard !clean.isEmpty,
                  !clean.contains("avatar"),
                  !clean.contains("sns-avatar"),
                  !clean.contains("logo"),
                  !clean.contains("fe-platform"),
                  let imgURL = URL(string: clean) else { continue }
            
            // 同一张图在小红书页面中可能同时以 !nd_dft / !nd_prv / ?imageView2 形式出现，按主干路径去重避免重复下载首图
            let baseKey = clean
                .components(separatedBy: "?").first?
                .components(separatedBy: "!").first ?? clean
            guard !seenAssetKeys.contains(baseKey) else { continue }
            seenAssetKeys.insert(baseKey)
            
            targetImageURLs.append(imgURL)
            if targetImageURLs.count >= 12 { break }
        }
        
        if !targetImageURLs.isEmpty {
            let indexedImages = await withTaskGroup(of: (Int, UIImage?).self) { group in
                for (idx, imgURL) in targetImageURLs.enumerated() {
                    let req = makeBrowserRequest(url: imgURL, referer: referer)
                    group.addTask {
                        guard let (imgData, imgResp) = try? await URLSession.shared.data(for: req),
                              (imgResp as? HTTPURLResponse)?.statusCode ?? 500 < 400,
                              let uiImg = UIImage(data: imgData) else {
                            return (idx, nil)
                        }
                        return (idx, uiImg)
                    }
                }
                var results: [(Int, UIImage)] = []
                for await (idx, img) in group {
                    if let img { results.append((idx, img)) }
                }
                return results.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
            
            if !indexedImages.isEmpty {
                return .images(indexedImages, contextText: combinedMeta)
            }
        }
        
        if !combinedMeta.isEmpty {
            return .webContent(text: combinedMeta, coverImage: nil)
        }
        
        throw NSError(domain: "LinkParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "平台触发登录或反爬验证，未获取到图文或视频；请复制带菜名的完整分享文案或保存图片/视频后导入"])
    }
    
    private func unescapeJSONURL(_ s: String) -> String {
        s.replacingOccurrences(of: "\\u002F", with: "/")
            .replacingOccurrences(of: "\\u002f", with: "/")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
    
    private func upgradeURLString(_ s: String) -> String {
        if s.hasPrefix("//") { return "https:" + s }
        if s.hasPrefix("http://") { return "https://" + s.dropFirst(7) }
        return s
    }
    
    private func extractFirstMatch(in text: String, patterns: [String]) -> String? {
        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return nil
    }
    
    private func extractAllMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }
}

