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
    @Published var errorMessage = ""
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        DispatchQueue.main.async {
            
            self.passengerRoutePolylineArr.withUnsafeBufferPointer { buffer in
                print("adress vm \(String(reflecting: buffer.baseAddress))")
            }
        }
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        
        if self.placeArray == [] {
            let overlayToPolyline = overlay as! MKPolyline
            if overlayToPolyline.title == "users_range" {
                renderer.strokeColor = .init(red: 49.0/255.0, green: 112.0/255.0, blue: 239.0/255.0, alpha: 1.0)
                renderer.lineWidth = 6
            } else {
                renderer.strokeColor = .black.withAlphaComponent(0.3)
                renderer.lineWidth = 5
            }
        } else {
            renderer.strokeColor = .init(red: 49.0/255.0, green: 112.0/255.0, blue: 239.0/255.0, alpha: 1.0)
            renderer.lineWidth = 6
        }
        return renderer
    }
    
    func fetchUsersOnTrip(uid: String, completion: @escaping (_ user: FirebaseUser) -> Void) -> Void {
        FirebaseManager.shared.firestore.collection("users")
            .document(uid)
            .getDocument { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch users: \(error)"
                    print("Failed to fetch users: \(error)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    self.errorMessage = "No data found"
                    return
                }
                
                completion(.init(data: data))
                
                self.errorMessage = "Fetched users successfully"
            }
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
    @Binding var placeRelatedUsersArray: [String]?
    @Binding var polylineArr: [MKPolyline]
    
    @Binding var searchRouteZoom: [MKAnnotation]
    
    @Binding var passengerCount: Int?
    
    @Binding var tripData: FirebaseTrip?
    
    @Binding var firebasePointsDictionaryArray: [FirebasePointsDictionary]
    
    @Binding var tripUsers: [String: FirebaseUser]
    
    @Binding var tripUids: [String]
    
    @Binding var pointsForGeoQuery: [String]
    
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
        
        print("points array: \(pointsArray)")
        
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
    
    
    func combinationsWithRepetition(input source: [CLLocationCoordinate2D], length: Int) -> [[CLLocationCoordinate2D]] {
        if length == 0 { return [[]] }
        
//        var subDist: Double = 0
//        var tempSubDist: Double = .infinity
//        var tempArr: [CLLocationCoordinate2D] = []
        
        let baseArray = combinationsWithRepetition(input: source, length: length - 1).filter{

            if $0.count != 0 {
                if $0.first != pointsArray.first! {
                    return false
                }
                
                if $0.contains(pointsArray.last!) {
                    if $0.firstIndex(of: pointsArray.last!)! != pointsArray.count-1 {
                        return false
                    }
                }
                
                if placeArray == [] {
                    if $0.contains(pointsArray[1]) && $0.contains(pointsArray[2]) {
                        if $0.firstIndex(of: pointsArray[1])! > $0.firstIndex(of: pointsArray[2])! {
                            return false
                        }
                    }
                    
                    if passengerCount != 0 {
                        for i in 0...(passengerCount!/2)-1 {
                            if $0.contains(pointsArray[i*2+3]) && $0.contains(pointsArray[i*2+4]) {
                                if $0.firstIndex(of: pointsArray[i*2+3])! > $0.firstIndex(of: pointsArray[i*2+4])! {
                                    return false
                                }
                            }
                        }
                    }
                }
            }
            return true
        }
        
//        if baseArray.count > 2 {
//            for array in baseArray {
//                if array.count > 3 {
//                    for i in 0...array.count-2 {
//                        subDist += CLLocation(latitude: array[i].latitude, longitude: array[i].longitude).distance(from: CLLocation(latitude: array[i+1].latitude, longitude: array[i+1].longitude))
//                    }
//                    if subDist < tempSubDist {
//                        print("56 subDist: \(subDist)")
//                        tempSubDist = subDist
//                        tempArr = array
//                    }
//                    subDist = 0
//                }
//            }
//            if tempArr != [] {
//                baseArray = [tempArr]
//            }
//        }
        
        var newArray = [[CLLocationCoordinate2D]]()
        for value in source {
            baseArray.forEach {
                if !$0.contains(value) {
                    newArray.append($0 + [value])
                }
            }
            print("56 newarrcount: \(newArray.count)")
        }
        return newArray
    }
    
    func getShortestWay(pointsArray: [CLLocationCoordinate2D], completionHandler: @escaping (_ shortestDistance: Float?, _ shortestWayArray: [MKRoute]?, _ annotationArray: [MKAnnotation]?) -> Void) -> Void {
        
        
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
                print("56 subDist: \(subDist)")
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
                var uid: String = ""
                
                if placeArray.count == 0 {
                    title = placeTitleArray![pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!]
                    tempAnnotion.subtitle = "\(placeSubtitleArray![pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!])"
                    uid = placeRelatedUsersArray![pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!]
                } else {
                    title = placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].name!
                    tempAnnotion.subtitle = "\(placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].locality ?? "")/\(placeArray[pointsArray.firstIndex(of: shortestSubArr[i].coordinate)!].administrativeArea ?? "")"
                }
                tempAnnotion.title = "Point \(i+1) \(title)"
                
                
                annotationArray.append(tempAnnotion)
                self.annotationArr.append(tempAnnotion)
                let hash = GFUtils.geoHash(forLocation: tempArr[i])
                
                if placeArray == [] {
                    print("pass cnt \(passengerCount!)")
                    
                    directionsMapViewModel.fetchUsersOnTrip(uid: uid) { user in
                        tripUsers[uid] = user
                        print("profile image: \(user.profileImageURL)")
                    }
                    if !tripUids.contains(uid) {
                        tripUids.append(uid)
                    }
                    firebasePointsDictionaryArray.append(FirebasePointsDictionary(geohash: hash, lat: tempArr[i].latitude, lon: tempArr[i].longitude, title: title, subtitle: tempAnnotion.subtitle!, relatedUser: uid))
                    print("title asd \(title)")
                    if tempArr[i] == pointsArray[1] {
                        self.tripData!.shortestPointsDictArray["passenger\((passengerCount!+1)/2+1)0"] = FirebasePointsDictionary(geohash: hash, lat: tempArr[i].latitude, lon: tempArr[i].longitude, title: title, subtitle: tempAnnotion.subtitle!, relatedUser: uid)
                    }
                    if shortestSubArr[i].coordinate == pointsArray[2] {
                        self.tripData!.shortestPointsDictArray["passenger\((passengerCount!+1)/2+1)1"] = FirebasePointsDictionary(geohash: hash, lat: tempArr[i].latitude, lon: tempArr[i].longitude, title: title, subtitle: tempAnnotion.subtitle!, relatedUser: uid)
                    }
                } else {
                    let documentData: [String: Any] = [
                        "geohash": hash,
                        "lat": tempArr[i].latitude,
                        "lon": tempArr[i].longitude,
                        "title": title,
                        "subtitle": tempAnnotion.subtitle!
                    ]
                    
                    if i == 0 {
                        self.shortestPointsDictArray["start"] = documentData
                    } else {
                        if i == placeArray.count-1 {
                            self.shortestPointsDictArray["destination"] = documentData
                        } else {
                            self.shortestPointsDictArray["step\(i)"] = documentData
                        }
                    }
                    
                    if placeArray != [] {
                        var pointsForGeoQueryLocal: [String] = []
                        
                        for route in routeArr {
                            for step in route.steps {
                                let queryHash = GFUtils.geoHash(forLocation: .init(latitude: step.polyline.coordinate.latitude, longitude: step.polyline.coordinate.longitude))
                                print("lat: \(step.polyline.coordinate.latitude) lon: \(step.polyline.coordinate.longitude), queryhash: \(queryHash)")
                                
                                if !pointsForGeoQueryLocal.contains(String(queryHash.prefix(3))) {
                                    pointsForGeoQueryLocal.append(String(queryHash.prefix(3)))
                                }
                            }
                        }
                        self.pointsForGeoQuery = pointsForGeoQueryLocal
                    }
//
//                    if !tempArr.isEmpty {
//                        for i in 0..<tempArr.count-1 {
//                            let latDiff = tempArr[i+1].latitude - tempArr[i].latitude
//                            let lonDiff = tempArr[i+1].longitude - tempArr[i].longitude
//
//                            let ratio = abs(latDiff)/abs(lonDiff)
//
//                            print("ratio: \(ratio)")
//                            print("lon diff: \(lonDiff)")
//                            print("lat diff: \(latDiff)")
//
//                            var latStep: Double = 0
//                            var lonStep: Double = 0
//
//                            var div: Double = 0
//
//
//
//                            if ratio < 1 {
//                                lonStep = 1.4*lonDiff/abs(lonDiff)
//                                div = abs(lonDiff)/1.4
//                                latStep = latDiff/div
//                            } else {
//                                latStep = 1.4*latDiff/abs(latDiff)
//                                div = abs(latDiff)/1.4
//                                lonStep = lonDiff/div
//                            }
//
//                            print("latStep \(latStep)")
//                            print("lonStep \(lonStep)")
//
//                            var latInc = tempArr[i].latitude
//                            var lonInc = tempArr[i].longitude
//
//                            for _ in 0...Int(ceil(abs(div))) {
//                                let queryHash = GFUtils.geoHash(forLocation: .init(latitude: latInc, longitude: lonInc))
//                                pointsForGeoQueryLocal.append(String(queryHash.prefix(3)))
//                                latInc += latStep
//                                lonInc += lonStep
//                            }
//                        }
//                        self.pointsForGeoQuery = pointsForGeoQueryLocal
//                    }
                    
                    
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
                            self.searchRouteZoom.append(arr[i])
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
            request.departureDate = self.tripDate
            request.requestsAlternateRoutes = true
            
            let directions = MKDirections(request: request)
        
            directions.calculate { response, error in
                if let error = error {
                    print(error)
                    calculateDirections()
                }
                
                print("routes count: \(response?.routes.count)")
                guard let route = response?.routes.first else {return}

                print("Count: \(response?.routes.count)")
                print("steps: \(route.steps.first?.polyline.coordinate.longitude)")
                print("advisory: \(route.advisoryNotices)")
                print("name: \(route.name)")
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
            
            
            for polyline in polylineArr {
                polyline.title = "users_range"
            }
            
            mapView.addAnnotations(annotationArr)
            if self.placeArray == [] {
                mapView.fitAll(in: self.searchRouteZoom, andShow: true)
            } else {
                mapView.fitAll()
            }
            
            for route in routeArr {
                mapView.addOverlay(route.polyline)
                completionHandler(mapView)
            }
        }
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
    }
}
