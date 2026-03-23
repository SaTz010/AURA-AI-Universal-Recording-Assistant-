import 'package:flutter/material.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Terms & Conditions',
      sections: [
        _LegalSection(
          heading: '1. Acceptance of Terms',
          body:
              'By using AURA, you agree to these terms as a baseline agreement for responsible and lawful usage of the platform.',
        ),
        _LegalSection(
          heading: '2. Responsible Use',
          body:
              'You agree to use recordings and generated summaries ethically, and to respect consent requirements in your region before capturing audio.',
        ),
        _LegalSection(
          heading: '3. Account Access',
          body:
              'You are responsible for activity under your account or guest session and should avoid sharing access with unauthorized users.',
        ),
        _LegalSection(
          heading: '4. Service Availability',
          body:
              'AURA may evolve over time, and features may be updated, refined, or temporarily unavailable while we improve reliability and quality.',
        ),
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Privacy Policy',
      sections: [
        _LegalSection(
          heading: '1. Data We Process',
          body:
              'AURA may process profile details, recording metadata, and app usage information to deliver core features and improve your experience.',
        ),
        _LegalSection(
          heading: '2. How Data Is Used',
          body:
              'Information is used to support authentication, sync your activity, and provide relevant AI-assisted recording and summary workflows.',
        ),
        _LegalSection(
          heading: '3. Data Protection',
          body:
              'We apply reasonable technical safeguards to protect your data and continuously review our practices to improve security and reliability.',
        ),
        _LegalSection(
          heading: '4. Your Choices',
          body:
              'You can sign out, clear local app data, and request data-related support through future account privacy controls as they become available.',
        ),
      ],
    );
  }
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.title, required this.sections});

  final String title;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(title, style: AuraTypography.titleLarge(colors.textPrimary)),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AuraSpacing.xl),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: AuraSpacing.lg),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Container(
            padding: const EdgeInsets.all(AuraSpacing.base),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AuraRadius.mdBr,
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.heading,
                  style: AuraTypography.titleMedium(colors.textPrimary),
                ),
                const SizedBox(height: AuraSpacing.sm),
                Text(
                  section.body,
                  style: AuraTypography.bodyMedium(colors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}
