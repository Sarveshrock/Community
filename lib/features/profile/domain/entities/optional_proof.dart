enum ProofType {
  github,
  leetcode,
  kaggle,
  huggingface,
  portfolio,
  certification,
  project
}

extension ProofTypeX on ProofType {
  String get value => name;

  String get label => switch (this) {
        ProofType.github => 'GitHub',
        ProofType.leetcode => 'LeetCode',
        ProofType.kaggle => 'Kaggle',
        ProofType.huggingface => 'Hugging Face',
        ProofType.portfolio => 'Portfolio',
        ProofType.certification => 'Certification',
        ProofType.project => 'Project',
      };

  static ProofType fromValue(String? value) {
    return ProofType.values
        .firstWhere((e) => e.value == value, orElse: () => ProofType.portfolio);
  }
}

/// Entirely optional (spec section 5 & 16) — never required for profile
/// completion.
class OptionalProof {
  const OptionalProof({
    required this.id,
    required this.proofType,
    this.url,
    this.title,
    this.description,
    this.verified = false,
  });

  final String id;
  final ProofType proofType;
  final String? url;
  final String? title;
  final String? description;
  final bool verified;

  factory OptionalProof.fromJson(Map<String, dynamic> json) => OptionalProof(
        id: json['id'] as String,
        proofType: ProofTypeX.fromValue(json['proof_type'] as String?),
        url: json['url'] as String?,
        title: json['title'] as String?,
        description: json['description'] as String?,
        verified: json['verified'] as bool? ?? false,
      );

  Map<String, dynamic> toInsertJson(String profileId) => {
        'profile_id': profileId,
        'proof_type': proofType.value,
        'url': url,
        'title': title,
        'description': description,
      };
}
