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
import SDWebImageSwiftUI

class TripDetailsViewModel: ObservableObject {
    
    var tripDetailsUser: FirebaseUser?
    
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
    
    
    func handleSend(completion: @escaping (_ isSaveSuccessfully: Bool) -> Void) {
        guard let tripData = tripData else {
            return
        }
        
        var newDict: [String: [String: Any]] = [:]
        
        for key in tripData.shortestPointsDictArray.keys {
            newDict[key] = ["geohash": tripData.shortestPointsDictArray[key]!.geohash, "lat": tripData.shortestPointsDictArray[key]!.lat, "lon": tripData.shortestPointsDictArray[key]!.lon, "title": tripData.shortestPointsDictArray[key]!.title, "subtitle": tripData.shortestPointsDictArray[key]!.subtitle, "relatedUser": tripData.shortestPointsDictArray[key]!.relatedUser ?? tripData.publisher]
        }
        
        let newData = ["publisher": tripData.publisher, "shortestPointsDictArray": newDict, "distance": tripData.distance, "tripDate": tripData.tripDate, "geohashesForQuery": tripData.geohashesForQuery, "timestamp": tripData.timestamp] as [String : Any]
        
        let document = FirebaseManager.shared.firestore.collection("trips")
            .document(tripData.id!)
        let ref = document.documentID
        document.setData(newData) { error in
            if let error = error {
                self.errorMessage = "Failed to save trip into Firestore: \(error)"
                return
            }
        }
        
        let usersTrips = FirebaseManager.shared.firestore.collection("users_trips")
            .document(tripDetailsUser!.uid)
            .collection("your_trips")
            .document()
        usersTrips.setData(["trip_id": ref]) { error in
            if let error = error {
                self.errorMessage = "Failed to save trip into Firestore: \(error)"
                return
            }
        }
        completion(true)
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
            
            self.tripDetailsUser = .init(data: data)
        }
    }
}

