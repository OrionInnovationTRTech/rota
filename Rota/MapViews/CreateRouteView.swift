//
//  CreateRouteView.swift
//  Rota
//
//  Created by Batuhan Doğan on 29.07.2022.
//

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift

class CreateRouteViewModel: ObservableObject {
    
    var createRouteUser: FirebaseUser?
    
    @Published var errorMessage: String = ""
    
    @Published var shortestPointsDictArray: [String: [String: Any]]?
    @Published var distance: Float?
    @Published var tripDate: Date?
    
    @Published var placeArray: [CLPlacemark]?
    
    @Published var tripData: FirebaseTrip?
    
    @Published var startingLocationManager: LocationManager?
    @Published var destinationLocationManager: LocationManager?
    
    
    init() {
        fetchCurrentUser()
    }
    
    
    func handleSend() {
        guard let publisher = FirebaseManager.shared.auth.currentUser?.uid else {return}
        if placeArray == [] {
            guard let tripData = tripData else {
                return
            }
            
            var newDict: [String: [String: Any]] = [:]
            
            for key in tripData.shortestPointsDictArray.keys {
                newDict[key] = ["geohash": tripData.shortestPointsDictArray[key]!.geohash, "lat": tripData.shortestPointsDictArray[key]!.lat, "lon": tripData.shortestPointsDictArray[key]!.lon, "title": tripData.shortestPointsDictArray[key]!.title, "subtitle": tripData.shortestPointsDictArray[key]!.subtitle]
            }
            
            let newData = ["publisher": tripData.publisher, "distance": tripData.distance, "timestamp": tripData.timestamp, "tripDate": tripData.tripDate, "shortestPointsDictArray": newDict] as [String : Any]
            
            let document = FirebaseManager.shared.firestore.collection("trips")
                .document(tripData.id!)
            
            document.setData(newData) { error in
                if let error = error {
                    self.errorMessage = "Failed to save trip into Firestore: \(error)"
                    return
                }
            }
        } else {
            let tripData = [FirebaseConstants.publisher: publisher, "shortestPointsDictArray": self.shortestPointsDictArray!, "distance": self.distance!, "tripDate": self.tripDate!, FirebaseConstants.timestamp: Timestamp()] as [String : Any]
            let document = FirebaseManager.shared.firestore.collection("trips")
                .document()
            document.setData(tripData) { error in
                if let error = error {
                    self.errorMessage = "Failed to save trip into Firestore: \(error)"
                    return
                }
            }
        }
        print("Successfully saved trip")
    }
    
    func fetchCurrentUser() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        self.errorMessage = "\(uid)"
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let err = error {
                self.errorMessage = "Failed to fetch current user: \(err.localizedDescription)"
                print("Failed to fetch current user: \(err.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found"
                return
            }
            
            self.createRouteUser = .init(data: data)
        }
    }
}

