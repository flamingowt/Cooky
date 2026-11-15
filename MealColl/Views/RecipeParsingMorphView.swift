import SwiftUI

/// 极简纯色线条与灵动岛物理形变解析加载动画
/// 展开态尺寸与首页分类卡片一致 (screenWidth - 32 × 284, cornerRadius: 28)
/// 轻触卡片/背景在展开大卡与底部悬浮胶囊 (212×52) 之间切换；上滑卡片飞入右上角「待入库队列」图标
public struct RecipeParsingMorphView: View {
    @ObservedObject private var workflowManager = RecipeAIWorkflowManager.shared
    
    // 是否收起为底部悬浮胶囊态（点击卡片或遮罩切换）
    @State private var isCollapsed: Bool = false
    @State private var currentStage: Int = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var isFlyingToQueue: Bool = false
    @State private var flyOpacity: Double = 1.0
    
    // 阶段名称
    private let stageTitles = [
        "正在采样画面食材",
        "正在解析烹饪火候",
        "正在量化调味配比",
        "正在凝结结构化菜谱"
    ]
    
    public init() {}
    
    public var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let cardWidth = max(280, screenWidth - 32)
        
        ZStack {
            // 半透明遮罩层（仅展开态显现，轻触背景收拢为底部胶囊，不关闭动画）
            Color.black
                .opacity((isCollapsed || isFlyingToQueue) ? 0.0 : 0.28)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.32), value: isCollapsed)
                .animation(.easeInOut(duration: 0.28), value: isFlyingToQueue)
                .allowsHitTesting(!isCollapsed && !isFlyingToQueue)
                .onTapGesture {
                    toggleMorphState()
                }
            
            VStack {
                Spacer()
                
                morphIslandCard(expandedWidth: cardWidth)
                    .padding(.bottom, isCollapsed ? 28 : 36)
                    .offset(
                        x: isFlyingToQueue ? screenWidth * 0.34 : 0,
                        y: isFlyingToQueue ? -screenHeight * 0.68 : dragOffsetY
                    )
                    .scaleEffect(isFlyingToQueue ? 0.10 : max(0.88, 1.0 + dragOffsetY / 900.0))
                    .opacity(flyOpacity)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                guard !isFlyingToQueue else { return }
                                if value.translation.height < 0 {
                                    dragOffsetY = value.translation.height * 0.65
                                } else {
                                    dragOffsetY = min(value.translation.height * 0.18, 16)
                                }
                            }
                            .onEnded { value in
                                guard !isFlyingToQueue else { return }
                                if value.translation.height < -60 || value.predictedEndTranslation.height < -140 {
                                    flyToPendingQueue()
                                } else {
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                                        dragOffsetY = 0
                                    }
                                }
                            }
                    )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    // MARK: - 双形态毛玻璃核心容器（展开与分类卡片等宽等高，轻触可缩成胶囊）
    private func morphIslandCard(expandedWidth: CGFloat) -> some View {
        let currentWidth = isCollapsed ? 212 : expandedWidth
        let currentHeight: CGFloat = isCollapsed ? 52 : 284
        let currentRadius: CGFloat = isCollapsed ? 26 : 28
        
        return ZStack(alignment: .top) {
            // 1. 顶部极简拖拽把手指示条 (仅在展开态显示)
            Capsule()
                .fill(Color(uiColor: .label).opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .opacity(isCollapsed ? 0 : 1)
            
            // 2. 核心动画舞台 (SVG 厨具食材线条 + Canvas 采样点阵)
            RecipeParsingGraphicStage(isCompact: isCollapsed) { newStage in
                currentStage = newStage
            }
            .frame(width: 148, height: 148)
            .scaleEffect(isCollapsed ? 0.22 : 1.0)
            .position(
                x: isCollapsed ? 32 : currentWidth / 2.0,
                y: isCollapsed ? 26 : 106
            )
            
            // 3. 状态文案
            HStack(spacing: 3) {
                Text(isCollapsed ? "正在解析菜谱" : (workflowManager.statusMessage.isEmpty ? stageTitles[currentStage] : workflowManager.statusMessage))
                    .font(.system(size: isCollapsed ? 13.5 : 15, weight: .medium))
                    .foregroundColor(Color(uiColor: .label).opacity(0.92))
                    .lineLimit(1)
                
                PulsingEllipsisView()
            }
            .frame(width: isCollapsed ? 150 : currentWidth - 40)
            .position(
                x: isCollapsed ? 124 : currentWidth / 2.0,
                y: isCollapsed ? 26 : 216
            )
            
            // 4. 底部 4 阶段指示微圆点 (仅在展开态显示)
            HStack(spacing: 7) {
                ForEach(0..<4) { idx in
                    Capsule()
                        .fill(idx == currentStage ? Color(uiColor: .label).opacity(0.88) : Color(uiColor: .label).opacity(0.18))
                        .frame(width: idx == currentStage ? 14 : 4, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStage)
                }
            }
            .position(x: currentWidth / 2.0, y: 256)
            .opacity(isCollapsed ? 0 : 1)
        }
        .frame(width: currentWidth, height: currentHeight)
        .background(
            RoundedRectangle(cornerRadius: currentRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: Color.black.opacity(isCollapsed ? 0.18 : 0.14),
                    radius: isCollapsed ? 16 : 26,
                    x: 0,
                    y: isCollapsed ? 8 : 12
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: currentRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.15),
                            Color.black.opacity(0.04),
                            Color.white.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMorphState()
        }
    }
    
    private func toggleMorphState() {
        guard !isFlyingToQueue else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
            isCollapsed.toggle()
        }
    }
    
    private func flyToPendingQueue() {
        guard !isFlyingToQueue else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
            dragOffsetY = 0
            isFlyingToQueue = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeOut(duration: 0.16)) {
                flyOpacity = 0.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            workflowManager.showParsingOverlay = false
        }
    }
}

