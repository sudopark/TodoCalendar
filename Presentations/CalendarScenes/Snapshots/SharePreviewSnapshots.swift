//
//  SharePreviewSnapshots.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation
import Extensions
import SnapshotTestHelpKit

@testable import CalendarScenes


final class SharePreviewSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#8e8e93")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let appearance = ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
        appearance.updateEventColorMap(by: [
            DefaultEventTag.default("#8e8e93"),
            DefaultEventTag.holiday("#ff0000"),
            CustomEventTag(uuid: "work", name: "업무", colorHex: "#4a90d9"),
            CustomEventTag(uuid: "personal", name: "개인", colorHex: "#50c878"),
            CustomEventTag(uuid: "exercise", name: "운동", colorHex: "#ff9f40"),
            CustomEventTag(uuid: "study", name: "스터디", colorHex: "#2ecc71"),
            CustomEventTag(uuid: "family", name: "가족", colorHex: "#e85d75"),
            CustomEventTag(uuid: "hobby", name: "취미", colorHex: "#9b59b6")
        ])
        return appearance
    }

    private func makeViewModel(
        isTagFilterExpanded: Bool,
        tagCellViewModels: [SharePreviewTagCellViewModel],
        lineModels: [SharePreviewLineModel],
        dateHeaderText: String,
        includeTagName: Bool,
        isShareEnabled: Bool
    ) -> any SharePreviewViewModel {
        return FakeSharePreviewViewModel(
            isTagFilterExpanded: isTagFilterExpanded,
            tagCellViewModels: tagCellViewModels,
            lineModels: lineModels,
            dateHeaderText: dateHeaderText,
            includeTagName: includeTagName,
            isShareEnabled: isShareEnabled
        )
    }

    // MARK: - default: 태그 필터 접힘, 행 5개 중 1개 isExcluded, 태그명 표시 off

    @MainActor
    func test_default() {
        captureSnapshotPair(named: "default", layout: .fullScreen) { theme in
            let viewModel = self.makeViewModel(
                isTagFilterExpanded: false,
                tagCellViewModels: [
                    .init(tagId: .custom("work"), name: "업무", isOn: true),
                    .init(tagId: .custom("personal"), name: "개인", isOn: true)
                ],
                lineModels: [
                    .init(eventId: "todo-1", dayStart: 0, name: "장보기", timeText: nil, tagId: .custom("personal"), tagName: "개인", isTodo: true),
                    .init(eventId: "todo-2", dayStart: 0, name: "병원 예약", timeText: "09:00", tagId: .custom("work"), tagName: "업무", isTodo: true),
                    .init(eventId: "sc-1", dayStart: 0, name: "팀 스탠드업", timeText: "09:00", tagId: .custom("work"), tagName: "업무"),
                    .init(
                        eventId: "sc-2", dayStart: 0, name: "디자인 리뷰", timeText: "13:00~14:30",
                        tagId: .custom("work"), tagName: "업무", isExcluded: true
                    ),
                    .init(
                        eventId: "sc-3", dayStart: 0, name: "가족 여행", timeText: R.String.calendarEventTimeAllday,
                        tagId: .custom("personal"), tagName: "개인"
                    )
                ],
                dateHeaderText: "08/15/2026 (Sat)",
                includeTagName: false,
                isShareEnabled: true
            )
            let state = SharePreviewViewState()
            state.bind(viewModel)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return SharePreviewView()
                .environment(state)
                .environment(SharePreviewViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - tagFilterExpanded: 태그 펼침, 6개 중 2개 off

    @MainActor
    func test_tagFilterExpanded() {
        captureSnapshotPair(named: "tagFilterExpanded", layout: .fullScreen) { theme in
            let viewModel = self.makeViewModel(
                isTagFilterExpanded: true,
                tagCellViewModels: [
                    .init(tagId: .custom("work"), name: "업무", isOn: true),
                    .init(tagId: .custom("personal"), name: "개인", isOn: true),
                    .init(tagId: .custom("exercise"), name: "운동", isOn: true),
                    .init(tagId: .custom("study"), name: "스터디", isOn: true),
                    .init(tagId: .custom("family"), name: "가족", isOn: false),
                    .init(tagId: .custom("hobby"), name: "취미", isOn: false)
                ],
                lineModels: [
                    .init(eventId: "todo-1", dayStart: 0, name: "장보기", timeText: nil, tagId: .custom("personal"), tagName: "개인", isTodo: true),
                    .init(eventId: "sc-1", dayStart: 0, name: "팀 스탠드업", timeText: "09:00", tagId: .custom("work"), tagName: "업무"),
                    .init(eventId: "sc-2", dayStart: 0, name: "요가 클래스", timeText: "18:00~19:00", tagId: .custom("exercise"), tagName: "운동"),
                    .init(eventId: "sc-3", dayStart: 0, name: "알고리즘 스터디", timeText: "20:00~21:30", tagId: .custom("study"), tagName: "스터디"),
                    .init(
                        eventId: "sc-4", dayStart: 0, name: "가족 저녁 식사", timeText: "19:30",
                        tagId: .custom("family"), tagName: "가족", isExcluded: true, isExcludedByTag: true
                    ),
                    .init(
                        eventId: "sc-5", dayStart: 0, name: "기타 연습", timeText: nil,
                        tagId: .custom("hobby"), tagName: "취미", isExcluded: true, isExcludedByTag: true
                    ),
                    .init(
                        eventId: "sc-6", dayStart: 0, name: "헬스장", timeText: "07:00",
                        tagId: .custom("exercise"), tagName: "운동", isExcluded: true
                    )
                ],
                dateHeaderText: "08/15/2026 (Sat)",
                includeTagName: false,
                isShareEnabled: true
            )
            let state = SharePreviewViewState()
            state.bind(viewModel)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return SharePreviewView()
                .environment(state)
                .environment(SharePreviewViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - includeTagName: 태그명 표시 on

    @MainActor
    func test_includeTagName() {
        captureSnapshotPair(named: "includeTagName", layout: .fullScreen) { theme in
            let viewModel = self.makeViewModel(
                isTagFilterExpanded: false,
                tagCellViewModels: [
                    .init(tagId: .custom("work"), name: "업무", isOn: true),
                    .init(tagId: .custom("personal"), name: "개인", isOn: true),
                    .init(tagId: .custom("exercise"), name: "운동", isOn: true)
                ],
                lineModels: [
                    .init(eventId: "todo-1", dayStart: 0, name: "이력서 업데이트", timeText: nil, tagId: .custom("work"), tagName: "업무", isTodo: true),
                    .init(eventId: "sc-1", dayStart: 0, name: "치과 예약", timeText: "10:30", tagId: .custom("personal"), tagName: "개인"),
                    .init(eventId: "sc-2", dayStart: 0, name: "프로젝트 회의", timeText: "14:00~15:00", tagId: .custom("work"), tagName: "업무"),
                    .init(
                        eventId: "sc-3", dayStart: 0, name: "마라톤 대회", timeText: R.String.calendarEventTimeAllday,
                        tagId: .custom("exercise"), tagName: "운동"
                    )
                ],
                dateHeaderText: "08/15/2026 (Sat)",
                includeTagName: true,
                isShareEnabled: true
            )
            let state = SharePreviewViewState()
            state.bind(viewModel)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return SharePreviewView()
                .environment(state)
                .environment(SharePreviewViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - empty: 행 0건

    @MainActor
    func test_empty() {
        captureSnapshotPair(named: "empty", layout: .fullScreen) { theme in
            let viewModel = self.makeViewModel(
                isTagFilterExpanded: false,
                tagCellViewModels: [],
                lineModels: [],
                dateHeaderText: "08/20/2026 (Thu)",
                includeTagName: false,
                isShareEnabled: false
            )
            let state = SharePreviewViewState()
            state.bind(viewModel)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return SharePreviewView()
                .environment(state)
                .environment(SharePreviewViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}


// MARK: - Test Doubles

/// SharePreviewViewState의 필드가 fileprivate라 state를 직접 채울 수 없어
/// production의 bind(_:) 경로로 상태를 주입하기 위한 최소 스텁.
private final class FakeSharePreviewViewModel: SharePreviewViewModel, @unchecked Sendable {

    private let stubIsTagFilterExpanded: Bool
    private let stubTagCellViewModels: [SharePreviewTagCellViewModel]
    private let stubLineModels: [SharePreviewLineModel]
    private let stubDateHeaderText: String
    private let stubIncludeTagName: Bool
    private let stubIsShareEnabled: Bool

    init(
        isTagFilterExpanded: Bool,
        tagCellViewModels: [SharePreviewTagCellViewModel],
        lineModels: [SharePreviewLineModel],
        dateHeaderText: String,
        includeTagName: Bool,
        isShareEnabled: Bool
    ) {
        self.stubIsTagFilterExpanded = isTagFilterExpanded
        self.stubTagCellViewModels = tagCellViewModels
        self.stubLineModels = lineModels
        self.stubDateHeaderText = dateHeaderText
        self.stubIncludeTagName = includeTagName
        self.stubIsShareEnabled = isShareEnabled
    }

    func prepare() { }
    func toggleTagFilterExpanded() { }
    func toggleTag(_ tagId: EventTagId) { }
    func selectAllTags() { }
    func deselectAllTags() { }
    func toggleLine(_ eventId: String) { }
    func toggleIncludeTagName(_ newValue: Bool) { }
    func share() { }
    func close() { }

    var isTagFilterExpanded: AnyPublisher<Bool, Never> {
        Just(self.stubIsTagFilterExpanded).eraseToAnyPublisher()
    }
    var tagCellViewModels: AnyPublisher<[SharePreviewTagCellViewModel], Never> {
        Just(self.stubTagCellViewModels).eraseToAnyPublisher()
    }
    var lineModels: AnyPublisher<[SharePreviewLineModel], Never> {
        Just(self.stubLineModels).eraseToAnyPublisher()
    }
    var sectionModels: AnyPublisher<[SharePreviewSectionModel], Never> {
        let sections = SharePreviewSectionComposer(timeZone: TimeZone(abbreviation: "KST")!)
            .sections(of: self.stubLineModels)
        return Just(sections).eraseToAnyPublisher()
    }
    var dateHeaderText: AnyPublisher<String, Never> {
        Just(self.stubDateHeaderText).eraseToAnyPublisher()
    }
    var includeTagName: AnyPublisher<Bool, Never> {
        Just(self.stubIncludeTagName).eraseToAnyPublisher()
    }
    var isShareEnabled: AnyPublisher<Bool, Never> {
        Just(self.stubIsShareEnabled).eraseToAnyPublisher()
    }
}
