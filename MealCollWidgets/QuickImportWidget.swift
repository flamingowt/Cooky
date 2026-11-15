import WidgetKit
import SwiftUI

struct QuickImportEntry: TimelineEntry {
    let date: Date
    let nickname: String
}

struct QuickImportProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickImportEntry {
        QuickImportEntry(date: Date(), nickname: WidgetDataProvider.loadUserNickname())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuickImportEntry) -> Void) {
        completion(QuickImportEntry(date: Date(), nickname: WidgetDataProvider.loadUserNickname()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickImportEntry>) -> Void) {
        completion(Timeline(entries: [QuickImportEntry(date: Date(), nickname: WidgetDataProvider.loadUserNickname())], policy: .never))
    }
}

struct QuickImportWidgetView: View {
    let entry: QuickImportEntry
    
    var body: some View {
        GeometryReader { geo in
            let horizontalPad: CGFloat = 16
            let verticalPad: CGFloat = 14
            let spacing: CGFloat = 12
            let contentWidth = max(220, geo.size.width - horizontalPad * 2)
            let tileWidth = (contentWidth - spacing * 2) / 3.0
            let availableTileHeight = max(68, geo.size.height - verticalPad * 2 - 34)
            let tileHeight = min(tileWidth, availableTileHeight)
            
            VStack(spacing: 12) {
                // 顶部品牌与功能标签：与下方三枚卡片左右边缘严格对齐
                HStack(alignment: .center) {
                    WidgetBrandLogoView(nickname: entry.nickname, fontSize: 15.5)
                    
                    Spacer()
                    
                    Text("快捷入库")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.045))
                        .clipShape(Capsule())
                }
                .frame(width: contentWidth)
                
                // 三枚等比例黑白极简圆角正方形按钮（拍照 / 相册 / 链接）
                HStack(spacing: spacing) {
                    quickImportSquare(
                        icon: "camera.fill",
                        title: "拍照识别",
                        width: tileWidth,
                        height: tileHeight,
                        url: URL(string: "mealcoll://import?source=camera")!
                    )
                    
                    quickImportSquare(
                        icon: "photo.on.rectangle.angled",
                        title: "相册导入",
                        width: tileWidth,
                        height: tileHeight,
                        url: URL(string: "mealcoll://import?source=album")!
                    )
                    
                    quickImportSquare(
                        icon: "link",
                        title: "粘贴链接",
                        width: tileWidth,
                        height: tileHeight,
                        url: URL(string: "mealcoll://import?source=link")!
                    )
                }
                .frame(width: contentWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            Color(uiColor: .systemGroupedBackground)
        }
    }
    
    private func quickImportSquare(
        icon: String,
        title: String,
        width: CGFloat,
        height: CGFloat,
        url: URL
    ) -> some View {
        Link(destination: url) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.055), lineWidth: 0.6)
            )
        }
    }
}

struct MealCollQuickImportWidget: Widget {
    let kind = "MealCollQuickImportWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickImportProvider()) { entry in
            QuickImportWidgetView(entry: entry)
        }
        .configurationDisplayName("快捷入库")
        .description("一键拍照识别、相册导入或粘贴链接解析菜谱")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

