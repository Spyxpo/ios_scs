# SCS iOS SDK

The official iOS SDK for Spyxpo Cloud Services (SCS) - a comprehensive Backend-as-a-Service platform.

## Features

- **Authentication** - User registration, login, profile management, and role-based access
- **Database** - NoSQL document database with collections, subcollections, and advanced queries
- **Storage** - File upload, download, and management
- **Realtime Database** - Real-time data synchronization with WebSocket support
- **Cloud Messaging** - Push notifications with topics and device token management
- **Remote Configuration** - Dynamic app configuration without deployments
- **Cloud Functions** - Serverless function invocation
- **Machine Learning** - Text recognition (OCR) and image labeling
- **AI Services** - Chat, text completion, and image generation

## Requirements

- iOS 14.0+ / macOS 12.0+ / tvOS 14.0+ / watchOS 7.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AstroX11/scs-ios.git", from: "1.0.0")
]
```

Or in Xcode:
1. File > Add Packages...
2. Enter the repository URL
3. Select the version and add to your target

## Quick Start

### Initialize the SDK

```swift
import SCS

// In your AppDelegate or App struct
Scs.initialize(config: ScsConfig(
    apiKey: "your-api-key",
    projectId: "your-project-id",
    baseUrl: "https://your-scs-instance.com"
))
```

### Get the SDK Instance

```swift
let scs = Scs.shared
```

## Authentication

### Register a New User

```swift
do {
    let user = try await scs.auth.register(
        email: "user@example.com",
        password: "securePassword123",
        displayName: "John Doe",
        customData: ["role": "member"]
    )
    print("Registered: \(user.email)")
} catch {
    print("Registration failed: \(error)")
}
```

### Login

```swift
do {
    let user = try await scs.auth.login(
        email: "user@example.com",
        password: "password"
    )
    print("Logged in: \(user.displayName ?? "")")
} catch {
    print("Login failed: \(error)")
}
```

### Observe Auth State

```swift
import Combine

var cancellables = Set<AnyCancellable>()

scs.auth.currentUserPublisher
    .sink { user in
        if let user = user {
            print("User logged in: \(user.email)")
        } else {
            print("User logged out")
        }
    }
    .store(in: &cancellables)
```

### Logout

```swift
scs.auth.logout()
```

### OAuth and Social Sign-In

SCS provides comprehensive OAuth and social authentication support for iOS. Each provider requires specific setup and credentials.

---

#### Google Sign-In

Authenticate users with their Google accounts using Google Sign-In SDK.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `idToken` | `String` | Yes | Google ID token from Google Sign-In SDK |
| `accessToken` | `String?` | No | Google access token for additional API access |

**Setup Requirements:**
1. Add [GoogleSignIn SDK](https://developers.google.com/identity/sign-in/ios/start-integrating) via SPM
2. Configure your OAuth client ID in Google Cloud Console
3. Add URL scheme to Info.plist

**Complete Implementation:**

```swift
import GoogleSignIn

class GoogleAuthManager {
    private let scs = Scs.shared

    func signIn(presenting viewController: UIViewController) async throws -> ScsUser {
        // Configure Google Sign-In
        guard let clientID = Bundle.main.infoDictionary?["GIDClientID"] as? String else {
            throw AuthError.configurationError("Missing Google Client ID")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Perform Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken("Google ID token not available")
        }

        let accessToken = result.user.accessToken.tokenString

        // Sign in with SCS
        let user = try await scs.auth.signInWithGoogle(
            idToken: idToken,
            accessToken: accessToken
        )

        return user
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        scs.auth.logout()
    }
}

// Usage in SwiftUI
struct GoogleSignInButton: View {
    @StateObject private var authManager = GoogleAuthManager()
    @State private var error: Error?

    var body: some View {
        Button("Sign in with Google") {
            Task {
                do {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let rootVC = windowScene.windows.first?.rootViewController else { return }
                    let user = try await authManager.signIn(presenting: rootVC)
                    print("Signed in: \(user.email)")
                } catch {
                    self.error = error
                }
            }
        }
    }
}
```

---

#### Facebook Sign-In

Authenticate users with their Facebook accounts using Facebook SDK.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `accessToken` | `String` | Yes | Facebook access token from Facebook SDK |

**Setup Requirements:**
1. Add [Facebook SDK](https://developers.facebook.com/docs/ios/getting-started) via SPM
2. Configure Facebook App ID in Info.plist
3. Add Facebook URL scheme

**Complete Implementation:**

```swift
import FacebookLogin
import FacebookCore

class FacebookAuthManager {
    private let scs = Scs.shared
    private let loginManager = LoginManager()

