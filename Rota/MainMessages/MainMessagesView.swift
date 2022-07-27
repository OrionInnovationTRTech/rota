//
//  MainMessagesView.swift
//  Rota
//
//  Created by Batuhan Doğan on 15.07.2022.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift

class MainMessagesViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var messagesViewUser: MessagesViewUser?
    @Published var isCurrentlyUserLoggedOut = false
    @Published var recentMessages = [RecentMessage]()
    
    init() {
        DispatchQueue.main.async {
            self.isCurrentlyUserLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        fetchRecentMessages()
    }
    
    private var firestoreListener: ListenerRegistration?
    
    func fetchRecentMessages() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        self.firestoreListener?.remove()
        self.recentMessages.removeAll()
        
        firestoreListener = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .order(by: FirebaseConstants.timestamp)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for recent messages: \(error)"
                    print(error)
                    return
                }
                querySnapshot?.documentChanges.forEach({ change in
                    let documentId = change.document.documentID
                    
                    if let index = self.recentMessages.firstIndex(where: { rm in
                        return rm.id == documentId
                    }) {
                        self.recentMessages.remove(at: index)
                    }
                    
                    if let rm = try? change.document.data(as: RecentMessage.self) {
                        self.recentMessages.insert(rm, at: 0)
                    }
                })
            }
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
    private var chatLogViewModel = ChatLogViewModel(messagesViewUser: nil)
    
    var body: some View {
        NavigationView {
            VStack {
                customNavBar
                messagesView
                
                NavigationLink("", isActive: $shouldNavigateToChatLogView) {
                    ChatLogView(chatLogViewModel: chatLogViewModel)
                }
            }
            .overlay(
                newMessageButton.padding(.bottom, 11), alignment: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
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
                self.messagesViewModel.fetchRecentMessages()
            })
        }
    }
    
    private var messagesView: some View {
        ScrollView {
            ForEach(messagesViewModel.recentMessages) { recentMessage in
                VStack {
                    Button {
                        let uid = FirebaseManager.shared.auth.currentUser?.uid == recentMessage.fromId ? recentMessage.toId : recentMessage.fromId
                        self.messageViewUser = .init(data: [FirebaseConstants.email: recentMessage.email, FirebaseConstants.profileImageURL: recentMessage.profileImageURL, FirebaseConstants.uid: uid])
                        self.chatLogViewModel.messagesViewUser = self.messageViewUser
                        self.chatLogViewModel.fetchMessages()
                        self.shouldNavigateToChatLogView.toggle()
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: recentMessage.profileImageURL))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .cornerRadius(12.8)
                                .clipped()
                                .overlay(RoundedRectangle(cornerRadius: 12.8).stroke(Color(.label), lineWidth: 1.5))
                            VStack(alignment: .leading, spacing: 8) {
                                Text(recentMessage.username)
                                    .font(.system(size: 17, weight: .bold))
                                Text(recentMessage.text)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(.darkGray))
                                
                            }
                            Spacer()
                            Text(recentMessage.timeAgo)
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
        .fullScreenCover(isPresented: $shouldShowCreateMessageScreen) {
            CreateMessageView(didSelectUser: {user in
                self.shouldNavigateToChatLogView.toggle()
                self.messageViewUser = user
                self.chatLogViewModel.messagesViewUser = user
                self.chatLogViewModel.fetchMessages()
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
