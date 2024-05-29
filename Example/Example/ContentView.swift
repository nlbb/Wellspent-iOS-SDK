import SwiftUI
import WellspentSDK

struct ContentView: View {
    @State
    private var userId = "123"

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

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()

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
                                localizedAppName: "DailyWisdom",
                                redirectionURL: URL(string: "dailyWisdom://daily")!
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
                        Text("User ID")
                    }
                )

                Button(
                    action: {
                        handleSDKErrors {
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