/// 可复用的纯色线条解析动画舞台（148×148 基准尺寸，可用于首页大卡与待入库缩略图）
public struct RecipeParsingGraphicStage: View {
    public var isCompact: Bool
    public var onStageChange: ((Int) -> Void)?
    
    @State private var currentStage: Int = 0
    @State private var stageProgress: CGFloat = 0.0
    @State private var totalTime: Double = 0.0
    @State private var scannerAngle: Double = 0.0
    @State private var animationTimer: Timer?
    
    public init(isCompact: Bool = false, onStageChange: ((Int) -> Void)? = nil) {
        self.isCompact = isCompact
        self.onStageChange = onStageChange
    }
    
    public var body: some View {
        ZStack {
            // 底层：36 颗微距呼吸采样微粒
            TimelineView(.animation) { _ in
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let numParticles = 36
                    let collapse = isCompact ? 1.0 : 0.0
                    
                    for i in 0..<numParticles {
                        let baseAngle = (Double(i) / Double(numParticles)) * Double.pi * 2.0
                        let dir = (i % 2 == 0) ? 1.0 : -1.0
                        let speed = (i % 3 == 0) ? 0.35 : 0.22
                        let curAngle = baseAngle + totalTime * speed * dir
                        
                        let expandedR = (i % 3 == 0 ? 40.0 : 54.0) + sin(totalTime * 2.2 + Double(i) * 0.45) * 2.5
                        let collapsedR = (i % 2 == 0) ? 52.0 : 36.0
                        let r = expandedR * (1.0 - collapse) + collapsedR * collapse
                        
                        let px = center.x + CGFloat(cos(curAngle) * r)
                        let py = center.y + CGFloat(sin(curAngle) * r)
                        
                        let wave = sin(curAngle * 2.0 - totalTime * 3.2 + Double(i) * 0.45)
                        let alpha = (wave > 0.25) ? 0.72 : 0.16
                        let dotRadius: CGFloat = (1.15 + CGFloat(i % 3) * 0.35) * (1.0 + collapse * 0.6)
                        
                        let dotRect = CGRect(x: px - dotRadius, y: py - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                        context.fill(Path(ellipseIn: dotRect), with: .color(Color(uiColor: .label).opacity(alpha)))
                    }
                }
            }
            
            // 公共精密扫描外圈与雷达扫描弧光
            Circle()
                .strokeBorder(
                    Color(uiColor: .label).opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 6])
                )
                .frame(width: 96, height: 96)
            
