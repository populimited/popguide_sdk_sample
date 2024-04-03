//
//  VoxSDK-Test
//

import Combine
import Foundation
import NukeUI
import PopguideSDK
import SwiftUI

struct PopMapDetailView: View {
  
  // MARK: - Stored Properties
  
  @State var popMap: PopMapModel
  @State var languageId: Int
  @State private var mapDetail: PopMapDetailsServer?
  @State private var fullDownloadMapSize: Double?
  @State private var lightDownloadMapSize: Double?
  @State private var progress: Double?
  @State private var isInstalled = false
  @State private var cancellables = Set<AnyCancellable>()
  
  // MARK: - Environment
  
  @EnvironmentObject private var popguideManager: PopguideManager
  
  var body: some View {
    ZStack {
      Color.white.ignoresSafeArea()
      
      VStack(alignment: .leading, spacing: 24) {
        if let coverPictureUrl = popMap.coverPicture {
          LazyImage(url: URL(string: coverPictureUrl)) { state in
            if let image = state.image {
              image
                .resizable()
                .scaledToFill()
                .frame(
                  width: UIScreen.main.bounds.width,
                  height: UIScreen.main.bounds.height * 0.20
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
          .disabled(mapDetail == nil)
          .opacity(mapDetail == nil ? 0.3 : 1)

          Text(isInstalled ? "Map Installed" : "Progress: \(progress ?? 0)")
            .foregroundStyle(.black)
        }
        .padding(.horizontal)
        
        Spacer()
      }
    }
    .task {
      await fetchPopMapDetail(languageId: languageId)
      isInstalled = isMapInstalled()
    }
  }
  
  private func fetchPopMapDetail(languageId: Int) async {
    guard let popmapId = popMap.id else { return }
    do {
      let response = try await popguideManager.fetchPopMapDetails(
        id: "\(popmapId)",
        languageId: languageId
      )
      guard let popMapTotalSizeModel = response?.popMapDetails?.popMapTotalSize else {
        return
      }
      // For Map size
      let mapSizeMB = Double(popMapTotalSizeModel.map) / 1_000_000.0
      
      // Calculate full Map Size
      fullDownloadMapSize = (Double(popMapTotalSizeModel.audio + popMapTotalSizeModel.image) / 1_000_000.0) + Double(mapSizeMB)
      
      // Calculate light Map Size
      lightDownloadMapSize = Double(popMapTotalSizeModel.image) / 1_000_000.0
      
      mapDetail = response?.popMapDetails
    } catch {
      print(error.localizedDescription)
    }
  }
  
  private func downloadFiles() {
    popguideManager.fetchPopMapDownlodables(
      mapDetail: mapDetail!,
      downloadType: .full
    )
    .receive(on: DispatchQueue.main)
    .sink { result in
      switch result {
      case .finished:
        isInstalled = true
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
    let missingFiles = popguideManager.getMissingDownlodables(mapDetail: mapDetail)
    return missingFiles.totalSize == 0
  }
  
  private func deleteMap() {
    guard let mapDetail else { return }
    popguideManager.deletePopMap(mapDetail)
    isInstalled = false
  }
}
