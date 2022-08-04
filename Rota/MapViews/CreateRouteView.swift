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
    
    @Published var pointsFloatArray: String?
    @Published var distance: Float?
    //@Published var directions: [Int: [String]]?
    @Published var tripDate: Date?
    
//    init(placeArray: [CLPlacemark], pointsArray: [CLLocationCoordinate2D], annotationArr: [MKAnnotation], routeArray: [MKRoute], distance: Float, directions: [Int: [String]], tripDate: Date) {
//        self.placeArray = placeArray
//        self.pointsArray = pointsArray
//        self.annotationArr = annotationArr
//        self.routeArray = routeArray
//        self.distance = distance
//        self.directions = directions
//        self.tripDate = tripDate
//        fetchCurrentUser()
//    }
    
    init() {
        fetchCurrentUser()
    }
    
    
    func handleSend() {
        guard let publisher = FirebaseManager.shared.auth.currentUser?.uid else {return}
        
        let document = FirebaseManager.shared.firestore.collection("trips")
            .document()
        
        let tripData = [FirebaseConstants.publisher: publisher, "pointsArray": self.pointsFloatArray!, "distance": self.distance!, "tripDate": self.tripDate!, FirebaseConstants.timestamp: Timestamp()] as [String : Any]
        
        document.setData(tripData) { error in
            if let error = error {
                self.errorMessage = "Failed to save trip into Firestore: \(error)"
                return
            }
        }
        print("Successfully saved trip")
        
//        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
//            .document(toId)
//            .collection(fromId)
//            .document()
//
//        recipientMessageDocument.setData(messageData) { error in
//            if let error = error {
//                self.errorMessage = "Failed to save message into Firestore: \(error)"
//                return
//            }
//            print("Recipient saved message as well")
//        }
        
        fetchCurrentUser()
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
    @State var pointsArray: [CLLocationCoordinate2D]
    
    @State var pointsFloatArray: [String: Double] = [:]
    
    @State var mapView: MKMapView = .init()
    
    @State var routeArray: [MKRoute] = []
    @State var distanceArray: [Float] = []
    @State var annotationArr: [MKAnnotation] = []
    
    @State var shouldShowPublishSheet = false
    @State var getMapView: MKMapView = .init()
    
    @State var tripDate: Date
    
    @ObservedObject var createRouteViewModel: CreateRouteViewModel = .init()
    
    var body: some View {
        NavigationView {
            ZStack {
                DirectionsMapView(distance: $distance, directions: $directions, pointsArray: $pointsArray, placeArray: $placeArray, mapView: $mapView, routeArray: $routeArray, distanceArray: $distanceArray, annotationArr: $annotationArr, pointsFloatArray: $pointsFloatArray)
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
                                if let theJSONData = try? JSONSerialization.data(
                                    withJSONObject: self.pointsFloatArray,
                                    options: []) {
                                    let theJSONText = String(data: theJSONData,
                                                               encoding: .ascii)
                                    print("JSON string = \(theJSONText!)")
                                    
                                    createRouteViewModel.pointsFloatArray = theJSONText
                                    createRouteViewModel.distance = self.distance
                                    //createRouteViewModel.directions = self.directions
                                    createRouteViewModel.tripDate = self.tripDate
                                    
                                    createRouteViewModel.handleSend()
                                }
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
                    if self.distance != 0 {
                        Text("Distance: \(String(format: "%.2f", self.distance))").fontWeight(.semibold)
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
