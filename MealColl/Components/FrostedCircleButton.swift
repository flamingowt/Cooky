import SwiftUI

public struct FrostedCircleButton: View {
    public let iconName: String
    public let size: CGFloat
    public let iconSize: CGFloat
    public let action: () -> Void
    
    public init(
        iconName: String,
        size: CGFloat = 38,
        iconSize: CGFloat = 15,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.size = size
        self.iconSize = iconSize
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .systemBackground).opacity(0.88))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}



public struct ScaleCardButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        let shouldScale = configuration.isPressed && !RecipeDataManager.shared.isEditing
        configuration.label
            .scaleEffect(shouldScale ? 0.98 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: shouldScale)
    }
}
