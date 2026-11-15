import SwiftUI

/// 待入库菜谱全屏详情视图（原路几何展开与收回，支持下滑或右滑手势丝滑收回到待入库列表）
public struct PendingRecipeFullscreenDetailView: View {
    public let item: PendingRecipeItem
    public let animationNamespace: Namespace.ID
    public let onCommitToCategory: (PendingRecipeItem) -> Void
    public let onDismiss: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var hasHapticTriggered: Bool = false
    
    public init(
        item: PendingRecipeItem,
        animationNamespace: Namespace.ID,
        onCommitToCategory: @escaping (PendingRecipeItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.animationNamespace = animationNamespace
        self.onCommitToCategory = onCommitToCategory
        self.onDismiss = onDismiss
    }
    
    private var pullDistance: CGFloat {
        max(dragOffset.height, dragOffset.width)
    }
    
    private var backdropOpacity: Double {
        let dragFade = Double(pullDistance / 400.0)
        return max(0.02, 0.45 - dragFade * 0.40)
    }
    
    private var currentScale: CGFloat {
        max(0.85, 1.0 - (pullDistance / 1600.0))
    }
    
    public var body: some View {
        ZStack {
            // 半透明暗化背景（轻点收回）
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    triggerDismiss()
                }
            
            // 全屏容器
            VStack(spacing: 0) {
                // 顶部抓手条与关闭栏
                ZStack {
                    Capsule()
                        .fill(Color(uiColor: .systemGray3))
                        .frame(width: 38, height: 4.8)
                    
                    HStack {
                        FrostedCircleButton(iconName: "xmark", size: 36, iconSize: 13) {
                            triggerDismiss()
                        }
                        
                        Spacer()
                        
                        Text("下滑或右滑收回")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                // 完整可滚动内容
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 封面大图
                        ZStack(alignment: .bottomLeading) {
                            if let data = item.coverImageData, let uiImg = UIImage(data: data) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 230)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(22)
                            } else {
                                Image("dish_kungpao")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 230)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(22)
                            }
                            
                            // 待入库标签
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10.5))
                                Text("待入库")
                                    .font(.system(size: 11.5, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                            .padding(14)
                        }
                        .matchedGeometryEffect(id: "pending_card_cover_\(item.id)", in: animationNamespace)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                        
                        // 2. 菜谱标题与卖点
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title)
                                .font(.system(size: 25, weight: .bold, design: .serif))
                                .foregroundColor(.primary)
                                .matchedGeometryEffect(id: "pending_card_title_\(item.id)", in: animationNamespace)
                            
                            Text(item.englishTitle)
                                .font(.system(size: 13.5, weight: .medium, design: .serif))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                            
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.system(size: 13.5, weight: .regular))
                                    .foregroundColor(Color.accentColor)
                                    .padding(.top, 2)
                            }
                        }
                        
                        // 3. 核心参数指标徽章
                        HStack(spacing: 8) {
                            metaBadge(icon: "chart.bar.fill", title: "难度", value: item.difficulty)
                            metaBadge(icon: "timer", title: "用时", value: item.cookingTime)
                            metaBadge(icon: "takeoutbag.and.cup.and.straw.fill", title: "食材", value: "\(item.ingredientCount) 种")
                            metaBadge(icon: "flame.fill", title: "热量", value: "\(item.calories) kcal")
                        }
                        
                        // 4. 菜品风味故事与详述
                        if !item.descriptionText.isEmpty {
                            Text(item.descriptionText)
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .foregroundColor(Color(uiColor: .label).opacity(0.85))
                                .lineSpacing(5.5)
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // 5. 严选食材 (主料与辅料)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("严选食材")
                                .font(.system(size: 16, weight: .bold))
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
                        
                        // 6. 调料严格量化对齐
                        if !item.seasonings.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("调味配比")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 8) {
                                    ForEach(item.seasonings) { s in
                                        seasoningBar(seasoning: s)
                                    }
                                }
                            }
                        }
                        
                        // 7. 制作工序与步骤
                        if !item.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("制作步骤")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 16) {
                                    ForEach(item.steps) { step in
                                        stepRow(step: step)
                                    }
                                }
                            }
                        }
                        
                        // 8. 主厨复盘与避坑建议
                        if !item.chefNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tips")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                ForEach(item.chefNotes, id: \.self) { note in
                                    HStack(alignment: .top, spacing: 7) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 12.5))
                                            .foregroundColor(.orange)
                                            .padding(.top, 2)
                                        Text(note)
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(uiColor: .secondaryLabel))
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // 9. 底部入库按钮：黑底白字，改名为「入库」
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onCommitToCategory(item)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.badge.plus")
                                Text("入库")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.20), radius: 8, y: 3)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 34)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(uiColor: .systemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: pullDistance > 0 ? 28 : 0, style: .continuous))
                    .matchedGeometryEffect(id: "pending_card_bg_\(item.id)", in: animationNamespace)
                    .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
            )
            .offset(x: max(0, dragOffset.width), y: max(0, dragOffset.height))
            .scaleEffect(currentScale)
            // 下滑或右滑手势收回
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let w = max(0, value.translation.width)
                        let h = max(0, value.translation.height)
                        dragOffset = CGSize(width: w, height: h)
                        
                        let dist = max(w, h)
                        if dist > 75 && !hasHapticTriggered {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            hasHapticTriggered = true
                        } else if dist <= 75 && hasHapticTriggered {
                            hasHapticTriggered = false
                        }
                    }
                    .onEnded { value in
                        let w = value.translation.width
                        let h = value.translation.height
                        if h > 75 || w > 75 || value.predictedEndTranslation.height > 150 || value.predictedEndTranslation.width > 150 {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            triggerDismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                dragOffset = .zero
                                hasHapticTriggered = false
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
    
    private func triggerDismiss() {
        onDismiss()
    }
    
    // MARK: - Subcomponents
    @ViewBuilder
    private func metaBadge(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.accentColor)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
    
    @ViewBuilder
    private func ingredientCapsule(name: String, amount: String, isEstimated: Bool) -> some View {
        HStack(spacing: 5) {
            Text(name)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(.primary)
            
            Text(amount)
                .font(.system(size: 11.5))
                .foregroundColor(Color(uiColor: .secondaryLabel))
            
            if isEstimated {
                Text("估")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6.5)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private func seasoningBar(seasoning: PendingRecipeItem.RecipeSeasoningItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(seasoning.name)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.primary)
                Text(seasoning.english)
                    .font(.system(size: 10))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
            }
            .frame(width: 82, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemBackground))
                    
                    Capsule()
                        .fill(Color(red: 0.27, green: 0.20, blue: 0.16)) // 经典深棕色
                        .frame(width: max(18, geo.size.width * CGFloat(min(1.0, max(0.15, seasoning.ratio)))))
                        .overlay(
                            Text(seasoning.amount)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, 8),
                            alignment: .leading
                        )
                }
            }
            .frame(height: 28)
        }
    }
    
    @ViewBuilder
    private func stepRow(step: PendingRecipeItem.RecipeStepItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(step.number)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.primary)
                    .clipShape(Circle())
                
                Text(step.title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !step.durationBadge.isEmpty {
                    Text(step.durationBadge)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            
            Text(step.text)
                .font(.system(size: 13))
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .lineSpacing(3.5)
                .padding(.leading, 34)
            
            if let data = step.stepImageData, let stepImg = UIImage(data: data) {
                Image(uiImage: stepImg)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipped()
                    .cornerRadius(14)
                    .padding(.leading, 34)
            }
        }
        .padding(.vertical, 4)
    }
}

