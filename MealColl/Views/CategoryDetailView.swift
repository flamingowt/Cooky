import SwiftUI
import UIKit

// MARK: - DisplayLink Driver for 120Hz Multi-Touch Reordering Loop
private class DisplayLinkDriver: NSObject {
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

// MARK: - Two-Column Layout
public struct TwoColumnGridLayout: Layout {
    public var spacing: CGFloat = 14
    public var itemHeight: CGFloat = 222
    
    public init(spacing: CGFloat = 14, itemHeight: CGFloat = 222) {
        self.spacing = spacing
        self.itemHeight = itemHeight
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        let rows = (subviews.count + 1) / 2
        let height = rows > 0
            ? CGFloat(rows) * itemHeight + CGFloat(rows - 1) * spacing
            : 0
        return CGSize(width: width, height: height)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let itemWidth = max(0, (bounds.width - spacing) / 2.0)
        let itemSize = ProposedViewSize(width: itemWidth, height: itemHeight)
        
        for (index, subview) in subviews.enumerated() {
            let col = index % 2
            let row = index / 2
            let x = bounds.minX + CGFloat(col) * (itemWidth + spacing)
            let y = bounds.minY + CGFloat(row) * (itemHeight + spacing)
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: itemSize
            )
        }
    }
}

// MARK: - CategoryDetailView
public struct CategoryDetailView: View {
    public let category: DishCategory
    public var sourceCategoryFrame: CGRect = .zero
    public var sourceFanDeckCenter: CGPoint = .zero
    public let isExpanded: Bool
    public let selectedDishId: String?
    public let animationNamespace: Namespace.ID
    public let onBack: () -> Void
    public let onSelectDish: (Dish, CGRect) -> Void
    
    @ObservedObject private var dataManager = RecipeDataManager.shared
    
    // Drag & Multi-Touch Reordering state
    @State private var draggedDishId: String? = nil
    @State private var dragStartIndex: Int = 0
    @State private var hoverIndex: Int = 0
    @State private var dragTouchScreenPosition: CGPoint = .zero
    @State private var touchCenterOffset: CGPoint = .zero
    @State private var isDropping: Bool = false
    @State private var dropTargetScreenPosition: CGPoint = .zero
    
    // ScrollView reference & 120Hz display link driver
    @State private var localScrollView: UIScrollView? = nil
    @State private var displayLinkDriver = DisplayLinkDriver()
    @State private var hasTriggeredPullDownDismiss: Bool = false
    @State private var gridOriginGlobal: CGPoint = .zero

    private var effectiveGridOriginGlobal: CGPoint {
        if gridOriginGlobal.y > 0 {
            return gridOriginGlobal
        }
        let safeTop = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets.top ?? 59
        return CGPoint(x: padding, y: safeTop + 70)
    }
    
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    private let padding: CGFloat = 20
    private let spacing: CGFloat = 14
    private let itemHeight: CGFloat = 222
    
    private var colWidth: CGFloat {
        (screenWidth - padding * 2 - spacing) / 2.0
    }
    private var colStep: CGFloat { colWidth + spacing }
    private var rowStep: CGFloat { itemHeight + spacing }
    
    public init(
        category: DishCategory,
        sourceCategoryFrame: CGRect = .zero,
        sourceFanDeckCenter: CGPoint = .zero,
        isExpanded: Bool,
        selectedDishId: String? = nil,
        animationNamespace: Namespace.ID,
        onBack: @escaping () -> Void,
        onSelectDish: @escaping (Dish, CGRect) -> Void
    ) {
        self.category = category
        self.sourceCategoryFrame = sourceCategoryFrame
        self.sourceFanDeckCenter = sourceFanDeckCenter
        self.isExpanded = isExpanded
        self.selectedDishId = selectedDishId
        self.animationNamespace = animationNamespace
        self.onBack = onBack
        self.onSelectDish = onSelectDish
    }
    
    private var currentCategory: DishCategory {
        dataManager.categories.first(where: { $0.id == category.id }) ?? category
    }
    
    // Real-time slot center calculation accounting for scrollview content offset
    private func slotCenter(for slot: Int) -> CGPoint {
        let col = slot % 2
        let row = slot / 2
        let currentScrollY = displayLinkDriver.scrollView?.contentOffset.y ?? 0
        let safeTop = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets.top ?? 59
        let baseGridTop: CGFloat = safeTop + 58 + 4
        let currentGridTop = baseGridTop - currentScrollY
        let x = padding + CGFloat(col) * colStep + colWidth / 2.0
        let y = currentGridTop + CGFloat(row) * rowStep + itemHeight / 2.0
        return CGPoint(x: x, y: y)
    }
    
