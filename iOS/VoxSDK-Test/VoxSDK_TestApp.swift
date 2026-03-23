//
//  VoxSDK_TestApp.swift
//  VoxSDK-Test
//
//  Sample app demonstrating the PopguideSDK integration flow.
//
//  The app follows this linear showcase:
//  1. **Bootstrap** — `PopguideManager` is initialized with app name, language, and environment.
//  2. **Login** — `fetchAccount(username:password:)` authenticates and returns service URLs and available tours.
//  3. **Collections** — `fetchPopMapCollections(collectionsUrl:languageId:)` loads the dynamic catalog.
//  4. **Tour detail** — `fetchPopMapDetails(body:id:languageId:forceUpdate:accountId:)` loads the full tour payload.
//  5. **Download** — `fetchPopMapDownlodables(mapDetail:downloadType:)` downloads assets with progress tracking.
//  6. **Offline** — `getMissingDownlodables(mapDetail:downloadType:)`, `popMapSize(mapDetail:)`,
//     and `localFile(mapDetailUID:)` verify and inspect downloaded content.
//  7. **Manage** — `cancelDownload(of:)` and `deletePopMap(_:)` handle cleanup.
//

import PopguideSDK
import SwiftUI

/// The app entry point.
///
/// Initializes ``PopguideManager`` as the single SDK entry point and injects it
/// into the SwiftUI environment so every view in the hierarchy can access it.
@main
struct VoxSDK_TestApp: App {
  @StateObject private var popguideManager = PopguideManager(
    appName: "sdk_sample",
    language: .english,
    environment: .production
  )

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ContentView()
      }
      .environmentObject(popguideManager)
    }
  }
}
