import SwiftUI

public struct DishDetailModalView: View {
    public let dish: Dish
    public let sourceFrame: CGRect
    public let onLogCooked: ((Dish) -> Void)?
    public let onDismiss: () -> Void
    
    // Continuous animation progress states:
    // flipProgress: 0.0 = Original DishCard in grid, 1.0 = Floating Preview Card (3D 180° flip)
    @State private var flipProgress: CGFloat = 0.0
    // fullscreenProgress: 0.0 = Floating Preview Card, 1.0 = Fullscreen Recipe View
    @State private var fullscreenProgress: CGFloat = 0.0
    
    // Unified vertical scroll + interactive drag states (zero UIScrollView gesture conflict)
    @State private var scrollOffset: CGFloat = 0.0
    @State private var maxScrollOffset: CGFloat = 680.0
    @State private var isScrollAtTop: Bool = true
    @State private var dragStartedAtTop: Bool? = nil
    @State private var isDragging: Bool = false
    @State private var dragStartScrollOffset: CGFloat = 0.0
    @State private var dragStartFullscreen: CGFloat = 0.0
    
    @State private var interactiveFlipDrag: CGFloat = 0.0      // 0.0 .. 0.48 while pulling down to close book
    @State private var interactiveFullscreenDrag: CGFloat = 0.0 // delta applied to fullscreenProgress
    @State private var dragTranslation: CGSize = .zero
    @State private var isClosing: Bool = false
    @State private var hasTriggeredHaptic: Bool = false
    @State private var hasLoggedToday: Bool = false
    @State private var isEnlargingStep: Bool = false
    
