# Popguide SDK - iOS Sample App

This sample app demonstrates the end-to-end integration of the PopguideSDK framework, from authentication to asset download and offline verification.

## Requirements

- iOS 16.0+
- Xcode 15+

## Documentation

- [Documentation](./PopguideSDK.doccarchive)

## How to import the SDK

1. Open your project in Xcode.
2. Select the target where you want to include the framework.
3. Go to **General** > **Frameworks, Libraries, and Embedded Content**.
4. Press **+**, then **Add Other...** > **Add Files...**.
5. Select the `PopguideSDK.xcframework` to include.

## SDK Integration Flow

The sample app follows a linear flow that covers all the key SDK features:

### 1. Bootstrap

`PopguideManager` is initialized with an app name, language, and environment:

```swift
PopguideManager(appName: "sdk_sample", language: .english, environment: .production)
```

### 2. Login

`fetchAccount(username:password:)` authenticates and returns:
- Available tours (`popMaps`) as `[PopMapModel]`.
- Service URLs (`popMapCollectionsUrl`, `popMapDetailsUrl`) used by subsequent calls.

### 3. Collections

`fetchPopMapCollections(collectionsUrl:languageId:)` loads the dynamic catalog using the `popMapCollectionsUrl` from the login response and a language code (e.g. `"en"`, `"it"`).

Collection items (`PopMapCollectionDetailDTO`) are lighter DTOs that are matched back to the full `PopMapModel` from the login payload.

### 4. Tour Details

`fetchPopMapDetails(body:id:languageId:forceUpdate:accountId:)` loads the full tour payload for a selected tour and language. The call uses:
- `popMapDetailsUrl` from the login response inside `DetailsBody`.
- `forceUpdate: true` to always fetch the latest server state.
- `accountId` from the tour model or login account.

### 5. Download

`fetchPopMapDownlodables(mapDetail:downloadType:)` returns a Combine publisher that emits download progress values and completes when all assets are written to disk.

### 6. Offline Verification

- `getMissingDownlodables(mapDetail:downloadType:)` — returns the count and total size of assets not yet available locally.
- `popMapSize(mapDetail:)` — returns the installed size reported by the SDK.
- `localFile(mapDetailUID:)` — resolves the local file URL for each asset (image, audio, video).

### 7. Manage

- `cancelDownload(of:)` — stops an active download.
- `deletePopMap(_:)` — removes all downloaded assets for the tour.

## Project Structure

| File | Description |
|------|-------------|
| `VoxSDK_TestApp.swift` | App entry point. Initializes `PopguideManager` and injects it into the environment. |
| `ContentView.swift` | Home screen. Handles login and collections loading, displays tour cards. |
| `PopMapCard.swift` | Card component for a single tour with cover image and language selectors. |
| `PopMapDetailView.swift` | Detail screen. Loads tour details, manages download/delete, and displays local files. |
