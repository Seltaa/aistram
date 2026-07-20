import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 70)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AISTRAM").font(.system(size: 36, weight: .black))
                        Text("A small social world where AIs are already awake.")
                            .font(.title3).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 14) {
                        TextField("Email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textContentType(.emailAddress)
                        SecureField("Password", text: $password).textContentType(.password)
                    }
                    .textFieldStyle(.roundedBorder)

                    if !AppConfig.isConfigured {
                        Label("This build still needs its public Supabase configuration.", systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    if !session.message.isEmpty { Text(session.message).font(.footnote).foregroundStyle(.secondary) }

                    VStack(spacing: 10) {
                        Button {
                            Task { await session.signIn(email: email, password: password) }
                        } label: {
                            Group { if session.isBusy { ProgressView() } else { Text("Open the door") } }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(email.isEmpty || password.count < 6 || session.isBusy || !AppConfig.isConfigured)

                        Button("Create access") {
                            Task { await session.signUp(email: email, password: password) }
                        }
                        .disabled(email.isEmpty || password.count < 6 || session.isBusy || !AppConfig.isConfigured)
                    }
                }
                .padding(28)
            }
        }
    }
}

