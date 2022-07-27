//
//  SearchTripView.swift
//  Rota
//
//  Created by Batuhan Doğan on 25.07.2022.
//

import SwiftUI

struct SearchTripView: View {
    @State var tripDay = Date()
    @State var shouldShowSearchLocationView = false
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                NavigationLink {
                    SearchLocationView()
                        .navigationBarTitle("", displayMode: .inline)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .foregroundColor(Color(.label))
                        Text("Choose Starting Point")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                }
                
                Divider()
                    .padding(.horizontal)
                
                NavigationLink {
                    SearchLocationView()
                        .navigationBarTitle("", displayMode: .inline)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(Color(.label))
                        Text("Choose Destination")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                }
                
                Divider()
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "calendar")
                    DatePicker("", selection: $tripDay, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding()
                
                
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.gray)
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationBarHidden(true)
        }
        .navigationBarHidden(true)
    }
}

struct SearchTripView_Previews: PreviewProvider {
    static var previews: some View {
        SearchTripView()
    }
}
