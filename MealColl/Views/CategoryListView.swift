import SwiftUI
import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

private class HomeDisplayLinkDriver: NSObject {
    private var displayLink: CADisplayLink?
    weak var scrollView: UIScrollView?
    var onTick: (() -> Void)?
    
    func start(onTick: @escaping () -> Void) {
        stop()
        self.onTick = onTick
        let dl = CADisplayLink(target: self, selector: #selector(handleTick))
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        onTick = nil
    }
    
    @objc private func handleTick() {
        onTick?()
    }
    
    deinit {
        stop()
    }
}

public struct CategoryListView: View {
    @ObservedObject private var dataManager = RecipeDataManager.shared
    @Binding public var selectedCategory: DishCategory?
    public let selectedDishId: String?
    public let onSelectDish: (Dish, CGRect) -> Void
    public let onTapMore: () -> Void
    public var onGoToCalendar: (() -> Void)? = nil
    
    @Namespace private var animationNamespace
    @State private var activeCategory: DishCategory
    @State private var activeCategoryFrame: CGRect = .zero
    @State private var activeFannedDeckCenter: CGPoint = .zero
    @State private var isExpanded: Bool
    @State private var isOverlayActive: Bool
    @State private var showAddCategorySheet: Bool = false
    @State private var showImportRecipeSheet: Bool = false
    @State private var isGooeyMenuOpen: Bool = false
    @State private var showCameraCapture: Bool = false
    @State private var showAlbumPicker: Bool = false
    @State private var selectedPhotosItems: [PhotosPickerItem] = []
    @State private var showPendingQueueSheet: Bool = false
    @ObservedObject private var queueManager = PendingRecipeQueueManager.shared
    @State private var draggedCategoryId: String? = nil
    @State private var dragStartIndex: Int = 0
    @State private var hoverIndex: Int = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var dragInitialTouchY: CGFloat = 0
    @State private var dragCurrentTouchY: CGFloat = 0
    @State private var dragInitialScrollY: CGFloat = 0
    @State private var homeDisplayLinkDriver = HomeDisplayLinkDriver()
    
    private let slotStep: CGFloat = 302
    
    public init(
        categories: [DishCategory] = [],
        selectedCategory: Binding<DishCategory?>,
        selectedDishId: String? = nil,
        onSelectDish: @escaping (Dish, CGRect) -> Void,
        onTapMore: @escaping () -> Void,
        onGoToCalendar: (() -> Void)? = nil
    ) {
        self._selectedCategory = selectedCategory
        self.selectedDishId = selectedDishId
        self.onSelectDish = onSelectDish
        self.onTapMore = onTapMore
        self.onGoToCalendar = onGoToCalendar
        
        let initialList = RecipeDataManager.shared.categories
        let initialCategory = selectedCategory.wrappedValue ?? (initialList.first ?? DishCategory.sampleCategories[0])
        let initiallyExpanded = selectedCategory.wrappedValue != nil
        self._activeCategory = State(initialValue: initialCategory)
        self._isExpanded = State(initialValue: initiallyExpanded)
        self._isOverlayActive = State(initialValue: initiallyExpanded)
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Background (tap to exit edit mode)
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if dataManager.isEditing {
                        dataManager.exitEditMode()
                    }
                }
            
            // Layer 1: Normal Category Cards List (Scrollable, never unmounted)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    // Header: 船长.de私厨 + ...
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Image("brand_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 46, alignment: .leading)
                            
                            let totalDishes = dataManager.categories.reduce(0) { $0 + $1.dishes.count }
                            Text("\(dataManager.categories.count) 大分类 · 精选 \(totalDishes) 款风味佳肴")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                        }
                        
                        Spacer()
                        
