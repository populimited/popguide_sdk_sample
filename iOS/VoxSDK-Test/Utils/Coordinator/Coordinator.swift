//
//  MilanoPass
//

import Collections
import Foundation
import SwiftUI

/// A class responsible for managing navigation and presentation of views.
@MainActor
final class Coordinator: ObservableObject {
  
  /// The current navigation path.
  @Published var path = NavigationPath()
  
  /// The current sheet page being presented.
  @Published var sheet: Page?
  @Published var fullScreeCover: Page?
  
  var parentCoordinator: Coordinator?
  
  init(parentCoordinator: Coordinator? = nil) {
    self.parentCoordinator = parentCoordinator
  }
  
  private var pushDismissCallbacks: Deque<() -> Void> = Deque()
  private var sheetDismissCallbacks: Deque<() -> Void> = Deque()
  private var fullScreenDismissCallbacks: Deque<() -> Void> = Deque()
  
  private var navigationStack = [Page]()
  
  var pagesCount: Int {
    path.count
  }
  
  var isPresented: Bool {
    sheet != nil || fullScreeCover != nil
  }
  
  func push(_ page: Page, onDismiss: (() -> Void)? = nil) {
    path.append(page)
    navigationStack.append(page)
    pushDismissCallbacks.append(onDismiss ?? {})
  }
  
  func pop() {
    if !path.isEmpty {
      path.removeLast()
    }
    if !navigationStack.isEmpty {
      navigationStack.removeLast()
    }
    let callback = pushDismissCallbacks.popLast()
    callback?()
  }
  
  func present(_ sheet: Page, onDismiss: (() -> Void)? = nil) {
    self.sheet = sheet
    sheetDismissCallbacks.append(onDismiss ?? {})
  }
  
  func dismissSheet() {
    sheet = nil
    let callback = sheetDismissCallbacks.popLast()
    callback?()
  }
  
  func presentFullScreen(_ page: Page, onDismiss: (() -> Void)? = nil) {
    self.fullScreeCover = page
    fullScreenDismissCallbacks.append(onDismiss ?? {})
  }
  
  func dismissFullScreen() {
    fullScreeCover = nil
    let callback = fullScreenDismissCallbacks.popLast()
    callback?()
  }
  
  func popToRoot() {
    if !path.isEmpty {
      path.removeLast(path.count)
    }
  }
  
  func popToHome() {
    if let index = navigationStack.firstIndex(where: { $0.type == .home }) {
      // Calculate the number of pages to pop
      let numberOfPagesToPop = navigationStack.count - (index + 1)
      
      // Remove pages
      path.removeLast(numberOfPagesToPop)
      navigationStack.removeLast(numberOfPagesToPop)
      
      // Call dismiss callbacks
      for _ in 0..<numberOfPagesToPop {
        let callback = pushDismissCallbacks.popLast()
        callback?()
      }
    }
  }
  
  // FIXME: It's temporarily solution
  func popToPage(_ pageIndex: Int) {
    if !path.isEmpty {
      path.removeLast(pageIndex)
    }
  }
  
  func dismissModal() {
    if fullScreeCover != nil {
      fullScreeCover = nil
      let fullScreenCallback = fullScreenDismissCallbacks.popLast()
      fullScreenCallback?()
    }
    
    if sheet != nil {
      sheet = nil
      let sheetCallback = sheetDismissCallbacks.popLast()
      sheetCallback?()
    }
    
    parentCoordinator?.dismissModal()
  }
  
  @ViewBuilder
  func build(page: Page) -> some View {
    switch page.type {
    case .home:
      ContentView()
    case let .mapDetail(popMap, languageId):
      PopMapDetailView(popMap: popMap, languageId: languageId)
    }
  }
}

struct CoordinatorView: View {
  @StateObject private var coordinator = Coordinator()
  private var parentCoordinator: Coordinator?
  
  let content: () -> AnyView
  
  init(content: @escaping () -> AnyView) {
    self.content = content
  }
  
  private init(parentCoordinator: Coordinator, content: @escaping () -> AnyView) {
    self.content = content
    self.parentCoordinator = parentCoordinator
  }
  
  var body: some View {
    NavigationStack(path: $coordinator.path) {
      content()
        .navigationDestination(for: Page.self) {
          coordinator.build(page: $0)
        }
        .sheet(item: $coordinator.sheet) {
          if $0.isModalWithNavigation {
            let newCoordinator = Coordinator(parentCoordinator: coordinator)
            coordinator.build(page: $0)
              .environmentObject(newCoordinator)
          } else {
            coordinator.build(page: $0)
          }
        }
        .fullScreenCover(item: $coordinator.fullScreeCover) { page in
          if page.isModalWithNavigation {
            
            CoordinatorView(parentCoordinator: coordinator) {
              AnyView(coordinator.build(page: page))
            }
            
          } else {
            coordinator.build(page: page)
          }
        }
    }
    .environmentObject(coordinator)
    .onAppear {
      coordinator.parentCoordinator = parentCoordinator
    }
  }
}
