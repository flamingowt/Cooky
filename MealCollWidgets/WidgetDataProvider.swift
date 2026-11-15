import Foundation
import SwiftUI
import AppIntents

/// 小组件数据读取中心（优先读取共享容器，自动回退至内置精选数据）
enum WidgetDataProvider {
    static let appGroupId = "group.com.mealcoll.app"
    
    static func loadUserNickname() -> String {
        if let defaults = UserDefaults(suiteName: appGroupId),
           let name = defaults.string(forKey: "mealcoll_user_nickname"),
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return "船长"
    }
    
    static func loadCategories() -> [DishCategory] {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            let fileURL = containerURL.appendingPathComponent("mealcoll_categories.json")
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode([DishCategory].self, from: data),
               !decoded.isEmpty {
                return decoded
            }
        }
        return DishCategory.sampleCategories
    }
    
    static func loadCookingRecords(dishes: [Dish]) -> [CookingRecord] {
        return CookingRecord.sampleRecords(dishes: dishes)
    }
    
    static func allDishes(from categories: [DishCategory]) -> [Dish] {
        categories.flatMap { $0.dishes }
    }
    
    static func latestCookedDish() -> (dish: Dish, record: CookingRecord)? {
        let categories = loadCategories()
        let dishes = allDishes(from: categories)
        let dishMap = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        let records = loadCookingRecords(dishes: dishes).sorted { $0.date > $1.date }
        for record in records {
            if let dish = dishMap[record.dishId] {
                return (dish, record)
            }
        }
        if let fallback = dishes.first {
            return (fallback, CookingRecord(id: "fallback", date: Date(), dishId: fallback.id, note: nil))
        }
        return nil
    }
}

/// 小组件统一品牌标识（用户名.de私厨）
struct WidgetBrandLogoView: View {
    let nickname: String
    var fontSize: CGFloat = 12
    var isLightOnDark: Bool = false
    
    var body: some View {
        let inkColor: Color = isLightOnDark ? .white : .primary
        let subColor: Color = isLightOnDark ? .white.opacity(0.85) : .secondary
        
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(nickname)
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .foregroundColor(inkColor)
            
            Text(".de")
                .font(.system(size: fontSize * 0.78, weight: .medium, design: .serif))
                .italic()
                .foregroundColor(subColor)
            
            Text("私厨")
                .font(.system(size: fontSize * 1.12, weight: .black, design: .serif))
                .foregroundColor(inkColor)
        }
        .lineLimit(1)
        .shadow(color: isLightOnDark ? Color.black.opacity(0.35) : .clear, radius: 2, y: 1)
    }
}

/// 小组件图片视图（支持 Asset Catalog 内置图片及本地自定义图片）
struct WidgetDishImage: View {
    let imageName: String
    
    var body: some View {
        if imageName.hasPrefix("custom_"),
           let uiImg = loadCustomImage(named: imageName) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
        } else {
            Image(imageName)
                .resizable()
                .scaledToFill()
        }
    }
    
    private func loadCustomImage(named name: String) -> UIImage? {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataProvider.appGroupId) {
            let url = containerURL.appendingPathComponent("CustomDishImages", isDirectory: true).appendingPathComponent("\(name).jpg")
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                return img
            }
        }
        return nil
    }
}

// MARK: - AppIntents (用于长按编辑「分类食谱」中组件选择大类)

struct CategoryAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "菜谱大类"
    static var defaultQuery = CategoryEntityQuery()
    
    let id: String
    let name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CategoryAppEntity] {
        let categories = WidgetDataProvider.loadCategories()
        return categories
            .filter { identifiers.contains($0.id) }
            .map { CategoryAppEntity(id: $0.id, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [CategoryAppEntity] {
        WidgetDataProvider.loadCategories().map {
            CategoryAppEntity(id: $0.id, name: $0.name)
        }
    }
    
    func defaultResult() async -> CategoryAppEntity? {
        let categories = WidgetDataProvider.loadCategories()
        let preferred = categories.first(where: { $0.id == "classic_stirfry" }) ?? categories.first
        return preferred.map { CategoryAppEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectCategoryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择菜谱大类"
    static var description = IntentDescription("选择要在中号小组件中展示的菜谱分类")
    
    @Parameter(title: "菜谱大类")
    var category: CategoryAppEntity?
    
    init() {}
    
    init(category: CategoryAppEntity?) {
        self.category = category
    }
}
