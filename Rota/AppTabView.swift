//
//  AppTabView.swift
//  Rota
//
//  Created by Batuhan Doğan on 25.07.2022.
//

import SwiftUI
class AppTabViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var messagesViewUser: FirebaseUser?
    @Published var isCurrentlyUserLoggedOut = false
    init() {
        DispatchQueue.main.async {
            self.isCurrentlyUserLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
    }
    func fetchCurrentUser() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        self.errorMessage = "\(uid)"
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let err = error {
                self.errorMessage = "Failed to fetch current user: \(err.localizedDescription)"
                print("Failed to fetch current user: \(err.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found"
                return
            }
            
            self.messagesViewUser = .init(data: data)
        }
    }
}
struct AppTabView: View {
    @ObservedObject private var appTabViewModel = AppTabViewModel()
    var body: some View {
        TabView {
            SearchTripView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .padding(.top, 8)
                .padding(.bottom, 1)
                .navigationBarTitle("Back")
                .navigationBarHidden(true)
            
            AddTripView()
                .tabItem {
                    Label("Add", systemImage: "plus")
                }
                .padding(.top, 8)
                .padding(.bottom, 1)
                .navigationBarTitle("Back")
                .navigationBarHidden(true)
            
            MainMessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message")
                }
                .padding(.top, 8)
                .padding(.bottom, 1)
                .navigationBarTitle("Back")
                .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $appTabViewModel.isCurrentlyUserLoggedOut) {
            AuthView(didCompleteLoginProcess: {
                self.appTabViewModel.isCurrentlyUserLoggedOut = false
                self.appTabViewModel.fetchCurrentUser()
            })
        }
    }
}

struct AppTabView_Previews: PreviewProvider {
    static var previews: some View {
        AppTabView()
    }
}
