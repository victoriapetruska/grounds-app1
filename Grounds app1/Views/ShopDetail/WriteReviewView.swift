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
            G.espresso.ignoresSafeArea()
            if submitted {
                SubmittedView { dismiss() }
            } else {
                ScrollView {
                    VStack(spacing: 20) {

                        // Header
                        VStack(spacing: 6) {
                            Text("Review").font(G.title(24)).foregroundStyle(G.cream)
                            Text(shop.name).font(G.body(15)).foregroundStyle(G.latte)
                        }
                        .padding(.top, 20)

                        // Star picker
                        VStack(spacing: 8) {
                            Text("Overall Rating").font(G.label(13)).foregroundStyle(G.muted)
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: Double(i) <= rating ? "star.fill" : "star")
                                        .font(.system(size: 34))
                                        .foregroundStyle(Double(i) <= rating ? G.gold : G.border)
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
                        .background(G.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // What did you have?
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What did you have?").font(G.label(13)).foregroundStyle(G.muted)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(drinks, id: \.self) { d in
                                        Button { drink = drink == d ? "" : d } label: {
                                            Text(d).font(G.label(12))
                                                .foregroundStyle(drink == d ? G.espresso : G.cream)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(drink == d ? G.caramelGrad : LinearGradient(colors: [G.surface], startPoint: .top, endPoint: .bottom))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(G.border, lineWidth: drink == d ? 0 : 1))
                                        }
                                    }
                                }
                            }
                        }

                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title (optional)").font(G.label(13)).foregroundStyle(G.muted)
                            TextField("Sum it up in one line...", text: $titleText)
                                .textFieldStyle(GroundsFieldStyle())
                        }

                        // Review body
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Your Review").font(G.label(13)).foregroundStyle(G.muted)
                                Spacer()
                                Text("\(reviewText.count)/500").font(G.label(11)).foregroundStyle(G.muted)
                            }
                            ZStack(alignment: .topLeading) {
                                if reviewText.isEmpty {
                                    Text("Tell others what you loved, what to order, vibe...")
                                        .font(G.body(14)).foregroundStyle(G.muted).padding(14)
                                }
                                TextEditor(text: $reviewText)
                                    .font(G.body(14))
                                    .foregroundStyle(G.cream)
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
                            .background(G.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
                        }

                        // Add photo (Pro only)
                        if auth.currentUser.isPremium {
                            Button { } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Add Photos / Video")
                                }
                                .font(G.body(14))
                                .foregroundStyle(G.latte)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(G.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
                            }
                        }

                        // Submit
                        GButton("Submit Review", icon: "paperplane.fill") {
                            withAnimation { submitted = true }
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.4)

                        Text("Reviews are visible to the entire Grounds community.")
                            .font(G.label(11))
                            .foregroundStyle(G.muted)
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
            ZStack {
                Circle().fill(G.caramelGrad).frame(width: 90, height: 90)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
            }
            Text("Review Submitted!").font(G.title(26)).foregroundStyle(G.cream)
            Text("Thanks for helping the coffee community ☕")
                .font(G.body(15)).foregroundStyle(G.latte).multilineTextAlignment(.center)
            Text("+30 points earned").font(G.label(14)).foregroundStyle(G.gold)
            Spacer()
            GButton("Done", action: onDone).padding(.horizontal, 40)
        }
        .padding(24)
    }
}
