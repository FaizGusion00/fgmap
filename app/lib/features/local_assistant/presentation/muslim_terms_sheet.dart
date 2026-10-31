import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/muslim_ai_settings.dart';

/// Dialog T&C ketat sebelum mengaktifkan FGMuslim AI.
Future<bool> showMuslimTermsSheet(BuildContext context, WidgetRef ref) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const SheetBottomInset(child: _MuslimTermsBody()),
  );
  return agreed == true;
}

class _MuslimTermsBody extends ConsumerStatefulWidget {
  const _MuslimTermsBody();

  @override
  ConsumerState<_MuslimTermsBody> createState() => _MuslimTermsBodyState();
}

class _MuslimTermsBodyState extends ConsumerState<_MuslimTermsBody> {
  bool _muslim = false;
  bool _notOfficial = false;
  bool _notAdvice = false;
  bool _thirdParty = false;
  bool _holdHarmless = false;

  bool get _all =>
      _muslim && _notOfficial && _notAdvice && _thirdParty && _holdHarmless;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.muslimAiTermsTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.muslimAiTermsLead,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.48,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _Check(
                    value: _muslim,
                    onChanged: (v) => setState(() => _muslim = v),
                    label: l10n.muslimAiTermsMuslim,
                  ),
                  _Check(
                    value: _notOfficial,
                    onChanged: (v) => setState(() => _notOfficial = v),
                    label: l10n.muslimAiTermsNotOfficial,
                  ),
                  _Check(
                    value: _notAdvice,
                    onChanged: (v) => setState(() => _notAdvice = v),
                    label: l10n.muslimAiTermsNotAdvice,
                  ),
                  _Check(
                    value: _thirdParty,
                    onChanged: (v) => setState(() => _thirdParty = v),
                    label: l10n.muslimAiTermsThirdParty,
                  ),
                  _Check(
                    value: _holdHarmless,
                    onChanged: (v) => setState(() => _holdHarmless = v),
                    label: l10n.muslimAiTermsHoldHarmless,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://islamic.app/'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(l10n.muslimAiOpenDeen),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('muslim-terms-agree'),
            onPressed: _all
                ? () async {
                    await ref
                        .read(muslimAiSettingsProvider.notifier)
                        .enableAfterAgreement();
                    if (context.mounted) Navigator.pop(context, true);
                  }
                : null,
            child: Text(l10n.muslimAiTermsAgree),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.muslimAiTermsCancel),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: value
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: value ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
          ),
        ),
      ),
    );
  }
}
