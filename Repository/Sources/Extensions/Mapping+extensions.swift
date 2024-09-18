//
//  Mapping+extensions.swift
//  Repository
//
//  Created by sudo.park on 3/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions

extension Encodable {
    
    func asJson() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any]
        else {
            throw RuntimeError("Deserialized object is not a dictionary")
        }
        return json
    }
}
