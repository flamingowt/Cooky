import Foundation
import SwiftUI

/// 原料类别定义
public enum IngredientCategory: String, Codable, CaseIterable {
    case main = "main"           // 主料
    case auxiliary = "auxiliary" // 辅料
    case seasoning = "seasoning" // 调料
}

/// 食材图标与元数据信息（暂用文字/SF Symbols/Emoji展示，预留自定义icon库无缝接入）
public struct IngredientIconInfo: Identifiable, Hashable, Codable {
    public var id: String { name }
    public let name: String
    public let englishName: String
    public let category: IngredientCategory
    public let iconName: String?      // 预留：用户提供的专用icon库图片资源名称
    public let symbolName: String    // 备用：SF Symbols矢量图标
    public let emoji: String         // 备用：文字或Emoji直观展示
    public let defaultAmount: String // 常规推荐用量
    public let colorHex: String      // 调料或食材代表色
    
    public init(
        name: String,
        englishName: String,
        category: IngredientCategory,
        iconName: String? = nil,
        symbolName: String = "leaf.fill",
        emoji: String = "🥗",
        defaultAmount: String = "",
        colorHex: String = "#5C3A28"
    ) {
        self.name = name
        self.englishName = englishName
        self.category = category
        self.iconName = iconName
        self.symbolName = symbolName
        self.emoji = emoji
        self.defaultAmount = defaultAmount
        self.colorHex = colorHex
    }
}

/// 全局原料映射中心：涵盖常见肉禽、海鲜、蔬菜、主食、调味料的超全映射字典与别名归一化
public final class IngredientIconMapper {
    public static let shared = IngredientIconMapper()
    
    private var mappingDict: [String: IngredientIconInfo] = [:]
    private var aliasMap: [String: String] = [:]
    
    private init() {
        buildComprehensiveDatabase()
    }
    
    // MARK: - Public Lookup
    /// 根据大模型抽取的原料名称匹配最合适的映射，未匹配时智能兜底
    public func lookup(name: String, category: IngredientCategory = .auxiliary) -> IngredientIconInfo {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = cleanIngredientName(trimmed)
        
        // 1. 别名查找
        let lookupKey = aliasMap[normalized] ?? normalized
        
        // 2. 精确匹配
        if let exact = mappingDict[lookupKey] {
            return exact
        }
        
        // 3. 包含/模糊匹配
        for (key, info) in mappingDict {
            if normalized.contains(key) || key.contains(normalized) {
                return info
            }
        }
        
        // 4. 智能根据类别兜底（文字为主，留好 icon 接口）
        return fallbackForCategory(name: trimmed, category: category)
    }
    
    // MARK: - Cleaning & Aliasing
    private func cleanIngredientName(_ raw: String) -> String {
        var str = raw
        let removes = ["精选", "优质", "新鲜", "自制", "适量", "少许", "特级", "农家", "厚切", "薄切", "切片", "切丁", "碎", "末"]
        for r in removes {
            str = str.replacingOccurrences(of: r, with: "")
        }
        return str
    }
    
    private func fallbackForCategory(name: String, category: IngredientCategory) -> IngredientIconInfo {
        switch category {
        case .main:
            return IngredientIconInfo(
                name: name,
                englishName: "Main Cut",
                category: .main,
                iconName: nil,
                symbolName: "fork.knife",
                emoji: "🥩",
                defaultAmount: "/ 200g"
            )
        case .auxiliary:
            return IngredientIconInfo(
                name: name,
                englishName: "Vegetables",
                category: .auxiliary,
                iconName: nil,
                symbolName: "leaf",
                emoji: "🥗",
                defaultAmount: "适量"
            )
        case .seasoning:
            return IngredientIconInfo(
                name: name,
                englishName: "Seasoning",
                category: .seasoning,
                iconName: nil,
                symbolName: "drop.fill",
                emoji: "🧂",
                defaultAmount: "1勺",
                colorHex: "#443228"
            )
        }
    }
    
