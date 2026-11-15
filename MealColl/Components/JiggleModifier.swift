import SwiftUI

public struct JiggleModifier: ViewModifier {
    public let isJiggling: Bool
    public let seed: Int
    @State private var animate: Bool = false
    
    public init(isJiggling: Bool, seed: Int = 0) {
        self.isJiggling = isJiggling
        self.seed = abs(seed)
    }
    
    public func body(content: Content) -> some View {
        let duration = 0.125 + Double(seed % 4) * 0.015
        let delay = Double(seed % 5) * 0.02
        
        content
            .rotationEffect(.degrees(isJiggling ? (animate ? 1.3 : -1.3) : 0))
            .offset(
                x: isJiggling ? (animate ? 0.5 : -0.5) : 0,
                y: isJiggling ? (animate ? -0.4 : 0.4) : 0
            )
            .animation(
                isJiggling ?
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(delay) : .default,
                value: isJiggling ? animate : false
            )
            .onAppear {
                if isJiggling {
                    animate = true
                }
            }
            .onChange(of: isJiggling) { newValue in
                animate = newValue
            }
    }
}

public extension View {
    func jiggle(isJiggling: Bool, seed: Int = 0) -> some View {
        self.modifier(JiggleModifier(isJiggling: isJiggling, seed: seed))
    }
    
    func jiggle(isJiggling: Bool, index: Int) -> some View {
        self.modifier(JiggleModifier(isJiggling: isJiggling, seed: index))
    }
}

public struct DeleteBadgeButton: View {
    public let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .systemRed))
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.22), radius: 3, y: 1)
                
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}
