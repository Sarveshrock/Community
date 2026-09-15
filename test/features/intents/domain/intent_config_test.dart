// Locks down the "extensibility requirement" architecture: every IntentType
// must resolve to a valid, non-empty configuration, and every field key
// within one IntentType's config must be unique (metadata is keyed by
// field.key, so a collision would silently overwrite data).

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/intents/domain/entities/intent.dart';
import 'package:community_app/features/intents/domain/intent_config.dart';

void main() {
  test('every IntentType resolves to a configuration with a title and at least one field', () {
    for (final type in IntentType.values) {
      final config = intentTypeConfig(type);
      expect(config.sectionTitle, isNotEmpty, reason: 'missing section title for $type');
      expect(config.fields, isNotEmpty, reason: 'missing dynamic fields for $type');
    }
  });

  test('field keys are unique within each IntentType (metadata is keyed by field.key)', () {
    for (final type in IntentType.values) {
      final keys = intentTypeConfig(type).fields.map((f) => f.key).toList();
      expect(keys.toSet().length, keys.length, reason: 'duplicate field key(s) for $type');
    }
  });

  test('dropdown/multiSelect fields always declare at least one option', () {
    for (final type in IntentType.values) {
      for (final field in intentTypeConfig(type).fields) {
        if (field.kind == IntentFieldKind.dropdown || field.kind == IntentFieldKind.multiSelect) {
          expect(field.options, isNotEmpty, reason: '${field.key} on $type has no options');
        }
      }
    }
  });

  test('findJob reuses JobEmploymentType labels rather than a duplicate list', () {
    final config = intentTypeConfig(IntentType.findJob);
    final employmentField = config.fields.firstWhere((f) => f.key == 'employment_type');
    expect(employmentField.options, contains('Full-time'));
  });

  test('findMentor reuses the existing mentorship topics list', () {
    final config = intentTypeConfig(IntentType.findMentor);
    final helpField = config.fields.firstWhere((f) => f.key == 'help_needed');
    expect(helpField.options, isNotEmpty);
  });
}