                        // Top Right: Done button in edit mode, OR Plus + Calendar swipe indicator normally
                        ZStack(alignment: .trailing) {
                            if dataManager.isEditing {
                                Button(action: {
                                    dataManager.exitEditMode()
                                }) {
                                    Text("完成")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.primary)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                                }
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                            } else {
                                // Top Right Controls: Plus '+' Button (Gooey Menu) + Pending Queue Icon + Chevron swipe-right indicator
                                HStack(spacing: 8) {
                                    // Plus button anchor (actual GooeyImportMenu floats above via overlayPreferenceValue)
                                    Color.clear
                                        .frame(width: 40, height: 40)
                                        .anchorPreference(key: PlusButtonAnchorKey.self, value: .bounds) { $0 }
                                    
                                    // Queue Button with pending count badge (加号右边新增待入库队列图标)
                                    ZStack(alignment: .topTrailing) {
                                        FrostedCircleButton(iconName: "tray.full", size: 40, iconSize: 17) {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            showPendingQueueSheet = true
                                        }
                                        
                                        if queueManager.badgeCount > 0 {
                                            Text("\(queueManager.badgeCount)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(minWidth: 16, minHeight: 16)
                                                .padding(.horizontal, 3)
                                                .background(Color.red)
                                                .clipShape(Capsule())
                                                .offset(x: 2, y: -2)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    
                                    // Isolated swipe Right affordance indicator
                                    PulsingChevronIndicator()
                                }
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                        .offset(y: 10) // 首页加号往下移一点
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                    .opacity(isExpanded ? 0.0 : 1.0)
                    
                    // Categories Cards (Gooey 菜单展开时整体顺滑下移留出空间，收起时平滑回弹)
                    VStack(spacing: 18) {
                        ForEach(Array(dataManager.categories.enumerated()), id: \.element.id) { index, category in
                        let isBeingDragged = (draggedCategoryId == category.id)
                        let visualShiftY = calculateCategoryVisualShift(index: index, categoryId: category.id)
                        
                        CategoryCardView(
                            category: category,
                            animationNamespace: animationNamespace,
                            isActiveCategory: activeCategory.id == category.id,
                            isExpanded: isExpanded,
                            hideStaticFanCards: isOverlayActive,
                            isEditing: dataManager.isEditing,
                            isDragging: isBeingDragged,
                            index: index,
                            action: {
                                expandCategory(category)
                            },
                            actionWithFrame: { frame, fanCenter in
                                expandCategory(category, frame: frame, fanDeckCenter: fanCenter)
                            },
                            onDelete: {
                                dataManager.deleteCategory(id: category.id)
                            },
                            onLongPress: {
                                dataManager.enterEditMode()
                            }
                        )
                        .offset(y: visualShiftY)
                        .animation(isBeingDragged ? nil : .spring(response: 0.58, dampingFraction: 0.86), value: visualShiftY)
                        .scaleEffect(isBeingDragged ? 1.05 : 1.0)
                        .shadow(color: isBeingDragged ? Color.black.opacity(0.22) : .clear, radius: isBeingDragged ? 20 : 0, y: isBeingDragged ? 10 : 0)
                        .zIndex(isBeingDragged ? 999 : Double(50 - index))
                        .overlay {
                            ReorderableCardGestureView(
                                isEnabled: dataManager.isEditing && !isExpanded,
                                minimumPressDuration: 0.16,
                                onLongPressBegan: { _ in },
                                onLongPressBeganWithScrollView: { touchLoc, sv in
                                    if let sv = sv {
                                        homeDisplayLinkDriver.scrollView = sv
                                    }
                                    draggedCategoryId = category.id
                                    dragStartIndex = index
                                    hoverIndex = index
                                    dragOffsetY = 0
                                    dragInitialTouchY = touchLoc.y
                                    dragCurrentTouchY = touchLoc.y
                                    dragInitialScrollY = sv?.contentOffset.y ?? 0
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    homeDisplayLinkDriver.start { [self] in
                                        onHomeDisplayLinkTick()
                                    }
                                },
                                onDragChanged: { touchLoc, _ in
                                    guard draggedCategoryId == category.id else { return }
                                    dragCurrentTouchY = touchLoc.y
                                    updateCategoryDragPositionAndSlot()
                                },
                                onDragEnded: {
                                    guard draggedCategoryId == category.id else { return }
                                    homeDisplayLinkDriver.stop()
                                    let from = dragStartIndex
                                    let to = hoverIndex
                                    let remainingOffset = dragOffsetY - CGFloat(to - from) * slotStep
                                    
                                    // 先无动画完成数据源换位，并同步将当前卡片 offset 补偿到手指松开时的精确位置，消除换位瞬间的跳动
                                    var tx = Transaction()
                                    tx.disablesAnimations = true
                                    withTransaction(tx) {
                                        if from != to {
                                            dataManager.moveCategory(from: from, to: to, autoSave: true)
                                        }
                                        dragStartIndex = to
                                        hoverIndex = to
                                        dragOffsetY = remainingOffset
                                    }
                                    
                                    DispatchQueue.main.async {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                            draggedCategoryId = nil
                                            dragOffsetY = 0
                                            hoverIndex = 0
                                            dragStartIndex = 0
                                        }
                                    }
                                },
                                onDragCancelled: {
                                    homeDisplayLinkDriver.stop()
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        draggedCategoryId = nil
                                        dragOffsetY = 0
                                        hoverIndex = 0
                                        dragStartIndex = 0
                                    }
                                }
                            )
                            .allowsHitTesting(dataManager.isEditing && !isExpanded)
                        }
                    }
                    
                    // Empty Card with Big Double-Line Plus (Visible only in Edit Mode)
                    // Matches existing category cards exactly in size, corner radius, background, shadow & padding
                    if dataManager.isEditing && !isExpanded {
                        newCategoryEmptyCard
                    }
                    }
                    .offset(y: isGooeyMenuOpen ? 56 : 0)
                    .animation(.spring(response: 0.50, dampingFraction: 0.78), value: isGooeyMenuOpen)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
                .contentShape(Rectangle())
                .onTapGesture {
                    if dataManager.isEditing && draggedCategoryId == nil {
                        dataManager.exitEditMode()
                    }
                }
            }
            .scrollDisabled(isOverlayActive)
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet(dataManager: dataManager) {
                    showAddCategorySheet = false
                }
            }
            .onChange(of: selectedCategory) { _, newCat in
                if let cat = newCat, !isExpanded && !isOverlayActive {
                    expandCategory(cat)
                } else if newCat == nil && isExpanded {
                    collapseCategory()
                }
            }
            
