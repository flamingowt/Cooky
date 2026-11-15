import SwiftUI

/// 待入库菜谱 3D 翻转展开详情卡（与首页卡牌翻转、下滑/右滑手势收起逻辑 100% 保持一致）
public struct FlippingPendingRecipeDetailCard: View {
    public let item: PendingRecipeItem
    public let onCommitToCategory: (PendingRecipeItem) -> Void
    public let onDismiss: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDismissing: Bool = false
    @State private var appearAnimation: Bool = false
    @State private var hasHapticTriggered: Bool = false
    
    public init(
        item: PendingRecipeItem,
        onCommitToCategory: @escaping (PendingRecipeItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.onCommitToCategory = onCommitToCategory
        self.onDismiss = onDismiss
    }
    
    // Dynamic 3D Y-axis flip angle
    // Opens with a 180° flip into view, and on dismiss flips 180° back
    private var flipAngle: Double {
        if !appearAnimation {
            return -180.0
        }
        if isDismissing {
            return 180.0
        }
        // Subtle 3D tilt tracking finger drag (尤其是右滑时的倾斜感)
        return Double(dragOffset.width / 18.0)
    }
    
    private var cardScale: CGFloat {
        if !appearAnimation || isDismissing {
            return 0.65
        }
        let dragDistance = max(dragOffset.height, dragOffset.width)
        return max(0.80, 1.0 - (dragDistance / 1200.0))
    }
    
    private var backdropOpacity: Double {
        if !appearAnimation || isDismissing {
            return 0.0
        }
        let dragDistance = max(dragOffset.height, dragOffset.width)
        let dragFade = Double(dragDistance / 350.0)
        return max(0.04, 0.50 - dragFade * 0.40)
    }
    
    public var body: some View {
        ZStack {
            // Blurred Dimmed Backdrop (点击背景收起)
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    triggerDismiss()
                }
            
            // Floating 3D Detail Card
            VStack(spacing: 0) {
                // Top Grabber & Controls Bar
                ZStack {
                    Capsule()
                        .fill(Color(uiColor: .systemGray3))
                        .frame(width: 36, height: 4.5)
                    
                    HStack {
                        FrostedCircleButton(iconName: "xmark", size: 34, iconSize: 12) {
                            triggerDismiss()
                        }
                        
                        Spacer()
                        
                        // 提示手势小标签
                        Text("下滑或右滑收起")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                
                // Scrollable Full Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. Cover Image
                        ZStack(alignment: .bottomLeading) {
                            if let data = item.coverImageData, let uiImg = UIImage(data: data) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(18)
                            } else {
                                Image("dish_kungpao")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(18)
                            }
                            
                            // Tag badge
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("待入库菜谱")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                            .padding(12)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
                        
                        // 2. Titles & Subtitle
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 23, weight: .bold, design: .serif))
                                .foregroundColor(.primary)
                            
                            Text(item.englishTitle)
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                            
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.accentColor)
                                    .padding(.top, 2)
                            }
                        }
                        
                        // 3. Meta Badges
                        HStack(spacing: 8) {
                            metaBadge(icon: "chart.bar.fill", title: "难度", value: item.difficulty)
                            metaBadge(icon: "timer", title: "用时", value: item.cookingTime)
                            metaBadge(icon: "takeoutbag.and.cup.and.straw.fill", title: "食材", value: "\(item.ingredientCount) 种")
                            metaBadge(icon: "flame.fill", title: "热量", value: "\(item.calories) kcal")
                        }
                        