    // MARK: - Comprehensive Ingredient Database
    private func register(_ info: IngredientIconInfo, aliases: [String] = []) {
        mappingDict[info.name] = info
        for a in aliases {
            aliasMap[a] = info.name
        }
    }
    
    private func buildComprehensiveDatabase() {
        // --- 1. 主料：肉禽蛋品 ---
        register(IngredientIconInfo(name: "牛里脊", englishName: "Beef Tenderloin", category: .main, iconName: "ing_beef_tenderloin", symbolName: "fork.knife", emoji: "🥩", defaultAmount: "/ 200g"), aliases: ["牛肉", "鲜牛肉", "牛柳", "肥牛", "安格斯牛肉", "牛肉片"])
        register(IngredientIconInfo(name: "猪五花", englishName: "Pork Belly", category: .main, iconName: "ing_pork_belly", symbolName: "fork.knife", emoji: "🥓", defaultAmount: "/ 250g"), aliases: ["五花肉", "五花肉片", "猪瘦肉"])
        register(IngredientIconInfo(name: "鸡胸肉", englishName: "Chicken Breast", category: .main, iconName: "ing_chicken_breast", symbolName: "fork.knife", emoji: "🍗", defaultAmount: "/ 200g"), aliases: ["鸡肉", "鸡柳"])
        register(IngredientIconInfo(name: "羊肉卷", englishName: "Lamb Slices", category: .main, iconName: "ing_lamb_slices", symbolName: "fork.knife", emoji: "🥩", defaultAmount: "/ 200g"), aliases: ["羊肉"])
        register(IngredientIconInfo(name: "鸡蛋", englishName: "Eggs", category: .main, iconName: "ing_egg", symbolName: "oval", emoji: "🥚", defaultAmount: "2 个"), aliases: ["可生食鸡蛋", "土鸡蛋", "蛋液"])
        
        // --- 2. 主料：水产海鲜 ---
        register(IngredientIconInfo(name: "三文鱼", englishName: "Salmon Cut", category: .main, iconName: "ing_salmon", symbolName: "fish", emoji: "🐟", defaultAmount: "/ 200g"), aliases: ["厚切三文鱼", "大西洋鲑"])
        register(IngredientIconInfo(name: "大虾", englishName: "Fresh Shrimp", category: .main, iconName: "ing_shrimp", symbolName: "fish.fill", emoji: "🦐", defaultAmount: "8-10 只"), aliases: ["基围虾", "黑虎虾", "明虾", "大头虾"])
        register(IngredientIconInfo(name: "鲈鱼", englishName: "Sea Bass", category: .main, iconName: "ing_sea_bass", symbolName: "fish", emoji: "🐟", defaultAmount: "1 条"), aliases: ["鲜鱼"])
        register(IngredientIconInfo(name: "鲜鱿鱼", englishName: "Squid", category: .main, iconName: "ing_squid", symbolName: "water.waves", emoji: "🦑", defaultAmount: "/ 150g"), aliases: ["鱿鱼", "鱿鱼圈", "墨鱼"])
        register(IngredientIconInfo(name: "花蛤", englishName: "Clams", category: .main, iconName: "ing_clam", symbolName: "circle.grid.cross", emoji: "🦪", defaultAmount: "/ 300g"), aliases: ["文蛤", "蛤蜊"])

        // --- 3. 主料：米面主食 ---
        register(IngredientIconInfo(name: "手工面片坯", englishName: "Dough Drops", category: .main, iconName: "ing_dough_drops", symbolName: "takeoutbag.and.cup.and.straw", emoji: "🥟", defaultAmount: "/ 250g"), aliases: ["面片坯", "手工面片", "面片", "揪面片"])
        register(IngredientIconInfo(name: "越光米", englishName: "Steamed Rice", category: .main, iconName: "ing_rice", symbolName: "takeoutbag.and.cup.and.straw.fill", emoji: "🍚", defaultAmount: "/ 200g"), aliases: ["大米", "白米饭", "丝苗米", "香米"])
        register(IngredientIconInfo(name: "拉面", englishName: "Ramen Noodles", category: .main, iconName: "ing_noodles", symbolName: "fork.knife", emoji: "🍜", defaultAmount: "/ 150g"), aliases: ["面条", "手擀面", "刀削面", "挂面"])
        register(IngredientIconInfo(name: "老豆腐", englishName: "Tofu", category: .main, iconName: "ing_firm_tofu", symbolName: "square", emoji: "🧈", defaultAmount: "/ 200g"), aliases: ["豆腐", "北豆腐"])

        // --- 4. 辅料：蔬菜蔬果 ---
        register(IngredientIconInfo(name: "西红柿", englishName: "Tomato", category: .auxiliary, iconName: "ing_tomato", symbolName: "circle.fill", emoji: "🍅", defaultAmount: "2 个"), aliases: ["番茄", "去皮西红柿", "番茄丁"])
        register(IngredientIconInfo(name: "洋葱", englishName: "Onion", category: .auxiliary, iconName: "ing_onion", symbolName: "circle", emoji: "🧅", defaultAmount: "半个"), aliases: ["紫洋葱", "白洋葱", "洋葱丝", "洋葱丁"])
        register(IngredientIconInfo(name: "青椒", englishName: "Green Pepper", category: .auxiliary, iconName: "ing_green_pepper", symbolName: "flame", emoji: "🫑", defaultAmount: "1 个"), aliases: ["菜椒", "甜椒", "尖椒", "杭椒", "螺丝椒"])
        register(IngredientIconInfo(name: "葱姜蒜", englishName: "Aromatics", category: .auxiliary, iconName: "ing_garlic", symbolName: "leaf", emoji: "🧄", defaultAmount: "适量"), aliases: ["大蒜", "蒜瓣", "蒜末"])
        register(IngredientIconInfo(name: "土豆", englishName: "Potato", category: .auxiliary, iconName: "ing_potato", symbolName: "circle.grid.2x1", emoji: "🥔", defaultAmount: "1 个"), aliases: ["马铃薯", "土豆块", "土豆丝"])
        register(IngredientIconInfo(name: "胡萝卜", englishName: "Carrot", category: .auxiliary, iconName: "ing_carrot", symbolName: "carrot", emoji: "🥕", defaultAmount: "半根"), aliases: ["胡萝卜丁", "红萝卜"])
        register(IngredientIconInfo(name: "西兰花", englishName: "Broccoli", category: .auxiliary, iconName: "ing_broccoli", symbolName: "leaf.fill", emoji: "🥦", defaultAmount: "5 朵"), aliases: ["绿菜花"])
        register(IngredientIconInfo(name: "香菇", englishName: "Mushroom", category: .auxiliary, iconName: "ing_shiitake", symbolName: "umbrella.fill", emoji: "🍄", defaultAmount: "3 朵"), aliases: ["鲜香菇", "鲜香菌菇", "菌菇"])
        register(IngredientIconInfo(name: "黄瓜", englishName: "Cucumber", category: .auxiliary, iconName: "ing_cucumber", symbolName: "leaf", emoji: "🥒", defaultAmount: "半根"), aliases: ["黄瓜丝", "黄瓜片", "小黄瓜"])
        register(IngredientIconInfo(name: "香菜", englishName: "Cilantro", category: .auxiliary, iconName: "ing_cilantro", symbolName: "leaf.arrow.triangle.circlepath", emoji: "🌿", defaultAmount: "少许"), aliases: ["芫荽"])

        // --- 5. 调料配比（固定高品质色深，量化对齐） ---
        register(IngredientIconInfo(name: "生抽", englishName: "Light soy sauce", category: .seasoning, iconName: "ing_light_soy_sauce", symbolName: "drop.fill", emoji: "🥢", defaultAmount: "2 勺", colorHex: "#443228"), aliases: ["特调生抽", "酱油"])
        register(IngredientIconInfo(name: "老抽", englishName: "Dark soy sauce", category: .seasoning, iconName: "ing_dark_soy_sauce", symbolName: "drop.triangle.fill", emoji: "🥢", defaultAmount: "1 勺", colorHex: "#443228"), aliases: ["老抽上色", "草菇老抽", "红烧酱油"])
        register(IngredientIconInfo(name: "辣椒面", englishName: "Chili flakes", category: .seasoning, iconName: "ing_chili_powder", symbolName: "flame.fill", emoji: "🌶️", defaultAmount: "1 勺", colorHex: "#443228"), aliases: ["香辣红油辣椒面", "上色辣椒面"])
        register(IngredientIconInfo(name: "白胡椒粉", englishName: "White pepper", category: .seasoning, iconName: "ing_white_pepper", symbolName: "sparkles", emoji: "🧂", defaultAmount: "适量", colorHex: "#443228"), aliases: ["白胡椒", "自胡椒"])
        register(IngredientIconInfo(name: "食用盐", englishName: "Salt", category: .seasoning, iconName: "ing_salt", symbolName: "snowflake", emoji: "🧂", defaultAmount: "适量", colorHex: "#443228"), aliases: ["食盐", "细盐", "盐", "精盐"])
        register(IngredientIconInfo(name: "蚝油", englishName: "Oyster sauce", category: .seasoning, iconName: "ing_oyster_sauce", symbolName: "drop", emoji: "🦪", defaultAmount: "1 勺", colorHex: "#443228"), aliases: ["鲍汁"])
        register(IngredientIconInfo(name: "香油", englishName: "Sesame oil", category: .seasoning, iconName: "ing_sesame_oil", symbolName: "drop.degreesign", emoji: "🥣", defaultAmount: "少许", colorHex: "#443228"), aliases: ["芝麻油", "麻油"])
        register(IngredientIconInfo(name: "料酒", englishName: "Cooking wine", category: .seasoning, iconName: "ing_cooking_wine", symbolName: "wineglass", emoji: "🍶", defaultAmount: "1 勺", colorHex: "#443228"), aliases: ["黄酒"])
        
        // --- 6. 全量标准化食材资源映射表（按 Assets.xcassets/ing_* 统一命名） ---
        let catalogEntries: [(String, String, IngredientCategory)] = [
            // 主料：肉禽蛋
            ("猪排骨", "ing_pork_ribs", .main), ("猪里脊", "ing_pork_tenderloin", .main), ("猪梅花肉", "ing_pork_shoulder", .main),
            ("猪蹄", "ing_pork_trotter", .main), ("猪肉末", "ing_minced_pork", .main), ("腊肉", "ing_cured_pork", .main),
            ("培根", "ing_bacon", .main), ("火腿肠", "ing_ham_sausage", .main), ("午餐肉", "ing_luncheon_meat", .main),
            ("猪肚", "ing_pork_tripe", .main), ("猪耳", "ing_pork_ear", .main), ("猪肋排", "ing_pork_spare_ribs", .main), ("猪腰", "ing_pork_kidney", .main),
            ("牛腩", "ing_beef_brisket", .main), ("肥牛卷", "ing_beef_slices", .main), ("牛排", "ing_steak", .main),
            ("牛腱子", "ing_beef_shank", .main), ("牛肉末", "ing_minced_beef", .main), ("牛尾", "ing_oxtail", .main),
            ("牛肚", "ing_beef_tripe", .main), ("酱牛肉", "ing_braised_beef", .main),
            ("羊排", "ing_lamb_chops", .main), ("羊腿肉", "ing_lamb_leg", .main),
            ("鸡腿肉", "ing_chicken_thigh", .main), ("鸡翅中", "ing_chicken_wings", .main), ("鸡爪", "ing_chicken_feet", .main),
            ("整鸡", "ing_whole_chicken", .main), ("鸭肉", "ing_duck", .main), ("鸭血", "ing_duck_blood", .main),
            ("鸭胗", "ing_duck_gizzard", .main), ("鹅肉", "ing_goose", .main),
            ("鸭蛋", "ing_duck_egg", .main), ("咸蛋黄", "ing_salted_egg_yolk", .main), ("皮蛋", "ing_century_egg", .main), ("鹌鹑蛋", "ing_quail_egg", .main),
            // 主料：水产海鲜
            ("鳕鱼", "ing_cod", .main), ("草鱼", "ing_grass_carp", .main), ("鲫鱼", "ing_crucian_carp", .main),
            ("鲤鱼", "ing_carp", .main), ("鱼头", "ing_fish_head", .main), ("黑鱼片", "ing_snakehead_fillet", .main),
            ("巴沙鱼", "ing_basa_fillet", .main), ("黄鱼", "ing_yellow_croaker", .main), ("带鱼", "ing_hairtail", .main),
            ("金枪鱼", "ing_tuna", .main), ("鳗鱼", "ing_eel", .main), ("虾仁", "ing_peeled_shrimp", .main),
            ("小龙虾", "ing_crayfish", .main), ("螃蟹", "ing_crab", .main), ("八爪鱼", "ing_octopus", .main),
            ("生蚝", "ing_oyster", .main), ("扇贝", "ing_scallop", .main), ("鲍鱼", "ing_abalone", .main),
            ("海参", "ing_sea_cucumber", .main), ("海带", "ing_kelp", .main), ("紫菜", "ing_seaweed", .main),
            // 主料：豆制品与米面
            ("嫩豆腐", "ing_silken_tofu", .main), ("日本豆腐", "ing_egg_tofu", .main), ("冻豆腐", "ing_frozen_tofu", .main),
            ("豆腐泡", "ing_tofu_puff", .main), ("千张", "ing_tofu_skin", .main), ("腐竹", "ing_yuba", .main),
            ("豆干", "ing_dried_tofu", .main), ("面筋", "ing_wheat_gluten", .main), ("魔芋结", "ing_konjac", .main),
            ("糯米", "ing_glutinous_rice", .main), ("紫米", "ing_black_rice", .main), ("小米", "ing_millet", .main),
            ("燕麦", "ing_oats", .main), ("面粉", "ing_flour", .main), ("意大利面", "ing_pasta", .main),
            ("乌冬面", "ing_udon", .main), ("粉丝", "ing_vermicelli", .main), ("米粉", "ing_rice_noodles", .main),
            ("河粉", "ing_ho_fun", .main), ("凉皮", "ing_liangpi", .main), ("年糕", "ing_rice_cake", .main),
            ("饺子皮", "ing_dumpling_wrapper", .main), ("馄饨皮", "ing_wonton_wrapper", .main),
            ("吐司面包", "ing_toast_bread", .main), ("馒头", "ing_steamed_bun", .main), ("玉米粒", "ing_corn_kernels", .main),
            ("红豆", "ing_red_bean", .main), ("绿豆", "ing_mung_bean", .main), ("黑豆", "ing_black_bean", .main), ("黄豆", "ing_soybean", .main),
            // 辅料：蔬果菌菇
            ("生姜", "ing_ginger", .auxiliary), ("小葱", "ing_scallion", .auxiliary), ("大葱", "ing_leek", .auxiliary),
            ("小米辣", "ing_bird_eye_chili", .auxiliary), ("干辣椒", "ing_dried_chili", .auxiliary), ("泡椒", "ing_pickled_chili", .auxiliary),
            ("红椒", "ing_red_pepper", .auxiliary), ("彩椒", "ing_bell_pepper", .auxiliary), ("线椒", "ing_long_chili", .auxiliary),
            ("迷迭香", "ing_rosemary", .auxiliary), ("百里香", "ing_thyme", .auxiliary), ("罗勒叶", "ing_basil", .auxiliary),
            ("薄荷叶", "ing_mint", .auxiliary), ("欧芹", "ing_parsley", .auxiliary), ("紫苏", "ing_perilla", .auxiliary),
            ("圣女果", "ing_cherry_tomato", .auxiliary), ("茄子", "ing_eggplant", .auxiliary), ("冬瓜", "ing_winter_melon", .auxiliary),
            ("丝瓜", "ing_luffa", .auxiliary), ("苦瓜", "ing_bitter_melon", .auxiliary), ("西葫芦", "ing_zucchini", .auxiliary),
            ("南瓜", "ing_pumpkin", .auxiliary), ("秋葵", "ing_okra", .auxiliary), ("四季豆", "ing_green_beans", .auxiliary),
            ("豇豆", "ing_long_beans", .auxiliary), ("毛豆", "ing_edamame", .auxiliary), ("豌豆", "ing_green_peas", .auxiliary),
            ("荷兰豆", "ing_snow_peas", .auxiliary), ("豆芽", "ing_bean_sprouts", .auxiliary), ("玉米棒", "ing_sweet_corn", .auxiliary),
            ("红薯", "ing_sweet_potato", .auxiliary), ("紫薯", "ing_purple_potato", .auxiliary), ("山药", "ing_yam", .auxiliary),
            ("芋头", "ing_taro", .auxiliary), ("白萝卜", "ing_daikon_radish", .auxiliary), ("莲藕", "ing_lotus_root", .auxiliary),
            ("竹笋", "ing_bamboo_shoot", .auxiliary), ("芦笋", "ing_asparagus", .auxiliary), ("荸荠", "ing_water_chestnut", .auxiliary),
            ("莴笋", "ing_celtuce", .auxiliary), ("芋圆", "ing_taro_balls", .auxiliary),
            ("大白菜", "ing_napa_cabbage", .auxiliary), ("小白菜", "ing_bok_choy", .auxiliary), ("娃娃菜", "ing_baby_cabbage", .auxiliary),
            ("生菜", "ing_lettuce", .auxiliary), ("菠菜", "ing_spinach", .auxiliary), ("油麦菜", "ing_romaine", .auxiliary),
            ("空心菜", "ing_water_spinach", .auxiliary), ("苋菜", "ing_amaranth", .auxiliary), ("包菜", "ing_cabbage", .auxiliary),
            ("紫甘蓝", "ing_purple_cabbage", .auxiliary), ("花菜", "ing_cauliflower", .auxiliary), ("西芹", "ing_celery", .auxiliary),
            ("韭菜", "ing_garlic_chives", .auxiliary), ("蒜薹", "ing_garlic_scape", .auxiliary), ("芥蓝", "ing_chinese_broccoli", .auxiliary),
            ("菜心", "ing_choy_sum", .auxiliary), ("茼蒿", "ing_garland_chrysanthemum", .auxiliary), ("西洋菜", "ing_watercress", .auxiliary),
            ("金针菇", "ing_enoki", .auxiliary), ("杏鲍菇", "ing_king_oyster_mushroom", .auxiliary), ("平菇", "ing_oyster_mushroom", .auxiliary),
            ("口蘑", "ing_button_mushroom", .auxiliary), ("茶树菇", "ing_tea_tree_mushroom", .auxiliary), ("蟹味菇", "ing_shimeji", .auxiliary),
            ("猴头菇", "ing_lions_mane", .auxiliary), ("黑木耳", "ing_wood_ear", .auxiliary), ("银耳", "ing_snow_fungus", .auxiliary), ("竹荪", "ing_bamboo_fungus", .auxiliary),
            ("柠檬", "ing_lemon", .auxiliary), ("青柠", "ing_lime", .auxiliary), ("菠萝", "ing_pineapple", .auxiliary),
            ("芒果", "ing_mango", .auxiliary), ("苹果", "ing_apple", .auxiliary), ("牛油果", "ing_avocado", .auxiliary),
            ("香蕉", "ing_banana", .auxiliary), ("草莓", "ing_strawberry", .auxiliary), ("蓝莓", "ing_blueberry", .auxiliary),
            ("红枣", "ing_red_date", .auxiliary), ("枸杞", "ing_goji_berry", .auxiliary), ("花生米", "ing_peanut", .auxiliary),
            ("核桃", "ing_walnut", .auxiliary), ("腰果", "ing_cashew", .auxiliary), ("松子", "ing_pine_nut", .auxiliary),
            ("杏仁", "ing_almond", .auxiliary), ("葡萄干", "ing_raisin", .auxiliary), ("酸菜", "ing_pickled_mustard", .auxiliary),
            ("榨菜", "ing_preserved_mustard", .auxiliary), ("梅干菜", "ing_dried_mustard_greens", .auxiliary), ("酸萝卜", "ing_pickled_radish", .auxiliary),
            // 调料
            ("蒸鱼豉油", "ing_steamed_fish_soy_sauce", .seasoning), ("东古一品鲜", "ing_premium_soy_sauce", .seasoning), ("日式酱油", "ing_japanese_soy_sauce", .seasoning),
            ("鲍鱼汁", "ing_abalone_sauce", .seasoning), ("鱼露", "ing_fish_sauce", .seasoning), ("虾酱", "ing_shrimp_paste", .seasoning),
            ("豆瓣酱", "ing_doubanjiang", .seasoning), ("黄豆酱", "ing_soybean_paste", .seasoning), ("甜面酱", "ing_sweet_bean_sauce", .seasoning),
            ("柱侯酱", "ing_chu_hou_paste", .seasoning), ("沙茶酱", "ing_shacha_sauce", .seasoning), ("芝麻酱", "ing_sesame_paste", .seasoning),
            ("花生酱", "ing_peanut_butter", .seasoning), ("黑椒酱", "ing_black_pepper_sauce", .seasoning), ("照烧汁", "ing_teriyaki_sauce", .seasoning),
            ("XO酱", "ing_xo_sauce", .seasoning), ("海鲜酱", "ing_hoisin_sauce", .seasoning), ("排骨酱", "ing_rib_sauce", .seasoning),
            ("陈醋", "ing_aged_vinegar", .seasoning), ("香醋", "ing_balsamic_vinegar", .seasoning), ("米醋", "ing_rice_vinegar", .seasoning),
            ("白醋", "ing_white_vinegar", .seasoning), ("苹果醋", "ing_apple_cider_vinegar", .seasoning), ("柠檬汁", "ing_lemon_juice", .seasoning),
            ("白砂糖", "ing_white_sugar", .seasoning), ("冰糖", "ing_rock_sugar", .seasoning), ("红糖", "ing_brown_sugar", .seasoning),
            ("蜂蜜", "ing_honey", .seasoning), ("麦芽糖", "ing_maltose", .seasoning), ("糖桂花", "ing_osmanthus_syrup", .seasoning),
            ("番茄酱", "ing_ketchup", .seasoning), ("番茄膏", "ing_tomato_paste", .seasoning), ("甜辣酱", "ing_sweet_chili_sauce", .seasoning),
            ("辣椒油", "ing_chili_oil", .seasoning), ("老干妈豆豉酱", "ing_chili_crisp", .seasoning), ("剁椒酱", "ing_chopped_chili_sauce", .seasoning),
            ("黄灯笼辣椒酱", "ing_yellow_chili_sauce", .seasoning), ("泰式冬阴功酱", "ing_tom_yum_paste", .seasoning), ("咖喱块", "ing_curry_cube", .seasoning),
            ("沙拉酱", "ing_mayonnaise", .seasoning), ("千岛酱", "ing_thousand_island", .seasoning), ("芥末酱", "ing_mustard", .seasoning), ("辣根酱", "ing_wasabi", .seasoning),
            ("花雕酒", "ing_shaoxing_wine", .seasoning), ("米酒", "ing_rice_wine", .seasoning), ("啤酒", "ing_beer", .seasoning),
            ("红酒", "ing_red_wine", .seasoning), ("白葡萄酒", "ing_white_wine", .seasoning), ("食用油", "ing_cooking_oil", .seasoning),
            ("花生油", "ing_peanut_oil", .seasoning), ("菜籽油", "ing_rapeseed_oil", .seasoning), ("橄榄油", "ing_olive_oil", .seasoning),
            ("花椒油", "ing_sichuan_pepper_oil", .seasoning), ("藤椒油", "ing_green_peppercorn_oil", .seasoning), ("葱油", "ing_scallion_oil", .seasoning),
            ("猪油", "ing_lard", .seasoning), ("黄油", "ing_butter", .seasoning), ("牛油火锅底料", "ing_hotpot_base", .seasoning),
            ("淡奶油", "ing_heavy_cream", .seasoning), ("纯牛奶", "ing_milk", .seasoning), ("椰浆", "ing_coconut_milk", .seasoning),
            ("酸奶", "ing_yogurt", .seasoning), ("芝士片", "ing_cheese_slice", .seasoning), ("马苏里拉芝士", "ing_mozzarella", .seasoning), ("帕玛森芝士", "ing_parmesan", .seasoning),
            ("海盐", "ing_sea_salt", .seasoning), ("味精", "ing_msg", .seasoning), ("鸡精", "ing_chicken_bouillon", .seasoning),
            ("松茸鲜", "ing_matsutake_seasoning", .seasoning), ("淀粉", "ing_starch", .seasoning), ("玉米淀粉", "ing_cornstarch", .seasoning),
            ("红薯淀粉", "ing_sweet_potato_starch", .seasoning), ("吉士粉", "ing_custard_powder", .seasoning), ("泡打粉", "ing_baking_powder", .seasoning),
            ("小苏打", "ing_baking_soda", .seasoning), ("酵母", "ing_yeast", .seasoning), ("黑胡椒碎", "ing_black_pepper", .seasoning),
            ("花椒粒", "ing_sichuan_peppercorn", .seasoning), ("青花椒", "ing_green_peppercorn", .seasoning), ("孜然粒", "ing_cumin", .seasoning),
            ("孜然粉", "ing_cumin_powder", .seasoning), ("五香粉", "ing_five_spice", .seasoning), ("十三香", "ing_thirteen_spice", .seasoning),
            ("咖喱粉", "ing_curry_powder", .seasoning), ("姜黄粉", "ing_turmeric", .seasoning), ("肉桂粉", "ing_cinnamon_powder", .seasoning),
            ("八角", "ing_star_anise", .seasoning), ("桂皮", "ing_cinnamon_bark", .seasoning), ("香叶", "ing_bay_leaf", .seasoning),
            ("草果", "ing_tsao_ko", .seasoning), ("小茴香", "ing_fennel_seed", .seasoning), ("丁香", "ing_clove", .seasoning),
            ("白芷", "ing_angelica_root", .seasoning), ("山奈", "ing_sand_ginger", .seasoning), ("豆蔻", "ing_cardamom", .seasoning),
            ("陈皮", "ing_dried_tangerine_peel", .seasoning), ("白芝麻", "ing_white_sesame", .seasoning), ("黑芝麻", "ing_black_sesame", .seasoning),
            ("熟花生碎", "ing_crushed_peanut", .seasoning), ("蒜蓉酥", "ing_fried_garlic", .seasoning), ("面包糠", "ing_breadcrumbs", .seasoning)
        ]
        for (name, icon, cat) in catalogEntries where mappingDict[name] == nil {
            register(IngredientIconInfo(name: name, englishName: name, category: cat, iconName: icon))
        }
        // 补充常用别名
        aliasMap["花椒"] = "花椒粒"
        aliasMap["醋"] = "陈醋"
        aliasMap["鸡腿"] = "鸡腿肉"
        aliasMap["鸡翅"] = "鸡翅中"
        aliasMap["排骨"] = "猪排骨"
        aliasMap["牡蛎"] = "生蚝"
        aliasMap["木耳"] = "黑木耳"
        aliasMap["芹菜"] = "西芹"
        aliasMap["黄花鱼"] = "黄鱼"
        aliasMap["梭子蟹"] = "螃蟹"
        aliasMap["熟玉米"] = "玉米棒"
        aliasMap["熟芝麻"] = "白芝麻"
        aliasMap["小油菜"] = "小白菜"
        aliasMap["辣椒酱"] = "剁椒酱"
    }
}

