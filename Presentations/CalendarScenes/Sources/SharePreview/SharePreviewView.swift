//
//  SharePreviewView.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Scenes
import CommonPresentation
import Extensions


// MARK: - SharePreviewViewState

@Observable final class SharePreviewViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    fileprivate var isTagFilterExpanded: Bool = false
    fileprivate var tagCellViewModels: [SharePreviewTagCellViewModel] = []
    fileprivate var sectionModels: [SharePreviewSectionModel] = []
    fileprivate var dateHeaderText: String = ""
    fileprivate var includeTagName: Bool = false
    fileprivate var isShareEnabled: Bool = false
    fileprivate var format: SharePreviewFormat = .text
    fileprivate var imageContentModel: ShareImageContentModel? = nil
    fileprivate var imageHeaderText: String = ""
    fileprivate var isIncludeTagNameOptionVisible: Bool = true

    func bind(_ viewModel: any SharePreviewViewModel) {

        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.isTagFilterExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] isExpanded in self?.isTagFilterExpanded = isExpanded }
            .store(in: &self.cancellables)

        viewModel.tagCellViewModels
            .receive(on: RunLoop.main)
            .sink { [weak self] models in self?.tagCellViewModels = models }
            .store(in: &self.cancellables)

        viewModel.sectionModels
            .receive(on: RunLoop.main)
            .sink { [weak self] sections in self?.sectionModels = sections }
            .store(in: &self.cancellables)

        viewModel.dateHeaderText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.dateHeaderText = text }
            .store(in: &self.cancellables)

        viewModel.includeTagName
            .receive(on: RunLoop.main)
            .sink { [weak self] isOn in self?.includeTagName = isOn }
            .store(in: &self.cancellables)

        viewModel.isShareEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnable in self?.isShareEnabled = isEnable }
            .store(in: &self.cancellables)

        viewModel.format
            .receive(on: RunLoop.main)
            .sink { [weak self] format in self?.format = format }
            .store(in: &self.cancellables)

        viewModel.imageContentModel
            .receive(on: RunLoop.main)
            .sink { [weak self] content in self?.imageContentModel = content }
            .store(in: &self.cancellables)

        viewModel.imageHeaderText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.imageHeaderText = text }
            .store(in: &self.cancellables)

        viewModel.isIncludeTagNameOptionVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in self?.isIncludeTagNameOptionVisible = isVisible }
            .store(in: &self.cancellables)
    }
}


// MARK: - SharePreviewViewEventHandler

final class SharePreviewViewEventHandler: Observable {
    var prepare: () -> Void = { }
    var close: () -> Void = { }
    var toggleTagFilterExpanded: () -> Void = { }
    var toggleTag: (EventTagId) -> Void = { _ in }
    var selectAllTags: () -> Void = { }
    var deselectAllTags: () -> Void = { }
    var toggleLine: (String) -> Void = { _ in }
    var toggleIncludeTagName: (Bool) -> Void = { _ in }
    var selectFormat: (SharePreviewFormat) -> Void = { _ in }
    var share: () -> Void = { }

    func bind(_ viewModel: any SharePreviewViewModel) {
        self.prepare = viewModel.prepare
        self.close = viewModel.close
        self.toggleTagFilterExpanded = viewModel.toggleTagFilterExpanded
        self.toggleTag = viewModel.toggleTag(_:)
        self.selectAllTags = viewModel.selectAllTags
        self.deselectAllTags = viewModel.deselectAllTags
        self.toggleLine = viewModel.toggleLine(_:)
        self.toggleIncludeTagName = viewModel.toggleIncludeTagName(_:)
        self.selectFormat = viewModel.selectFormat(_:)
        self.share = viewModel.share
    }
}


// MARK: - SharePreviewContainerView

struct SharePreviewContainerView: View {

    @State private var state: SharePreviewViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SharePreviewViewEventHandler

    var stateBinding: (SharePreviewViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SharePreviewViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        SharePreviewView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.prepare()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}


// MARK: - SharePreviewView

struct SharePreviewView: View {

