//
//  PopMapCard.swift
//  VoxSDK-Test
//
//  A card view that displays a single tour with its cover image and language selectors.
//
//  Each language flag is a `NavigationLink` that pushes ``PopMapDetailView`` with the
//  selected `PopMapModel`, `languageId`, and the current `loginResponse` so the detail
//  screen has access to service URLs like `popMapDetailsUrl`.
//

import NukeUI
import PopguideSDK
import SwiftUI

// MARK: - PopMapCard

struct PopMapCard: View {

  /// The full tour model returned by `fetchAccount`.
  let popMap: PopMapModel

  /// The login response passed through so the detail screen can access service URLs.
  var loginResponse: ApiResponseLogin?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let coverPictureUrl = popMap.coverPicture {
        LazyImage(url: URL(string: coverPictureUrl)) { state in
          if let image = state.image {
            image
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity)
              .clipped()
          } else {
            Rectangle()
              .fill(.quaternary)
              .frame(height: 140)
              .overlay(ProgressView())
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text(popMap.name ?? "--")
          .font(.title3.bold())

        if let packages = popMap.packages, !packages.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Languages")
              .font(.caption)
              .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(packages.indices, id: \.self) { index in
                  let pack = packages[index]
                  if let flagUrl = pack.languageFlag, let langId = pack.languageId {
                    NavigationLink {
                      PopMapDetailView(
                        popMap: popMap,
                        languageId: langId,
                        loginResponse: loginResponse
                      )
                    } label: {
                      VStack(spacing: 4) {
                        LazyImage(url: URL(string: flagUrl)) { state in
                          if let image = state.image {
                            image
                              .resizable()
                              .scaledToFill()
                              .frame(width: 32, height: 32)
                              .clipShape(Circle())
                              .shadow(color: .black.opacity(0.15), radius: 2)
                          } else {
                            Circle()
                              .fill(.quaternary)
                              .frame(width: 32, height: 32)
                          }
                        }
                        
                        if let name = pack.languageName {
                          Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      .padding()
    }
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
  }
}

// MARK: - SDK Model Extensions

extension PopMapCollectionDTO {
  /// A user-facing title built from all available localized collection titles.
  var displayTitle: String {
    let titles = languages?
      .compactMap { $0.collectionTitle }
      .filter { !$0.isEmpty } ?? []
    return titles.isEmpty ? "Collection \(id ?? 0)" : titles.joined(separator: ", ")
  }
}

extension PopMapCollectionDTO.PopMapCollectionDetailDTO {
  /// A compact title for a collection tour item.
  var displayTitle: String {
    title ?? uid ?? "Tour"
  }
}
