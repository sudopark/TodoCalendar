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
    let hasUnsavedChange: Bool
    let setting: any WidgetStyleSetting
    let background: WidgetAppearanceSettings.Background?
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.styleId == rhs.styleId
            && lhs.name == rhs.name
            && lhs.hasUnsavedChange == rhs.hasUnsavedChange
            && lhs.background == rhs.background
            && lhs.setting.isSame(rhs.setting)
    }
}


// MARK: - WidgetStyleEditViewModel

protocol WidgetStyleEditViewModel: AnyObject, WidgetStyleEditSceneInteractor {
    
    func refresh()
    func selectStyle(_ styleId: WidgetStyleId)
    func addStyle()
    func appendStyle(copying styleId: WidgetStyleId)
    func removeStyle(_ styleId: WidgetStyleId)
    func resetStyle(_ styleId: WidgetStyleId)
    func discard()
    func editName(_ name: String)
    func updateSetting(_ setting: any WidgetStyleSetting)
    func updateBackground(_ hex: String)
    func confirm()
    func close()
    
    var styles: AnyPublisher<[WidgetStyleCellViewModel], Never> { get }
    var selectedStyleId: AnyPublisher<WidgetStyleId, Never> { get }
    var editingName: AnyPublisher<String, Never> { get }
    var hasUnsavedChange: AnyPublisher<Bool, Never> { get }
    var hasAnyUnsavedEdit: AnyPublisher<Bool, Never> { get }
    var selectedSetting: AnyPublisher<any WidgetStyleSetting, Never> { get }
    var selectedBackground: AnyPublisher<WidgetAppearanceSettings.Background?, Never> { get }
}

final class WidgetStyleEditViewModelImple: WidgetStyleEditViewModel, @unchecked Sendable {
    
    private let variants: [WidgetVariant]
    private let widgetStyleUsecase: any WidgetStyleUsecase
    var router: (any WidgetStyleEditRouting)?
    
    init(
        variants: [WidgetVariant],
        widgetStyleUsecase: any WidgetStyleUsecase
    ) {
        self.variants = variants
        self.widgetStyleUsecase = widgetStyleUsecase
    }
    
    private struct Subject {
        let savedStyles = CurrentValueSubject<[WidgetStyleId: WidgetStyle]?, Never>(nil)
        let editingStyles = CurrentValueSubject<[WidgetStyle]?, Never>(nil)
        let selectedStyleId = CurrentValueSubject<WidgetStyleId?, Never>(nil)
        let editingName = CurrentValueSubject<String?, Never>(nil)
    }
    private let subject = Subject()
}


// MARK: - 조작

extension WidgetStyleEditViewModelImple {
    
    func refresh() {
        let styles = self.styleVariants().flatMap {
            self.widgetStyleUsecase.loadStyles(of: $0)
        }
        self.subject.savedStyles.send(styles.asDictionary { $0.id })
        self.subject.editingStyles.send(styles)
        guard let first = styles.first else { return }
        self.select(first.id)
    }
    
    func selectStyle(_ styleId: WidgetStyleId) {
        guard self.editingStyle(of: styleId) != nil else { return }
        self.select(styleId)
    }
    
    /// 추가 카드는 복제할 카드를 고르지 않는다 — 목록 맨 앞의 기본 스타일에서 시작한다.
    func addStyle() {
        guard let first = self.subject.editingStyles.value?.first else { return }
        self.appendStyle(copying: first.id)
    }
    
    func appendStyle(copying styleId: WidgetStyleId) {
        guard let styles = self.subject.editingStyles.value,
              let source = styles.first(where: { $0.id == styleId })
        else { return }
        let newStyle = WidgetStyle(
            id: self.widgetStyleUsecase.makeNewStyleId(for: source.id.variant),
            name: self.copiedName(from: source, in: styles),
            setting: source.setting,
            background: source.background
        )
        self.subject.editingStyles.send(styles + [newStyle])
        self.select(newStyle.id)
    }
    
    func removeStyle(_ styleId: WidgetStyleId) {
        let confirmed: () -> Void = { [weak self] in self?.dropStyle(styleId) }
        let info = ConfirmDialogInfo()
            |> \.message .~ pure("widget.style.edit::remove::message".localized())
            |> \.confirmText .~ "common.remove".localized()
            |> \.confirmed .~ pure(confirmed)
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }
    
