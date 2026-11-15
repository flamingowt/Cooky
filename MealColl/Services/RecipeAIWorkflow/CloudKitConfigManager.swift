import Foundation
import CloudKit
import Combine

/// 全局 App 配置模型（支持 CloudKit 公共数据库热更新）
public struct AppCloudConfig: Codable {
    public var llmEndpoint: String
    public var llmApiKey: String
    public var llmModelName: String
    public var promptVersion: String
    public var promptTemplate: String
    public var linkParsingRules: [String: String]
    public var enablePureFoodInference: Bool
    public var maxSamplingFrames: Int
    
    public static let `default` = AppCloudConfig(
        llmEndpoint: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        llmApiKey: (Bundle.main.object(forInfoDictionaryKey: "ARK_API_KEY") as? String)
            ?? ProcessInfo.processInfo.environment["ARK_API_KEY"]
            ?? "",
        llmModelName: "doubao-seed-2-1-lite-260915",
        promptVersion: "2026.11.v5",
        promptTemplate: """
# Role
你是一位精通中西方烹饪与烘焙工艺的美食主编兼视觉导演，同时具备出版级印前质检能力。请结合输入的「素材时序网格图」与「逐秒 OCR 时间轴日志」，提取并规整出一份符合手机 App 极致排版的标准菜谱 JSON。

# Core Rules & Task Guidelines
## 0. 【前置守门】输入内容属性判断
- 首先必须判断输入内容是否为「食物 / 烹饪 / 菜谱相关」：
  - 若判定为「非食物类」（如风景、穿搭、数码、宠物搞笑、纯日常记录、人物自拍等与饮食或烹饪无关的内容）：
    - 严格仅输出纯 JSON：{"category": "非食物", "reason": "简短说明原因，15~25字，例如：内容为宠物日常照片，未包含食物或菜谱信息"}，流程立即终止。
  - 若判定为「食物类」，继续执行下方任务。

## 1. 真实工序自然切分（按实际过程划分，不超过 15 步）
- 输入图片按 `#01 图`、`#02 图`... 编号排列（视频关键帧按时间轴 `0.6`、`8.5` 标注）。
- 步骤数量根据实际烹饪过程自然划分：原则是能说清楚做的过程、不遗漏关键步骤，但最多不超过 15 步（简单快手菜可 3~5 步，复杂菜肴 6~15 步，严禁超过 15 步）。
- 场景 A（输入中已包含制作过程或文字步骤）：
  - 严格将 "is_ai_generated" 设为 false；
  - 按客观时序切分工序，每步选取动作清晰的关键帧 frame_spec；图片模式格式为 `step01:img_02@0.10,0.20,0.80,0.65`（或仅 `step01:img_02`），视频模式格式为 `step01:8.5@0.10,0.20,0.80,0.65`。
- 场景 B（输入中不包含制作步骤，例如用户仅拍了一张成品菜/食材照片，或只有菜名没有做法）：
  - 严格将 "is_ai_generated" 设为 true；
  - 识别画面中的菜品或食材后，结合自身烹饪专业知识补充完整、具体、可落地的文字制作步骤（不超过 15 步）；
  - 步骤无需配图，每步的 frame_spec 直接置空传空字符串 ""；
  - 所有食材用量标记为估算："is_estimated": true；
  - 封面图 cover_frame 选用成品优质图片，图片模式 spec 格式为 `cover_main:img_01@x,y,w,h` 或 `cover_main:img_01`。
- 每步必须包含：number("01", "02"...), title(≤12字), duration_badge, text, frame_spec。
- 🚫【去掉原片要点】：步骤中不要输出任何 tip 提示。

## 2. 原片未提及信息常识估算法则
- 难度：Easy / Medium / Chef
- 时间：纯快炒 10m/15m，腌制加炒 20m/25m，大菜慢炖 35m+
- 热量卡路里：清爽 350~450，荤素面食 550~680，重油 750~900
- 用量标识：真实提取 "is_estimated": false，估算 "is_estimated": true 并标注类似 "/ 200g (估)"。

## 3. 严厉禁令
- 🚫【禁止脑补食材】：未出现、未使用的食材严禁捏造添加！
- 🚫【不要抽取 Rating】：禁止输出 rating 相关字段。

## 4. 食材数量与调料配比量化铁律
- 📐 食材数量 (metrics.ingredient_count)：严格等于「主料品类数 + 辅料品类数」（绝不包含调料）！
- 📏 调料配比严格量化对齐 (ratio 0.10 ~ 1.00)：
  - 不要输出任何颜色字段，系统统一赋予固定颜色；
  - 同一单位勺数长度必须一致：适量/少许=0.20，1勺=0.45，2勺=0.80，3勺及以上=1.00。

## 5. 主厨复盘 (Chef's Notes)
提炼 2~3 条实用建议。

# Output JSON Format (仅输出纯 JSON)
{
  "is_ai_generated": false,
  "name": "菜谱中文名",
  "englishName": "English Name",
  "subtitle": "一句话卖点副标题",
  "description": "菜品风味故事与口感详述 (约80-120字)",
  "cover_frame": { "spec": "cover_main:0.6", "description": "装盘成品镜头" },
  "metrics": {
    "difficulty": "Medium",
    "time": "20m",
    "ingredient_count": 6,
    "calories": "630"
  },
  "ingredients": {
    "main": [ { "name": "面片坯", "english": "Dough Drops", "amount": "250g", "is_estimated": true } ],
    "auxiliary": [ { "name": "西红柿", "english": "Tomato", "amount": "2个", "is_estimated": false } ],
    "seasonings": [ { "name": "生抽", "english": "Light soy sauce", "amount": "2勺", "ratio": 0.80 } ]
  },
  "steps": [
    {
      "number": "01",
      "title": "牛肉切片抓拌上浆",
      "duration_badge": "▸ 腌制 15 分钟 (00:04 - 00:10)",
      "text": "牛里脊逆纹切薄片，加入生抽抓匀，淋食用油锁水腌制。",
      "frame_spec": "step01:8.5@0.10,0.20,0.80,0.65"
    }
  ],
  "chefs_notes": [ "面片切忌煮过头，大火煮至八分熟断生捞出过冷水。" ]
}
""",
        linkParsingRules: [
            "xhs": "xiaohongshu.com,xhslink.com",
            "douyin": "douyin.com,v.douyin.com",
            "bilibili": "b23.tv,bilibili.com"
        ],
        enablePureFoodInference: true,
        maxSamplingFrames: 50
    )
}

