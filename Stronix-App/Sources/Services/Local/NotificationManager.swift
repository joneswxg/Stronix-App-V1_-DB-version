import Foundation
import UserNotifications
import UIKit
import AVFoundation

/// 通知管理器 - 处理推送通知、声音提醒和震动反馈
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // MARK: - 设置状态
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    @Published var vibrationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled")
        }
    }
    
    // MARK: - 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        // 从UserDefaults加载设置
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        self.vibrationEnabled = UserDefaults.standard.bool(forKey: "vibrationEnabled")
        
        // 如果是首次启动，设置默认值
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            self.notificationsEnabled = true
            self.soundEnabled = true
            self.vibrationEnabled = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
        
        setupAudioSession()
        requestNotificationPermission()
    }
    
    // MARK: - 音频会话设置
    private func setupAudioSession() {
        do {
            // 使用.playback模式支持后台音频播放
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ 音频会话设置成功 - 支持后台播放")
        } catch {
            print("❌ 音频会话设置失败: \(error)")
        }
    }
    
    // MARK: - 通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 通知权限请求失败: \(error)")
                } else {
                    print("✅ 通知权限: \(granted ? "已授权" : "被拒绝")")
                    if granted {
                        self?.notificationsEnabled = true
                    }
                }
            }
        }
    }
    
    /// 公开方法：请求通知权限
    func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.requestNotificationPermission()
                case .authorized, .provisional:
                    self.notificationsEnabled = true
                    print("✅ 通知权限已授权")
                case .denied:
                    self.notificationsEnabled = false
                    print("⚠️ 通知权限被拒绝，请在设置中开启")
                case .ephemeral:
                    self.notificationsEnabled = true
                    print("✅ 通知权限已授权（临时）")
                @unknown default:
                    self.notificationsEnabled = false
                    print("⚠️ 未知的通知权限状态")
                }
            }
        }
    }
    
    // MARK: - 推送通知
    func sendRestEndNotification(actionName: String, setNumber: Int, reps: Int) {
        guard notificationsEnabled else { 
            print("⚠️ 通知已禁用，跳过发送通知")
            return 
        }
        
        let content = UNMutableNotificationContent()
        content.title = "休息时间结束"
        content.body = "下一组: \(actionName) - 第\(setNumber)组 x \(reps)次"
        content.sound = soundEnabled ? .default : nil
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "restEndNotification_\(UUID().uuidString)",
            content: content,
            trigger: nil // 立即发送
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error)")
            } else {
                print("✅ 休息结束通知已发送: \(actionName) - 第\(setNumber)组")
            }
        }
    }
    
    // MARK: - 声音提醒
    func playCountdownSound() {
        guard soundEnabled else { return }
        
        // 使用系统音效
        AudioServicesPlaySystemSound(1054) // 滴滴声音
    }
    
    func playRestEndSound() {
        guard soundEnabled else { return }
        
        // 使用系统音效
        AudioServicesPlaySystemSound(1005) // 新邮件音效
    }
    
    // MARK: - 震动反馈
    func triggerVibration(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard vibrationEnabled else { return }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    func triggerNotificationVibration() {
        guard vibrationEnabled else { return }
        
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    // MARK: - 倒计时最后三秒提醒
    func triggerCountdownAlert() {
        playCountdownSound()
        triggerVibration(style: .medium) // 增强震动强度
    }
    
    // MARK: - 休息结束提醒
    func triggerRestEndAlert(actionName: String, setNumber: Int, reps: Int) {
        // 取消结束音效，只保留震动和通知
        triggerNotificationVibration()
        sendRestEndNotification(actionName: actionName, setNumber: setNumber, reps: reps)
    }
    
    // MARK: - 清理资源
    deinit {
        audioPlayer?.stop()
    }
}

// MARK: - 音频服务扩展
import AudioToolbox

extension NotificationManager {
    /// 播放系统音效的便捷方法
    private func playSystemSound(_ soundID: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}