import SwiftUI

struct BattlesView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var social: SocialService
    @EnvironmentObject var community: CommunityService
    @State private var challenges: [Challenge] = []
    @State private var showCreateBattle = false

    var pending:   [Challenge] { challenges.filter { $0.status == .pending && $0.opponentID == auth.currentUser.id } }
    var active:    [Challenge] { challenges.filter { $0.status == .active } }
    var completed: [Challenge] { challenges.filter { $0.status == .completed || $0.status == .declined } }

    /// Loads real challenges, then fills in live scores computed from actual check-ins —
    /// nothing here is stored/stale, it's recomputed from CloudKit every time.
    private func loadChallenges() async {
        await social.fetchChallenges(myID: auth.currentUser.id)
        var loaded: [Challenge] = []
        let now = Date()

        for original in social.challenges {
            var challenge = original
            if challenge.status == .active && challenge.endDate < now {
                challenge.status = .completed
                let id = challenge.id
                Task { await social.markChallengeCompleted(id) }
            }
            if challenge.status == .active || challenge.status == .completed {
                let challengerID = challenge.challengerID
                let opponentID = challenge.opponentID
                let type = challenge.type
                let start = challenge.startDate
                let end = challenge.endDate
                async let challengerScore = community.metricScore(
                    forUserID: challengerID, type: type, from: start, to: end)
                async let opponentScore = community.metricScore(
                    forUserID: opponentID, type: type, from: start, to: end)
                challenge.challengerScore = await challengerScore
                challenge.opponentScore   = await opponentScore
            }
            loaded.append(challenge)
        }
        challenges = loaded
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // ── Create Battle CTA ─────────────────────────────────────────
                CreateBattleBanner { showCreateBattle = true }
                    .padding(.horizontal, 16)

                // ── Pending Challenges ────────────────────────────────────────
                if !pending.isEmpty {
                    VStack(spacing: 12) {
                        LeagueSectionHeader(
                            title: "INCOMING CHALLENGES",
                            subtitle: "\(pending.count) waiting for your response",
                            icon: "bell.badge.fill",
                            color: G.gold
                        )
                        .padding(.horizontal, 16)

                        ForEach(pending) { challenge in
                            PendingChallengeCard(challenge: challenge) { accepted in
                                respond(to: challenge, accepted: accepted)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                // ── Active Battles ────────────────────────────────────────────
                if !active.isEmpty {
                    VStack(spacing: 12) {
                        LeagueSectionHeader(
                            title: "ACTIVE BATTLES",
                            subtitle: "\(active.count) in progress",
                            icon: "bolt.fill",
                            color: Color.orange
                        )
                        .padding(.horizontal, 16)

                        ForEach(active) { challenge in
                            ActiveBattleCard(challenge: challenge, myID: auth.currentUser.id)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                // ── Completed ─────────────────────────────────────────────────
                if !completed.isEmpty {
                    VStack(spacing: 12) {
                        LeagueSectionHeader(
                            title: "COMPLETED",
                            subtitle: "Past battles",
                            icon: "checkmark.seal.fill",
                            color: G.muted
                        )
                        .padding(.horizontal, 16)

                        ForEach(completed) { challenge in
                            CompletedBattleCard(challenge: challenge, myID: auth.currentUser.id)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                if challenges.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.slash").font(.system(size: 40)).foregroundStyle(G.muted)
                        Text("No battles yet").font(G.title(20)).foregroundStyle(G.muted)
                        Text("Challenge a friend to see who discovers more coffee shops!").font(G.body(14)).foregroundStyle(G.muted).multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 60).padding(.horizontal, 40)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .task { await loadChallenges() }
        .sheet(isPresented: $showCreateBattle) {
            CreateBattleView { newChallenge in
                Task {
                    await social.createChallenge(newChallenge)
                    await loadChallenges()
                }
            }
        }
    }

    private func respond(to challenge: Challenge, accepted: Bool) {
        Task {
            await social.respondToChallenge(challenge, accept: accepted)
            await loadChallenges()
        }
    }
}

// MARK: - Create Battle Banner

struct CreateBattleBanner: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [G.caramel.opacity(0.25), G.roast],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                RoundedRectangle(cornerRadius: 18).stroke(G.caramel.opacity(0.5), lineWidth: 1)

                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(G.caramelGrad).frame(width: 52, height: 52)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Challenge a Friend")
                            .font(G.title(18))
                            .foregroundStyle(G.cream)
                        Text("Pick a friend, pick a category, and compete to see who's the bigger coffee nerd.")
                            .font(G.body(12))
                            .foregroundStyle(G.latte)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(G.caramel)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Challenge Card

struct PendingChallengeCard: View {
    let challenge: Challenge
    let onRespond: (Bool) -> Void
    @State private var responded = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(G.surface)
            RoundedRectangle(cornerRadius: 16).stroke(G.gold.opacity(0.4), lineWidth: 1)

            VStack(spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(G.gold.opacity(0.15)).frame(width: 36, height: 36)
                        Image(systemName: challenge.type.icon)
                            .font(.system(size: 15)).foregroundStyle(G.gold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(challenge.challengerName) challenged you!")
                            .font(G.body(14)).fontWeight(.semibold).foregroundStyle(G.cream)
                        Text(challenge.type.rawValue + " · " + challenge.duration.label)
                            .font(G.label(11)).foregroundStyle(G.muted)
                    }
                    Spacer()
                    Text("New").font(G.label(10)).foregroundStyle(G.espresso)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(G.gold).clipShape(Capsule())
                }

                Text(challenge.type.description)
                    .font(G.body(13)).foregroundStyle(G.latte)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if responded {
                    Text("Response sent!").font(G.label(13)).foregroundStyle(G.sage)
                } else {
                    HStack(spacing: 10) {
                        Button {
                            responded = true
                            onRespond(false)
                        } label: {
                            Text("Decline")
                                .font(G.label(13)).foregroundStyle(G.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(G.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(G.border, lineWidth: 1))
                        }
                        Button {
                            responded = true
                            onRespond(true)
                        } label: {
                            Text("Accept ⚡")
                                .font(G.label(13)).fontWeight(.bold).foregroundStyle(G.espresso)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(G.caramelGrad)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Active Battle Card

struct ActiveBattleCard: View {
    let challenge: Challenge
    let myID: String

    var iAmChallenger: Bool { challenge.challengerID == myID }
    var myScore:       Int  { iAmChallenger ? challenge.challengerScore : challenge.opponentScore }
    var theirScore:    Int  { iAmChallenger ? challenge.opponentScore   : challenge.challengerScore }
    var myName:        String { iAmChallenger ? challenge.challengerName : challenge.opponentName }
    var theirName:     String { iAmChallenger ? challenge.opponentName   : challenge.challengerName }
    var iAmWinning:    Bool { myScore >= theirScore }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(G.surface)
            RoundedRectangle(cornerRadius: 16)
                .stroke(iAmWinning ? G.caramel.opacity(0.5) : G.border, lineWidth: 1)

            VStack(spacing: 14) {
                // Type + time
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: challenge.type.icon)
                            .font(.system(size: 12)).foregroundStyle(G.caramel)
                        Text(challenge.type.rawValue)
                            .font(G.label(11)).foregroundStyle(G.latte)
                    }
                    Spacer()
                    Text(challenge.timeRemaining)
                        .font(G.label(11))
                        .foregroundStyle(challenge.timeRemaining.contains("h") ? G.gold : G.muted)
                }

                // VS row
                HStack(alignment: .center, spacing: 0) {
                    // My side
                    VStack(spacing: 4) {
                        AvatarView(name: myName, size: 44)
                            .overlay(
                                iAmWinning
                                ? Circle().stroke(G.caramel, lineWidth: 2)
                                : Circle().stroke(Color.clear, lineWidth: 2)
                            )
                        Text(myName.components(separatedBy: " ").first ?? myName)
                            .font(G.label(11)).foregroundStyle(G.cream).lineLimit(1)
                        Text("\(myScore)").font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(iAmWinning ? G.caramel : G.muted)
                    }
                    .frame(maxWidth: .infinity)

                    // VS badge
                    Text("VS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(G.espresso)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(G.caramelGrad)
                        .clipShape(Capsule())

                    // Their side
                    VStack(spacing: 4) {
                        AvatarView(name: theirName, size: 44)
                            .overlay(
                                !iAmWinning
                                ? Circle().stroke(Color.red.opacity(0.6), lineWidth: 2)
                                : Circle().stroke(Color.clear, lineWidth: 2)
                            )
                        Text(theirName.components(separatedBy: " ").first ?? theirName)
                            .font(G.label(11)).foregroundStyle(G.cream).lineLimit(1)
                        Text("\(theirScore)").font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(!iAmWinning ? Color.red.opacity(0.8) : G.muted)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(G.surface2).frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(G.caramelGrad)
                            .frame(width: geo.size.width * CGFloat(challenge.challengerProgress), height: 8)
                    }
                }
                .frame(height: 8)

                // Lead label
                HStack {
                    if iAmWinning && myScore != theirScore {
                        Label("You're leading by \(myScore - theirScore)!", systemImage: "arrow.up")
                            .font(G.label(11)).foregroundStyle(G.sage)
                    } else if !iAmWinning {
                        Label("Down by \(theirScore - myScore) — catch up!", systemImage: "arrow.down")
                            .font(G.label(11)).foregroundStyle(G.gold)
                    } else {
                        Text("It's a tie — make your move!").font(G.label(11)).foregroundStyle(G.latte)
                    }
                    Spacer()
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Completed Battle Card

struct CompletedBattleCard: View {
    let challenge: Challenge
    let myID: String

    var iWon: Bool {
        if challenge.challengerID == myID { return challenge.challengerScore > challenge.opponentScore }
        return challenge.opponentScore > challenge.challengerScore
    }
    var opponentName: String {
        challenge.challengerID == myID ? challenge.opponentName : challenge.challengerName
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill((iWon ? G.gold : G.muted).opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: iWon ? "trophy.fill" : "medal")
                    .font(.system(size: 18))
                    .foregroundStyle(iWon ? G.gold : G.muted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(iWon ? "You won! 🎉" : "Better luck next time")
                    .font(G.body(14)).fontWeight(.semibold)
                    .foregroundStyle(iWon ? G.cream : G.muted)
                Text("\(challenge.type.rawValue) vs \(opponentName)")
                    .font(G.label(11)).foregroundStyle(G.muted)
                Text("\(challenge.challengerScore) – \(challenge.opponentScore)")
                    .font(G.mono(11)).foregroundStyle(G.latte)
            }
            Spacer()
            Text(iWon ? "+\(challenge.type == .streak ? 50 : 30) pts" : "")
                .font(G.label(11)).fontWeight(.bold).foregroundStyle(G.gold)
        }
        .padding(14)
        .background(G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
    }
}

// MARK: - Create Battle Sheet

struct CreateBattleView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var social: SocialService
    let onCreate: (Challenge) -> Void

    @State private var selectedFriend: GroundsUserProfile? = nil
    @State private var selectedType: ChallengeType  = .shops
    @State private var selectedDuration: ChallengeDuration = .oneWeek
    @State private var created = false

    var body: some View {
        ZStack {
            G.espresso.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(G.border).frame(width: 40, height: 5).padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Text("Create a Battle")
                            .font(G.title(24)).foregroundStyle(G.cream)
                            .padding(.top, 16)

                        // Choose friend
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CHALLENGE").font(G.label(11)).foregroundStyle(G.muted)
                            if social.friends.isEmpty {
                                Text("Add a friend first to challenge them.")
                                    .font(G.body(13)).foregroundStyle(G.muted)
                            } else {
                                ForEach(social.friends) { friend in
                                    FriendPickerRow(
                                        friend: friend,
                                        isSelected: selectedFriend?.id == friend.id
                                    ) { selectedFriend = friend }
                                }
                            }
                        }

                        // Choose type
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CATEGORY").font(G.label(11)).foregroundStyle(G.muted)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(ChallengeType.allCases) { type in
                                    ChallengeTypeChip(type: type, isSelected: selectedType == type) {
                                        selectedType = type
                                    }
                                }
                            }
                        }

                        // Choose duration
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DURATION").font(G.label(11)).foregroundStyle(G.muted)
                            HStack(spacing: 8) {
                                ForEach(ChallengeDuration.allCases, id: \.rawValue) { dur in
                                    Button { selectedDuration = dur } label: {
                                        Text(dur.label)
                                            .font(G.label(12))
                                            .foregroundStyle(selectedDuration == dur ? G.espresso : G.cream)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(selectedDuration == dur ? G.caramelGrad : LinearGradient(colors: [G.surface], startPoint: .top, endPoint: .bottom))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(selectedDuration == dur ? Color.clear : G.border, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        if created {
                            Label("Challenge sent!", systemImage: "checkmark.circle.fill")
                                .font(G.body(15)).fontWeight(.semibold).foregroundStyle(G.sage)
                        } else {
                            GButton("Send Challenge ⚡",
                                    style: selectedFriend != nil ? .gold : .outline) {
                                guard let friend = selectedFriend else { return }
                                let end = Date().addingTimeInterval(Double(selectedDuration.rawValue) * 86400)
                                let newChallenge = Challenge(
                                    id: UUID().uuidString,
                                    type: selectedType,
                                    duration: selectedDuration,
                                    startDate: Date(), endDate: end,
                                    status: .pending,
                                    challengerID: auth.currentUser.id,
                                    challengerName: auth.currentUser.name,
                                    challengerAvatar: nil,
                                    opponentID: friend.id,
                                    opponentName: friend.name,
                                    opponentAvatar: nil,
                                    challengerScore: 0, opponentScore: 0
                                )
                                onCreate(newChallenge)
                                created = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

struct FriendPickerRow: View {
    let friend: GroundsUserProfile
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AvatarView(name: friend.name, size: 40)
                    .overlay(isSelected ? Circle().stroke(G.caramel, lineWidth: 2) : Circle().stroke(Color.clear, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.name).font(G.body(14)).fontWeight(.semibold).foregroundStyle(G.cream)
                    Text("@\(friend.username)").font(G.label(11)).foregroundStyle(G.muted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? G.caramel : G.border)
            }
            .padding(12)
            .background(isSelected ? G.caramel.opacity(0.1) : G.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? G.caramel.opacity(0.4) : G.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ChallengeTypeChip: View {
    let type: ChallengeType
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? G.espresso : G.caramel)
                Text(type.rawValue)
                    .font(G.label(11))
                    .foregroundStyle(isSelected ? G.espresso : G.cream)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? G.caramelGrad : LinearGradient(colors: [G.surface], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.clear : G.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
