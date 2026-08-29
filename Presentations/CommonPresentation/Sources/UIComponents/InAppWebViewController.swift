//
//  InAppWebViewController.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import WebKit
import Extensions


// MARK: - InAppWebViewController

public final class InAppWebViewController: UIViewController {

    private enum Constant {
        static let progressHeight: CGFloat = 2
    }

    private let url: URL
    private let appearance: ViewAppearance

    private let webView = WKWebView()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let toolBar = UIToolbar()
    private let errorView: WebViewErrorView

    private lazy var goBackButton = UIBarButtonItem(
        image: UIImage(systemName: "chevron.backward"),
        style: .plain, target: self, action: #selector(self.goBack)
    )
    private lazy var goForwardButton = UIBarButtonItem(
        image: UIImage(systemName: "chevron.forward"),
        style: .plain, target: self, action: #selector(self.goForward)
    )
    private lazy var openInBrowserButton = UIBarButtonItem(
        image: UIImage(systemName: "safari"),
        style: .plain, target: self, action: #selector(self.openInBrowser)
    )

    private var observations: [NSKeyValueObservation] = []
    private var lastFailedURL: URL?

    public init(url: URL, appearance: ViewAppearance) {
        self.url = url
        self.appearance = appearance
        self.errorView = WebViewErrorView(appearance: appearance)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.setupLayout()
        self.setupStyling()
        self.bindErrorViewActions()
        self.bindWebViewStates()

        self.webView.navigationDelegate = self
        self.loadPage(self.url)
    }
}


// MARK: - actions

extension InAppWebViewController {

    /// 로드 실패 시 webView.url 은 직전 성공 페이지로 남아 실패한 URL 을 잃는다.
    private var targetURL: URL {
        return self.lastFailedURL ?? self.webView.url ?? self.url
    }

    private func loadPage(_ url: URL) {
        self.errorView.isHidden = true
        self.webView.load(URLRequest(url: url))
    }

    @objc private func goBack() {
        self.webView.goBack()
    }

    @objc private func goForward() {
        self.webView.goForward()
    }

    @objc private func openInBrowser() {
        UIApplication.shared.open(self.targetURL)
    }
}


// MARK: - WKNavigationDelegate

extension InAppWebViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.lastFailedURL = nil
        self.errorView.isHidden = true
    }

    public func webView(
        _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error
    ) {
        self.showErrorIfNeed(error)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        self.showErrorIfNeed(error)
    }

    /// 다른 링크 이동으로 진행 중인 로드가 취소된 경우는 실패가 아니다.
    private func showErrorIfNeed(_ error: any Error) {
        let error = error as NSError
        guard error.code != NSURLErrorCancelled else { return }
        self.lastFailedURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        self.errorView.isHidden = false
    }
}


// MARK: - states

extension InAppWebViewController {

    private func bindErrorViewActions() {

        self.errorView.retry = { [weak self] in
            guard let self = self else { return }
            self.loadPage(self.targetURL)
        }
        self.errorView.openInBrowser = { [weak self] in
            self?.openInBrowser()
        }
    }

    private func bindWebViewStates() {

        self.observations = [
            self.webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                self?.navigationItem.title = webView.title
            },
            self.webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                self?.progressView.setProgress(Float(webView.estimatedProgress), animated: true)
            },
            self.webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                self?.progressView.isHidden = !webView.isLoading
            },
            self.webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                self?.goBackButton.isEnabled = webView.canGoBack
            },
            self.webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                self?.goForwardButton.isEnabled = webView.canGoForward
            }
        ]
    }
}


// MARK: - setup

extension InAppWebViewController {

    private func setupLayout() {

        self.view.addSubview(self.webView)
        self.webView.autoLayout.active(with: self.view) {
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.topAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.topAnchor)
        }

