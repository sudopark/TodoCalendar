//
//  PlaceSuggestUsecase.swift
//  Domain
//
//  Created by sudo.park on 11/11/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import MapKit
import CoreLocation
import Contacts
import Combine
import CombineExt
import Prelude
import Optics
import Extensions
import AsyncFlatMap


// MARK: - PlaceSuggestEngine

public protocol PlaceSuggestEngine: AnyObject {
    
    func prepare()
    func suggest(query: String) -> AnyPublisher<[Place], any Error>
}


private struct SubscriberHolder<Output, Failure: Error>: @unchecked Sendable {
    let subscriber: Publishers.Create<Output, Failure>.Subscriber
}

public final class MapKitBasePlaceSuggestEngineImple: PlaceSuggestEngine,  @unchecked Sendable {
    
    private var currentRegionCapitalLocation: CLLocationCoordinate2D?
    
    public init() {}
    
    public func prepare() {
        guard let regionCode = Locale.current.region?.identifier,
              let countryName = Locale.current.localizedString(forRegionCode: regionCode)
        else { return }
        
        let geocoder = CLGeocoder()
        let searchString = "\(countryName) capital"
        geocoder.geocodeAddressString(searchString) { placemarks, error in
            guard let location = placemarks?.first?.location else { return }
            self.currentRegionCapitalLocation = location.coordinate
        }
    }
    
    public func suggest(query: String) -> AnyPublisher<[Place], any Error> {

        return Publishers.Create { [weak self] subscriber in
            let holder = SubscriberHolder(subscriber: subscriber)
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

            if let capitalLocation = self?.currentRegionCapitalLocation {
                request.region = .init(
                    center: capitalLocation,
                    span: .init(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                guard let response
                else {
                    let error = error ?? RuntimeError("failed")
                    holder.subscriber.send(completion: .failure(error))
                    return
                }
                
                let places = response.mapItems.compactMap { $0.asPlace() }
                
                holder.subscriber.send(places)
                holder.subscriber.send(completion: .finished)
            }
            
            return AnyCancellable { }
        }
        .eraseToAnyPublisher()
    }
}

private extension MKMapItem {
    
    func asPlace() -> Place? {
        guard let name = self.name else { return nil }
        let place = Place(name)
        if #available(iOS 26.0, *) {
            let location = Place.Coordinate(
                self.location.coordinate.latitude, self.location.coordinate.longitude
            )
            let addr = self.address?.fullAddress
            return place
                |> \.coordinate .~ location
                |> \.addressText .~ addr
            
        } else {
            let location = self.placemark.location
                .map {
                    Place.Coordinate($0.coordinate.latitude, $0.coordinate.longitude)
                }
            let addr = self.placemark.postalAddress
                .map {
                    CNPostalAddressFormatter.string(from: $0, style: .mailingAddress)
                }?
                .replacingOccurrences(of: "\n", with: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return place
                |> \.coordinate .~ location
                |> \.addressText .~ addr
        }
    }
}


// MARK: - PlaceSuggestUsecase

public protocol PlaceSuggestUsecase: AnyObject, Sendable {
    
    func prepare()
    func starSuggest(_ query: String)
    func stopSuggest()
    
    var suggestPlaces: AnyPublisher<[Place], Never> { get }
}

public final class PlaceSuggestUsecaseImple: PlaceSuggestUsecase, @unchecked Sendable {
    
    private let suggestEngine: any PlaceSuggestEngine
    private let throttleTime: RunLoop.SchedulerTimeType.Stride
    public init(
        suggestEngine: any PlaceSuggestEngine,
        throttleTime: RunLoop.SchedulerTimeType.Stride = .milliseconds(1200)
    ) {
        self.suggestEngine = suggestEngine
        self.throttleTime = throttleTime
        self.bindSuggest()
    }
    
    private struct Subject {
        let query = CurrentValueSubject<String?, Never>(nil)
        let places = CurrentValueSubject<[Place], Never>([])
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}

extension PlaceSuggestUsecaseImple {
    
    public func prepare() {
        self.suggestEngine.prepare()
    }
    
    public func starSuggest(_ query: String) {
        self.subject.query.send(query)
    }
    
    public func stopSuggest() {
        self.subject.query.send(nil)
    }
    
    private func bindSuggest() {
        
        let suggestOrNot: (String?) -> AnyPublisher<[Place], Never>? = { [weak self] query in
            guard let self else { return nil }
            guard let query else {
                return Just([]).eraseToAnyPublisher()
            }
            return self.suggestEngine.suggest(query: query)
                .ignoreError()
        }
        
        self.subject.query
            .throttle(for: self.throttleTime, scheduler: RunLoop.main, latest: true)
            .compactMap(suggestOrNot)
            .switchToLatest()
            .sink(receiveValue: { [weak self] places in
                self?.subject.places.send(places)
            })
            .store(in: &self.cancellables)
    }
}

extension PlaceSuggestUsecaseImple {
    
    public var suggestPlaces: AnyPublisher<[Place], Never> {
        return self.subject.places
            .eraseToAnyPublisher()
    }
}
