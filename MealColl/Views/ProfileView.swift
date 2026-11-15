import SwiftUI

public struct ProfileView: View {
    public let onDismiss: () -> Void
    @ObservedObject private var dataManager = RecipeDataManager.shared
    
    @State private var showTrashCan: Bool = false
    @State private var selectedDetailTitle: String? = nil
    @State private var showLogoutAlert: Bool = false
    @State private var showVersionToast: Bool = false
    
    // Olive green for "退出登录" exactly as shown in Image 2 (#95C033 / #8DB826)
    private let logoutOliveGreen = Color(red: 0.584, green: 0.753, blue: 0.200)
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Custom Navigation Bar (Image 2 exact: < on left, "设置" in center)
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onDismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    Text("设置")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Empty placeholder to keep title centered
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 6)
                
                // Settings List matching Image 2
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 1. 隐私政策
                        settingRow(title: "隐私政策") {
                            selectedDetailTitle = "隐私政策"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 2. 用户协议
                        settingRow(title: "用户协议") {
                            selectedDetailTitle = "用户协议"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 3. “船长私厨”AI功能使用规范 (Image 2 style)
                        settingRow(title: "“船长私厨”AI功能使用规范") {
                            selectedDetailTitle = "“船长私厨”AI功能使用规范"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 4. 申请使用权限
                        settingRow(title: "申请使用权限") {
                            selectedDetailTitle = "申请使用权限"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 5. 相册设置
                        settingRow(title: "相册设置") {
                            selectedDetailTitle = "相册设置"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 6. 版本号 (Detail: 1.2.0, no chevron)
                        settingRow(title: "版本号", detail: "1.2.0") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dataManager.showToast("已是最新版本 (v1.2.0)")
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 7. 资质证照
                        settingRow(title: "资质证照") {
                            selectedDetailTitle = "资质证照"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 8. 开源软件声明
                        settingRow(title: "开源软件声明") {
                            selectedDetailTitle = "开源软件声明"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 9. 账号与安全
                        settingRow(title: "账号与安全") {
                            selectedDetailTitle = "账号与安全"
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 10. 我的回收站 (Integrated with trash badge count)
                        let trashCount = dataManager.deletedCategories.count + dataManager.deletedDishes.count
                        settingRow(title: "我的回收站", badgeCount: trashCount) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showTrashCan = true
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // 11. 退出登录 (Image 2 exact: olive green text, left-aligned)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Text("退出登录")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(logoutOliveGreen)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showTrashCan) {
            TrashCanView(dataManager: dataManager) {
                showTrashCan = false
            }
        }
        .sheet(item: Binding<DetailSheetItem?>(
            get: { selectedDetailTitle.map { DetailSheetItem(title: $0) } },
            set: { selectedDetailTitle = $0?.title }
        )) { item in
            SettingsDetailSheet(title: item.title)
        }
        .alert("退出登录", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) {}
            Button("确定退出", role: .destructive) {
                dataManager.showToast("已安全退出账号")
                onDismiss()
            }
        } message: {
            Text("确定要退出“船长私厨”当前登录账号吗？")
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-testTrashCan") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTrashCan = true
                }
            }
        }
    }
    
    // MARK: - Row Builder matching Image 2
    @ViewBuilder
    private func settingRow(title: String, detail: String? = nil, badgeCount: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                } else {
                    HStack(spacing: 8) {
                        if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Detail Sheet Helper
private struct DetailSheetItem: Identifiable {
    let id = UUID()
    let title: String
}

private struct SettingsDetailSheet: View {
    let title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 10)
                    
                    Text(detailContent(for: title))
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .lineSpacing(6)
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func detailContent(for title: String) -> String {
        switch title {
        case "隐私政策":
            return "“船长私厨”高度重视您的个人隐私与数据安全。本应用所有菜谱数据、历史烹饪记录、自建分类及个人收藏均加密存储于本地设备沙盒中，未获得您的明确授权，绝不上传任何个人私密信息。\n\n如需同步或备份服务，将采用端到端加密传输协议，保障您拥有对个人数据的完全控制与随时清除权利。"
        case "用户协议":
            return "欢迎使用“船长私厨”应用。请仔细阅读本用户协议。通过使用本应用，您同意遵守关于食谱整理、分类管理、烹饪日历记录的相关使用条款。\n\n本应用鼓励健康饮食与烹饪创新，用户可自由管理个人食单与笔记。"
        case "“船长私厨”AI功能使用规范":
            return "本应用内包含由智能大模型驱动的菜谱提取与解析服务。用户在使用智能提取小红书、抖音、B站等链接时，应遵守知识产权及合理使用原则。\n\n系统生成的用料配比及烹饪建议仅供参考，请根据食材新鲜度与烹饪实际火候做出适度调整。"
        case "申请使用权限":
            return "为向您提供完整的私厨体验，“船长私厨”可能需要申请以下系统权限：\n\n1. 相册读取与写入：用于导入精美菜品图片与自定义个人头像；\n2. 剪贴板访问：用于在“导入食谱”页面便捷识别并粘贴第三方食谱链接；\n3. 通知权限：用于每日下厨提醒与饮食规划计划提示。"
        case "相册设置":
            return "当前已允许访问相册精选照片。您可以在“设置 - 隐私与安全性 - 照片”中随时调整“船长私厨”的照片访问权限级别（所有照片 / 选中的照片 / 无）。"
        case "资质证照":
            return "船长私厨移动客户端软件\n著作权登记号：2026SR889201\n开发者：船长工作室 (Captain Studio)\n软硬件兼容性：iOS 16.0 及以上版本。"
        case "开源软件声明":
            return "“船长私厨”的诞生离不开开源社区的卓越贡献。在此特别致谢以下开源项目与技术标准：\n\n· SwiftUI & Swift Standard Library\n· Apple SF Symbols\n· Combine Framework\n\n本项目所有开源组件均遵循 MIT / Apache 2.0 许可协议。"
        case "账号与安全":
            return "当前账号：船长私厨号 7779559087\n绑定手机：138****8888\n账号状态：安全保护中\n双重验证：已启用设备锁保护。"
        default:
            return "详细说明信息加载完成。"
        }
    }
}