                        // 4. Description Story
                        if !item.descriptionText.isEmpty {
                            Text(item.descriptionText)
                                .font(.system(size: 13.5, weight: .regular, design: .serif))
                                .foregroundColor(Color(uiColor: .label).opacity(0.85))
                                .lineSpacing(5)
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemBackground).opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        
                        // 5. Ingredients Section (主料 & 辅料)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("严选食材")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if !item.mainIngredients.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("主料")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(uiColor: .secondaryLabel))
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(item.mainIngredients) { ing in
                                            let mapped = IngredientIconMapper.shared.lookup(name: ing.name, category: .main)
                                            ingredientCapsule(name: mapped.name, amount: ing.amount, isEstimated: ing.isEstimated)
                                        }
                                    }
                                }
                            }
                            
                            if !item.auxiliaryIngredients.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("辅料")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(uiColor: .secondaryLabel))
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(item.auxiliaryIngredients) { ing in
                                            let mapped = IngredientIconMapper.shared.lookup(name: ing.name, category: .auxiliary)
                                            ingredientCapsule(name: mapped.name, amount: ing.amount, isEstimated: ing.isEstimated)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 6. Seasonings (调料严格量化对齐)
                        if !item.seasonings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("调味配比")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 8) {
                                    ForEach(item.seasonings) { s in
                                        seasoningBar(seasoning: s)
                                    }
                                }
                            }
                        }
                        
                        // 7. Cooking Steps
                        if !item.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("制作步骤")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 14) {
                                    ForEach(item.steps) { step in
                                        stepRow(step: step)
                                    }
                                }
                            }
                        }
                        
                        // 8. Chef's Notes
                        if !item.chefNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tips")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                ForEach(item.chefNotes, id: \.self) { note in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                            .padding(.top, 2)
                                        Text(note)
                                            .font(.system(size: 12.5))
                                            .foregroundColor(Color(uiColor: .secondaryLabel))
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        
                        // 9. Commit to Category Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onCommitToCategory(item)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.badge.plus")
                                Text("按类别入库加入菜单库")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 18)
                }
            }
            .frame(maxWidth: 360)
            .frame(maxHeight: 620)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 12)
            )
            .offset(x: max(0, dragOffset.width), y: max(0, dragOffset.height))
            .scaleEffect(cardScale)
            // 3D Horizontal Flip along Y axis
            .rotation3DEffect(
                .degrees(flipAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            // Pull-down & Swipe-Right Dismiss Gestures
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // 同时响应向右滑动与向下滑动
                        let w = max(0, value.translation.width)
                        let h = max(0, value.translation.height)
                        dragOffset = CGSize(width: w, height: h)
                        
                        let totalDist = max(w, h)
                        if totalDist > 85 && !hasHapticTriggered {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            hasHapticTriggered = true
                        } else if totalDist <= 85 && hasHapticTriggered {
                            hasHapticTriggered = false
                        }
                    }
                    .onEnded { value in
                        let w = value.translation.width
                        let h = value.translation.height
                        if h > 85 || w > 85 || value.predictedEndTranslation.height > 160 || value.predictedEndTranslation.width > 160 {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            triggerDismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                dragOffset = .zero
                                hasHapticTriggered = false
                            }
                        }
                    }
            )
        }
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.78, blendDuration: 0)) {
                appearAnimation = true
            }
        }
    }
    
    private func triggerDismiss() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            isDismissing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            onDismiss()
        }
    }
    
    // MARK: - Subcomponents
    @ViewBuilder
    private func metaBadge(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.accentColor)
            Text(value)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    @ViewBuilder
    private func ingredientCapsule(name: String, amount: String, isEstimated: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
            
            Text(amount)
                .font(.system(size: 11))
                .foregroundColor(Color(uiColor: .secondaryLabel))
            
            if isEstimated {
                Text("估")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 3)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private func seasoningBar(seasoning: PendingRecipeItem.RecipeSeasoningItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(seasoning.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text(seasoning.english)
                    .font(.system(size: 10))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
            }
            .frame(width: 80, alignment: .leading)
            
            // 量化对齐进度胶囊（系统高级深色）
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemBackground))
                    
                    Capsule()
                        .fill(Color(red: 0.27, green: 0.20, blue: 0.16)) // 经典深棕色
                        .frame(width: max(16, geo.size.width * CGFloat(min(1.0, max(0.15, seasoning.ratio)))))
                        .overlay(
                            Text(seasoning.amount)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, 8),
                            alignment: .leading
                        )
                }
            }
            .frame(height: 26)
        }
    }
    
    @ViewBuilder
    private func stepRow(step: PendingRecipeItem.RecipeStepItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(step.number)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.primary)
                    .clipShape(Circle())
                
                Text(step.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !step.durationBadge.isEmpty {
                    Text(step.durationBadge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            
            Text(step.text)
                .font(.system(size: 12.5))
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .lineSpacing(3)
                .padding(.leading, 32)
            
            if let data = step.stepImageData, let stepImg = UIImage(data: data) {
                Image(uiImage: stepImg)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(12)
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
    }
}