    public init(
        dish: Dish,
        sourceFrame: CGRect = .zero,
        onLogCooked: ((Dish) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.dish = dish
        self.sourceFrame = sourceFrame
        self.onLogCooked = onLogCooked
        self.onDismiss = onDismiss
    }
    
    private var effectiveFlipProgress: CGFloat {
        max(0.0, min(1.0, flipProgress - interactiveFlipDrag))
    }
    
    private var effectiveFullscreenProgress: CGFloat {
        max(0.0, min(1.0, fullscreenProgress + interactiveFullscreenDrag))
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenSize = screenGeo.size
            let safeTop = screenGeo.safeAreaInsets.top
            let safeBottom = screenGeo.safeAreaInsets.bottom
            
            // Fallback source frame if not provided (e.g. from Calendar)
            let resolvedSourceFrame: CGRect = (sourceFrame.width > 10 && sourceFrame.height > 10)
                ? sourceFrame
                : CGRect(
                    x: (screenSize.width - 170) / 2.0,
                    y: (screenSize.height - 222) / 2.0,
                    width: 170,
                    height: 222
                )
            
            ZStack {
                // Dimmed backdrop that fades with flipProgress and fullscreenProgress
                Color.black
                    .opacity(Double(effectiveFlipProgress) * (0.30 + Double(effectiveFullscreenProgress) * 0.18))
                    .ignoresSafeArea()
                    .onTapGesture {
                        triggerBookClose()
                    }
                
                // Frame-accurate Two-Sided 3D Book Flip + Fullscreen Expansion View
                TwoSidedFlippingRecipeContainer(
                    dish: dish,
                    flipProgress: effectiveFlipProgress,
                    fullscreenProgress: effectiveFullscreenProgress,
                    dragTranslation: dragTranslation,
                    sourceFrame: resolvedSourceFrame,
                    screenSize: screenSize,
                    safeTop: safeTop,
                    safeBottom: safeBottom,
                    hasLoggedToday: $hasLoggedToday,
                    scrollOffset: $scrollOffset,
                    maxScrollOffset: $maxScrollOffset,
                    isScrollAtTop: $isScrollAtTop,
                    isEnlargingStep: $isEnlargingStep,
                    onLogCooked: onLogCooked,
                    onTapClose: {
                        triggerBookClose()
                    },
                    onExpandFullscreen: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                            fullscreenProgress = 1.0
                            interactiveFullscreenDrag = 0.0
                        }
                    }
                )
                .contentShape(Rectangle())
                .gesture(unifiedCardDragGesture, including: effectiveFullscreenProgress < 0.98 ? .all : .none)
                .simultaneousGesture(fullscreenCloseGesture, including: effectiveFullscreenProgress >= 0.98 ? .all : .none)
            }
            .frame(width: screenSize.width, height: screenSize.height)
        }
        .ignoresSafeArea()
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            // Phase A: 3D Flip Open from original card into Floating Preview Card
            withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) {
                flipProgress = 1.0
            }
            
            if ProcessInfo.processInfo.arguments.contains("-testCardCycle") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                        fullscreenProgress = 1.0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        scrollOffset = maxScrollOffset
                    }
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-testStepGallery") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                        fullscreenProgress = 1.0
                    }
                }
            }
        }
    }
    
    // MARK: - Unified Vertical Scroll + Fullscreen Expand + 3D Book-Close Gesture
    private var unifiedCardDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                guard !isClosing && !isEnlargingStep else { return }
                if !isDragging {
                    isDragging = true
                    dragStartScrollOffset = scrollOffset
                    dragStartFullscreen = fullscreenProgress
                }
                
                let dy = value.translation.height
                let dx = value.translation.width
                
                // 1. Right swipe gesture: 菜谱卡片打开后任何时候向右滑，能直接收起卡片
                if dx > 12 && dx > abs(dy) * 0.65 {
                    let swipeRightAmount = dx - 12
                    interactiveFlipDrag = min(0.38, swipeRightAmount / 260.0)
                    dragTranslation = CGSize(width: swipeRightAmount * 0.82, height: 0)
                    interactiveFullscreenDrag = -min(0.45, swipeRightAmount / 220.0)
                    scrollOffset = dragStartScrollOffset
                    return
                }
                
                if dragStartFullscreen < 0.5 {
                    // Started in Floating Preview Card mode
                    if dy < 0 {
                        // Swiping UP -> smoothly expand floating card to Fullscreen
                        interactiveFlipDrag = 0.0
                        dragTranslation = .zero
                        let expandPull = -dy
                        interactiveFullscreenDrag = min(1.0, expandPull / 190.0)
                        
                        // If continuing to drag up after reaching fullscreen, scroll up to maxScrollOffset (strict stop at bottom)
                        if expandPull > 190 {
                            scrollOffset = min(maxScrollOffset, (expandPull - 190) * 0.75)
                        } else {
                            scrollOffset = 0
                        }
                    } else {
                        // 垂直下拉不关闭卡片，仅往右滑收起卡片
                        interactiveFullscreenDrag = 0.0
                        interactiveFlipDrag = 0.0
                        dragTranslation = .zero
                        scrollOffset = 0
                    }
                } else {
                    // Started in Fullscreen mode
                    let proposedScroll = dragStartScrollOffset - dy
                    
                    if proposedScroll > 0 {
                        // Content is NOT at the top yet -> scroll the recipe content, strictly clamped at maxScrollOffset (no overscroll past bottom button!)
                        interactiveFullscreenDrag = 0.0
                        interactiveFlipDrag = 0.0
                        dragTranslation = .zero
                        let newOffset = min(maxScrollOffset, proposedScroll)
                        if abs(newOffset - scrollOffset) > 0.5 {
                            scrollOffset = newOffset
                        }
                    } else {
                        // Content HAS reached the very top (scrollOffset == 0) and user is pulling down!
                        scrollOffset = 0
                        let overshootDown = -proposedScroll // >= 0
                        
                        // 垂直下拉仅从全屏缩回悬浮预览，不关闭卡片（只有往右滑才收起）
                        interactiveFlipDrag = 0.0
                        dragTranslation = .zero
                        if overshootDown > 0 && dy > abs(dx) * 0.8 {
                            let shrinkProgress = min(1.0, overshootDown / 125.0)
                            interactiveFullscreenDrag = -shrinkProgress
                        } else {
                            interactiveFullscreenDrag = 0.0
                        }
                    }
                }
            }
            .onEnded { value in
                guard !isClosing && !isEnlargingStep else { return }
                isDragging = false
                hasTriggeredHaptic = false
                
                let dy = value.translation.height
                let dx = value.translation.width
                let predictedY = value.predictedEndTranslation.height
                let predictedX = value.predictedEndTranslation.width
                
                // 1. Right swipe to close: 菜谱卡片打开后任何时候向右滑，能直接收起卡片
                if (dx > 45 || predictedX > 85) && dx > abs(dy) * 0.6 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    triggerBookClose()
                    return
                }
                
                // If user started right swipe but released without reaching threshold, spring back
                if dx > 12 && dx > abs(dy) * 0.65 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        interactiveFullscreenDrag = 0.0
                        interactiveFlipDrag = 0.0
                        dragTranslation = .zero
                        scrollOffset = dragStartScrollOffset
                    }
                    return
                }
                
                if dragStartFullscreen < 0.5 {
                    if dy < -32 || predictedY < -85 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                            fullscreenProgress = 1.0
                            interactiveFullscreenDrag = 0.0
                            interactiveFlipDrag = 0.0
                            dragTranslation = .zero
                            scrollOffset = min(maxScrollOffset, scrollOffset)
                        }
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            interactiveFullscreenDrag = 0.0
                            interactiveFlipDrag = 0.0
                            dragTranslation = .zero
                            scrollOffset = 0
                        }
                    }
                } else {
                    let proposedScroll = dragStartScrollOffset - dy
                    let overshootDown = -proposedScroll
                    let velocityY = predictedY - dy
                    
                    if overshootDown > 0 {
                        let isDownwardsDominant = (dy > abs(dx) * 1.2)
                        if isDownwardsDominant && (overshootDown > 42 || (dragStartScrollOffset <= 10 && overshootDown + velocityY * 0.35 > 85)) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                fullscreenProgress = 0.0
                                interactiveFullscreenDrag = 0.0
                                interactiveFlipDrag = 0.0
                                dragTranslation = .zero
                                scrollOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                                interactiveFullscreenDrag = 0.0
                                interactiveFlipDrag = 0.0
                                dragTranslation = .zero
                                scrollOffset = 0
                            }
                        }
                    } else {
                        // Strict clamp to [0, maxScrollOffset] so it stops right at the bottom check-in tab!
                        let projectedScroll = proposedScroll - velocityY * 0.45
                        let clampedScroll = max(0.0, min(maxScrollOffset, projectedScroll))
                        
                        withAnimation(.interpolatingSpring(stiffness: 280, damping: 30)) {
                            scrollOffset = clampedScroll
                            interactiveFullscreenDrag = 0.0
                            interactiveFlipDrag = 0.0
                            dragTranslation = .zero
                        }
                    }
                }
            }
    }
    
    // MARK: - Fullscreen Close Gesture (Right-swipe or top pull-down without interfering with native ScrollView)
    private var fullscreenCloseGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onChanged { _ in
                if dragStartedAtTop == nil {
                    dragStartedAtTop = isScrollAtTop
                }
            }
            .onEnded { value in
                let startedAtTop = dragStartedAtTop ?? false
                dragStartedAtTop = nil
                guard !isClosing && !isEnlargingStep else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                let predictedX = value.predictedEndTranslation.width

                if (dx > 60 || predictedX > 110) && dx > abs(dy) * 1.3 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    triggerBookClose()
                    return
                }
            }
    }

    // MARK: - Trigger 3D Book-Close Flip Back to Original Card
    private func triggerBookClose() {
        guard !isClosing else { return }
        isClosing = true
        
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            fullscreenProgress = 0.0
            interactiveFullscreenDrag = 0.0
            interactiveFlipDrag = 0.0
            dragTranslation = .zero
            scrollOffset = 0.0
            flipProgress = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            onDismiss()
        }
    }
}

