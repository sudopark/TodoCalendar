//
//  LandmarkMapView.swift
//  CommonPresentation
//
//  Created by sudo.park on 11/14/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import SwiftUI
import MapKit
import Domain


public struct LandmarkMapView: View {
    
    private let name: String
    private let coordinate: CLLocationCoordinate2D
    
    @State private var cameraPosition: MapCameraPosition
    
    public init(
        name: String,
        coordinate: Place.Coordinate,
        span: (Double, Double) = (0.005, 0.005)
    ) {
        self.name = name
        let coordinate = CLLocationCoordinate2D(
            latitude: coordinate.latttude, longitude: coordinate.longitude
        )
        self.coordinate = coordinate
        let region = MKCoordinateRegion(
            center: coordinate,
            span: .init(latitudeDelta: span.0, longitudeDelta: span.1)
        )
        _cameraPosition = State(initialValue: .region(region))
    }
    
    public var body: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            
            Marker(name, systemImage: "mappin", coordinate: coordinate)
                
        }
        .mapStyle(.standard)
    }
}

#Preview {
    LandmarkMapView(
        name: "경북궁",
        coordinate: .init(37.579871, 126.977051)
    )
    .frame(height: 200)
}