            // Layer 1.5: Transparent backdrop to dismiss Gooey Import Menu on outside tap
            if isGooeyMenuOpen && !dataManager.isEditing && !isExpanded {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                            isGooeyMenuOpen = false
                        }
                    }
                    .zIndex(40)
            }
            
            // Layer 2: Persistent Expanded Category Detail View (never destroyed mid-animation)
            CategoryDetailView(
                category: activeCategory,
                sourceCategoryFrame: activeCategoryFrame,
                sourceFanDeckCenter: activeFannedDeckCenter,
                isExpanded: isExpanded,
                selectedDishId: selectedDishId,
                animationNamespace: animationNamespace,
                onBack: {
                    collapseCategory()
                },
                onSelectDish: { dish, frame in
                    onSelectDish(dish, frame)
                }
            )
            .opacity(isOverlayActive ? 1.0 : 0.0)
            .animation(nil, value: isOverlayActive)
            .allowsHitTesting(isExpanded)
            .zIndex(100)
        }
        .overlayPreferenceValue(PlusButtonAnchorKey.self) { anchor in
            GeometryReader { geo in
                if let anchor = anchor, !dataManager.isEditing && !isExpanded {
                    let rect = geo[anchor]
                    GooeyImportMenu(
                        isOpen: $isGooeyMenuOpen,
                        selectedPhotosItems: $selectedPhotosItems,
                        onSelectCamera: {
                            launchCameraCapture()
                        },
                        onSelectLink: {
                            showImportRecipeSheet = true
                        }
                    )
                    .position(x: rect.midX, y: rect.midY)
                }
            }
            .zIndex(50)
        }
        .fullScreenCover(isPresented: $showCameraCapture) {
            CameraCaptureView(
                onCaptureImage: { image in
                    Task {
                        await RecipeAIWorkflowManager.shared.processImages(images: [image], sourceTag: "相机拍照")
                    }
                },
                onCaptureVideo: { videoURL in
                    Task {
                        await RecipeAIWorkflowManager.shared.processVideo(url: videoURL, sourceTag: "相机录像")
                    }
                }
            )
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showAlbumPicker,
            selection: $selectedPhotosItems,
            maxSelectionCount: 9,
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        )
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MealCollTriggerImport"))) { note in
            let source = note.userInfo?["source"] as? String ?? "link"
            isGooeyMenuOpen = false
            switch source {
            case "camera":
                showCameraCapture = true
            case "album":
                showAlbumPicker = true
            default:
                showImportRecipeSheet = true
            }
        }
        .onChange(of: selectedPhotosItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                isGooeyMenuOpen = false
            }
            let picked = newItems
            selectedPhotosItems = []
            Task {
                for item in picked {
                    let isVideoType = item.supportedContentTypes.contains(where: {
                        $0.conforms(to: .movie) || $0.conforms(to: .video) || $0.conforms(to: .quickTimeMovie) || $0.conforms(to: .mpeg4Movie)
                    })
                    if isVideoType, let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                        await RecipeAIWorkflowManager.shared.processVideo(url: movie.url, sourceTag: "相册视频")
                        return
                    }
                }
                var loadedImages: [UIImage] = []
                for item in picked {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        loadedImages.append(img)
                    }
                }
                if !loadedImages.isEmpty {
                    await RecipeAIWorkflowManager.shared.processImages(images: loadedImages, sourceTag: "相册照片")
                }
            }
        }
        .sheet(isPresented: $showImportRecipeSheet) {
            RecipeImportSourcePickerSheet(startWithLinkEditor: true)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showPendingQueueSheet) {
            PendingRecipesSheetView()
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-testImport") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showImportRecipeSheet = true
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-testExpandCollapse") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let first = dataManager.categories.first {
                        expandCategory(first)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    collapseCategory()
                }
            }
        }
    }
    
    // MARK: - Drag Shift Calculation
    private func calculateCategoryVisualShift(index: Int, categoryId: String) -> CGFloat {
        guard draggedCategoryId != nil else { return 0 }
        if categoryId == draggedCategoryId {
            return dragOffsetY
        }
        if dragStartIndex < hoverIndex {
            if index > dragStartIndex && index <= hoverIndex {
                return -slotStep
            }
        } else if dragStartIndex > hoverIndex {
            if index >= hoverIndex && index < dragStartIndex {
                return slotStep
            }
        }
        return 0
    }
    
    private func updateCategoryDragPositionAndSlot() {
        guard draggedCategoryId != nil else { return }
        let currentScrollY = homeDisplayLinkDriver.scrollView?.contentOffset.y ?? dragInitialScrollY
        dragOffsetY = (dragCurrentTouchY - dragInitialTouchY) + (currentScrollY - dragInitialScrollY)
        
        let count = dataManager.categories.count
        let currentEffectiveIndex = CGFloat(dragStartIndex) + (dragOffsetY / slotStep)
        
        var target = hoverIndex
        if currentEffectiveIndex > CGFloat(hoverIndex) + 0.52 && hoverIndex < count - 1 {
            target = hoverIndex + 1
        } else if currentEffectiveIndex < CGFloat(hoverIndex) - 0.52 && hoverIndex > 0 {
            target = hoverIndex - 1
        }
        
        if target != hoverIndex {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.86)) {
                hoverIndex = target
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    private func onHomeDisplayLinkTick() {
        guard draggedCategoryId != nil, let sv = homeDisplayLinkDriver.scrollView else { return }
        let screenHeight = UIScreen.main.bounds.height
        let safeTop = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets.top ?? 59
        let topThreshold = safeTop + 65
        let bottomThreshold = screenHeight - 85
        
        var deltaY: CGFloat = 0
        if dragCurrentTouchY > bottomThreshold {
            let overflow = dragCurrentTouchY - bottomThreshold
            deltaY = min(12.0, max(2.0, overflow * 0.18))
        } else if dragCurrentTouchY < topThreshold {
            let overflow = topThreshold - dragCurrentTouchY
            deltaY = -min(12.0, max(2.0, overflow * 0.18))
        }
        
        if deltaY != 0 {
            let maxOffset = max(0, sv.contentSize.height - sv.bounds.height)
            let newOffset = max(0, min(maxOffset, sv.contentOffset.y + deltaY))
            if newOffset != sv.contentOffset.y {
                sv.contentOffset.y = newOffset
                updateCategoryDragPositionAndSlot()
            }
        }
    }
    

    
    // MARK: - Empty New Category Card (Sleek dashed-border add-category card)
    private var newCategoryEmptyCard: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAddCategorySheet = true
        }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 3) {
                    Text("添加新分类")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("自定义你的私厨菜单分类")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])
                    )
                    .foregroundColor(Color(uiColor: .separator).opacity(0.75))
            )
        }
        .buttonStyle(ScaleCardButtonStyle())
        .id("bottom_plus_card")
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }
    
    private func expandCategory(_ category: DishCategory, frame: CGRect = .zero, fanDeckCenter: CGPoint = .zero) {
        print("[EXPAND] expandCategory called for \(category.name), isExpanded: \(isExpanded), isEditing: \(dataManager.isEditing)")
        print("[EXPAND_FRAME] passed frame: \(frame), fanDeckCenter: \(fanDeckCenter)")
        guard !isExpanded && !isOverlayActive else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let safeTop = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets.top ?? 59
        let capturedFrame: CGRect
        let capturedFanCenter: CGPoint
        if frame.height > 10 {
            capturedFrame = frame
            capturedFanCenter = (fanDeckCenter.y > 0)
                ? fanDeckCenter
                : CGPoint(x: frame.midX, y: frame.minY + 182.0)
        } else {
            let idx = dataManager.categories.firstIndex(where: { $0.id == category.id }) ?? 0
            capturedFrame = CGRect(x: 16, y: safeTop + 108 + CGFloat(idx) * 302, width: UIScreen.main.bounds.width - 32, height: 284)
            capturedFanCenter = CGPoint(x: UIScreen.main.bounds.width / 2.0, y: safeTop + 108 + CGFloat(idx) * 302 + 182.0)
        }
        
        // 1. Place overlay cards at exact fan starting anchors without animation
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeCategoryFrame = capturedFrame
            activeFannedDeckCenter = capturedFanCenter
            activeCategory = category
            isOverlayActive = true
            isExpanded = false
            selectedCategory = category
        }
        
        // 2. Animate expansion on next render frame (0.02s ensures Frame 0 commits activeCategory & activeCategoryFrame at fan anchors first):
        //    - Cards 0..2 match-transform from fan_slot_0..2 to grid_slot_0..2 & un-rotate to 0°
        //    - Cards 3..5 fade in + move + scale from fan into grid
        //    - Background cross-fades seamlessly with zero flicker or hitch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                isExpanded = true
            }
        }
    }
    
    private func launchCameraCapture() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraCapture = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraCapture = true
                    }
                }
            }
        default:
            break
        }
    }
    
    private func collapseCategory() {
        guard isExpanded else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // 1. Animate collapse smoothly back to activeCategoryFrame:
        //    - Cards 0..2 match-transform back from grid_slot_0..2 to fan_slot_0..2 & rotate to -10°/0°/+10°
        //    - Cards 3..5 fade out + move + scale back toward fan
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            isExpanded = false
        }
        
        // 2. After spring fully settles, cleanly deactivate overlay & restore static fan cards with zero jump
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
            if !isExpanded {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isOverlayActive = false
                    selectedCategory = nil
                }
            }
        }
    }
}