    @Environment(SharePreviewViewState.self) private var state
    @Environment(SharePreviewViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: "share_preview::title".localized())
                .eventHandler(\.onClose, self.eventHandlers.close)
                .padding(.horizontal, spacing: .regular)

            self.formatPickerView()
                .padding(.horizontal, spacing: .regular)
                .padding(.top, spacing: .small)

            self.tagFilterView()
                .padding(.horizontal, spacing: .regular)
                .padding(.top, spacing: .regular)

            ScrollView {
                self.formatBodyView()
                    .padding(spacing: .regular)
            }

            if self.state.isIncludeTagNameOptionVisible {
                self.optionView()
            }

            BottomConfirmButton(
                title: "share_preview::share_button".localized(),
                isEnable: self.state.isShareEnabled
            )
            .eventHandler(\.onTap, self.eventHandlers.share)
        }
        .background(self.appearance.colorSet.bg0.asColor)
    }

    // MARK: - format picker

    private func formatPickerView() -> some View {
        Picker("", selection: Binding(
            get: { self.state.format },
            set: { self.eventHandlers.selectFormat($0) }
        )) {
            Text("share_preview::format::text".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .tag(SharePreviewFormat.text)
            Text("share_preview::format::image".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .tag(SharePreviewFormat.image)
        }
        .pickerStyle(.segmented)
        // 세그먼트 색은 시스템 트레이트를 따라가므로 앱 테마에 국소 고정한다.
        .colorScheme(self.appearance.colorSet is DefaultDarkColorSet ? .dark : .light)
    }

    // MARK: - tag filter dropdown

    private func tagFilterView() -> some View {
        VStack(alignment: .leading, spacing: 0) {

            Button {
                self.appearance.impactIfNeed()
                self.eventHandlers.toggleTagFilterExpanded()
            } label: {
                HStack(spacing: Metric.Spacing.small) {
                    Text("share_preview::tag_filter::title".localized())
                        .font(self.appearance.fontSet.normal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text0.asColor)
                    Text("\(self.onTagCount) / \(self.state.tagCellViewModels.count)")
                        .font(self.appearance.fontSet.normal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                    Spacer()
                    Image(systemName: self.state.isTagFilterExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                }
                .padding(spacing: .regular)
            }

            if self.state.isTagFilterExpanded {
                VStack(alignment: .leading, spacing: Metric.Spacing.small) {
                    ForEach(self.state.tagCellViewModels) { cellViewModel in
                        self.tagCellView(cellViewModel)
                    }
                    HStack {
                        Button {
                            self.eventHandlers.selectAllTags()
                        } label: {
                            Text("share_preview::tag_filter::select_all".localized())
                                .foregroundStyle(self.appearance.colorSet.accent.asColor)
                        }
                        Spacer()
                        Button {
                            self.eventHandlers.deselectAllTags()
                        } label: {
                            Text("share_preview::tag_filter::deselect_all".localized())
                                .foregroundStyle(self.appearance.colorSet.accent.asColor)
                        }
                    }
                }
                .font(self.appearance.fontSet.normal.asFont)
                .padding(.horizontal, spacing: .regular)
                .padding(.bottom, spacing: .regular)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }

    private var onTagCount: Int {
        self.state.tagCellViewModels.filter { $0.isOn }.count
    }

    private func tagCellView(_ cellViewModel: SharePreviewTagCellViewModel) -> some View {
        let colorSource: any EventTagColorSource = {
            switch cellViewModel.tagId {
            case .externalCalendar(AppleCalendarService.id, let calendarId):
                return AppleCalendarEventColorSource(calendarId: calendarId)
            case .externalCalendar(_, let calendarId):
                return GoogleCalendarEventColorSource(calendarId: calendarId, colorId: nil)
            default:
                return cellViewModel.tagId
            }
        }()

        return HStack(spacing: Metric.Spacing.small) {
            EventTagColorView(colorSource) { color in
                Image(systemName: cellViewModel.isOn ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(color)
                    .font(.title3)
            }
            .animation(.easeIn, value: cellViewModel.isOn)
            .onTapGesture {
                self.appearance.impactIfNeed()
                self.eventHandlers.toggleTag(cellViewModel.tagId)
            }
            Text(cellViewModel.name)
                .lineLimit(1)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            Spacer()
        }
    }

    // MARK: - event line list

    @ViewBuilder
    private func formatBodyView() -> some View {
        switch self.state.format {
        case .text:
            self.bodyView()
        case .image:
            if let content = self.state.imageContentModel {
                ShareImageCardView(
                    headerText: self.state.imageHeaderText, content: content, cardWidth: self.cardWidth
                )
                .eventHandler(\.lineTapped, self.eventHandlers.toggleLine)
            } else {
                self.emptyView()
            }
        }
    }

    // SharePreviewRouter의 cardWidth와 같은 값이어야 미리보기와 공유 이미지가 어긋나지 않는다.
    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - Metric.Spacing.regular * 2
    }

    private func bodyView() -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            Text(self.state.dateHeaderText)
                .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)

            if self.state.sectionModels.isEmpty {
                self.emptyView()
            } else {
                ForEach(self.state.sectionModels) { section in
                    self.sectionView(section)
                }
            }
        }
    }

    private func sectionView(_ section: SharePreviewSectionModel) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            if let dayHeaderText = section.dayHeaderText {
                Text(dayHeaderText)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                    .padding(.top, spacing: .small)
            }
            ForEach(section.lines) { line in
                self.lineRowView(line)
            }
        }
    }

    private func emptyView() -> some View {
        Text("share_preview::empty".localized())
            .font(self.appearance.fontSet.normal.asFont)
            .foregroundStyle(self.appearance.colorSet.text2.asColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing: .xlarge)
    }

    private func lineRowView(_ line: SharePreviewLineModel) -> some View {
        let rowColor = line.isExcluded
            ? self.appearance.colorSet.text2.asColor
            : self.appearance.colorSet.text0.asColor
        return HStack(alignment: .top, spacing: Metric.Spacing.small) {
            Image(systemName: line.isExcluded ? "square" : "checkmark.square.fill")
                .foregroundStyle(
                    line.isExcluded ? self.appearance.colorSet.text2.asColor : self.appearance.colorSet.accent.asColor
                )
                .opacity(line.isExcludedByTag ? Constant.disabledCheckboxOpacity : 1)
            self.lineRowText(line)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(rowColor)
            Spacer()
        }
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.eventHandlers.toggleLine(line.eventId)
        }
        .allowsHitTesting(!line.isExcludedByTag)
    }

    // EventShareTextBuilder.bulletLine과 같은 조립 규칙 — 화면과 공유 텍스트가 일치해야 한다.
    private func lineRowText(_ line: SharePreviewLineModel) -> Text {
        let todoPrefix = line.isTodo ? "\(R.String.calendarEventTimeTodo) " : ""
        let timePrefix = line.timeText.map { "\($0) " } ?? ""
        var text = Text("\(Constant.bullet)\(todoPrefix)\(timePrefix)\(line.name)")
        if self.state.includeTagName, let tagName = line.tagName {
            text = text + Text("\(Constant.tagSeparator)\(tagName)")
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
        return text
    }

    // MARK: - include tag name option

    private func optionView() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(self.appearance.colorSet.line.asColor)
                .frame(height: 1)

            HStack {
                Text("share_preview::option::include_tag_name".localized())
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { self.state.includeTagName },
                        set: { self.eventHandlers.toggleIncludeTagName($0) }
                    )
                )
                .labelsHidden()
            }
            .padding(spacing: .regular)
        }
    }
}

private enum Constant {
    static let bullet: String = "• "
    static let tagSeparator: String = " · "
    static let disabledCheckboxOpacity: Double = 0.4
}
