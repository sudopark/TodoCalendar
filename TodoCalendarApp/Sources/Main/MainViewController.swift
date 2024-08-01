//
//  
//  MainViewController.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import UIKit
import Combine
import Domain
import CombineCocoa
import Scenes
import CommonPresentation
import Extensions


// MARK: - MainViewController

final class MainViewController: UIViewController, MainScene {
    
    private let headerView = HeaderView()
    private let calendarContainerView = UIView()
    
    private let viewModel: any MainViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any MainSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any MainViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        super.loadView()
        self.setupLayout()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.bind()
        self.viewModel.prepare()
    }
    
    func addCalendar(_ calendarScene: any CalendarScene) {
        self.addChild(calendarScene)
        self.calendarContainerView.addSubview(calendarScene.view)
        calendarScene.view.autoLayout.active(with: self.calendarContainerView) {
            $0.topAnchor.constraint(equalTo: $1.topAnchor)
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor)
        }
        calendarScene.didMove(toParent: self)
    }
}

// MARK: - bind

extension MainViewController {
    
    private func bind() {
        
        self.viewAppearance.didUpdated
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tuple in
                self?.setupStyling(tuple.1, tuple.2)
            })
            .store(in: &self.cancellables)
        
        self.viewModel.currentMonth
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] month in
                self?.headerView.monthLabel.text = month
            })
            .store(in: &self.cancellables)
        
        self.viewModel.isShowReturnToToday
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] show in
                self?.headerView.returnTodayView.isHidden = !show
            })
            .store(in: &self.cancellables)
        
        self.viewModel.temporaryUserDataMigrationStatus
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] status in
                self?.headerView.updateMigrationStatus(status)
            })
            .store(in: &self.cancellables)
        
        self.headerView.returnTodayView.addTapGestureRecognizerPublisher()
            .sink(receiveValue: { [weak self] in
                self?.viewModel.returnToToday()
            })
            .store(in: &self.cancellables)
        
        self.headerView.migrationButton.addTapGestureRecognizerPublisher()
            .sink(receiveValue: { [weak self] in
                self?.viewModel.handleMigration()
            })
            .store(in: &self.cancellables)
        
        self.headerView.eventTypeFilterButton
            .addTapGestureRecognizerPublisher()
            .sink(receiveValue: { [weak self] in
                self?.viewModel.moveToEventTypeFilterSetting()
            })
            .store(in: &self.cancellables)
        
        self.headerView.settingButton.addTapGestureRecognizerPublisher()
            .sink { [weak self] in
                self?.viewModel.moveToSetting()
            }
            .store(in: &self.cancellables)
        
        self.headerView.logButton.addTapGestureRecognizerPublisher()
            .sink(receiveValue: { [weak self] in
                let consoleBuilder = LoggerConsoleBuilder()
                let consoleVC = consoleBuilder.makeConsoleView()
                self?.present(consoleVC, animated: true)
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - setup presenting

extension MainViewController {
    
    
    private func setupLayout() {
        
        self.view.addSubview(self.headerView)
        headerView.autoLayout.active(with: self.view) {
            $0.leadingAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.trailingAnchor)
            $0.topAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.topAnchor)
            $0.heightAnchor.constraint(equalToConstant: 44)
        }
        self.headerView.setupLayout()
        
        self.view.addSubview(calendarContainerView)
        calendarContainerView.autoLayout.active(with: self.view) {
            $0.leadingAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.trailingAnchor)
            $0.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor)
        }
    }
    
    private func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.view.backgroundColor = colorSet.dayBackground
        self.headerView.setupStyling(fontSet, colorSet)
    }
}

private final class HeaderView: UIView {
    
    private var migrationStatus: TemporaryUserDataMigrationStatus?
    private var currentColorSet: (any ColorSet)?
    
    let monthLabel = UILabel()
    let returnTodayView = UIView()
    private let returnTodayImage = UIImageView()
    private let returnTodayLabel = UILabel()
    private let buttonsStackView = UIStackView()
    let migrationButton = UIButton()
    let eventTypeFilterButton = UIButton()
    let settingButton = UIButton()
    let logButton = UIButton()
    
    func updateMigrationStatus(_ status: TemporaryUserDataMigrationStatus?) {
         self.migrationStatus = status
        switch status {
        case .migrating:
            self.migrationButton.isHidden = false
            self.migrationButton.tintColor = self.currentColorSet?.text0
            self.migrationButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath"), for: .normal)
            self.runMigrationAnimation()
            
        case .need:
            self.migrationButton.isHidden = false
            self.migrationButton.tintColor = self.currentColorSet?.accentInfo
            self.migrationButton.setImage(UIImage(systemName: "exclamationmark.triangle"), for: .normal)
            self.stopMigrationAnimation()
            
        case .none:
            self.migrationButton.isHidden = true
            self.stopMigrationAnimation()
        }
    }
    
