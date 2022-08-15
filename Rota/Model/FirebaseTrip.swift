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
import CoreLocation

struct FirebaseTrip: Decodable, Identifiable {
    @DocumentID var id: String?
    let publisher: String
    var shortestPointsDictArray: [String: FirebasePointsDictionary]
    let distance: Float
    let tripDate, timestamp: Date
}
