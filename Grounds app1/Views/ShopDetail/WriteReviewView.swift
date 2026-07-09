import SwiftUI

struct WriteReviewView: View {
    let shop: CoffeeShop
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthService
    @State private var rating: Double = 0
    @State private var titleText  = ""
    @State private var reviewText = ""
    @State private var drink  = ""
    @State private var submitted = false

    let drinks = ["Espresso","Latte","Cappuccino","Cortado","Cold Brew",
                  "Pour-Over","Flat White","Americano","Mocha","Matcha Latte"]

    var canSubmit: Bool { rating > 0 && reviewText.count >= 10 }

    var body: some View {
        ZStack {
            G.parchment.ignoresSafeArea()
            if submitted {
                SubmittedView { dismiss() }
            } else {
                ScrollView {
                    VStack(spacing: 20) {

                        // Header
                        VStack(spacing: 6) {
                            Text("Review").font(G.serif(22, weight: .bold)).foregroundStyle(G.darkRoast)
                            Text(shop.name).font(G.sans(15)).foregroundStyle(G.lightRoast)
                        }
                        .padding(.top, 20)

                        // Star picker
                        VStack(spacing: 8) {
                            Text("OVERALL RATING").font(G.mono(11)).foregroundStyle(G.lightRoast)
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: Double(i) <= rating ? "star.fill" : "star")
                                        .font(.system(size: 34))
                                        .foregroundStyle(Double(i) <= rating ? G.stampRed : G.kraftLine)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.2)) { rating = Double(i) }
                                        }
                                        .scaleEffect(Double(i) <= rating ? 1.1 : 1.0)
                                        .animation(.spring(response: 0.2), value: rating)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(G.kraft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(G.kraftLine, lineWidth: 1))

                        // What did you have?
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHAT DID YOU HAVE?").font(G.mono(11)).foregroundStyle(G.lightRoast)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(drinks, id: \.self) { d in
                                        Button { drink = drink == d ? "" : d } label: {
                                            Text(d).font(G.sans(12, weight: .medium))
                                                .foregroundStyle(drink == d ? G.parchment : G.darkRoast)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(drink == d ? G.stampRed : G.kraft)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(G.kraftLine, lineWidth: drink == d ? 0 : 1))
                                        }
                                    }
                                }
                            }
                        }

                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TITLE (OPTIONAL)").font(G.mono(11)).foregroundStyle(G.lightRoast)
                            TextField("Sum it up in one line…", text: $titleText)
                                .textFieldStyle(GroundsFieldStyle())
                        }

                        // Review body
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("YOUR REVIEW").font(G.mono(11)).foregroundStyle(G.lightRoast)
                                Spacer()
                                Text("\(reviewText.count)/500").font(G.mono(11)).foregroundStyle(G.lightRoast)
                            }
                            ZStack(alignment: .topLeading) {
                                if reviewText.isEmpty {
                                    Text("Tell others what you loved, what to order, vibe…")
                                        .font(G.sans(14)).foregroundStyle(G.lightRoast).padding(14)
                                }
                                TextEditor(text: $reviewText)
                                    .font(G.sans(14))
                                    .foregroundStyle(G.darkRoast)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(minHeight: 120)
                                    .padding(10)
                                    .onChange(of: reviewText) {
                                        if reviewText.count > 500 {
                                            reviewText = String(reviewText.prefix(500))
                                        }
                                    }
                            }
                            .background(G.kraft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
                        }

                        // Add photo (Pro only)
                        if auth.currentUser.isPremium {
                            Button { } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Add Photos / Video")
                                }
                                .font(G.sans(14))
                                .foregroundStyle(G.darkRoast.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(G.kraft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
                            }
                        }

                        // Submit
                        GButton("Submit Review", icon: "paperplane.fill") {
                            withAnimation { submitted = true }
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.4)

                        Text("Reviews are visible to the entire Grounds community.")
                            .font(G.sans(11))
                            .foregroundStyle(G.lightRoast)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
            }
        }
    }
}

struct SubmittedView: View {
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            StampMark(symbol: "checkmark", isSymbolName: true, size: 90, rotation: -6)
            Text("Review Submitted").font(G.serif(24, weight: .bold)).foregroundStyle(G.darkRoast)
            Text("Thanks for helping the coffee community")
                .font(G.sans(15)).foregroundStyle(G.lightRoast).multilineTextAlignment(.center)
            Spacer()
            GButton("Done", action: onDone).padding(.horizontal, 40)
        }
        .padding(24)
    }
}
