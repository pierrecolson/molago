import SwiftUI

/// Les trois textes du matin, trois pans de couleur égaux.
///
/// Trois cartes de même taille, délibérément : aucun texte ne doit paraître plus
/// important qu'un autre. On distingue les univers **à la couleur avant de lire
/// le titre**, et c'est ce qui tient la promesse des cinq secondes.
struct LibraryView: View {
    let day: Day

    @State private var morning = MorningCall()
    @State private var showingMorning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    Text(day.dayLabel)
                        .font(.caption.weight(.bold))
                        .kerning(1.4)
                        .foregroundStyle(Dancheong.inkSoft)
                        .padding(.bottom, 2)

                    ForEach(day.texts) { text in
                        NavigationLink {
                            ReaderView(text: text)
                        } label: {
                            UniverseCard(text: text)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .background(Dancheong.ground)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingMorning = true } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Morning time")
                }
            }
            .sheet(isPresented: $showingMorning) {
                MorningSheet(morning: morning)
                    .presentationDetents([.height(300)])
            }
        }
        .tint(Dancheong.jangdan)
        .task {
            // Après que la journée s'est affichée, jamais avant : une app qui
            // réclame une permission sans avoir montré à quoi elle sert se fait
            // refuser, et iOS ne laisse pas redemander.
            await morning.enable()
        }
    }
}

/// Un pan de couleur pleine. Pas une carte blanche portant une étiquette
/// colorée : la carte **est** la couleur.
private struct UniverseCard: View {
    let text: Day.Text

    private var universe: (color: Color, hanja: String) {
        Dancheong.universe(text.slot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(text.universe.uppercased())
                .font(.caption2.weight(.heavy))
                .kerning(1.6)
                .foregroundStyle(.white.opacity(0.85))

            Text(text.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Text(text.meta)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        // Trois cartes rigoureusement égales, quelle que soit la longueur du
        // titre : aucun texte du jour ne doit paraître plus important qu'un
        // autre (spec §4.3). Une hauteur qui suit le contenu créerait une
        // hiérarchie que personne n'a décidée.
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        .padding(17)
        .background(alignment: .bottomTrailing) {
            // Le hanja de l'univers, très grand et à peine visible : c'est le
            // sujet du texte écrit dans la langue de sa racine. Il déborde du
            // coin, et le rognage de la carte fait le reste.
            Text(universe.hanja)
                .font(.system(size: 118, weight: .bold))
                .foregroundStyle(.white.opacity(0.13))
                .fixedSize()
                .offset(x: 30, y: 30)
        }
        .background(universe.color)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .dancheongKeyline(cornerRadius: 22)
    }
}

/// Le seul réglage de l'app : à quelle heure elle vous dit qu'il y a à lire.
private struct MorningSheet: View {
    @Bindable var morning: MorningCall
    @Environment(\.dismiss) private var dismiss

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: morning.hour, minute: morning.minute)
                ) ?? Date()
            },
            set: { new in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: new)
                morning.hour = parts.hour ?? 7
                morning.minute = parts.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                Text(morning.isAuthorized
                     ? "One notification a day, and nothing else. It tells you the texts are there \u{2014} it never asks you for anything."
                     : "Notifications are off. Turn them on in Settings if you want Molago to tell you when the morning texts arrive.")
                    .font(.footnote)
                    .foregroundStyle(Dancheong.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Dancheong.ground)
            .navigationTitle("Every morning at " + morning.timeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
