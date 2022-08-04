//
//  FirebaseTrip.swift
//  Rota
//
//  Created by Batuhan Doğan on 4.08.2022.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift

struct FirebaseTrip: Codable, Identifiable {
    @DocumentID var id: String?
    
    let publisher, pointsArray: String
    let distance: Float
    let tripDate, timestamp: Date
    
    init(data: [String: Any]) {
        self.publisher = data["publisher"] as? String ?? ""
        self.pointsArray = data["pointsArray"] as? String ?? ""
        self.distance = data["distance"] as? Float ?? 0
        self.tripDate = data["tripDate"] as? Date ?? Date()
        self.timestamp = data["timestamp"] as? Date ?? Date()
    }
}
