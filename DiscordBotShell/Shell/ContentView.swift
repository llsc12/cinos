//
//  ContentView.swift
//  DiscordBotShell
//
//  Created by Lakhan Lothiyi on 23/09/2024.
//

import SwiftUI
import DDBKit

struct ContentView: View {
  @State var vm = ViewModel()
  @State var doScrolling = true
  @State var timer: Timer? = nil
  
  @State var fontSize = UserDefaults.standard.value(forKey: "Shell.FontSize") as? CGFloat ?? 12 {
    didSet {
      UserDefaults.standard.set(self.fontSize, forKey: "Shell.FontSize")
    }
  }
  let _FontSizeRange: ClosedRange<CGFloat> = 6...18

  @State var keepPinned = UserDefaults.standard.value(forKey: "Shell.KeepPinned") as? Bool ?? true {
    didSet {
      UserDefaults.standard.set(self.keepPinned, forKey: "Shell.KeepPinned")
    }
  }
  
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(vm.logs) { item in
              cell(item)
                .background {
                  if item.type != .out {
                    Rectangle()
                      .fill(item.type == .err ? .yellow : .red)
                      .opacity(0.15)
                  }
                }
            }
          }
          SwiftUI.Text("")
            .id("bottom")
        }
        .navigationTitle("Bot Logs")
        .font(.system(size: fontSize, weight: .regular, design: .monospaced))
        .multilineTextAlignment(.leading)
        .toolbarTitleDisplayMode(.inline)
        .onChange(of: vm.logs) {
          if doScrolling {
            proxy.scrollTo("bottom")
          }
        }
        .onScrollPhaseChange { oldPhase, newPhase in
          guard newPhase != .animating else { return }
          if newPhase == .idle {
            self.timer = .scheduledTimer(withTimeInterval: 5, repeats: false, block: { _ in
              withAnimation {
                proxy.scrollTo("bottom")
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.doScrolling = true
              })
            })
          } else {
            // user is somehow interacting, so stop scrolling
            self.timer?.invalidate()
            self.timer = nil
            self.doScrolling = false
          }
        }
      }
      .background {
        Rectangle()
          .fill(Color(hue: 0.6416666667, saturation: 0.07, brightness: 0.17))
          .ignoresSafeArea()
      }
      .toolbar {
        Menu {
          Slider(value: $fontSize, in: self._FontSizeRange)
//          Slider(value: $fontSize, in: self._FontSizeRange, step: 1)
//          Slider(value: $fontSize, in: self._FontSizeRange, step: 1)
        } label: {
          Image(systemName: "gear")
        }

      }
    }
  }
  
  @ViewBuilder
  func cell(_ log: StdOutInterceptor.LogItem) -> some View {
    SwiftUI.Text(log.str.trimmingCharacters(in: .whitespacesAndNewlines))
      .frame(maxWidth: .infinity, alignment: .leading)
      .contextMenu {
        Button("Copy") {
          UIPasteboard.general.string = log.str
        }
      }
    Divider()
  }
}

@Observable
class ViewModel {
  
  init() {
    StdOutInterceptor.shared.startIntercepting()
    ProcessMonitor.shared.startMonitoring()
    NotificationCenter.default.addObserver(forName: .newLogAdded, object: nil, queue: .main) { _ in
      self.logs = StdOutInterceptor.shared.getLogs()
    }
  }
  
  deinit {
    StdOutInterceptor.shared.stopIntercepting()
  }
  
  var logs: [StdOutInterceptor.LogItem] = []
}

#Preview {
  ContentView()
}
