import SwiftUI

public struct RecipeCalendarView: View {
    public let dishes: [Dish]
    @Binding public var cookingRecords: [CookingRecord]
    public let onSelectDish: (Dish, CGRect) -> Void
    public let onGoToRecipes: () -> Void
    public var onTapProfile: () -> Void = {}
    
    @ObservedObject private var dataManager = RecipeDataManager.shared
    
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var dayFrames: [Date: CGRect] = [:]
    
    // Sheets & Modals
    @State private var showSettings: Bool = false
    @State private var showAvatarPicker: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var showVIPSheet: Bool = false
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["一", "二", "三", "四", "五", "六", "日"]
    
    private var dishMap: [String: Dish] {
        Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
    }
    
    public init(
        dishes: [Dish],
        cookingRecords: Binding<[CookingRecord]>,
        onSelectDish: @escaping (Dish, CGRect) -> Void,
        onGoToRecipes: @escaping () -> Void,
        onTapProfile: @escaping () -> Void = {}
    ) {
        self.dishes = dishes
        self._cookingRecords = cookingRecords
        self.onSelectDish = onSelectDish
        self.onGoToRecipes = onGoToRecipes
        self.onTapProfile = onTapProfile
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Header & Profile Section (Image 1 Exact Layout)
                headerSection
                
                // Monthly Calendar Card
                calendarCard
                
                // Selected Date Detail Section
                selectedDayDetailSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .onPreferenceChange(CalendarDayFramePreferenceKey.self) { frames in
            dayFrames = frames
        }
        .fullScreenCover(isPresented: $showSettings) {
            ProfileView {
                showSettings = false
            }
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet()
                .presentationDetents([.fraction(0.55), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(isPresented: $showEditProfile)
        }
        .sheet(isPresented: $showVIPSheet) {
            VIPMembershipView()
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-testSettings") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSettings = true
                }
            }
        }
    }
    
