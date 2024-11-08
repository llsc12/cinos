//
//  StdOutInterceptor.swift
//  DiscordBotShell
//
//  Created by Lakhan Lothiyi on 23/09/2024.
//

import Foundation

class StdOutInterceptor {
  static let shared = StdOutInterceptor()
  
  private let stdoutPipe = Pipe()
  private let stderrPipe = Pipe()
  
  private var stdoutBackup: Int32?
  private var stderrBackup: Int32?
  
  private var stdoutReader: FileHandle?
  private var stderrReader: FileHandle?
  
  private var logBuffer: [LogItem] = []
  
  private var isActive = false
  
  private init() {}
  
  // Parse lines from the string, generating LogItems for each line.
  func items(from str: String, source: LogItem.LogType) -> [LogItem] {
//    let lines = str.components(separatedBy: "\n")
//    return lines.map { LogItem(str: $0, type: source) }
    [.init(str: str, type: source)]
  }
  
  // Add log items based on incoming stdout or stderr
  func _addLog(_ item: String, source: LogItem.LogType) {
    guard isActive else { return }
    self.logBuffer.append(contentsOf: self.items(from: item, source: source))
  }
  
  func startIntercepting() {
    self.isActive = true
    
    // Backup original stdout and stderr
    stdoutBackup = dup(STDOUT_FILENO)
    stderrBackup = dup(STDERR_FILENO)
    
    // Redirect stdout and stderr to pipes
    dup2(stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    dup2(stderrPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
    
    setbuf(stdout, nil)  // Disable buffering on stdout
    setbuf(stderr, nil)  // Disable buffering on stderr
    
    stdoutReader = stdoutPipe.fileHandleForReading
    stderrReader = stderrPipe.fileHandleForReading
    
    // Handle stdout data
    stdoutReader?.readabilityHandler = { handle in
      let data = handle.availableData
      if !data.isEmpty {
        let output = String(decoding: data, as: UTF8.self)
        self._addLog(output, source: .out)
        
        // Restore output to the real console
        FileHandle(fileDescriptor: self.stdoutBackup!).write(data)
        
        // Optionally, notify the UI that there's new log data
        NotificationCenter.default.post(name: .newLogAdded, object: nil)
      }
    }
    
    // Handle stderr data
    stderrReader?.readabilityHandler = { handle in
      let data = handle.availableData
      if !data.isEmpty {
        let output = String(decoding: data, as: UTF8.self)
        self._addLog(output, source: .err)
        
        // Restore output to the real console
        FileHandle(fileDescriptor: self.stderrBackup!).write(data)
        
        // Optionally, notify the UI that there's new log data
        NotificationCenter.default.post(name: .newLogAdded, object: nil)
      }
    }
  }
  
  func stopIntercepting() {
    self.isActive = false
    
    // Restore original stdout and stderr
    if let stdoutBackup = stdoutBackup {
      dup2(stdoutBackup, STDOUT_FILENO)
    }
    if let stderrBackup = stderrBackup {
      dup2(stderrBackup, STDERR_FILENO)
    }
  }
  
  struct LogItem: Identifiable, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    
    let id: UUID = UUID()
    let str: String
    var type: LogType
    
    init(str: String, type: LogType) {
      // Extract and analyze OSLog metadata first
      let (metadata, cleanedLog) = LogItem.extractAndCleanMetadata(from: str)
      
      // Determine the log type based on the metadata
      self.type = LogItem.determineLogType(from: metadata, defaultType: type)
      
      // Set the cleaned-up log string
      self.str = cleanedLog
    }
    
    // Enum to represent the log type (stdout, warning, error)
    enum LogType {
      case out // out
      case err // error
      case flt // fault
    }
    
    // Extracts the OSLog metadata and returns both the metadata and the cleaned-up log message
    static func extractAndCleanMetadata(from log: String) -> (metadata: String?, cleanedLog: String) {
      // Regex to match OSLog metadata pattern (adjust based on actual format)
      let osLogRegex = #"OSLOG-[A-F0-9-]+.+?\{.+?\}"#
      
      // Try to find the metadata using the regex
      if let range = log.range(of: osLogRegex, options: .regularExpression) {
        let metadata = String(log[range])
        let cleanedLog = log.replacingOccurrences(of: metadata, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (metadata: metadata, cleanedLog: cleanedLog)
      }
      
      // If no metadata is found, return the original log as the cleanedLog
      return (metadata: nil, cleanedLog: log)
    }
    
    // Determine log type based on the extracted metadata
    static func determineLogType(from metadata: String?, defaultType: LogType) -> LogType {
      guard let metadata = metadata else { return defaultType }
      
      // Check for faults
      if metadata.localizedCaseInsensitiveContains("fault") {
        return .flt
      }
      
      // Check for errors
      if metadata.localizedCaseInsensitiveContains("error") {
        return .err
      }
      
      return defaultType
    }
  }
  
  func getLogs() -> [LogItem] {
    self.logBuffer = self.logBuffer.compactMap { $0.str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    return logBuffer
  }
}

extension Notification.Name {
  static let newLogAdded = Notification.Name("newLogAdded")
}
