//
//  BotMain.swift
//  DiscordBotShell
//
//  Created by Lakhan Lothiyi on 23/09/2024.
//

import DDBKit
import Database

struct MyDiscordBot: DiscordBotApp {
  init() async {
    // Edit below as needed.
    bot = await BotGatewayManager( /// Need sharding? Use `ShardingGatewayManager`
      /// Do not store your token in your code in production.
      token: token,
      /// replace the above with your own token, but only for testing
      presence: .init(activities: [], status: .online, afk: false),
      intents: [.messageContent, .guildMessages]
    )
    // Will be useful
    cache = await .init(
      gatewayManager: bot,
      intents: .all, // it's better to minimise cached data to your needs
      requestAllMembers: .enabledWithPresences,
      messageCachingPolicy: .saveEditHistoryAndDeleted
    )
  }
  
  var body: [any DDBKit.BotScene] {
    ReadyEvent { ready in
      print("Connected as \(ready?.user.username ?? ""), in \(ready?.guilds.count ?? 0) guilds.")
    }
    
    Command("increment") { interaction, cmd, db in
      
      
      let number = Double((try? cmd.requireOption(named: "number").value?.asString) ?? "0") ?? 0
      
      // an easier way of sending messages without directly using http client
      // is going to arrive soon dw :3
      do {
        let _ = try await bot.client.createInteractionResponse(
          id: interaction.id,
          token: interaction.token,
          payload: .deferredChannelMessageWithSource()
        )
        let _ = try await bot.client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: .init(content: "\(number + 1)")
          )
        print("\(interaction.user?.username ?? "") invoked increment, sending \(number + 1).")
      } catch {
        // :3
      }
    }
    .description("Adds 1 to an inputted value")
    .addingOptions {
      DoubleOption(name: "number", description: "value")
        .required()
        .autocompletions { gm in
          let value = Int(gm.asString) ?? 0
          return [
            .init(name: "\(value)", value: .int(value)),
            .init(name: "\(value + 1)", value: .int(value + 1)),
            .init(name: "\(value + 2)", value: .int(value + 2)),
            .init(name: "\(value + 3)", value: .int(value + 3)),
            .init(name: "\(value + 4)", value: .int(value + 4)),
          ]
        }
    }
  }
  
  let database = Database.shared
  var bot: any Bot
  var cache: Cache
}
