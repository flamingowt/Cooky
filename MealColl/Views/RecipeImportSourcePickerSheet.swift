import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// 极简三路径菜谱输入面板（相机、相册、链接等高三分，统一虚线框与视觉观感）
public struct RecipeImportSourcePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var workflowManager = RecipeAIWorkflowManager.shared
    
    // 链接导入状态
    @State private var linkText: String = ""
    @State private var isEditingLink: Bool = false
    @FocusState private var isLinkEditorFocused: Bool
    
    // 相机与相册状态
    @State private var showCamera: Bool = false
    @State private var selectedPhotosItems: [PhotosPickerItem] = []
    
    // 三分统一卡片高度
    private let cardHeight: CGFloat = 116
    public let startWithLinkEditor: Bool
    
    public init(startWithLinkEditor: Bool = false) {
        self.startWithLinkEditor = startWithLinkEditor
        self._isEditingLink = State(initialValue: startWithLinkEditor)
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                if !startWithLinkEditor && !isEditingLink {
                    // 1. 相机拍摄卡片（虚线圈，三分等高）
                    cameraDashedCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // 2. 相册导入卡片（虚线圈，三分等高）
                    photosPickerDashedCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // 3. 链接导入卡片（未展开时三分等高；点击后隐藏前两项并放大为可编辑区域）
                linkImportDashedCard
                
                // 全局解析中状态条（若有）
                if workflowManager.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text(workflowManager.statusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }
                
                if !isEditingLink {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, isEditingLink ? 16 : 0)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(
                onCaptureImage: { image in
                    dismiss()
                    Task {
                        await workflowManager.processImages(images: [image], sourceTag: "相机拍照")
                    }
                },
                onCaptureVideo: { videoURL in
                    dismiss()
                    Task {
                        await workflowManager.processVideo(url: videoURL, sourceTag: "相机录像")
                    }
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotosItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                // 优先检查是否包含视频（是视频走视频工作流，是照片走照片工作流）
                for item in newItems {
                    let isVideoType = item.supportedContentTypes.contains(where: {
                        $0.conforms(to: .movie) || $0.conforms(to: .video) || $0.conforms(to: .quickTimeMovie) || $0.conforms(to: .mpeg4Movie)
                    })
                    
                    if isVideoType {
                        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                            dismiss()
                            await workflowManager.processVideo(url: movie.url, sourceTag: "相册视频")
                            return
                        }
                    }
                }
                
                var loadedImages: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        loadedImages.append(img)
                    }
                }
                
                if !loadedImages.isEmpty {
                    dismiss()
                    await workflowManager.processImages(images: loadedImages, sourceTag: "相册照片")
                }
            }
        }
        .onAppear {
            if startWithLinkEditor && !isEditingLink {
                enterLinkEditMode()
            }
        }
    }
    
    // MARK: - 1. 相机拍摄卡片（虚线圈，三分等高）
    private var cameraDashedCard: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            requestCameraAndLaunch()
        }) {
            ZStack {
                // 统一虚线边框背景
                dashedCardBackground
                
                // 中心圆形图标
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground).opacity(0.85))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .frame(height: cardHeight)
        }
        .buttonStyle(ScaleCardButtonStyle())
    }
    
    // MARK: - 2. 相册导入卡片（虚线圈，三分等高）
    private var photosPickerDashedCard: some View {
        PhotosPicker(
            selection: $selectedPhotosItems,
            maxSelectionCount: 9,
            matching: .any(of: [.images, .videos])
        ) {
            ZStack {
                // 统一虚线边框背景
                dashedCardBackground
                
                // 中心圆形图标
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground).opacity(0.85))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .frame(height: cardHeight)
        }
        .buttonStyle(ScaleCardButtonStyle())
    }
    
    // MARK: - 3. 链接导入卡片（虚线圈；点击后隐藏拍照与相册并放大为可编辑区）
    private var linkImportDashedCard: some View {
        ZStack {
            // 统一虚线边框背景
            dashedCardBackground
            
            if !isEditingLink {
                // 空状态：居中圆形链接图标，与前两个卡片观感完全一致
                Button(action: {
                    enterLinkEditMode()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.89, green: 0.95, blue: 1.0))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleCardButtonStyle())
            } else {
                // 展开编辑状态：大尺寸可编辑文本区 + 剪贴板快捷粘贴 + 返回按钮 + 开始解析按钮
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                        
                        Text("粘贴或编辑菜谱链接")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            pasteFromClipboard()
                        }) {
                            Text("粘贴剪贴板")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(red: 0.89, green: 0.95, blue: 1.0))
                                .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            exitLinkEditMode()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.75))
                        
                        TextEditor(text: $linkText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.primary)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .focused($isLinkEditorFocused)
                        
                        if linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("请粘贴小红书 / 抖音 / B站分享链接或完整文案，支持直接编辑修改...")
                                .font(.system(size: 13.5))
                                .foregroundColor(Color(uiColor: .placeholderText))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Button(action: {
                        startParsingLink()
                    }) {
                        HStack(spacing: 6) {
                            if workflowManager.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                                Text("正在解析...")
                                    .font(.system(size: 15, weight: .bold))
                            } else {
                                Text("开始解析")
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.35) : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                    }
                    .disabled(workflowManager.isProcessing || linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
            }
        }
        .frame(maxHeight: isEditingLink ? .infinity : cardHeight)
        .frame(height: isEditingLink ? nil : cardHeight)
    }
    
    // MARK: - 通用统一虚线边框背景
    private var dashedCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                style: StrokeStyle(lineWidth: 1.6, dash: [7, 5])
            )
            .foregroundColor(Color(uiColor: .separator).opacity(0.8))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
            )
    }
    
    // MARK: - Actions
    private func enterLinkEditMode() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let clipboardString = UIPasteboard.general.string,
           !clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            linkText = clipboardString
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
            isEditingLink = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isLinkEditorFocused = true
        }
    }
    
    private func exitLinkEditMode() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isLinkEditorFocused = false
        if startWithLinkEditor {
            dismiss()
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
            linkText = ""
            isEditingLink = false
        }
    }
    
    private func pasteFromClipboard() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let clipboardString = UIPasteboard.general.string,
           !clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                linkText = clipboardString
            }
        }
    }
    
    private func startParsingLink() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let urlToProcess = linkText
        dismiss()
        Task {
            await workflowManager.processLink(urlString: urlToProcess)
        }
    }
    
    private func requestCameraAndLaunch() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showCamera = true
                    }
                }
            }
        case .authorized:
            self.showCamera = true
        case .denied, .restricted:
            print("⚠️ [Camera] Camera access denied or restricted")
        @unknown default:
            break
        }
    }
}

// MARK: - Safe Camera Controller
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCaptureImage: (UIImage) -> Void
    let onCaptureVideo: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.mediaTypes = ["public.image", "public.movie"]
            picker.videoQuality = .typeHigh
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.onCaptureVideo(videoURL)
            } else if let img = info[.originalImage] as? UIImage {
                parent.onCaptureImage(img)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Video Transferable Helper
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copyURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: received.file, to: copyURL)
            return VideoTransferable(url: copyURL)
        }
    }
}
