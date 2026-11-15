import SwiftUI

public struct TrashCanView: View {
    @ObservedObject var dataManager: RecipeDataManager
    public let onDismiss: () -> Void
    
    @State private var showClearConfirm: Bool = false
    
    public init(dataManager: RecipeDataManager, onDismiss: @escaping () -> Void) {
        self.dataManager = dataManager
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        Group {
                if dataManager.deletedCategories.isEmpty && dataManager.deletedDishes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 54))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                        
                        Text("回收站空空如也")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Text("长按卡片进入编辑模式后，点击减号删除的内容会出现在这里，可随时一键还原。")
                            .font(.system(size: 13))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Section 1: Deleted Categories
                        if !dataManager.deletedCategories.isEmpty {
                            Section(header: Text("已删除大类 (\(dataManager.deletedCategories.count))")) {
                                ForEach(dataManager.deletedCategories) { item in
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color(uiColor: .secondarySystemBackground))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: item.category.iconName)
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(red: 0.95, green: 0.65, blue: 0.35))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.category.name)
                                                .font(.system(size: 15, weight: .semibold))
                                            Text("含 \(item.category.dishes.count) 道菜品 · \(item.category.subtitle)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            dataManager.restoreCategory(item: item)
                                        }) {
                                            Text("还原")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule().fill(Color.blue.opacity(0.12))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            dataManager.deleteCategoryPermanently(id: item.id)
                                        } label: {
                                            Label("彻底删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Section 2: Deleted Dishes
                        if !dataManager.deletedDishes.isEmpty {
                            Section(header: Text("已删除菜品 (\(dataManager.deletedDishes.count))")) {
                                ForEach(dataManager.deletedDishes) { item in
                                    HStack(spacing: 14) {
                                        Image(item.dish.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.dish.name)
                                                .font(.system(size: 15, weight: .semibold))
                                            Text("原分类：\(item.originalCategoryName)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            dataManager.restoreDish(item: item)
                                        }) {
                                            Text("还原")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule().fill(Color.blue.opacity(0.12))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            dataManager.deleteDishPermanently(id: item.id)
                                        } label: {
                                            Label("彻底删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("我的回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !dataManager.deletedCategories.isEmpty || !dataManager.deletedDishes.isEmpty {
                        Button("清空") {
                            showClearConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
            .confirmationDialog("确定清空回收站吗？此操作无法撤销。", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空回收站", role: .destructive) {
                    dataManager.clearTrash()
                }
                Button("取消", role: .cancel) {}
            }
    }
}
