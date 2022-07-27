//
//  SearchLocationView.swift
//  MapTestProject
//
//  Created by Batuhan Doğan on 25.07.2022.
//

import SwiftUI
import MapKit

struct SearchLocationView: View {
    @StateObject var locationManager: LocationManager = .init()
    @State var navigationTag: String?
    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                TextField("Find locations here", text: $locationManager.searchText)
                Button {
                    locationManager.searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(Color(.label))
                }

            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
            }
            .padding(.vertical, 10)
            
            if let places = locationManager.fetchedPlaces, !places.isEmpty {
                List {
                    ForEach(places, id: \.self) { place in
                        Button {
                            if let coordinate = place.location?.coordinate{
                                locationManager.pickedLocation = .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                locationManager.mapView.region = .init(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                                locationManager.addDraggablePin(coordinate: coordinate)
                                locationManager.updatePlacemark(location: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
                            }
                            navigationTag = "MAPVIEW"
                        } label: {
                            HStack(spacing: 15) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(place.name ?? "")
                                        .font(.title3.bold())
                                    Text(place.locality ?? "")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                    }
                }
            } else {
                Button {
                    if let coordinate = locationManager.userLocation?.coordinate{
                        locationManager.mapView.region = .init(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                        locationManager.addDraggablePin(coordinate: coordinate)
                        locationManager.updatePlacemark(location: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
                        
                        navigationTag = "MAPVIEW"
                    }
                } label: {
                    Label {
                        Text("Use current location")
                            .font(.callout)
                    } icon: {
                        Image(systemName: "location.north.circle.fill")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            }

        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            NavigationLink(tag: "MAPVIEW", selection: $navigationTag) {
                MapViewSelection()
                    .environmentObject(locationManager)
            } label: {}
                .labelsHidden()

        }
    }
}

struct SearchLocationView_Previews: PreviewProvider {
    static var previews: some View {
        SearchLocationView()
            .preferredColorScheme(.light)
    }
}

struct MapViewSelection: View {
    @EnvironmentObject var locationManager: LocationManager
    @State var navigationTag: String?
    var body: some View {
        ZStack{
            MapViewHelper()
                .environmentObject(locationManager)
                .ignoresSafeArea()

            if let place = locationManager.pickedPlacemark {
                
                VStack(spacing: 0) {
            
                    VStack {
                        Button {
                            locationManager.pickedPlacemark = nil
                            locationManager.pickedLocation = nil
                            
                            locationManager.mapView.removeAnnotations(locationManager.mapView.annotations)
                            
                            if let coordinate = locationManager.userLocation?.coordinate{
                                locationManager.mapView.region = .init(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                                locationManager.addDraggablePin(coordinate: coordinate)
                                locationManager.updatePlacemark(location: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
                                
                                navigationTag = "MAPVIEW"
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title2.bold())
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.white)
                                }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    VStack(spacing: 15) {
                        Text("Confirm Location")
                            .font(.title2.bold())
                        HStack(spacing: 15) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(place.name ?? "")
                                    .font(.title3.bold())
                                Text(place.locality ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        
                        Button  {
                            
                        } label: {
                            Text("Confirm Location")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.blue)
                                }
                                .overlay(alignment: .trailing) {
                                    Image(systemName: "arrow.right")
                                        .font(.title3.bold())
                                        .padding(.trailing)
                                }
                                .foregroundColor(.white)
                        }

                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white)
                            .ignoresSafeArea()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .onDisappear {
            locationManager.pickedPlacemark = nil
            locationManager.pickedLocation = nil
            
            locationManager.mapView.removeAnnotations(locationManager.mapView.annotations)
        }
    }
}

struct MapViewHelper: UIViewRepresentable {
    @EnvironmentObject var locationManager: LocationManager
    func makeUIView(context: Context) -> MKMapView {
        return locationManager.mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
    }
}
