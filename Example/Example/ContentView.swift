import SwiftUI
import WellspentSDK

struct ContentView: View {
    @State 
    private var userId: String = UserDefaults.standard.string(forKey: "userId") ?? ""
    
    @State
    private var isUserIdStored: Bool = UserDefaults.standard.string(forKey: "userId") != nil

    @State
    private var errorMessage: String?

    func handleSDKErrors(_ closure: () throws -> ()) {
        do {
            errorMessage = nil
            try closure()
        } catch {
            errorMessage = "\(error)"
        }
    }

    func handleAsyncSDKErrors(_ closure: () async throws -> ()) async {
        do {
            errorMessage = nil
            try await closure()
        } catch {
            errorMessage = "\(error)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("B2B Partner App:")
                .font(.title)
                .padding(.top, 20)
            
            Text(
            """
            Here are the steps to follow:
            1. Tap Configure
            2. Enter your user id and then tap identify - you won't be able to edit your user id after tapping identify.
            3. Tap present onboarding - this shows the app clip.
            4. Tap complete daily habit - emulates the success criteria.
            """
            )
            .font(.caption)
            .padding(.bottom, 20)

            if let errorMsg = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")

                    Text(errorMsg)
                        .padding()

                    Button(
                        action: {
                            errorMessage = nil
                        },
                        label: {
                            Image(systemName: "xmark")
                        }
                    )
                }
                .foregroundColor(.red)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }

            Button(
                action: {
                    handleSDKErrors {
                        try WellspentSDK.shared.configure(
                            with: WellspentSDKConfiguration(
                                partnerId: "example",
                                localizedAppName: "Babbel",
                                redirectionURL: URL(string: "dailyWisdom://daily")!,
                                isUsingUniversalLinks: false
                            )
                        )
                    }
                },
                label: {
                    Label(
                        title: { Text("Configure") },
                        icon: { Image(systemName: "wrench.adjustable") }
                    )

                }
            )

            HStack {
                TextField(
                    text: $userId,
                    label: {
                        Text("Enter your user ID")
                    }
                )
                .disabled(isUserIdStored)

                Button(
                    action: {
                        
                        handleSDKErrors {
                            if !isUserIdStored {
                                let trimmedUserId = userId.replacingOccurrences(of: " ", with: "")
                                UserDefaults.standard.set(trimmedUserId, forKey: "userId")
                                userId = trimmedUserId
                            }
                            try WellspentSDK.shared.identify(as: userId)
                        }
                    },
                    label: {
                        Label(
                            title: { Text("Identify") },
                            icon: { Image(systemName: "person") }
                        )
                    }
                )
                .disabled(userId.isEmpty)
            }

            Button(
                action: {
                    errorMessage = nil
                    WellspentSDK.shared.presentOnboarding { error in
                        if let error {
                            errorMessage = "\(error)"
                        }
                    }
                },
                label: {
                    Label(
                        title: { Text("Present Onboarding") },
                        icon: { Image(systemName: "play.circle") }
                    )
                }
            )

            Button(
                action: {
                    Task {
                        await handleAsyncSDKErrors {
                            try await WellspentSDK.shared.completeDailyHabit()
                        }
                    }
                },
                label: {
                    Label(
                        title: { Text("Complete Daily Habit") },
                        icon: { Image(systemName: "checkmark.square.fill") }
                    )
                }
            )

            Spacer()

            Divider()

            Button(
                role: .destructive,
                action: {
                    WellspentSDK.shared.logout()
                },
                label: {
                    Label(
                        title: { Text("Logout") },
                        icon: { Image(systemName: "power") }
                    )
                }
            )

            Spacer()
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
}

#Preview {
    ContentView()
}