            Circle()
                .trim(from: 0, to: 0.18)
                .stroke(
                    Color(uiColor: .label).opacity(0.45),
                    style: StrokeStyle(lineWidth: isCompact ? 2.4 : 1.4, lineCap: .round)
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(scannerAngle))
            
            // 4 个纯色线条阶段切换展示
            Group {
                switch currentStage {
                case 0:
                    stage0FishAndLeafView
                case 1:
                    stage1SpatulaAndPanView
                case 2:
                    stage2ForkAndKnifeView
                default:
                    stage3StructuredRecipeView
                }
            }
            .frame(width: 148, height: 148)
        }
        .frame(width: 148, height: 148)
        .onAppear {
            startAnimationLoop()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
    
    // MARK: - 阶段 01：鲜鱼与蔬果采样 (鱼 + 鲜蔬叶片)
    private var stage0FishAndLeafView: some View {
        let drawOffset = calculateDrawOffset()
        let strokeW: CGFloat = isCompact ? 2.6 : 1.75
        let strokeThinW: CGFloat = isCompact ? 1.8 : 1.15
        
        return ZStack {
            // 流线游鱼轮廓
            FishOutlineShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round))
            
            // 鱼鳃极简弧线
            FishGillShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label).opacity(0.5), style: StrokeStyle(lineWidth: strokeThinW, lineCap: .round))
            
            // 鲜蔬叶片轮廓
            LeafOutlineShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round))
            
            // 叶脉
            LeafVeinShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label).opacity(0.5), style: StrokeStyle(lineWidth: strokeThinW, lineCap: .round))
            
            // 采样锚点
            if stageProgress > 0.25 {
                Circle().fill(Color(uiColor: .label)).frame(width: 3.4, height: 3.4).position(x: 44, y: 64)
                Circle().stroke(Color(uiColor: .label), lineWidth: 1.35).frame(width: 4.4, height: 4.4).position(x: 70, y: 56)
                Circle().stroke(Color(uiColor: .label), lineWidth: 1.35).frame(width: 4.4, height: 4.4).position(x: 72, y: 94)
            }
        }
        .offset(y: sin(totalTime * 2.8) * 1.5) // 微柔悬浮感
    }
    
    // MARK: - 阶段 02：锅铲与烹饪火候 (锅铲微倾 + 煎锅与蒸汽)
    private var stage1SpatulaAndPanView: some View {
        let drawOffset = calculateDrawOffset()
        let strokeW: CGFloat = isCompact ? 2.6 : 1.75
        let strokeThinW: CGFloat = isCompact ? 1.8 : 1.15
        
        let tilt = sin(totalTime * 3.8) * 4.5
        let lift = cos(totalTime * 3.8) * 1.5
        
        return ZStack {
            // 翻炒微动的锅铲
            ZStack {
                SpatulaHeadShape()
                    .trim(from: 0, to: drawOffset)
                    .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round))
                
                SpatulaSlotsShape()
                    .trim(from: 0, to: drawOffset)
                    .stroke(Color(uiColor: .label).opacity(0.45), style: StrokeStyle(lineWidth: strokeThinW, lineCap: .round))
                
                SpatulaHandleShape()
                    .trim(from: 0, to: drawOffset)
                    .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
                
                if stageProgress > 0.25 {
                    Circle().stroke(Color(uiColor: .label), lineWidth: 1.3).frame(width: 4, height: 4).position(x: 107, y: 33)
                }
            }
            .offset(y: lift)
            .rotationEffect(.degrees(tilt), anchor: UnitPoint(x: 70.0 / 148.0, y: 68.0 / 148.0))
            
            // 平底煎锅与手柄
            PanBodyShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round))
            
            PanHandleShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label).opacity(0.45), style: StrokeStyle(lineWidth: strokeThinW, lineCap: .round))
            
            // 升腾蒸汽
            SteamWavesShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label).opacity(0.4), style: StrokeStyle(lineWidth: strokeThinW, lineCap: .round))
        }
    }
    
    // MARK: - 阶段 03：刀叉与餐盘配比 (刀叉合拢 + 黄金配比盘)
    private var stage2ForkAndKnifeView: some View {
        let drawOffset = calculateDrawOffset()
        let strokeW: CGFloat = isCompact ? 2.6 : 1.75
        let strokeThinW: CGFloat = isCompact ? 1.8 : 1.15
        let shift = sin(totalTime * 2.6) * 1.8
        
        return ZStack {
            // 左侧餐叉
            ForkShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
                .offset(x: shift)
            
            // 右侧主厨餐刀
            KnifeShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
                .offset(x: -shift)
            
            // 中央配比餐盘与切线
            Circle()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW))
                .frame(width: 32, height: 32)
                .position(x: 74, y: 74)
            
            PlateProportionShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label).opacity(0.5), style: StrokeStyle(lineWidth: strokeThinW, lineCap: .round))
            
            if stageProgress > 0.25 {
                Circle().fill(Color(uiColor: .label)).frame(width: 3.6, height: 3.6).position(x: 74, y: 74)
            }
        }
    }
    
    // MARK: - 阶段 04：凝结成结构化菜谱 (卡片外框 + 三行食材步骤)
    private var stage3StructuredRecipeView: some View {
        let drawOffset = calculateDrawOffset()
        let strokeW: CGFloat = isCompact ? 2.6 : 1.75
        let strokeThinW: CGFloat = isCompact ? 1.8 : 1.15
        
        return ZStack {
            // 菜谱卡片圆角外框
            RecipeCardOutlineShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW))
            
            // 标题、营养环与三行食材步骤线
            RecipeLinesShape()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
            
            Circle()
                .trim(from: 0, to: drawOffset)
                .stroke(Color(uiColor: .label).opacity(0.5), style: StrokeStyle(lineWidth: strokeThinW))
                .frame(width: 9, height: 9)
                .position(x: 90, y: 57)
            
            // 三颗食材节点
            if stageProgress > 0.25 {
                Circle().fill(Color(uiColor: .label)).frame(width: 3.2, height: 3.2).position(x: 56, y: 78)
                Circle().fill(Color(uiColor: .label)).frame(width: 3.2, height: 3.2).position(x: 56, y: 87)
                Circle().fill(Color(uiColor: .label)).frame(width: 3.2, height: 3.2).position(x: 56, y: 96)
            }
        }
    }
    
    // MARK: - Easing & Calculation Helpers
    private func calculateDrawOffset() -> CGFloat {
        if stageProgress < 0.35 {
            let t = stageProgress / 0.35
            return easeInOutCubic(t)
        } else if stageProgress < 0.82 {
            return 1.0
        } else {
            let t = (stageProgress - 0.82) / 0.18
            return max(0.0, 1.0 - easeInOutCubic(t))
        }
    }
    
    private func easeInOutCubic(_ x: CGFloat) -> CGFloat {
        return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0
    }
    
    // MARK: - Animation Clock Loop
    private func startAnimationLoop() {
        animationTimer?.invalidate()
        let stageDuration = 2.6 // 每个阶段 2.6 秒
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            totalTime += 0.02
            scannerAngle += 1.4
            
            let elapsedInStage = totalTime.truncatingRemainder(dividingBy: stageDuration)
            stageProgress = CGFloat(elapsedInStage / stageDuration)
            
            let newStage = Int((totalTime / stageDuration).truncatingRemainder(dividingBy: 4))
            if newStage != currentStage {
                currentStage = newStage
                onStageChange?(newStage)
            }
        }
    }
}

