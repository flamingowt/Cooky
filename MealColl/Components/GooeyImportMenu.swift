import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 首页右上角 Gooey（液态粘连）展开式导入菜单按钮
/// 白底黑标，点击 `+` 旋转 45° 变为 `×`，下方以液态粘连动效横向弹出「相机、图库、链接」三个圆形小按钮
public struct GooeyImportMenu: View {
    @Binding public var isOpen: Bool
    @Binding public var selectedPhotosItems: [PhotosPickerItem]
    public let onSelectCamera: () -> Void
    public let onSelectLink: () -> Void
    
    private let buttonSize: CGFloat = 40
    private let subButtonSize: CGFloat = 46
    private let dropY: CGFloat = 54
    private let stepX: CGFloat = 56
    private let canvasPad: CGFloat = 22
    
    private let iconColor = Color(red: 0.14, green: 0.14, blue: 0.16)
    
    public init(
        isOpen: Binding<Bool>,
        selectedPhotosItems: Binding<[PhotosPickerItem]>,
        onSelectCamera: @escaping () -> Void,
        onSelectLink: @escaping () -> Void
    ) {
        self._isOpen = isOpen
        self._selectedPhotosItems = selectedPhotosItems
        self.onSelectCamera = onSelectCamera
        self.onSelectLink = onSelectLink
    }
    
    private var canvasWidth: CGFloat {
        buttonSize + stepX * 2 + canvasPad * 2
    }
    
    private var canvasHeight: CGFloat {
        buttonSize + dropY + canvasPad * 2
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // 1. 白底液态粘连背景层（blur + alphaThreshold 实时融合）
            GooeyHorizontalBlobCanvas(
                progress: isOpen ? 1.0 : 0.0,
                buttonSize: buttonSize,
                subButtonSize: subButtonSize,
                dropY: dropY,
                stepX: stepX,
                pad: canvasPad,
                blobColor: .white
            )
            .frame(width: canvasWidth, height: canvasHeight)
            .offset(y: -canvasPad)
            .allowsHitTesting(false)
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
            
            // 2. 三个横向排列的子按钮（相机、图库、链接），随液态球一起从 `+` 中心向下并横向散开
            // ZStack 顶部对齐时，46pt 子按钮中心比 40pt 主按钮中心低 (subButtonSize - buttonSize)/2 = 3pt，需向上补偿保持绝对同心
            let centerAlignY = (buttonSize - subButtonSize) / 2
            
            // (1) 相机（左）
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                    isOpen = false
                }
                onSelectCamera()
            }) {
                subButtonIcon("camera.fill")
            }
            .buttonStyle(.plain)
            .offset(x: isOpen ? -stepX : 0, y: isOpen ? (dropY + centerAlignY) : centerAlignY)
            .scaleEffect(isOpen ? 1.0 : 0.35)
            .opacity(isOpen ? 1.0 : 0.0)
            .allowsHitTesting(isOpen)
            
            // (2) 图库（中）
            PhotosPicker(
                selection: $selectedPhotosItems,
                maxSelectionCount: 9,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            ) {
                subButtonIcon("photo.on.rectangle.angled")
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
            .offset(x: 0, y: isOpen ? (dropY + centerAlignY) : centerAlignY)
            .scaleEffect(isOpen ? 1.0 : 0.35)
            .opacity(isOpen ? 1.0 : 0.0)
            .allowsHitTesting(isOpen)
            
            // (3) 链接（右）
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                    isOpen = false
                }
                onSelectLink()
            }) {
                subButtonIcon("link")
            }
            .buttonStyle(.plain)
            .offset(x: isOpen ? stepX : 0, y: isOpen ? (dropY + centerAlignY) : centerAlignY)
            .scaleEffect(isOpen ? 1.0 : 0.35)
            .opacity(isOpen ? 1.0 : 0.0)
            .allowsHitTesting(isOpen)
            
            // 3. 主 `+` / `×` 按钮（最上层，点击旋转 45° 展开与收起）
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.50, dampingFraction: 0.68)) {
                    isOpen.toggle()
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                    .rotationEffect(.degrees(isOpen ? 45 : 0))
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: buttonSize, height: buttonSize, alignment: .top)
    }
    
    @ViewBuilder
    private func subButtonIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(iconColor)
            .frame(width: subButtonSize, height: subButtonSize)
            .contentShape(Circle())
    }
}

private struct GooeyHorizontalBlobCanvas: View, Animatable {
    var progress: CGFloat
    let buttonSize: CGFloat
    let subButtonSize: CGFloat
    let dropY: CGFloat
    let stepX: CGFloat
    let pad: CGFloat
    let blobColor: Color
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.5, color: blobColor))
            context.addFilter(.blur(radius: 7.5))
            context.drawLayer { ctx in
                let originX = size.width / 2
                let originY = pad + buttonSize / 2
                
                // 主按钮白底圆形
                let mainRect = CGRect(
                    x: originX - buttonSize / 2,
                    y: originY - buttonSize / 2,
                    width: buttonSize,
                    height: buttonSize
                )
                ctx.fill(Circle().path(in: mainRect), with: .color(.black))
                
                // 3 个向下并横向散开的子圆形（带轻微交错，形成液态拉丝与分离效果）
                let targets: [CGFloat] = [-stepX, 0, stepX]
                for (index, targetDX) in targets.enumerated() {
                    let stagger = CGFloat(index) * 0.055
                    let localP = max(0, min(1, (progress - stagger) / (1 - stagger)))
                    let cx = originX + targetDX * localP
                    let cy = originY + dropY * localP
                    let scale = 0.72 + 0.28 * localP
                    let d = subButtonSize * scale
                    let rect = CGRect(
                        x: cx - d / 2,
                        y: cy - d / 2,
                        width: d,
                        height: d
                    )
                    ctx.fill(Circle().path(in: rect), with: .color(.black))
                }
            }
        }
    }
}
