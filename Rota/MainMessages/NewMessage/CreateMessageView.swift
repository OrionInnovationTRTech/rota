//
//  CreateMessageView.swift
//  Rota
//
//  Created by Batuhan Doğan on 19.07.2022.
//

import SwiftUI
import SDWebImageSwiftUI

class CreateMessageViewModel: ObservableObject {
    @Published var users = [MessagesViewUser]()
    @Published var errorMessage = ""
    
    init() {
        fetchAllUsers()
    }
    
    private func fetchAllUsers() {
        FirebaseManager.shared.firestore.collection("users")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch users: \(error)"
                    print("Failed to fetch users: \(error)")
                    return
                }
                
                snapshot?.documents.forEach({ queryDocumentSnapshot in
                    let data = queryDocumentSnapshot.data()
                    let user = MessagesViewUser(data: data)
                    if user.uid != FirebaseManager.shared.auth.currentUser?.uid {
                        self.users.append(.init(data: data))
                    }
                })
                
                self.errorMessage = "Fetched users successfully"
            }
    }
}

struct CreateMessageView: View {
    
    let didSelectUser: (MessagesViewUser) -> ()
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var createMessageViewModel = CreateMessageViewModel()
    var body: some View {
        NavigationView {
            ScrollView {
                ForEach(createMessageViewModel.users) { user in
                    Button {
                        didSelectUser(user)
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: user.profileImageURL))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .cornerRadius(10)
                                .clipped()
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.label), lineWidth: 1.5))
                            Text(user.email)
                                .foregroundColor(Color(.label))
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    Divider()
//                        .padding(.vertical, 2)
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
            }
        } 
    }
}

struct CreateMessageView_Previews: PreviewProvider {
    static var previews: some View {
//        CreateMessageView(didSelectUser: {})
        MainMessagesView()
    }
}
