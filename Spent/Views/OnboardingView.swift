import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var page = 0
    @State private var showEmailSignIn = false
    @State private var showEmailSignUp = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            TabView(selection: $page) {
                hookScreen.tag(0)
                rateSetupScreen.tag(1)
                signInScreen.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                dotsIndicator
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailAuthView(startInSignUpMode: false)
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailAuthView(startInSignUpMode: true)
        }
    }

    // Screen 1
    private var hookScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Every minute costs\nyou something.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
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
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
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

            if let authError = appVM.auth.authError {
                Text(authError)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                appVM.auth.handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 50)
            .padding(.horizontal, 32)

            Button {
                showEmailSignUp = true
            } label: {
                Text("Create Account with Email")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 32)

            Button {
                showEmailSignIn = true
            } label: {
                Text("Already have an account? Sign in")
                    .font(.system(size: 12, design: .monospaced))
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
                .font(.system(size: 12, weight: .bold, design: .monospaced))
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
                .font(.system(size: 22, weight: .bold, design: .monospaced))

            modePicker
            rateInputs

            Spacer()

            Button {
                withAnimation { page = 2 }
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
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
                withAnimation(.easeInOut(duration: 0.25)) {
                    appVM.updateSettings { s in
                        s.userMode = newVal ? .student(currentGPA: 3.5, scale: .deviceDefault) : .standard(hourlyRate: s.wage)
                    }
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
            VStack(spacing: 12) {
                HStack {
                    Text("Current GPA")
                        .font(.system(size: 13, design: .monospaced))
                    Spacer()
                    TextField("3.5", value: Binding(
                        get: { appVM.settings.currentGPA },
                        set: { v in appVM.updateSettings { $0.currentGPA = v } }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 80)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                HStack {
                    Text("Session length")
                        .font(.system(size: 13, design: .monospaced))
                    Spacer()
                    Stepper("\(appVM.settings.studentSessionMinutes) min", value: Binding(
                        get: { appVM.settings.studentSessionMinutes },
                        set: { v in appVM.updateSettings { $0.studentSessionMinutes = v } }
                    ), in: 15...120, step: 5)
                    .font(.system(size: 13, design: .monospaced))
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
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
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
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
    var startInSignUpMode: Bool = false

    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp: Bool
    @State private var isLoading = false
    @State private var error: String?

    init(startInSignUpMode: Bool = false) {
        self.startInSignUpMode = startInSignUpMode
        _isSignUp = State(initialValue: startInSignUpMode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .font(.system(size: 15, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))

                        Divider()

                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .font(.system(size: 15, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if let error {
                        Text(error)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            isLoading = true
                            error = nil
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
                        Group {
                            if isLoading {
                                ProgressView().tint(Color(.systemBackground))
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primary)
                    .foregroundStyle(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        withAnimation { isSignUp.toggle() }
                        error = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Create one")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, design: .monospaced))
                }
            }
        }
        .fontDesign(.monospaced)
    }
}
