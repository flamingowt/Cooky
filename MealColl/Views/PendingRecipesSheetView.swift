import SwiftUI

/// 待入库菜单列表视图（点击卡片就地向下拉长展现全部，再次点击平滑收回）
public struct PendingRecipesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var queueManager = PendingRecipeQueueManager.shared
    @ObservedObject private var dataManager = RecipeDataManager.shared
    @ObservedObject private var workflowManager = RecipeAIWorkflowManager.shared
    
    // 当前展开的菜谱 ID（为 nil 时全部收起）
    @State private var expandedItemId: String? = nil
    @State private var selectedItemForImport: PendingRecipeItem? = nil
    @State private var activeGalleryItem: PendingRecipeItem? = nil
    @State private var activeGalleryStepIndex: Int = 0
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if queueManager.pendingItems.isEmpty {
                    emptyQueueView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(queueManager.pendingItems) { item in
                                let isExpanded = (expandedItemId == item.id)
                                
                                pendingAccordionCard(for: item, isExpanded: isExpanded)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("待入库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .sheet(item: $activeGalleryItem) { galleryItem in
                pendingStepGalleryOverlay(for: galleryItem)
            }
            .sheet(item: $selectedItemForImport) { item in
                CategorySelectionModal(recipeItem: item) { targetCatId in
                    queueManager.commitToCategory(item: item, categoryId: targetCatId)
                    selectedItemForImport = nil
                    if queueManager.pendingItems.isEmpty {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyQueueView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: 76, height: 76)
                Image(systemName: "tray")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text("队列空空如也")
                .font(.system(size: 17, weight: .bold))
            Text("点击首页加号导入短视频、图文或链接，生成的菜谱会暂存在这里等待分类入库。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
    }
    
    // MARK: - Accordion Recipe Card (可向下拉长展开/收回的卡片)
    private func pendingAccordionCard(for item: PendingRecipeItem, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: 可点区域（点击展开，展开后点击任意位置立即收回）
            VStack(alignment: .leading, spacing: 14) {
                // MARK: 1. 结构完全稳定的 Header（折叠与展开共用一套几何骨架，杜绝文字飞移与布局跳动）
                HStack(alignment: .top, spacing: 12) {
                    // 固定尺寸左侧微缩图（正在解析时显示矢量动效，排队中显示等待图标，其余显示封面图）
                    if item.status == .processing {
                        ZStack {
                            Color(uiColor: .secondarySystemGroupedBackground)
                            RecipeParsingGraphicStage(isCompact: true)
                                .scaleEffect(0.52)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
                        )
                    } else if item.status == .queued {
                        ZStack {
                            Color(uiColor: .secondarySystemGroupedBackground)
                            VStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("排队中")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
                        )
                    } else {
                        coverImageView(for: item)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text(item.title)
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer(minLength: 6)
                            
                            if item.isPendingOrActive {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 32, height: 32)
                            } else {
                                // 专用的展开/收回状态指示图标
                                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(isExpanded ? .primary : Color(uiColor: .tertiaryLabel))
                                    .frame(width: 32, height: 32)
                            }
                        }
                        
                        if !item.englishTitle.isEmpty {
                            Text(item.englishTitle)
                                .font(.system(size: 11.5, weight: .medium, design: .serif))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // 核心参数指标药丸（或解析中/排队中/非食物/失败状态标签）
                        if item.status == .processing {
                            HStack(spacing: 5) {
                                ProgressView()
                                    .scaleEffect(0.65)
                                Text("正在解析中...")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                            
                            Text(workflowManager.statusMessage.isEmpty ? "轻触返回首页查看解析动效" : workflowManager.statusMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        } else if item.status == .queued {
                            HStack(spacing: 5) {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text("排队等待中...")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                            
                            Text("前序任务完成后自动开始，轻触查看解析动效")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        } else if item.status == .failed {
                            HStack(spacing: 5) {
                                Image(systemName: "xmark.octagon.fill")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text("解析失败")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundColor(Color(red: 0.85, green: 0.25, blue: 0.20))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.98, green: 0.90, blue: 0.88))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                            
                            Text(item.errorReason ?? "解析失败，请点击「重新识别」重试")
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                                .lineLimit(isExpanded ? 4 : 2)
                                .padding(.top, 2)
                        } else if item.isNotFood {
                            HStack(spacing: 5) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text("非食物内容")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundColor(Color(red: 0.85, green: 0.30, blue: 0.15))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.98, green: 0.90, blue: 0.88))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                            
                            Text(item.errorReason ?? "该内容非食物或菜谱相关，无法生成菜谱")
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                                .lineLimit(isExpanded ? 4 : 2)
                                .padding(.top, 2)
                        } else {
                            HStack(spacing: 5) {
                                metricBadge(label: item.difficulty)
                                metricBadge(label: item.cookingTime)
                                metricBadge(label: "\(item.ingredientCount) 种食材")
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                
                // MARK: 2. 展开内容 vs 折叠预览
                if item.isPendingOrActive {
                    EmptyView()
                } else if isExpanded {
                    if item.status == .failed {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "xmark.octagon.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.85, green: 0.25, blue: 0.20))
                                .padding(.top, 1)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("解析未完成")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.primary)
                                Text(item.errorReason ?? "网络或模型解析异常，请点击「重新识别」重试，或删除该条记录。")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.99, green: 0.94, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if item.isNotFood {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.85, green: 0.30, blue: 0.15))
                                .padding(.top, 1)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("无法识别为菜谱")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.primary)
                                Text(item.errorReason ?? "该内容非食物或菜谱相关，请确认链接/图片后点击「重新识别」或删除。")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.99, green: 0.94, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                        // 宽幅完整封面图（仅图片中心区域点击打开图片列表，边缘及卡片其余区域点击收起卡片）
                        ZStack(alignment: .bottomTrailing) {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .overlay {
                                    coverImageView(for: item)
                                        .allowsHitTesting(false)
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            
                            HStack(spacing: 6) {
                                Text("\(item.calories) kcal")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.black.opacity(0.55)))
                            }
                            .padding(10)
                            .allowsHitTesting(false)
                            
                            // 仅中心区域触发图片列表
                            GeometryReader { imgGeo in
                                Color.clear
                                    .frame(width: imgGeo.size.width * 0.56, height: imgGeo.size.height * 0.58)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        activeGalleryStepIndex = -1
                                        activeGalleryItem = item
                                    }
                                    .position(x: imgGeo.size.width / 2, y: imgGeo.size.height / 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        
                        // 副标题
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.accentColor)
                        }
                        
                        // 1. 菜品风味故事
                        if !item.descriptionText.isEmpty {
                            Text(item.descriptionText)
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .foregroundColor(Color(uiColor: .label).opacity(0.85))
                                .lineSpacing(4.5)
                                .padding(12)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        // 2. 严选食材（主料与辅料完整展开）
                        VStack(alignment: .leading, spacing: 10) {
                            Text("严选食材")
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if !item.mainIngredients.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("主料")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(item.mainIngredients) { ing in
                                            let mapped = IngredientIconMapper.shared.lookup(name: ing.name, category: .main)
                                            ingredientChip(name: mapped.name, amount: ing.amount, isEstimated: ing.isEstimated)
                                        }
                                    }
                                }
                            }
                            
                            if !item.auxiliaryIngredients.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("辅料")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(item.auxiliaryIngredients) { ing in
                                            let mapped = IngredientIconMapper.shared.lookup(name: ing.name, category: .auxiliary)
                                            ingredientChip(name: mapped.name, amount: ing.amount, isEstimated: ing.isEstimated)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 3. 调味配比（量化对齐进度胶囊）
                        if !item.seasonings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("调味配比")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 8) {
                                    ForEach(item.seasonings) { s in
                                        seasoningBar(seasoning: s)
                                    }
                                }
                            }
                        }
                        
                        // 4. 完整制作步骤
                        if !item.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("制作步骤 (\(item.steps.count) 步)")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 12) {
                                    ForEach(Array(item.steps.enumerated()), id: \.element.id) { idx, step in
                                        stepRow(step: step, stepIndex: idx, item: item)
                                    }
                                }
                            }
                        }
                        
                        // 5. Tips
                        if !item.chefNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tips")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                ForEach(item.chefNotes, id: \.self) { note in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(.orange)
                                            .padding(.top, 2)
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(uiColor: .secondaryLabel))
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        // 6. 底部轻触收回提示
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .bold))
                            Text("轻触卡片任意处收回")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .transition(.opacity)
                    }
                } else if !item.isNotFood && item.status != .failed {
                    // 折叠状态下的横滑食材小预览
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.mainIngredients) { ing in
                                let mapped = IngredientIconMapper.shared.lookup(name: ing.name, category: .main)
                                ingredientChip(name: mapped.name, amount: ing.amount, isEstimated: ing.isEstimated)
                            }
                            ForEach(item.auxiliaryIngredients) { ing in
                                let mapped = IngredientIconMapper.shared.lookup(name: ing.name, category: .auxiliary)
                                ingredientChip(name: mapped.name, amount: ing.amount, isEstimated: ing.isEstimated)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if item.isPendingOrActive {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    workflowManager.showParsingOverlay = true
                    dismiss()
                } else {
                    // 折叠时点击展开，展开后点击卡片任意地方平滑收回
                    toggleCardExpansion(for: item.id)
                }
            }
            
            Divider()
            
            // 底部操作栏（删除 + 重新识别 + 黑底白字入库）
            HStack(spacing: 10) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    queueManager.remove(byId: item.id)
                }) {
                    Text("删除")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red.opacity(0.85))
                }
                
                Spacer()
                
                if item.isPendingOrActive {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        workflowManager.showParsingOverlay = true
                        dismiss()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                            Text("查看解析动效")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                } else {
                    let isRetrying = workflowManager.retryingItemIds.contains(item.id)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            await workflowManager.reprocessPendingItem(item)
                        }
                    }) {
                        HStack(spacing: 5) {
                            if isRetrying {
                                ProgressView()
                                    .scaleEffect(0.75)
                                Text("识别中...")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("重新识别")
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                    .disabled(isRetrying)
                }
                
                if !item.isPendingOrActive && !item.isNotFood && item.status != .failed {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedItemForImport = item
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.badge.plus")
                            Text("入库")
                        }
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        )
        .clipped()
    }
    
    // MARK: - Toggle Animation Helper
    private func toggleCardExpansion(for id: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            if expandedItemId == id {
                expandedItemId = nil
            } else {
                expandedItemId = id
            }
        }
    }
    
    // MARK: - Cover Image Helper
    @ViewBuilder
    private func coverImageView(for item: PendingRecipeItem, fitMode: Bool = false) -> some View {
        let baseImg: Image = {
            if let data = item.coverImageData, let uiImg = UIImage(data: data) {
                return Image(uiImage: uiImg)
            } else if item.title.contains("三文鱼") {
                return Image("ing_salmon")
            } else if item.title.contains("面") {
                return Image("noodles_beef")
            } else {
                return Image("dish_kungpao")
            }
        }()
        if fitMode {
            baseImg
                .resizable()
                .scaledToFit()
        } else {
            baseImg
                .resizable()
                .scaledToFill()
        }
    }
    
    // MARK: - Subcomponents
    private func metricBadge(label: String) -> some View {
        Text(label)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(Capsule())
    }
    
    private func ingredientChip(name: String, amount: String, isEstimated: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.primary)
            
            Text(amount)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
            
            if isEstimated {
                Text("估")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 3)
                    .background(Color(uiColor: .systemGray5))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(uiColor: .systemBackground))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5))
    }
    
    @ViewBuilder
    private func seasoningBar(seasoning: PendingRecipeItem.RecipeSeasoningItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(seasoning.name)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.primary)
                Text(seasoning.english)
                    .font(.system(size: 9.5))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
            }
            .frame(width: 78, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .systemBackground))
                    
                    Capsule()
                        .fill(Color(red: 0.27, green: 0.20, blue: 0.16)) // 统一经典深棕色
                        .frame(width: max(16, geo.size.width * CGFloat(min(1.0, max(0.15, seasoning.ratio)))))
                        .overlay(
                            Text(seasoning.amount)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, 6),
                            alignment: .leading
                        )
                }
            }
            .frame(height: 24)
        }
    }
    
    @ViewBuilder
    private func stepRow(step: PendingRecipeItem.RecipeStepItem, stepIndex: Int, item: PendingRecipeItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(step.number)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.primary)
                    .clipShape(Circle())
                
                Text(step.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !step.durationBadge.isEmpty {
                    Text(step.durationBadge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(Capsule())
                }
            }
            
            Text(step.text)
                .font(.system(size: 12))
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .lineSpacing(3)
                .padding(.leading, 30)
            
            if let data = step.stepImageData, let stepImg = UIImage(data: data) {
                ZStack(alignment: .bottomTrailing) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .overlay {
                            Image(uiImage: stepImg)
                                .resizable()
                                .scaledToFill()
                                .allowsHitTesting(false)
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .padding(8)
                        .allowsHitTesting(false)
                    
                    // 仅中心区域触发图片列表，边缘点击收起卡片
                    GeometryReader { imgGeo in
                        Color.clear
                            .frame(width: imgGeo.size.width * 0.56, height: imgGeo.size.height * 0.58)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                activeGalleryStepIndex = stepIndex
                                activeGalleryItem = item
                            }
                            .position(x: imgGeo.size.width / 2, y: imgGeo.size.height / 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private func pendingStepGalleryOverlay(for item: PendingRecipeItem) -> some View {
        let stepsWithImages = Array(item.steps.enumerated()).filter { $0.element.stepImageData != nil }
        ZStack(alignment: .top) {
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        activeGalleryItem = nil
                    }
                }
            
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        Text("步骤图片与做法")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            activeGalleryItem = nil
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.20)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 24) {
                            // 封面大图
                            VStack(alignment: .leading, spacing: 10) {
                                Text("成品参考")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.65))
                                coverImageView(for: item, fitMode: true)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .id(-1)
                            
                            // 步骤图序列
                            ForEach(stepsWithImages, id: \.offset) { idx, st in
                                if let data = st.stepImageData, let img = UIImage(data: data) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("STEP \(st.number) · \(st.title)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text("\(idx + 1) / \(item.steps.count)")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        Text(st.text)
                                            .font(.system(size: 13.5))
                                            .foregroundColor(.white.opacity(0.88))
                                            .lineSpacing(4)
                                    }
                                    .id(idx)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activeGalleryItem = nil
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation {
                                proxy.scrollTo(activeGalleryStepIndex, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 分类入库选择模态弹窗
private struct CategorySelectionModal: View {
    let recipeItem: PendingRecipeItem
    let onCommit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = RecipeDataManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("请选择要归类的菜谱分类")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                List {
                    ForEach(dataManager.categories) { cat in
                        Button(action: {
                            onCommit(cat.id)
                            dismiss()
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 18))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("\(cat.count) 道菜品 · \(cat.subtitle)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("存入分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
