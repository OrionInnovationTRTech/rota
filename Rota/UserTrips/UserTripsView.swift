//
//  UserTripsView.swift
//  Rota
//
//  Created by Batuhan Doğan on 15.08.2022.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift
import SDWebImageSwiftUI

class UserTripsViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var userTripsIDs = [String]()
    @Published var userTrips: [FirebaseTrip] = []
    
    @Published var tripsRelatedPointsDetails: [[String]] = []
    
    @Published var userTripsPublishers: [String: FirebaseUser] = [:]
    
    @Published var count = 0
    
    var currentUser: FirebaseUser?
    
    init(currentUser: FirebaseUser?) {
        self.currentUser = currentUser
        fetchUserTripsID {
            self.fetchUserTrips { trips in
                self.userTrips = trips
                print("trips: \(trips)")
            }
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
    
    var firestoreListener: ListenerRegistration?
    
    func fetchUserTripsID(completionHandler: @escaping () -> Void) {
        guard let currentUser = currentUser else {
            return
        }
        firestoreListener?.remove()
        userTripsIDs.removeAll()
        firestoreListener = FirebaseManager.shared.firestore.collection("users_trips")
            .document(currentUser.uid)
            .collection("your_trips")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        if let trip = try? change.document.data(as: YourTripsID.self) {
                            self.userTripsIDs.append(trip.trip_id)
                            print("Appending chatMessage")
                        }
                    }
                })
                
                DispatchQueue.main.async {
                    self.count += 1
                }
                
                completionHandler()
                
            }
    }
    
    func fetchUserTrips(completionHandler: @escaping (_ trips: [FirebaseTrip]) -> Void) {
        var trips: [FirebaseTrip] = []
        for id in userTripsIDs {
            FirebaseManager.shared.firestore.collection("trips")
                .document(id)
                .getDocument { snapshot, error in
                    if let error = error {
                        self.errorMessage = "Failed to fetch users: \(error)"
                        print("Failed to fetch users: \(error)")
                        return
                    }
                    
                    guard let trip = try? snapshot?.data(as: FirebaseTrip.self) else {
                        self.errorMessage = "No data found"
                        return
                    }
                    trips.append(trip)
                    
                    self.fetchUser(publisher: trip.publisher) { user in
                        self.userTripsPublishers[trip.publisher] = user
                        if trips.count == self.userTripsIDs.count {
                            self.getRelatedPointsDetails(trips: trips)
                            completionHandler(trips)
                        }
                    }
                    
                }
        }
    }
    
    func getRelatedPointsDetails(trips: [FirebaseTrip]) {
        guard let currentUser = currentUser else {
            return
        }
        for trip in trips {
            let pointsKeys = trip.shortestPointsDictArray.keys
            
            var tripPoints: [String] = []
            
            tripPoints.append(trip.shortestPointsDictArray["start"]!.title)
            tripPoints.append(trip.shortestPointsDictArray["destination"]!.title)
            
            for key in pointsKeys {
                if trip.shortestPointsDictArray[key]!.relatedUser == currentUser.uid {
                    if key.contains("passenger") {
                        
                        
                        let index = Int(key.components(separatedBy: "passenger")[1])!
                        if index % 10 == 0 {
                            tripPoints.insert(trip.shortestPointsDictArray[key]!.title, at: 1)
                        } else {
                            if tripPoints.count == 3 {
                                tripPoints.insert(trip.shortestPointsDictArray[key]!.title, at: 2)
                            } else {
                                tripPoints.insert(trip.shortestPointsDictArray[key]!.title, at: 1)
                            }
                        }
                    }
                }
            }
            
            self.tripsRelatedPointsDetails.append(tripPoints)
            tripPoints = []
        }
    }
    
    
}

struct UserTripsView: View {
    @ObservedObject var userTripsViewModel: UserTripsViewModel
    
    @State var imageSystemNames = ["play.fill", "figure.wave", "figure.walk", "stop.fill"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Trips")
                    .font(.largeTitle.bold())
                    .padding(.bottom)
                ForEach(0..<userTripsViewModel.tripsRelatedPointsDetails.count, id: \.self) { i in
//                    Text("\(userTripsViewModel.userTrips[i].distance)")
                    
                    VStack(alignment: .leading, spacing: 0) {
                        NavigationLink {
                            
                        } label: {
                            VStack(alignment: .leading) {
                                ForEach(0..<4, id: \.self) { j in
                                    HStack {
                                        Group {
                                            Image(systemName: imageSystemNames[j])
                                                .font(.title2)
                                            Text("\(userTripsViewModel.tripsRelatedPointsDetails[i][j])")
                                        }
                                        .foregroundColor([1, 2].contains(j) ? Color(.label) : .gray)
                                    }
                                    Divider()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }
                        
                        NavigationLink {
                            
                        } label: {
                            HStack(alignment: .center) {
                                WebImage(url: URL(string: userTripsViewModel.userTripsPublishers[userTripsViewModel.userTrips[i].publisher]!.profileImageURL))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(10)
                                    .clipped()
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
                                Text("\(userTripsViewModel.userTripsPublishers[userTripsViewModel.userTrips[i].publisher]!.name ?? userTripsViewModel.userTripsPublishers[userTripsViewModel.userTrips[i].publisher]!.email)")
                                    
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(Color(.label))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .padding(.bottom, 10)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.gray.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                                }
                            }
                        }

                        
                        NavigationLink {
                            ChatLogView(chatLogViewModel: ChatLogViewModel(messagesViewUser: userTripsViewModel.userTripsPublishers[userTripsViewModel.userTrips[i].publisher]!))
                        } label: {
                            HStack {
                                Text("Communicate with publisher")
                                    .foregroundColor(.white)
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.white)
                            }
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(.blue)
                            .cornerRadius(10)
                            .offset(y: -10)
                            .padding(.bottom, -10)
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                    }

                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UserTripsView_Previews: PreviewProvider {
    static var previews: some View {
        UserTripsView(userTripsViewModel: UserTripsViewModel(currentUser: FirebaseUser(data: ["email": "deneme@gmail.com", "name": "Deneme Deneme", "profileImageURL": "https://firebasestorage.googleapis.com:443/v0/b/rota-21e5d.appspot.com/o/6VRV5rgMwBOz0lWckJV0U9wv4wr2?alt=media&token=5997c62c-f7e3-4ecd-bb4a-eed2f3a91bfe", "uid": "6VRV5rgMwBOz0lWckJV0U9wv4wr2"])))
    }
}
