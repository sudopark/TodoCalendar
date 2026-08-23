//
//  LegalNoticeBannerView.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Combine
import Domain
import Extensions
import CommonPresentation


// MARK: - LegalNoticeBannerRowView

final class LegalNoticeBannerRowView: UIView {

    private enum Constant {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10
        static let iconSize: CGFloat = 18
        static let closeButtonSize: CGFloat = 24
    }

    private let contentStackView = UIStackView()
    private let iconImageView = UIImageView()
    private let textStackView = UIStackView()
    private let messageLabel = UILabel()
    private let effectiveDateLabel = UILabel()
    private let closeButton = UIButton()

    private let tapSubject = PassthroughSubject<Void, Never>()
    private let closeSubject = PassthroughSubject<Void, Never>()
    private let cancellables = CancelBag()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupLayout()
        self.bind()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


// MARK: - bind

extension LegalNoticeBannerRowView {

    var tapped: AnyPublisher<Void, Never> {
        return self.tapSubject.eraseToAnyPublisher()
    }

    var closeTapped: AnyPublisher<Void, Never> {
        return self.closeSubject.eraseToAnyPublisher()
    }

    private func bind() {
        let rowTapPublisher = self.addTapGestureRecognizerPublisher()
        self.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer })?.delegate = self

        rowTapPublisher
            .sink(receiveValue: { [weak self] in self?.tapSubject.send(()) })
            .store(in: self.cancellables)

        self.closeButton.addTapGestureRecognizerPublisher()
            .sink(receiveValue: { [weak self] in self?.closeSubject.send(()) })
            .store(in: self.cancellables)
    }
}


extension LegalNoticeBannerRowView: UIGestureRecognizerDelegate {

    // 본체 탭 제스처가 closeButton 위 터치까지 받으면 두 액션이 동시에 발화한다
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
        return touch.view !== self.closeButton
    }
}


// MARK: - update

extension LegalNoticeBannerRowView {

    func update(_ model: LegalNoticeBannerModel) {
        self.messageLabel.text = model.message
        self.effectiveDateLabel.text = model.effectiveDateText
    }

    func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.iconImageView.tintColor = colorSet.accentInfo
        self.messageLabel.font = fontSet.normal
        self.messageLabel.textColor = colorSet.text0
        self.effectiveDateLabel.font = fontSet.subNormal
        self.effectiveDateLabel.textColor = colorSet.text2
        self.closeButton.tintColor = colorSet.text2
    }
}


// MARK: - layout

extension LegalNoticeBannerRowView {

    private func setupLayout() {

        self.addSubview(contentStackView)
        contentStackView.autoLayout.active(with: self) {
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor, constant: Constant.horizontalPadding)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor, constant: -Constant.horizontalPadding)
            $0.topAnchor.constraint(equalTo: $1.topAnchor, constant: Constant.verticalPadding)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor, constant: -Constant.verticalPadding)
        }
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = 8

        contentStackView.addArrangedSubview(iconImageView)
        iconImageView.autoLayout.active {
            $0.widthAnchor.constraint(equalToConstant: Constant.iconSize)
            $0.heightAnchor.constraint(equalToConstant: Constant.iconSize)
        }
        iconImageView.image = UIImage(systemName: "doc.text")
        iconImageView.contentMode = .scaleAspectFit

        contentStackView.addArrangedSubview(textStackView)
        textStackView.axis = .vertical
        textStackView.spacing = 2
        textStackView.addArrangedSubview(messageLabel)
        textStackView.addArrangedSubview(effectiveDateLabel)
        messageLabel.numberOfLines = 0

        contentStackView.addArrangedSubview(closeButton)
        closeButton.autoLayout.active {
            $0.widthAnchor.constraint(equalToConstant: Constant.closeButtonSize)
            $0.heightAnchor.constraint(equalToConstant: Constant.closeButtonSize)
        }
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
    }
}


// MARK: - LegalNoticeBannerView

final class LegalNoticeBannerView: UIView {

    private let stackView = UIStackView()
    private var rows: [LegalNoticeBannerRowView] = []
    private var separators: [UIView] = []
    private let cancellables = CancelBag()
    private var currentFontSet: (any FontSet)?
    private var currentColorSet: (any ColorSet)?

    private let documentTappedSubject = PassthroughSubject<LegalDocumentType, Never>()
    private let closeTappedSubject = PassthroughSubject<LegalDocumentType, Never>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


// MARK: - update

extension LegalNoticeBannerView {

    var documentTapped: AnyPublisher<LegalDocumentType, Never> {
        return self.documentTappedSubject.eraseToAnyPublisher()
    }

    var closeTapped: AnyPublisher<LegalDocumentType, Never> {
        return self.closeTappedSubject.eraseToAnyPublisher()
    }

    func update(_ models: [LegalNoticeBannerModel]) {
        self.stackView.arrangedSubviews.forEach {
            self.stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        self.cancellables.cancelAll()
        self.separators = []

        self.rows = models.map { model -> LegalNoticeBannerRowView in
            let row = LegalNoticeBannerRowView()
            row.update(model)
            self.applyStyleIfNeeded(to: row)
            self.bind(row, documentType: model.documentType)
            return row
        }

        self.rows.enumerated().forEach { index, row in
            if index > 0 {
                let separator = self.makeSeparatorView()
                self.separators.append(separator)
                self.stackView.addArrangedSubview(separator)
            }
            self.stackView.addArrangedSubview(row)
        }

        self.isHidden = models.isEmpty
    }

    private func bind(_ row: LegalNoticeBannerRowView, documentType: LegalDocumentType) {
        row.tapped
            .sink(receiveValue: { [weak self] in self?.documentTappedSubject.send(documentType) })
            .store(in: self.cancellables)
        row.closeTapped
            .sink(receiveValue: { [weak self] in self?.closeTappedSubject.send(documentType) })
            .store(in: self.cancellables)
    }

    private func applyStyleIfNeeded(to row: LegalNoticeBannerRowView) {
        guard let fontSet = self.currentFontSet, let colorSet = self.currentColorSet else { return }
        row.setupStyling(fontSet, colorSet)
    }

    private func makeSeparatorView() -> UIView {
        let separator = UIView()
        separator.autoLayout.active {
            $0.heightAnchor.constraint(equalToConstant: 1)
        }
        separator.backgroundColor = self.currentColorSet?.line
        return separator
    }

    func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.currentFontSet = fontSet
        self.currentColorSet = colorSet
        self.backgroundColor = colorSet.bg1
        self.rows.forEach { $0.setupStyling(fontSet, colorSet) }
        self.separators.forEach { $0.backgroundColor = colorSet.line }
    }
}


// MARK: - layout

extension LegalNoticeBannerView {

    private func setupLayout() {

        self.addSubview(stackView)
        stackView.autoLayout.active(with: self) {
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.topAnchor.constraint(equalTo: $1.topAnchor)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor)
        }
        stackView.axis = .vertical
        stackView.spacing = 0
    }
}