// MARK: - 呼吸闪烁省略号
private struct PulsingEllipsisView: View {
    @State private var phase: Double = 0.0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 1.5) {
                ForEach(0..<4) { idx in
                    let alpha = (sin(time * 3.5 - Double(idx) * 0.45) + 1.0) / 2.0
                    Text(".")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(uiColor: .label).opacity(0.25 + alpha * 0.70))
                }
            }
        }
    }
}

// MARK: - Accurate Vector Shapes (Normalized to 148x148)

private struct FishOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        
        path.move(to: CGPoint(x: 35 * sx, y: 66 * sy))
        path.addCurve(
            to: CGPoint(x: 93 * sx, y: 66 * sy),
            control1: CGPoint(x: 49 * sx, y: 48 * sy),
            control2: CGPoint(x: 76 * sx, y: 48 * sy)
        )
        path.addLine(to: CGPoint(x: 111 * sx, y: 53 * sy))
        path.addLine(to: CGPoint(x: 105 * sx, y: 66 * sy))
        path.addLine(to: CGPoint(x: 111 * sx, y: 79 * sy))
        path.addLine(to: CGPoint(x: 93 * sx, y: 66 * sy))
        path.addCurve(
            to: CGPoint(x: 35 * sx, y: 66 * sy),
            control1: CGPoint(x: 76 * sx, y: 84 * sy),
            control2: CGPoint(x: 49 * sx, y: 84 * sy)
        )
        path.closeSubpath()
        return path
    }
}

