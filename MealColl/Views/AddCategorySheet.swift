import SwiftUI

public struct AddCategorySheet: View {
    @ObservedObject var dataManager: RecipeDataManager
    public let onDismiss: () -> Void
    
    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var selectedIcon: String = "fork.knife"
    
    private let availableIcons = [
        "fork.knife",
        "flame.fill",
        "leaf.fill",
        "fish.fill",
        "cup.and.saucer.fill",
        "takeoutbag.and.cup.and.straw.fill",
        "carrot.fill",
        "heart.fill",
        "sparkles",
        "wineglass.fill"
    ]
    
    public init(dataManager: RecipeDataManager, onDismiss: @escaping () -> Void) {
        self.dataManager = dataManager
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("分类基本信息")) {
                    TextField("例如：减脂轻食 / 惬意早午餐", text: $name)
                    TextField("副标题介绍（可选，如：少油轻负担）", text: $subtitle)
                }
                
                Section(header: Text("挑选分类图标")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 46))], spacing: 14) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedIcon = icon
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(red: 0.95, green: 0.65, blue: 0.35) : Color(uiColor: .secondarySystemBackground))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("新建大类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        saveNewCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
    
    private func saveNewCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        dataManager.addCategory(
            name: trimmedName,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIcon
        )
        onDismiss()
    }
}

