//
//  LinkPreview.swift
//  Domain
//
//  Created by sudo.park on 8/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public struct LinkPreview {
    
    public var url: URL?
    public var title: String?
    public var description: String?
    public var mainImagePath: String?
    public var images: [String] = []
    
    public init(
        url: URL? = nil,
        title: String? = nil,
        description: String? = nil,
        mainImagePath: String? = nil,
        images: [String]
    ) {
        self.url = url
        self.title = title
        self.description = description
        self.mainImagePath = mainImagePath
        self.images = images
    }
}