struct CreateRouteView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var directions: [Int: [String]] = [:]
    @State private var showDirections = false
    @State var distance: Float = 0
    
    @State var placeArray: [CLPlacemark]
    @State var placeTitleArray: [String]?
    @State var placeSubtitleArray: [String]?
    
    @State var passengerCount: Int?
    
    @State var pointsArray: [CLLocationCoordinate2D]
    
    @State var shortestPointsDictArray: [String: [String: Any]] = [:]
    
    @State var mapView: MKMapView = .init()
    
    @State var routeArray: [MKRoute] = []
    @State var distanceArray: [Float] = []
    @State var annotationArr: [MKAnnotation] = []
    
    @State var shouldShowPublishSheet = false
    @State var getMapView: MKMapView = .init()
    
    @State var tripDate = Date()
    @State var expectedTravelTime: String = ""
    @State var expectedTime: Double = 0
    @State var timeArr: [Double] = []
    
    @State var polylineArr: [MKPolyline] = []
    
    @State var tripID: String?
    
    @State var tripData: FirebaseTrip?
    
    @State var startingLocationManager: LocationManager?
    @State var destinationLocationManager: LocationManager?
    
    @ObservedObject var createRouteViewModel: CreateRouteViewModel = .init()
    
    var body: some View {
        NavigationView {
            ZStack {
                DirectionsMapView(distance: $distance, directions: $directions, pointsArray: $pointsArray, placeArray: $placeArray, mapView: $mapView, routeArray: $routeArray, distanceArray: $distanceArray, annotationArr: $annotationArr, shortestPointsDictArray: $shortestPointsDictArray, tripDate: $tripDate, expectedTravelTimeString: $expectedTravelTime, expectedTime: $expectedTime, timeArr: $timeArr, placeTitleArray: $placeTitleArray, placeSubtitleArray: $placeSubtitleArray, polylineArr: $polylineArr, passengerCount: $passengerCount, tripData: $tripData)
                    .ignoresSafeArea()
                    .onDisappear {
                        self.mapView.removeOverlays(self.mapView.overlays)
                        self.mapView.removeAnnotations(self.mapView.annotations)
                    }
                    .navigationBarTitle("", displayMode: .inline)
                
                HStack {
                    Button {
                        self.showDirections.toggle()
                    } label: {
                        if self.distance == 0 {
                            Text("Show Directions")
                                .fontWeight(.semibold)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.init(white: 0.9, alpha: 1)))
                                }
                                .foregroundColor(.gray)
                                .opacity(0.7)
                        } else {
                            Text("Show Directions")
                                .fontWeight(.semibold)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(.blue)
                                }
                                .foregroundColor(.blue)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.white)
                                }
                        }
                    }
                    .padding()
                    .disabled(self.distance == 0)
           
                    Button {
                        self.shouldShowPublishSheet.toggle()
                    } label: {
                        if self.distance == 0 {
                            Text("Confirm Route")
                                .fontWeight(.semibold)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.init(white: 0.9, alpha: 1)))
                                }
                                .foregroundColor(.gray)
                                .opacity(0.7)
                        } else {
                            Text("Confirm Route")
                                .fontWeight(.semibold)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.blue)
                                }
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(self.distance == 0)
                    .sheet(isPresented: $shouldShowPublishSheet, onDismiss: {
                        self.getMapView.removeOverlays(self.getMapView.overlays)
                        self.getMapView.removeAnnotations(self.getMapView.annotations)
                    }, content: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Summary")
                                .font(.largeTitle.bold())
                                .padding(.bottom)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(0..<self.placeArray.count, id: \.self) { i in
                                    HStack(spacing: 10) {
                                        if let place = placeArray[i] {
                                            if i == 0 {
                                                Image(systemName: "play.fill")
                                                    .foregroundColor(Color(.label))
                                            } else if i == placeArray.count-1 {
                                                Image(systemName: "stop.fill")
                                                    .foregroundColor(Color(.label))
                                            } else {
                                                Image(systemName: "target")
                                                    .foregroundColor(Color(.label))
                                            }
                                            
                                            HStack {
                                                Text(place.name ?? "Choose Starting Point")
                                                    .foregroundColor(.gray)
                                                Text("\(place.locality ?? "")/\(place.administrativeArea ?? "")")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                    
                                    if i != placeArray.count-1 {
                                        Divider()
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                            }
                            
                            HStack {
                                Image(systemName: "calendar")
                                Text(tripDate.formatted())
                                Spacer()
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                            }
                            .padding(.vertical)
                            
                            ShowMapView(getMapView: $getMapView, routeArray: $routeArray, distance: $distance, annotationArr: $annotationArr)
                                .cornerRadius(15)
                                .padding(2)
                                .background {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(.blue, lineWidth: 4)
                                }
                            
                            Button {
                                //MARK: - firebase
                                createRouteViewModel.placeArray = self.placeArray
                                createRouteViewModel.shortestPointsDictArray = shortestPointsDictArray
                                createRouteViewModel.distance = self.distance
                                //createRouteViewModel.directions = self.directions
                                createRouteViewModel.tripDate = self.tripDate
                                
                                createRouteViewModel.tripData = self.tripData
                                createRouteViewModel.startingLocationManager = self.startingLocationManager
                                createRouteViewModel.destinationLocationManager = self.destinationLocationManager
                                    
                                print("pass cnt: \(passengerCount!)")
                                
                                createRouteViewModel.handleSend()
                                self.shouldShowPublishSheet.toggle()
                            } label: {
                                Text("Publish Route")
                                    .fontWeight(.semibold)
                                    .padding(12)
                                
                                    .frame(maxWidth: .infinity, alignment: .bottom)
                                    .background {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(.blue)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical)
                            }

                            
                            
                        }
                        .padding()
                    })
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack {
                        if self.distance != 0 {
                            Text("Distance: \(String(format: "%.2f", self.distance)) km").fontWeight(.semibold)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.white)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                        if self.expectedTravelTime != "" {
                            Text("Expected Travel Time: \(String(self.expectedTravelTime))").fontWeight(.semibold)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.white)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                    }
                    
                }
            }
        }
        .popupNavigationView(show: $showDirections) {
            List {
                ForEach(0..<self.directions.count, id: \.self) { i in
                    let randColor = Color.random
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Route: \(i+1)")
                            .foregroundColor(.white)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(randColor)
                            }
                        ForEach(0..<self.directions[i]!.count, id: \.self) { j in
                            Text(self.directions[i]![j])
                                .padding()
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(randColor, lineWidth: 3)
                    }
                    .padding(.bottom)
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        self.showDirections.toggle()
                    }
                }
            }
        }
    }
}

//struct CreateRouteView_Previews: PreviewProvider {
//    static var previews: some View {
//        CreateRouteView(placeArray: .init(), pointsArray: [CLLocationCoordinate2D(latitude: 40.71, longitude: -74), CLLocationCoordinate2D(latitude: 40.71, longitude: -74)], tripDate: Date())
//    }
//}
