//
//  
//  SettingItemListViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes
import CommonPresentation


protocol SettingItemModelType {
    var compareKey: String { get }
}

struct SettingItemModel: SettingItemModelType {
    enum ItemId: String, Equatable {
        case appearance
        case editEvent
        case holidaySetting
        case openWeb
        case aiUsageGuide
        case feedback
        case help
        case shareApp
        case addReview
        case openSourceLicense
        case billingPlan
        case terms
        case privacyPolicy
        case adPrivacyOptions
    }
    
    let itemId: ItemId
    let iconNamge: String
    let text: String
    
    init(_ itemId: ItemId) {
        self.itemId = itemId
        switch itemId {
        case .appearance:
            self.iconNamge = "eyeglasses"
            self.text = "setting.appearance.title".localized()
        case .editEvent:
            self.iconNamge = "calendar"
            self.text = "setting.appearance.event.edit::name".localized()
        case .holidaySetting:
            self.iconNamge = "globe"
            self.text = "setting.holiday.item::name".localized()
        case .openWeb:
            self.iconNamge = "safari"
            self.text = "setting.openWeb::name".localized()
        case .aiUsageGuide:
            self.iconNamge = "sparkles"
            self.text = "setting.aiGuide::name".localized()
        case .feedback:
            self.iconNamge = "ellipsis.bubble"
            self.text = "setting.feedback::name".localized()
        case .help:
            self.iconNamge = "questionmark.circle"
            self.text = "setting.help::name".localized()
        case .shareApp:
            self.iconNamge = "square.and.arrow.up"
            self.text = "setting.share::name".localized()
        case .addReview:
            self.iconNamge = "star"
            self.text = "setting.write_review::name".localized()
        case .openSourceLicense:
            self.iconNamge = "doc.on.doc"
            self.text = "setting.openSourceLicense::name".localized()
        case .billingPlan:
            self.iconNamge = "creditcard"
            self.text = "setting.billing.plan::name".localized()
        case .terms:
            self.iconNamge = "doc.text"
            self.text = "setting.terms::name".localized()
        case .privacyPolicy:
            self.iconNamge = "hand.raised"
            self.text = "setting.privacyPolicy::name".localized()
        case .adPrivacyOptions:
            self.iconNamge = "checkmark.shield"
            self.text = "setting.adPrivacyOptions::name".localized()
        }
    }
    
    var compareKey: String { self.itemId.rawValue }
}

struct AccountSettingItemModel: SettingItemModelType {
    var compareKey: String {
        return "AccountSettingItemModel"
    }
    let signInMethod: String?
    let isSignIn: Bool
    var iconName: String {
        return self.isSignIn ? "person.crop.circle" : "person.crop.circle.badge.plus"
    }
    var title: String {
        return self.isSignIn
            ? "setting.account.signedIn::manageAccount".localized()
            : "setting.account.needSignIn".localized()
    }
    
    init(_ accountInfo: AccountInfo?) {
        self.isSignIn = accountInfo != nil
        self.signInMethod = accountInfo?.signInMethod
    }
}

struct SuggestAppItemModel: SettingItemModelType {
    
    let imagePath: String
    let name: String
    var description: String?
    let sourcePath: String
    
    var compareKey: String { self.sourcePath }
    
    static func readmind() -> SuggestAppItemModel {
        return SuggestAppItemModel(
            imagePath: "https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/c8/77/ec/c877ec10-f7bb-2762-f512-0fa769ff6d6f/AppIcon-1x_U007emarketing-0-10-0-85-220.png/230x0w.webp",
            name: "setting.suggest::readmind::appName".localized(),
            description: "setting.suggest::readmind::message".localized(),
            sourcePath: "http://itunes.apple.com/app/id/id1565634642"
        )
    }
}


protocol SettingSectionModelType {
    var headerText: String? { get }
    var items: [any SettingItemModelType] { get }
}
struct SettingSectionModel: SettingSectionModelType {
    
    let headerText: String?
    let items: [any SettingItemModelType]
    
    init(headerText: String?, items: [any SettingItemModelType]) {
        self.headerText = headerText
        self.items = items
    }
}

