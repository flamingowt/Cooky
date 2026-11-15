import Foundation
import SwiftUI
import UIKit

public struct DishIngredientItem: Hashable, Codable {
    public let name: String
    public let english: String
    public let amount: String
    public let imageName: String
    
    public init(name: String, english: String, amount: String, imageName: String) {
        self.name = name
        self.english = english
        self.amount = amount
        self.imageName = imageName
    }
}

public struct DishSeasoningItem: Hashable, Codable {
    public let name: String
    public let english: String
    public let amount: String
    public let ratio: Double
    public let colorHex: UInt
    
    public init(name: String, english: String, amount: String, ratio: Double, colorHex: UInt) {
        self.name = name
        self.english = english
        self.amount = amount
        self.ratio = ratio
        self.colorHex = colorHex
    }
}

public struct DishStepItem: Hashable, Codable {
    public let number: String
    public let text: String
    public let imageName: String
    
    public init(number: String, text: String, imageName: String) {
        self.number = number
        self.text = text
        self.imageName = imageName
    }
}

public enum DishImageLoader {
    public static func uiImage(for name: String) -> UIImage? {
        if let asset = UIImage(named: name) {
            return asset
        }
        if name.hasPrefix("/"), let fileImg = UIImage(contentsOfFile: name) {
            return fileImg
        }
        let fileName = (name as NSString).lastPathComponent
        if !fileName.isEmpty,
           let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let candidate = docs.appendingPathComponent(fileName).path
            if let docImg = UIImage(contentsOfFile: candidate) {
                return docImg
            }
        }
        return nil
    }
}

public struct DishImageView: View {
    public let name: String
    
    public init(_ name: String) {
        self.name = name
    }
    
    public var body: some View {
        if let uiImg = DishImageLoader.uiImage(for: name) {
            Image(uiImage: uiImg)
                .resizable()
        } else {
            Image(name)
                .resizable()
        }
    }
}

/// 统一食材缩略图：优先按映射表哈希匹配已入库食材图，暂无素材时以极简文字卡片代替
public struct IngredientThumbnailView: View {
    public let name: String
    public let imageName: String
    public let size: CGFloat
    public let cornerRadius: CGFloat
    public let fillHeight: CGFloat?
    public let isSquareFill: Bool
    
    public init(name: String, imageName: String, size: CGFloat = 44, cornerRadius: CGFloat = 10, fillHeight: CGFloat? = nil, isSquareFill: Bool = false) {
        self.name = name
        self.imageName = imageName
        self.size = size
        self.cornerRadius = cornerRadius
        self.fillHeight = fillHeight
        self.isSquareFill = isSquareFill
    }
    
    private var shortLabel: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 2 { return trimmed }
        return String(trimmed.prefix(2))
    }
    
    @ViewBuilder
    private var fillContent: some View {
        if !imageName.isEmpty, let uiImg = DishImageLoader.uiImage(for: imageName) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(red: 0.945, green: 0.941, blue: 0.922)
                Text(shortLabel.isEmpty ? "料" : shortLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.22, green: 0.22, blue: 0.22))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
        }
    }
    
    public var body: some View {
        if isSquareFill {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { fillContent }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else if let targetHeight = fillHeight {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: targetHeight)
                .overlay { fillContent }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else if !imageName.isEmpty, let uiImg = DishImageLoader.uiImage(for: imageName) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.925, green: 0.925, blue: 0.915))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
                Text(shortLabel.isEmpty ? "料" : shortLabel)
                    .font(.system(size: size >= 46 ? 13 : 11.5, weight: .bold))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, 3)
            }
            .frame(width: size, height: size)
        }
    }
}

