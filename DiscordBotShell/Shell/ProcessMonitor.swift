//
//  ProcessMonitor.swift
//  DiscordBotShell
//
//  Created by Lakhan Lothiyi on 23/09/2024.
//

import UIKit
import UserNotifications
import AVFoundation

class ProcessMonitor {
  static let shared = ProcessMonitor()
  
  private var backgroundTaskID: UIBackgroundTaskIdentifier?
  private var isMonitoring = false
  
  private var audioPlayer: AVAudioPlayer? // AVAudioPlayer to play silent audio
  
  // Path to the silent audio file
  private var silentAudioFileURL: URL = {
    return Bundle.main.url(forResource: "Silence", withExtension: "m4a")!
  }()
  
  private init() {}
  
  // Start the monitoring process
  func startMonitoring() {
    guard !self.isMonitoring else { return }
    self.isMonitoring = true
    
    self.registerForNotifications()
    self.scheduleProcessKeepAliveNotification()
    
    DispatchQueue.global().async {
      // Start long-running tasks here, like audio playback
      do {
        // Set up and activate the audio session
        try AVAudioSession.sharedInstance().setActive(true)
        try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        print("Audio session started to prevent background termination.")
        
        // Start playing silent audio
        try self.startPlayingSilentAudio()
        
        // Continue monitoring in the background
        self.monitorProcessInBackground()
      } catch {
        print("Error starting audio session or silent audio: \(error)")
        self.sendNotification(title: "Error", message: "Failed to start process monitoring.")
      }
    }
  }
  
  // Start playing the silent audio to keep the app alive
  private func startPlayingSilentAudio() throws {
    // Initialize the AVAudioPlayer with the silent audio file
    self.audioPlayer = try AVAudioPlayer(contentsOf: self.silentAudioFileURL)
    self.audioPlayer?.numberOfLoops = -1 // Infinite loop to keep playing
    self.audioPlayer?.volume = 0.1       // Volume set to very low
    self.audioPlayer?.play()             // Start playing the silent audio
    print("Silent audio started playing.")
  }
  
  // Periodically checks and schedules background tasks to keep process alive
  private func monitorProcessInBackground() {
    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
      if UIApplication.shared.applicationState != .background {
        // Restart the monitoring after delay
        self.monitorProcessInBackground()
      }
    }
  }
  
  // Register for audio session interruption notifications
  private func registerForNotifications() {
    NotificationCenter.default.addObserver(self, selector: #selector(audioSessionWasInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
  }
  
  // Schedule a notification to keep the process alive
  private func scheduleProcessKeepAliveNotification() {
    let delay = 5 as TimeInterval
    
    let content = UNMutableNotificationContent()
    content.title = "App Is Running"
    content.body = "App is being kept alive to monitor process."
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay + 1, repeats: false)
    let request = UNNotificationRequest(identifier: "ProcessKeepAlive", content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request)
    
    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
      // Reschedule to keep process alive.
      self.scheduleProcessKeepAliveNotification()
    }
  }
  
  // Send a local notification with a title and message
  private func sendNotification(title: String, message: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
  
  // Handle audio session interruptions
  @objc private func audioSessionWasInterrupted(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
    
    switch type {
    case .began:
      self.sendNotification(title: "App", message: "Audio Session Interrupted")
      self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ProcessKeepAlive") {
        if let backgroundTaskID = self.backgroundTaskID {
          UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
      }
      
    case .ended:
      self.sendNotification(title: "App", message: "Audio Session Resumed")
      if let backgroundTaskID = self.backgroundTaskID {
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
      }
      
      // Resume silent audio playback if needed
      try? AVAudioSession.sharedInstance().setActive(true)
      self.audioPlayer?.play()
      
    @unknown default:
      break
    }
  }
}
