//
//  DiscordBotShellApp.swift
//  DiscordBotShell
//
//  Created by Lakhan Lothiyi on 23/09/2024.
//

import SwiftUI
import DiscordBM
import Logging

@main
struct DiscordBotShellApp: App {
  
  init() {
    // redirect logger to stdout so `StdOutInterceptor`
    DiscordGlobalConfiguration.makeLogger = { label in
      let stdoutHandler = StreamLogHandler.standardOutput(label: label) // stdout
      return Logger(label: label, factory: { _ in stdoutHandler })
    }
  }
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .task {
          do {
            let bot = await MyDiscordBot()
            try await bot.run()
          } catch {
            print("[FATAL] \(error)")
          }
        }
    }
  }
}
