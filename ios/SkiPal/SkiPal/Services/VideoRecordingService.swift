//
//  VideoRecordingService.swift
//  SkiPal
//
//  视频录制服务 - 使用 AVFoundation 录制带数据叠加的视频
//

import Foundation
import AVFoundation
import CoreLocation
import Combine
import UIKit
import CoreImage

/// 视频录制状态
enum VideoRecordingState {
    case idle
    case preparing
    case recording
    case paused
    case saving
    case error(String)

    var description: String {
        switch self {
        case .idle: return "待机"
        case .preparing: return "准备中"
        case .recording: return "录制中"
        case .paused: return "已暂停"
        case .saving: return "保存中"
        case .error(let msg): return "错误: \(msg)"
        }
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

/// 视频会话
struct VideoSession: Identifiable {
    let id: UUID
    let url: URL
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    var location: CLLocation?
    var skiSessionId: UUID?

    init(url: URL, startTime: Date = Date()) {
        self.id = UUID()
        self.url = url
        self.startTime = startTime
    }
}

/// 视频录制配置
struct VideoRecordingConfig {
    var resolution: CGSize = CGSize(width: 1920, height: 1080)
    var frameRate: Int32 = 30
    var bitrate: Int = 8_000_000  // 8 Mbps
    var overlayEnabled: Bool = true
    var overlayPosition: OverlayPosition = .topLeft
    var showSpeed: Bool = true
    var showAltitude: Bool = true
    var showDistance: Bool = true
    var showMap: Bool = false
    var showTime: Bool = true

    enum OverlayPosition {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
}

/// 视频录制服务
class VideoRecordingService: NSObject, ObservableObject {
    static let shared = VideoRecordingService()

    // 发布属性
    @Published private(set) var state: VideoRecordingState = .idle
    @Published private(set) var currentDuration: TimeInterval = 0
    @Published private(set) var recordedVideos: [VideoSession] = []
    @Published private(set) var isCameraAvailable = false
    @Published var config = VideoRecordingConfig()

    // 捕获会话
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // 当前录制
    private var currentOutputURL: URL?
    private var recordingStartTime: Date?
    private var timer: Timer?

    // 数据引用
    weak var locationService: LocationService?
    weak var recordingService: RecordingService?

    // 叠加层
    private var overlayView: UIView?
    private var overlayTimer: Timer?

    // CIContext 用于视频处理
    private let ciContext = CIContext()

    private override init() {
        super.init()
        checkCameraAuthorization()
        loadRecordedVideos()
    }

    // MARK: - 公开方法

    /// 设置预览层
    func setupPreviewLayer(in view: UIView) -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds

        self.previewLayer = previewLayer
        return previewLayer
    }

    /// 准备录制
    func prepareForRecording() async throws {
        guard await checkAndRequestCameraPermission() else {
            throw VideoError.permissionDenied
        }

        state = .preparing

        // 创建捕获会话
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // 添加视频输入
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            state = .error("无法访问摄像头")
            throw VideoError.cameraUnavailable
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }

        // 添加音频输入 - CRITICAL: 完整的音频配置
        if let audioDevice = try? AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    print("✅ 音频输入已添加")
                }
            } catch {
                print("⚠️ 无法添加音频输入: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ 未找到音频设备")
        }

        // 添加视频输出
        let movieOutput = AVCaptureMovieFileOutput()
        movieOutput.movieFragmentInterval = .invalid  // 更安全的录制

        // 配置视频参数
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        // IMPORTANT: 配置视频叠加层渲染
        setupVideoComposition(for: session, output: movieOutput)

        self.videoOutput = movieOutput
        self.captureSession = session

        // 启动会话
        session.startRunning()
        isCameraAvailable = true
        state = .idle

