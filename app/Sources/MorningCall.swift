import Foundation
import Observation
import UserNotifications

/// L'unique notification de l'application.
///
/// Elle annonce qu'il y a quelque chose à lire. **Elle ne réclame rien.** Aucun
/// rappel, aucune relance, aucun rattrapage — et surtout aucune des formulations
/// que la spec proscrit nommément : « Don't forget », « Your streak »,
/// « You haven't read today » (§4.2).
///
/// Elle est locale et non distante : le push (APNs) demande un compte Apple
/// payant. La contrepartie est qu'elle ne peut pas porter le titre du jour, qui
/// n'existe pas encore sur le téléphone au moment où elle est programmée. On
/// annonce donc ce qu'on sait avec certitude — qu'il y a trois textes — plutôt
/// que d'inventer.
@Observable
@MainActor
final class MorningCall {
    private static let identifier = "molago.morning"
    private static let hourKey = "molago.morningHour"
    private static let minuteKey = "molago.morningMinute"

    /// L'heure choisie. Sept heures par défaut : avant le métro.
    var hour: Int {
        didSet { UserDefaults.standard.set(hour, forKey: Self.hourKey); reschedule() }
    }
    var minute: Int {
        didSet { UserDefaults.standard.set(minute, forKey: Self.minuteKey); reschedule() }
    }

    private(set) var isAuthorized = false

    init() {
        let defaults = UserDefaults.standard
        hour = defaults.object(forKey: Self.hourKey) as? Int ?? 7
        minute = defaults.object(forKey: Self.minuteKey) as? Int ?? 0
    }

    /// Demande l'autorisation, puis programme.
    ///
    /// On la demande après que la journée s'est affichée, jamais au tout premier
    /// écran : une app qui réclame une permission avant d'avoir montré à quoi
    /// elle sert se fait refuser, et on ne redemande pas deux fois.
    func enable() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        default:
            isAuthorized = false
        }

        if isAuthorized { reschedule() }
    }

    /// Une seule notification programmée à la fois, qui se répète chaque jour.
    ///
    /// On remplace au lieu d'ajouter : sinon les notifications s'empileraient à
    /// chaque changement d'heure, et l'app enverrait plusieurs fois par jour ce
    /// qui doit arriver une fois.
    private func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Molago"
        content.body = "Three texts for this morning."
        content.sound = .default

        var when = DateComponents()
        when.hour = hour
        when.minute = minute

        center.add(UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        ))
    }

    var timeLabel: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
