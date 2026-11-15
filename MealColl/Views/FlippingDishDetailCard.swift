import SwiftUI

public struct FlippingDishDetailCard: View {
    public let dish: Dish
    public let onLogCooked: ((Dish) -> Void)?
    public let onDismiss: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDismissing: Bool = false
    @State private var appearAnimation: Bool = false
    @State private var hasHapticTriggered: Bool = false
    @State private var hasLoggedToday: Bool = false
    
    public init(
        dish: Dish,
        onLogCooked: ((Dish) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.dish = dish
        self.onLogCooked = onLogCooked
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
        // Subtle 3D tilt tracking finger drag
        return Double(dragOffset.width / 22.0)
    }
    
    private var cardScale: CGFloat {
        if !appearAnimation || isDismissing {
            return 0.65
        }
        return max(0.80, 1.0 - (dragOffset.height / 1100.0))
    }
    
    private var backdropOpacity: Double {
        if !appearAnimation || isDismissing {
            return 0.0
        }
        let dragFade = Double(dragOffset.height / 350.0)
        return max(0.04, 0.45 - dragFade * 0.40)
    }
    
    public var body: some View {
        ZStack {
            // Blurred Dimmed Backdrop
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    triggerDismiss()
                }
            
            // Floating 3D Detail Card (Video 2 Exact Modal)
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
                        
                        FrostedCircleButton(iconName: "ellipsis", size: 34, iconSize: 13) {}
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Dish Cover Image
                        ZStack(alignment: .bottomLeading) {
                            DishImageView(dish.imageName)
                                .scaledToFill()
                                .frame(height: 190)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
                            
                            // Tag badge
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text(dish.tag)
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
                        
                        // Dish Title & Rating
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(dish.name)
                                    .font(.system(size: 22, weight: .bold, design: .serif))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 12))
                                    Text(String(format: "%.1f", dish.rating))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            
                            Text(dish.englishName)
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(Color(uiColor: .secondaryLabel))
                        }
                        
                        // Flavor Story Pill
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                            Text("菜品风味故事 · \(dish.flavor)")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                        }
                        .foregroundColor(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        // Detailed Description
                        Text(dish.description)
                            .font(.system(size: 13.5, weight: .regular, design: .serif))
                            .foregroundColor(Color(uiColor: .label).opacity(0.85))
                            .lineSpacing(5)
                        
                        // Meta Badges
                        HStack(spacing: 10) {
                            metaBadge(icon: "timer", title: "用时", value: dish.cookingTime)
                            metaBadge(icon: "flame", title: "热量", value: dish.calories)
                            metaBadge(icon: "leaf", title: "特色", value: dish.flavor.components(separatedBy: "·").first ?? "经典")
                        }
                        .padding(.vertical, 2)
                        
                        // Ingredients Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("严选食材")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(dish.ingredients, id: \.self) { item in
                                    Text(item)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(Color(uiColor: .secondaryLabel))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        
                        // Action Buttons
                        VStack(spacing: 8) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                hasLoggedToday.toggle()
                                onLogCooked?(dish)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: hasLoggedToday ? "checkmark.circle.fill" : "flame.circle.fill")
                                    Text(hasLoggedToday ? "已标记为今日烹饪" : "打卡：今天做了这道菜")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(hasLoggedToday ? .white : Color.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(hasLoggedToday ? Color.green : Color.accentColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            
                            Button(action: {
                                triggerDismiss()
                            }) {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                    Text("收藏这道美味")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 18)
                }
            }
            .frame(maxWidth: 350)
            .frame(maxHeight: 570)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.22), radius: 25, x: 0, y: 12)
            )
            .offset(y: max(0, dragOffset.height))
            .scaleEffect(cardScale)
            // 3D Horizontal Flip along Y axis
            .rotation3DEffect(
                .degrees(flipAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            // Pull-down Drag Gesture (Video 2 Dismiss)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation
                            if value.translation.height > 90 && !hasHapticTriggered {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                hasHapticTriggered = true
                            } else if value.translation.height <= 90 && hasHapticTriggered {
                                hasHapticTriggered = false
                            }
                        } else {
                            dragOffset = CGSize(width: value.translation.width * 0.15, height: value.translation.height * 0.1)
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 90 || value.predictedEndTranslation.height > 180 {
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
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
