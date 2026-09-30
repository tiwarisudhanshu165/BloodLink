import SwiftUI

/// Shown for a couple of seconds when the app opens.
/// Uses the image set named "AppLogo" if you add one to Assets,
/// otherwise falls back to a red blood-drop symbol.
struct SplashView: View {
    @State private var appeared = false

    private let crimson = Color(red: 0.827, green: 0.184, blue: 0.184)   // #D32F2F
    private let background = Color(red: 1.0, green: 0.961, blue: 0.961)  // #FFF5F5

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 16) {
                logo
                    .scaleEffect(appeared ? 1.0 : 0.8)
                    .opacity(appeared ? 1 : 0)

                Text("BloodLink")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(crimson)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var logo: some View {
        if UIImage(named: "AppLogo") != nil {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
        } else {
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .foregroundColor(crimson)
        }
    }
}

#Preview {
    SplashView()
}
