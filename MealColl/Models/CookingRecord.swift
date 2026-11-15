import Foundation

public struct CookingRecord: Identifiable, Hashable {
    public let id: String
    public let date: Date
    public let dishId: String
    public let note: String?
    
    public init(id: String = UUID().uuidString, date: Date, dishId: String, note: String? = nil) {
        self.id = id
        self.date = date
        self.dishId = dishId
        self.note = note
    }
}

extension CookingRecord {
    // Generate sample records for recent days in current month
    public static func sampleRecords(dishes: [Dish]) -> [CookingRecord] {
        let calendar = Calendar.current
        let today = Date()
        var records: [CookingRecord] = []
        
        let dishMap = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        
        // Days offset: e.g. -1, -2, -4, -6, -8, today
        let history: [(daysAgo: Int, dishId: String, note: String)] = [
            (0, "rice_claypot", "午餐：焦香锅巴太绝了，加了一颗溏心蛋"),
            (1, "noodles_beef", "晚餐：自制手拉清汤牛肉面，配热油泼辣子"),
            (3, "dish_beef", "晚餐：小炒黄牛肉，镬气十足猛火十秒出锅"),
            (5, "drink_mango", "下午茶：自制杨枝甘露，多肉红西柚粒"),
            (7, "dish_kungpao", "晚餐：经典宫保鸡丁，甜酸糊辣开胃下饭"),
            (9, "rice_unagi", "午餐：炙烤蒲烧鳗鱼饭，浓郁酱汁沁入米芯")
        ]
        
        for item in history {
            if let date = calendar.date(byAdding: .day, value: -item.daysAgo, to: today),
               dishMap[item.dishId] != nil {
                records.append(
                    CookingRecord(
                        id: "record_\(item.dishId)_\(item.daysAgo)",
                        date: date,
                        dishId: item.dishId,
                        note: item.note
                    )
                )
            }
        }
        
        return records
    }
}