private struct FishGillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 52 * sx, y: 59 * sy))
        path.addCurve(
            to: CGPoint(x: 52 * sx, y: 73 * sy),
            control1: CGPoint(x: 56 * sx, y: 64 * sy),
            control2: CGPoint(x: 56 * sx, y: 68 * sy)
        )
        return path
    }
}

private struct LeafOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 46 * sx, y: 96 * sy))
        path.addCurve(
            to: CGPoint(x: 96 * sx, y: 93 * sy),
            control1: CGPoint(x: 54 * sx, y: 81 * sy),
            control2: CGPoint(x: 78 * sx, y: 81 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 46 * sx, y: 96 * sy),
            control1: CGPoint(x: 80 * sx, y: 107 * sy),
            control2: CGPoint(x: 56 * sx, y: 105 * sy)
        )
        path.closeSubpath()
        return path
    }
}

private struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 42 * sx, y: 97 * sy))
        path.addCurve(
            to: CGPoint(x: 95 * sx, y: 93 * sy),
            control1: CGPoint(x: 60 * sx, y: 95 * sy),
            control2: CGPoint(x: 76 * sx, y: 94 * sy)
        )
        return path
    }
}

private struct SpatulaHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 46 * sx, y: 70 * sy))
        path.addLine(to: CGPoint(x: 72 * sx, y: 54 * sy))
        path.addLine(to: CGPoint(x: 84 * sx, y: 66 * sy))
        path.addLine(to: CGPoint(x: 58 * sx, y: 82 * sy))
        path.closeSubpath()
        return path
    }
}

private struct SpatulaSlotsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 55 * sx, y: 71 * sy))
        path.addLine(to: CGPoint(x: 69 * sx, y: 62 * sy))
        
        path.move(to: CGPoint(x: 59 * sx, y: 75 * sy))
        path.addLine(to: CGPoint(x: 73 * sx, y: 66 * sy))
        
        path.move(to: CGPoint(x: 63 * sx, y: 79 * sy))
        path.addLine(to: CGPoint(x: 77 * sx, y: 70 * sy))
        return path
    }
}

private struct SpatulaHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 78 * sx, y: 60 * sy))
        path.addLine(to: CGPoint(x: 90 * sx, y: 48 * sy))
        path.addLine(to: CGPoint(x: 106 * sx, y: 34 * sy))
        return path
    }
}

private struct PanBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 34 * sx, y: 89 * sy))
        path.addLine(to: CGPoint(x: 94 * sx, y: 89 * sy))
        path.addCurve(
            to: CGPoint(x: 64 * sx, y: 106 * sy),
            control1: CGPoint(x: 91 * sx, y: 102 * sy),
            control2: CGPoint(x: 79 * sx, y: 106 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 34 * sx, y: 89 * sy),
            control1: CGPoint(x: 49 * sx, y: 106 * sy),
            control2: CGPoint(x: 37 * sx, y: 102 * sy)
        )
        path.closeSubpath()
        return path
    }
}

private struct PanHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 94 * sx, y: 90 * sy))
        path.addLine(to: CGPoint(x: 114 * sx, y: 85 * sy))
        return path
    }
}