struct AppInfoSectionModel: SettingSectionModelType {
    let headerText: String?
    var version: String?
    var isUpdateAvailable: Bool = false
    let items: [any SettingItemModelType]
}


// MARK: - SettingItemListViewModel

protocol SettingItemListViewModel: AnyObject, Sendable, SettingItemListSceneInteractor {

    // interactor
    func prepare()
    func selectItem(_ model: any SettingItemModelType)
    func openAppUpdate()
    func close()

    // presenter
    var sectionModels: AnyPublisher<[any SettingSectionModelType], Never> { get }
}


// MARK: - SettingItemListViewModelImple

final class SettingItemListViewModelImple: SettingItemListViewModel, @unchecked Sendable {

    private let appstoreLinkPath: String
    private let accountUsecase: any AccountUsecase
    private let uiSettingUsecase: any UISettingUsecase
    private let deviceInfoFetchService: any DeviceInfoFetchService
    private let appUpdateCheckUsecase: any AppUpdateCheckUsecase
    private let privacyOptionsFormRouter: (any PrivacyOptionsFormRouter)?
    var router: (any SettingItemListRouting)?

    init(
        appstoreLinkPath: String,
        accountUsecase: any AccountUsecase,
        uiSettingUsecase: any UISettingUsecase,
        deviceInfoFetchService: any DeviceInfoFetchService,
        appUpdateCheckUsecase: any AppUpdateCheckUsecase,
        privacyOptionsFormRouter: (any PrivacyOptionsFormRouter)?
    ) {
        self.appstoreLinkPath = appstoreLinkPath
        self.accountUsecase = accountUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.deviceInfoFetchService = deviceInfoFetchService
        self.appUpdateCheckUsecase = appUpdateCheckUsecase
        self.privacyOptionsFormRouter = privacyOptionsFormRouter

        self.bindIsSignedIn()
    }

    private func bindIsSignedIn() {
        self.accountUsecase.currentAccountInfo
            .map { $0 != nil }
            .sink(receiveValue: { [weak self] isSignedIn in
                self?.subject.isSignedIn.send(isSignedIn)
            })
            .store(in: self.cancellables)
    }
    
    
    private struct Subject {
        let deviceInfo = CurrentValueSubject<DeviceInfo?, Never>(nil)
        let isAdPrivacyOptionsRequired = CurrentValueSubject<Bool, Never>(false)
        let isSignedIn = CurrentValueSubject<Bool, Never>(false)
    }
    
    private let cancellables = CancelBag()
    private let subject = Subject()
}


// MARK: - SettingItemListViewModelImple Interactor

extension SettingItemListViewModelImple {
    
    func prepare() {
        self.prepareDeviceInfo()
        self.prepareAdPrivacyOptionsRequirement()
    }
    
    private func prepareDeviceInfo() {
        Task { [weak self] in
            let info = await self?.deviceInfoFetchService.fetchDeviceInfo()
            self?.subject.deviceInfo.send(info)
        }
        .store(in: self.cancellables)
    }
    
    private func prepareAdPrivacyOptionsRequirement() {
        Task { @MainActor [weak self] in
            let isRequired = self?.privacyOptionsFormRouter?.isPrivacyOptionsRequired()
            self?.subject.isAdPrivacyOptionsRequired.send(isRequired ?? false)
        }
        .store(in: self.cancellables)
    }
    
    func selectItem(_ model: any SettingItemModelType) {
        switch model {
        case let settingItem as SettingItemModel:
            self.handleSettingItemSelected(settingItem)
        case let account as AccountSettingItemModel:
            self.handleSignIn(account)
        case let suggest as SuggestAppItemModel:
            self.router?.openSafari(suggest.sourcePath)
        default: break
        }
    }
    
    func openAppUpdate() {
        self.router?.openSafari(self.appstoreLinkPath)
    }

    func close() {
        self.router?.closeScene()
    }
    