// MARK: - Animatable Two-Sided 3D Flip + Fullscreen Morph Container
private struct TwoSidedFlippingRecipeContainer: View, Animatable {
    let dish: Dish
    var flipProgress: CGFloat       // 0.0 = Grid Card (Front), 1.0 = Floating Card (Back)
    var fullscreenProgress: CGFloat // 0.0 = Floating Card, 1.0 = Fullscreen Sheet
    let dragTranslation: CGSize
    let sourceFrame: CGRect
    let screenSize: CGSize
    let safeTop: CGFloat
    let safeBottom: CGFloat
    @Binding var hasLoggedToday: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var maxScrollOffset: CGFloat
    @Binding var isScrollAtTop: Bool
    @Binding var isEnlargingStep: Bool
    let onLogCooked: ((Dish) -> Void)?
    let onTapClose: () -> Void
    let onExpandFullscreen: () -> Void
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(flipProgress, fullscreenProgress) }
        set {
            flipProgress = newValue.first
            fullscreenProgress = newValue.second
        }
    }
    
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
    
    var body: some View {
        let p = max(0.0, min(1.0, flipProgress))
        let f = max(0.0, min(1.0, fullscreenProgress))
        
        // Floating Preview Card target rect
        let floatingWidth = min(368, screenSize.width - 28)
        let floatingHeight: CGFloat = min(560, screenSize.height * 0.67)
        let floatingRect = CGRect(
            x: (screenSize.width - floatingWidth) / 2.0,
            y: (screenSize.height - floatingHeight) / 2.0 + 12,
            width: floatingWidth,
            height: floatingHeight
        )
        
        // Fullscreen target rect
        let fullscreenRect = CGRect(
            x: 0,
            y: 0,
            width: screenSize.width,
            height: screenSize.height
        )
        
        // Interpolate sourceFrame -> floatingRect (via p) -> fullscreenRect (via f)
        let stage1Width = lerp(sourceFrame.width, floatingRect.width, p)
        let stage1Height = lerp(sourceFrame.height, floatingRect.height, p)
        let stage1MidX = lerp(sourceFrame.midX, floatingRect.midX, p)
        let stage1MidY = lerp(sourceFrame.midY, floatingRect.midY, p)
        
        let currentWidth = lerp(stage1Width, fullscreenRect.width, f)
        let currentHeight = lerp(stage1Height, fullscreenRect.height, f)
        let currentMidX = lerp(stage1MidX, fullscreenRect.midX, f)
        let currentMidY = lerp(stage1MidY, fullscreenRect.midY, f)
        let isCircularSource = sourceFrame.width > 0 && sourceFrame.width <= 60
        let sourceCornerRadius: CGFloat = isCircularSource ? (sourceFrame.width / 2.0) : 18
        let currentCornerRadius = lerp(lerp(sourceCornerRadius, 28, p), 44, f)
        
        // 3D Rotation Math:
        let isShowingFrontFace = (p < 0.5)
        let yRotationDegrees: Double = isShowingFrontFace
            ? Double(-180.0 * p)
            : Double(180.0 * (1.0 - p))
        
        let midFlipIntensity = sin(Double(p) * .pi) * Double(1.0 - f)
        let xTiltDegrees: Double = -6.0 * midFlipIntensity
        
        // 当完全展开全屏时，不渲染沉重的大模糊阴影以极大提升滑动帧率（从 40fps 提升到 120fps）
        let shadowOpacity = 0.18 * Double(p) * max(0.0, 1.0 - Double(f))
        let shadowRadius: CGFloat = (f >= 0.95) ? 0 : 26
        
        ZStack {
            if isShowingFrontFace {
                if isCircularSource {
                    // 来自日历日期头像时，正面收缩阶段平滑过渡为圆形菜品缩略图，精准落入对应日期
                    ZStack {
                        DishCardView(dish: dish, isCompact: false)
                            .opacity(Double(min(1.0, p / 0.35)))
                        DishImageView(dish.imageName)
                            .scaledToFill()
                            .opacity(Double(max(0.0, 1.0 - p / 0.35)))
                    }
                    .allowsHitTesting(false)
                    .frame(width: currentWidth, height: currentHeight)
                    .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                    .shadow(color: Color.black.opacity(0.16 * Double(p)), radius: 8, y: 3)
                } else {
                    DishCardView(dish: dish, isCompact: false)
                        .allowsHitTesting(false)
                        .frame(width: currentWidth, height: currentHeight)
                }
            } else {
                RecipeCleanWhiteBackFaceView(
                    dish: dish,
                    fullscreenProgress: f,
                    containerWidth: currentWidth,
                    containerHeight: currentHeight,
                    cornerRadius: currentCornerRadius,
                    safeTop: safeTop,
                    safeBottom: safeBottom,
                    hasLoggedToday: $hasLoggedToday,
                    scrollOffset: $scrollOffset,
                    maxScrollOffset: $maxScrollOffset,
                    isScrollAtTop: $isScrollAtTop,
                    isEnlargingStep: $isEnlargingStep,
                    onLogCooked: onLogCooked,
                    onTapClose: onTapClose,
                    onExpandFullscreen: onExpandFullscreen
                )
                .frame(width: currentWidth, height: currentHeight)
                .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(
                            color: Color.black.opacity(shadowOpacity),
                            radius: shadowRadius,
                            x: 0,
                            y: 12
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1.0)
                )
            }
        }
        .rotation3DEffect(
            .degrees(abs(yRotationDegrees) < 0.05 ? 0 : yRotationDegrees),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: (abs(yRotationDegrees) < 0.05 && abs(xTiltDegrees) < 0.05) ? 0 : 0.58
        )
        .rotation3DEffect(
            .degrees(abs(xTiltDegrees) < 0.05 ? 0 : xTiltDegrees),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            perspective: (abs(yRotationDegrees) < 0.05 && abs(xTiltDegrees) < 0.05) ? 0 : 0.58
        )
        .position(x: currentMidX, y: currentMidY)
        .offset(dragTranslation)
    }
}

