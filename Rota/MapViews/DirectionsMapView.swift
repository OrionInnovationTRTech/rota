//
//  DirectionsMapView.swift
//  Rota
//
//  Created by Batuhan Doğan on 3.08.2022.
//

import SwiftUI
import MapKit

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
    
    @Binding var pointsFloatArray: [String: Double]
    
    func makeCoordinator() -> MapViewCoordinator {
        return MapViewCoordinator()
    }
    
    func makeUIView(context: Context) -> MKMapView {
        self.mapView.delegate = context.coordinator
        
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.71, longitude: -74), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        self.mapView.setRegion(region, animated: true)
        
        getShortestWay(pointsArray: pointsArray) { shortestDistance, shortestWayArray, annotationArray in
            if let shortestDistance = shortestDistance, let shortestWayArray = shortestWayArray, let annotationArray = annotationArray {
                self.distance = shortestDistance
                drawRoute(mapView:self.mapView, routeArr: shortestWayArray, annotationArr: annotationArray) { overlayView in
                    DispatchQueue.main.async {
                        self.mapView = overlayView
                    }
                }
            }
        }
        return self.mapView
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
        lastArray = lastArray.filter{$0.first == pointsArray.first! && $0.last == pointsArray.last!}// && $0.firstIndex(of: p10)! < $0.firstIndex(of: p11)! && $0.firstIndex(of: p20)! < $0.firstIndex(of: p21)! && $0.firstIndex(of: p30)! < $0.firstIndex(of: p31)!}
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
            for i in 0...shortestSubArr.count-1 {
                let tempAnnotion = MKPointAnnotation()
                tempAnnotion.coordinate = shortestSubArr[i].coordinate
                tempAnnotion.title = "Point \(i+1) \(placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].name!)"
                tempAnnotion.subtitle = "\(placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].locality!)/\(placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].administrativeArea!)"
                annotationArray.append(tempAnnotion)
                self.annotationArr.append(tempAnnotion)
                self.pointsFloatArray["\(i) lat"] = shortestSubArr[i].coordinate.latitude
                self.pointsFloatArray["\(i) lon"] = shortestSubArr[i].coordinate.longitude
            }
            print("Shortest = \(shortestWayArray) : \(shortestDistance) : \(annotationArray)")
            completionHandler(shortestDistance, shortestWayArray, annotationArray)
        }
    }
    
    func getDistanceSum(arr: [MKPlacemark], comp: @escaping (_ sumDistance: Float, _ routeArr: [MKRoute]) -> Void) -> Void {
//        let semaphore = DispatchSemaphore(value: 0)
        if !arr.isEmpty {
            for i in 0...arr.count-2 {
                print(i)
                getDistance(arr: arr, startPoint: arr[i], destinationPoint: arr[i+1]) { distance, route in
                    print(distance)
                    self.routeArray.append(route)
                    self.distanceArray.append(distance)
                    print("Arr: \(i)")
                    print("count \(routeArray.count) \(distanceArray) \(arr.count)")
                    if distanceArray.count == arr.count-1 {
                        var sum: Float = 0
                        for distance in self.distanceArray {
                            sum += distance
                        }
                        comp(sum, self.routeArray)
                    }
                }
            }
        }
    }
    
    func appendArray(distance: Float, route: MKRoute, doneAppending: @escaping (_ distance: [Float], _ route: [MKRoute]) -> Void) -> Void {
    }
    
    func getDistance(arr: [MKPlacemark], startPoint: MKPlacemark, destinationPoint: MKPlacemark, doneSearching: @escaping (_ distance: Float, _ route: MKRoute) -> Void) -> Void {
        func calculateDirections() {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: startPoint)
            request.destination = MKMapItem(placemark: destinationPoint)
            request.transportType = .automobile
            
            let directions = MKDirections(request: request)
        
            directions.calculate { response, error in
                if let error = error {
                    print(error)
                    calculateDirections()
                }
                guard let route = response?.routes.first else {return}
                doneSearching(Float(route.distance/1000), route)
                self.directions[arr.firstIndex(of: startPoint)!] = route.steps.map{$0.instructions}.filter{!$0.isEmpty}
            }
        }
        calculateDirections()
        
    }
    
    func drawRoute(mapView: MKMapView, routeArr: [MKRoute], annotationArr: [MKAnnotation], completionHandler: @escaping (_ overlayView: MKMapView) -> Void) -> Void {
        mapView.addAnnotations(annotationArr)
        for route in routeArr {
            mapView.addOverlay(route.polyline)
            mapView.fitAll()
            completionHandler(mapView)
        }
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
    }
    
    class MapViewCoordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .blue
            renderer.lineWidth = 3
            return renderer
        }
    }
}
