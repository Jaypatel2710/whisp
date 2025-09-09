import SwiftUI

struct FriendsView: View {
    let username: String
    @Binding var friends: [Friend]
    @Binding var errorMessage: String
    @Binding var isLoading: Bool
    
    let onAddFriend: (String) -> Void
    let onRefreshFriends: () -> Void
    let onSelectFriend: (String) -> Void
    let onLogout: () -> Void
    
    @State private var newFriendUsername = ""
    @State private var showingAddFriend = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Hello, \(username)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(friends.count) friends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Logout") {
                    onLogout()
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Divider()
                .padding(.vertical, 10)
            
            // Add Friend Section
            HStack(spacing: 12) {
                TextField("Add friend by username", text: $newFriendUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        if !newFriendUsername.isEmpty {
                            onAddFriend(newFriendUsername)
                            newFriendUsername = ""
                        }
                    }
                
                Button("Add") {
                    if !newFriendUsername.isEmpty {
                        onAddFriend(newFriendUsername)
                        newFriendUsername = ""
                    }
                }
                .disabled(newFriendUsername.isEmpty || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            // Refresh Button
            HStack {
                Button("Refresh") {
                    onRefreshFriends()
                }
                .disabled(isLoading)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
            
            // Loading Indicator
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            }
            
            // Friends List
            if friends.isEmpty && !isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No friends yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add friends by their username to start messaging")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 50)
            } else {
                List(friends) { friend in
                    FriendRow(
                        friend: friend,
                        onTap: {
                            onSelectFriend(friend.username)
                        }
                    )
                }
                .listStyle(PlainListStyle())
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .onAppear {
            onRefreshFriends()
        }
    }
}

struct FriendRow: View {
    let friend: Friend
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(friend.online ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundColor(friend.online ? .green : .secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(friend.online ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
