//
//  DirectionsMapView.swift
//  Rota
//
//  Created by Batuhan Doğan on 3.08.2022.
//

import SwiftUI
import MapKit
import GeoFire

class DirectionsMapViewModel: NSObject, ObservableObject, MKMapViewDelegate {
    @Published var placeArray: [CLPlacemark] = []
    @Published var passengerRoutePlaceArr: [MKPlacemark] = []
    @Published var passengerRoutePolylineArr: [MKPolyline] = []
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        DispatchQueue.main.async {
            
            self.passengerRoutePolylineArr.withUnsafeBufferPointer { buffer in
                print("adress vm \(String(reflecting: buffer.baseAddress))")
            }
        }
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        
        if self.placeArray == [] {
            let overlayToPolyline = overlay as! MKPolyline
            if self.passengerRoutePolylineArr.contains(overlayToPolyline) {
                renderer.strokeColor = .blue.withAlphaComponent(1)
            } else {
                renderer.strokeColor = .gray.withAlphaComponent(0.5)
            }
        } else {
            renderer.strokeColor = .blue
        }
        renderer.lineWidth = 5
        return renderer
    }
}

struct DirectionsMapView: UIViewRepresentable {
    typealias UIViewType = MKMapView

    @Binding var distance: Float
    @Binding var directions: [Int: [String]]
    @Binding var pointsArray: [CLLocationCoordinate2D]
    @Binding var placeArray: [CLPlacemark]
    @Binding var mapView: MKMapView
    
    @Binding var routeArray: [MKRoute]
    @Binding var distanceArray: [Float]
    @Binding var annotationArr: [MKAnnotation]
    @Binding var shortestPointsDictArray: [String: [String: Any]]
    
    @Binding var tripDate: Date
    @Binding var expectedTravelTimeString: String
    @Binding var expectedTime: Double
    @Binding var timeArr: [Double]
    
    @Binding var placeTitleArray: [String]?
    @Binding var placeSubtitleArray: [String]?
    @Binding var polylineArr: [MKPolyline]
    
    @Binding var passengerCount: Int?
    
    @Binding var tripData: FirebaseTrip?
    
    @ObservedObject var directionsMapViewModel = DirectionsMapViewModel()
    
    func makeCoordinator() -> DirectionsMapViewModel {
        directionsMapViewModel.passengerRoutePolylineArr.withUnsafeBufferPointer { buffer in
            print("asd adress vm \(String(reflecting: buffer.baseAddress))")
        }
        
        return directionsMapViewModel
    }
    
    func makeUIView(context: Context) -> MKMapView {
        self.mapView.delegate = context.coordinator
        
        self.directionsMapViewModel.placeArray = self.placeArray
        
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.71, longitude: -74), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        self.mapView.setRegion(region, animated: true)
        
