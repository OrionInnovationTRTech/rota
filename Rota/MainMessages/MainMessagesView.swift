//
//  MainMessagesView.swift
//  Rota
//
//  Created by Batuhan Doğan on 15.07.2022.
//

import SwiftUI
import SDWebImageSwiftUI

class MainMessagesViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var messagesViewUser: MessagesViewUser?
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
    func handleSingOut() {
        isCurrentlyUserLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
    }
}

struct MainMessagesView: View {
    
    @State var shouldShowLogOutOptions = false
    @State var shouldNavigateToChatLogView = false
    @ObservedObject private var messagesViewModel = MainMessagesViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                customNavBar
                messagesView
                
                NavigationLink("", isActive: $shouldNavigateToChatLogView) {
                    ChatLogView(messagesViewUser: messageViewUser)
                }
            }
            .overlay(
                newMessageButton.padding(.bottom, 11), alignment: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationBarHidden(true)
        }
    }
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            WebImage(url: URL(string: messagesViewModel.messagesViewUser?.profileImageURL ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .cornerRadius(10)
                .clipped()
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
            Text(messagesViewModel.messagesViewUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? "")
                .font(.system(size: 24, weight: .bold))
            Spacer()
            Button {
                self.shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
            }
        }
        .padding()
        .actionSheet(isPresented: $shouldShowLogOutOptions) {
            .init(title: Text("Settings"), message: Text("What do you want to do?"), buttons: [
                .destructive(Text("Sign Out"), action: {
                    print("Handle sign out")
                    messagesViewModel.handleSingOut()
                }),
                .cancel()
            ])
        }
        .fullScreenCover(isPresented: $messagesViewModel.isCurrentlyUserLoggedOut) {
            AuthView(didCompleteLoginProcess: {
                self.messagesViewModel.isCurrentlyUserLoggedOut = false
                self.messagesViewModel.fetchCurrentUser()
            })
        }
    }
    
    private var messagesView: some View {
        ScrollView {
            ForEach(0..<10, id: \.self) { num in
                VStack {
                    NavigationLink {
                        ChatLogView(messagesViewUser: messageViewUser)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .padding(8)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
                            VStack(alignment: .leading) {
                                Text("Username")
                                    .font(.system(size: 17, weight: .bold))
                                Text("Message sent to user")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(.lightGray))
                                
                            }
                            Spacer()
                            Text("22d")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal)
                    }
                    Divider()
                        .padding(.vertical, 7)
                }
                .padding(.top, 1)
            }
            .padding(.bottom, 55)
        }
    }
    
    @State var shouldShowCreateMessageScreen = false
    @State var messageViewUser: MessagesViewUser?
    
    private var newMessageButton: some View {
        Button(action: {
            shouldShowCreateMessageScreen.toggle()
        }, label: {
            VStack{
                HStack {
                    Text("New Message")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "square.and.pencil")
                        //.frame(width: 20, height: 20)
                        .font(.system(size: 18, weight: .bold))
                }
                .padding(.horizontal)
            }
            .foregroundColor(.white)
            .padding(.vertical)
            .background(.blue)
            .cornerRadius(10)
            .padding(.horizontal)
        })
        .padding(.bottom)
        .fullScreenCover(isPresented: $shouldShowCreateMessageScreen) {
            CreateMessageView(didSelectUser: {user in
                self.shouldNavigateToChatLogView.toggle()
                self.messageViewUser = user
            })
        }
    }
}

struct MainMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
            .previewInterfaceOrientation(.portrait)
//        MainMessagesView()
//            .preferredColorScheme(.dark)
            
    }
}
