//
//  SearchBar.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.secondary)
            
            TextField("Search note...", text: $text)
                .font(.custom("HelveticaNeue", size: 16))
                .foregroundStyle(Color.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("Colors/CardBackground"))
        )
        .animation(.default, value: text.isEmpty)
    }
}

#Preview {
    SearchBar(text: .constant(""))
        .padding()
}
