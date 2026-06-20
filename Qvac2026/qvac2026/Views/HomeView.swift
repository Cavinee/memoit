//
//  HomeView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI

struct HomeView: View {

    var refreshTick: Int = 0

    @StateObject private var vm = HomeViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            SearchBar(text: $vm.searchText)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            List {
                ForEach(vm.groupedNotes, id: \.title) { group in
                    Section {
                        ForEach(group.notes) { note in
                            ZStack {
                                NavigationLink(value: NoteRoute.existing(note)) { EmptyView() }
                                    .opacity(0)
                                NoteCard(note: note)
                            }
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    vm.delete(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    vm.togglePin(note)
                                } label: {
                                    Label(note.pinned ? "Unpin" : "Pin",
                                          systemImage: note.pinned ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                        }
                    } header: {
                        Text(group.title)
                            .font(.custom("HelveticaNeue", size: 13))
                            .foregroundStyle(Color.secondary)
                            .kerning(1.0)
                            .textCase(nil)
                            .padding(.leading, 20)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { vm.refresh() }
        .task(id: refreshTick) {
            vm.refresh()
        }
    }

    private var titleHeader: some View {
        HStack(alignment: .center) {
            Text("Notes")
                .font(.custom("HelveticaNeue-Bold", size: 34))
                .foregroundStyle(Color.primary)

            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
