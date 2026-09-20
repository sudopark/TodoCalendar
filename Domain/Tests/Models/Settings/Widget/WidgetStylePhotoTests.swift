//
//  WidgetStylePhotoTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct WidgetStylePhotoTests {

    private func photo(
        id: String?,
        original: String = "/tmp/a.original",
        rendering: String = "/tmp/a.render.jpg"
    ) -> WidgetStylePhoto {
        return .init(
            id: id, original: URL(filePath: original), rendering: URL(filePath: rendering)
        )
    }

    @Test("식별자가 없으면 아직 저장소 밖에 있는 초안이다")
    func isDraft_whenIdIsNil_isTrue() {
        // given
        let draft = self.photo(id: nil)
        let stored = self.photo(id: "uuid-1")

        // when + then
        #expect(draft.isDraft == true)
        #expect(stored.isDraft == false)
    }

    @Test("식별자가 같아도 파일 자리가 다르면 다른 값이다")
    func equality_comparesFileLocationsToo() {
        // given
        let photo = self.photo(id: "uuid-1")

        // when + then
        #expect(photo == self.photo(id: "uuid-1"))
        #expect(photo != self.photo(id: "uuid-1", original: "/tmp/b.original"))
        #expect(photo != self.photo(id: "uuid-1", rendering: "/tmp/b.render.jpg"))
        #expect(photo != self.photo(id: "uuid-2"))
        #expect(photo != self.photo(id: nil))
    }
}