        getShortestWay(pointsArray: pointsArray) { shortestDistance, shortestWayArray, annotationArray in
            if let shortestDistance = shortestDistance, let shortestWayArray = shortestWayArray, let annotationArray = annotationArray {
                self.distance = shortestDistance
                
                getExpectedTimeString()
                drawRoute(mapView: self.mapView, routeArr: shortestWayArray, annotationArr: annotationArray) { overlayView in
                    DispatchQueue.main.async {
                        self.mapView = overlayView
                    }
                }
            }
        }
        return self.mapView
    }
    
    func getExpectedTimeString() -> Void {
        let interval = self.expectedTime
        self.expectedTime = 0
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short

        let formattedString = formatter.string(from: TimeInterval(interval))!
        self.expectedTravelTimeString = formattedString
    }
    
    func getShortestWay(pointsArray: [CLLocationCoordinate2D], completionHandler: @escaping (_ shortestDistance: Float?, _ shortestWayArray: [MKRoute]?, _ annotationArray: [MKAnnotation]?) -> Void) -> Void {
        
        func combinationsWithRepetition(input source: [CLLocationCoordinate2D], length: Int) -> [[CLLocationCoordinate2D]] {
            if length == 0 { return [[]] }
            let baseArray = combinationsWithRepetition(input: source, length: length - 1)
            var newArray = [[CLLocationCoordinate2D]]()
            for value in source {
                baseArray.forEach {
                    if !$0.contains(value) {
                        newArray.append($0 + [value])
                    }
                }
            }
            
            return newArray
        }
        var lastArray = combinationsWithRepetition(input: pointsArray, length: pointsArray.count)
        print("ararrarraasdad \(pointsArray)")
        
        if placeArray == [] {
            lastArray = lastArray.filter{$0.first == pointsArray.first! && $0.last == pointsArray.last! && $0.firstIndex(of: pointsArray[1])! < $0.firstIndex(of: pointsArray[2])!}
        } else {
            lastArray = lastArray.filter{$0.first == pointsArray.first! && $0.last == pointsArray.last!}// && $0.firstIndex(of: p10)! < $0.firstIndex(of: p11)! && $0.firstIndex(of: p20)! < $0.firstIndex(of: p21)! && $0.firstIndex(of: p30)! < $0.firstIndex(of: p31)!}
        }
        
        print("lastArray: \(lastArray)")
        
        var subDist: Double = 0
        
        var tempSubDist: Double = .infinity
        var tempArr: [CLLocationCoordinate2D] = []
        
        for array in lastArray {
            for i in 0...array.count-2 {
                subDist += CLLocation(latitude: array[i].latitude, longitude: array[i].longitude).distance(from: CLLocation(latitude: array[i+1].latitude, longitude: array[i+1].longitude))
            }
            if subDist < tempSubDist {
                print("subDist: \(subDist)")
                tempSubDist = subDist
                tempArr = array
            }
            subDist = 0
        }
        
        var shortestSubArr: [MKPlacemark] = []
        for coord in tempArr {
            shortestSubArr.append(MKPlacemark.init(coordinate: coord))
        }
        
        print("SubArray: \(shortestSubArr)")
        
        var shortestWayArray: [MKRoute] = []
        var annotationArray: [MKAnnotation] = []
        var shortestDistance: Float = .infinity
        
        getDistanceSum(arr: shortestSubArr) { sumDist, routeArr in

            shortestDistance = sumDist
            shortestWayArray = routeArr
            for i in 0...(placeArray.count == 0 ? placeTitleArray!.count : placeArray.count)-1 {
                let tempAnnotion = MKPointAnnotation()
                tempAnnotion.coordinate = shortestSubArr[i].coordinate
                var title: String = ""
                if placeArray.count == 0 {
                    title = placeTitleArray![pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!]
                    tempAnnotion.subtitle = "\(placeSubtitleArray![pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!])/\(placeSubtitleArray![pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!])"
                } else {
                    title = placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].name!
                    tempAnnotion.subtitle = "\(placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].locality ?? "")/\(placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].administrativeArea ?? "")"
                }
                tempAnnotion.title = "Point \(i+1) \(title)"
                
                annotationArray.append(tempAnnotion)
                self.annotationArr.append(tempAnnotion)
                let hash = GFUtils.geoHash(forLocation: tempArr[i])
                let documentData: [String: Any] = [
                    "geohash": hash,
                    "lat": tempArr[i].latitude,
                    "lon": tempArr[i].longitude,
                    "title": title,
                    "subtitle": tempAnnotion.subtitle!
                ]
                if placeArray == [] {
                    print("pass cnt \(passengerCount!)")
                    if tempArr[i] == pointsArray[1] {
                        self.tripData!.shortestPointsDictArray["passenger\((passengerCount!+1)/2+1)0"] = FirebasePointsDictionary(geohash: hash, lat: tempArr[i].latitude, lon: tempArr[i].longitude, title: title, subtitle: tempAnnotion.subtitle!)
                    }
                    if shortestSubArr[i].coordinate == pointsArray[2] {
                        self.tripData!.shortestPointsDictArray["passenger\((passengerCount!+1)/2+1)1"] = FirebasePointsDictionary(geohash: hash, lat: tempArr[i].latitude, lon: tempArr[i].longitude, title: title, subtitle: tempAnnotion.subtitle!)
                    }
                } else {
                    if i == 0 {
                        self.shortestPointsDictArray["start"] = documentData
                    } else {
                        if i == placeArray.count-1 {
                            self.shortestPointsDictArray["destination"] = documentData
                        } else {
                            self.shortestPointsDictArray["step\(i)"] = documentData
                        }
                    }
                }
            }
            print("Shortest = \(shortestWayArray) : \(shortestDistance) : \(annotationArray)")
            completionHandler(shortestDistance, shortestWayArray, annotationArray)
        }
    }
    
    func getDistanceSum(arr: [MKPlacemark], comp: @escaping (_ sumDistance: Float, _ routeArr: [MKRoute]) -> Void) -> Void {
        
        var appendIt = false
        var placeArr: [MKPlacemark] = []
        
        if !arr.isEmpty {
            if self.placeArray == [] {
                for place in arr {
                    if place.coordinate == pointsArray[1] {
                        appendIt = true
                    }
                    if appendIt {
                        placeArr.append(place)
                    }
                    if place.coordinate == pointsArray[2] {
                        appendIt = false
                    }
                }
            }
            print("place array asdasd \(placeArr)")
            
            for i in 0...arr.count-2 {
                print(i)
                getDistance(arr: arr, startPoint: arr[i], destinationPoint: arr[i+1]) { distance, route, expectedTime in
                    if placeArray == [] {
                        if placeArr.contains(arr[i]) {
                            if arr[i].coordinate != pointsArray[2] {
                                self.polylineArr.append(route.polyline)
                                print("count of poly arr \(self.polylineArr.count)")
                            }
                        }
                    }
                    
                    print(distance)
                    self.routeArray.append(route)
                    self.distanceArray.append(distance)
                    self.timeArr.append(expectedTime)
                    print(timeArr)
                    print("Arr: \(i)")
                    print("count \(routeArray.count) \(distanceArray) \(arr.count)")
                    if distanceArray.count == arr.count-1 && timeArr.count == arr.count-1 {
                        var sum: Float = 0
                        var totalTime: Double = 0
                        for i in 0..<self.distanceArray.count {
                            sum += self.distanceArray[i]
                            totalTime += self.timeArr[i]
                        }
                        self.expectedTime += totalTime
                        comp(sum, self.routeArray)
                    }
                }
            }
        }
    }
    
    func appendArray(distance: Float, route: MKRoute, doneAppending: @escaping (_ distance: [Float], _ route: [MKRoute]) -> Void) -> Void {
    }
    
    func getDistance(arr: [MKPlacemark], startPoint: MKPlacemark, destinationPoint: MKPlacemark, doneSearching: @escaping (_ distance: Float, _ route: MKRoute, _ expectedTime: Double) -> Void) -> Void {
        func calculateDirections() {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: startPoint)
            request.destination = MKMapItem(placemark: destinationPoint)
            request.transportType = .automobile
            request.arrivalDate = self.tripDate
            
            let directions = MKDirections(request: request)
        
            directions.calculate { response, error in
                if let error = error {
                    print(error)
                    calculateDirections()
                }
                guard let route = response?.routes.first else {return}
                    
                print("steps: \(route.steps)")
                print("advisory: \(route.advisoryNotices)")
                print("expected time: \(route.expectedTravelTime)")
                doneSearching(Float(route.distance/1000), route, route.expectedTravelTime)
                self.directions[arr.firstIndex(of: startPoint)!] = route.steps.map{$0.instructions}.filter{!$0.isEmpty}
                print(route.polyline.coordinate)
                
            }
        }
        calculateDirections()
        
    }
    
    func drawRoute(mapView: MKMapView, routeArr: [MKRoute], annotationArr: [MKAnnotation], completionHandler: @escaping (_ overlayView: MKMapView) -> Void) -> Void {
        DispatchQueue.main.async {
            print(self.polylineArr)
            directionsMapViewModel.placeArray = self.placeArray
            directionsMapViewModel.passengerRoutePolylineArr = self.polylineArr
            
            directionsMapViewModel.passengerRoutePolylineArr.withUnsafeBufferPointer { buffer in
                print("adress \(String(reflecting: buffer.baseAddress))")
            }
            
            print("poly array \(self.polylineArr) vm poly array \(directionsMapViewModel.passengerRoutePolylineArr)")
            
        
            mapView.addAnnotations(annotationArr)
            for route in routeArr {
                mapView.addOverlay(route.polyline)
                mapView.fitAll()
                completionHandler(mapView)
            }
        }
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
    }
}
