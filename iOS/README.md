# Popguide SDK - iOS Sample App

This sample app demonstrates the end-to-end integration of the PopguideSDK framework, from authentication to asset download and offline verification.

## Requirements

### Sample App
- iOS 16.0+
- Xcode 15+

### PopguideSDK Framework
- iOS 13.0+
- Xcode 26+
- Architecture: arm64 (device), arm64 + x86_64 (simulator)

## Documentation

- [Documentation](./PopguideSDK.doccarchive)

## How to import the SDK

1. Open your project in Xcode.
2. Select the target where you want to include the framework.
3. Go to **General** > **Frameworks, Libraries, and Embedded Content**.
4. Press **+**, then **Add Other...** > **Add Files...**.
5. Select the `PopguideSDK.xcframework` to include.

## SDK Integration Flow

The sample app follows a linear flow that covers all the key SDK features.

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. BOOTSTRAP                                                       │
│  PopguideManager(appName:language:environment:)                     │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. LOGIN                                                           │
│  fetchAccount(username:password:) → ApiResponseLogin                │
│  ├─ popMaps: [PopMapModel]         (available tours)                │
│  ├─ popMapCollectionsUrl           (collections endpoint)           │
│  ├─ popMapDetailsUrl               (details endpoint)               │
│  └─ account                        (account info + branding)        │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. COLLECTIONS                                                     │
│  fetchPopMapCollections(collectionsUrl:languageId:)                  │
│  └─ PopMapCollectionDTO[] → match to PopMapModel via uid/id         │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. TOUR DETAILS                                                    │
│  fetchPopMapDetails(body:id:languageId:forceUpdate:accountId:)      │
│  └─ PopMapDetailsServer                                             │
│     ├─ levels[]                    (itineraries)                    │
│     │  └─ points[] (PointServer)   (POIs / activities)              │
│     │     └─ contents (ContentsServer)                              │
│     │        ├─ audios[]           (AudioServer)                    │
│     │        ├─ images[]           (ImageServer)                    │
│     │        └─ videos[]           (VideoServer)                    │
│     └─ popMapTotalSize             (full / light size breakdown)    │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                  ┌────────┴────────┐
                  ▼                 ▼
┌──────────────────────┐  ┌──────────────────────────────────────────┐
│  5a. DOWNLOAD FULL   │  │  5b. DOWNLOAD LIGHT                      │
│  .full → audio +     │  │  .light → images only                    │
│  images + videos     │  │                                          │
└──────────┬───────────┘  └──────────────────┬───────────────────────┘
           │                                 │
           └────────────┬────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│  6. OFFLINE VERIFICATION                                            │
│  ├─ getMissingDownlodables(mapDetail:downloadType:) → count + size  │
│  ├─ popMapSize(mapDetail:) → installed size on disk                 │
│  └─ audioServer.localFile(mapDetailUID:) → local file URL           │
│     imageServer.localFile(mapDetailUID:)                            │
│     videoServer.localFile(mapDetailUID:)                            │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  7. MANAGE                                                          │
│  ├─ cancelDownload(of:deleteFiles:) → stop download                 │
│  │   deleteFiles: true (default) = removes downloaded files         │
│  │   deleteFiles: false = preserves files already on disk           │
│  └─ deletePopMap(_:) → removes all downloaded assets (full map)     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1. Bootstrap

`PopguideManager` is initialized with an app name, language, and environment:

```swift
PopguideManager(appName: "sdk_sample", language: .english, environment: .production)
```

- `appName` identifies the brand in API calls. Must be agreed with the SDK provider.
- `environment`: `.production` for store builds, `.staging` for testing.
- Service domains are determined automatically by the environment and the login response.

### 2. Login

`fetchAccount(username:password:)` authenticates and returns:
- Available tours (`popMaps`) as `[PopMapModel]`.
- Service URLs (`popMapCollectionsUrl`, `popMapDetailsUrl`) used by subsequent calls.
- Account info and branding data.

### 3. Collections

`fetchPopMapCollections(collectionsUrl:languageId:)` loads the dynamic catalog using the `popMapCollectionsUrl` from the login response and a language code (e.g. `"en"`, `"it"`).

Collection items (`PopMapCollectionDetailDTO`) are lighter DTOs that are matched back to the full `PopMapModel` from the login payload.

### 4. Tour Details

`fetchPopMapDetails(body:id:languageId:forceUpdate:accountId:)` loads the full tour payload for a selected tour and language. The call uses:
- `popMapDetailsUrl` from the login response inside `DetailsBody`.
- `forceUpdate: true` to always fetch the latest server state.
- `accountId` from the tour model or login account.

The response contains the full content structure: `levels` → `points` (`PointServer`) → `contents` (`audios`, `images`, `videos`). Each asset conforms to `LocalFileCheckable` and exposes a `file` property with the remote URL.

### 5. Download

`fetchPopMapDownlodables(mapDetail:downloadType:)` returns a Combine publisher that emits download progress values and completes when all assets are written to disk.

Two download modes are available:
- `.full` — downloads all resources (images + audio + video).
- `.light` — downloads images only.

Files are stored in `Documents/{mapUID}/` when using account scoping). Max 6 concurrent file downloads.

### 6. Offline Verification

- `getMissingDownlodables(mapDetail:downloadType:)` — returns the count and total size of assets not yet available locally.
- `popMapSize(mapDetail:)` — returns the installed size reported by the SDK.
- `localFile(mapDetailUID:)` — resolves the local file URL for each asset (image, audio, video).

### 7. Manage

- `cancelDownload(of mapDetail:)` — stops an active download. By default (`deleteFiles: true`) removes files already downloaded. 
- `deletePopMap(_:)` — removes all downloaded assets for the tour (operates at the full map level).

## File Storage

Downloaded assets are stored in the app's `Documents` directory, organized by map and account:

```
Documents/
└── {mapUID}/
    ├── image_001.jpg
    ├── image_002.jpg
    ├── audio_en_001.mp3
    ├── audio_en_002.mp3
    ├── video_001.mp4
    └── icon.png
```

- Files are saved flat (no subdirectories), using the filename extracted from the remote URL.
- `localFile(mapDetailUID:)` resolves local files by matching the filename (`lastPathComponent`) inside the map folder.
- `deletePopMap(_:)` removes the entire map folder and all its contents.
- The SDK does not set `isExcludedFromBackup` on downloaded files. If needed, the integrating app should handle iCloud backup exclusion.

## Selective Audio Download

The SDK downloads assets at the map level (`.full` or `.light`). To download only specific audio files for selected POIs without downloading the entire map:

1. Call `fetchPopMapDetails(body:id:languageId:forceUpdate:accountId:)` to load the tour metadata.
2. Navigate `details.levels[].points[].contents.audios` to find the `AudioServer` entries you need.
3. Use the `file` property of each `AudioServer` as the remote URL to download the file independently.
4. Save the file in `Documents/{mapUID}/` using the last path component of the URL as the filename.
5. `localFile(mapDetailUID:)` will then find the file automatically.

Optionally, download the `.light` package first to get all images, and then add only the required audio files manually.

> **Note:** Files downloaded outside the SDK are still subject to `deletePopMap(_:)`, which removes the entire map folder.

## Project Structure

| File | Description |
|------|-------------|
| `VoxSDK_TestApp.swift` | App entry point. Initializes `PopguideManager` and injects it into the environment. |
| `ContentView.swift` | Home screen. Handles login and collections loading, displays tour cards. |
| `PopMapCard.swift` | Card component for a single tour with cover image and language selectors. |
| `PopMapDetailView.swift` | Detail screen. Loads tour details, manages download/delete, and displays local files. |