    private func runMigrationAnimation() {
        self.stopMigrationAnimation()
        
        let rotation : CABasicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 1.5
        rotation.isCumulative = true
        rotation.repeatCount = Float.greatestFiniteMagnitude
        self.migrationButton.layer.add(rotation, forKey: "rotationAnimation")
    }
    
    private func stopMigrationAnimation() {
        self.migrationButton.layer.removeAllAnimations()
    }
    
    func setupLayout() {
        
        self.addSubview(monthLabel)
        monthLabel.autoLayout.active(with: self) {
            $0.centerYAnchor.constraint(equalTo: $1.centerYAnchor)
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor, constant: 16)
        }
        
        self.addSubview(returnTodayView)
        returnTodayView.autoLayout.active(with: self) {
            $0.centerXAnchor.constraint(equalTo: $1.centerXAnchor).setupPriority(.defaultLow)
            $0.centerYAnchor.constraint(equalTo: $1.centerYAnchor)
        }
        
        self.returnTodayView.addSubview(returnTodayImage)
        returnTodayImage.autoLayout.active {
            $0.widthAnchor.constraint(equalToConstant: 15)
            $0.heightAnchor.constraint(equalToConstant: 15)
            $0.leadingAnchor.constraint(equalTo: returnTodayView.leadingAnchor, constant: 8)
            $0.centerYAnchor.constraint(equalTo: returnTodayView.centerYAnchor)
        }
        
        self.returnTodayView.addSubview(returnTodayLabel)
        returnTodayLabel.autoLayout.active {
            $0.leadingAnchor.constraint(equalTo: returnTodayImage.trailingAnchor, constant: 4)
            $0.trailingAnchor.constraint(equalTo: returnTodayView.trailingAnchor, constant: -8)
            $0.topAnchor.constraint(equalTo: returnTodayView.topAnchor, constant: 6)
            $0.bottomAnchor.constraint(equalTo: returnTodayView.bottomAnchor, constant: -6)
        }
        
        self.returnTodayView.layer.borderWidth = 1.5
        self.returnTodayView.clipsToBounds = true
        self.returnTodayView.layer.cornerRadius = 12
        self.returnTodayLabel.text = "TODAY".localized()
        self.returnTodayView.isHidden = true
        
        self.addSubview(buttonsStackView)
        buttonsStackView.autoLayout.active {
            $0.centerYAnchor.constraint(equalTo: self.centerYAnchor)
            $0.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16)
            $0.leadingAnchor.constraint(greaterThanOrEqualTo: returnTodayView.trailingAnchor, constant: 4)
        }
        buttonsStackView.spacing = 12
        
        #if DEBUG
        buttonsStackView.addArrangedSubview(logButton)
        logButton.setTitle("Log", for: .normal)
        logButton.setTitleColor(.red, for: .normal)
        logButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        #endif
        
        buttonsStackView.addArrangedSubview(migrationButton)
        migrationButton.autoLayout.active {
            $0.widthAnchor.constraint(equalToConstant: 25)
            $0.heightAnchor.constraint(equalToConstant: 25)
        }
        migrationButton.isHidden = true
        buttonsStackView.addArrangedSubview(eventTypeFilterButton)
        eventTypeFilterButton.autoLayout.active {
            $0.widthAnchor.constraint(equalToConstant: 25)
            $0.heightAnchor.constraint(equalToConstant: 25)
        }
        buttonsStackView.addArrangedSubview(settingButton)
        settingButton.autoLayout.active {
            $0.widthAnchor.constraint(equalToConstant: 25)
            $0.heightAnchor.constraint(equalToConstant: 25)
        }
    }
    
    func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.currentColorSet = colorSet
        
        self.monthLabel.font = fontSet.bigMonth
        self.monthLabel.textColor = colorSet.text0
        
        self.returnTodayImage.tintColor = colorSet.text0
        self.returnTodayImage.image = UIImage(systemName: "arrow.uturn.right")
        
        self.returnTodayLabel.font = fontSet.subNormalWithBold
        self.returnTodayLabel.textColor = colorSet.text0
        
        self.returnTodayView.layer.borderColor = colorSet.text0.cgColor
        
        switch self.migrationStatus {
        case .migrating:
            self.migrationButton.tintColor = colorSet.text0
        case .need:
            self.migrationButton.tintColor = colorSet.accentInfo
        default: break
        }
        self.eventTypeFilterButton.tintColor = colorSet.text0
        self.eventTypeFilterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        self.settingButton.tintColor = colorSet.text0
        self.settingButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
    }
}
