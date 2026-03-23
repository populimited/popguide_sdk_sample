//
//  PopMapDetailView.swift
//  VoxSDK-Test
//
//  Detail screen for a single tour, demonstrating the download and offline inspection flow.
//
//  This view showcases the following SDK calls:
//
//  ### Tour details
//  `fetchPopMapDetails(body:id:languageId:forceUpdate:accountId:)` loads the full detail
//  payload for the selected tour and language. The `DetailsBody` includes the `popMapDetailsUrl`
//  from the login response. Setting `forceUpdate: true` ensures the latest server state.
//
//  ### Download management
//  - `fetchPopMapDownlodables(mapDetail:downloadType:)` returns a Combine publisher that
//    emits download progress and completes when all assets are written to disk.
//  - `cancelDownload(of:)` stops an active download without deleting files already on disk.
//  - `deletePopMap(_:)` removes all downloaded assets for the tour.
//
//  ### Offline verification
//  - `getMissingDownlodables(mapDetail:downloadType:)` returns the count and total size
//    of assets not yet available locally.
//  - `popMapSize(mapDetail:)` returns the installed size reported by the SDK.
//  - `localFile(mapDetailUID:)` resolves the local file URL for each asset (image, audio, video).
//

import Combine
import Foundation
import NukeUI
import PopguideSDK
import SwiftUI

// MARK: - Supporting Types

extension PointServer: Identifiable {}

/// A wrapper for a local file path resolved by the SDK.
///
/// Used by the local files section to display and copy the on-disk paths of downloaded assets.
struct LocalFile: Identifiable, Hashable {
  let id = UUID()
  let path: String

  func hash(into hasher: inout Hasher) {
    hasher.combine(path)
  }
}

// MARK: - PopMapDetailView

struct PopMapDetailView: View {

  // MARK: - Stored Properties

  /// The tour selected from the collections screen.
  @State var popMap: PopMapModel

  /// The numeric language identifier from the selected package.
  ///
  /// This value comes from `PackageModel.languageId` and is passed to
  /// `fetchPopMapDetails` and used implicitly by the download flow.
  @State var languageId: Int

  /// The login response, used to extract `popMapDetailsUrl` and `accountId`
  /// for the detail request.
  var loginResponse: ApiResponseLogin?

  /// The full detail payload returned by `fetchPopMapDetails`.
  ///
  /// Contains itineraries (levels), points, and asset references used for
  /// download and offline file resolution.
  @State private var mapDetail: PopMapDetailsServer?

  @State private var fullDownloadMapSize: Double?
  @State private var lightDownloadMapSize: Double?

  /// The latest progress value emitted by `fetchPopMapDownlodables`.
  ///
  /// The SDK publisher can emit values in the `0...1` or `0...100` range.
  /// This is normalized before display using ``normalizedProgress``.
  @State private var progress: Double?

  @State private var isInstalled = false
  @State private var isDownloading = false
  @State private var isLoadingDetails = true
  @State private var cancellables = Set<AnyCancellable>()
  @State private var localFilesPath = [LocalFile]()

  /// The number of remote assets not yet available locally,
  /// from `getMissingDownlodables(mapDetail:downloadType:)`.
  @State private var missingFilesCount = 0

  /// The installed size reported by `popMapSize(mapDetail:)`.
  @State private var installedSize: Int64 = 0

  // MARK: - Environment

  @EnvironmentObject private var popguideManager: PopguideManager

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // Cover
        if let coverPictureUrl = popMap.coverPicture {
          LazyImage(url: URL(string: coverPictureUrl)) { state in
            if let image = state.image {
              image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            } else {
              Rectangle()
                .fill(.quaternary)
                .frame(height: 200)
                .overlay(ProgressView())
            }
          }
        }

        VStack(alignment: .leading, spacing: 20) {
          Text(popMap.name ?? "--")
            .font(.title.bold())

          if isLoadingDetails {
            HStack {
              ProgressView()
              Text("Loading details...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          } else {
            infoSection
            downloadSection
          }

          if isInstalled && !localFilesPath.isEmpty {
            localFilesSection
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
      }
    }
    .navigationTitle(popMap.name ?? "Detail")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await fetchPopMapDetail(languageId: languageId)
      isInstalled = isMapInstalled()
      isLoadingDetails = false
    }
    .onChange(of: isInstalled) { newValue in
      guard
        let levels = mapDetail?.levels,
        newValue
      else {
        localFilesPath = []
        return
      }
      localFilesPath = levels.reduce(into: [LocalFile]()) { partialResult, level in
        partialResult += level.points?.reduce(into: [LocalFile]()) { partialResult, point in
          partialResult += getPointLocalFiles(point)
        } ?? []
      }
    }
  }