    private var currentFloatingPosition: CGPoint {
        if isDropping {
            return dropTargetScreenPosition
        } else {
            return CGPoint(
                x: dragTouchScreenPosition.x - touchCenterOffset.x,
                y: dragTouchScreenPosition.y - touchCenterOffset.y
            )
        }
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Background (tap empty area to exit edit mode) - fades smoothly with isExpanded so home card background never vanishes
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
                .opacity(isExpanded ? 1.0 : 0.0)
                .contentShape(Rectangle())
                .onTapGesture {
                    if dataManager.isEditing && draggedDishId == nil {
                        dataManager.exitEditMode()
                    }
                }
            
            VStack(spacing: 0) {
                // Top Navigation Bar (matching Video 1: clean '<' back button at top-left)
                HStack(spacing: 14) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onBack()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: .systemBackground).opacity(0.88))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .scaleEffect(isExpanded ? 1.0 : 0.7)
                    .opacity(isExpanded ? 1.0 : 0.0)
                    .zIndex(100)
                    
                    Spacer()
                    
                    // Done button in edit mode (Level 2)
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
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .zIndex(50)
                
                // Scrollable 2-Column Grid (supports all 20+ dishes + smooth 2-finger interaction)
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // 顶部下拉检测器（当用户滑到最顶部再往下拉时，平滑收回返回首页）
                            GeometryReader { geo in
                                let minY = geo.frame(in: .named("category_detail_scroll_space")).minY
                                Color.clear
                                    .preference(key: PullDownOffsetPreferenceKey.self, value: minY)
                            }
                            .frame(height: 0)
                            
