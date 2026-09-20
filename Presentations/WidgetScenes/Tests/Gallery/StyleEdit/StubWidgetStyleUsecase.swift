//
//  StubWidgetStyleUsecase.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


final class StubWidgetStyleUsecase: WidgetStyleUsecase, @unchecked Sendable {
    
    /// 프로덕션이 스타일 좌표별로 스트림을 가르므로 스텁도 좌표별로 나눈다 — 하나로 묶으면
    /// 좌표 하나를 갱신해도 다른 좌표 구독이 함께 흔들려 방출 수가 변형 수를 탄다.
    private var styleSubjects: [WidgetVariant: CurrentValueSubject<[WidgetStyle]?, Never>] = [:]
    var stubStyles: [WidgetStyle] = [] {
        didSet {
            self.styleSubjects
                .filter { $0.value.value != nil }
                .forEach { variant, subject in
                    subject.send(self.styles(in: self.stubStyles, of: variant))
                }
        }
    }
    
    private var mintedStyleIdCount: Int = 0
    private var mintedDraftPhotoCount: Int = 0
    private var mintedStoredPhotoCount: Int = 0
    
    func refreshStyles(of variant: WidgetVariant) {
        self.subject(of: variant).send(self.styles(in: self.stubStyles, of: variant))
    }
    
    func styles(of variant: WidgetVariant) -> AnyPublisher<[WidgetStyle], Never> {
        return self.subject(of: variant)
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {
        return self.styles(in: self.stubStyles, of: variant)
    }
    
    private func subject(
        of variant: WidgetVariant
    ) -> CurrentValueSubject<[WidgetStyle]?, Never> {
        let key = variant.styleVariant
        if let existing = self.styleSubjects[key] { return existing }
        let created = CurrentValueSubject<[WidgetStyle]?, Never>(nil)
        self.styleSubjects[key] = created
        return created
    }
    
    private func styles(
        in styles: [WidgetStyle], of variant: WidgetVariant
    ) -> [WidgetStyle] {
        return styles.filter { $0.id.variant == variant.styleVariant }
    }
    
    /// 기존 좌표는 자리를 지키고 새 좌표만 뒤에 붙는다 — 저장소도 정렬 키로 순서를 정해
    /// 갱신이 목록 순서를 바꾸지 않는다.
    func updateStyle(_ style: WidgetStyle) {
        let stored = self.storing(style)
        guard self.stubStyles.contains(where: { $0.id == stored.id })
        else {
            self.stubStyles = self.stubStyles + [stored]
            return
        }
        self.stubStyles = self.stubStyles.map { $0.id == stored.id ? stored : $0 }
    }

    private func storing(_ style: WidgetStyle) -> WidgetStyle {
        guard let photo = style.photo, photo.isDraft else { return style }
        self.mintedStoredPhotoCount += 1
        let id = "stored\(self.mintedStoredPhotoCount)"
        return style |> \.photo .~ .init(
            id: id,
            original: URL(filePath: "/tmp/\(id).original"),
            rendering: URL(filePath: "/tmp/\(id).render.jpg")
        )
    }
    
    func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId {
        self.mintedStyleIdCount += 1
        return .init(variant: variant, style: .custom(id: "new\(self.mintedStyleIdCount)"))
    }
    
    func removeStyle(_ id: WidgetStyleId) {
        self.stubStyles = self.stubStyles.filter { $0.id != id }
    }
    
    private(set) var didMakeDraftPhotoFrom: Data?
    private(set) var didMakeDraftPhotoCopying: WidgetStylePhoto?
    
    func makeDraftPhoto(from picked: Data) -> WidgetStylePhoto? {
        self.didMakeDraftPhotoFrom = picked
        return self.draftPhoto()
    }
    
    func makeDraftPhoto(copying photo: WidgetStylePhoto) -> WidgetStylePhoto? {
        self.didMakeDraftPhotoCopying = photo
        return self.draftPhoto()
    }
    
    private func draftPhoto() -> WidgetStylePhoto {
        self.mintedDraftPhotoCount += 1
        let name = "draft\(self.mintedDraftPhotoCount)"
        return .init(
            id: nil,
            original: URL(filePath: "/tmp/\(name).original"),
            rendering: URL(filePath: "/tmp/\(name).render.jpg")
        )
    }
}
