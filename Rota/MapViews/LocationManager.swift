//
//  LocationManager.swift
//  MapTestProject
//
//  Created by Batuhan Doğan on 25.07.2022.
//

import SwiftUI
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject, MKMapViewDelegate, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate {
    
    @Published var mapView: MKMapView = .init()
    @Published var manager: CLLocationManager = .init()
    
    @Published var userLocation: CLLocation?
    
    @Published var pickedLocation: CLLocationCoordinate2D?
    @Published var pickedPlacemark: CLPlacemark?
    
    
    @Published var stepLocationArr: [CLLocationCoordinate2D]? = []
    @Published var stepPlacemarkArr: [CLPlacemark]? = []
    
    @Published var index: Int?
    
    @Published var request = MKLocalSearch.Request()
    @Published var request2 = MKLocalSearch.Request()
    
    
    var completer: MKLocalSearchCompleter
    @Published var searchText = ""
    @Published var cancellable: AnyCancellable?
    @Published var fetchedPlaces: [CLPlacemark]?
    @Published var fetchedPlacesAdress: [CLPlacemark]?
    @Published var completions: [MKLocalSearchCompletion] = []
    
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        
        mapView.delegate = self
        manager.delegate = self
        
        manager.requestWhenInUseAuthorization()
        
        if let userLocation = self.userLocation {
            self.mapView.region = .init(center: .init(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
        }
        
        cancellable = $searchText
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink(receiveValue: { value in
                if value != "" {
                    if let userLocation = self.userLocation {
                        self.completer.region = .init(center: .init(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
                    }
                    self.completer.resultTypes = .pointOfInterest
                    self.completer.pointOfInterestFilter = .includingAll
                    self.completer.queryFragment = value.lowercased()
                    
                    if let userLocation = self.userLocation {
                        self.request.region = .init(center: .init(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
                    }
                    self.request.naturalLanguageQuery = value.lowercased()
                    self.request.resultTypes = .pointOfInterest
                    self.request.pointOfInterestFilter = .includingAll
                    self.fetchPlaces(value: value)
                    
                    if let userLocation = self.userLocation {
                        self.request2.region = .init(center: .init(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
                    }
                    self.request2.naturalLanguageQuery = value.lowercased()
                    self.fetchPlacesAdress(value: value)
                    
                } else {
                    self.completions = []
                    self.fetchedPlaces = nil
                }
            })
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
        print("completions of completer: \(completions)")
    }
    
    func fetchPlaces(value: String) {
        Task {
            do {
                let response = try await MKLocalSearch(request: self.request).start()
                await MainActor.run(body: {
                    self.fetchedPlaces = response.mapItems.compactMap({ item -> CLPlacemark? in
                        return item.placemark
                    })
                })
            }
        }
    }
    
    func fetchPlacesAdress(value: String) {
        Task {
            do {
                let response = try await MKLocalSearch(request: self.request2).start()
                await MainActor.run(body: {
                    self.fetchedPlacesAdress = response.mapItems.compactMap({ item -> CLPlacemark? in
                        return item.placemark
                    })
                })
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        self.userLocation = currentLocation
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways: manager.requestLocation()
        case .authorizedWhenInUse: manager.requestLocation()
        case .denied: handleLocationError()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: ()
        }
    }
    
    func handleLocationError() {
        
    }
    
    func addDraggablePin(coordinate: CLLocationCoordinate2D) {
        let annotion = MKPointAnnotation()
        annotion.coordinate = coordinate
        annotion.subtitle = "Pin is draggable"
        mapView.addAnnotation(annotion)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "PIN")
        marker.isDraggable = true
        marker.canShowCallout = false
        
        return marker
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        guard let newLocation = view.annotation?.coordinate else { return }
        updatePlacemark(location: .init(latitude: newLocation.latitude, longitude: newLocation.longitude), coordinates: newLocation) {
        }
    }
    
    func updatePlacemark(location: CLLocation, coordinates: CLLocationCoordinate2D, complitionHandler: @escaping () -> Void) {
        Task {
            do {
                guard let place = try await reverseLocationCoordinates(location: location) else { return }
                await MainActor.run(body: {
                    self.pickedPlacemark = place
                    self.pickedLocation = coordinates
                    if let index = self.index, let stepLocationArr = self.stepLocationArr {
                        if stepLocationArr.count <= index {
                            self.stepPlacemarkArr?.append(place)
                            self.stepLocationArr?.append(coordinates)
                        } else {
                            self.stepPlacemarkArr?[index] = place
                            self.stepLocationArr?[index] = coordinates
                        }
                    }
                    complitionHandler()
                })
            }
        }
    }
    
    func reverseLocationCoordinates(location: CLLocation) async throws -> CLPlacemark? {
        let place = try await CLGeocoder().reverseGeocodeLocation(location).first
        return place
    }
}
