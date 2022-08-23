//
//  YourTripsID.swift
//  Rota
//
//  Created by Batuhan Doğan on 18.08.2022.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift

struct YourTripsID: Codable, Identifiable {
    @DocumentID var id: String?
    let trip_id: String
}
