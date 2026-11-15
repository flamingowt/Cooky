import SwiftUI

public struct ToastBannerView: View {
    @ObservedObject var dataManager: RecipeDataManager
    
    public init(dataManager: RecipeDataManager) {
        self.dataManager = dataManager
    }
    
    public var body: some View {
        if let message = dataManager.toastMessage {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.95, green: 0.65, blue: 0.35))
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
                
                if dataManager.lastUndoAction != nil {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dataManager.undoLastDeleted()
                    }) {
                        Text("撤销")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(Color(red: 0.98, green: 0.76, blue: 0.42))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.96))
                    .shadow(color: Color.black.opacity(0.25), radius: 14, y: 6)
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
            )
            .padding(.horizontal, 22)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(999)
        }
    }
}

