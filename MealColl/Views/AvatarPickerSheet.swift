import SwiftUI
import PhotosUI

public struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = RecipeDataManager.shared
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    private let presetIcons: [(id: String, name: String, icon: String)] = [
        ("person.fill", "经典人物", "person.fill"),
        ("sailboat.fill", "船长航海", "sailboat.fill"),
        ("fork.knife", "厨房主理", "fork.knife"),
        ("cup.and.saucer.fill", "慢调生活", "cup.and.saucer.fill"),
        ("flame.fill", "生活烟火", "flame.fill"),
        ("sparkles", "灵感闪耀", "sparkles")
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Drag Indicator Header
                Capsule()
                    .fill(Color(uiColor: .tertiaryLabel))
                    .frame(width: 36, height: 4.5)
                    .padding(.top, 10)
                
                // Title
                VStack(spacing: 4) {
                    Text("更换头像")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("选择个性化预设或从相册挑选专属照片")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                }
                
                // 1. PhotosPicker Action Button (从相册挑选)
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16, weight: .semibold))
                        Text("从相册选取照片")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
                }
                .onChange(of: selectedPhotoItem) { newItem in
                    guard let item = newItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                dataManager.setCustomAvatar(data: data)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                        }
                    }
                }
                
                // 2. Minimalist Black & White Presets (黑白极简预设)
                VStack(alignment: .leading, spacing: 10) {
                    Text("黑白简约风格预设")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(presetIcons, id: \.id) { preset in
                            let isSelected = (dataManager.customAvatarData == nil && dataManager.selectedAvatarPreset == preset.icon)
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                dataManager.setAvatarPreset(preset.icon)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }) {
                                VStack(spacing: 8) {
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
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 21, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isSelected ? Color.accentColor : Color.white.opacity(0.12),
                                                lineWidth: isSelected ? 2.5 : 1.0
                                            )
                                    )
                                    .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.08), radius: 4, y: 2)
                                    
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? Color.accentColor : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(uiColor: .systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(SpringyBadgeButtonStyle())
                        }
                    }
                }
                
                Spacer(minLength: 10)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
    }
}

