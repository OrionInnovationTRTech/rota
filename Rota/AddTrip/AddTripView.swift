//
//  AddTripView.swift
//  Rota
//
//  Created by Batuhan Doğan on 28.07.2022.
//

import SwiftUI
import MapKit

struct AddTripView: View {
    @State var statusMessage = ""
    @State var tripDay = Date()
    @State var shouldShowSearchLocationView = false
    @StateObject var startingLocationManager = LocationManager()
    @StateObject var destinationLocationManager = LocationManager()
    @StateObject var stepLocationManager = LocationManager()
    
    @State var count = 0
    
    @State var showAddTargetMessage = false
    @State var showCreateRouteMessage = false

    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Add New Trip")
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
                    
                    ForEach(0..<self.count, id: \.self) { i in
                        NavigationLink {
                            NavigationView {
                                SearchLocationView(locationManager: stepLocationManager, index: i)
                                    .navigationBarTitle("", displayMode: .inline)
                                    .navigationBarHidden(true)
                            }
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "target")
                                    .foregroundColor(Color(.label))
                                
                                if i < stepLocationManager.stepPlacemarkArr?.count ?? 0 {
                                    HStack {
                                        if let place = stepLocationManager.stepPlacemarkArr?[i] {
                                            Text(place.name ?? "Choose Step Point")
                                                .foregroundColor(.gray)
                                            Text("\(place.locality ?? "")/\(place.administrativeArea ?? "")")
                                                .font(.caption.bold())
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                } else {
                                    Text("Choose Step Point")
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button {
                                    if i < stepLocationManager.stepPlacemarkArr?.count ?? 0 {
                                        stepLocationManager.stepPlacemarkArr?.remove(at: i)
                                        stepLocationManager.stepLocationArr?.remove(at: i)
                                    }
                                    count -= 1
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }

                            }
                            .padding()
                        }
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    
                    
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
                }
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                }
                
                Button {
                    if !(startingLocationManager.pickedLocation == nil || stepLocationManager.stepPlacemarkArr?.count != count) {
                        self.count += 1
                        self.showAddTargetMessage = false
                    } else {
                        self.showAddTargetMessage = true
                    }
                } label: {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(Color(.label))
                            Text("Add step point")
                                .foregroundColor(Color(.darkGray))
                        }
                        if self.showAddTargetMessage {
                            if startingLocationManager.pickedLocation == nil {
                                Text("(Please choose the starting point)")
                                    .foregroundColor(.red)
                                    .lineLimit(0)
                            }
                            
                            if stepLocationManager.stepPlacemarkArr?.count != count {
                                Text("(Please choose the step point)")
                                    .foregroundColor(.red)
                                
                            }
                        }
                    }
                    .padding()
                }

                
                
                
                HStack {
                    Image(systemName: "calendar")
                    DatePicker("", selection: $tripDay, in: Date()...)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
                }
                .padding(.top)
                
                
                NavigationLink {
                    if let locationStart = startingLocationManager.pickedLocation, let locationEnd = destinationLocationManager.pickedLocation, let placemarkStart = startingLocationManager.pickedPlacemark, let placemarkEnd = destinationLocationManager.pickedPlacemark, let stepPlaceArray = stepLocationManager.stepPlacemarkArr, let stepLocationArr = stepLocationManager.stepLocationArr {
                        
                        CreateRouteView(placeArray: [placemarkStart] + stepPlaceArray + [placemarkEnd], pointsArray: [locationStart] + stepLocationArr + [locationEnd], tripDate: tripDay, didSaveTrip: {
                            self.startingLocationManager.pickedLocation = nil
                            self.startingLocationManager.pickedPlacemark = nil
                            
                            self.destinationLocationManager.pickedLocation = nil
                            self.destinationLocationManager.pickedPlacemark = nil
                            
                            self.stepLocationManager.pickedLocation = nil
                            self.stepLocationManager.pickedPlacemark = nil
                            
                            self.stepLocationManager.stepLocationArr = nil
                            self.stepLocationManager.stepPlacemarkArr = nil
                            
                            self.count = 0
                        })
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    
                } label: {
                    if startingLocationManager.pickedLocation != nil && destinationLocationManager.pickedLocation != nil {
                        Text("Create Route")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.blue)
                            }
                            .foregroundColor(.white)
                        
                    } else {
                        VStack(spacing: 0) {
                            Text("Create Route")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.init(white: 0.9, alpha: 1)))
                                }
                                .foregroundColor(.gray)
                        }
                        .opacity(0.7)
                    }
                }
                .padding(.top)
                .disabled(startingLocationManager.pickedLocation == nil && destinationLocationManager.pickedLocation == nil)

            }
            .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

struct AddTripView_Previews: PreviewProvider {
    static var previews: some View {
        AddTripView()
    }
}

