import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var page = 0
    @State private var showEmailAuth = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            TabView(selection: $page) {
                hookScreen.tag(0)
                signInScreen.tag(1)
                rateSetupScreen.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                dotsIndicator
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
        }
    }

    // Screen 1
    private var hookScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Every minute costs\nyou something.")
                .font(.system(size: 28, design: .monospaced, weight: .bold))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("Spent shows you the real cost\nof your screen time.")
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()

            Button {
                withAnimation { page = 1 }
            } label: {
                Text("Start Free Trial")
                    .font(.system(size: 16, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primary)
                    .foregroundStyle(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 32)
    }

    // Screen 2
    private var signInScreen: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 6) {
                categoryRow(symbol: "chart.line.uptrend.xyaxis", label: "INVESTED", description: "earns credit", color: .green)
                categoryRow(symbol: "dollarsign.circle", label: "SPENT", description: "costs money", color: .red)
                categoryRow(symbol: "minus.circle", label: "NEUTRAL", description: "shown free", color: .secondary)
            }
            .padding(.horizontal, 32)

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                appVM.auth.handleAppleSignIn(result: result)
                if appVM.auth.isSignedIn { withAnimation { page = 2 } }
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 50)
            .padding(.horizontal, 32)

            Button {
                showEmailAuth = true
            } label: {
                Text("Use email instead")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 80)
        }
    }

    private func categoryRow(symbol: String, label: String, description: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 12, design: .monospaced, weight: .bold))
            Text("—")
                .foregroundStyle(.secondary)
            Text(description)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // Screen 3
    private var rateSetupScreen: some View {
        @Bindable var appVM = appVM
        return VStack(spacing: 20) {
            Spacer()

            Text("Set your rate")
                .font(.system(size: 22, design: .monospaced, weight: .bold))

            modePicker
            rateInputs

            Spacer()

            Button {
                Task {
                    await appVM.screenTime.requestAuthorization()
                    await appVM.initialize()
                }
            } label: {
                Text("Grant Access")
                    .font(.system(size: 16, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primary)
                    .foregroundStyle(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var modePicker: some View {
        let isStudent = appVM.settings.userMode.isStudent
        Picker("Mode", selection: Binding(
            get: { isStudent },
            set: { newVal in
                appVM.updateSettings { s in
                    s.userMode = newVal ? .student(currentGPA: 3.5, scale: .deviceDefault) : .standard(hourlyRate: s.wage)
                }
            }
        )) {
            Text("Standard").tag(false)
            Text("Student").tag(true)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var rateInputs: some View {
        if appVM.settings.userMode.isStudent {
            Text("We'll track your GPA impact, not your wages")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 12) {
                HStack {
                    Text("Wage ($)")
                        .font(.system(size: 13, design: .monospaced))
                    Spacer()
                    TextField("20.00", value: Binding(
                        get: { appVM.settings.wage },
                        set: { v in appVM.updateSettings { $0.wage = v } }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 100)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Picker("Period", selection: Binding(
                    get: { appVM.settings.ratePeriod },
                    set: { v in appVM.updateSettings { $0.ratePeriod = v } }
                )) {
                    ForEach(SpentSettings.RatePeriod.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var dotsIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(page == i ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut, value: page)
            }
        }
    }
}

struct EmailAuthView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .font(.system(size: 15, design: .monospaced))
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                SecureField("Password", text: $password)
                    .font(.system(size: 15, design: .monospaced))
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if let error {
                    Text(error)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        isLoading = true
                        do {
                            if isSignUp {
                                try await appVM.auth.signUpWithEmail(email, password: password)
                            } else {
                                try await appVM.auth.signInWithEmail(email, password: password)
                            }
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .font(.system(size: 16, design: .monospaced, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.primary)
                .foregroundStyle(.background)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button {
                    isSignUp.toggle()
                } label: {
                    Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