    func signIn(from viewController: UIViewController) async throws -> ScsUser {
        return try await withCheckedThrowingContinuation { continuation in
            loginManager.logIn(permissions: ["public_profile", "email"], from: viewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result, !result.isCancelled else {
                    continuation.resume(throwing: AuthError.cancelled)
                    return
                }

                guard let accessToken = AccessToken.current?.tokenString else {
                    continuation.resume(throwing: AuthError.missingToken("Facebook access token not available"))
                    return
                }

                Task {
                    do {
                        let user = try await self.scs.auth.signInWithFacebook(accessToken: accessToken)
                        continuation.resume(returning: user)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func signOut() {
        loginManager.logOut()
        scs.auth.logout()
    }
}

// Usage
let facebookAuth = FacebookAuthManager()
let user = try await facebookAuth.signIn(from: viewController)
```

---

#### Apple Sign-In

Native Sign in with Apple integration - the recommended authentication method for iOS apps.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `identityToken` | `String` | Yes | Apple identity token (JWT) |
| `authorizationCode` | `String?` | No | Authorization code for server verification |
| `fullName` | `String?` | No | User's full name (only available on first sign-in) |

**Setup Requirements:**
1. Enable "Sign in with Apple" capability in Xcode
2. Configure App ID in Apple Developer Portal

**Complete Implementation:**

```swift
import AuthenticationServices

class AppleAuthManager: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let scs = Scs.shared
    private var continuation: CheckedContinuation<ScsUser, Error>?

    func signIn() async throws -> ScsUser {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthError.invalidCredential)
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthError.missingToken("Apple identity token not available"))
            return
        }

        let authorizationCode = appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        // Get full name (only available on first sign-in)
        var fullName: String?
        if let givenName = appleIDCredential.fullName?.givenName,
           let familyName = appleIDCredential.fullName?.familyName {
            fullName = "\(givenName) \(familyName)"
        }

        Task {
            do {
                let user = try await scs.auth.signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    fullName: fullName
                )
                continuation?.resume(returning: user)
            } catch {
                continuation?.resume(throwing: error)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }
}

// SwiftUI Usage
struct AppleSignInButton: View {
    @StateObject private var authManager = AppleAuthManager()

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            Task {
                do {
                    let user = try await authManager.signIn()
                    print("Signed in: \(user.email)")
                } catch {
                    print("Error: \(error)")
                }
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
    }
}
```

---

#### GitHub Sign-In

Authenticate users with their GitHub accounts using OAuth.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | `String` | Yes | OAuth authorization code from GitHub |
| `redirectUri` | `String?` | No | Redirect URI (must match OAuth app config) |

**Complete Implementation:**

```swift
import AuthenticationServices

class GitHubAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let scs = Scs.shared
    private let clientId: String
    private let redirectUri: String

    init(clientId: String, redirectUri: String) {
        self.clientId = clientId
        self.redirectUri = redirectUri
    }

    func signIn() async throws -> ScsUser {
        // Step 1: Get authorization code via OAuth
        let authURL = URL(string: "https://github.com/login/oauth/authorize?client_id=\(clientId)&redirect_uri=\(redirectUri)&scope=user:email")!

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: URL(string: redirectUri)?.scheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.missingCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }

        // Step 2: Exchange code for SCS authentication
        let user = try await scs.auth.signInWithGitHub(
            code: code,
            redirectUri: redirectUri
        )

        return user
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// Usage
let githubAuth = GitHubAuthManager(
    clientId: "your-github-client-id",
    redirectUri: "yourapp://github/callback"
)
let user = try await githubAuth.signIn()
```

---

#### Twitter/X Sign-In

Authenticate users with their Twitter/X accounts using OAuth 1.0a.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `oauthToken` | `String` | Yes | Twitter OAuth token |
| `oauthTokenSecret` | `String` | Yes | Twitter OAuth token secret |

**Complete Implementation:**

```swift
import AuthenticationServices

class TwitterAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let scs = Scs.shared
    private let consumerKey: String
    private let callbackURL: String

    init(consumerKey: String, callbackURL: String) {
        self.consumerKey = consumerKey
        self.callbackURL = callbackURL
    }

    func signIn() async throws -> ScsUser {
        // Step 1: Get request token from your backend
        let requestToken = try await getRequestToken()

        // Step 2: Authorize with Twitter
        let authURL = URL(string: "https://api.twitter.com/oauth/authorize?oauth_token=\(requestToken.oauthToken)")!

        let (oauthToken, oauthVerifier) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String), Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: URL(string: callbackURL)?.scheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let oauthToken = components.queryItems?.first(where: { $0.name == "oauth_token" })?.value,
                      let oauthVerifier = components.queryItems?.first(where: { $0.name == "oauth_verifier" })?.value else {
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }

                continuation.resume(returning: (oauthToken, oauthVerifier))
            }

            session.presentationContextProvider = self
            session.start()
        }

        // Step 3: Exchange for access token via your backend
        let accessToken = try await exchangeForAccessToken(oauthToken: oauthToken, oauthVerifier: oauthVerifier)

        // Step 4: Sign in with SCS
        let user = try await scs.auth.signInWithTwitter(
            oauthToken: accessToken.token,
            oauthTokenSecret: accessToken.secret
        )

        return user
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }

    // Implement these methods to communicate with your backend
    private func getRequestToken() async throws -> (oauthToken: String, oauthTokenSecret: String) {
        // Call your backend to get request token
        fatalError("Implement backend call")
    }

    private func exchangeForAccessToken(oauthToken: String, oauthVerifier: String) async throws -> (token: String, secret: String) {
        // Call your backend to exchange for access token
        fatalError("Implement backend call")
    }
}
```

---

#### Microsoft Sign-In

Authenticate users with their Microsoft accounts using MSAL.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `accessToken` | `String` | Yes | Microsoft access token from MSAL |
| `idToken` | `String?` | No | Microsoft ID token for additional claims |

**Setup Requirements:**
1. Add [MSAL SDK](https://github.com/AzureAD/microsoft-authentication-library-for-objc) via SPM
2. Register app in Azure Portal
3. Configure redirect URI

**Complete Implementation:**

```swift
import MSAL

class MicrosoftAuthManager {
    private let scs = Scs.shared
    private var application: MSALPublicClientApplication?
    private let clientId: String
    private let redirectUri: String

