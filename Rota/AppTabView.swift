//
//  AppTabView.swift
//  Rota
//
//  Created by Batuhan Doğan on 25.07.2022.
//

import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            SearchTripView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .padding(.bottom, 1)
            
            MainMessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message")
                }
                .padding(.bottom, 1)
        }
    }
}

struct AppTabView_Previews: PreviewProvider {
    static var previews: some View {
        AppTabView()
    }
}
