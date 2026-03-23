//
//  ContentView.swift
//  VoxSDK-Test
//
//  Home screen of the SDK sample app.
//
//  This view demonstrates two SDK calls executed in sequence:
//  1. `fetchAccount(username:password:)` — authenticates and returns the account payload,
//     including service URLs (`popMapCollectionsUrl`).
//  2. `fetchPopMapCollections(collectionsUrl:languageId:)` — loads the dynamic catalog of
//     tour collections using the `popMapCollectionsUrl` returned by login and a language code
//     derived from the current device locale.
//
//  After both calls complete, the view displays the collections. Each collection contains
//  lighter tour DTOs (`PopMapCollectionDetailDTO`) that are matched back to the full
//  `PopMapModel` from the login payload before navigating to the detail screen.
//

import NukeUI
import PopguideSDK
import SwiftUI

// MARK: - ContentView

struct ContentView: View {

  @EnvironmentObject private var popguideManager: PopguideManager

  /// The login payload returned by ``PopguideManager/fetchAccount(username:password:)``.
  ///
  /// Stores service URLs (`popMapCollectionsUrl`, `popMapDetailsUrl`) and the full
  /// `PopMapModel` array used to resolve collection items into richer tour models.
  @State private var loginResponse: ApiResponseLogin?

  /// The collections payload returned by ``PopguideManager/fetchPopMapCollections(collectionsUrl:languageId:)``.
  ///
  /// Populated automatically after a successful login when `popMapCollectionsUrl` is available.
  @State private var collectionsResponse: PopMapCollectionsResponse?

  @State private var isLoading = false
  @State private var errorMessage: String?

  private let username = "POP-001600"
  private let password = "93043"

  /// The full tour models returned by login, used to match collection items.
  private var maps: [PopMapModel] {
    loginResponse?.popMaps ?? []
  }

  private var isLoggedIn: Bool {
    loginResponse != nil
  }

  /// The collections returned by `fetchPopMapCollections`.
  private var collections: [PopMapCollectionDTO] {
    collectionsResponse?.popMapCollections ?? []
  }

  /// The language code passed to `fetchPopMapCollections`.
  ///
  /// Collections use string language codes (e.g. `"en"`, `"it"`), unlike detail and download
  /// calls which use numeric `languageId` values from the tour packages.
  private var collectionsLanguageCode: String {
    Locale.current.language.languageCode?.identifier ?? "en"
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        loginSection

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if isLoading {
          ProgressView("Loading...")
            .padding(.top, 40)
        } else if isLoggedIn {
          collectionsSection
        }
      }
      .padding(.horizontal, 20)
    }
    .navigationTitle("SDK Sample")
  }

  // MARK: - Login Section

  private var loginSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Account", systemImage: "person.circle")
        .font(.headline)

      if isLoggedIn {
        HStack {
          Label(username, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.green)

          Spacer()
        }
      } else {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Username")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(username)
              .font(.subheadline.monospaced())
          }

          VStack(alignment: .leading, spacing: 4) {
            Text("Password")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(password)
              .font(.subheadline.monospaced())
          }

          Spacer()
        }

        Button {
          fetchAccount()
        } label: {
          Text("Login")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.purple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  // MARK: - Collections Section

  private var collectionsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      if collections.isEmpty {
        Text("No collections available.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.vertical, 20)
          .frame(maxWidth: .infinity)
      } else {
        ForEach(collections.indices, id: \.self) { index in
          collectionCard(collections[index])
        }
      }
    }
  }

  /// Renders a single collection with its matched tour cards.
  private func collectionCard(_ collection: PopMapCollectionDTO) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(collection.displayTitle)
        .font(.title3.bold())

      Text("Tours: \(collection.popMaps?.count ?? 0) | Languages: \(collection.languages?.count ?? 0)")
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)

      if let collectionMaps = collection.popMaps {
        ForEach(collectionMaps.indices, id: \.self) { mapIndex in
          let collectionMap = collectionMaps[mapIndex]
          if let matchedMap = matchMap(for: collectionMap) {
            PopMapCard(popMap: matchedMap, loginResponse: loginResponse)
          }
        }
      }
    }
  }

  /// Resolves a collection tour item back to its full `PopMapModel` from the login payload.
  ///
  /// Collection items (`PopMapCollectionDetailDTO`) are lighter DTOs that only expose `uid` and `id`.
  /// This method matches them against the richer `PopMapModel` array so the detail screen can
  /// use the full tour data including packages, cover picture, and account identifiers.
  private func matchMap(for collectionMap: PopMapCollectionDTO.PopMapCollectionDetailDTO) -> PopMapModel? {
    maps.first {
      if let collectionUID = collectionMap.uid, $0.uid == collectionUID {
        return true
      }
      if let collectionId = collectionMap.id, $0.id == collectionId {
        return true
      }
      return false
    }
  }

  // MARK: - Actions

  /// Executes the login and collections flow in sequence.
  ///
  /// 1. Calls `fetchAccount(username:password:)` to authenticate.
  /// 2. If the response contains a `popMapCollectionsUrl`, immediately calls
  ///    `fetchPopMapCollections(collectionsUrl:languageId:)` to load the dynamic catalog.
  ///
  /// Both calls happen within the same loading state so the user sees a single spinner.
  private func fetchAccount() {
    isLoading = true
    errorMessage = nil
    collectionsResponse = nil
    Task {
      do {
        let response = try await popguideManager.fetchAccount(
          username: username,
          password: password
        )
        loginResponse = response

        if let collectionsUrl = response.popMapCollectionsUrl {
          let collectionsResult = try await popguideManager.fetchPopMapCollections(
            collectionsUrl: collectionsUrl,
            languageId: collectionsLanguageCode
          )
          collectionsResponse = collectionsResult
        }
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }
}

#Preview("Page") {
  NavigationStack {
    ContentView()
      .environmentObject(
        PopguideManager(
          appName: "sdk_sample",
          language: .english,
          environment: .production
        )
      )
  }
}
