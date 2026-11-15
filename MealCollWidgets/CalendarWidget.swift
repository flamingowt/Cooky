import WidgetKit
import SwiftUI

struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let nickname: String
    let recordsByDay: [Date: Dish]
    let monthCount: Int
}

struct CalendarWidgetProvider: TimelineProvider {
    private let calendar = Calendar.current
    
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        makeEntry(for: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(for: now)
        let nextRefresh = calendar.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(14400)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
    
    private func makeEntry(for date: Date) -> CalendarWidgetEntry {
        let categories = WidgetDataProvider.loadCategories()
        let dishes = WidgetDataProvider.allDishes(from: categories)
        let dishMap = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        let records = WidgetDataProvider.loadCookingRecords(dishes: dishes)
        
        var map: [Date: Dish] = [:]
        var monthCount = 0
        for rec in records {
            let day = calendar.startOfDay(for: rec.date)
            if map[day] == nil, let dish = dishMap[rec.dishId] {
                map[day] = dish
            }
            if calendar.isDate(rec.date, equalTo: date, toGranularity: .month) {
                monthCount += 1
            }
        }
        return CalendarWidgetEntry(
            date: date,
            nickname: WidgetDataProvider.loadUserNickname(),
            recordsByDay: map,
            monthCount: monthCount
        )
    }
}

struct CalendarWidgetView: View {
    let entry: CalendarWidgetEntry
    private let calendar = Calendar.current
    private let daysOfWeek = ["一", "二", "三", "四", "五", "六", "日"]
    
    var body: some View {
        let days = generateDaysInMonth(for: entry.date)
        let rowCount = max(5, Int(ceil(Double(days.count) / 7.0)))
        
        GeometryReader { geo in
            let horizontalPad: CGFloat = 16
            let verticalPad: CGFloat = 14
            let headerHeight: CGFloat = 38
            let weekdayHeight: CGFloat = 16
            let sectionGap: CGFloat = 8
            let rowSpacing: CGFloat = 6
            let availableGridHeight = max(180, geo.size.height - verticalPad * 2 - headerHeight - weekdayHeight - sectionGap * 2)
            let rowHeight = (availableGridHeight - rowSpacing * CGFloat(rowCount - 1)) / CGFloat(rowCount)
            let avatarSize = min(32, max(24, rowHeight - 16))
            
            VStack(spacing: sectionGap) {
                // 顶部品牌 Logo、月份与下厨次数徽章
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        WidgetBrandLogoView(nickname: entry.nickname, fontSize: 13.5)
                        Text(monthYearString(from: entry.date))
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Text("本月 \(entry.monthCount) 道")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
                .frame(height: headerHeight)
                
                // 星期标题栏
                HStack(spacing: 4) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: weekdayHeight)
                
                // 日历网格（按可用高度均分每行，消除底部留白）
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: rowSpacing) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date = date {
                            dayCell(for: date, rowHeight: rowHeight, avatarSize: avatarSize)
                        } else {
                            Color.clear
                                .frame(height: rowHeight)
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPad)
            .padding(.vertical, verticalPad)
        }
        .widgetURL(URL(string: "mealcoll://calendar"))
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
    
    @ViewBuilder
    private func dayCell(for date: Date, rowHeight: CGFloat, avatarSize: CGFloat) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let dish = entry.recordsByDay[dayStart]
        
        VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 10.5, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .orange : Color(uiColor: .secondaryLabel))
            
            if let dish = dish {
                WidgetDishImage(imageName: dish.imageName)
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isToday ? Color.orange : Color.white, lineWidth: isToday ? 1.8 : 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 2.5, y: 1)
            } else {
                Circle()
                    .fill(isToday ? Color.orange.opacity(0.14) : Color.clear)
                    .frame(width: avatarSize - 2, height: avatarSize - 2)
                    .overlay(
                        isToday ? Circle().stroke(Color.orange, lineWidth: 1.2) : nil
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
    
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count else {
            return []
        }
        let firstDay = monthInterval.start
        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = (weekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in 1...daysInMonth {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }
        return days
    }
}

struct MealCollCalendarWidget: Widget {
    let kind = "MealCollCalendarWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("下厨日历")
        .description("在桌面直接查看每日下厨美食印记")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