                            TwoColumnGridLayout(spacing: spacing, itemHeight: itemHeight) {
                            ForEach(Array(currentCategory.dishes.enumerated()), id: \.element.id) { index, dish in
                                let isCurrentlyFlippedOpen = (selectedDishId == dish.id)
                                let isBeingDragged = (draggedDishId == dish.id)
                                let visualOffset = calculateVisualOffset(index: index, dishId: dish.id)
                                
                                ZStack {
                                    if index < 3 {
                                        // 1. Grid card representation (scales down to fan size & cross-fades out during collapse)
                                        gridDishCard(dish: dish, index: index, isBeingDragged: isBeingDragged)
                                            .scaleEffect(x: isExpanded ? 1.0 : (98.0 / colWidth), y: isExpanded ? 1.0 : (142.0 / itemHeight))
                                            .opacity(isExpanded ? 1.0 : 0.0)
                                        
                                        // 2. Exact static Fan card representation (cross-fades in to 100% pixel match with home fan deck)
                                        FannedCardItemView(dish: dish)
                                            .scaleEffect(x: isExpanded ? (colWidth / 98.0) : 1.0, y: isExpanded ? (itemHeight / 142.0) : 1.0)
                                            .opacity(isExpanded ? 0.0 : 1.0)
                                    } else if index < 6 {
                                        gridDishCard(dish: dish, index: index, isBeingDragged: isBeingDragged)
                                            .scaleEffect(x: isExpanded ? 1.0 : (98.0 / colWidth), y: isExpanded ? 1.0 : (142.0 / itemHeight))
                                            .opacity(isExpanded ? 1.0 : 0.0)
                                    } else {
                                        gridDishCard(dish: dish, index: index, isBeingDragged: isBeingDragged)
                                            .opacity(isExpanded ? 1.0 : 0.0)
                                    }
                                }
                                .modifier(CardExpansionModifier(
                                    index: index,
                                    categoryId: currentCategory.id,
                                    sourceCategoryFrame: sourceCategoryFrame,
                                    sourceFanDeckCenter: sourceFanDeckCenter,
                                    gridOriginGlobal: effectiveGridOriginGlobal,
                                    isExpanded: isExpanded,
                                    isEditing: dataManager.isEditing,
                                    animationNamespace: animationNamespace
                                ))
                                .opacity((isCurrentlyFlippedOpen || isBeingDragged) ? 0.0 : 1.0)
                                .id("dish_\(index)")
                                .offset(visualOffset)
                                .animation(isBeingDragged ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: visualOffset)
                                .zIndex(isBeingDragged ? 999 : (index < 3 ? Double((index + 1) * 10) : Double(currentCategory.dishes.count - index)))
                                .overlay {
                                    ReorderableCardGestureView(
                                        isEnabled: dataManager.isEditing && isExpanded,
                                        minimumPressDuration: 0.16,
                                        onLongPressBegan: { touchLoc in
                                            handleDragBegan(dish: dish, index: index, touchLocation: touchLoc)
                                        },
                                        onLongPressBeganWithScrollView: { touchLoc, sv in
                                            if let sv = sv {
                                                displayLinkDriver.scrollView = sv
                                            }
                                            handleDragBegan(dish: dish, index: index, touchLocation: touchLoc)
                                        },
                                        onDragChanged: { touchLoc, translation in
                                            handleDragChanged(dish: dish, touchLocation: touchLoc, translation: translation)
                                        },
                                        onDragEnded: {
                                            handleDragEnded(dish: dish)
                                        },
                                        onDragCancelled: {
                                            handleDragCancelled(dish: dish)
                                        }
                                    )
                                    .allowsHitTesting(dataManager.isEditing && isExpanded)
                                }
                            }
                        }
                        .background(
                            GeometryReader { gridGeo in
                                let origin = gridGeo.frame(in: .global).origin
                                Color.clear
                                    .onAppear {
                                        gridOriginGlobal = origin
                                    }
                                    .onChange(of: origin) { newOrigin in
                                        gridOriginGlobal = newOrigin
                                    }
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 80)
                        }
                        .animation(nil, value: currentCategory.id)
                        .background(
                            LocalScrollViewIntrospector { sv in
                                displayLinkDriver.scrollView = sv
                                sv.isScrollEnabled = true
                                sv.clipsToBounds = false
                                sv.delaysContentTouches = false
                                sv.canCancelContentTouches = true
                                sv.panGestureRecognizer.cancelsTouchesInView = false
                            }
                        )
                    }
                    .coordinateSpace(name: "category_detail_scroll_space")
                    .onPreferenceChange(PullDownOffsetPreferenceKey.self) { offset in
                        // 当滑到最上面再往下拉超过 65pt 时，平滑返回首页
                        if offset > 65 && isExpanded && !dataManager.isEditing && selectedDishId == nil && draggedDishId == nil {
                            if !hasTriggeredPullDownDismiss {
                                hasTriggeredPullDownDismiss = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onBack()
                            }
                        } else if offset <= 10 {
                            hasTriggeredPullDownDismiss = false
                        }
                    }
                    .scrollClipDisabled()
                    .scrollDisabled(false)
                    .onChange(of: category.id) { _, _ in
                        displayLinkDriver.scrollView?.setContentOffset(.zero, animated: false)
                    }
                    .onChange(of: isExpanded) { _, expanded in
                        if !expanded {
                            displayLinkDriver.scrollView?.setContentOffset(.zero, animated: false)
                            scrollProxy.scrollTo("dish_0", anchor: .top)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // Dedicated Left Edge Interactive Swipe-Back Strip (Screen Left Edge -> Swipe Right to Return)
            if isExpanded && !dataManager.isEditing && selectedDishId == nil {
                Color.clear
                    .frame(width: 44)
                    .padding(.top, 90) // 确保避开左上角返回按钮热区
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 12, coordinateSpace: .global)
                            .onEnded { value in
                                guard isExpanded && !dataManager.isEditing && selectedDishId == nil else { return }
                                if value.translation.width > 38 && value.translation.width > abs(value.translation.height) * 1.15 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onBack()
                                }
                            }
                    )
            }
            
            // Floating Dragged Card Overlay (Follows Finger 1 Globally in screen coordinates; unaffected by Finger 2 scrolling)
            if let draggedId = draggedDishId,
               let draggedDish = currentCategory.dishes.first(where: { $0.id == draggedId }) {
                DishCardView(
                    dish: draggedDish,
                    isCompact: false,
                    isEditing: true,
                    isDragging: true,
                    index: hoverIndex,
                    onCardTapWithFrame: { _ in },
                    onDelete: {},
                    onLongPress: {}
                )
                .frame(width: colWidth, height: itemHeight)
                .scaleEffect(1.08)
                .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 14)
                .position(currentFloatingPosition)
                .ignoresSafeArea()
                .zIndex(9999)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isDropping)
            }
        }
    }
    
    // MARK: - Grid Dish Card Builder
    @ViewBuilder
    private func gridDishCard(dish: Dish, index: Int, isBeingDragged: Bool) -> some View {
        DishCardView(
            dish: dish,
            isCompact: false,
            isEditing: dataManager.isEditing,
            isDragging: isBeingDragged,
            index: index,
            onCardTapWithFrame: { frame in
                if isExpanded && !isBeingDragged && draggedDishId == nil {
                    onSelectDish(dish, frame)
                }
            },
            onDelete: {
                dataManager.deleteDish(dishId: dish.id, in: currentCategory.id)
            },
            onLongPress: {
                dataManager.enterEditMode()
            }
        )
    }
    
    // MARK: - Drag & Drop Slot Logic
    private func calculateVisualOffset(index: Int, dishId: String) -> CGSize {
        guard draggedDishId != nil else { return .zero }
        if dishId == draggedDishId {
            return .zero
        }
        var targetSlot = index
        if dragStartIndex < hoverIndex {
            if index > dragStartIndex && index <= hoverIndex {
                targetSlot = index - 1
            }
        } else if dragStartIndex > hoverIndex {
            if index >= hoverIndex && index < dragStartIndex {
                targetSlot = index + 1
            }
        }
        let shiftX = (CGFloat(targetSlot % 2) - CGFloat(index % 2)) * colStep
        let shiftY = (CGFloat(targetSlot / 2) - CGFloat(index / 2)) * rowStep
        return CGSize(width: shiftX, height: shiftY)
    }
    
    private func updateHoverSlot() {
        guard draggedDishId != nil else { return }
        let count = currentCategory.dishes.count
        guard count > 0 else { return }
        
        let cardCenter = currentFloatingPosition
        var bestSlot = hoverIndex
        var bestDistance: CGFloat = .infinity
        
        for k in 0..<count {
            let center = slotCenter(for: k)
            let dist = hypot(cardCenter.x - center.x, cardCenter.y - center.y)
            if dist < bestDistance {
                bestDistance = dist
                bestSlot = k
            }
        }
        
        if bestSlot != hoverIndex {
            let curCenter = slotCenter(for: hoverIndex)
            let distToCur = hypot(cardCenter.x - curCenter.x, cardCenter.y - curCenter.y)
            // 16pt hysteresis prevents jitter
            if bestDistance < distToCur - 16 {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    hoverIndex = bestSlot
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    private func handleDragBegan(dish: Dish, index: Int, touchLocation: CGPoint) {
        guard draggedDishId == nil else { return }
        draggedDishId = dish.id
        dragStartIndex = index
        hoverIndex = index
        isDropping = false
        dragTouchScreenPosition = touchLocation
        
        let initialCenter = slotCenter(for: index)
        touchCenterOffset = CGPoint(
            x: touchLocation.x - initialCenter.x,
            y: touchLocation.y - initialCenter.y
        )
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Start 120Hz display link driver
        displayLinkDriver.start { [self] in
            onDisplayLinkTick()
        }
    }
    
    private func handleDragChanged(dish: Dish, touchLocation: CGPoint, translation: CGSize) {
        guard draggedDishId == dish.id, !isDropping else { return }
        dragTouchScreenPosition = touchLocation
        updateHoverSlot()
    }
    
    private func handleDragEnded(dish: Dish) {
        guard draggedDishId == dish.id, !isDropping else { return }
        displayLinkDriver.stop()
        
        let from = dragStartIndex
        let to = hoverIndex
        
        let targetCenter = slotCenter(for: to)
        dropTargetScreenPosition = targetCenter
        isDropping = true
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            // Animate floating card to target slot center
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if from != to {
                dataManager.moveDish(in: currentCategory.id, from: from, to: to, autoSave: true)
            }
            draggedDishId = nil
            isDropping = false
            dragStartIndex = 0
            hoverIndex = 0
        }
    }
    
    private func handleDragCancelled(dish: Dish) {
        guard draggedDishId == dish.id else { return }
        displayLinkDriver.stop()
        let targetCenter = slotCenter(for: dragStartIndex)
        dropTargetScreenPosition = targetCenter
        isDropping = true
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            // Animate back to original slot
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            draggedDishId = nil
            isDropping = false
            dragStartIndex = 0
            hoverIndex = 0
        }
    }
    
    // MARK: - 120Hz Loop Handler
    private func onDisplayLinkTick() {
        guard draggedDishId != nil, !isDropping else { return }
        checkAndPerformAutoScroll()
        updateHoverSlot()
    }
    
    private func checkAndPerformAutoScroll() {
        guard draggedDishId != nil, !isDropping, let sv = displayLinkDriver.scrollView else { return }
        let safeTop = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets.top ?? 59
        let topThreshold = safeTop + 65
        let bottomThreshold = screenHeight - 85
        
        let cardBottomEdge = currentFloatingPosition.y + itemHeight * 0.36
        let cardTopEdge = currentFloatingPosition.y - itemHeight * 0.36
        let bottomTriggerY = max(dragTouchScreenPosition.y, cardBottomEdge)
        let topTriggerY = min(dragTouchScreenPosition.y, cardTopEdge)
        
        var deltaY: CGFloat = 0
        if bottomTriggerY > bottomThreshold {
            let overflow = bottomTriggerY - bottomThreshold
            deltaY = min(12.0, max(2.0, overflow * 0.18))
        } else if topTriggerY < topThreshold {
            let overflow = topThreshold - topTriggerY
            deltaY = -min(12.0, max(2.0, overflow * 0.18))
        }
        
        if deltaY != 0 {
            let maxOffset = max(0, sv.contentSize.height - sv.bounds.height)
            let newOffset = max(0, min(maxOffset, sv.contentOffset.y + deltaY))
            if newOffset != sv.contentOffset.y {
                sv.contentOffset.y = newOffset
            }
        }
    }
}

