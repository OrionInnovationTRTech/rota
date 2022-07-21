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

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    let messagePadding = 10
}

struct ChatMessage: Identifiable {
    var id: String { documentId }
    var documentId: String
    var fromId, toId, text: String
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
    }
}

class ChatLogViewModel: ObservableObject {
    @Published var messageText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    let messagesViewUser: MessagesViewUser?
    init(messagesViewUser: MessagesViewUser?) {
        self.messagesViewUser = messagesViewUser
        fetchMessages()
    }
    func handleSend() {
        print(messageText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        guard let toId = messagesViewUser?.uid else {return}
        
        let document = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [FirebaseConstants.fromId: fromId, FirebaseConstants.toId: toId, FirebaseConstants.text: self.messageText, "timestamp": Timestamp()] as [String: Any]
        
        document.setData(messageData) { error in
            if let error = error {
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
        }
        print("Successfully saved sending message on current user")
        messageText = ""
        
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
    }
    
    private func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        guard let toId = messagesViewUser?.uid else {return}
        FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                    }
                })
            }
    }
}

struct ChatLogView: View {
    let messagesViewUser: MessagesViewUser?
    init(messagesViewUser: MessagesViewUser?) {
        self.messagesViewUser = messagesViewUser
        self.chatLogViewModel = .init(messagesViewUser: messagesViewUser)
    }
    @ObservedObject var chatLogViewModel: ChatLogViewModel
    var body: some View {
        ZStack{
            messagesDisplay
            Text(chatLogViewModel.errorMessage)
        }
        .navigationTitle(messagesViewUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
    private var messagesDisplay: some View {
        VStack {
            ScrollView {
                ForEach(chatLogViewModel.chatMessages) { message in
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

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView {
//            ChatLogView(messagesViewUser: .init(data: ["uid": "7HE51jnztEaW8iHVgm6rD4yiMRD2", "email": "test5@gmail.com"]))
//        }
        MainMessagesView()
        .preferredColorScheme(.light)
        
    }
}
