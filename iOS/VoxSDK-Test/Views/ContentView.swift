//
//  VoxSDK-Test
//

import NukeUI
import PopguideSDK
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
  
  // Environment Objects
  @EnvironmentObject private var popguideManager: PopguideManager
  
  // States
  @State private var maps: [PopMapModel] = []
  
  // Constants
  private let username: String = "POP-000312"
  private let password: String = "98741"
  
  var body: some View {
    ZStack(alignment: .top) {
      VStack {
        HStack(spacing: 32) {
          Text(username)
          
          Text(password)
          
          Spacer()
        }
        
        if !maps.isEmpty {
          VStack(spacing: 24) {
            ForEach(maps.indices, id: \.self) { index in
              PopMapView(popMap: maps[index])
            }
          }
        }
        
        Spacer()
        
        Button {
          fetchAccount()
        } label: {
          Text("Fetch Account")
            .padding()
            .background(.purple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
      }
      .padding()
    }
  }
  
  private func fetchAccount() {
    Task {
      do {
        let response = try await popguideManager.fetchAccount(
          username: username,
          password: password
        )
        print(response.success ?? false)
        
        maps = response.popMaps ?? []
      } catch {
        print(error.localizedDescription)
      }
    }
  }
}

#Preview("Page") {
  ContentView()
    .environmentObject(
      PopguideManager(
        appName: "TestApp",
        language: .english,
        environment: .production
      )
    )
}

// MARK: - PopMapView

struct PopMapView: View {
  
  // Environment Objects
  @EnvironmentObject private var popguideManager: PopguideManager
  @EnvironmentObject private var coordinator: Coordinator
  
  // States
  @State var popMap: PopMapModel
  
  private let columns: [GridItem] = [
    GridItem(.flexible(minimum: 40)),
    GridItem(.flexible(minimum: 40)),
    GridItem(.flexible(minimum: 40))
  ]
  
  var body: some View {
    VStack {
      HStack {
        Text(popMap.name ?? "--")
        
        Spacer()
        
        if let coverPictureUrl = popMap.coverPicture {
          LazyImage(url: URL(string: coverPictureUrl)) { state in
            if let image = state.image {
              image
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 58)
                .clipped()
            } else {
              ProgressView()
            }
          }
        }
      }
      
      LazyVGrid(columns: columns, spacing: 20) {
        ForEach(popMap.packages!.indices, id: \.self) { index in
          VStack(spacing: 8) {
            VStack {
              let languagePack = popMap.packages![index]
              
              if let urlStr = languagePack.languageFlag {
                Button {
                  coordinator.push(
                    Page(
                      .mapDetail(
                        popMap: popMap,
                        languageId: languagePack.languageId!
                      )
                    )
                  )
                } label: {
                  LazyImage(url: URL(string: urlStr)) { state in
                    if let image = state.image {
                      image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .shadow(radius: 2)
                    } else {
                      ProgressView()
                    }
                  }
                }
              }
            }
          }
        }
      }
      .padding(.all, 10)
    }
  }
}

#Preview("PopMapView") {
  ContentView()
}
