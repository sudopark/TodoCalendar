//
//  ContinuousMonthsViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation


private enum Constant {
    static let focusedSectionIndex: Int = 2
    static let snapProgressThreshold: CGFloat = 0.5
    static let horizontalInset: CGFloat = Metric.Spacing.small
    static let anchorTolerance: CGFloat = 0.5
}


final class ContinuousMonthsViewController: UIViewController, UICollectionViewDelegate {

    private let viewModel: any ContinuousMonthsViewModel
    let viewAppearance: ViewAppearance
    private let viewState = ContinuousMonthsViewState()
    private let eventHandler = ContinuousMonthsViewEventHandler()
    private let cancellables = CancelBag()

    private let collectionView: LayoutObservingCollectionView
    private var dataSource: UICollectionViewDiffableDataSource<CalendarMonth, WeekItem>?
    private var sections: [ContinuousMonthSection] = []
    private var pendingSections: [ContinuousMonthSection]?
    private var focusIndex: Int = Constant.focusedSectionIndex
    private var isUserScrolling = false
    private var isExternalScrolling = false
    private var lastLayoutWidth: CGFloat = 0

    init(viewModel: any ContinuousMonthsViewModel, viewAppearance: ViewAppearance) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        self.collectionView = LayoutObservingCollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(
            estimatedRowHeight: viewAppearance.rowHeightOnCalendar.cgValue,
            horizontalInset: Constant.horizontalInset
        ))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupLayout()
        self.viewState.bind(self.viewModel)
        self.eventHandler.bind(self.viewModel)
        self.bind()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = self.collectionView.bounds.width
        guard width > 0, width != self.lastLayoutWidth else { return }
        self.lastLayoutWidth = width
        self.viewState.rowWidth = width - Constant.horizontalInset * 2
    }

    private func bind() {
        self.viewModel.sections
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] sections in
                self?.receive(sections)
            })
            .store(in: self.cancellables)
    }
}


// MARK: - layout

extension ContinuousMonthsViewController {

    private func setupLayout() {
        let header = UIHostingController(
            rootView: ContinuousMonthsHeaderView()
                .environment(self.viewState)
                .environment(self.viewAppearance)
        )
        header.sizingOptions = .intrinsicContentSize
        self.addChild(header)
        self.view.addSubview(header.view)
        header.didMove(toParent: self)

        let background = UIHostingConfiguration {
            ContinuousMonthsBackgroundView().environment(self.viewAppearance)
        }
        .margins(.all, 0)
        self.collectionView.backgroundView = background.makeContentView()
        self.collectionView.backgroundColor = .clear
        self.dataSource = self.makeDataSource()
        self.collectionView.delegate = self
        self.collectionView.didLayout = { [weak self] in
            self?.keepFocusedSectionAtTop()
        }
        self.collectionView.decelerationRate = .fast
        self.collectionView.contentInsetAdjustmentBehavior = .never
        self.collectionView.showsVerticalScrollIndicator = false
        self.view.addSubview(self.collectionView)

        header.view.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            header.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            header.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.collectionView.topAnchor.constraint(equalTo: header.view.bottomAnchor),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
}


private final class LayoutObservingCollectionView: UICollectionView {

    var didLayout: () -> Void = { }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.didLayout()
    }
}

private extension UICollectionViewCompositionalLayout {

    convenience init(estimatedRowHeight: CGFloat, horizontalInset inset: CGFloat) {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(estimatedRowHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: inset, bottom: 0, trailing: inset)
        self.init(section: section)
    }
}


// MARK: - sections

extension ContinuousMonthsViewController {

    private var isScrolling: Bool {
        return self.isUserScrolling || self.isExternalScrolling
            || self.collectionView.isTracking || self.collectionView.isDragging || self.collectionView.isDecelerating
    }

    private func receive(_ newSections: [ContinuousMonthSection]) {
        guard !self.sections.isEmpty else {
            self.apply(newSections)
            return
        }
        guard !self.isScrolling else {
            self.pendingSections = newSections
            return
        }
        let newFocusedMonth = newSections[safe: Constant.focusedSectionIndex]?.month
        guard let indexInBuffer = self.sections.firstIndex(where: { $0.month == newFocusedMonth }),
              indexInBuffer != self.focusIndex
        else {
            self.apply(newSections)
            return
        }
        self.pendingSections = newSections
        self.isExternalScrolling = true
        self.focusIndex = indexInBuffer
        self.collectionView.setContentOffset(CGPoint(x: 0, y: self.anchor(indexInBuffer)), animated: true)
    }

