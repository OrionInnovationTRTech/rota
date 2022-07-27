//
//  ChatLogView.swift
//  Rota
//
//  Created by Batuhan Doğan on 20.07.2022.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

class ChatLogViewModel: ObservableObject {
    @Published var count = 0
    @Published var messageText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    
    var messagesViewUser: MessagesViewUser?
    
    @Published var currentUser: MessagesViewUser?
    
    init(messagesViewUser: MessagesViewUser?) {
        self.messagesViewUser = messagesViewUser
        fetchMessages()
    }
    
    var firestoreListener: ListenerRegistration?
    
    func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        guard let toId = messagesViewUser?.uid else {return}
        firestoreListener?.remove()
        chatMessages.removeAll()
        firestoreListener = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: FirebaseConstants.timestamp)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        if let msg = try? change.document.data(as: ChatMessage.self) {
                            self.chatMessages.append(msg)
                            print("Appending chatMessage")
                        }
                    }
                })
                DispatchQueue.main.async {
                    self.count += 1
                }
                
            }
    }
    
    func handleSend() {
        print(messageText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        guard let toId = messagesViewUser?.uid else {return}
        
        let document = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [FirebaseConstants.fromId: fromId, FirebaseConstants.toId: toId, FirebaseConstants.text: self.messageText, FirebaseConstants.timestamp: Timestamp()] as [String: Any]
        
        document.setData(messageData) { error in
            if let error = error {
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
        }
        print("Successfully saved sending message on current user")
        
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            print("Recipient saved message as well")
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
            
            self.currentUser = .init(data: data)
            self.persistRecentMessage()
            self.messageText = ""
        }
    }
    
    private func persistRecentMessage() {
        guard let messagesViewUser = messagesViewUser else {
            return
        }
        
        guard let currentUser = currentUser else {
            print("Error on current user")
            return
        }
        
        let uid = currentUser.uid
        
        let toId = messagesViewUser.uid
        
        let document = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.text: messageText,
            FirebaseConstants.profileImageURL: messagesViewUser.profileImageURL,
            FirebaseConstants.email: messagesViewUser.email
        ] as [String : Any]
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message: \(error)"
                print("Failed to save recent message: \(error)")
                return
            }
        }
        
        print("Successfully saved recent message on current user")
        
        let recipientDocument = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(toId)
            .collection("messages")
            .document(uid)
        
        let recipientData = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.text: messageText,
            FirebaseConstants.profileImageURL: currentUser.profileImageURL,
            FirebaseConstants.email: currentUser.email
        ] as [String : Any]
        
        recipientDocument.setData(recipientData) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message: \(error)"
                print("Failed to save recent message: \(error)")
                return
            }
        }
        
        print("Successfully saved recent message on recipient user")
    }
}

struct ChatLogView: View {
//    let messagesViewUser: MessagesViewUser?
//    init(messagesViewUser: MessagesViewUser?) {
//        self.messagesViewUser = messagesViewUser
//        self.chatLogViewModel = .init(messagesViewUser: messagesViewUser)
//    }
    @ObservedObject var chatLogViewModel: ChatLogViewModel
    var body: some View {
        messagesDisplay
        .navigationTitle(chatLogViewModel.messagesViewUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            self.chatLogViewModel.firestoreListener?.remove()
        }
    }
    private var messagesDisplay: some View {
        VStack {
            ScrollView {
                ScrollViewReader { scrollViewProxy in
                    VStack {
                        ForEach(chatLogViewModel.chatMessages) { message in
                            MessageView(message: message)
                        }
                        HStack { Spacer() }
                            .id("Empty")
                    }
                    .onReceive(chatLogViewModel.$count) { _ in
                        withAnimation(.easeOut(duration: 0.5)) {
                            scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                        }
                    }
                }
                
            }
            .background(Color(.init(white: 0.95, alpha: 1)))
            .safeAreaInset(edge: .bottom) {
                chatBottomBar
                    .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
        
    }
    
    private var chatBottomBar: some View {
        HStack {
            Image(systemName: "plus.square")
                .font(.system(size: 24))
                .foregroundColor(Color(.label))
            ZStack(alignment: .leading) {
                Text("Description")
                    .padding(.horizontal, 4)
                TextEditor(text: $chatLogViewModel.messageText)
                    .opacity(chatLogViewModel.messageText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            Button {
                chatLogViewModel.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(5)

        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct MessageView: View {
    let message: ChatMessage
    var body: some View {
        VStack {
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
                HStack{
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                HStack{
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(.white)
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView {
//            ChatLogView(messagesViewUser: .init(data: ["uid": "7HE51jnztEaW8iHVgm6rD4yiMRD2", "email": "test5@gmail.com"]))
//        }
        MainMessagesView()
        .preferredColorScheme(.light)
        
    }
}