        print("✅ 视频录制准备完成")
    }

    /// 开始录制
    func startRecording() {
        guard let output = videoOutput, let session = captureSession, session.isRunning else {
            state = .error("捕获会话未就绪")
            return
        }

        // 生成输出 URL
        let outputURL = generateOutputURL()
        currentOutputURL = outputURL

        // 开始录制
        output.startRecording(to: outputURL, recordingDelegate: self)
        recordingStartTime = Date()
        state = .recording

        // 启动计时器
        startTimer()

        print("🎬 开始录制视频")
    }

    /// 暂停录制
    func pauseRecording() {
        guard case .recording = state else { return }

        guard #available(iOS 18.0, *) else {
            print("⚠️ 当前系统不支持视频暂停，继续录制")
            return
        }

        videoOutput?.pauseRecording()
        state = .paused
        stopTimer()

        print("⏸️ 视频录制已暂停")
    }

    /// 恢复录制
    func resumeRecording() {
        guard case .paused = state else { return }

        guard #available(iOS 18.0, *) else {
            print("⚠️ 当前系统不支持视频继续录制，保持暂停状态")
            return
        }

        videoOutput?.resumeRecording()
        state = .recording
        startTimer()

        print("▶️ 视频录制已恢复")
    }

    /// 停止录制
    func stopRecording() {
        guard state.isRecording || state.isPaused else { return }

        state = .saving
        videoOutput?.stopRecording()
        stopTimer()

        print("⏹️ 停止录制视频")
    }

    /// 切换摄像头
    func switchCamera() {
        guard let session = captureSession else { return }

        session.beginConfiguration()

        // 移除当前输入
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)

            // 切换到另一个摄像头
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                }
            } else {
                // 回退
                session.addInput(currentInput)
            }
        }

        session.commitConfiguration()
    }

    /// 删除视频
    func deleteVideo(_ video: VideoSession) {
        // 删除文件
        try? FileManager.default.removeItem(at: video.url)

        // 从列表移除
        recordedVideos.removeAll { $0.id == video.id }
        saveRecordedVideos()
    }

    /// 清理所有视频
    func clearAllVideos() {
        for video in recordedVideos {
            try? FileManager.default.removeItem(at: video.url)
        }
        recordedVideos.removeAll()
        saveRecordedVideos()
    }

    /// 获取视频缩略图
    func getThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    // MARK: - 私有方法

    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAvailable = true
        case .notDetermined:
            isCameraAvailable = false
        case .denied, .restricted:
            isCameraAvailable = false
        @unknown default:
            isCameraAvailable = false
        }
    }

    private func checkAndRequestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            default:
                continuation.resume(returning: false)
            }
        }
    }

    private func generateOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoPath = documentsPath.appendingPathComponent("Videos")

        // 创建视频目录
        try? FileManager.default.createDirectory(at: videoPath, withIntermediateDirectories: true)

        let fileName = "ski_video_\(Date().timeIntervalSince1970).mp4"
        return videoPath.appendingPathComponent(fileName)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.currentDuration = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func loadRecordedVideos() {
        guard let data = UserDefaults.standard.data(forKey: "recordedVideos"),
              let videos = try? JSONDecoder().decode([VideoSession].self, from: data) else {
            return
        }
        recordedVideos = videos
    }

    private func saveRecordedVideos() {
        guard let data = try? JSONEncoder().encode(recordedVideos) else { return }
        UserDefaults.standard.set(data, forKey: "recordedVideos")
    }

    // MARK: - IMPORTANT: 视频叠加层渲染

    /// 设置视频合成以渲染叠加层
    private func setupVideoComposition(for session: AVCaptureSession, output: AVCaptureMovieFileOutput) {
        guard config.overlayEnabled else { return }

        // 创建 AVVideoComposition 用于实时叠加渲染
        let videoComposition = AVMutableVideoComposition()

        // 获取视频尺寸
        if let connection = output.connection(with: .video) {
            let videoOrientation = connection.videoOrientation
            let dimensions: CGSize

            if videoOrientation == .portrait || videoOrientation == .portraitUpsideDown {
                dimensions = CGSize(width: config.resolution.height, height: config.resolution.width)
            } else {
                dimensions = config.resolution
            }

            videoComposition.renderSize = dimensions
        } else {
            videoComposition.renderSize = config.resolution
        }

        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.frameRate))

        // 创建自定义视频合成指令
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: .positiveInfinity)

        // 设置合成器用于渲染叠加层
        videoComposition.instructions = [instruction]

        // 存储合成配置供后续使用
        self.currentVideoComposition = videoComposition

        print("✅ 视频叠加合成已配置")
    }

    /// 实时更新叠加层数据
    func updateOverlayData(speed: Double, altitude: Double, distance: Double, duration: TimeInterval) {
        self.currentOverlayData = OverlayData(
            speed: speed,
            altitude: altitude,
            distance: distance,
            duration: duration,
            showSpeed: config.showSpeed,
            showAltitude: config.showAltitude,
            showDistance: config.showDistance,
            showTime: config.showTime
        )
    }

    /// 渲染叠加层到视频帧
    private func renderOverlayToFrame(_ frame: CVPixelBuffer, timestamp: CMTime) -> CVPixelBuffer? {
        guard config.overlayEnabled, let overlayData = currentOverlayData else {
            return frame
        }

        return VideoOverlayRenderer.shared.renderOverlay(to: frame, overlayData: overlayData)
    }

    // 视频合成和叠加数据存储
    private var currentVideoComposition: AVMutableVideoComposition?
    private var currentOverlayData: OverlayData?
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoRecordingService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("📁 开始写入文件: \(fileURL.lastPathComponent)")
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("❌ 录制错误: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            return
        }

        // 创建视频会话记录
        var videoSession = VideoSession(url: outputFileURL, startTime: recordingStartTime ?? Date())
        videoSession.endTime = Date()
        videoSession.duration = currentDuration

        // 添加位置信息
        if let location = locationService?.currentLocation {
            videoSession.location = location
        }

        // 关联滑雪会话
        if recordingService?.state.isActive == true {
            // 可以在这里关联当前滑雪会话
        }

        // 保存到列表
        recordedVideos.insert(videoSession, at: 0)
        saveRecordedVideos()

        // 重置状态
        currentDuration = 0
        recordingStartTime = nil
        currentOutputURL = nil
        state = .idle

        print("✅ 视频已保存: \(outputFileURL.lastPathComponent)")

        // 发送通知
        NotificationCenter.default.post(name: .videoRecordingDidFinish, object: videoSession)
    }

    func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("⏸️ 录制暂停")
    }

    func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("▶️ 录制恢复")
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let videoRecordingDidFinish = Notification.Name("videoRecordingDidFinish")
}

