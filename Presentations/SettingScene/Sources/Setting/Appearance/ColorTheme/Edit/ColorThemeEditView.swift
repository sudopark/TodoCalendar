//
//  ColorThemeEditView.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


// MARK: - ColorThemeEditViewState

@Observable final class ColorThemeEditViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    fileprivate var sampleModel: CalendarAppearanceModel = .init(.sunday)
    fileprivate var name: String = ""
    fileprivate var seeds: CustomColorThemeSeeds?
    fileprivate var previewColorSet: ColorThemeDefinition?
    fileprivate var isSavable: Bool = false
    fileprivate var isDeletable: Bool = false
    fileprivate var isProcessing: Bool = false

    func bind(_ viewModel: any ColorThemeEditViewModel) {

        guard self.didBind == false else { return }
        self.didBind = true

        self.name = viewModel.initialName ?? ""
        self.isDeletable = viewModel.isDeletable

        viewModel.sampleModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.sampleModel = model
            })
            .store(in: self.cancellables)

        viewModel.seeds
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] seeds in
                self?.seeds = seeds
            })
            .store(in: self.cancellables)

        viewModel.previewColorSet
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] definition in
                self?.previewColorSet = definition
            })
            .store(in: self.cancellables)

        viewModel.isSavable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isSavable = flag
            })
            .store(in: self.cancellables)

        viewModel.isProcessing
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isProcessing = flag
            })
            .store(in: self.cancellables)
    }
}


// MARK: - ColorThemeEditViewEventHandler

final class ColorThemeEditViewEventHandler: Observable {

    var enterName: (String) -> Void = { _ in }
    var selectBackground: (String) -> Void = { _ in }
    var selectAccent: (String) -> Void = { _ in }
    var selectForm: (CustomColorThemeForm) -> Void = { _ in }
    var toggleSeed: (ColorThemeEditSeedSlot, Bool) -> Void = { _, _ in }
    var selectSeed: (ColorThemeEditSeedSlot, String) -> Void = { _, _ in }
    var save: () -> Void = { }
    var delete: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any ColorThemeEditViewModel) {

        self.enterName = viewModel.enterName(_:)
        self.selectBackground = { viewModel.selectBackground(hex: $0) }
        self.selectAccent = { viewModel.selectAccent(hex: $0) }
        self.selectForm = viewModel.selectForm(_:)
        self.toggleSeed = { viewModel.toggleSeed($0, isOn: $1) }
        self.selectSeed = { viewModel.selectSeed($0, hex: $1) }
        self.save = viewModel.save
        self.delete = viewModel.delete
        self.close = viewModel.close
    }
}


// MARK: - ColorThemeEditContainerView

struct ColorThemeEditContainerView: View {

    @State private var state: ColorThemeEditViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: ColorThemeEditViewEventHandler

    var stateBinding: (ColorThemeEditViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: ColorThemeEditViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return ColorThemeEditView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}


// MARK: - ColorThemeEditView

struct ColorThemeEditView: View {

    @Environment(ColorThemeEditViewState.self) private var state
    @Environment(ColorThemeEditViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    @State private var isDetailExpanded: Bool = false

    private let forms: [CustomColorThemeForm] = [.filled, .grouped, .outlined]

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    CalendarAppearanceSampleView(
                        model: self.state.sampleModel,
                        colorSet: self.state.previewColorSet
                    )
                    .padding(.vertical, spacing: .xlarge)

                    self.formView
                }

                FullScreenLoadingView(isLoading: self.state.isProcessing)
            }
            .background(appearance.colorSet.bg0.asColor)
            .navigationTitle(self.titleText)
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        eventHandlers.close()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        eventHandlers.save()
                    } label: {
                        Text("common.save".localized())
                    }
                    .disabled(!self.state.isSavable)
                }
            }
        }
        .id(appearance.navigationBarId)
    }

    private var titleText: String {
        return self.state.isDeletable
            ? "setting.appearance.calendar.colorTheme.edit::title::edit".localized()
            : "setting.appearance.calendar.colorTheme.edit::title::new".localized()
    }

    private var formView: some View {
        List {
            self.formRow { self.nameRow }

            if let seeds = self.state.seeds {
                self.formRow { self.backgroundRow(seeds) }
                self.formRow { self.accentRow(seeds) }
                self.formRow { self.formSelectRow(seeds) }
                self.formRow { self.detailHeaderRow(seeds) }

                if self.isDetailExpanded {
                    ForEach(ColorThemeEditSeedSlot.allCases, id: \.self) { slot in
                        self.formRow { self.seedRow(slot, seeds) }
                    }
                }
            }

            if self.state.isDeletable {
                self.formRow { self.deleteButton }
            }
        }
        .listStyle(.plain)
        .background(appearance.colorSet.bg0.asColor)
    }

    private func formRow<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        return content()
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
            .listRowBackground(appearance.colorSet.bg0.asColor)
    }
}


// MARK: - ColorThemeEditView rows

extension ColorThemeEditView {

    private var nameRow: some View {
        @Bindable var state = self.state
        return AppearanceRow(
            "setting.appearance.calendar.colorTheme.edit::name".localized(),
            TextField(
                "",
                text: $state.name,
                prompt: Text(
                    "setting.appearance.calendar.colorTheme.edit::name::placeholder".localized()
                )
                .foregroundStyle(appearance.colorSet.placeHolder.asColor)
            )
            .onChange(of: state.name) { _, new in
                self.eventHandlers.enterName(new)
            }
            .autocorrectionDisabled()
            .multilineTextAlignment(.trailing)
            .font(self.appearance.fontSet.normal.asFont)
            .foregroundStyle(self.appearance.colorSet.text0.asColor)
            .submitLabel(.done)
        )
    }

