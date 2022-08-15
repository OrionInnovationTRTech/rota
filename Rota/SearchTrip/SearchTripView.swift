//
//  SearchTripView.swift
//  Rota
//
//  Created by Batuhan Doğan on 25.07.2022.
//

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import SDWebImageSwiftUI

class SearchTripViewModel: ObservableObject {
    @Published var trips: [FirebaseTrip] = []
    @Published var errorMessage = ""
    
    @Published var pointsCoordinateArr: [CLLocationCoordinate2D] = []
    @Published var pointsTitleArr: [String] = []
    @Published var pointsSubtitleArr: [String] = []
    
    @Published var tripsPlaceArr: [[CLPlacemark]] = []
    @Published var users: [String: FirebaseUser] = [:]
    @Published var count = 0
    @Published var searchLocationManager = LocationManager()
    
    @Published var passengerCount = 0
    
    func fetchTrips(completionHandler: @escaping () -> Void) {
        self.trips = []
        FirebaseManager.shared.firestore.collection("trips")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch users: \(error)"
                    print("Failed to fetch users: \(error)")
                    return
                }
                self.count = 0
                snapshot?.documents.forEach({ queryDocumentSnapshot in
                    if let trip = try? queryDocumentSnapshot.data(as: FirebaseTrip.self) {
                        self.trips.append(trip)
                        self.fetchUser(publisher: trip.publisher) { user in
                            self.users[trip.publisher] = user
                            self.count += 1
                            print("count \(self.count) trip count \(self.trips.count)")
                            if self.count == self.trips.count {
                                completionHandler()
                            }
                        }
                    }
                })
                self.errorMessage = "Fetched users successfully"
            }
    }
    
    func fetchUser(publisher: String, completion: @escaping (_ user: FirebaseUser) -> Void) {
        FirebaseManager.shared.firestore.collection("users")
            .document(publisher)
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

struct SearchTripView: View {
    @State var tripDay = Date()
    @State var shouldShowSearchLocationView = false
    @StateObject var startingLocationManager = LocationManager()
    @StateObject var destinationLocationManager = LocationManager()
    
    @ObservedObject var searchTripViewModel = SearchTripViewModel()
    
    @State var shouldShowTrips = false
    @State var tripsPointsTitle: [[String]] = []
    @State var tripsPointsSubtitle: [[String]] = []
    
    
    @State var choosenPointsCoordinate: [CLLocationCoordinate2D] = []
    @State var choosenPointsTitle: [String] = []
    @State var choosenPointsSubtitle: [String] = []
    
    @State var headerHeight: CGFloat = 0
    @State var headerOffset: CGFloat = 0
    @State var lastHeaederOffset: CGFloat = 0
    @State var direction: SwipeDirection = .none
    @State var shiftOffset: CGFloat = 0
    
    @State var users: [FirebaseUser] = []
    
    @State var tripsData: [FirebaseTrip] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Search Trips")
                .font(.largeTitle.bold())
                .padding(.bottom)
            VStack {
                NavigationLink {
                    NavigationView {
                        SearchLocationView(locationManager: startingLocationManager)
                            .navigationBarTitle("", displayMode: .inline)
                            .navigationBarHidden(true)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .foregroundColor(Color(.label))
                        
                        if let place = startingLocationManager.pickedPlacemark {
                            HStack {
                                Text(place.name ?? "Choose Starting Point")
                                    .foregroundColor(.gray)
                                Text("\(place.locality ?? "")/\(place.administrativeArea ?? "")")
                                    .font(.caption.bold())
                                    .foregroundColor(.gray)
                            }
                            
                        } else {
                            Text("Choose Starting Point")
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                
                Divider()
                    .padding(.horizontal)
                
                NavigationLink {
                    NavigationView {
                        SearchLocationView(locationManager: destinationLocationManager)
                            .navigationBarTitle("", displayMode: .inline)
                            .navigationBarHidden(true)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(Color(.label))
                        
                        if let place = destinationLocationManager.pickedPlacemark {
                            HStack {
                                Text(place.name ?? "Choose Destination")
                                    .foregroundColor(.gray)
                                Text("\(place.locality ?? "")/\(place.administrativeArea ?? "")")
                                    .font(.caption.bold())
                                    .foregroundColor(.gray)
                            }
                            
                        } else {
                            Text("Choose Destination")
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                
                Divider()
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "calendar")
                    DatePicker("", selection: $tripDay, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding()
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
            }
            
            Button {
                self.tripsPointsTitle = []
                self.tripsPointsSubtitle = []
                self.users = []
                searchTripViewModel.fetchTrips {
                    for trip in searchTripViewModel.trips {
                        var titles: [String] = []
                        var subtitles: [String] = []
                        titles.append(trip.shortestPointsDictArray["start"]!.title)
                        subtitles.append(trip.shortestPointsDictArray["start"]!.subtitle)
                        titles.append(trip.shortestPointsDictArray["destination"]!.title)
                        subtitles.append(trip.shortestPointsDictArray["destination"]!.subtitle)
                        self.tripsPointsTitle.append(titles)
                        self.tripsPointsSubtitle.append(subtitles)
                        self.users.append(searchTripViewModel.users[trip.publisher]!)
                        self.tripsData.append(trip)
                    }
                    shouldShowTrips.toggle()
                }
            } label: {
                Text("Search Trips")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.blue)
                    }
                    .foregroundColor(.white)
                    .padding(.top)
            }.fullScreenCover(isPresented: $shouldShowTrips) {
                tripsView
            }
            
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    var tripsView: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                tripsViewTrips
                    .padding(.top, self.headerHeight)
                    .offsetY { previous, current in
                        if previous > current && current < 0 {
                            if direction != .up {
                                shiftOffset = current - headerOffset
                                direction = .up
                                lastHeaederOffset = headerOffset
                            }
                            let offset = current < 0 ? (current - shiftOffset) : 0
                            headerOffset = (-offset < headerHeight ? (offset < 0 ? offset : 0): -headerHeight)
                        } else {
                            if direction != .down {
                                shiftOffset = current
                                direction = .down
                                lastHeaederOffset = headerOffset
                            }
                            
                            let offset = lastHeaederOffset + (current - shiftOffset)
                            headerOffset = (offset > 0 ? 0 : offset)
                        }
                    }
            }
            .coordinateSpace(name: "SCROLL")
            .overlay(alignment: .top) {
                tripsViewHeaderButton
                    .anchorPreference(key: HeaderBoundsKey.self, value: .bounds){$0}
                    .overlayPreferenceValue(HeaderBoundsKey.self) { value in
                        GeometryReader { proxy in
                            if let anchor = value {
                                Color.clear
                                    .onAppear {
                                        self.headerHeight = proxy[anchor].height
                                    }
                            }
                        }
                    }
                    .offset(y: -headerOffset < headerHeight ? headerOffset: (headerOffset < 0 ? headerOffset : 0))
            }
            .ignoresSafeArea(.all, edges: .top)
            
            .navigationBarTitle("Back", displayMode: .inline)
            .navigationBarHidden(true)
        }
    }
    
    var tripsViewTrips: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<searchTripViewModel.trips.count, id: \.self) { i in
                
                NavigationButton(action: {
                    var coordinates: [CLLocationCoordinate2D] = []
                    var titles: [String] = []
                    var subtitles: [String] = []
                    
                    coordinates.append(CLLocationCoordinate2D(latitude: searchTripViewModel.trips[i].shortestPointsDictArray["start"]!.lat, longitude: searchTripViewModel.trips[i].shortestPointsDictArray["start"]!.lon))
                    titles.append(searchTripViewModel.trips[i].shortestPointsDictArray["start"]!.title)
                    subtitles.append(searchTripViewModel.trips[i].shortestPointsDictArray["start"]!.subtitle)
                    
                    coordinates.append(self.startingLocationManager.pickedLocation!)
                    titles.append("\(self.startingLocationManager.pickedPlacemark?.locality ?? "")/\(self.startingLocationManager.pickedPlacemark?.administrativeArea ?? "")")
                    subtitles.append(self.startingLocationManager.pickedPlacemark?.locality ?? "")
                    
                    coordinates.append(self.destinationLocationManager.pickedLocation!)
                    titles.append("\(self.destinationLocationManager.pickedPlacemark?.locality ?? "")/\(self.destinationLocationManager.pickedPlacemark?.administrativeArea ?? "")")
                    subtitles.append(self.destinationLocationManager.pickedPlacemark?.locality ?? "")
                    
                    searchTripViewModel.passengerCount = searchTripViewModel.trips[i].shortestPointsDictArray.keys.filter{$0.contains("passenger")}.count-1
                    
                    print("psg count : \(searchTripViewModel.passengerCount)")
                    print("coo count : \(coordinates.count)")
                    if searchTripViewModel.passengerCount != 0 {
                        for _ in 0...searchTripViewModel.passengerCount {
                            coordinates.append(self.destinationLocationManager.pickedLocation!)
                            titles.append("\(self.destinationLocationManager.pickedPlacemark?.locality ?? "")/\(self.destinationLocationManager.pickedPlacemark?.administrativeArea ?? "")")
                            subtitles.append(self.destinationLocationManager.pickedPlacemark?.locality ?? "")
                        }
                    }
                    
                    print("coo count : \(coordinates.count)")
                    
                    var index = 0
                    
                    for key in searchTripViewModel.trips[i].shortestPointsDictArray.keys {
                        if key.contains("passenger") {
                            index = Int(key.components(separatedBy: "passenger")[1])!
                            index = (index % 10 != 1 ? index/10*2-1 : index/10*2) + 2
                            print("index asd \(index)")
                            coordinates[index] = (CLLocationCoordinate2D(latitude: searchTripViewModel.trips[i].shortestPointsDictArray[key]!.lat, longitude: searchTripViewModel.trips[i].shortestPointsDictArray[key]!.lon))
                            titles[index] = (searchTripViewModel.trips[i].shortestPointsDictArray[key]!.title)
                            subtitles[index] = (searchTripViewModel.trips[i].shortestPointsDictArray[key]!.subtitle)
                        }
                    }
                    
                    
                    print("coo count : \(coordinates.count)")

                    for key in searchTripViewModel.trips[i].shortestPointsDictArray.keys {
                        if key.contains("step") {
                            coordinates.append(CLLocationCoordinate2D(latitude: searchTripViewModel.trips[i].shortestPointsDictArray[key]!.lat, longitude: searchTripViewModel.trips[i].shortestPointsDictArray[key]!.lon))
                            titles.append(searchTripViewModel.trips[i].shortestPointsDictArray[key]!.title)
                            subtitles.append(searchTripViewModel.trips[i].shortestPointsDictArray[key]!.subtitle)
                        }
                    }
                    
                    coordinates.append(CLLocationCoordinate2D(latitude: searchTripViewModel.trips[i].shortestPointsDictArray["destination"]!.lat, longitude: searchTripViewModel.trips[i].shortestPointsDictArray["destination"]!.lon))
                    titles.append(searchTripViewModel.trips[i].shortestPointsDictArray["destination"]!.title)
                    subtitles.append(searchTripViewModel.trips[i].shortestPointsDictArray["destination"]!.subtitle)
                    
                    searchTripViewModel.pointsCoordinateArr = coordinates
                    searchTripViewModel.pointsTitleArr = titles
                    searchTripViewModel.pointsSubtitleArr = subtitles
                }, destination: {
                    CreateRouteView(placeArray: [], placeTitleArray: searchTripViewModel.pointsTitleArr, placeSubtitleArray: searchTripViewModel.pointsSubtitleArr, passengerCount: searchTripViewModel.passengerCount, pointsArray: searchTripViewModel.pointsCoordinateArr, tripData: self.tripsData[i], startingLocationManager: self.startingLocationManager, destinationLocationManager: self.destinationLocationManager)
                }, label: {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                    .foregroundColor(Color(.label))
                                Text(tripsPointsTitle[i][0])
                                    .foregroundColor(.gray)
                                Text(tripsPointsSubtitle[i][0])
                                    .font(.caption.bold())
                                    .foregroundColor(.gray)
                            }
                            Divider()
                            HStack(spacing: 10) {
                                Image(systemName: "stop.fill")
                                    .foregroundColor(Color(.label))
                                Text(tripsPointsTitle[i].last!)
                                    .foregroundColor(.gray)
                                Text(tripsPointsSubtitle[i].last!)
                                    .font(.caption.bold())
                                    .foregroundColor(.gray)
                            }
                            Divider()
                            HStack(spacing: 16) {
                                WebImage(url: URL(string: self.users[i].profileImageURL))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(10)
                                    .clipped()
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
                                Text("\(self.users[i].name ?? self.users[i].email)")
                                    .foregroundColor(Color(.label))
                                Spacer()
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                    }
                    .padding(.vertical)
                })
            }
        }
        .padding()
    }
    
    var tripsViewHeaderButton: some View {
        Button {
            shouldShowTrips.toggle()
        } label: {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "chevron.left")
                    Spacer()
                    if let startPlace = startingLocationManager.pickedPlacemark {
                        Text("\(startPlace.subLocality ?? "Choose Starting Point"), \(startPlace.locality ?? "")/\(startPlace.administrativeArea ?? "")")
                    }
                    Image(systemName: "arrow.right.to.line")
                    if let endPlace = destinationLocationManager.pickedPlacemark {
                        Text("\(endPlace.subLocality ?? "Choose Starting Point"), \(endPlace.locality ?? "")/\(endPlace.administrativeArea ?? "")")
                    }
                }
                .lineLimit(1)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.blue)
                }
                .padding(.bottom)
                .foregroundColor(.white)
                Divider()
                    .padding(.horizontal, -15)
            }
            .padding(.horizontal, 15)
            .padding(.top, safeArea().top)
            .background(.white)
        }
    }
}

struct SearchTripView_Previews: PreviewProvider {
    static var previews: some View {
        SearchTripView()
    }
}

struct NavigationButton<Destination: View, Label: View>: View {
    var action: () -> Void = { }
    var destination: () -> Destination
    var label: () -> Label

    @State private var isActive: Bool = false

    var body: some View {
        Button(action: {
            self.action()
            self.isActive.toggle()
        }) {
            self.label()
              .background(
                ScrollView { // Fixes a bug where the navigation bar may become hidden on the pushed view
                    NavigationLink(destination: LazyDestination { self.destination() },
                                                 isActive: self.$isActive) { EmptyView() }
                }
              )
        }
    }
}

// This view lets us avoid instantiating our Destination before it has been pushed.
struct LazyDestination<Destination: View>: View {
    var destination: () -> Destination
    var body: some View {
        self.destination()
    }
}

enum SwipeDirection {
    case up
    case down
    case none
}