private struct SteamWavesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 44 * sx, y: 56 * sy))
        path.addCurve(
            to: CGPoint(x: 44 * sx, y: 37 * sy),
            control1: CGPoint(x: 41 * sx, y: 49 * sy),
            control2: CGPoint(x: 47 * sx, y: 44 * sy)
        )
        path.move(to: CGPoint(x: 56 * sx, y: 50 * sy))
        path.addCurve(
            to: CGPoint(x: 56 * sx, y: 31 * sy),
            control1: CGPoint(x: 53 * sx, y: 43 * sy),
            control2: CGPoint(x: 59 * sx, y: 38 * sy)
        )
        return path
    }
}

private struct ForkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 42 * sx, y: 42 * sy))
        path.addLine(to: CGPoint(x: 42 * sx, y: 58 * sy))
        path.addCurve(
            to: CGPoint(x: 47 * sx, y: 72 * sy),
            control1: CGPoint(x: 42 * sx, y: 64 * sy),
            control2: CGPoint(x: 47 * sx, y: 66 * sy)
        )
        path.addLine(to: CGPoint(x: 47 * sx, y: 104 * sy))
        
        path.move(to: CGPoint(x: 52 * sx, y: 42 * sy))
        path.addLine(to: CGPoint(x: 52 * sx, y: 58 * sy))
        path.addCurve(
            to: CGPoint(x: 47 * sx, y: 72 * sy),
            control1: CGPoint(x: 52 * sx, y: 64 * sy),
            control2: CGPoint(x: 47 * sx, y: 66 * sy)
        )
        
        path.move(to: CGPoint(x: 47 * sx, y: 42 * sy))
        path.addLine(to: CGPoint(x: 47 * sx, y: 62 * sy))
        return path
    }
}

private struct KnifeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 101 * sx, y: 42 * sy))
        path.addCurve(
            to: CGPoint(x: 95 * sx, y: 76 * sy),
            control1: CGPoint(x: 93 * sx, y: 48 * sy),
            control2: CGPoint(x: 92 * sx, y: 64 * sy)
        )
        path.addLine(to: CGPoint(x: 101 * sx, y: 76 * sy))
        path.addLine(to: CGPoint(x: 101 * sx, y: 104 * sy))
        
        path.move(to: CGPoint(x: 101 * sx, y: 42 * sy))
        path.addLine(to: CGPoint(x: 101 * sx, y: 76 * sy))
        return path
    }
}

private struct PlateProportionShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        path.move(to: CGPoint(x: 74 * sx, y: 58 * sy))
        path.addLine(to: CGPoint(x: 74 * sx, y: 90 * sy))
        
        path.move(to: CGPoint(x: 74 * sx, y: 74 * sy))
        path.addLine(to: CGPoint(x: 88 * sx, y: 66 * sy))
        return path
    }
}

private struct RecipeCardOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        let r = CGRect(x: 46 * sx, y: 42 * sy, width: 56 * sx, height: 64 * sy)
        path.addRoundedRect(in: r, cornerSize: CGSize(width: 8 * sx, height: 8 * sy))
        return path
    }
}

private struct RecipeLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 148.0
        let sy = rect.height / 148.0
        
        path.move(to: CGPoint(x: 55 * sx, y: 54 * sy))
        path.addLine(to: CGPoint(x: 79 * sx, y: 54 * sy))
        
        path.move(to: CGPoint(x: 55 * sx, y: 61 * sy))
        path.addLine(to: CGPoint(x: 68 * sx, y: 61 * sy))
        
        path.move(to: CGPoint(x: 53 * sx, y: 69 * sy))
        path.addLine(to: CGPoint(x: 95 * sx, y: 69 * sy))
        
        path.move(to: CGPoint(x: 63 * sx, y: 78 * sy))
        path.addLine(to: CGPoint(x: 92 * sx, y: 78 * sy))
        
        path.move(to: CGPoint(x: 63 * sx, y: 87 * sy))
        path.addLine(to: CGPoint(x: 86 * sx, y: 87 * sy))
        
        path.move(to: CGPoint(x: 63 * sx, y: 96 * sy))
        path.addLine(to: CGPoint(x: 90 * sx, y: 96 * sy))
        
        return path
    }
}