/// CloudKit 配置与同步中枢
public final class CloudKitConfigManager: ObservableObject {
    public static let shared = CloudKitConfigManager()
    
    // 热更新配置
    @Published public private(set) var activeConfig: AppCloudConfig = .default
    @Published public private(set) var lastFetchDate: Date? = nil
    @Published public private(set) var isCloudKitAvailable: Bool = false
    
    private let publicDatabase: CKDatabase?
    private let privateDatabase: CKDatabase?
    private let localConfigKey = "com.mealcoll.app_cloud_config_cache"
    
    /// 当前工程未配置 iCloud/CloudKit Entitlement 时直接跳过 CKContainer，避免 iOS 抛出 SIGTRAP 闪退
    /// 注意：ubiquityIdentityToken 仅反映系统是否登录 iCloud，不能代表当前 App 拥有 CloudKit 权限
    private static let hasCloudKitEntitlement = false
    
    private init() {
        if Self.hasCloudKitEntitlement {
            let container = CKContainer.default()
            self.publicDatabase = container.publicCloudDatabase
            self.privateDatabase = container.privateCloudDatabase
        } else {
            self.publicDatabase = nil
            self.privateDatabase = nil
        }
        
        loadLocalCache()
        if Self.hasCloudKitEntitlement {
            checkAccountStatusAndFetch()
        }
    }
    
    // MARK: - 1. 全局配置热更新 (Public Database)
    /// App 启动时异步从 CloudKit 公共数据库拉取配置
    public func fetchLatestRemoteConfig() {
        guard let publicDatabase else { return }
        let recordID = CKRecord.ID(recordName: "GlobalAppConfigRecord")
        
        publicDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else { return }
            if let error = error {
                print("⚠️ [CloudKit] Public config fetch fallback to local: \(error.localizedDescription)")
                return
            }
            
            guard let record = record else { return }
            
            DispatchQueue.main.async {
                var config = self.activeConfig
                if let endpoint = record["llmEndpoint"] as? String, !endpoint.isEmpty {
                    config.llmEndpoint = endpoint
                }
                if let apiKey = record["llmApiKey"] as? String, !apiKey.isEmpty {
                    config.llmApiKey = apiKey
                }
                if let model = record["llmModelName"] as? String, !model.isEmpty {
                    config.llmModelName = model
                }
                if let version = record["promptVersion"] as? String, !version.isEmpty {
                    config.promptVersion = version
                }
                if let template = record["promptTemplate"] as? String, !template.isEmpty {
                    config.promptTemplate = template
                }
                if let pureInference = record["enablePureFoodInference"] as? Int64 {
                    config.enablePureFoodInference = (pureInference == 1)
                }
                
                self.activeConfig = config
                self.lastFetchDate = Date()
                self.saveLocalCache(config)
                print("✅ [CloudKit] Successfully fetched hot config, prompt version: \(config.promptVersion)")
            }
        }
    }
    
    // MARK: - 2. 菜谱私有数据库存储 (Private Database)
    /// 保存生成的菜谱结构化数据与历史记录至私有数据库，绑定用户个人 iCloud
    public func saveRecipeToPrivateCloud(recipeId: String, recipeJsonString: String, completion: ((Bool) -> Void)? = nil) {
        guard let privateDatabase else {
            completion?(false)
            return
        }
        let record = CKRecord(recordType: "UserRecipeRecord", recordID: CKRecord.ID(recordName: recipeId))
        record["recipeId"] = recipeId as CKRecordValue
        record["recipeData"] = recipeJsonString as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                print("⚠️ [CloudKit Private] Failed to sync user recipe: \(error.localizedDescription)")
                completion?(false)
            } else {
                print("☁️ [CloudKit Private] Synced recipe \(recipeId) to user's iCloud")
                completion?(true)
            }
        }
    }
    
    // MARK: - Internal Helpers
    private func checkAccountStatusAndFetch() {
        CKContainer.default().accountStatus { [weak self] status, _ in
            DispatchQueue.main.async {
                self?.isCloudKitAvailable = (status == .available)
                self?.fetchLatestRemoteConfig()
            }
        }
    }
    
    private func loadLocalCache() {
        if let data = UserDefaults.standard.data(forKey: localConfigKey),
           let cached = try? JSONDecoder().decode(AppCloudConfig.self, from: data) {
            // Migrate stale OpenAI empty-key defaults or closed Doubao snapshot to active Doubao config
            let isStale = cached.llmApiKey.isEmpty
                || cached.llmEndpoint.contains("api.openai.com")
                || cached.llmModelName == "doubao-seed-2-0-lite-260215"
                || cached.llmModelName == "doubao-seed-2-0-lite-260428"
                || cached.promptVersion != AppCloudConfig.default.promptVersion
            if isStale {
                self.activeConfig = AppCloudConfig.default
                saveLocalCache(AppCloudConfig.default)
            } else {
                self.activeConfig = cached
            }
        }
    }
    
    private func saveLocalCache(_ config: AppCloudConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: localConfigKey)
        }
    }
}