public struct Dish: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let englishName: String
    public let categoryId: String
    public let imageName: String
    public let subtitle: String
    public let description: String
    public let tag: String
    public let rating: Double
    public let cookingTime: String
    public let calories: String
    public let ingredients: [String]
    public let flavor: String
    public let customMainIngredients: [DishIngredientItem]?
    public let customAuxiliaryIngredients: [DishIngredientItem]?
    public let customSeasonings: [DishSeasoningItem]?
    public let customSteps: [DishStepItem]?
    public let customChefNotes: [String]?
    public let customDifficulty: String?
    public let isAIGenerated: Bool
    
    /// 烹饪难度 Tag (中英文)
    public var difficulty: String {
        if let customDifficulty, !customDifficulty.isEmpty {
            switch customDifficulty.lowercased() {
            case "easy", "简单": return "简单"
            case "medium", "适中": return "适中"
            case "chef", "进阶": return "进阶"
            default: return customDifficulty
            }
        }
        switch cookingTime {
        case let t where t.contains("10") || t.contains("12") || t.contains("15"):
            return "简单"
        case let t where t.contains("18") || t.contains("20") || t.contains("25"):
            return "适中"
        default:
            return "进阶"
        }
    }
    
    public var difficultyEnglish: String {
        switch difficulty {
        case "简单": return "Easy"
        case "适中": return "Medium"
        default: return "Chef"
        }
    }
    
    /// 简短时间展示（如 25m）
    public var shortTime: String {
        let digits = cookingTime.filter { $0.isNumber }
        return digits.isEmpty ? "20m" : "\(digits)m"
    }
    
    /// 纯数字卡路里（如 730）
    public var caloriesNumber: String {
        let digits = calories.filter { $0.isNumber }
        return digits.isEmpty ? "580" : digits
    }
    
    /// 食材总数量（主料 + 辅料 + 调料）
    public var totalIngredientCount: Int {
        mainIngredientItems.count + auxiliaryIngredientItems.count + seasoningItems.count
    }
    
    /// 统一通过 IngredientIconMapper 哈希字典匹配已入库的食材图片资源，暂无图片则返回空字符串（由 UI 展示文字代替）
    public static func resolveIngredientIcon(name: String, category: IngredientCategory) -> String {
        if let icon = IngredientIconMapper.shared.lookup(name: name, category: category).iconName,
           UIImage(named: icon) != nil {
            return icon
        }
        return ""
    }
    
    /// 1. 主料列表 (主食材卡片)
    public var mainIngredientItems: [(name: String, english: String, amount: String, imageName: String)] {
        if let customMainIngredients, !customMainIngredients.isEmpty {
            return customMainIngredients.map {
                ($0.name, $0.english, $0.amount, Self.resolveIngredientIcon(name: $0.name, category: .main))
            }
        }
        let first = ingredients.first ?? "精选主料"
        let second = ingredients.dropFirst().first ?? "精选优质米"
        return [
            (name: first, english: "Main Cut", amount: "/ 300g", imageName: Self.resolveIngredientIcon(name: first, category: .main)),
            (name: second, english: "Rice / Base", amount: "/ 150g", imageName: Self.resolveIngredientIcon(name: second, category: .main))
        ]
    }
    
    /// 2. 辅料列表 (配菜食材卡片，带高品质实物图或文字兜底)
    public var auxiliaryIngredientItems: [(name: String, english: String, amount: String, imageName: String)] {
        if let customAuxiliaryIngredients, !customAuxiliaryIngredients.isEmpty {
            return customAuxiliaryIngredients.map {
                ($0.name, $0.english, $0.amount, Self.resolveIngredientIcon(name: $0.name, category: .auxiliary))
            }
        }
        let defaults: [(String, String, String)] = [
            ("洋葱", "Onion", "1 pc"),
            ("蒜瓣", "Garlic", "2 cloves"),
            ("黄油", "Butter", "2 tbsp"),
            ("鲜香菌菇", "Mushroom", "30g")
        ]
        return defaults.map { (name, eng, amt) in
            (name: name, english: eng, amount: amt, imageName: Self.resolveIngredientIcon(name: name, category: .auxiliary))
        }
    }
    
    /// 3. 调料列表 (横条比例展示)
    public var seasoningItems: [(name: String, english: String, amount: String, ratio: CGFloat, colorHex: UInt)] {
        if let customSeasonings, !customSeasonings.isEmpty {
            return customSeasonings.map { ($0.name, $0.english, $0.amount, CGFloat($0.ratio), $0.colorHex) }
        }
        return [
            (name: "海盐", english: "Salt", amount: "3g", ratio: 0.22, colorHex: 0xE0A314),
            (name: "特调豉油", english: "Soy Sauce", amount: "15g", ratio: 0.85, colorHex: 0x5C3A28),
            (name: "黑胡椒", english: "Pepper", amount: "2g", ratio: 0.20, colorHex: 0x5E8C31),
            (name: "初榨橄榄油", english: "Olive Oil", amount: "10g", ratio: 0.52, colorHex: 0x544E49)
        ]
    }
    
    /// 4. 制作步骤 (一行一句步骤，带图)
    public var stepList: [(number: String, text: String, imageName: String)] {
        if let customSteps, !customSteps.isEmpty {
            return customSteps.map { ($0.number, $0.text, $0.imageName) }
        }
        let firstIng = ingredients.first ?? "主食材"
        let secondIng = ingredients.dropFirst().first ?? "辅料"
        return [
            ("01", "将\(firstIng)洗净擦干，均匀淋入调料腌制入味。", imageName),
            ("02", "热锅下少许油，将腌制好的\(firstIng)下锅慢煎至焦香。", "dish_kungpao"),
            ("03", "下入\(secondIng)与特调豉油，中小火翻拌慢煨收汁。", "dish_mapo"),
            ("04", "盛出趁热淋在主食上，点缀新鲜香草即可享用。", "rice_claypot")
        ]
    }
    
    /// 带用量的具体配料清单
    public var ingredientDetails: [(name: String, amount: String)] {
        let defaultAmounts = ["200g", "150g", "2 份", "适量", "15ml", "少许"]
        return ingredients.enumerated().map { idx, item in
            (name: item, amount: defaultAmounts[idx % defaultAmounts.count])
        }
    }
    
    /// 具体烹饪步骤
    public var steps: [String] {
        if let customSteps, !customSteps.isEmpty {
            return customSteps.map(\.text)
        }
        let firstIng = ingredients.first ?? "主料"
        let secondIng = ingredients.dropFirst().first ?? "辅料"
        let thirdIng = ingredients.dropFirst(2).first ?? "灵魂酱汁"
        return [
            "准备食材：将\(firstIng)与\(secondIng)洗净备好，按配方比例调配好\(thirdIng)静置待用。",
            "预热与初加工：锅中热油或预热容器，先将\(firstIng)下锅以中小火慢煎/焖煮，激发出底味香气。",
            "合味收汁：加入\(secondIng)与调好的\(thirdIng)，配合（\(flavor)）的风味要领均匀翻拌或文火慢煨至熟透。",
            "装盘点缀：出锅装入温热的餐具中，趁热享用这道「\(name)」。"
        ]
    }
    
    /// 烹饪 Tips
    public var chefNotes: [String] {
        if let customChefNotes, !customChefNotes.isEmpty {
            return customChefNotes
        }
        return [
            "提前备齐所有主辅料与调味料，下锅过程更从容不易糊锅。",
            "出锅前注意观察汤汁浓稠度，按个人口味微调咸淡即可。"
        ]
    }
    
    public init(
        id: String,
        name: String,
        englishName: String,
        categoryId: String,
        imageName: String,
        subtitle: String,
        description: String,
        tag: String,
        rating: Double,
        cookingTime: String,
        calories: String,
        ingredients: [String],
        flavor: String,
        customMainIngredients: [DishIngredientItem]? = nil,
        customAuxiliaryIngredients: [DishIngredientItem]? = nil,
        customSeasonings: [DishSeasoningItem]? = nil,
        customSteps: [DishStepItem]? = nil,
        customChefNotes: [String]? = nil,
        customDifficulty: String? = nil,
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.categoryId = categoryId
        self.imageName = imageName
        self.subtitle = subtitle
        self.description = description
        self.tag = tag
        self.rating = rating
        self.cookingTime = cookingTime
        self.calories = calories
        self.ingredients = ingredients
        self.flavor = flavor
        self.customMainIngredients = customMainIngredients
        self.customAuxiliaryIngredients = customAuxiliaryIngredients
        self.customSeasonings = customSeasonings
        self.customSteps = customSteps
        self.customChefNotes = customChefNotes
        self.customDifficulty = customDifficulty
        self.isAIGenerated = isAIGenerated
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        englishName = try c.decode(String.self, forKey: .englishName)
        categoryId = try c.decode(String.self, forKey: .categoryId)
        imageName = try c.decode(String.self, forKey: .imageName)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        description = try c.decode(String.self, forKey: .description)
        tag = try c.decode(String.self, forKey: .tag)
        rating = try c.decode(Double.self, forKey: .rating)
        cookingTime = try c.decode(String.self, forKey: .cookingTime)
        calories = try c.decode(String.self, forKey: .calories)
        ingredients = try c.decode([String].self, forKey: .ingredients)
        flavor = try c.decode(String.self, forKey: .flavor)
        customMainIngredients = try c.decodeIfPresent([DishIngredientItem].self, forKey: .customMainIngredients)
        customAuxiliaryIngredients = try c.decodeIfPresent([DishIngredientItem].self, forKey: .customAuxiliaryIngredients)
        customSeasonings = try c.decodeIfPresent([DishSeasoningItem].self, forKey: .customSeasonings)
        customSteps = try c.decodeIfPresent([DishStepItem].self, forKey: .customSteps)
        customChefNotes = try c.decodeIfPresent([String].self, forKey: .customChefNotes)
        customDifficulty = try c.decodeIfPresent(String.self, forKey: .customDifficulty)
        isAIGenerated = try c.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
    }
}