struct TripDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State var directions: [Int: [String]] = [:]
    @State private var showDirections = false
    @State var distance: Float = 0
    
    @State var placeArray: [CLPlacemark]
    @State var placeTitleArray: [String]?
    @State var placeSubtitleArray: [String]?
    @State var placeRelatedUserArray: [String]?
    
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
    
    @State var searchRouteZoom: [MKAnnotation] = []
    
    @State var tripID: String?
    
    @State var tripData: FirebaseTrip?
    
    @State var startingLocationManager: LocationManager?
    @State var destinationLocationManager: LocationManager?
    
    @State var showMap: Double = 0
    
    @State var firebasePointsDictionaryArray: [FirebasePointsDictionary] = []
    
    @State var tripUsers: [String: FirebaseUser] = [:]
    
    @State var tripUids: [String] = []
    
    @State var pointsForGeoQuery: [String] = []
    
    @State private var tripInformationSize: CGSize = .zero
    
    let didSaveTrip: () -> ()
    
    @ObservedObject var tripDetailsViewModel: TripDetailsViewModel = .init()
    
    @State var profileImageURL: String = ""
    
    @State var scrollable = true
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    DirectionsMapView(distance: $distance, directions: $directions, pointsArray: $pointsArray, placeArray: $placeArray, mapView: $mapView, routeArray: $routeArray, distanceArray: $distanceArray, annotationArr: $annotationArr, shortestPointsDictArray: $shortestPointsDictArray, tripDate: $tripDate, expectedTravelTimeString: $expectedTravelTime, expectedTime: $expectedTime, timeArr: $timeArr, placeTitleArray: $placeTitleArray, placeSubtitleArray: $placeSubtitleArray, placeRelatedUsersArray: $placeRelatedUserArray, polylineArr: $polylineArr, searchRouteZoom: $searchRouteZoom, passengerCount: $passengerCount, tripData: $tripData, firebasePointsDictionaryArray: $firebasePointsDictionaryArray, tripUsers: $tripUsers, tripUids: $tripUids, pointsForGeoQuery: $pointsForGeoQuery)
                        .ignoresSafeArea()
                        .onDisappear {
                            self.mapView.removeOverlays(self.mapView.overlays)
                            self.mapView.removeAnnotations(self.mapView.annotations)
                        }
                        .navigationBarTitle("", displayMode: .inline)

                    HStack {
                        Button {
                            self.showDirections.toggle()
                            print("firebasepointsarray: \(firebasePointsDictionaryArray)")
                        } label: {
                            if self.distance == 0 {
                                Text("Show Directions")
                                    .fontWeight(.semibold)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .center)
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
                                    .frame(maxWidth: .infinity, alignment: .center)
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
                                    .frame(maxWidth: .infinity, alignment: .center)
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
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(.blue)
                                    }
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
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
                                    tripDetailsViewModel.placeArray = self.placeArray
                                    tripDetailsViewModel.shortestPointsDictArray = shortestPointsDictArray
                                    tripDetailsViewModel.distance = self.distance
                                    //createRouteViewModel.directions = self.directions
                                    tripDetailsViewModel.tripDate = self.tripDate

                                    tripDetailsViewModel.tripData = self.tripData
                                    tripDetailsViewModel.startingLocationManager = self.startingLocationManager
                                    tripDetailsViewModel.destinationLocationManager = self.destinationLocationManager

                                    tripDetailsViewModel.handleSend { isSaveSuccessfully in
                                        if isSaveSuccessfully {
                                            self.didSaveTrip()
                                        }
                                    }
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
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .opacity(self.showMap)
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
                        .opacity(self.showMap)
                    }
                }
            }
            .navigationBarBackButtonHidden(showMap == 1 ? true : false)
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
                .opacity(self.showMap)
                .listStyle(PlainListStyle())
                .navigationBarTitle("", displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            self.showDirections.toggle()
                        } label: {
                            Text("Close")
                                .opacity(showMap)
                        }
                    }
                }
            }
            
            if tripUsers.keys.count == 0 {
               ProgressView("Loading")
           }

            VStack(alignment: .leading, spacing: 0) {
                ScrollView(scrollable ? .vertical : [], showsIndicators: true) {
                    tripInformations
                    .overlay(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                self.tripInformationSize = geo.size
                            }
                        }
                    )
                }
                .simultaneousGesture(showMap == 0 ? nil : DragGesture(minimumDistance: 0), including: .all)
                .frame(maxWidth: .infinity, maxHeight: showMap == 0 ? .infinity : self.tripInformationSize.height + 10, alignment: showMap == 0 ? .topLeading : .center)
                .padding()
                .padding(.bottom, showMap == 0 ? 0 : 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showMap == 0 ? .topLeading : .bottomLeading)
        }
    }
    
    var tripInformations: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showMap == 0 {
                Group {
                    if tripUsers.keys.count != 0 {
                        Text(tripData?.tripDate.formatted(date: .long, time: .shortened) ?? "")
                            .font(.title.bold())
                        VStack(alignment: .leading) {
                            ForEach(0..<firebasePointsDictionaryArray.count, id: \.self) { i in
                                HStack {
                                    if tripUsers[firebasePointsDictionaryArray[i].relatedUser!] != nil { // !=
                                        Text(firebasePointsDictionaryArray[i].title)
                                        Text(firebasePointsDictionaryArray[i].subtitle)
                                            .font(.caption.bold())
//                                            tripUsers[firebasePointsDictionaryArray[i].relatedUser!]!.profileImageURL
                                        WebImage(url: URL(string: tripUsers[firebasePointsDictionaryArray[i].relatedUser!]!.profileImageURL))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 30, height: 30)
                                            .cornerRadius(10)
                                            .clipped()
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
                                    }
                                }
                                .lineLimit(1)
                                
                                if i != firebasePointsDictionaryArray.count-1 {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                        }
                    }
                }
            }
            
            HStack {
                Button {
                    withAnimation {
                        self.showMap = self.showMap == 1 ? 0 : 1
                    }
                } label: {
                    HStack {
                        Image(systemName: self.showMap == 0 ? "eye" : "eye.slash")
                        Text(self.showMap == 0 ? "View the route on the map" : "Close the map")
                    }
                    .padding()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: showMap == 0 ? .leading : .center)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.blue)
                    }
                    .padding(showMap == 1 ? .horizontal : .bottom)
                }
            }.offset(y: showMap == 0 ? -20 : 0)
                .padding(.bottom, showMap == 0 ? -20 : 0)
                .opacity(tripUsers.keys.count == 0 ? 0 : 1)

            
            VStack(alignment: .leading, spacing: 0) {
                if showMap == 0 {
                    if tripUsers.keys.count != 0 {
                        Text("Publisher")
                            .font(.title.bold())
                        HStack(alignment: .center, spacing: 0) {
                            NavigationLink {
                                
                            } label: {
                                HStack {
                                    if tripUsers.keys.count != 0 {
                                        if tripUsers[tripData!.publisher] != nil {
                                            Text("\(tripUsers[tripData!.publisher]?.name != nil ? tripUsers[tripData!.publisher]!.name!.components(separatedBy: "@")[0] : tripUsers[tripData!.publisher]!.email.components(separatedBy: "@")[0])")
                                                .font(.title2)
                                            
                                            Spacer()
                                            
                                            Group {
                                                Image(systemName: "star.fill")
                                                Text("4.3/5 (64 point)")
                                            }
                                            .foregroundColor(.gray)
                                            
                                            Spacer()
                                            
                                            //tripUsers[tripData!.publisher]!.profileImageURL
                                            WebImage(url: URL(string: tripUsers[tripData!.publisher]!.profileImageURL))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .cornerRadius(10)
                                                .clipped()
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
                                            
                                            Image(systemName: "chevron.right")
                                        }
                                    }
                                }
                                .foregroundColor(Color(.label))
                                .padding()
                                .background {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white)
                                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                                    }
                                }
                            }
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white)
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                                }
                            }
                            NavigationLink {
                                if tripUsers[tripData!.publisher] != nil {
                                    ChatLogView(chatLogViewModel: ChatLogViewModel(messagesViewUser: tripUsers[tripData!.publisher]!))
                                }
                            } label: {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .padding()
                            }
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom)
                        
                        
                        Text("Passengers")
                            .font(.title.bold())
                        if tripUsers.keys.count != 0 {
                            ForEach(0..<tripUids.count, id: \.self) { i in
                                NavigationLink {
                                    
                                } label: {
                                    if tripUsers.keys.count == tripUids.count {
                                        if tripData!.publisher != tripUids[i] {
                                            HStack {
                                                if tripUsers[tripUids[i]] != nil {
                                                    Text("\(tripUsers[tripUids[i]]?.name != nil ? tripUsers[tripUids[i]]!.name!.components(separatedBy: " ")[0] : tripUsers[tripUids[i]]!.email.components(separatedBy: "@")[0])")
                                                        .font(.title2)
                                                    
                                                    Spacer()
                                                    
                                                    Group {
                                                        Image(systemName: "star.fill")
                                                        Text("4.3/5 (64 point)")
                                                    }
                                                    .foregroundColor(.gray)
                                                    
                                                    Spacer()
                                                    
                                                    //tripUsers[tripData!.publisher]!.profileImageURL
                                                    WebImage(url: URL(string: tripUsers[tripUids[i]]!.profileImageURL))
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 40, height: 40)
                                                        .cornerRadius(10)
                                                        .clipped()
                                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
                                                    
                                                    Image(systemName: "chevron.right")
                                                }
                                            }
                                            .foregroundColor(Color(.label))
                                            .padding()
                                            .background {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }

                            }
                        }
                    }
                }
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showMap == 0 ? .topLeading : .bottomLeading)
        
    }
}

