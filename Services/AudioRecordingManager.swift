import Foundation
import AVFoundation
import Combine

/// 管理 iOS 錄音，支援背景錄音（鎖屏不中斷）
@MainActor
final class AudioRecordingManager: NSObject, ObservableObject {
    static let shared = AudioRecordingManager()
    private override init() { super.init() }

    // MARK: - Published state

    @Published var isRecording = false
    @Published var elapsedSeconds: Int = 0
    @Published var audioLevel: Float = 0.0  // 0.0 ~ 1.0，給波形 UI 用
    @Published var error: String?

    // MARK: - Private

    private var recorder: AVAudioRecorder?
    private var currentFileURL: URL?
    private var timer: Timer?
    private var levelTimer: Timer?

    // MARK: - Public API

    func startRecording() async -> URL? {
        do {
            try setupAudioSession()
        } catch {
            self.error = "無法設定錄音：\(error.localizedDescription)"
            return nil
        }

        let fileURL = makeFileURL()
        let settings: [String: Any] = [
            AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:          44100,
            AVNumberOfChannelsKey:    1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.record()
        } catch {
            self.error = "無法開始錄音：\(error.localizedDescription)"
            return nil
        }

        currentFileURL = fileURL
        isRecording = true
        elapsedSeconds = 0
        startTimers()
        return fileURL
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        stopTimers()
        isRecording = false

        // 停用 audio session 讓其他 App 恢復音訊
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return currentFileURL
    }

    // MARK: - Private helpers

    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .record + allowBluetooth 允許使用 AirPods/藍牙耳機麥克風
        try session.setCategory(.record, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try session.setActive(true)

        // 監聽中斷事件（接電話、Siri 等）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .ended {
            // 中斷結束後（如通話結束）恢復錄音
            if let optionValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    recorder?.record()
                }
            }
        }
    }

    private func makeFileURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(UUID().uuidString + ".m4a")
    }

    private func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recorder?.updateMeters()
                let power = self?.recorder?.averagePower(forChannel: 0) ?? -60
                // 將 dB (-60 ~ 0) 轉換為 0.0 ~ 1.0
                let normalized = max(0, min(1, (power + 60) / 60))
                self?.audioLevel = normalized
            }
        }
    }

    private func stopTimers() {
        timer?.invalidate(); timer = nil
        levelTimer?.invalidate(); levelTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.error = "錄音編碼錯誤：\(error?.localizedDescription ?? "未知")"
            self.isRecording = false
        }
    }
}

