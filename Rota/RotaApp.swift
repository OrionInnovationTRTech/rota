//
//  RotaApp.swift
//  Rota
//
//  Created by Batuhan Doğan on 13.07.2022.
//

import SwiftUI

@main
struct RotaApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                AppTabView()
            }
            .navigationBarHidden(true)
        }
    }
}