    init(clientId: String, redirectUri: String) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        setupMSAL()
    }

    private func setupMSAL() {
        do {
            let config = MSALPublicClientApplicationConfig(clientId: clientId)
            config.redirectUri = redirectUri
            application = try MSALPublicClientApplication(configuration: config)
        } catch {
            print("Failed to create MSAL application: \(error)")
        }
    }

    func signIn(from viewController: UIViewController) async throws -> ScsUser {
        guard let application = application else {
            throw AuthError.configurationError("MSAL not configured")
        }

        let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
        let parameters = MSALInteractiveTokenParameters(scopes: ["user.read"], webviewParameters: webviewParameters)

        let result = try await application.acquireToken(with: parameters)

        let user = try await scs.auth.signInWithMicrosoft(
            accessToken: result.accessToken,
            idToken: result.idToken
        )

        return user
    }

    func signOut() async throws {
        guard let application = application,
              let account = application.allAccounts()?.first else { return }

        try application.remove(account)
        scs.auth.logout()
    }
}

// Usage
let microsoftAuth = MicrosoftAuthManager(
    clientId: "your-azure-client-id",
    redirectUri: "msauth.com.yourapp://auth"
)
let user = try await microsoftAuth.signIn(from: viewController)
```

---

### Anonymous Authentication

Create temporary accounts for users who want to try your app without signing up. Anonymous accounts can be upgraded to permanent accounts later.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `customData` | `[String: Any]?` | No | Optional metadata to associate with the anonymous user |

**Use Cases:**
- Guest checkout in e-commerce apps
- Try-before-you-sign-up experiences
- Gradual onboarding flows
- Saving user data before requiring registration

**Complete Implementation:**

```swift
class AnonymousAuthManager {
    private let scs = Scs.shared

    /// Sign in anonymously
    func signInAnonymously(referrer: String? = nil) async throws -> ScsUser {
        var customData: [String: Any] = [:]

        if let referrer = referrer {
            customData["referrer"] = referrer
        }
        customData["createdAt"] = Date().timeIntervalSince1970
        customData["platform"] = "iOS"

        let user = try await scs.auth.signInAnonymously(
            customData: customData.isEmpty ? nil : customData
        )

        print("Anonymous user created: \(user.id)")
        return user
    }

    /// Check if current user is anonymous
    var isAnonymous: Bool {
        return scs.auth.currentUser?.isAnonymous ?? false
    }

    /// Upgrade anonymous account to permanent account with email/password
    func upgradeWithEmailPassword(email: String, password: String) async throws -> ScsUser {
        guard isAnonymous else {
            throw AuthError.notAnonymous
        }

        let user = try await scs.auth.linkProvider(
            "password",
            credentials: [
                "email": email,
                "password": password
            ]
        )

        return user
    }

    /// Upgrade anonymous account with Google
    func upgradeWithGoogle(idToken: String, accessToken: String?) async throws -> ScsUser {
        guard isAnonymous else {
            throw AuthError.notAnonymous
        }

        var credentials: [String: String] = ["idToken": idToken]
        if let accessToken = accessToken {
            credentials["accessToken"] = accessToken
        }

        let user = try await scs.auth.linkProvider(
            "google",
            credentials: credentials
        )

        return user
    }

    /// Upgrade anonymous account with Apple
    func upgradeWithApple(identityToken: String, fullName: String?) async throws -> ScsUser {
        guard isAnonymous else {
            throw AuthError.notAnonymous
        }

        var credentials: [String: String] = ["identityToken": identityToken]
        if let fullName = fullName {
            credentials["fullName"] = fullName
        }

        let user = try await scs.auth.linkProvider(
            "apple",
            credentials: credentials
        )

        return user
    }
}

// SwiftUI Usage Example
struct GuestCheckoutView: View {
    @StateObject private var authManager = AnonymousAuthManager()
    @State private var user: ScsUser?

    var body: some View {
        VStack {
            if authManager.isAnonymous {
                Text("Shopping as Guest")
                Button("Create Account to Save Progress") {
                    // Show account creation flow
                }
            }

            // Cart contents...
        }
        .task {
            if scs.auth.currentUser == nil {
                user = try? await authManager.signInAnonymously(referrer: "checkout")
            }
        }
    }
}
```

---

### Phone Number Authentication

Authenticate users with their phone numbers using SMS verification codes.

**Step 1 Parameters (sendPhoneVerificationCode):**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `phoneNumber` | `String` | Yes | Phone number in E.164 format (e.g., "+14155551234") |
| `recaptchaToken` | `String?` | No | reCAPTCHA token for abuse prevention |

**Step 2 Parameters (signInWithPhoneNumber):**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `verificationId` | `String` | Yes | Verification ID from step 1 |
| `code` | `String` | Yes | 6-digit verification code from SMS |

**Complete Implementation:**

```swift
import Combine

class PhoneAuthManager: ObservableObject {
    private let scs = Scs.shared

    @Published var verificationId: String?
    @Published var isCodeSent = false
    @Published var isVerifying = false
    @Published var error: Error?

    /// Send verification code to phone number
    func sendVerificationCode(phoneNumber: String) async throws {
        // Validate phone number format
        guard phoneNumber.hasPrefix("+") && phoneNumber.count >= 10 else {
            throw AuthError.invalidPhoneNumber
        }

        isVerifying = true
        defer { isVerifying = false }

        let verificationId = try await scs.auth.sendPhoneVerificationCode(
            phoneNumber: phoneNumber,
            recaptchaToken: nil // Add reCAPTCHA if needed
        )

        await MainActor.run {
            self.verificationId = verificationId
            self.isCodeSent = true
        }
    }

