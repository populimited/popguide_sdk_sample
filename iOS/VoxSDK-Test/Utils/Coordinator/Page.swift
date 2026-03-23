//
//  MilanoPass
//

import Foundation
import PopguideSDK
import SwiftUI

struct Page: Hashable, Identifiable {
  enum PageType: Equatable {
    case home
    case mapDetail(popMap: PopMapModel, languageId: Int, loginResponse: ApiResponseLogin?)
    
    var id: String {
      String(reflecting: self)
    }
    
    static func == (lhs: Page.PageType, rhs: Page.PageType) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  let id = UUID()
  let type: PageType
  var isModalWithNavigation: Bool
  
  init(_ type: PageType, isModalWithNavigation: Bool = false) {
    self.type = type
    self.isModalWithNavigation = isModalWithNavigation
  }
  
  static func == (lhs: Page, rhs: Page) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
