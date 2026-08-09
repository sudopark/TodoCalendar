//
//  SharedCommandItem.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 공유 시트가 넘긴 아이템. 텍스트인지 이미지인지가 이후 화면·전송 분기를 가른다.
enum SharedCommandItem: Sendable, Equatable {
    case text(String)
    case image(Data)
}