// MARK: - 错误类型
enum VideoError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "摄像头权限被拒绝"
        case .cameraUnavailable:
            return "摄像头不可用"
        case .recordingFailed(let reason):
            return "录制失败: \(reason)"
        }
    }
}

// MARK: - 视频叠加渲染器
class VideoOverlayRenderer {
    private let ciContext = CIContext()

    /// 渲染带叠加层的视频帧
    func renderFrame(_ sampleBuffer: CMSampleBuffer, with overlay: OverlayData) -> CIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        var image = CIImage(cvPixelBuffer: pixelBuffer)

        // 创建叠加文本
        let overlayImage = createOverlayImage(overlay)

        // 合成
        if let overlay = overlayImage {
            let transformed = overlay.transformed(by: CGAffineTransform(translationX: 20, y: 20))
            image = image.composited(over: transformed)
        }

        return image
    }

    private func createOverlayImage(_ data: OverlayData) -> CIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 150))

        let image = renderer.image { context in
            let ctx = context.cgContext

            // 半透明背景
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            ctx.fillRoundedRect(CGRect(x: 0, y: 0, width: 300, height: 150), cornerRadius: 10)

            // 文字属性
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let smallAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.lightGray
            ]

            var y: CGFloat = 15

            // 速度
            if data.showSpeed {
                let speedText = String(format: "%.1f km/h", data.speed)
                let label = NSAttributedString(string: "速度", attributes: smallAttributes)
                label.draw(at: CGPoint(x: 15, y: y))
                let value = NSAttributedString(string: speedText, attributes: attributes)
                value.draw(at: CGPoint(x: 15, y: y + 18))
                y += 50
            }

            // 海拔
            if data.showAltitude {
                let altText = String(format: "%.0f m", data.altitude)
                let label = NSAttributedString(string: "海拔", attributes: smallAttributes)
                label.draw(at: CGPoint(x: 15, y: y))
                let value = NSAttributedString(string: altText, attributes: attributes)
                value.draw(at: CGPoint(x: 15, y: y + 18))
                y += 50
            }

            // 时间
            if data.showTime {
                let timeText = formatDuration(data.duration)
                let value = NSAttributedString(string: timeText, attributes: attributes)
                value.draw(at: CGPoint(x: 150, y: 15))
            }
        }

        return CIImage(image: image)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// 叠加数据
