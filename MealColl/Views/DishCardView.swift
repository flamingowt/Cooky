import SwiftUI

public struct DishCardView: View {
    public let dish: Dish
    public var isCompact: Bool = false
    public var isEditing: Bool = false
    public var isDragging: Bool = false
    public var index: Int = 0
    public let onCardTap: () -> Void
    public var onCardTapWithFrame: ((CGRect) -> Void)? = nil
    public var onDelete: () -> Void = {}
    public var onLongPress: () -> Void = {}
    
    @State private var hasLongPressed: Bool = false
    
    public init(
        dish: Dish,
        isCompact: Bool = false,
        isEditing: Bool = false,
        isDragging: Bool = false,
        index: Int = 0,
        onCardTap: @escaping () -> Void = {},
        onCardTapWithFrame: ((CGRect) -> Void)? = nil,
        onDelete: @escaping () -> Void = {},
        onLongPress: @escaping () -> Void = {}
    ) {
        self.dish = dish
        self.isCompact = isCompact
        self.isEditing = isEditing
        self.isDragging = isDragging
        self.index = index
        self.onCardTap = onCardTap
        self.onCardTapWithFrame = onCardTapWithFrame
        self.onDelete = onDelete
        self.onLongPress = onLongPress
    }
    
    public var body: some View {
        GeometryReader { geo in
            Button(action: {
                if !hasLongPressed && !isEditing && !isDragging && !RecipeDataManager.shared.isEditing {
                    onCardTapWithFrame?(geo.frame(in: .global))
                    onCardTap()
                }
            }) {
                cardContent(geo: geo)
            }
            .buttonStyle(ScaleCardButtonStyle())
        }
        .jiggle(isJiggling: isEditing && !isCompact && !isDragging, seed: dish.id.hashValue)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    guard !isCompact && !isEditing && !RecipeDataManager.shared.isEditing else { return }
                    hasLongPressed = true
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onLongPress()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        hasLongPressed = false
                    }
                }
        )
    }
    
    @ViewBuilder
    private func cardContent(geo: GeometryProxy) -> some View {
        let cornerRadius: CGFloat = isCompact ? 14 : 18
        
        ZStack(alignment: .bottom) {
            // Dish cover image dynamically sized to current animated geometry
            DishImageView(dish.imageName)
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            
            // Dark gradient overlay for typography readability
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: Color.black.opacity(0.35), location: 0.65),
                    .init(color: Color.black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: geo.size.width, height: geo.size.height)
            
            // Expanded Grid Metadata (smoothly fades in/out with expansion)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dish.tag)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.45))
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", dish.rating))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .opacity(isCompact ? 0.0 : 1.0)
                
                Text(dish.name)
                    .font(.system(size: isCompact ? 10 : 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
                
                if !isCompact {
                    Text(dish.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.82))
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, isCompact ? 6 : 10)
            .padding(.bottom, isCompact ? 6 : 12)
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: isCompact ? 8 : 10, x: 0, y: 6)
        )
        .overlay(alignment: .topTrailing) {
            DeleteBadgeButton {
                onDelete()
            }
            .offset(x: 6, y: -6)
            .scaleEffect((isEditing && !isCompact) ? 1.0 : 0.001)
            .opacity((isEditing && !isCompact) ? 1.0 : 0.0)
            .allowsHitTesting(isEditing && !isCompact)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isEditing)
            .zIndex(50)
        }
    }
}
