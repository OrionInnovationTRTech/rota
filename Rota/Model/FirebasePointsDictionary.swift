//
//  FirebasePointsDictionary.swift
//  Rota
//
//  Created by Batuhan Doğan on 7.08.2022.
//

import Foundation

struct FirebasePointsDictionary: Decodable {
    let geohash: String
    let lat: Double
    let lon: Double
    let title: String
    let subtitle: String
}