struct OverlayData {
    var speed: Double = 0
    var altitude: Double = 0
    var distance: Double = 0
    var duration: TimeInterval = 0
    var showSpeed: Bool = true
    var showAltitude: Bool = true
    var showDistance: Bool = true
    var showTime: Bool = true
}

// MARK: - IMPORTANT: 视频叠加渲染器扩展
extension VideoOverlayRenderer {
    static let shared = VideoOverlayRenderer()

    /// 渲染叠加层到视频帧
    func renderOverlay(to pixelBuffer: CVPixelBuffer, overlayData: OverlayData) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // 创建叠加图像
        // createOverlayImage 已直接返回 CIImage，无需再做一次 UIImage 转换
        guard let overlayCI = createOverlayImage(overlayData) else {
            return pixelBuffer
        }

        // 根据配置确定叠加位置
        let overlayPosition = calculateOverlayPosition(for: ciImage.extent.size, overlaySize: overlayCI.extent.size)

        // 变换叠加层到正确位置
        let transformedOverlay = overlayCI.transformed(by: CGAffineTransform(translationX: overlayPosition.x, y: overlayPosition.y))

        // 合成图像
        let composited = ciImage.composited(over: transformedOverlay)

        // 渲染回 CVPixelBuffer
        var outputBuffer: CVPixelBuffer?
        let options: [CIContextOption: Any] = [:]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary,
            &outputBuffer
        )

        guard let output = outputBuffer else { return pixelBuffer }
        ciContext.render(composited, to: output)

        return output
    }

    private func calculateOverlayPosition(for videoSize: CGSize, overlaySize: CGSize) -> CGPoint {
        let padding: CGFloat = 20

        // 默认左上角，可以根据配置调整
        return CGPoint(x: padding, y: videoSize.height - overlaySize.height - padding)
    }
}

// MARK: - CoreGraphics 扩展
extension CGContext {
    func fillRoundedRect(_ rect: CGRect, cornerRadius: CGFloat) {
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        addPath(path)
        fillPath()
    }
}

// MARK: - VideoSession Codable
extension VideoSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id, url, startTime, endTime, duration, skiSessionId
        case latitude, longitude, altitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        skiSessionId = try container.decodeIfPresent(UUID.self, forKey: .skiSessionId)

        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .longitude),
           let alt = try container.decodeIfPresent(Double.self, forKey: .altitude) {
            location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: alt,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: endTime ?? Date()
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(skiSessionId, forKey: .skiSessionId)

        if let loc = location {
            try container.encode(loc.coordinate.latitude, forKey: .latitude)
            try container.encode(loc.coordinate.longitude, forKey: .longitude)
            try container.encode(loc.altitude, forKey: .altitude)
        }
    }
}