    /// Verify code and sign in
    func verifyCode(_ code: String) async throws -> ScsUser {
        guard let verificationId = verificationId else {
            throw AuthError.missingVerificationId
        }

        // Validate code format
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            throw AuthError.invalidVerificationCode
        }

        isVerifying = true
        defer { isVerifying = false }

        let user = try await scs.auth.signInWithPhoneNumber(
            verificationId: verificationId,
            code: code
        )

        await MainActor.run {
            self.isCodeSent = false
            self.verificationId = nil
        }

        return user
    }

    /// Resend verification code
    func resendCode(phoneNumber: String) async throws {
        try await sendVerificationCode(phoneNumber: phoneNumber)
    }
}

// SwiftUI Phone Auth View
struct PhoneAuthView: View {
    @StateObject private var authManager = PhoneAuthManager()
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 20) {
            if !authManager.isCodeSent {
                // Phone number input
                VStack(alignment: .leading) {
                    Text("Phone Number")
                        .font(.headline)

                    TextField("+1 (555) 123-4567", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Button("Send Verification Code") {
                    Task {
                        do {
                            try await authManager.sendVerificationCode(phoneNumber: phoneNumber)
                        } catch {
                            authManager.error = error
                            showError = true
                        }
                    }
                }
                .disabled(phoneNumber.isEmpty || authManager.isVerifying)

            } else {
                // Verification code input
                VStack(alignment: .leading) {
                    Text("Verification Code")
                        .font(.headline)
                    Text("Enter the 6-digit code sent to \(phoneNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("123456", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Button("Verify & Sign In") {
                    Task {
                        do {
                            let user = try await authManager.verifyCode(verificationCode)
                            print("Signed in: \(user.id)")
                        } catch {
                            authManager.error = error
                            showError = true
                        }
                    }
                }
                .disabled(verificationCode.count != 6 || authManager.isVerifying)

                Button("Resend Code") {
                    Task {
                        try? await authManager.resendCode(phoneNumber: phoneNumber)
                    }
                }
                .font(.caption)
            }

            if authManager.isVerifying {
                ProgressView()
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(authManager.error?.localizedDescription ?? "Unknown error")
        }
    }
}
```

---

### Custom Token Authentication

Authenticate users with custom JWT tokens generated by your backend server. This is useful for migrating existing users or implementing custom authentication flows.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `token` | `String` | Yes | Custom JWT token from your backend |

**Use Cases:**
- Migrating users from existing authentication systems
- Enterprise SSO integration
- Custom authentication flows
- Backend-initiated sessions

**Complete Implementation:**

```swift
class CustomTokenAuthManager {
    private let scs = Scs.shared
    private let backendURL: URL

    init(backendURL: URL) {
        self.backendURL = backendURL
    }

    /// Get custom token from your backend and sign in
    func signInWithCustomToken(userId: String, additionalClaims: [String: Any]? = nil) async throws -> ScsUser {
        // Step 1: Request custom token from your backend
        let token = try await requestCustomToken(userId: userId, claims: additionalClaims)

        // Step 2: Sign in with SCS
        let user = try await scs.auth.signInWithCustomToken(token)

        return user
    }

    /// Request custom token from your backend
    private func requestCustomToken(userId: String, claims: [String: Any]?) async throws -> String {
        var request = URLRequest(url: backendURL.appendingPathComponent("/auth/custom-token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["userId": userId]
        if let claims = claims {
            body["claims"] = claims
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenRequestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw AuthError.invalidTokenResponse
        }

        return token
    }
}

// Usage for enterprise SSO
class EnterpriseSSOManager {
    private let customTokenAuth: CustomTokenAuthManager

    init(backendURL: URL) {
        self.customTokenAuth = CustomTokenAuthManager(backendURL: backendURL)
    }

    /// Sign in with enterprise SSO credentials
    func signInWithSSO(ssoToken: String, employeeId: String) async throws -> ScsUser {
        // Your backend validates SSO token and returns custom SCS token
        return try await customTokenAuth.signInWithCustomToken(
            userId: employeeId,
            additionalClaims: [
                "ssoToken": ssoToken,
                "enterprise": true
            ]
        )
    }
}
```

---

### Account Linking

Link multiple authentication providers to a single user account, allowing users to sign in with any linked provider.

**linkProvider Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | `String` | Yes | Provider name ("google", "facebook", "apple", "github", "twitter", "microsoft", "password") |
| `credentials` | `[String: String]` | Yes | Provider-specific credentials |

**unlinkProvider Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | `String` | Yes | Provider name to unlink |

**Complete Implementation:**

```swift
class AccountLinkingManager {
    private let scs = Scs.shared

    /// Get currently linked providers
    var linkedProviders: [String] {
        return scs.auth.currentUser?.providers ?? []
    }

    /// Link Google account
    func linkGoogle(idToken: String, accessToken: String?) async throws -> ScsUser {
        var credentials: [String: String] = ["idToken": idToken]
        if let accessToken = accessToken {
            credentials["accessToken"] = accessToken
        }

        return try await scs.auth.linkProvider("google", credentials: credentials)
    }

    /// Link Facebook account
    func linkFacebook(accessToken: String) async throws -> ScsUser {
        return try await scs.auth.linkProvider("facebook", credentials: [
            "accessToken": accessToken
        ])
    }

    /// Link Apple account
    func linkApple(identityToken: String, fullName: String?) async throws -> ScsUser {
        var credentials: [String: String] = ["identityToken": identityToken]
        if let fullName = fullName {
            credentials["fullName"] = fullName
        }

        return try await scs.auth.linkProvider("apple", credentials: credentials)
    }

    /// Link email/password
    func linkEmailPassword(email: String, password: String) async throws -> ScsUser {
        return try await scs.auth.linkProvider("password", credentials: [
            "email": email,
            "password": password
        ])
    }

    /// Unlink a provider
    func unlinkProvider(_ provider: String) async throws -> ScsUser {
        // Ensure at least one provider remains
        guard linkedProviders.count > 1 else {
            throw AuthError.cannotUnlinkLastProvider
        }

        return try await scs.auth.unlinkProvider(provider)
    }

    /// Fetch sign-in methods for an email
    func fetchSignInMethods(email: String) async throws -> [String] {
        return try await scs.auth.fetchSignInMethodsForEmail(email)
    }
}

// SwiftUI Account Settings View
struct LinkedAccountsView: View {
    @StateObject private var linkingManager = AccountLinkingManager()
    @State private var linkedProviders: [String] = []

    let allProviders = [
        ("google", "Google", "g.circle.fill"),
        ("facebook", "Facebook", "f.circle.fill"),
        ("apple", "Apple", "apple.logo"),
        ("github", "GitHub", "chevron.left.forwardslash.chevron.right"),
        ("twitter", "Twitter/X", "at.circle.fill"),
        ("microsoft", "Microsoft", "m.circle.fill")
    ]

    var body: some View {
        List {
            Section("Linked Accounts") {
                ForEach(allProviders, id: \.0) { provider in
                    HStack {
                        Image(systemName: provider.2)
                            .foregroundColor(.blue)
                        Text(provider.1)
                        Spacer()

                        if linkedProviders.contains(provider.0) {
                            if linkedProviders.count > 1 {
                                Button("Unlink") {
                                    Task {
                                        _ = try? await linkingManager.unlinkProvider(provider.0)
                                        refreshLinkedProviders()
                                    }
                                }
                                .foregroundColor(.red)
                            } else {
                                Text("Primary")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button("Link") {
                                // Initiate provider linking flow
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshLinkedProviders()
        }
    }

    private func refreshLinkedProviders() {
        linkedProviders = linkingManager.linkedProviders
    }
}
```

---

### Password Reset & Email Verification

Handle password recovery and email verification flows.

**Complete Implementation:**

```swift
class PasswordResetManager: ObservableObject {
    private let scs = Scs.shared

    @Published var isLoading = false
    @Published var emailSent = false
    @Published var error: Error?

    /// Send password reset email
    func sendPasswordResetEmail(_ email: String) async throws {
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        isLoading = true
        defer { isLoading = false }

        try await scs.auth.sendPasswordResetEmail(email)

        await MainActor.run {
            emailSent = true
        }
    }

    /// Confirm password reset with code from email
    func confirmPasswordReset(code: String, newPassword: String) async throws {
        // Validate password strength
        guard isStrongPassword(newPassword) else {
            throw AuthError.weakPassword
        }

        isLoading = true
        defer { isLoading = false }

        try await scs.auth.confirmPasswordReset(
            code: code,
            newPassword: newPassword
        )
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func isStrongPassword(_ password: String) -> Bool {
        return password.count >= 8 &&
               password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
               password.rangeOfCharacter(from: .lowercaseLetters) != nil &&
               password.rangeOfCharacter(from: .decimalDigits) != nil
    }
}

class EmailVerificationManager: ObservableObject {
    private let scs = Scs.shared

    @Published var isLoading = false
    @Published var verificationSent = false

    /// Send email verification to current user
    func sendEmailVerification() async throws {
        guard scs.auth.currentUser != nil else {
            throw AuthError.noCurrentUser
        }

        isLoading = true
        defer { isLoading = false }

        try await scs.auth.sendEmailVerification()

        await MainActor.run {
            verificationSent = true
        }
    }

    /// Verify email with code
    func verifyEmail(code: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await scs.auth.verifyEmail(code)
    }

    /// Check if current user's email is verified
    var isEmailVerified: Bool {
        return scs.auth.currentUser?.emailVerified ?? false
    }
}

// SwiftUI Password Reset View
struct PasswordResetView: View {
    @StateObject private var resetManager = PasswordResetManager()
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var showCodeEntry = false

    var body: some View {
        VStack(spacing: 20) {
            if !showCodeEntry {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                Button("Send Reset Email") {
                    Task {
                        try? await resetManager.sendPasswordResetEmail(email)
                        showCodeEntry = true
                    }
                }
                .disabled(email.isEmpty || resetManager.isLoading)
            } else {
                TextField("Reset Code", text: $code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("New Password", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Reset Password") {
                    Task {
                        try? await resetManager.confirmPasswordReset(
                            code: code,
                            newPassword: newPassword
                        )
                    }
                }
                .disabled(code.isEmpty || newPassword.isEmpty || resetManager.isLoading)
            }

            if resetManager.isLoading {
                ProgressView()
            }
        }
        .padding()
    }
}
```

---

### Complete Authentication Service Example

Here's a comprehensive authentication service that brings together all authentication methods:

```swift
import Foundation
import Combine
import GoogleSignIn
import FacebookLogin
import AuthenticationServices
import MSAL

// MARK: - Auth Error Types
enum AuthError: LocalizedError {
    case configurationError(String)
    case missingToken(String)
    case cancelled
    case invalidCredential
    case missingCode
    case invalidResponse
    case invalidPhoneNumber
    case missingVerificationId
    case invalidVerificationCode
    case tokenRequestFailed
    case invalidTokenResponse
    case notAnonymous
    case cannotUnlinkLastProvider
    case invalidEmail
    case weakPassword
    case noCurrentUser

    var errorDescription: String? {
        switch self {
        case .configurationError(let message): return "Configuration error: \(message)"
        case .missingToken(let message): return message
        case .cancelled: return "Sign-in was cancelled"
        case .invalidCredential: return "Invalid credentials"
        case .missingCode: return "Authorization code not received"
        case .invalidResponse: return "Invalid response from provider"
        case .invalidPhoneNumber: return "Invalid phone number format"
        case .missingVerificationId: return "Verification ID not found"
        case .invalidVerificationCode: return "Invalid verification code"
        case .tokenRequestFailed: return "Failed to request token"
        case .invalidTokenResponse: return "Invalid token response"
        case .notAnonymous: return "Current user is not anonymous"
        case .cannotUnlinkLastProvider: return "Cannot unlink the last provider"
        case .invalidEmail: return "Invalid email format"
        case .weakPassword: return "Password is too weak"
        case .noCurrentUser: return "No user is signed in"
        }
    }
}

// MARK: - Complete Auth Service
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let scs = Scs.shared
    private var cancellables = Set<AnyCancellable>()

    @Published var currentUser: ScsUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: Error?

    private init() {
        // Observe auth state changes
        scs.auth.currentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
            .store(in: &cancellables)
    }

    // MARK: - Email/Password Auth

    func register(email: String, password: String, displayName: String?) async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        return try await scs.auth.register(
            email: email,
            password: password,
            displayName: displayName
        )
    }

    func login(email: String, password: String) async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        return try await scs.auth.login(email: email, password: password)
    }

    // MARK: - OAuth Providers

    func signInWithGoogle(from viewController: UIViewController) async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken("Google ID token not available")
        }

        return try await scs.auth.signInWithGoogle(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }

    func signInWithFacebook(from viewController: UIViewController) async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        let loginManager = LoginManager()

        return try await withCheckedThrowingContinuation { continuation in
            loginManager.logIn(permissions: ["public_profile", "email"], from: viewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let accessToken = AccessToken.current?.tokenString else {
                    continuation.resume(throwing: AuthError.missingToken("Facebook access token not available"))
                    return
                }

                Task {
                    do {
                        let user = try await self.scs.auth.signInWithFacebook(accessToken: accessToken)
                        continuation.resume(returning: user)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Anonymous Auth

    func signInAnonymously() async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        return try await scs.auth.signInAnonymously(
            customData: ["platform": "iOS", "createdAt": Date().timeIntervalSince1970]
        )
    }

    var isAnonymous: Bool {
        return currentUser?.isAnonymous ?? false
    }

    // MARK: - Phone Auth

    func sendPhoneVerificationCode(phoneNumber: String) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        return try await scs.auth.sendPhoneVerificationCode(phoneNumber: phoneNumber)
    }

    func signInWithPhoneNumber(verificationId: String, code: String) async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        return try await scs.auth.signInWithPhoneNumber(
            verificationId: verificationId,
            code: code
        )
    }

    // MARK: - Account Linking

    func linkProvider(_ provider: String, credentials: [String: String]) async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        return try await scs.auth.linkProvider(provider, credentials: credentials)
    }

    func unlinkProvider(_ provider: String) async throws -> ScsUser {
        isLoading = true
        defer { isLoading = false }

        return try await scs.auth.unlinkProvider(provider)
    }

    // MARK: - Password Reset

    func sendPasswordResetEmail(_ email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await scs.auth.sendPasswordResetEmail(email)
    }

    func confirmPasswordReset(code: String, newPassword: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await scs.auth.confirmPasswordReset(code: code, newPassword: newPassword)
    }

    // MARK: - Email Verification

    func sendEmailVerification() async throws {
        try await scs.auth.sendEmailVerification()
    }

    func verifyEmail(_ code: String) async throws {
        try await scs.auth.verifyEmail(code)
    }

    // MARK: - Sign Out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        LoginManager().logOut()
        scs.auth.logout()
    }
}

// MARK: - SwiftUI App Integration
@main
struct MyApp: App {
    @StateObject private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}
```

## Database

NoSQL document database with collections and subcollections. SCS supports two powerful database options:

### Database Types

| Type | Name | Description | Best For |
|------|------|-------------|----------|
| `eazi` | **eaZI Database** | Document-based NoSQL with Firestore-like collections, documents, and subcollections | Development, prototyping, small to medium apps |
| `reladb` | **RelaDB** | Production-grade NoSQL database with relational-style views | Production, scalability, advanced queries |

### Initialize with eaZI (Default)

```swift
import SCS

// eaZI is the default database - no special configuration needed
Scs.initialize(config: ScsConfig(
    projectId: "your-project-id",
    apiKey: "your-api-key"
    // databaseType: "eazi" is implicit
))
```

### Initialize with RelaDB (Production)

```swift
import SCS

// Use RelaDB for production
Scs.initialize(config: ScsConfig(
    projectId: "your-project-id",
    apiKey: "your-api-key",
    databaseType: "reladb"  // Enable RelaDB
))
```

### eaZI Database Features

- **Document-based**: Firestore-like collections and documents
- **Subcollections**: Nested data organization
- **File-based storage**: No external dependencies required
- **Zero configuration**: Works out of the box
- **Query support**: Filtering, ordering, and pagination

### RelaDB Features

- **Production-ready**: Built for reliability and performance
- **Scalable**: Horizontal scaling and replication support
- **Advanced queries**: Aggregation pipelines, complex filters
- **Indexing**: Custom indexes for optimized performance
- **Schema flexibility**: Dynamic schema with validation support
- **Relational-style views**: Table view with columns and rows in the console

### Collection Operations

```swift
// Get a collection reference
let users = scs.database.collection("users")

// List all collections
let collections = try await scs.database.listCollections()

// Create a collection
try await scs.database.createCollection("newCollection")

// Delete a collection
try await scs.database.deleteCollection("oldCollection")
```

### Document Operations

```swift
// Add document with auto-generated ID
let doc = try await scs.database.collection("users").add([
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30,
    "tags": ["developer", "swift"],
    "profile": [
        "bio": "Software developer",
        "avatar": "https://example.com/avatar.jpg"
    ]
])
print("Document ID: \(doc.id)")

// Set document with custom ID (creates or overwrites)
try await scs.database.collection("users").doc("user-123").set([
    "name": "Jane Doe",
    "email": "jane@example.com"
])

// Get a single document
if let user = try await scs.database.collection("users").doc("user-123").get() {
    print("Name: \(user.getString("name") ?? "")")
}

// Update document (partial update)
try await scs.database.collection("users").doc("user-123").update([
    "age": 31,
    "profile.bio": "Senior developer"
])

// Delete document
try await scs.database.collection("users").doc("user-123").delete()
```

### Query Operations

```swift
// Simple query with single filter
let activeUsers = try await scs.database.collection("users")
    .where("status", isEqualTo: "active")
    .get()

// Multiple filters
let results = try await scs.database.collection("users")
    .where("age", isGreaterThanOrEqualTo: 18)
    .where("status", isEqualTo: "active")
    .get()

// Ordering and pagination
let posts = try await scs.database.collection("posts")
    .where("published", isEqualTo: true)
    .orderBy("createdAt", descending: true)
    .limit(10)
    .skip(20)
    .get()

// Using 'in' operator
let featured = try await scs.database.collection("posts")
    .where("category", in: ["tech", "science", "news"])
    .get()

// Using 'contains' for array fields
let tagged = try await scs.database.collection("posts")
    .where("tags", contains: "swift")
    .get()
```

### Query Operators

| Operator | Method | Example |
|----------|--------|---------|
| `==` | `isEqualTo` | `.where("status", isEqualTo: "active")` |
| `!=` | `isNotEqualTo` | `.where("status", isNotEqualTo: "deleted")` |
| `>` | `isGreaterThan` | `.where("age", isGreaterThan: 18)` |
| `>=` | `isGreaterThanOrEqualTo` | `.where("age", isGreaterThanOrEqualTo: 18)` |
| `<` | `isLessThan` | `.where("price", isLessThan: 100)` |
| `<=` | `isLessThanOrEqualTo` | `.where("price", isLessThanOrEqualTo: 50)` |
| `in` | `in` | `.where("status", in: ["active", "pending"])` |
| `contains` | `contains` | `.where("tags", contains: "featured")` |

### Subcollections

```swift
// Access a subcollection
let postsRef = scs.database
    .collection("users")
    .doc("userId")
    .collection("posts")

// Add to subcollection
let post = try await postsRef.add([
    "title": "My First Post",
    "content": "Hello World!",
    "createdAt": Date().timeIntervalSince1970
])

// Query subcollection
let userPosts = try await postsRef
    .orderBy("createdAt", descending: true)
    .limit(5)
    .get()

// Nested subcollections (e.g., users/userId/posts/postId/comments)
let commentsRef = scs.database
    .collection("users")
    .doc("userId")
    .collection("posts")
    .doc("postId")
    .collection("comments")

// List subcollections of a document
let subcollections = try await scs.database
    .collection("users")
    .doc("userId")
    .listCollections()
```

## Storage

### Upload Data

```swift
let imageData = UIImage(named: "photo")!.jpegData(compressionQuality: 0.8)!
let file = try await scs.storage.upload(
    data: imageData,
    filename: "photo.jpg",
    folder: "images"
)
print("Uploaded: \(file.url ?? "")")
```

### Upload from URL

```swift
let localURL = URL(fileURLWithPath: "/path/to/file.pdf")
let file = try await scs.storage.upload(url: localURL, folder: "documents")
```

### List Files

```swift
let files = try await scs.storage.list(folder: "images")
for file in files {
    print("File: \(file.name) (\(file.formattedSize))")
}
```

### Download a File

```swift
let data = try await scs.storage.download(fileId: file.id)
// Use data...
```

### Delete a File

```swift
try await scs.storage.delete(fileId: file.id)
```

## Realtime Database

### Get a Reference

```swift
let usersRef = scs.realtime.ref("users")
let userRef = scs.realtime.ref("users/user1")
```

### Set Data

```swift
try await scs.realtime.ref("users/user1").set([
    "name": "John",
    "status": "online"
])
```

### Listen for Changes

```swift
scs.realtime.ref("users/user1").onValue { data in
    print("User data changed: \(data ?? [:])")
}
```

### Update Data

```swift
try await scs.realtime.ref("users/user1").update([
    "status": "offline"
])
```

### Push Data (Auto-generated Key)

```swift
let newRef = try await scs.realtime.ref("messages").push([
    "text": "Hello!"
])
print("New message key: \(newRef.key)")
```

### Remove Data

```swift
try await scs.realtime.ref("users/user1").remove()
```

### Stop Listening

```swift
scs.realtime.ref("users/user1").off()
```

## Cloud Messaging

### Register Device Token

```swift
// Get APNS token and register it
try await scs.messaging.registerToken(apnsToken, platform: DeviceToken.platformIOS)
```

### Subscribe to Topic

```swift
try await scs.messaging.subscribeToTopic(token: apnsToken, topic: "news")
```

### Send to Topic

```swift
try await scs.messaging.sendToTopic(
    "news",
    title: "Breaking News",
    body: "Something happened!",
    data: ["url": "https://example.com/article"]
)
```

### Unsubscribe from Topic

```swift
try await scs.messaging.unsubscribeFromTopic(token: apnsToken, topic: "news")
```

## Remote Configuration

### Fetch and Activate

```swift
let updated = try await scs.remoteConfig.fetchAndActivate()
if updated {
    print("Config updated!")
}
```

### Get Values

```swift
let welcomeMessage = scs.remoteConfig.getString("welcome_message", default: "Hello!")
let maxItems = scs.remoteConfig.getInt("max_items", default: 10)
let featureEnabled = scs.remoteConfig.getBool("new_feature", default: false)
let settings = scs.remoteConfig.getJson("settings")
```

## Cloud Functions

### Call a Function

```swift
let result = try await scs.functions.call("processPayment", data: [
    "amount": 100,
    "currency": "USD"
])

if result.success {
    let data = result.getDataAsDictionary()
    print("Payment ID: \(data?["paymentId"] ?? "")")
} else {
    print("Error: \(result.error ?? "")")
}
```

### Using HttpsCallable

```swift
let processPayment = scs.functions.httpsCallable("processPayment")
let result = try await processPayment.call(["amount": 100])
```

## Machine Learning

### Text Recognition (OCR)

```swift
let imageData = UIImage(named: "document")!.jpegData(compressionQuality: 0.8)!
let result = try await scs.ml.recognizeText(data: imageData, filename: "document.jpg")
print("Recognized text: \(result.text)")
```

### Image Labeling

```swift
let result = try await scs.ml.labelImage(data: imageData, filename: "photo.jpg")
for label in result.labels {
    print("\(label.label): \(label.confidence)")
}
```

## AI Services

### Chat

```swift
let response = try await scs.ai.chat(messages: [
    .system("You are a helpful assistant."),
    .user("What is the capital of France?")
], model: "llama2")

print("AI: \(response.content)")
```

### Simple Ask

```swift
let answer = try await scs.ai.ask(
    "What is the capital of France?",
    systemPrompt: "You are a helpful assistant."
)
print("AI: \(answer)")
```

### Text Completion

```swift
let completion = try await scs.ai.complete(
    prompt: "Once upon a time",
    maxTokens: 100
)
print(completion.content)
```

### Image Generation

```swift
let result = try await scs.ai.generateImage(
    prompt: "A sunset over mountains",
    size: "512x512"
)
print("Image URL: \(result.imageUrl ?? "")")
```

### Chat Builder (Fluent API)

```swift
let response = try await scs.ai.chat(
    scs.ai.chatBuilder()
        .system("You are a helpful assistant.")
        .user("Hello!")
        .model("llama2")
        .temperature(0.7)
        .maxTokens(100)
)
```

## AI Agents

Create and manage AI agents with custom instructions and tools.

### Create an Agent

```swift
let agent = try await scs.ai.createAgent(
    name: "Customer Support",
    instructions: "You are a helpful customer support assistant. Be polite and helpful.",
    model: "llama3.2",
    temperature: 0.7
)
print("Created agent: \(agent.id)")
```

### Run the Agent

```swift
// Run the agent
var response = try await scs.ai.runAgent(
    agent.id,
    input: "How do I reset my password?"
)
print("Agent: \(response.output)")
print("Session: \(response.sessionId)")

// Continue the conversation in the same session
response = try await scs.ai.runAgent(
    agent.id,
    input: "Thanks! What about enabling 2FA?",
    sessionId: response.sessionId
)
```

### Manage Agent Sessions

```swift
// List agent sessions
let sessions = try await scs.ai.listAgentSessions(agent.id)

// Get full session history
let session = try await scs.ai.getAgentSession(agent.id, sessionId: response.sessionId)
for msg in session.messages {
    print("\(msg.role): \(msg.content)")
}

// Delete a session
try await scs.ai.deleteAgentSession(agent.id, sessionId: response.sessionId)
```

### Manage Agents

```swift
// List agents
let agents = try await scs.ai.listAgents()

// Update agent
try await scs.ai.updateAgent(
    agent.id,
    instructions: "Updated instructions here",
    temperature: 0.5
)

// Delete agent
try await scs.ai.deleteAgent(agent.id)
```

### Agent Tools

```swift
// Define a tool for agents
let tool = try await scs.ai.defineTool(
    name: "get_weather",
    description: "Get weather for a location",
    parameters: [
        "type": "object",
        "properties": [
            "location": [
                "type": "string",
                "description": "City name"
            ]
        ]
    ]
)

// List tools
let tools = try await scs.ai.listTools()

// Delete a tool
try await scs.ai.deleteTool(tool.id)
```

## Error Handling

```swift
do {
    let user = try await scs.auth.login(email: email, password: password)
} catch let error as ScsError {
    switch error {
    case .invalidCredentials:
        print("Invalid email or password")
    case .userNotFound:
        print("User not found")
    case .networkError(let message):
        print("Network error: \(message)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

## License

MIT License - see LICENSE file for details.

## Support

- [GitHub Issues](https://github.com/AstroX11/SCS/issues)
- [Documentation](https://docs.spyxpo.com/scs)