// MARK: - Enlarged Step Lightbox Info
private struct EnlargedStepInfo: Identifiable, Equatable {
    let id = UUID()
    let number: String
    let text: String
    let imageName: String
}

// MARK: - Recipe Clean White Back Face View
// Exact Reference Structure:
// 1. Clean White Background (和首页一致)
// 2. Top Plate Hero with Share Button (左上角箭头已移除，纯净极简)
// 3. Title & Author Info + 4 Metrics Row
// 4. Ingredients divided into: 主料、辅料、调料 (无横滑，整体一体化卡片布局)
// 5. Steps (一行一句步骤，带图，点击可放大看大图，再次点击收回)
// 6. Bottom "今日做了这道菜 · 记入日历" tab strictly stops at bottom
private struct RecipeCleanWhiteBackFaceView: View {
    let dish: Dish
    let fullscreenProgress: CGFloat
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let cornerRadius: CGFloat
    let safeTop: CGFloat
    let safeBottom: CGFloat
    @Binding var hasLoggedToday: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var maxScrollOffset: CGFloat
    @Binding var isScrollAtTop: Bool
    @Binding var isEnlargingStep: Bool
    let onLogCooked: ((Dish) -> Void)?
    let onTapClose: () -> Void
    let onExpandFullscreen: () -> Void
    