    // MARK: - Header & Profile Section (Image 1 Exact Layout)
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Top Bar Navigation Icons (Image 1: Left 3 icons, Right "消息" pill)
            HStack(spacing: 20) {
                // Left 1: Menu icon -> opens Settings (Image 2)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showSettings = true
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.primary)
                }
                
                // Left 2: Help / FAQ icon
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dataManager.showToast("使用帮助：长按卡片进入编辑模式，支持左右滑动切换页面")
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                }
                
                // Left 3: Scan / Viewfinder icon
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dataManager.showToast("食谱扫码与相册识别功能已就绪")
                }) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Right: "消息" Capsule Pill Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dataManager.showToast("消息中心暂无新动态")
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "envelope")
                            .font(.system(size: 13, weight: .semibold))
                        Text("消息")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.top, 4)
            
            // 2. Avatar & Username / ID Row (Image 1 layout)
            HStack(spacing: 16) {
                // Circular Avatar (Tap to change avatar)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAvatarPicker = true
                }) {
                    MinimalistAvatarView(size: 72, showCameraBadge: false)
                }
                .buttonStyle(SpringyBadgeButtonStyle())
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(dataManager.userNickname)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // ID Number with copy button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        UIPasteboard.general.string = dataManager.userIdNumber
                        dataManager.showToast("已复制私厨号: \(dataManager.userIdNumber)")
                    }) {
                        HStack(spacing: 4) {
                            Text("私厨号:\(dataManager.userIdNumber)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                            
                            Image(systemName: "square.on.square")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 2)
            
            // VIP Banner (VIP颜色换一下 -> 优雅尊贵香槟金渐变，非荧光绿)
            vipBanner
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - VIP Banner (Changed Color: Luxury Champagne Gold & Warm Amber)
    private var vipBanner: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showVIPSheet = true
        }) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.black)
                        
                        Text("VIP")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        
                        if dataManager.isVIP {
                            Text("已激活")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0.984, green: 0.886, blue: 0.655))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.black)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(dataManager.isVIP ? "私厨尊享特权已生效 · 畅享无限 AI 解析与秘制菜谱" : "限时 2 折成为 VIP · 畅享专属秘制菜谱")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                }
                
                Spacer()
                
                Text(dataManager.isVIP ? "查看特权" : "立享 2 折")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.984, green: 0.886, blue: 0.655), // Champagne gold
                                Color(red: 0.929, green: 0.765, blue: 0.455)  // Warm golden amber
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // Helper for Profile Stats Column
    @ViewBuilder
    private func statColumn(count: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(count)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(uiColor: .secondaryLabel))
        }
    }
    
    // Share Kitchen Profile
    private func shareProfile() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let shareText = "【\(dataManager.userNickname)私厨】食谱日历 · 私厨号: \(dataManager.userIdNumber)\n已记录 \(cookingRecords.count) 道下厨美味，欢迎来我的私厨空间！"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Calendar Card
    private var calendarCard: some View {
        VStack(spacing: 12) {
            // Month Title & Internal Switcher
            HStack(spacing: 8) {
                Text(monthYearString(from: currentMonth))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                // Month switcher buttons inside calendar card
                HStack(spacing: 4) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        changeMonth(by: -1)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary.opacity(0.75))
                            .frame(width: 28, height: 28)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        changeMonth(by: 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary.opacity(0.75))
                            .frame(width: 28, height: 28)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentMonth = Date()
                        selectedDate = Date()
                    }
                }) {
                    Text("回到今天")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            // Days of week header
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days Grid
            let days = generateDaysInMonth(for: currentMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        // Empty placeholder
                        Color.clear
                            .frame(height: 54)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 14, y: 6)
        )
    }
    
    // MARK: - Day Cell
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dayKey = calendar.startOfDay(for: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let record = recordForDate(date)
        let dish = record.flatMap { dishMap[$0.dishId] }
        
        Button(action: {
            if isSelected, let dish = dish {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onSelectDish(dish, dayFrames[dayKey] ?? .zero)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedDate = date
                }
            }
        }) {
            VStack(spacing: 2) {
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 11, weight: isToday ? .bold : .medium))
                    .foregroundColor(isToday ? Color.accentColor : (isSelected ? .primary : Color(uiColor: .secondaryLabel)))
                
                // Dish Icon or placeholder
                ZStack {
                    if let dish = dish {
                        // Cooked dish icon with shadow and border
                        DishImageView(dish.imageName)
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.accentColor : Color.white, lineWidth: isSelected ? 2 : 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.18), radius: 3, y: 1.5)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: CalendarDayFramePreferenceKey.self,
                                            value: [dayKey: geo.frame(in: .global)]
                                        )
                                }
                            )
                    } else {
                        Circle()
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                            .frame(width: 30, height: 30)
                            .overlay(
                                isToday ?
                                Circle()
                                    .stroke(Color.accentColor, lineWidth: 1.2)
                                    .frame(width: 26, height: 26)
                                : nil
                            )
                    }
                }
                .frame(height: 34)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Selected Day Detail
    private var selectedDayDetailSection: some View {
        let record = recordForDate(selectedDate)
        let dish = record.flatMap { dishMap[$0.dishId] }
        let dateString = formatDateString(selectedDate)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dateString)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                if calendar.isDateInToday(selectedDate) {
                    Text("今天")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if let dish = dish, let record = record {
                // Dish Card for this day (收起时动画飞回对应日历日期头像)
                let dayKey = calendar.startOfDay(for: selectedDate)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelectDish(dish, dayFrames[dayKey] ?? .zero)
                }) {
                    HStack(spacing: 14) {
                        DishImageView(dish.imageName)
                            .scaledToFill()
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(dish.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.orange)
                                    Text(String(format: "%.1f", dish.rating))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Text(record.note ?? dish.subtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                                .lineLimit(2)
                            
                            HStack(spacing: 8) {
                                Label(dish.cookingTime, systemImage: "timer")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.accentColor)
                                
                                Text("·")
                                    .foregroundColor(.secondary)
                                
                                Text(dish.flavor)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
                    )
                }
                .buttonStyle(ScaleCardButtonStyle())
            } else {
                // Empty state for this day
                VStack(spacing: 12) {
                    Image(systemName: "frying.pan.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                        .padding(.top, 8)
                    
                    Text("这天还没有下厨记录")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                    
                    Button(action: {
                        onGoToRecipes()
                    }) {
                        HStack(spacing: 6) {
                            Text("去食单挑一道菜")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.primary)
                        .clipShape(Capsule())
                    }
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .systemBackground).opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.black.opacity(0.04), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    private var recordsInCurrentMonth: [CookingRecord] {
        cookingRecords.filter { calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month) }
    }
    
    private var recordsByDay: [Date: CookingRecord] {
        Dictionary(
            cookingRecords.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }
    
    private func recordForDate(_ date: Date) -> CookingRecord? {
        let dayStart = calendar.startOfDay(for: date)
        return recordsByDay[dayStart]
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentMonth = newMonth
            }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
    
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
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

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @ObservedObject private var dataManager = RecipeDataManager.shared
    @Binding var isPresented: Bool
    
    @State private var nickname: String = ""
    @State private var bio: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("私厨身份")) {
                    HStack {
                        Text("昵称")
                            .font(.system(size: 15))
                        Spacer()
                        TextField("设置私厨昵称", text: $nickname)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("私厨号")
                            .font(.system(size: 15))
                        Spacer()
                        Text(dataManager.userIdNumber)
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
                
                Section(header: Text("个人简介"), footer: Text("用简短的一两句话，介绍你的美食态度或招牌拿手好菜。")) {
                    TextEditor(text: $bio)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dataManager.updateProfile(nickname: nickname, bio: bio)
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .onAppear {
                nickname = dataManager.userNickname
                bio = dataManager.userBio
            }
        }
    }
}

private struct CalendarDayFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGRect] = [:]
    static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
