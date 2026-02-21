import SwiftUI

/// A small sheet for purchasing the "Show Support" tip jar IAP.
struct TipJarSheet: View {
    @Environment(TipJarService.self) private var tipJar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            if tipJar.hasPurchased {
                Text("Thank You!")
                    .font(.title)
                    .bold()

                Text("You're a star. Your support means a lot.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Show Your Support")
                    .font(.title)
                    .bold()

                Text("Love Blaze Books? A small tip helps keep development going. You'll earn a gold star in your library as a thank you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if tipJar.isPurchasing {
                    ProgressView()
                        .controlSize(.large)
                } else if let product = tipJar.product {
                    Button {
                        Task { await tipJar.purchase() }
                    } label: {
                        Text("Support \(product.displayPrice)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)
                }
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }
}
