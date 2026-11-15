import Foundation
import SwiftUI
import Combine

/// 待入库菜谱重试原始载荷（用于「重新识别」按钮重跑链路）
public struct PendingRetryPayload: Codable {
    public enum Kind: String, Codable {
        case link
        case video
        case images
        case text
    }
    
    public let kind: Kind
    public let textInput: String?
    public let imageFileNames: [String]?
    public let videoFileName: String?
    public let extraContextText: String?
    public let sourceTag: String
    
    public init(
        kind: Kind,
        textInput: String? = nil,
        imageFileNames: [String]? = nil,
        videoFileName: String? = nil,
        extraContextText: String? = nil,
        sourceTag: String
    ) {
        self.kind = kind
        self.textInput = textInput
        self.imageFileNames = imageFileNames
        self.videoFileName = videoFileName
        self.extraContextText = extraContextText
        self.sourceTag = sourceTag
    }
}

/// 端侧重试素材磁盘缓存（Documents/PendingRetryCache）
public enum PendingRetryStorage {
    private static var cacheDirectory: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("PendingRetryCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public static func saveImages(_ images: [UIImage]) -> [String] {
        guard let dir = cacheDirectory else { return [] }
        let batchId = UUID().uuidString.prefix(8)
        var names: [String] = []
        for (idx, img) in images.enumerated() {
            let name = "retry_img_\(batchId)_\(idx).jpg"
            if let data = img.jpegData(compressionQuality: 0.85) {
                let url = dir.appendingPathComponent(name)
                if (try? data.write(to: url)) != nil {
                    names.append(name)
                }
            }
        }
        return names
    }
    
    public static func loadImages(fileNames: [String]) -> [UIImage] {
        guard let dir = cacheDirectory else { return [] }
        return fileNames.compactMap { name in
            let url = dir.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }
    
    public static func saveVideo(from sourceURL: URL) -> String? {
        guard let dir = cacheDirectory else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let name = "retry_vid_\(UUID().uuidString.prefix(8)).\(ext)"
        let destURL = dir.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return name
        } catch {
            return nil
        }
    }
    
    public static func videoURL(fileName: String) -> URL? {
        guard let dir = cacheDirectory else { return nil }
        let url = dir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    public static func cleanup(payload: PendingRetryPayload?) {
        guard let payload = payload, let dir = cacheDirectory else { return }
        if let names = payload.imageFileNames {
            for name in names {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
            }
        }
        if let videoName = payload.videoFileName {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(videoName))
        }
    }
}

/// 待入库任务状态（支持排队、后台解析、完成、非食物拦截、失败重试）
public enum PendingTaskStatus: String, Codable {
    case queued
    case processing
    case completed
    case nonFood
    case failed
}

/// 待入库菜谱项目（已解析好但尚未选择分类入库的菜单项）
public struct PendingRecipeItem: Identifiable, Codable {
    public let id: String
    public let title: String
    public let englishTitle: String
    public let subtitle: String
    public let descriptionText: String
    public let cookingTime: String
    public let calories: String
    public let difficulty: String
    public let ingredientCount: Int
    public let coverImageData: Data?
    public let mainIngredients: [RecipeIngredientItem]
    public let auxiliaryIngredients: [RecipeIngredientItem]
    public let seasonings: [RecipeSeasoningItem]
    public let steps: [RecipeStepItem]
    public let chefNotes: [String]
    public let createdAt: Date
    public let sourceTag: String
    public let isNotFood: Bool
    public let errorReason: String?
    public let retryPayload: PendingRetryPayload?
    public let isAIGenerated: Bool
    public let status: PendingTaskStatus
    
    public var isPendingOrActive: Bool {
        status == .queued || status == .processing
    }
    
    public struct RecipeIngredientItem: Codable, Identifiable {
        public var id: String { name }
        public let name: String
        public let english: String
        public let amount: String
        public let isEstimated: Bool
    }
    
    public struct RecipeSeasoningItem: Codable, Identifiable {
        public var id: String { name }
        public let name: String
        public let english: String
        public let amount: String
        public let ratio: Double
    }
    
