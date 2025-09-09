import SwiftUI

struct ChatView: View {
    let selectedFriend: String
    let messages: [Message]
    let onSendMessage: (String) -> Void
    let onBackToFriends: () -> Void
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Back") {
                    onBackToFriends()
                }
                .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(selectedFriend)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Ephemeral chat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button("Send") {
                    sendMessage()
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        onSendMessage(trimmedText)
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: Message
    
    private var isFromMe: Bool {
        message.from == "me"
    }
    
    private var timestamp: String {
        let date = Date(timeIntervalSince1970: TimeInterval(message.timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack {
            if isFromMe {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                HStack {
                    if !isFromMe {
                        Text(message.from)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(timestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.text ?? "")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isFromMe ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(isFromMe ? .white : .primary)
            }
            
            if !isFromMe {
                Spacer(minLength: 50)
            }
        }
    }
}
