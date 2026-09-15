/// Thin wrapper around the authenticated identity. Profile completeness is
/// tracked separately via profiles.profile_completed and fetched by the
/// profile feature — this entity only carries what auth itself owns.
///
/// Value equality matters here more than it looks: Supabase's
/// `onAuthStateChange` re-emits on every `TOKEN_REFRESHED`/`INITIAL_SESSION`
/// event — periodically, and on app resume — even when the signed-in user
/// hasn't changed at all. `authStateProvider` wraps that stream directly, and
/// nearly every other provider in the app (`myProfileProvider`,
/// `myOptionalProofsProvider`, connection/notification/admin providers, ...)
/// watches it. Without `==`, each of those re-emissions produced a "new"
/// `AppUser` by identity, so every dependent provider treated it as a real
/// change and re-fetched from the network — which is what made the Profile
/// page (and others) visibly flash to a loading state and back repeatedly
/// ("disappearing"), with no actual sign-in/out ever happening. With value
/// equality, a same-valued re-emission is a no-op for every watcher.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.emailConfirmed = false,
  });

  final String id;
  final String? email;
  final bool emailConfirmed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          emailConfirmed == other.emailConfirmed;

  @override
  int get hashCode => Object.hash(id, email, emailConfirmed);
}
