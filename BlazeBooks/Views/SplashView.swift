import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 1.0

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 270, height: 270)
                .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) {
                scale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.25)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onFinished()
                }
            }
        }
    }
}
