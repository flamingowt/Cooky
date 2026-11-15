import SwiftUI

public struct MinimalistAvatarView: View {
    @ObservedObject private var dataManager = RecipeDataManager.shared
    public let size: CGFloat
    public let showCameraBadge: Bool
    public var onCameraTap: (() -> Void)? = nil
    
    public init(size: CGFloat = 80, showCameraBadge: Bool = false, onCameraTap: (() -> Void)? = nil) {
        self.size = size
        self.showCameraBadge = showCameraBadge
        self.onCameraTap = onCameraTap
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main Black & White Minimalist Avatar (黑白色简约默认风格)
            Group {
                if let data = dataManager.customAvatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.16, green: 0.16, blue: 0.18),
                                        Color(red: 0.08, green: 0.08, blue: 0.09)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Image(systemName: dataManager.selectedAvatarPreset)
                            .font(.system(size: size * 0.44, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: size, height: size)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.14), radius: size * 0.08, y: size * 0.04)
            
            // Camera badge on bottom right (点进去头像右下角增加相机标识，可以点击更换头像)
            if showCameraBadge {
                let badgeSize = max(26, size * 0.34)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onCameraTap?()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.18, green: 0.18, blue: 0.20),
                                        Color(red: 0.10, green: 0.10, blue: 0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: badgeSize, height: badgeSize)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: badgeSize * 0.46, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color(uiColor: .systemBackground), lineWidth: 2.2)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
                }
                .buttonStyle(SpringyBadgeButtonStyle())
                .offset(x: 2, y: 2)
            }
        }
    }
}

// Apple design spring tactile button style
public struct SpringyBadgeButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