// MARK: - Local ScrollView Introspector
private struct LocalScrollViewIntrospector: UIViewRepresentable {
    var onFound: (UIScrollView) -> Void
    
    func makeUIView(context: Context) -> LocalScrollHelperView {
        let view = LocalScrollHelperView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onDidMoveToWindow = { [weak view] in
            guard let view = view else { return }
            findLocalScrollView(from: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: LocalScrollHelperView, context: Context) {
        findLocalScrollView(from: uiView)
    }
    
    private func findLocalScrollView(from view: UIView) {
        var current: UIView? = view
        while let curr = current {
            if let sv = curr as? UIScrollView {
                let name = String(describing: type(of: sv))
                if !name.contains("Paging") && !name.contains("Queuing") {
                    onFound(sv)
                    return
                }
            }
            for sub in curr.subviews {
                if let sv = sub as? UIScrollView {
                    let name = String(describing: type(of: sv))
                    if !name.contains("Paging") && !name.contains("Queuing") {
                        onFound(sv)
                        return
                    }
                }
            }
            current = curr.superview
        }
    }
}

private class LocalScrollHelperView: UIView {
    var onDidMoveToWindow: (() -> Void)?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onDidMoveToWindow?()
        }
    }
}

// MARK: - Card Expansion & Fan Matching Modifier
struct CardExpansionModifier: ViewModifier {
    let index: Int
    let categoryId: String
    let sourceCategoryFrame: CGRect
    let sourceFanDeckCenter: CGPoint
    let gridOriginGlobal: CGPoint
    let isExpanded: Bool
    let isEditing: Bool
    let animationNamespace: Namespace.ID
    
