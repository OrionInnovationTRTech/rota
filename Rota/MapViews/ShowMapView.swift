//
//  ShowMapView.swift
//  Rota
//
//  Created by Batuhan Doğan on 3.08.2022.
//

import SwiftUI
import MapKit

struct ShowMapView: UIViewRepresentable {
    typealias UIViewType = MKMapView
    
    @Binding var getMapView: MKMapView
    @Binding var routeArray: [MKRoute]
    @Binding var distance: Float
    @Binding var annotationArr: [MKAnnotation]
    
    func makeCoordinator() -> MapViewCoordinator {
        return MapViewCoordinator()
    }
    
    func makeUIView(context: Context) -> MKMapView {
        self.getMapView.delegate = context.coordinator
        
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.71, longitude: -74), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        self.getMapView.setRegion(region, animated: true)
        
        drawRoute(mapView: getMapView, routeArr: routeArray, annotationArr: annotationArr) { overlayView in
            DispatchQueue.main.async {
                self.getMapView = overlayView
            }
        }
        return self.getMapView
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
