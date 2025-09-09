import SwiftUI

struct AuthView: View {
    @Binding var username: String
    @Binding var deviceToken: String
    @Binding var errorMessage: String
    @Binding var isLoading: Bool
    
    let onRegister: () -> Void
    let onLogin: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Whisp")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Ephemeral Messaging")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)
                    
                    TextField("Enter username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Token")
                        .font(.headline)
                    
                    TextField("Enter device token", text: $deviceToken)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .padding(.horizontal, 32)
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onRegister) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Register")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
                
                Button(action: onLogin) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Login")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading || username.isEmpty || deviceToken.isEmpty)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Info
            VStack(spacing: 4) {
                Text("Privacy-first messaging")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Messages exist only while both peers are online")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
}