    private func backgroundRow(_ seeds: CustomColorThemeSeeds) -> some View {
        return AppearanceRow(
            "setting.appearance.calendar.colorTheme.edit::background".localized(),
            ColorSelectView(Color.from(seeds.background) ?? .clear)
                .eventHandler(\.colorSelected) { color in
                    self.eventHandlers.selectBackground(UIColor(color).rgbHexString)
                }
        )
    }

    private func accentRow(_ seeds: CustomColorThemeSeeds) -> some View {
        return AppearanceRow(
            "setting.appearance.calendar.colorTheme.edit::accent".localized(),
            ColorSelectView(Color.from(seeds.accent) ?? .clear)
                .eventHandler(\.colorSelected) { color in
                    self.eventHandlers.selectAccent(UIColor(color).rgbHexString)
                }
        )
    }

    private func formSelectRow(_ seeds: CustomColorThemeSeeds) -> some View {
        let selection = Binding<CustomColorThemeForm>(
            get: { seeds.form },
            set: { self.eventHandlers.selectForm($0) }
        )
        return AppearanceRow(
            "setting.appearance.calendar.colorTheme.edit::form".localized(),
            Picker("", selection: selection) {
                ForEach(self.forms, id: \.rawValue) { form in
                    Text(form.title).tag(form)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 210)
        )
    }

    private func detailHeaderRow(_ seeds: CustomColorThemeSeeds) -> some View {
        return AppearanceRow(
            "setting.appearance.calendar.colorTheme.edit::details".localized(),
            HStack(spacing: Metric.Spacing.small) {
                if !self.isDetailExpanded {
                    Text(self.detailSummary(seeds))
                        .font(self.appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                }
                Image(systemName: self.isDetailExpanded ? "chevron.up" : "chevron.down")
                    .font(self.appearance.fontSet.size(12).asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            self.appearance.impactIfNeed()
            withAnimation {
                self.isDetailExpanded.toggle()
            }
        }
    }

    private func detailSummary(_ seeds: CustomColorThemeSeeds) -> String {
        let count = ColorThemeEditSeedSlot.allCases
            .filter { seeds.hex(of: $0) != nil }
            .count
        return count == 0
            ? "setting.appearance.calendar.colorTheme.edit::details::auto".localized()
            : String(
                format: "setting.appearance.calendar.colorTheme.edit::details::count".localized(),
                count
            )
    }

    private func seedRow(
        _ slot: ColorThemeEditSeedSlot,
        _ seeds: CustomColorThemeSeeds
    ) -> some View {
        let seedHex = seeds.hex(of: slot)
        let isSpecified = Binding<Bool>(
            get: { seedHex != nil },
            set: { self.eventHandlers.toggleSeed(slot, $0) }
        )
        return AppearanceRow(
            slot.title,
            HStack(spacing: Metric.Spacing.regular) {
                if let seedHex {
                    ColorSelectView(Color.from(seedHex) ?? .clear)
                        .eventHandler(\.colorSelected) { color in
                            self.eventHandlers.selectSeed(slot, UIColor(color).rgbHexString)
                        }
                } else {
                    Text("setting.appearance.calendar.colorTheme.edit::details::auto".localized())
                        .font(self.appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                }

                Toggle("", isOn: isSpecified)
                    .controlSize(.small)
                    .labelsHidden()
            }
        )
    }

    private var deleteButton: some View {
        return ConfirmButton(
            title: "common.remove".localized(),
            textColor: self.appearance.colorSet.accentWarn.asColor,
            backgroundColor: self.appearance.colorSet.secondaryBtnBackground.asColor
        )
        .eventHandler(\.onTap, self.eventHandlers.delete)
    }
}


// MARK: - private helpers

private extension CustomColorThemeSeeds {

    func hex(of slot: ColorThemeEditSeedSlot) -> String? {
        switch slot {
        case .text: return self.text
        case .surface: return self.surface
        case .today: return self.today
        case .selectedDay: return self.selectedDay
        case .holidayOrWeekEnd: return self.holidayOrWeekEnd
        case .ai: return self.ai
        }
    }
}

private extension ColorThemeEditSeedSlot {

    var title: String {
        switch self {
        case .text: return "setting.appearance.calendar.colorTheme.edit::seed::text".localized()
        case .surface: return "setting.appearance.calendar.colorTheme.edit::seed::surface".localized()
        case .today: return "setting.appearance.calendar.colorTheme.edit::seed::today".localized()
        case .selectedDay: return "setting.appearance.calendar.colorTheme.edit::seed::selectedDay".localized()
        case .holidayOrWeekEnd: return "setting.appearance.calendar.colorTheme.edit::seed::holidayOrWeekEnd".localized()
        case .ai: return "setting.appearance.calendar.colorTheme.edit::seed::ai".localized()
        }
    }
}

private extension CustomColorThemeForm {

    var title: String {
        switch self {
        case .filled: return "setting.appearance.calendar.colorTheme.edit::form::filled".localized()
        case .grouped: return "setting.appearance.calendar.colorTheme.edit::form::grouped".localized()
        case .outlined: return "setting.appearance.calendar.colorTheme.edit::form::outlined".localized()
        }
    }
}
