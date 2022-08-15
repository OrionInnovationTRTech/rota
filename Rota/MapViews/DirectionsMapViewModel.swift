//
//  DirectionsMapViewModel.swift
//  Rota
//
//  Created by Batuhan Doğan on 11.08.2022.
//

import Foundation
import MapKit

class DirectionsMapViewModel: ObservableObject {
    @Published var placeArray: [CLPlacemark] = []
    @Published var passengerRoutePlaceArr: [MKPlacemark] = []
    @Published var passengerRoutePolylineArr: [MKPolyline] = []
    @Published var appendIt: Bool = false
    @Published var routeLineColor: UIColor = .yellow
}