    // Dynamic delta from grid slot center to the exact on-screen fan deck slot center
    private var fanDelta: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 20
        let spacing: CGFloat = 14
        let colWidth: CGFloat = (screenWidth - padding * 2 - spacing) / 2.0
        let itemHeight: CGFloat = 222
        let safeTop = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets.top ?? 59
        
        let col = index % 2
        let row = index / 2
        
        let gridX = gridOriginGlobal.x + CGFloat(col) * (colWidth + spacing) + colWidth / 2.0
        let gridY = gridOriginGlobal.y + CGFloat(row) * (itemHeight + spacing) + itemHeight / 2.0
        
        let fanCenterX: CGFloat
        let fanCenterY: CGFloat
        if sourceFanDeckCenter.y > 0 {
            fanCenterX = sourceFanDeckCenter.x
            fanCenterY = sourceFanDeckCenter.y
        } else {
            let cardMinY = (sourceCategoryFrame.height > 10) ? sourceCategoryFrame.minY : (safeTop + 108)
            fanCenterX = (sourceCategoryFrame.width > 10) ? sourceCategoryFrame.midX : screenWidth / 2.0
            fanCenterY = cardMinY + 180.0
        }
        
        let fanTargetX: CGFloat
        let fanTargetY: CGFloat
        if index < 3 {
            let offset = FannedDeckView.fanOffset(for: index)
            fanTargetX = fanCenterX + offset.width
            fanTargetY = fanCenterY + offset.height
        } else {
            fanTargetX = fanCenterX
            fanTargetY = fanCenterY
        }
        
        return CGSize(width: fanTargetX - gridX, height: fanTargetY - gridY)
    }
    
    private var fanRotation: Double {
        switch index {
        case 0: return -10
        case 1: return 0
        case 2: return 10
        default: return 0
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if index < 6 {
            let delta = isExpanded ? CGSize.zero : fanDelta
            content
                .rotationEffect(.degrees(isExpanded ? 0 : fanRotation))
                .offset(x: delta.width, y: delta.height)
        } else {
            content
                .opacity(isExpanded ? 1.0 : 0.0)
        }
    }
}

// MARK: - Pull Down to Dismiss Preference Key
private struct PullDownOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