    func resetStyle(_ styleId: WidgetStyleId) {
        guard let initialSetting = styleId.variant.initialSetting else { return }
        let confirmed: () -> Void = { [weak self] in
            self?.replaceStyle(styleId) {
                $0 |> \.setting .~ initialSetting |> \.name .~ nil |> \.background .~ nil
            }
            self?.refreshEditingName()
        }
        let info = ConfirmDialogInfo()
            |> \.message .~ pure("widget.style.edit::reset::message".localized())
            |> \.confirmText .~ "widget.style.edit::reset::confirm".localized()
            |> \.confirmed .~ pure(confirmed)
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }
    
    /// 저장본이 없는 초안을 되돌리면 남길 값이 없어 목록에서 뺀다.
    func discard() {
        guard let selectedId = self.subject.selectedStyleId.value else { return }
        guard let saved = self.subject.savedStyles.value?[selectedId] else {
            self.dropStyle(selectedId)
            return
        }
        self.replaceStyle(selectedId) { _ in saved }
        self.refreshEditingName()
    }
    
    func editName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).emptyAsNil()
        self.updateSelectedStyle { $0 |> \.name .~ trimmed }
    }
    
    /// 다른 변형의 설정이 섞이면 저장 때 조용히 막힌다 — 들어오는 자리에서 끊는다.
    func updateSetting(_ setting: any WidgetStyleSetting) {
        guard self.variants.first?.isOwnSetting(setting) == true else { return }
        self.updateSelectedStyle { $0 |> \.setting .~ setting }
    }
    
    func updateBackground(_ hex: String) {
        self.updateSelectedStyle { $0 |> \.background .~ .custom(hex: hex) }
    }
    
    /// 저장해도 화면에 남는다 — 다른 카드를 이어서 저장할 수 있어야 한다.
    func confirm() {
        self.saveSelectedStyle()
    }
    
    /// 편집분은 화면에만 있어서, 이탈 경로가 어디든 여기서 붙잡지 않으면 그대로 사라진다.
    func close() {
        guard self.hasUnsavedEdit() else {
            self.router?.closeScene()
            return
        }
        let form = ActionSheetForm()
            |> \.message .~ pure("widget.style.edit::unsaved::message".localized())
            |> \.actions .~ [
                .init("widget.style.edit::unsaved::save".localized()) { [weak self] in
                    self?.saveAllEditingStyles()
                    self?.router?.closeScene()
                },
                .init(
                    "widget.style.edit::unsaved::discard".localized(), style: .destructive
                ) { [weak self] in
                    self?.router?.closeScene()
                },
                .init("common.cancel".localized(), style: .cancel)
            ]
        self.router?.showActionSheet(form)
    }
    
    /// 스타일을 공유하는 변형끼리는 좌표가 같아 그대로 훑으면 같은 목록이 여러 벌 이어붙는다.
    private func styleVariants() -> [WidgetVariant] {
        return self.variants.map { $0.styleVariant }.removeDuplicates { $0 }
    }

    private func dropStyle(_ styleId: WidgetStyleId) {
        guard let styles = self.subject.editingStyles.value else { return }
        if let saved = self.subject.savedStyles.value, saved[styleId] != nil {
            self.widgetStyleUsecase.removeStyle(styleId)
            self.subject.savedStyles.send(saved.filter { $0.key != styleId })
        }
        let remains = styles.filter { $0.id != styleId }
        self.subject.editingStyles.send(remains)
        guard self.subject.selectedStyleId.value == styleId, let first = remains.first
        else { return }
        self.select(first.id)
    }
    
    private func updateSelectedStyle(
        _ mutating: (WidgetStyle) -> WidgetStyle
    ) {
        guard let selectedId = self.subject.selectedStyleId.value else { return }
        self.replaceStyle(selectedId, mutating)
    }
    
    private func replaceStyle(
        _ styleId: WidgetStyleId,
        _ mutating: (WidgetStyle) -> WidgetStyle
    ) {
        guard let styles = self.subject.editingStyles.value else { return }
        self.subject.editingStyles.send(
            styles.map { $0.id == styleId ? mutating($0) : $0 }
        )
    }
    
    private func saveSelectedStyle() {
        guard let selectedId = self.subject.selectedStyleId.value,
              let editing = self.editingStyle(of: selectedId),
              editing.isSame(self.subject.savedStyles.value?[selectedId]) == false
        else { return }
        self.save([editing])
    }

    /// 이탈 경로에서만 쓴다 — 화면을 떠나면 남은 편집분을 되살릴 자리가 없다.
    private func saveAllEditingStyles() {
        guard let editings = self.subject.editingStyles.value else { return }
        let saved = self.subject.savedStyles.value ?? [:]
        self.save(editings.filter { $0.isSame(saved[$0.id]) == false })
    }

    private func save(_ styles: [WidgetStyle]) {
        guard !styles.isEmpty else { return }
        styles.forEach { self.widgetStyleUsecase.updateStyle($0) }
        Set(self.variants.map { $0.kind }).forEach {
            WidgetCenter.shared.reloadTimelines(ofKind: $0)
        }
        self.subject.savedStyles.send(
            (self.subject.savedStyles.value ?? [:])
                .merging(styles.asDictionary { $0.id }) { _, saved in saved }
        )
    }
    
    private func select(_ styleId: WidgetStyleId) {
        self.subject.selectedStyleId.send(styleId)
        self.refreshEditingName()
    }
    
    /// 입력 값은 화면이 들고 있어서, 편집분이 바깥 사유로 바뀌면 여기서 되돌려보내야 화면과 어긋나지 않는다.
    private func refreshEditingName() {
        guard let selectedId = self.subject.selectedStyleId.value else { return }
        self.subject.editingName.send(self.editingStyle(of: selectedId)?.name ?? "")
    }
    
    private func copiedName(
        from source: WidgetStyle,
        in styles: [WidgetStyle]
    ) -> String {
        let baseName = "widget.style::custom::copy_format".localized(with: source.displayName)
        let takenNames = Set(styles.map { $0.displayName })
        guard takenNames.contains(baseName) else { return baseName }
        return (2...).lazy
            .map { "\(baseName) \($0)" }
            .first { takenNames.contains($0) == false } ?? baseName
    }
    
    private func editingStyle(of styleId: WidgetStyleId) -> WidgetStyle? {
        return self.subject.editingStyles.value?.first { $0.id == styleId }
    }
    
    private func hasUnsavedEdit() -> Bool {
        guard let editings = self.subject.editingStyles.value,
              let saved = self.subject.savedStyles.value
        else { return false }
        return editings.hasUnsavedEdit(against: saved)
    }
}


