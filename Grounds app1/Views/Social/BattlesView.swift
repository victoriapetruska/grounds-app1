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
        ZStack {
            G.parchment.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Create Battle CTA ─────────────────────────────────────────
                    CreateBattleBanner { showCreateBattle = true }
                        .padding(.horizontal, 16)

                    // ── Pending Challenges ────────────────────────────────────────
                    if !pending.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            PaperSectionHeader("INCOMING CHALLENGES", subtitle: "\(pending.count) waiting")
                                .padding(.horizontal, 20)

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
                        VStack(alignment: .leading, spacing: 10) {
                            PaperSectionHeader("ACTIVE BATTLES", subtitle: "\(active.count) in progress")
                                .padding(.horizontal, 20)

                            ForEach(active) { challenge in
                                ActiveBattleCard(challenge: challenge, myID: auth.currentUser.id)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }

                    // ── Completed ─────────────────────────────────────────────────
                    if !completed.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            PaperSectionHeader("COMPLETED", subtitle: "past battles")
                                .padding(.horizontal, 20)

                            ForEach(completed) { challenge in
                                CompletedBattleCard(challenge: challenge, myID: auth.currentUser.id)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }

                    if challenges.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bolt.slash").font(.system(size: 36)).foregroundStyle(G.lightRoast)
                            Text("No battles yet").font(G.serif(19, weight: .bold)).foregroundStyle(G.darkRoast)
                            Text("Challenge a friend to see who discovers more coffee shops.")
                                .font(G.sans(14)).foregroundStyle(G.lightRoast).multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 60).padding(.horizontal, 40)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 12)
            }
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
                RoundedRectangle(cornerRadius: 18).fill(G.kraft)
                RoundedRectangle(cornerRadius: 18).stroke(G.stampRed.opacity(0.35), lineWidth: 1)

                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(G.stampRed).frame(width: 50, height: 50)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(G.parchment)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Challenge a Friend")
                            .font(G.serif(17, weight: .bold))
                            .foregroundStyle(G.darkRoast)
                        Text("Pick a friend, pick a category, and compete to see who's the bigger coffee nerd.")
                            .font(G.sans(12))
                            .foregroundStyle(G.lightRoast)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(G.stampRed)
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
            RoundedRectangle(cornerRadius: 16).fill(G.kraft)
            RoundedRectangle(cornerRadius: 16).stroke(G.stampRed.opacity(0.35), lineWidth: 1)

            VStack(spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(G.stampRed.opacity(0.12)).frame(width: 36, height: 36)
                        Image(systemName: challenge.type.icon)
                            .font(.system(size: 15)).foregroundStyle(G.stampRed)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(challenge.challengerName) challenged you")
                            .font(G.sans(14, weight: .semibold)).foregroundStyle(G.darkRoast)
                        Text(challenge.type.rawValue + " · " + challenge.duration.label)
                            .font(G.mono(11)).foregroundStyle(G.lightRoast)
                    }
                    Spacer()
                    Text("NEW").font(G.mono(10)).foregroundStyle(G.parchment)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(G.stampRed).clipShape(Capsule())
                }

                Text(challenge.type.description)
                    .font(G.sans(13)).foregroundStyle(G.darkRoast.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if responded {
                    Text("Response sent").font(G.sans(13, weight: .medium)).foregroundStyle(G.sage)
                } else {
                    HStack(spacing: 10) {
                        Button {
                            responded = true
                            onRespond(false)
                        } label: {
                            Text("Decline")
                                .font(G.sans(13, weight: .medium)).foregroundStyle(G.lightRoast)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(G.parchment)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(G.kraftLine, lineWidth: 1))
                        }
                        Button {
                            responded = true
                            onRespond(true)
                        } label: {
                            Text("Accept")
                                .font(G.sans(13, weight: .bold)).foregroundStyle(G.parchment)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(G.stampRed)
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
            RoundedRectangle(cornerRadius: 16).fill(G.kraft)
            RoundedRectangle(cornerRadius: 16)
                .stroke(iAmWinning ? G.stampRed.opacity(0.4) : G.kraftLine, lineWidth: 1)

            VStack(spacing: 14) {
                // Type + time
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: challenge.type.icon)
                            .font(.system(size: 12)).foregroundStyle(G.stampRed)
                        Text(challenge.type.rawValue)
                            .font(G.mono(11)).foregroundStyle(G.lightRoast)
                    }
                    Spacer()
                    Text(challenge.timeRemaining)
                        .font(G.mono(11))
                        .foregroundStyle(challenge.timeRemaining.contains("h") ? G.stampRed : G.lightRoast)
                }

                // VS row
                HStack(alignment: .center, spacing: 0) {
                    // My side
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(G.parchment)
                            Text(String(myName.prefix(1)).uppercased())
                                .font(G.serif(16, weight: .bold)).foregroundStyle(G.darkRoast)
                        }
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(iAmWinning ? G.stampRed : Color.clear, lineWidth: 2))
                        Text(myName.components(separatedBy: " ").first ?? myName)
                            .font(G.sans(11, weight: .medium)).foregroundStyle(G.darkRoast).lineLimit(1)
                        Text("\(myScore)").font(G.serif(24, weight: .bold))
                            .foregroundStyle(iAmWinning ? G.stampRed : G.lightRoast)
                    }
                    .frame(maxWidth: .infinity)

                    // VS badge
                    Text("VS")
                        .font(G.mono(12))
                        .foregroundStyle(G.parchment)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(G.darkRoast)
                        .clipShape(Capsule())

                    // Their side
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(G.parchment)
                            Text(String(theirName.prefix(1)).uppercased())
                                .font(G.serif(16, weight: .bold)).foregroundStyle(G.darkRoast)
                        }
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(!iAmWinning ? G.stampRed : Color.clear, lineWidth: 2))
                        Text(theirName.components(separatedBy: " ").first ?? theirName)
                            .font(G.sans(11, weight: .medium)).foregroundStyle(G.darkRoast).lineLimit(1)
                        Text("\(theirScore)").font(G.serif(24, weight: .bold))
                            .foregroundStyle(!iAmWinning ? G.stampRed : G.lightRoast)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(G.parchment).frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(G.stampRed)
                            .frame(width: geo.size.width * CGFloat(challenge.challengerProgress), height: 8)
                    }
                }
                .frame(height: 8)

                // Lead label
                HStack {
                    if iAmWinning && myScore != theirScore {
                        Label("You're leading by \(myScore - theirScore)", systemImage: "arrow.up")
                            .font(G.sans(11, weight: .medium)).foregroundStyle(G.sage)
                    } else if !iAmWinning {
                        Label("Down by \(theirScore - myScore) — catch up", systemImage: "arrow.down")
                            .font(G.sans(11, weight: .medium)).foregroundStyle(G.stampRed)
                    } else {
                        Text("It's a tie — make your move").font(G.sans(11)).foregroundStyle(G.lightRoast)
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
                Circle().fill((iWon ? G.stampRed : G.lightRoast).opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: iWon ? "trophy.fill" : "medal")
                    .font(.system(size: 18))
                    .foregroundStyle(iWon ? G.stampRed : G.lightRoast)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(iWon ? "You won" : "Better luck next time")
                    .font(G.sans(14, weight: .semibold))
                    .foregroundStyle(G.darkRoast)
                Text("\(challenge.type.rawValue) vs \(opponentName)")
                    .font(G.mono(11)).foregroundStyle(G.lightRoast)
                Text("\(challenge.challengerScore) – \(challenge.opponentScore)")
                    .font(G.mono(11)).foregroundStyle(G.darkRoast)
            }
            Spacer()
            if iWon {
                Text("+\(challenge.type == .streak ? 50 : 30) pts")
                    .font(G.mono(11)).foregroundStyle(G.stampRed)
            }
        }
        .padding(14)
        .background(G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
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
            G.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(G.kraftLine).frame(width: 40, height: 5).padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Text("Create a Battle")
                            .font(G.serif(22, weight: .bold)).foregroundStyle(G.darkRoast)
                            .padding(.top, 16)

                        // Choose friend
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CHALLENGE").font(G.mono(11)).foregroundStyle(G.lightRoast)
                            if social.friends.isEmpty {
                                Text("Add a friend first to challenge them.")
                                    .font(G.sans(13)).foregroundStyle(G.lightRoast)
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
                            Text("CATEGORY").font(G.mono(11)).foregroundStyle(G.lightRoast)
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
                            Text("DURATION").font(G.mono(11)).foregroundStyle(G.lightRoast)
                            HStack(spacing: 8) {
                                ForEach(ChallengeDuration.allCases, id: \.rawValue) { dur in
                                    Button { selectedDuration = dur } label: {
                                        Text(dur.label)
                                            .font(G.sans(12, weight: .medium))
                                            .foregroundStyle(selectedDuration == dur ? G.parchment : G.darkRoast)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(selectedDuration == dur ? G.stampRed : G.kraft)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(selectedDuration == dur ? Color.clear : G.kraftLine, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        if created {
                            Label("Challenge sent", systemImage: "checkmark.circle.fill")
                                .font(G.sans(15, weight: .semibold)).foregroundStyle(G.sage)
                        } else {
                            Button {
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
                            } label: {
                                Text("Send Challenge")
                                    .font(G.sans(16, weight: .semibold))
                                    .foregroundStyle(G.parchment)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(selectedFriend != nil ? G.stampRed : G.lightRoast)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(selectedFriend == nil)
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
                ZStack {
                    Circle().fill(G.parchment)
                    Text(String(friend.name.prefix(1)).uppercased())
                        .font(G.serif(15, weight: .bold)).foregroundStyle(G.darkRoast)
                }
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(isSelected ? G.stampRed : Color.clear, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.name).font(G.sans(14, weight: .semibold)).foregroundStyle(G.darkRoast)
                    Text("@\(friend.username)").font(G.mono(11)).foregroundStyle(G.lightRoast)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? G.stampRed : G.kraftLine)
            }
            .padding(12)
            .background(isSelected ? G.stampRed.opacity(0.08) : G.kraft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? G.stampRed.opacity(0.4) : G.kraftLine, lineWidth: 1))
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
                    .foregroundStyle(isSelected ? G.parchment : G.stampRed)
                Text(type.rawValue)
                    .font(G.sans(11, weight: .medium))
                    .foregroundStyle(isSelected ? G.parchment : G.darkRoast)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? G.stampRed : G.kraft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.clear : G.kraftLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