    private func apply(_ newSections: [ContinuousMonthSection]) {
        self.sections = newSections
        self.pendingSections = nil
        self.focusIndex = Constant.focusedSectionIndex
        UIView.performWithoutAnimation {
            self.dataSource?.apply(newSections.snapshot(), animatingDifferences: false)
            self.collectionView.layoutIfNeeded()
        }
    }

    // 셀 높이는 SwiftUI 가 재고 이벤트가 늦게 와도 바뀌어서, 멈춰 있는 동안은 레이아웃마다 포커스 섹션을 맨 위에 다시 붙인다
    private func keepFocusedSectionAtTop() {
        guard !self.sections.isEmpty, !self.isScrolling else { return }
        let top = self.anchor(self.focusIndex)
        guard abs(self.collectionView.contentOffset.y - top) > Constant.anchorTolerance else { return }
        self.collectionView.setContentOffset(CGPoint(x: 0, y: top), animated: false)
    }

    private func anchor(_ sectionIndex: Int) -> CGFloat {
        let indexPath = IndexPath(item: 0, section: sectionIndex)
        return self.collectionView.layoutAttributesForItem(at: indexPath)?.frame.minY ?? 0
    }
}


// MARK: - data source

extension ContinuousMonthsViewController {

    private func makeDataSource() -> UICollectionViewDiffableDataSource<CalendarMonth, WeekItem> {
        let registration = UICollectionView.CellRegistration<UICollectionViewCell, WeekItem> { [weak self] cell, _, item in
            guard let self else { return }
            cell.contentConfiguration = UIHostingConfiguration {
                ContinuousMonthsWeekCellView(week: item.week)
                    .environment(self.viewState)
                    .environment(self.eventHandler)
                    .environment(self.viewAppearance)
            }
            .margins(.all, 0)
        }
        return UICollectionViewDiffableDataSource(collectionView: self.collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }
}

private struct WeekItem: Hashable {
    let week: WeekRowModel

    static func == (lhs: WeekItem, rhs: WeekItem) -> Bool {
        return lhs.week == rhs.week
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.week.id)
    }
}

private extension Array where Element == ContinuousMonthSection {

    func snapshot() -> NSDiffableDataSourceSnapshot<CalendarMonth, WeekItem> {
        var snapshot = NSDiffableDataSourceSnapshot<CalendarMonth, WeekItem>()
        snapshot.appendSections(self.map { $0.month })
        self.forEach { section in
            snapshot.appendItems(section.weeks.map { WeekItem(week: $0) }, toSection: section.month)
        }
        return snapshot
    }
}


// MARK: - snap

extension ContinuousMonthsViewController {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.isUserScrolling = true
        self.isExternalScrolling = false
    }

    // 시스템이 넘긴 목표 오프셋은 손 뗀 위치에 관성 거리를 더한 값이라, 끌어간 거리와 속도를 함께 담는다
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        self.focusIndex = self.snappedSectionIndex(projectedOffset: targetContentOffset.pointee.y)
        targetContentOffset.pointee.y = self.anchor(self.focusIndex)
    }

    private func snappedSectionIndex(projectedOffset: CGFloat) -> Int {
        let current = self.anchor(self.focusIndex)
        let moved = projectedOffset - current
        let neighbor = moved > 0 ? self.focusIndex + 1 : self.focusIndex - 1
        guard self.sections.indices.contains(neighbor) else { return self.focusIndex }
        let distanceToNeighbor = abs(self.anchor(neighbor) - current)
        return abs(moved) >= distanceToNeighbor * Constant.snapProgressThreshold ? neighbor : self.focusIndex
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        self.settle()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.settle()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.settle()
    }

    private func settle() {
        let wasExternalScrolling = self.isExternalScrolling
        self.isExternalScrolling = false
        self.isUserScrolling = false

        if wasExternalScrolling {
            self.applyPendingSectionsIfNeeded()
        } else if self.focusIndex != Constant.focusedSectionIndex,
                  let month = self.sections[safe: self.focusIndex]?.month {
            self.settleUserScroll(on: month)
        } else {
            self.applyPendingSectionsIfNeeded()
        }
    }

    // VM 포커스가 이미 이 달이면 버퍼를 다시 내지 않는다
    private func settleUserScroll(on month: CalendarMonth) {
        let pending = self.pendingSections
        self.pendingSections = nil
        if let pending, pending[safe: Constant.focusedSectionIndex]?.month == month {
            self.apply(pending)
        }
        self.viewModel.scrolled(to: month)
    }

    private func applyPendingSectionsIfNeeded() {
        guard let pending = self.pendingSections else { return }
        self.apply(pending)
    }
}
