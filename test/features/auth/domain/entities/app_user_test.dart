// Locks down AppUser's value equality — the actual bug behind "profile
// keeps disappearing": authStateProvider wraps Supabase's onAuthStateChange
// stream directly, which re-emits (TOKEN_REFRESHED, INITIAL_SESSION, app
// resume, ...) for the *same* signed-in user far more often than the user
// actually signs in/out. Without ==, every one of those re-emissions looked
// like a new value to Riverpod, and nearly every provider in the app
// watches authStateProvider — so each tick re-fetched and briefly showed a
// loading state everywhere, including Profile.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/auth/domain/entities/app_user.dart';

void main() {
  test('two AppUsers with the same fields are equal', () {
    const a = AppUser(id: 'u1', email: 'a@b.com', emailConfirmed: true);
    const b = AppUser(id: 'u1', email: 'a@b.com', emailConfirmed: true);

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('a changed field makes two AppUsers unequal', () {
    const a = AppUser(id: 'u1', email: 'a@b.com');
    const differentId = AppUser(id: 'u2', email: 'a@b.com');
    const differentEmail = AppUser(id: 'u1', email: 'c@d.com');
    const differentConfirmed = AppUser(id: 'u1', email: 'a@b.com', emailConfirmed: true);

    expect(a, isNot(equals(differentId)));
    expect(a, isNot(equals(differentEmail)));
    expect(a, isNot(equals(differentConfirmed)));
  });

  test('a null email compares equal to another null email', () {
    const a = AppUser(id: 'u1', email: null);
    const b = AppUser(id: 'u1', email: null);

    expect(a, equals(b));
  });
}