    private func handleSettingItemSelected(_ model: SettingItemModel) {
        switch model.itemId {
        case .appearance:
            self.routeApearanceSetting()
            
        case .editEvent:
            self.router?.routeToEventSetting()
            
        case .holidaySetting:
            self.router?.routeToHolidaySetting()

        case .openWeb:
            self.router?.openSafari(WebAppLink.homePath)

        case .aiUsageGuide:
            self.router?.showWebView(GuideLink.aiInputPath)

        case .feedback:
            self.router?.routeToFeedbackPost()
            
        case .help:
            self.router?.showWebView(GuideLink.indexPath)
            
        case .shareApp:
            self.router?.openShare(link: self.appstoreLinkPath)
            
        case .addReview:
            self.router?.openSafari(self.appstoreLinkPath)
            
        case .openSourceLicense:
            self.router?.routeToOpenSourceLicense()

        case .billingPlan:
            self.handleBillingPlanSelected()

        case .terms:
            self.router?.showWebView(LegalLink.termsPath)

        case .privacyPolicy:
            self.router?.showWebView(LegalLink.privacyPolicyPath)

        case .adPrivacyOptions:
            self.router?.routeToAdPrivacyOptions()
        }
    }
    
    private func handleBillingPlanSelected() {
        if self.subject.isSignedIn.value {
            self.router?.routeToPaywall()
        } else {
            let info = ConfirmDialogInfo()
                |> \.title .~ "billing::needSignIn::title".localized()
                |> \.message .~ "billing::needSignIn::message".localized()
                |> \.confirmed .~ { [weak self] in self?.router?.routeToSignIn() }
            self.router?.showConfirm(dialog: info)
        }
    }

    private func handleSignIn(_ item: AccountSettingItemModel) {
        if item.isSignIn {
            self.router?.routeToAccountManage()
        } else {
            self.router?.routeToSignIn()
        }
    }
    
    private func routeApearanceSetting() {
        
        let setting = self.uiSettingUsecase.loadSavedAppearanceSetting()
        self.router?.routeToAppearanceSetting(inital: setting.calendar)
    }
}


// MARK: - SettingItemListViewModelImple Presenter

extension SettingItemListViewModelImple {
    
    var sectionModels: AnyPublisher<[any SettingSectionModelType], Never> {

        let transform: (AccountInfo?, DeviceInfo?, Bool, Bool) -> [any SettingSectionModelType] = { account, device, isUpdateAvailable, isAdPrivacyOptionsRequired in
            let baseSectionItems: [SettingItemModel] = [
                .init(.appearance),
                .init(.editEvent),
                .init(.holidaySetting),
                .init(.billingPlan)
            ]
            let accountItem = AccountSettingItemModel(account)
            let baseSection = SettingSectionModel(
                headerText: nil,
                items: baseSectionItems + [accountItem]
            )

            let supportSectionItems: [SettingItemModel] = [
                .init(.openWeb),
                .init(.aiUsageGuide),
                .init(.feedback),
                .init(.help)
            ]
            let supportSection = SettingSectionModel(headerText: "setting.section.support::name".localized(), items: supportSectionItems)

            let appInfoSectionItems: [SettingItemModel] = [
                .init(.shareApp),
                .init(.addReview),
                .init(.openSourceLicense),
                .init(.terms),
                .init(.privacyPolicy)
            ] + (isAdPrivacyOptionsRequired ? [.init(.adPrivacyOptions)] : [])
            let appInfoSection = AppInfoSectionModel(
                headerText: "setting.section.app::name".localized(),
                version: device?.appVersion.map { "v\($0)"},
                isUpdateAvailable: isUpdateAvailable,
                items: appInfoSectionItems
            )

            let suggestItem = SuggestAppItemModel.readmind()
            let suggestSection = SettingSectionModel(headerText: "setting.section.suggest::name".localized(), items: [suggestItem])

            let sections: [any SettingSectionModelType] = [
                baseSection, supportSection, appInfoSection, suggestSection
            ]
            return sections
        }

        return Publishers
            .CombineLatest4(
                self.accountUsecase.currentAccountInfo,
                self.subject.deviceInfo,
                self.appUpdateCheckUsecase.isUpdateAvailable,
                self.subject.isAdPrivacyOptionsRequired
            )
            .map(transform)
            .eraseToAnyPublisher()
    }
}