  // MARK: - Info Section

  /// Displays size metrics and installation status from the SDK.
  private var infoSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let fullDownloadMapSize {
        infoRow(label: "Full size", value: String(format: "%.1f MB", fullDownloadMapSize))
      }

      if let lightDownloadMapSize {
        infoRow(label: "Light size", value: String(format: "%.1f MB", lightDownloadMapSize))
      }

      if missingFilesCount > 0 {
        infoRow(label: "Missing files", value: "\(missingFilesCount)")
      }

      if installedSize > 0 {
        infoRow(
          label: "Installed size",
          value: ByteCountFormatter.string(fromByteCount: installedSize, countStyle: .file)
        )
      }

      if isInstalled {
        Label("Map installed", systemImage: "checkmark.circle.fill")
          .font(.subheadline)
          .foregroundStyle(.green)
          .padding(.top, 4)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private func infoRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.subheadline.monospaced())
    }
  }

  // MARK: - Download Section

  /// Download, cancel, and delete controls.
  ///
  /// During an active download, shows a `ProgressView` with the normalized progress
  /// value and a cancel button. Otherwise shows a download or delete button depending
  /// on whether the map is already installed.
  private var downloadSection: some View {
    VStack(spacing: 12) {
      if isDownloading {
        VStack(spacing: 8) {
          ProgressView(value: normalizedProgress)
          Text(progressLabel)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }

        Button {
          cancelDownload()
        } label: {
          Text("Cancel Download")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
      } else {
        Button {
          if isInstalled {
            deleteMap()
          } else {
            downloadFiles()
          }
        } label: {
          Text(isInstalled ? "Delete Map Content" : "Download")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isInstalled ? .red : .purple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(mapDetail == nil)
        .opacity(mapDetail == nil ? 0.3 : 1)
      }
    }
  }

  /// Normalizes the SDK progress to a `0...1` range suitable for `ProgressView`.
  ///
  /// The SDK publisher can emit either `0...1` or `0...100` depending on the content.
  private var normalizedProgress: Double {
    let p = progress ?? 0
    let normalized = p > 1 ? p / 100 : p
    return min(max(normalized, 0), 1)
  }

  /// A user-facing percentage string for the current download progress.
  private var progressLabel: String {
    let p = progress ?? 0
    let percentage = p > 1 ? p : p * 100
    return String(format: "%.0f%%", percentage)
  }

  // MARK: - Local Files Section

  /// Displays the on-disk paths resolved by `localFile(mapDetailUID:)` for each asset.
  ///
  /// Only shown after a successful download. Each path is selectable for copying.
  private var localFilesSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Local files (\(localFilesPath.count))", systemImage: "folder")
        .font(.headline)
        .padding(.top, 8)

      ForEach(localFilesPath) { file in
        Text(file.path)
          .font(.caption2.monospaced())
          .lineLimit(10)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  // MARK: - SDK Actions

  /// Loads the full tour detail payload for the selected language.
  ///
  /// Calls `fetchPopMapDetails(body:id:languageId:forceUpdate:accountId:)` with:
  /// - `popMapDetailsUrl` from the login response in the `DetailsBody`.
  /// - `forceUpdate: true` to always fetch the latest server state.
  /// - `accountId` from the tour model or login account.
  ///
  /// After a successful response, calculates download sizes from `popMapTotalSize`
  /// and refreshes the missing files and installed size metrics.
  private func fetchPopMapDetail(languageId: Int) async {
    guard let popmapId = popMap.id else { return }
    do {
      let response = try await popguideManager.fetchPopMapDetails(
        body: DetailsBody(
          marketplacesUrl: nil,
          messageBoxUrl: nil,
          popMapDetailsUrl: loginResponse?.popMapDetailsUrl,
          walksUrl: nil
        ),
        id: "\(popmapId)",
        languageId: languageId,
        forceUpdate: true,
        accountId: popMap.accountId ?? loginResponse?.account?.id ?? 0
      )
      guard let popMapTotalSizeModel = response?.details.popMapTotalSize else {
        return
      }
      let mapSizeMB = Double(popMapTotalSizeModel.map) / 1_000_000.0
      fullDownloadMapSize = (Double(popMapTotalSizeModel.audio + popMapTotalSizeModel.image) / 1_000_000.0) + mapSizeMB
      lightDownloadMapSize = Double(popMapTotalSizeModel.image) / 1_000_000.0
      mapDetail = response?.details
      refreshDownloadMetrics()
    } catch {
      print(error.localizedDescription)
    }
  }

  /// Starts downloading all assets for the current tour and language.
  ///
  /// Subscribes to the `fetchPopMapDownlodables(mapDetail:downloadType:)` Combine publisher,
  /// which emits progress values and completes when all files are written to disk.
  /// On completion, marks the map as installed and refreshes the download metrics.
  private func downloadFiles() {
    guard let mapDetail else { return }
    isDownloading = true
    progress = 0
    popguideManager.fetchPopMapDownlodables(
      mapDetail: mapDetail,
      downloadType: .full
    )
    .receive(on: DispatchQueue.main)
    .sink { result in
      isDownloading = false
      switch result {
      case .finished:
        isInstalled = true
        refreshDownloadMetrics()
      case let .failure(error):
        print(error.localizedDescription)
      }
    } receiveValue: { progress in
      self.progress = progress
    }
    .store(in: &cancellables)
  }

  /// Checks whether all assets for the current tour are available locally.
  ///
  /// Uses `getMissingDownlodables(mapDetail:downloadType:)` and considers
  /// the map installed when `totalSize` is zero.
  private func isMapInstalled() -> Bool {
    guard let mapDetail else { return false }
    let missingFiles = popguideManager.getMissingDownlodables(
      mapDetail: mapDetail,
      downloadType: .full
    )
    return missingFiles.totalSize == 0
  }

  /// Refreshes the missing files count and installed size from the SDK.
  ///
  /// Called after detail loading, download completion, cancellation, and deletion
  /// to keep the UI in sync with the actual on-disk state.
  private func refreshDownloadMetrics() {
    guard let mapDetail else { return }
    let missing = popguideManager.getMissingDownlodables(
      mapDetail: mapDetail,
      downloadType: .full
    )
    missingFilesCount = missing.remoteUrls.count
    installedSize = popguideManager.popMapSize(mapDetail: mapDetail) ?? 0
  }

  /// Cancels the active download.
  ///
  /// Calls `cancelDownload(of:)` on the SDK and removes the local Combine subscription.
  /// Files already written to disk are preserved.
  private func cancelDownload() {
    guard let mapDetail else { return }
    popguideManager.cancelDownload(of: mapDetail)
    cancellables.removeAll()
    isDownloading = false
    refreshDownloadMetrics()
  }

  /// Deletes all downloaded assets for the current tour.
  ///
  /// If a download is in progress, it is cancelled first via `cancelDownload(of:)`.
  /// Then calls `deletePopMap(_:)` to remove files from disk.
  private func deleteMap() {
    guard let mapDetail else { return }
    if isDownloading {
      popguideManager.cancelDownload(of: mapDetail)
      cancellables.removeAll()
      isDownloading = false
    }
    popguideManager.deletePopMap(mapDetail)
    isInstalled = false
    refreshDownloadMetrics()
  }

  /// Resolves the local file paths for all assets in a given point.
  ///
  /// Uses `localFile(mapDetailUID:)` on each image, video, and audio asset
  /// to get the on-disk URL where the SDK has written the downloaded file.
  private func getPointLocalFiles(_ point: PointServer) -> [LocalFile] {
    guard let mapUID = mapDetail?.uid else { return [] }
    var files = [LocalFile]()

    files += point.contents?.images?.compactMap {
      guard let url = $0.localFile(mapDetailUID: mapUID) else { return nil }
      return LocalFile(path: url.absoluteString)
    } ?? []

    files += point.contents?.videos?.compactMap {
      guard let url = $0.localFile(mapDetailUID: mapUID) else { return nil }
      return LocalFile(path: url.absoluteString)
    } ?? []

    files += point.contents?.audios?.compactMap {
      guard let url = $0.localFile(mapDetailUID: mapUID) else { return nil }
      return LocalFile(path: url.absoluteString)
    } ?? []

    return Array(Set(files))
  }
}