// MARK: - Double-Line Light Gray Plus Icon (双线条浅灰色加号)
public struct DoubleLinePlusIcon: View {
    private let strokeColor = Color(red: 0.76, green: 0.76, blue: 0.80) // 浅灰色
    private let length: CGFloat = 52
    private let strokeWidth: CGFloat = 2.4
    private let gap: CGFloat = 8
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Horizontal parallel double lines
            Capsule()
                .fill(strokeColor)
                .frame(width: length, height: strokeWidth)
                .offset(y: -gap / 2)
            
            Capsule()
                .fill(strokeColor)
                .frame(width: length, height: strokeWidth)
                .offset(y: gap / 2)
            
            // Vertical parallel double lines
            Capsule()
                .fill(strokeColor)
                .frame(width: strokeWidth, height: length)
                .offset(x: -gap / 2)
            
            Capsule()
                .fill(strokeColor)
                .frame(width: strokeWidth, height: length)
                .offset(x: gap / 2)
        }
    }
}

private struct PlusButtonAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

// MARK: - Isolated Pulsing Chevron Indicator
private struct PulsingChevronIndicator: View {
    @State private var isHinting: Bool = false
    
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(uiColor: .secondaryLabel).opacity(0.65))
            .offset(x: isHinting ? 3 : 0)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isHinting)
            .onAppear {
                isHinting = true
            }
    }
}
