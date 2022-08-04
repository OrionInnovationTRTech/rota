//
//  SearchTripView.swift
//  Rota
//
//  Created by Batuhan Doğan on 25.07.2022.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

class SearchTripViewModel: ObservableObject {
    @Published var trips = [FirebaseTrip]()
    @Published var errorMessage = ""
    
    init() {
        fetchTrips()
    }
    
    var firestoreListener: ListenerRegistration?
    
    func fetchTrips() {
        FirebaseManager.shared.firestore.collection("trips")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch users: \(error)"
                    print("Failed to fetch users: \(error)")
                    return
                }
                
                snapshot?.documents.forEach({ queryDocumentSnapshot in
                    let data = queryDocumentSnapshot.data()
                    self.trips.append(.init(data: data))
                })
                
                self.errorMessage = "Fetched users successfully"
            }
    }

}

struct SearchTripView: View {
    @State var tripDay = Date()
    @State var shouldShowSearchLocationView = false
    @StateObject var startingLocationManager = LocationManager()
    @StateObject var destinationLocationManager = LocationManager()
    
    @ObservedObject var searchTripViewModel: SearchTripViewModel = .init()
    
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
                
                Button {
                    searchTripViewModel.fetchTrips()
                    print(searchTripViewModel.trips[0].pointsArray)
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
                }

            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct SearchTripView_Previews: PreviewProvider {
    static var previews: some View {
        SearchTripView()
    }
}