//struct TripDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        TripDetailsView(placeArray: [], placeTitleArray: ["Ziya Gokalp Cd. 11", "Mamak Belediyesi", "Cumhuriyet Blv. 14", "21. Sk.", "Cumhuriyet Meydani"], placeSubtitleArray: ["Cankaya/Ankara", "Mamak/Ankara", "Konak/İzmir", "Muratpasa/Antalya", "Muğla/Muğla"], passengerCount: 0, pointsArray: [CLLocationCoordinate2D(latitude: 39.9210643, longitude: 32.8562777), CLLocationCoordinate2D(latitude: 39.93172803, longitude: 32.91075684), CLLocationCoordinate2D(latitude: 38.419506, longitude: 27.1293471), CLLocationCoordinate2D(latitude: 36.8877208, longitude: 30.7027403), CLLocationCoordinate2D(latitude: 37.215367, longitude: 28.363556)], tripData: FirebaseTrip(id: "FJczP4xlFtZVQyeViEVL", publisher: "7HE51jnztEaW8iHVgm6rD4yiMRD2", shortestPointsDictArray: ["start": Rota.FirebasePointsDictionary(geohash: "sxp75emjnc", lat: 39.9210643, lon: 32.8562777, title: "Ziya Gokalp Cd. 11", subtitle: "Cankaya/Ankara", relatedUser: "7HE51jnztEaW8iHVgm6rD4yiMRD2"), "step1": Rota.FirebasePointsDictionary(geohash: "swtcfejn99", lat: 36.8877208, lon: 30.7027403, title: "21. Sk.", subtitle: "Muratpasa/Antalya", relatedUser: "7HE51jnztEaW8iHVgm6rD4yiMRD2"), "destination": Rota.FirebasePointsDictionary(geohash: "sws5tqvenz", lat: 37.215367, lon: 28.363556, title: "Cumhuriyet Meydani", subtitle: "Muğla/Muğla", relatedUser: "7HE51jnztEaW8iHVgm6rD4yiMRD2")], distance: 792.702, tripDate: Date(), timestamp: Date()), firebasePointsDictionaryArray: [Rota.FirebasePointsDictionary(geohash: "sxpyuyydx9", lat: 40.5990373, lon: 33.6164284, title: "Necip Fazil Kisakurek Sk. 16B", subtitle: "Çankırı Merkez/Çankırı", relatedUser: Optional("7HE51jnztEaW8iHVgm6rD4yiMRD2")), Rota.FirebasePointsDictionary(geohash: "sxp75emjnc", lat: 39.9210643, lon: 32.8562777, title: "Ziya Gokalp Cd. 11", subtitle: "Cankaya/Ankara", relatedUser: Optional("7HE51jnztEaW8iHVgm6rD4yiMRD2")), Rota.FirebasePointsDictionary(geohash: "swxp7w358v", lat: 37.8718756, lon: 32.4989669, title: "Mevlana Cd. 31–39", subtitle: "Karatay/Konya", relatedUser: Optional("7HE51jnztEaW8iHVgm6rD4yiMRD2")), Rota.FirebasePointsDictionary(geohash: "swtcfejn99", lat: 36.8877208, lon: 30.7027403, title: "21. Sk.", subtitle: "Muratpasa/Antalya", relatedUser: Optional("7HE51jnztEaW8iHVgm6rD4yiMRD2")), Rota.FirebasePointsDictionary(geohash: "swtcc8usz3", lat: 36.87506, lon: 30.658356, title: "600. Sk. 1", subtitle: "Konyaaltı/Antalya", relatedUser: Optional("7HE51jnztEaW8iHVgm6rD4yiMRD2")), Rota.FirebasePointsDictionary(geohash: "swg6964cze", lat: 38.419506, lon: 27.1293471, title: "Cumhuriyet Blv. 14", subtitle: "Konak/İzmir", relatedUser: Optional("7HE51jnztEaW8iHVgm6rD4yiMRD2")), Rota.FirebasePointsDictionary(geohash: "sws5tqvenz", lat: 37.215367, lon: 28.363556, title: "Cumhuriyet Meydani", subtitle: "Muğla/Muğla", relatedUser: Optional("7HE51jnztEaW8iHVgm6rD4yiMRD2"))], didSaveTrip:{})
//            
//    }
//}