    public struct RecipeStepItem: Codable, Identifiable {
        public var id: String { number }
        public let number: String
        public let title: String
        public let durationBadge: String
        public let text: String
        public let stepImageData: Data?
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        englishTitle: String,
        subtitle: String,
        descriptionText: String,
        cookingTime: String,
        calories: String,
        difficulty: String,
        ingredientCount: Int,
        coverImageData: Data?,
        mainIngredients: [RecipeIngredientItem],
        auxiliaryIngredients: [RecipeIngredientItem],
        seasonings: [RecipeSeasoningItem],
        steps: [RecipeStepItem],
        chefNotes: [String],
        createdAt: Date = Date(),
        sourceTag: String = "AI智能抽取",
        isNotFood: Bool = false,
        errorReason: String? = nil,
        retryPayload: PendingRetryPayload? = nil,
        isAIGenerated: Bool = false,
        status: PendingTaskStatus? = nil
    ) {
        self.id = id
        self.title = title
        self.englishTitle = englishTitle
        self.subtitle = subtitle
        self.descriptionText = descriptionText
        self.cookingTime = cookingTime
        self.calories = calories
        self.difficulty = difficulty
        self.ingredientCount = ingredientCount
        self.coverImageData = coverImageData
        self.mainIngredients = mainIngredients
        self.auxiliaryIngredients = auxiliaryIngredients
        self.seasonings = seasonings
        self.steps = steps
        self.chefNotes = chefNotes
        self.createdAt = createdAt
        self.sourceTag = sourceTag
        self.isNotFood = isNotFood
        self.errorReason = errorReason
        self.retryPayload = retryPayload
        self.isAIGenerated = isAIGenerated
        self.status = status ?? (isNotFood ? .nonFood : .completed)
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        englishTitle = try c.decode(String.self, forKey: .englishTitle)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        descriptionText = try c.decode(String.self, forKey: .descriptionText)
        cookingTime = try c.decode(String.self, forKey: .cookingTime)
        calories = try c.decode(String.self, forKey: .calories)
        difficulty = try c.decode(String.self, forKey: .difficulty)
        ingredientCount = try c.decode(Int.self, forKey: .ingredientCount)
        coverImageData = try c.decodeIfPresent(Data.self, forKey: .coverImageData)
        mainIngredients = try c.decode([RecipeIngredientItem].self, forKey: .mainIngredients)
        auxiliaryIngredients = try c.decode([RecipeIngredientItem].self, forKey: .auxiliaryIngredients)
        seasonings = try c.decode([RecipeSeasoningItem].self, forKey: .seasonings)
        steps = try c.decode([RecipeStepItem].self, forKey: .steps)
        chefNotes = try c.decode([String].self, forKey: .chefNotes)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        sourceTag = try c.decode(String.self, forKey: .sourceTag)
        isNotFood = try c.decodeIfPresent(Bool.self, forKey: .isNotFood) ?? false
        errorReason = try c.decodeIfPresent(String.self, forKey: .errorReason)
        retryPayload = try c.decodeIfPresent(PendingRetryPayload.self, forKey: .retryPayload)
        isAIGenerated = try c.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
        let decodedNotFood = isNotFood
        status = try c.decodeIfPresent(PendingTaskStatus.self, forKey: .status) ?? (decodedNotFood ? .nonFood : .completed)
    }
    
    public func withStatus(_ newStatus: PendingTaskStatus, errorReason: String? = nil) -> PendingRecipeItem {
        PendingRecipeItem(
            id: id,
            title: title,
            englishTitle: englishTitle,
            subtitle: errorReason ?? subtitle,
            descriptionText: errorReason ?? descriptionText,
            cookingTime: cookingTime,
            calories: calories,
            difficulty: difficulty,
            ingredientCount: ingredientCount,
            coverImageData: coverImageData,
            mainIngredients: mainIngredients,
            auxiliaryIngredients: auxiliaryIngredients,
            seasonings: seasonings,
            steps: steps,
            chefNotes: chefNotes,
            createdAt: createdAt,
            sourceTag: sourceTag,
            isNotFood: newStatus == .nonFood,
            errorReason: errorReason ?? self.errorReason,
            retryPayload: retryPayload,
            isAIGenerated: isAIGenerated,
            status: newStatus
        )
    }
}

/// 待入库菜单队列管理器（单例，负责队列维护、持久化及入库转正操作）
@MainActor
public final class PendingRecipeQueueManager: ObservableObject {
    public static let shared = PendingRecipeQueueManager()
    
    @Published public private(set) var pendingItems: [PendingRecipeItem] = []
    
    public var badgeCount: Int {
        pendingItems.count
    }
    
