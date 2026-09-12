//
//  WidgetStyleEditViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import Scenes


// MARK: - cell view models

struct WidgetStyleCellViewModel: Equatable {
    
    let styleId: WidgetStyleId
    let name: String
    let setting: TodayStyleSetting
}

struct WidgetStyleItemCellViewModel: Equatable {
    
    let item: TodayStyleItem
    let isOn: Bool
    
    var name: String { self.item.name }
    var note: String? { self.item.note }
}

extension WidgetStyleId.Style {
    
    var name: String {
        switch self {
        case .default: return "widget.style::default".localized()
        case .custom(let id): return id
        }
    }
}


// MARK: - WidgetStyleEditViewModel

protocol WidgetStyleEditViewModel: AnyObject, WidgetStyleEditSceneInteractor {
    
    func refresh()
    func selectStyle(_ styleId: WidgetStyleId)
    func toggleItem(_ item: TodayStyleItem)
    func confirm()
    func close()
    
    var styles: AnyPublisher<[WidgetStyleCellViewModel], Never> { get }
    var selectedStyleId: AnyPublisher<WidgetStyleId, Never> { get }
    var items: AnyPublisher<[WidgetStyleItemCellViewModel], Never> { get }
}

final class WidgetStyleEditViewModelImple: WidgetStyleEditViewModel, @unchecked Sendable {
    
    private let variant: WidgetVariant
    private let widgetStyleUsecase: any WidgetStyleUsecase
    var router: (any WidgetStyleEditRouting)?
    
    init(
        variant: WidgetVariant,
        widgetStyleUsecase: any WidgetStyleUsecase
    ) {
        self.variant = variant
        self.widgetStyleUsecase = widgetStyleUsecase
    }
    
    private struct Subject {
        let styles = CurrentValueSubject<[WidgetStyle<TodayStyleSetting>]?, Never>(nil)
        let selectedStyleId = CurrentValueSubject<WidgetStyleId?, Never>(nil)
        let editingSetting = CurrentValueSubject<TodayStyleSetting?, Never>(nil)
    }
    private let subject = Subject()
}


// MARK: - 조작

extension WidgetStyleEditViewModelImple {
    
    func refresh() {
        let styles = self.widgetStyleUsecase.loadStyles(TodayStyleSetting.self, of: self.variant)
        self.subject.styles.send(styles)
        guard let first = styles.first else { return }
        self.subject.selectedStyleId.send(first.id)
        self.subject.editingSetting.send(first.setting)
    }
    
    func selectStyle(_ styleId: WidgetStyleId) {
        guard let style = self.subject.styles.value?.first(where: { $0.id == styleId })
        else { return }
        self.subject.selectedStyleId.send(styleId)
        self.subject.editingSetting.send(style.setting)
    }
    
    func toggleItem(_ item: TodayStyleItem) {
        guard let setting = self.subject.editingSetting.value else { return }
        let keyPath = item.settingKeyPath
        let turnedOn = !setting[keyPath: keyPath].isDisplayed
        self.subject.editingSetting.send(setting |> keyPath .~ turnedOn)
    }
    
    func confirm() {
        guard let styleId = self.subject.selectedStyleId.value,
              let setting = self.subject.editingSetting.value
        else { return }
        self.widgetStyleUsecase.updateStyle(setting, for: styleId)
        WidgetCenter.shared.reloadTimelines(ofKind: self.variant.kind)
        self.router?.closeScene()
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - 출력

extension WidgetStyleEditViewModelImple {
    
    /// 고른 카드는 저장값이 아니라 편집 중인 설정을 그린다 — 토글이 미리보기에 바로 비친다.
    var styles: AnyPublisher<[WidgetStyleCellViewModel], Never> {
        return Publishers.CombineLatest3(
            self.subject.styles.compactMap { $0 },
            self.subject.selectedStyleId.compactMap { $0 },
            self.subject.editingSetting.compactMap { $0 }
        )
        .map { styles, selectedId, editing in
            return styles.map { style in
                WidgetStyleCellViewModel(
                    styleId: style.id,
                    name: style.id.style.name,
                    setting: style.id == selectedId ? editing : style.setting
                )
            }
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var selectedStyleId: AnyPublisher<WidgetStyleId, Never> {
        return self.subject.selectedStyleId
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var items: AnyPublisher<[WidgetStyleItemCellViewModel], Never> {
        return self.subject.editingSetting
            .compactMap { $0 }
            .map { setting in
                return TodayStyleItem.allCases.map { item in
                    WidgetStyleItemCellViewModel(
                        item: item, isOn: setting[keyPath: item.settingKeyPath].isDisplayed
                    )
                }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