// MARK: - 출력

extension WidgetStyleEditViewModelImple {
    
    var styles: AnyPublisher<[WidgetStyleCellViewModel], Never> {
        return Publishers.CombineLatest(
            self.subject.editingStyles.compactMap { $0 },
            self.subject.savedStyles.compactMap { $0 }
        )
        .map { editings, saved in
            return editings.map { style in
                WidgetStyleCellViewModel(
                    styleId: style.id,
                    name: style.displayName,
                    hasUnsavedChange: style.isSame(saved[style.id]) == false,
                    setting: style.setting,
                    background: style.background
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
    
    /// 입력 중인 글자는 흘리지 않는다 — 되돌려보내면 화면 입력과 맞물려 돈다.
    var editingName: AnyPublisher<String, Never> {
        return self.subject.editingName
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    /// 하단 버튼이 고른 스타일 하나만 다루므로 표시도 그 스타일 기준이다.
    var hasUnsavedChange: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest3(
            self.subject.editingStyles.compactMap { $0 },
            self.subject.savedStyles.compactMap { $0 },
            self.subject.selectedStyleId.compactMap { $0 }
        )
        .map { editings, saved, selectedId in
            guard let editing = editings.first(where: { $0.id == selectedId })
            else { return false }
            return editing.isSame(saved[selectedId]) == false
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    /// 엣지 스와이프 잠금은 목록 전체 기준이다 — 고르지 않은 카드의 편집분도 이탈하면 사라진다.
    var hasAnyUnsavedEdit: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest(
            self.subject.editingStyles.compactMap { $0 },
            self.subject.savedStyles.compactMap { $0 }
        )
        .map { $0.hasUnsavedEdit(against: $1) }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var selectedSetting: AnyPublisher<any WidgetStyleSetting, Never> {
        return Publishers.CombineLatest(
            self.subject.editingStyles.compactMap { $0 },
            self.subject.selectedStyleId.compactMap { $0 }
        )
        .compactMap { editings, selectedId in
            return editings.first { $0.id == selectedId }?.setting
        }
        .removeDuplicates { $0.isSame($1) }
        .eraseToAnyPublisher()
    }
    
    var selectedBackground: AnyPublisher<WidgetAppearanceSettings.Background?, Never> {
        return Publishers.CombineLatest(
            self.subject.editingStyles.compactMap { $0 },
            self.subject.selectedStyleId.compactMap { $0 }
        )
        .map { editings, selectedId in
            return editings.first { $0.id == selectedId }?.background
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}


// MARK: - 편집분 대조

private extension Array where Element == WidgetStyle {

    func hasUnsavedEdit(against saved: [WidgetStyleId: Element]) -> Bool {
        return self.contains { $0.isSame(saved[$0.id]) == false }
    }
}