    private let storageKey = "com.mealcoll.pending_recipe_queue"
    
    private init() {
        loadPersistedQueue()
        if pendingItems.count < 3 {
            seedSamplePendingIfFirstLaunch()
        }
    }
    
    // MARK: - Queue Actions
    public func enqueue(_ item: PendingRecipeItem) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            pendingItems.insert(item, at: 0)
        }
        persistQueue()
        
        // 自动将结构化数据同步至用户的 iCloud 私有数据库
        if let encoded = try? JSONEncoder().encode(item),
           let jsonStr = String(data: encoded, encoding: .utf8) {
            CloudKitConfigManager.shared.saveRecipeToPrivateCloud(recipeId: item.id, recipeJsonString: jsonStr)
        }
    }
    
    public func replaceItem(id: String, with newItem: PendingRecipeItem) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            if let idx = pendingItems.firstIndex(where: { $0.id == id }) {
                pendingItems[idx] = newItem
            } else {
                pendingItems.insert(newItem, at: 0)
            }
        }
        persistQueue()
    }
    
    public func updateItemStatus(id: String, status: PendingTaskStatus, errorReason: String? = nil) {
        guard let idx = pendingItems.firstIndex(where: { $0.id == id }) else { return }
        pendingItems[idx] = pendingItems[idx].withStatus(status, errorReason: errorReason)
        persistQueue()
    }
    
    public func nextQueuedItem() -> PendingRecipeItem? {
        pendingItems.last(where: { $0.status == .queued })
    }
    
    public func remove(byId id: String) {
        if let target = pendingItems.first(where: { $0.id == id }) {
            PendingRetryStorage.cleanup(payload: target.retryPayload)
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            pendingItems.removeAll(where: { $0.id == id })
        }
        persistQueue()
    }
    
    /// 按类别正式入库加入用户的菜单库
    public func commitToCategory(item: PendingRecipeItem, categoryId: String) {
        // 1. 保存封面图到本地以供 Dish 显示
        var resolvedImageName = "dish_kungpao"
        if let data = item.coverImageData,
           UIImage(data: data) != nil {
            let fileName = "custom_dish_\(item.id).jpg"
            if let fileURL = getDocumentsDirectory()?.appendingPathComponent(fileName),
               (try? data.write(to: fileURL)) != nil {
                resolvedImageName = fileName
            }
        }
        
        // 2. 收集食材名字与完整结构化主料/辅料/调料/步骤，并自动按映射表匹配食材图片资源
        let allIngNames = item.mainIngredients.map(\.name) + item.auxiliaryIngredients.map(\.name)
        let customMains: [DishIngredientItem] = item.mainIngredients.map { ing in
            let imgName = Dish.resolveIngredientIcon(name: ing.name, category: .main)
            return DishIngredientItem(name: ing.name, english: ing.english, amount: ing.amount, imageName: imgName)
        }
        let customAux: [DishIngredientItem] = item.auxiliaryIngredients.map { ing in
            let imgName = Dish.resolveIngredientIcon(name: ing.name, category: .auxiliary)
            return DishIngredientItem(name: ing.name, english: ing.english, amount: ing.amount, imageName: imgName)
        }
        let palette: [UInt] = [0x5C3A28, 0xE0A314, 0x5E8C31, 0x544E49]
        let customSeasonings: [DishSeasoningItem] = item.seasonings.enumerated().map { idx, s in
            DishSeasoningItem(
                name: s.name,
                english: s.english,
                amount: s.amount,
                ratio: s.ratio,
                colorHex: palette[idx % palette.count]
            )
        }
        let customSteps: [DishStepItem] = item.steps.map { step in
            var stepImageName = resolvedImageName
            if let stepData = step.stepImageData, UIImage(data: stepData) != nil {
                let fileName = "custom_dish_\(item.id)_step_\(step.number).jpg"
                if let fileURL = getDocumentsDirectory()?.appendingPathComponent(fileName),
                   (try? stepData.write(to: fileURL)) != nil {
                    stepImageName = fileName
                }
            }
            return DishStepItem(number: step.number, text: step.text, imageName: stepImageName)
        }
        
        // 3. 构建标准 Dish 对象
        let newDish = Dish(
            id: "dish_\(item.id.prefix(8))",
            name: item.title,
            englishName: item.englishTitle,
            categoryId: categoryId,
            imageName: resolvedImageName,
            subtitle: item.subtitle,
            description: item.descriptionText,
            tag: item.sourceTag,
            rating: 5.0,
            cookingTime: item.cookingTime.contains("m") ? item.cookingTime.replacingOccurrences(of: "m", with: "分钟") : item.cookingTime,
            calories: item.calories.contains("大卡") ? item.calories : "\(item.calories)大卡",
            ingredients: allIngNames,
            flavor: "家常鲜香",
            customMainIngredients: customMains.isEmpty ? nil : customMains,
            customAuxiliaryIngredients: customAux.isEmpty ? nil : customAux,
            customSeasonings: customSeasonings.isEmpty ? nil : customSeasonings,
            customSteps: customSteps.isEmpty ? nil : customSteps,
            customChefNotes: item.chefNotes.isEmpty ? nil : item.chefNotes,
            customDifficulty: item.difficulty,
            isAIGenerated: item.isAIGenerated
        )
        
        // 4. 正式录入 RecipeDataManager
        RecipeDataManager.shared.addDish(newDish, toCategoryId: categoryId)
        
        // 5. 从待入库队列中安全移除
        remove(byId: item.id)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // MARK: - Persistence
    private var queueFileURL: URL? {
        getDocumentsDirectory()?.appendingPathComponent("pending_recipe_queue.json")
    }
    
    private func persistQueue() {
        guard let url = queueFileURL,
              let data = try? JSONEncoder().encode(pendingItems) else { return }
        try? data.write(to: url, options: .atomic)
    }
    
    private func loadPersistedQueue() {
        if let url = queueFileURL,
           let data = try? Data(contentsOf: url),
           let items = try? JSONDecoder().decode([PendingRecipeItem].self, from: data) {
            self.pendingItems = items.map { $0.status == .processing ? $0.withStatus(.queued) : $0 }
            return
        }
        // 兼容迁移旧版 UserDefaults 缓存，避免大图片超出 UserDefaults 4MB 限制引发崩溃
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([PendingRecipeItem].self, from: data) {
            self.pendingItems = items.map { $0.status == .processing ? $0.withStatus(.queued) : $0 }
            persistQueue()
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
    
    private func getDocumentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private func seedSamplePendingIfFirstLaunch() {
        let sample1 = PendingRecipeItem(
            id: "sample_pending_01",
            title: "西北番茄牛肉炒面片",
            englishTitle: "Northwestern Stir-Fried Dough Drops",
            subtitle: "劲道爽滑 · 茄汁浓郁挂汁",
            descriptionText: "精选筋道面片现揪现煮，牛里脊薄切上浆锁水，大火爆出红油辣香，配以鲜番茄熬出的浓厚原汁，面片吸饱汤汁，酸辣咸香过瘾。",
            cookingTime: "20m",
            calories: "630",
            difficulty: "Medium",
            ingredientCount: 6,
            coverImageData: nil,
            mainIngredients: [
                .init(name: "面片坯", english: "Dough Drops", amount: "250g", isEstimated: true),
                .init(name: "牛里脊", english: "Beef Tenderloin", amount: "200g", isEstimated: true)
            ],
            auxiliaryIngredients: [
                .init(name: "西红柿", english: "Tomato", amount: "2个", isEstimated: false),
                .init(name: "洋葱", english: "Onion", amount: "半个", isEstimated: false),
                .init(name: "青椒", english: "Green Pepper", amount: "1个", isEstimated: false),
                .init(name: "葱姜蒜", english: "Aromatics", amount: "适量", isEstimated: false)
            ],
            seasonings: [
                .init(name: "生抽", english: "Light soy sauce", amount: "2勺", ratio: 0.80),
                .init(name: "老抽", english: "Dark soy sauce", amount: "1勺", ratio: 0.45),
                .init(name: "辣椒面", english: "Chili flakes", amount: "1勺", ratio: 0.45),
                .init(name: "白胡椒、十三香", english: "White pepper, spices", amount: "适量", ratio: 0.20)
            ],
            steps: [
                .init(number: "01", title: "牛肉切片抓拌上浆", durationBadge: "▸ 腌制 15 分钟", text: "牛里脊逆纹切薄片，加入生抽、老抽、白胡椒抓匀，淋食用油锁水腌制。", stepImageData: nil),
                .init(number: "02", title: "沸水揪面片过凉", durationBadge: "▸ 水开揪面", text: "锅中水沸腾后揪入面片，大火煮熟后捞出过凉水沥干备用。", stepImageData: nil),
                .init(number: "03", title: "大火滑炒牛肉变色", durationBadge: "▸ 热油滑炒", text: "起锅烧油放入腌好的牛肉，快速大火翻炒至变色立即控油盛出。", stepImageData: nil),
                .init(number: "04", title: "爆香料头炒红油", durationBadge: "▸ 爆出香味", text: "锅留底油放入葱姜蒜末爆香，加入一大勺上色辣椒面翻炒出诱人红油。", stepImageData: nil),
                .init(number: "05", title: "煸炒番茄熬出浓汤", durationBadge: "▸ 熬出茄汁", text: "倒入去皮西红柿丁大火翻炒，熬出浓郁沙沙汤汁。", stepImageData: nil),
                .init(number: "06", title: "下入配菜综合调味", durationBadge: "▸ 复合调味", text: "放入洋葱与青椒，加入生抽、老抽调味翻炒均匀。", stepImageData: nil),
                .init(number: "07", title: "面片回锅裹匀收汁", durationBadge: "▸ 翻炒出锅", text: "倒入沥干的面片与牛肉，大火快速翻炒裹匀汤汁盛盘。", stepImageData: nil)
            ],
            chefNotes: [
                "面片切忌煮过头，大火煮至八分熟断生捞出过冷水，炒制时才筋道耐嚼不易坨烂。",
                "西红柿去皮切小丁，先加少许盐大火煸出浓郁沙汁，再下面片吸收原汁最入味。"
            ],
            sourceTag: "小红书爆款"
        )
        
        let sample2 = PendingRecipeItem(
            id: "sample_pending_02",
            title: "蒜香柠檬黄油三文鱼",
            englishTitle: "Garlic Butter Pan-Seared Salmon",
            subtitle: "表皮焦脆 · 内里鲜嫩多汁",
            descriptionText: "厚切三文鱼菲力双面煎至焦香金黄，融化浓醇黄油与大蒜碎激发出复合焦香，挤入新鲜柠檬汁提亮果香，鱼肉鲜嫩甘美，拌饭一绝。",
            cookingTime: "15m",
            calories: "480",
            difficulty: "Easy",
            ingredientCount: 5,
            coverImageData: nil,
            mainIngredients: [
                .init(name: "三文鱼厚切", english: "Salmon Fillet", amount: "220g", isEstimated: true),
                .init(name: "香米米饭", english: "Steamed Rice", amount: "1碗", isEstimated: false)
            ],
            auxiliaryIngredients: [
                .init(name: "黄柠檬", english: "Lemon", amount: "半个", isEstimated: false),
                .init(name: "大蒜", english: "Garlic Cloves", amount: "4瓣", isEstimated: false),
                .init(name: "新鲜迷迭香", english: "Rosemary", amount: "1枝", isEstimated: false)
            ],
            seasonings: [
                .init(name: "无盐黄油", english: "Butter", amount: "15g", ratio: 0.45),
                .init(name: "生抽", english: "Light soy sauce", amount: "1勺", ratio: 0.45),
                .init(name: "现磨黑胡椒", english: "Black Pepper", amount: "适量", ratio: 0.20),
                .init(name: "海盐", english: "Sea Salt", amount: "适量", ratio: 0.20)
            ],
            steps: [
                .init(number: "01", title: "三文鱼吸干水分腌制", durationBadge: "▸ 吸水腌制 5m", text: "三文鱼用厨房纸吸干表面水分，两面均匀撒上海盐和现磨黑胡椒。", stepImageData: nil),
                .init(number: "02", title: "热锅小火慢煎鱼皮", durationBadge: "▸ 煎出脆皮", text: "平底锅烧热倒少许橄榄油，鱼皮朝下中火慢煎3分钟至焦脆金黄。", stepImageData: nil),
                .init(number: "03", title: "翻面下入黄油蒜香", durationBadge: "▸ 淋油浇灌", text: "翻面继续煎制，下入黄油、拍扁蒜瓣和迷迭香，用勺子不断舀起融化的黄油浇在鱼肉上。", stepImageData: nil),
                .init(number: "04", title: "挤入柠檬汁提香装盘", durationBadge: "▸ 锁汁出锅", text: "关火前挤入半个柠檬汁，淋入生抽快速摇匀，搭配热米饭摆盘享用。", stepImageData: nil)
            ],
            chefNotes: [
                "三文鱼表面水分一定要彻底吸干，煎制时鱼皮才能迅速起脆且不破皮。",
                "黄油发烟点低，一定要在鱼肉快煎好时再下锅淋油增香，防止蒜蓉发苦发黑。"
            ],
            sourceTag: "抖音精选"
        )
        
        let sample3 = PendingRecipeItem(
            id: "sample_pending_03",
            title: "地道川味宫保鸡丁",
            englishTitle: "Traditional Kung Pao Chicken",
            subtitle: "红亮糊辣 · 荔枝酸甜微麻",
            descriptionText: "川菜二十四味型之糊辣荔枝味典范。精选滑嫩琵琶腿肉切丁上浆，慢火炸香干辣椒与汉源大红袍花椒，滑入鸡丁与大葱白段，复合糖醋汁急火快炒出锅。",
            cookingTime: "25m",
            calories: "660",
            difficulty: "Chef",
            ingredientCount: 6,
            coverImageData: nil,
            mainIngredients: [
                .init(name: "琵琶鸡腿肉", english: "Chicken Thigh", amount: "300g", isEstimated: true),
                .init(name: "油酥花生米", english: "Fried Peanuts", amount: "60g", isEstimated: false)
            ],
            auxiliaryIngredients: [
                .init(name: "大葱白段", english: "Scallion Stalks", amount: "2根", isEstimated: false),
                .init(name: "剪段干辣椒", english: "Dried Chili", amount: "15g", isEstimated: false),
                .init(name: "汉源大红袍花椒", english: "Sichuan Pepper", amount: "1小撮", isEstimated: false),
                .init(name: "蒜片姜片", english: "Ginger & Garlic", amount: "适量", isEstimated: false)
            ],
            seasonings: [
                .init(name: "保宁醋", english: "Sichuan Vinegar", amount: "2勺", ratio: 0.80),
                .init(name: "白砂糖", english: "Sugar", amount: "2勺", ratio: 0.80),
                .init(name: "生抽", english: "Light soy sauce", amount: "1勺", ratio: 0.45),
                .init(name: "水淀粉", english: "Starch Water", amount: "1勺", ratio: 0.45),
                .init(name: "熟菜籽油", english: "Rapeseed Oil", amount: "适量", ratio: 0.20)
            ],
            steps: [
                .init(number: "01", title: "鸡腿剔骨切丁上浆", durationBadge: "▸ 上浆抓匀 10m", text: "鸡腿肉改刀切成1.5cm见方小丁，加入料酒、生抽、水淀粉充分抓至起黏，封油备用。", stepImageData: nil),
                .init(number: "02", title: "调制经典宫保味汁", durationBadge: "▸ 调配味汁", text: "碗中加入保宁醋2勺、白糖2勺、生抽1勺、少许盐、淀粉和鲜汤，调匀成荔枝味碗汁。", stepImageData: nil),
                .init(number: "03", title: "文火炸香辣椒花椒", durationBadge: "▸ 炝出糊辣香", text: "锅入菜籽油烧至五成热，下入干辣椒段与花椒，小火文火慢炝至红棕色棕红油亮。", stepImageData: nil),
                .init(number: "04", title: "下入鸡丁快速滑散", durationBadge: "▸ 大火滑炒", text: "转大火倒入鸡丁，快速推散滑炒至八成熟变白断生。", stepImageData: nil),
                .init(number: "05", title: "下入大葱泼入味汁", durationBadge: "▸ 急火翻炒", text: "加入葱白段与姜蒜片爆香，烹入调好的宫保味汁，大火推匀收汁亮油。", stepImageData: nil),
                .init(number: "06", title: "下花生米出锅装盘", durationBadge: "▸ 翻匀出锅", text: "最后撒入香脆油酥花生米，快速颠翻两下出锅，花生保持香脆。", stepImageData: nil)
            ],
            chefNotes: [
                "宫保味型关键在糖醋配比，醋糖比例严格掌握在 1:1，酸甜醇厚不抢糊辣风味。",
                "花生米必须在关火临出锅那一刻撒入，颠锅两次立刻装盘，防止被热汤浸软失脆。"
            ],
            sourceTag: "经典川味"
        )
        
        self.pendingItems = [sample1, sample2, sample3]
        persistQueue()
    }
}