    @State private var showShareSheet: Bool = false
    @State private var activeStepGalleryIndex: Int? = nil
    @State private var showAIDisclaimer: Bool = false
    @State private var aiDisclaimerTask: Task<Void, Never>? = nil
    
    private var shareItems: [Any] {
        let text = """
        【船长.de私厨】精选菜谱：《\(dish.name)》
        \(dish.subtitle)
        烹饪用时：\(dish.cookingTime) · 卡路里：\(dish.calories)
        主要用料：\(dish.ingredients.joined(separator: "、"))
        
        分享自 船长.de私厨 App
        """
        if let image = DishImageLoader.uiImage(for: dish.imageName) {
            return [text, image]
        }
        return [text]
    }
    
    // Clean styling tokens
    private let titleColor = Color(red: 0.12, green: 0.12, blue: 0.12)       // #1F1F1F Deep Charcoal
    private let subtextColor = Color(red: 0.50, green: 0.50, blue: 0.50)     // #808080 Muted Gray
    private let tileBg = Color(red: 0.955, green: 0.955, blue: 0.948)        // #F3F3F1 Soft warm-neutral tile
    private let trackBg = Color(red: 0.925, green: 0.925, blue: 0.920)       // #ECECEB Ratio bar background track
    
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
    
    var body: some View {
        let effectiveSafeTop = max(54, safeTop)
        let effectiveSafeBottom = max(24, safeBottom)
        let topControlsTopPadding = lerp(16, effectiveSafeTop + 4, fullscreenProgress)
        let plateDiameter = lerp(205, 236, fullscreenProgress)
        
        ZStack(alignment: .top) {
            // 1. Pure White Background (保持白色和首页一致)
            Color(uiColor: .systemBackground)
            
            // Native 120Hz ScrollView (zero SwiftUI per-frame re-render, native tap-vs-scroll disambiguation)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    GeometryReader { topGeo in
                        Color.clear
                            .preference(
                                key: RecipeScrollAtTopKey.self,
                                value: topGeo.frame(in: .named("recipeScroll")).minY >= -4
                            )
                    }
                    .frame(height: 0)
                    // 1. Top Ceramic Plate with Dish Main Image (主图统一放在最上面的盘子里)
                    ZStack(alignment: .top) {
                        // Top-right Apple Share Button flanking the plate (左上角箭头已移除)
                        HStack {
                            Spacer()
                            
                            // Top-right Apple Share Button (苹果分享按钮，点击分享菜谱卡片给别人)
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showShareSheet = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(y: -1) // Optical alignment for SF Symbol
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                                    )
                                    .shadow(color: Color.black.opacity(0.18), radius: 5, y: 2)
                            }
                            .buttonStyle(SpringyBadgeButtonStyle())
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, topControlsTopPadding)
                        .zIndex(5)
                        
