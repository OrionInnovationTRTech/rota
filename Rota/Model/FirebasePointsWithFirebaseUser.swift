//
//  FirebasePointsWithFirebaseUser.swift
//  Rota
//
//  Created by Batuhan Doğan on 16.08.2022.
//

import Foundation

struct FirebasePointsWithFirebaseUser {
    let geohash: String
    let lat: Double
    let lon: Double
    let title: String
    let subtitle: String
    let relatedUser: FirebaseUser?
}
