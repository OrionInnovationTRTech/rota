//
//  MessagesViewUser.swift
//  Rota
//
//  Created by Batuhan Doğan on 15.07.2022.
//

import Foundation

struct FirebaseUser: Identifiable {
    var id: String {uid}
    
    let uid, email, profileImageURL: String
    let name: String?
    
    init(data: [String: Any]) {
        self.uid = data["uid"] as? String ?? ""
        self.name = data["name"] as? String? ?? ""
        self.email = data["email"] as? String ?? ""
        self.profileImageURL = data["profileImageURL"] as? String ?? ""
    }
}