                        // Centered Ceramic Plate overlapping top edge
                        ZStack(alignment: .bottom) {
                            CeramicPlateHeroImage(
                                imageName: dish.imageName,
                                diameter: plateDiameter
                            )
                            
                            if dish.isAIGenerated {
                                Button(action: {
                                    triggerAIDisclaimer()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("AI 生成")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.68))
                                    )
                                    .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
                                .offset(x: plateDiameter * 0.28, y: -12)
                                .zIndex(6)
                            }
                            
                            if showAIDisclaimer {
                                Text("AI 根据画面推演制作流程，可能包含误差")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.78))
                                    )
                                    .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)
                                    .padding(.bottom, 18)
                                    .transition(.opacity)
                                    .zIndex(8)
                                    .allowsHitTesting(false)
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            if dish.isAIGenerated {
                                triggerAIDisclaimer()
                            }
                        }
                        .offset(y: lerp(-24, effectiveSafeTop - 34, fullscreenProgress))
                    }
                    .frame(height: plateDiameter + lerp(-12, effectiveSafeTop - 20, fullscreenProgress))
                    
                    // 2. Dish Title & Subtitle
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dish.name)
                            .font(.system(size: 26, weight: .heavy, design: .serif))
                            .foregroundColor(titleColor)
                            .tracking(0.3)
                        
                        HStack(spacing: 4) {
                            Text("by @mealcoll ·")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(subtextColor)
                            
                            Text("See Original Link")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(titleColor)
                                .underline()
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    
                    // 3. 4-Column Metrics Row (难度 / 时间 / 食材数量 / 付量流量)
                    HStack(spacing: 0) {
                        metricColumn(label: "难度", value: dish.difficultyEnglish)
                        metricColumn(label: "时间", value: dish.shortTime)
                        metricColumn(label: "食材数量", value: "\(dish.totalIngredientCount)")
                        metricColumn(label: "热量卡路里", value: dish.caloriesNumber)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    
                    // 4. Section: Ingredients (原料)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Ingredients")
                            .font(.system(size: 22, weight: .heavy, design: .serif))
                            .foregroundColor(titleColor)
                        
                        // (1) 主料 (4列方图平铺，无外框留白，文字在下方)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("主料")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(titleColor)
                            
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 4),
                                alignment: .leading,
                                spacing: 14
                            ) {
                                ForEach(Array(dish.mainIngredientItems.enumerated()), id: \.offset) { _, item in
                                    ingredientGridTile(name: item.name, imageName: item.imageName, amount: item.amount)
                                }
                            }
                        }
                        
                        // (2) 辅料 (4列方图平铺，无外框留白，文字在下方)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("辅料")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(titleColor)
                            
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 4),
                                alignment: .leading,
                                spacing: 14
                            ) {
                                ForEach(Array(dish.auxiliaryIngredientItems.enumerated()), id: \.offset) { _, item in
                                    ingredientGridTile(name: item.name, imageName: item.imageName, amount: item.amount)
                                }
                            }
                        }
                        
                        // (3) 调料（调料的比例是如图的横条表示的）
                        VStack(alignment: .leading, spacing: 10) {
                            Text("调料")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(titleColor)
                            
                            VStack(spacing: 10) {
                                ForEach(Array(dish.seasoningItems.enumerated()), id: \.offset) { _, seasoning in
                                    HStack(spacing: 14) {
                                        // Left: Seasoning Name + English
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(seasoning.name)
                                                .font(.system(size: 13.5, weight: .bold))
                                                .foregroundColor(titleColor)
                                                .lineLimit(1)
                                            Text(seasoning.english)
                                                .font(.system(size: 10.5, weight: .medium))
                                                .foregroundColor(subtextColor)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 70, alignment: .leading)
                                        
                                        // Right: Proportion Horizontal Bar (移除每行的嵌套 GeometryReader，大幅减少滑动时的布局重算)
                                        let r = Double((seasoning.colorHex >> 16) & 0xFF) / 255.0
                                        let g = Double((seasoning.colorHex >> 8) & 0xFF) / 255.0
                                        let b = Double(seasoning.colorHex & 0xFF) / 255.0
                                        let pillColor = Color(red: r, green: g, blue: b)
                                        let trackWidth = max(80, containerWidth - 128)
                                        
                                        ZStack(alignment: .leading) {
                                            // Background light gray track
                                            Capsule()
                                                .fill(trackBg)
                                            
                                            // Active colored proportion pill
                                            Capsule()
                                                .fill(pillColor)
                                                .frame(width: max(48, trackWidth * seasoning.ratio))
                                            
                                            // Amount label on the colored pill
                                            Text(seasoning.amount)
                                                .font(.system(size: 11, weight: .heavy))
                                                .foregroundColor(.white)
                                                .padding(.leading, 12)
                                        }
                                        .frame(width: trackWidth, height: 28)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    
                    // 5. Section: Steps (下面是步骤，一行一句步骤，带图)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Steps")
                            .font(.system(size: 22, weight: .heavy, design: .serif))
                            .foregroundColor(titleColor)
                        
                        VStack(spacing: 14) {
                            ForEach(Array(dish.stepList.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .center, spacing: 14) {
                                    // Step Image (带图，点击放大进入全部步骤全屏滑动大图)
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                            activeStepGalleryIndex = idx
                                        }
                                    }) {
                                        ZStack(alignment: .bottomTrailing) {
                                            DishImageView(step.imageName)
                                                .scaledToFill()
                                                .frame(width: 92, height: 66)
                                                .clipped()
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
                                                )
                                                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                                            
                                            // Zoom icon badge
                                            Image(systemName: "plus.magnifyingglass")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(Circle().fill(Color.black.opacity(0.55)))
                                                .padding(4)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Step Number + One-Line Step Description (一行一句步骤)
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(step.number)
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundColor(titleColor)
                                            .frame(width: 24, alignment: .leading)
                                        
                                        Text(step.text)
                                            .font(.system(size: 13.5, weight: .medium))
                                            .foregroundColor(titleColor.opacity(0.88))
                                            .lineSpacing(3)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(tileBg.opacity(0.65))
                                )
                            }
                        }
                        
                        // 5.5 Tips (烹饪贴士 / 原主厨复盘)
                        if !dish.chefNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Tips")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(titleColor)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(dish.chefNotes, id: \.self) { note in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "lightbulb.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.orange)
                                                .padding(.top, 3)
                                            
                                            Text(note)
                                                .font(.system(size: 13.5, weight: .medium))
                                                .foregroundColor(titleColor.opacity(0.85))
                                                .lineSpacing(3)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(tileBg)
                                )
                            }
                        }
                        
                        // 6. Bottom Tab ("今日做了这道菜 · 记入日历") — exact scroll bottom stop!
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            hasLoggedToday.toggle()
                            onLogCooked?(dish)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: hasLoggedToday ? "checkmark.circle.fill" : "calendar.badge.plus")
                                Text(hasLoggedToday ? "已打卡至今日菜谱日历" : "今日做了这道菜 · 记入日历")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(hasLoggedToday ? Color.green : titleColor)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                        .padding(.bottom, effectiveSafeBottom + 14)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .coordinateSpace(name: "recipeScroll")
            .scrollDisabled(fullscreenProgress < 0.98)
            .onPreferenceChange(RecipeScrollAtTopKey.self) { atTop in
                if isScrollAtTop != atTop {
                    isScrollAtTop = atTop
                }
            }
            .clipped()
            
            // 7. Lightbox Step Gallery Overlay (点开一张图片，所有步骤图片排好并可顺畅下滑查看)
            if let initialStep = activeStepGalleryIndex {
                ZStack(alignment: .top) {
                    // Deep dark background
                    Color.black.opacity(0.92)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack(spacing: 0) {
                        // Top Header Bar
                        HStack {
                            // Title & Counter
                            HStack(spacing: 8) {
                                Image(systemName: "photo.stack.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Text("步骤图片与做法")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("(\(dish.stepList.count) 步)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            
                            Spacer()
                            
                            // Close Button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    activeStepGalleryIndex = nil
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
                        .padding(.horizontal, 22)
                        .padding(.top, max(52, safeTop + 6))
                        .padding(.bottom, 12)
                        .background(
                            Color.black.opacity(0.65)
                                .ignoresSafeArea(edges: .top)
                        )
                        .zIndex(20)
                        
                        // Vertical Scrollable Step Cards List (所有的步骤图片都排列好可以下滑)
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 24) {
                                    ForEach(Array(dish.stepList.enumerated()), id: \.offset) { idx, step in
                                        VStack(alignment: .leading, spacing: 14) {
                                            // Step Number & Progress Tag
                                            HStack {
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 6, height: 6)
                                                    Text("步骤 \(step.number)")
                                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                                        .foregroundColor(.white)
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 5)
                                                .background(
                                                    Capsule().fill(Color.white.opacity(0.18))
                                                )
                                                
                                                Spacer()
                                                
                                                Text("\(idx + 1) / \(dish.stepList.count)")
                                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.45))
                                            }
                                            
                                            // Big Step Image
                                            DishImageView(step.imageName)
                                                .scaledToFit()
                                                .frame(maxWidth: min(containerWidth - 36, 360))
                                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                )
                                                .shadow(color: Color.black.opacity(0.45), radius: 18, y: 10)
                                            
                                            // Step Instruction Text
                                            Text(step.text)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white.opacity(0.96))
                                                .lineSpacing(5)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .padding(.horizontal, 2)
                                                .padding(.top, 2)
                                        }
                                        .padding(18)
                                        .background(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .fill(Color(white: 0.14).opacity(0.85))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                                )
                                        )
                                        .id("step_gallery_\(idx)")
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                activeStepGalleryIndex = nil
                                            }
                                        }
                                    }
                                    
                                    // Bottom dismiss prompt
                                    Text("已滑至底部 · 轻触任意图片或右上角收回")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(.top, 10)
                                        .padding(.bottom, max(44, safeBottom + 28))
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                            }
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    activeStepGalleryIndex = nil
                                }
                            }
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        scrollProxy.scrollTo("step_gallery_\(initialStep)", anchor: .top)
                                    }
                                }
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .global)
                        .onEnded { val in
                            if val.translation.width > 50 && val.translation.width > abs(val.translation.height) * 0.8 {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    activeStepGalleryIndex = nil
                                }
                            }
                        }
                )
                .zIndex(200)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .onChange(of: activeStepGalleryIndex != nil) { _, isEnlarged in
            isEnlargingStep = isEnlarged
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-testStepGallery") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        activeStepGalleryIndex = 0
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
    }
    
    // MARK: - Helper Subviews
    private func triggerAIDisclaimer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        aiDisclaimerTask?.cancel()
        withAnimation(.easeIn(duration: 0.2)) {
            showAIDisclaimer = true
        }
        aiDisclaimerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 1.0)) {
                showAIDisclaimer = false
            }
        }
    }
    
    @ViewBuilder
    private func ingredientGridTile(name: String, imageName: String, amount: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            IngredientThumbnailView(
                name: name,
                imageName: imageName,
                cornerRadius: 14,
                isSquareFill: true
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !amount.isEmpty {
                    Text(amount)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(subtextColor)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func metricColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(subtextColor)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(titleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Top Ceramic Plate Hero Image Component
private struct CeramicPlateHeroImage: View {
    let imageName: String
    let diameter: CGFloat
    
    var body: some View {
        ZStack {
            // Outer stoneware ceramic rim
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.46, blue: 0.39),
                            Color(red: 0.38, green: 0.30, blue: 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: diameter, height: diameter)
                .shadow(color: Color(red: 0.22, green: 0.15, blue: 0.10).opacity(0.28), radius: 18, x: 0, y: 12)
            
            // Inner off-white ceramic glaze rim
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.96, green: 0.95, blue: 0.93),
                            Color(red: 0.85, green: 0.82, blue: 0.78)
                        ],
                        center: .center,
                        startRadius: diameter * 0.32,
                        endRadius: diameter * 0.48
                    )
                )
                .frame(width: diameter - 8, height: diameter - 8)
            
            // Subtle inner plate well shadow
            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 2)
                .frame(width: diameter - 26, height: diameter - 26)
            
            // Plated Dish Main Photo
            DishImageView(imageName)
                .scaledToFill()
                .frame(width: diameter - 28, height: diameter - 28)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        }
        .drawingGroup()
    }
}

private struct RecipeScrollAtTopKey: PreferenceKey {
    static var defaultValue: Bool = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

public struct FlowLayout: Layout {
    public var spacing: CGFloat
    
    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        return CGSize(width: width, height: currentY + rowHeight)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

// MARK: - Native iOS Share Activity View Controller
public struct ActivityViewController: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

