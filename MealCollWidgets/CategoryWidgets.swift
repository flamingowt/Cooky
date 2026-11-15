import WidgetKit
import SwiftUI

// MARK: - 1. 中号组件：指定大类菜谱（展示 3 道菜）

struct CategoryMediumEntry: TimelineEntry {
    let date: Date
    let category: DishCategory
}

struct CategoryMediumProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CategoryMediumEntry {
        let categories = WidgetDataProvider.loadCategories()
        return CategoryMediumEntry(date: Date(), category: categories.first!)
    }
    
    func snapshot(for configuration: SelectCategoryIntent, in context: Context) async -> CategoryMediumEntry {
        CategoryMediumEntry(date: Date(), category: resolveCategory(from: configuration))
    }
    
    func timeline(for configuration: SelectCategoryIntent, in context: Context) async -> Timeline<CategoryMediumEntry> {
        let now = Date()
        let entry = CategoryMediumEntry(date: now, category: resolveCategory(from: configuration))
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(14400)
        return Timeline(entries: [entry], policy: .after(next))
    }
    
    private func resolveCategory(from configuration: SelectCategoryIntent) -> DishCategory {
        let categories = WidgetDataProvider.loadCategories()
        if let targetId = configuration.category?.id,
           let found = categories.first(where: { $0.id == targetId }) {
            return found
        }
        return categories.first(where: { $0.id == "classic_stirfry" }) ?? categories[0]
    }
}

struct CategoryMediumWidgetView: View {
    let entry: CategoryMediumEntry
    
    var body: some View {
        let topDishes = Array(entry.category.dishes.prefix(3))
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Link(destination: URL(string: "mealcoll://category?id=\(entry.category.id)")!) {
                    HStack(spacing: 6) {
                        Text(entry.category.name)
                            .font(.system(size: 15, weight: .bold, design: .serif))
                            .foregroundColor(.primary)
                        
                        Text("\(entry.category.count) 道")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                WidgetBrandLogoView(nickname: WidgetDataProvider.loadUserNickname(), fontSize: 11.5)
            }
            
            HStack(spacing: 8) {
                ForEach(topDishes) { dish in
                    Link(destination: URL(string: "mealcoll://dish?id=\(dish.id)")!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 78)
                                .overlay {
                                    WidgetDishImage(imageName: dish.imageName)
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            
                            Text(dish.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "timer")
                                    .font(.system(size: 8.5))
                                Text(dish.cookingTime)
                                    .font(.system(size: 9.5, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}

struct MealCollCategoryMediumWidget: Widget {
    let kind = "MealCollCategoryMediumWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCategoryIntent.self,
            provider: CategoryMediumProvider()
        ) { entry in
            CategoryMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("分类食谱精选")
        .description("选择一个食谱大类，在桌面展示精选菜肴（长按组件可切换分类）")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - 2. 小号组件 A：随机大类食谱

struct RandomCategoryEntry: TimelineEntry {
    let date: Date
    let category: DishCategory
}

struct RandomCategoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> RandomCategoryEntry {
        let categories = WidgetDataProvider.loadCategories()
        return RandomCategoryEntry(date: Date(), category: categories.first!)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RandomCategoryEntry) -> Void) {
        let categories = WidgetDataProvider.loadCategories()
        completion(RandomCategoryEntry(date: Date(), category: categories.randomElement() ?? categories[0]))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RandomCategoryEntry>) -> Void) {
        let categories = WidgetDataProvider.loadCategories().shuffled()
        let now = Date()
        var entries: [RandomCategoryEntry] = []
        
        for (idx, cat) in categories.prefix(6).enumerated() {
            let entryDate = Calendar.current.date(byAdding: .hour, value: idx * 2, to: now) ?? now.addingTimeInterval(Double(idx * 7200))
            entries.append(RandomCategoryEntry(date: entryDate, category: cat))
        }
        
        let refresh = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now.addingTimeInterval(43200)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct RandomCategoryWidgetView: View {
    let entry: RandomCategoryEntry
    
    var body: some View {
        let previewDishes = Array(entry.category.dishes.prefix(2))
        
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                WidgetBrandLogoView(nickname: WidgetDataProvider.loadUserNickname(), fontSize: 10)
                Spacer()
                Text("\(entry.category.count)道")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
            
            Text(entry.category.name)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 2)
            
            // 扇形双卡预览
            ZStack {
                if previewDishes.count >= 2 {
                    WidgetDishImage(imageName: previewDishes[1].imageName)
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white, lineWidth: 1.5))
                        .rotationEffect(.degrees(8))
                        .offset(x: 22, y: 2)
                        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                }
                
                if let first = previewDishes.first {
                    WidgetDishImage(imageName: first.imageName)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white, lineWidth: 1.5))
                        .rotationEffect(.degrees(-5))
                        .offset(x: -16, y: 0)
                        .shadow(color: Color.black.opacity(0.16), radius: 5, y: 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 74)
            
            if let first = previewDishes.first {
                Text(first.name)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .widgetURL(URL(string: "mealcoll://category?id=\(entry.category.id)"))
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}

struct MealCollRandomCategoryWidget: Widget {
    let kind = "MealCollRandomCategoryWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RandomCategoryProvider()) { entry in
            RandomCategoryWidgetView(entry: entry)
        }
        .configurationDisplayName("随机食谱分类")
        .description("随机推荐经典炒菜、米饭精选等分类灵感")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - 3. 小号组件 B：最近一次吃的菜

struct LatestDishEntry: TimelineEntry {
    let date: Date
    let dish: Dish
    let cookedDate: Date
}

struct LatestDishProvider: TimelineProvider {
    func placeholder(in context: Context) -> LatestDishEntry {
        let fallback = DishCategory.sampleCategories[0].dishes[0]
        return LatestDishEntry(date: Date(), dish: fallback, cookedDate: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LatestDishEntry) -> Void) {
        completion(makeEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestDishEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(14400)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    
    private func makeEntry() -> LatestDishEntry {
        if let latest = WidgetDataProvider.latestCookedDish() {
            return LatestDishEntry(date: Date(), dish: latest.dish, cookedDate: latest.record.date)
        }
        let fallback = DishCategory.sampleCategories[0].dishes[0]
        return LatestDishEntry(date: Date(), dish: fallback, cookedDate: Date())
    }
}

struct LatestDishWidgetView: View {
    let entry: LatestDishEntry
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .overlay {
                    WidgetDishImage(imageName: entry.dish.imageName)
                }
                .clipped()
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(alignment: .leading, spacing: 4) {
                WidgetBrandLogoView(
                    nickname: WidgetDataProvider.loadUserNickname(),
                    fontSize: 10.5,
                    isLightOnDark: true
                )
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                    Text("最近下厨 · \(relativeDayText(entry.cookedDate))")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                
                Spacer()
                
                Text(entry.dish.name)
                    .font(.system(size: 14.5, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                
                HStack(spacing: 5) {
                    Text(entry.dish.cookingTime)
                    Text("·")
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", entry.dish.rating))
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            }
            .padding(12)
        }
        .widgetURL(URL(string: "mealcoll://dish?id=\(entry.dish.id)"))
        .containerBackground(for: .widget) {
            Color.black
        }
    }
    
    private func relativeDayText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        if days > 0 && days <= 7 { return "\(days)天前" }
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

struct MealCollLatestDishWidget: Widget {
    let kind = "MealCollLatestDishWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LatestDishProvider()) { entry in
            LatestDishWidgetView(entry: entry)
        }
        .configurationDisplayName("最近一次下厨")
        .description("展示你最近一次打卡做过的拿手菜")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

