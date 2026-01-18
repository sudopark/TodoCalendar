//
//  UserLocationMonitoringUsecase.swift
//  Domain
//
//  Created by sudo.park on 1/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CoreLocation


public enum UserLocationMonitoringAuthorizationStatus {
    case serviceDisabled
    case notDetermine
    case deny
    case restricted
    case grant
    case unknown
}

public protocol UserLocationMonitoringUsecase {
    
    func requestAuthorization()
    func start()
    func stop()
    
    func currentAuthorizationStatus() -> UserLocationMonitoringAuthorizationStatus
    var location: AnyPublisher<any UserLocation, Never> { get }
    func currentLocation() async throws -> (any UserLocation)?
}

extension CLLocation: UserLocation {
    
    public var latitude: Double { self.coordinate.latitude }
    public var longitude: Double { self.coordinate.longitude }
}



// MARK: - UserLocationMonitoringUsecaseImple

public final class UserLocationMonitoringUsecaseImple: NSObject, UserLocationMonitoringUsecase, @unchecked Sendable {
    
    private let locationManager: CLLocationManager
    
    public override init() {
        self.locationManager = CLLocationManager()
        super.init()
        
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.delegate = self
    }
    
    private struct Subject {
        let lastLocation = CurrentValueSubject<(any UserLocation)?, Never>(nil)
        let isMonitoringRequested = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()
}

extension UserLocationMonitoringUsecaseImple {
    
    public func requestAuthorization() {
        self.locationManager.requestWhenInUseAuthorization()
    }
    
    public func currentAuthorizationStatus() -> UserLocationMonitoringAuthorizationStatus {
        
        guard CLLocationManager.locationServicesEnabled()
        else {
            return .serviceDisabled
        }
        
        let status: UserLocationMonitoringAuthorizationStatus = switch self.locationManager.authorizationStatus {
        case .notDetermined: .notDetermine
        case .restricted: .restricted
        case .denied: .deny
        case .authorizedAlways: .grant
        case .authorizedWhenInUse: .grant
        case .authorized: .grant
        @unknown default: .unknown
        }
       
        return status
    }
    
}

extension UserLocationMonitoringUsecaseImple: CLLocationManagerDelegate {
    
    public func start() {
        self.subject.isMonitoringRequested.send(true)
        self.startMonitoringIfPossible()
    }
    
    public func stop() {
        self.subject.isMonitoringRequested.send(false)
        self.locationManager.stopUpdatingLocation()
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.startMonitoringIfPossible()
    }
    
    private func startMonitoringIfPossible() {
        
        guard self.subject.isMonitoringRequested.value else { return }
        
        guard CLLocationManager.locationServicesEnabled()
        else {
            self.locationManager.stopUpdatingLocation()
            return
        }
        
        switch self.locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            self.locationManager.startUpdatingLocation()
            
        default: break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.subject.lastLocation.send(location)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        
    }
}


extension UserLocationMonitoringUsecaseImple {
    
    public func currentLocation() async throws -> (any UserLocation)? {
        return self.subject.lastLocation.value
    }
    
    public var location: AnyPublisher<any UserLocation, Never> {
        return self.subject.lastLocation
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
