import SwiftUI

public struct CategoryCardView: View {
    public let category: DishCategory
    public let animationNamespace: Namespace.ID
    public var isActiveCategory: Bool = false
    public var isExpanded: Bool = false
    public var hideStaticFanCards: Bool = false
    public var isEditing: Bool = false
    public var isDragging: Bool = false
    public var index: Int = 0
    public let action: () -> Void
    public var actionWithFrame: ((CGRect, CGPoint) -> Void)? = nil
    public var onDelete: () -> Void = {}
    public var onLongPress: () -> Void = {}
    
    @State private var hasLongPressed: Bool = false
    @State private var fanCenter: CGPoint = .zero
    
    public init(
        category: DishCategory,
        animationNamespace: Namespace.ID,
        isActiveCategory: Bool = false,
        isExpanded: Bool = false,
        hideStaticFanCards: Bool = false,
        isEditing: Bool = false,
        isDragging: Bool = false,
        index: Int = 0,
        action: @escaping () -> Void,
        actionWithFrame: ((CGRect, CGPoint) -> Void)? = nil,
        onDelete: @escaping () -> Void = {},
        onLongPress: @escaping () -> Void = {}
    ) {
        self.category = category
        self.animationNamespace = animationNamespace
        self.isActiveCategory = isActiveCategory
        self.isExpanded = isExpanded
        self.hideStaticFanCards = hideStaticFanCards
        self.isEditing = isEditing
        self.isDragging = isDragging
        self.index = index
        self.action = action
        self.actionWithFrame = actionWithFrame
        self.onDelete = onDelete
        self.onLongPress = onLongPress
    }
    
    public var body: some View {
        GeometryReader { geo in
            Button(action: {
                if !isEditing && !RecipeDataManager.shared.isEditing && !hasLongPressed && !isDragging {
                    let cardFrame = geo.frame(in: .global)
                    let center = (fanCenter.y > 0) ? fanCenter : CGPoint(x: cardFrame.midX, y: cardFrame.minY + 184.0)
                    if let actionWithFrame = actionWithFrame {
                        actionWithFrame(cardFrame, center)
                    } else {
                        action()
                    }
                }
            }) {
                cardContent
            }
            .buttonStyle(.plain)
        }
        .frame(height: 284)
        .jiggle(isJiggling: isEditing && !isExpanded && !isDragging, seed: category.id.hashValue)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    guard !isExpanded && !isEditing && !RecipeDataManager.shared.isEditing else { return }
                    hasLongPressed = true
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onLongPress()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        hasLongPressed = false
                    }
                }
        )
    }
    
    private var cardContent: some View {
        VStack(spacing: 12) {
            // Top Meta: Timestamp & Item Count
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .medium))
                    Text(category.updatedTimeAgo)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color(uiColor: .secondaryLabel))
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "square.3.layers.3d.down.right")
                        .font(.system(size: 13, weight: .medium))
                    Text("\(category.count)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(uiColor: .secondaryLabel))
            }
            .padding(.horizontal, 4)
            .opacity(isExpanded ? 0.0 : 1.0)
            
            // Titles
            VStack(spacing: 4) {
                Text(category.name)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(category.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .padding(.top, 2)
            .opacity(isExpanded ? 0.0 : 1.0)
            
            // Fanned Card Covers with live source anchors
            FannedDeckView(
                dishes: category.dishes,
                animationNamespace: animationNamespace,
                categoryId: category.id,
                isActiveCategory: isActiveCategory,
                hideStaticCards: isActiveCategory && hideStaticFanCards
            )
            .background(
                GeometryReader { fanGeo in
                    Color.clear
                        .onAppear {
                            let f = fanGeo.frame(in: .global)
                            fanCenter = CGPoint(x: f.midX, y: f.midY)
                        }
                        .onChange(of: fanGeo.frame(in: .global)) { _, f in
                            fanCenter = CGPoint(x: f.midX, y: f.midY)
                        }
                }
            )
            .padding(.top, 4)
            .padding(.bottom, 6)
            .opacity(isActiveCategory ? 1.0 : (isExpanded ? 0.0 : 1.0))
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(height: 284)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.black.opacity(0.03), lineWidth: 1)
                )
                .opacity(isExpanded ? 0.0 : 1.0)
        )
        .overlay(alignment: .topTrailing) {
            DeleteBadgeButton {
                onDelete()
            }
            .offset(x: 6, y: -6)
            .scaleEffect((isEditing && !isExpanded) ? 1.0 : 0.001)
            .opacity((isEditing && !isExpanded) ? 1.0 : 0.0)
            .allowsHitTesting(isEditing && !isExpanded)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isEditing)
            .zIndex(60)
        }
    }
}
