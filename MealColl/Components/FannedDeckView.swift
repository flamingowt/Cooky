import SwiftUI

// MARK: - Reusable Fanned Card Item View (Used both by FannedDeckView and CategoryDetailView collapse/expand)
public struct FannedCardItemView: View {
    public let dish: Dish
    
    public init(dish: Dish) {
        self.dish = dish
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            DishImageView(dish.imageName)
                .scaledToFill()
                .frame(width: 98, height: 142)
                .clipped()
            
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: 98, height: 142)
            
            Text(dish.name)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
        }
        .frame(width: 98, height: 142)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 6)
        )
    }
}

public struct FannedDeckView: View {
    public let dishes: [Dish]
    public let animationNamespace: Namespace.ID
    public var categoryId: String = ""
    public var isActiveCategory: Bool = false
    public var hideStaticCards: Bool = false
    
    public init(
        dishes: [Dish],
        animationNamespace: Namespace.ID,
        categoryId: String = "",
        isActiveCategory: Bool = false,
        hideStaticCards: Bool = false
    ) {
        self.dishes = dishes
        self.animationNamespace = animationNamespace
        self.categoryId = categoryId
        self.isActiveCategory = isActiveCategory
        self.hideStaticCards = hideStaticCards
    }
    
    public static func fanAngle(for index: Int) -> Double {
        switch index {
        case 0: return -10
        case 1: return 0
        case 2: return 10
        default: return 0
        }
    }
    
    public static func fanOffset(for index: Int) -> CGSize {
        switch index {
        case 0: return CGSize(width: -54, height: 6)
        case 1: return CGSize(width: 0, height: -4)
        case 2: return CGSize(width: 54, height: 6)
        default: return .zero
        }
    }
    
    public var body: some View {
        ZStack {
            ForEach(0..<min(3, dishes.count), id: \.self) { index in
                let dish = dishes[index]
                let angle = Self.fanAngle(for: index)
                let offset = Self.fanOffset(for: index)
                
                deckSlot(
                    dish: dish,
                    index: index,
                    angle: angle,
                    offset: offset,
                    zIndex: Double(index + 1)
                )
            }
        }
        .frame(height: 165)
    }
    
    @ViewBuilder
    private func deckSlot(
        dish: Dish,
        index: Int,
        angle: Double,
        offset: CGSize,
        zIndex: Double
    ) -> some View {
        ZStack {
            // Static fan card (visible when overlay is inactive)
            FannedCardItemView(dish: dish)
                .rotationEffect(.degrees(angle))
                .opacity(hideStaticCards ? 0.0 : 1.0)
                .animation(nil, value: hideStaticCards)
        }
        .offset(x: offset.width, y: offset.height)
        .zIndex(zIndex)
    }
}
