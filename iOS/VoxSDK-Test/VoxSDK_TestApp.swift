//
//  VoxSDK-Test
//

import PopguideSDK
import SwiftUI

@main
struct VoxSDK_TestApp: App {
  @StateObject private var popguideManager = PopguideManager(
    appName: "popguide",
    language: .english,
    environment: .production
  )
  
  var body: some Scene {
    WindowGroup {
      CoordinatorView {
        AnyView(ContentView())
      }
      .environmentObject(popguideManager)
    }
  }
}
