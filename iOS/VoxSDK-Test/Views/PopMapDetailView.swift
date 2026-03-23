//
//  VoxSDK-Test
//

import Combine
import Foundation
import NukeUI
import PopguideSDK
import SwiftUI

extension PointServer: Identifiable {}

struct LocalFile: Identifiable, Hashable {
  let id = UUID()
  let path: String
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(path)
  }
}

struct PopMapDetailView: View {
  
  // MARK: - Stored Properties
  
  @State var popMap: PopMapModel
  @State var languageId: Int
  var loginResponse: ApiResponseLogin?
  @State private var mapDetail: PopMapDetailsServer?
  @State private var fullDownloadMapSize: Double?
  @State private var lightDownloadMapSize: Double?
  @State private var progress: Double?
  @State private var isInstalled = false
  @State private var isDownloading = false
  @State private var cancellables = Set<AnyCancellable>()
  @State private var localFilesPath = [LocalFile]()
  @State private var missingFilesCount = 0
  @State private var installedSize: Int64 = 0
  
  // MARK: - Environment
  
  @EnvironmentObject private var popguideManager: PopguideManager
  @EnvironmentObject private var coordinator: Coordinator
  
  var body: some View {
    ZStack {
      Color.white.ignoresSafeArea()
      
      VStack(alignment: .leading, spacing: 16) {
        if let coverPictureUrl = popMap.coverPicture {
          LazyImage(url: URL(string: coverPictureUrl)) { state in
            if let image = state.image {
              image
                .resizable()
                .scaledToFill()
                .frame(
                  width: UIScreen.main.bounds.width,
                  height: UIScreen.main.bounds.height * 0.18
                )
                .clipped()
            } else {
              ProgressView()
            }
          }
        }
        
        VStack(alignment: .leading, spacing: 24) {
          Text(popMap.name ?? "--")
            .font(.title)
            .bold()
            .foregroundStyle(.black)
          
          if let fullDownloadMapSize {
            Text("Full Size: \(String(format: "%.1f", fullDownloadMapSize)) MB")
              .foregroundStyle(.black)
          }
          
          if let lightDownloadMapSize {
            Text("Light Size: \(String(format: "%.1f", lightDownloadMapSize)) MB")
              .foregroundStyle(.black)
          }
          
          if missingFilesCount > 0 {
            Text("Missing files: \(missingFilesCount)")
              .foregroundStyle(.black)
          }

          if installedSize > 0 {
            Text("Installed size: \(ByteCountFormatter.string(fromByteCount: installedSize, countStyle: .file))")
              .foregroundStyle(.black)
          }

          Button {
            if isInstalled {
              deleteMap()
            } else {
              downloadFiles()
            }
          } label: {
            Text(isInstalled ? "Delete Map Content" : "Download")
              .padding()
              .background(.purple)
              .foregroundStyle(.white)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .disabled(mapDetail == nil || isDownloading)
          .opacity(mapDetail == nil ? 0.3 : 1)

          if isDownloading {
            Button {
              cancelDownload()
            } label: {
              Text("Cancel Download")
                .padding()
                .background(.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
          }

          Text(isInstalled ? "Map Installed" : "Progress: \(progress ?? 0)")
            .foregroundStyle(.black)
        }
        .padding(.horizontal)
        
        if isInstalled {
          List(localFilesPath) { file in
            Text(file.path)
              .font(.footnote)
              .foregroundStyle(.black)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(Color.white)
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 0)
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(.gray.opacity(0.2), lineWidth: 1)
              )
              .buttonStyle(PlainButtonStyle())
              .listRowSeparator(.hidden)
          }
          .listStyle(.plain)
        }
        
        Spacer()
      }
    }
    .task {
      await fetchPopMapDetail(languageId: languageId)
      isInstalled = isMapInstalled()
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
          partialResult += getPointLocalFiels(point)
        } ?? []
      }
      print(localFilesPath.count)
    }
  }
  
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
      // For Map size
      let mapSizeMB = Double(popMapTotalSizeModel.map) / 1_000_000.0

      // Calculate full Map Size
      fullDownloadMapSize = (Double(popMapTotalSizeModel.audio + popMapTotalSizeModel.image) / 1_000_000.0) + Double(mapSizeMB)

      // Calculate light Map Size
      lightDownloadMapSize = Double(popMapTotalSizeModel.image) / 1_000_000.0

      mapDetail = response?.details
      refreshDownloadMetrics()
    } catch {
      print(error.localizedDescription)
    }
  }
  
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
  
  private func isMapInstalled() -> Bool {
    guard let mapDetail else { return false }
    let missingFiles = popguideManager.getMissingDownlodables(
      mapDetail: mapDetail,
      downloadType: .full
    )
    return missingFiles.totalSize == 0
  }

  private func refreshDownloadMetrics() {
    guard let mapDetail else { return }
    let missing = popguideManager.getMissingDownlodables(
      mapDetail: mapDetail,
      downloadType: .full
    )
    missingFilesCount = missing.remoteUrls.count
    installedSize = popguideManager.popMapSize(mapDetail: mapDetail) ?? 0
  }

  private func cancelDownload() {
    guard let mapDetail else { return }
    popguideManager.cancelDownload(of: mapDetail)
    cancellables.removeAll()
    isDownloading = false
    refreshDownloadMetrics()
  }

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
  
  private func getPointLocalFiels(_ point: PointServer) -> [LocalFile] {
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
    
    // Apply set to remove duplciates
    return Array(Set(files))
  }
}