        self.view.addSubview(self.toolBar)
        self.toolBar.autoLayout.active(with: self.view) {
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.bottomAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.bottomAnchor)
            $0.topAnchor.constraint(equalTo: self.webView.bottomAnchor)
        }

        self.view.addSubview(self.progressView)
        self.progressView.autoLayout.active(with: self.view) {
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.topAnchor.constraint(equalTo: self.webView.topAnchor)
            $0.heightAnchor.constraint(equalToConstant: Constant.progressHeight)
        }

        self.view.addSubview(self.errorView)
        self.errorView.autoLayout.active(with: self.webView) {
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.topAnchor.constraint(equalTo: $1.topAnchor)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor)
        }
    }

    private func setupStyling() {

        self.view.backgroundColor = self.appearance.colorSet.bg0
        self.webView.backgroundColor = self.appearance.colorSet.bg0
        self.webView.isOpaque = false

        self.progressView.progressTintColor = self.appearance.colorSet.accent
        self.progressView.trackTintColor = .clear
        self.progressView.isHidden = true

        self.toolBar.tintColor = self.appearance.colorSet.text0
        self.toolBar.barTintColor = self.appearance.colorSet.bg0
        self.toolBar.items = [
            self.goBackButton,
            self.goForwardButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            self.openInBrowserButton
        ]

        self.errorView.isHidden = true
    }
}


// MARK: - WebViewErrorView

private final class WebViewErrorView: UIView {

    private enum Constant {
        static let contentWidth: CGFloat = 260
        static let buttonHeight: CGFloat = 44
    }

    private let appearance: ViewAppearance
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let openInBrowserButton = UIButton(type: .system)

    var retry: (() -> Void)?
    var openInBrowser: (() -> Void)?

    init(appearance: ViewAppearance) {
        self.appearance = appearance
        super.init(frame: .zero)
        self.setupLayout()
        self.setupStyling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {

        let stackView = UIStackView(
            arrangedSubviews: [self.messageLabel, self.retryButton, self.openInBrowserButton]
        )
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = Metric.Spacing.small
        stackView.setCustomSpacing(Metric.Spacing.large, after: self.messageLabel)

        self.addSubview(stackView)
        stackView.autoLayout.active(with: self) {
            $0.centerXAnchor.constraint(equalTo: $1.centerXAnchor)
            $0.centerYAnchor.constraint(equalTo: $1.centerYAnchor)
            $0.widthAnchor.constraint(equalToConstant: Constant.contentWidth)
        }

        self.retryButton.autoLayout.active {
            $0.heightAnchor.constraint(equalToConstant: Constant.buttonHeight)
        }
        self.openInBrowserButton.autoLayout.active {
            $0.heightAnchor.constraint(equalToConstant: Constant.buttonHeight)
        }
    }

    private func setupStyling() {

        self.backgroundColor = self.appearance.colorSet.bg0

        self.messageLabel.text = "webview::error::message".localized()
        self.messageLabel.textColor = self.appearance.colorSet.text1
        self.messageLabel.font = self.appearance.fontSet.normal
        self.messageLabel.textAlignment = .center
        self.messageLabel.numberOfLines = 0

        self.retryButton.setTitle("webview::error::retry".localized(), for: .normal)
        self.retryButton.setTitleColor(self.appearance.colorSet.primaryBtnText, for: .normal)
        self.retryButton.titleLabel?.font = self.appearance.fontSet.normal
        self.retryButton.backgroundColor = self.appearance.colorSet.primaryBtnBackground
        self.retryButton.layer.cornerRadius = Metric.Radius.regular
        self.retryButton.addAction(
            UIAction { [weak self] _ in self?.retry?() }, for: .touchUpInside
        )

        self.openInBrowserButton.setTitle("webview::openInBrowser".localized(), for: .normal)
        self.openInBrowserButton.setTitleColor(self.appearance.colorSet.text2, for: .normal)
        self.openInBrowserButton.titleLabel?.font = self.appearance.fontSet.subNormal
        self.openInBrowserButton.addAction(
            UIAction { [weak self] _ in self?.openInBrowser?() }, for: .touchUpInside
        )
    }
}
