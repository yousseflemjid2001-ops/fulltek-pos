import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class OfflineLicenseResultCard extends StatelessWidget {
  final OfflineLicenseResponse license;
  final String Function(String) tr;
  final ValueChanged<String>? onCopied;

  const OfflineLicenseResultCard({
    super.key,
    required this.license,
    required this.tr,
    this.onCopied,
  });

  void _copyValue(BuildContext context, String value, String feedbackLabel) {
    Clipboard.setData(ClipboardData(text: value));
    if (onCopied != null) {
      onCopied!(feedbackLabel);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$feedbackLabel · ${tr('copied_ok')}')),
        );
    }
  }

  String _formatExpiry(String iso) {
    final trimmed = iso.trim();
    if (trimmed.isEmpty) return '—';
    if (trimmed.contains('T')) {
      final parts = trimmed.split('T');
      final date = parts[0];
      final time = parts[1].replaceAll('Z', '').split('.').first;
      return '$date $time UTC';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('offline_license_result_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FTColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FTColors.ochre.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tr('code_lbl'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: FTColors.muted,
                ),
              ),
              _pill('+${license.days}j', FTColors.ochre),
              _pill(
                tr('lic_grace').replaceAll('{d}', '${license.graceDays}'),
                FTColors.pharma,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                license.code,
                key: const Key('license_code_value'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  color: FTColors.ochre,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              key: const Key('copy_license_code'),
              onPressed: () => _copyValue(context, license.code, tr('code_lbl')),
              icon: const Icon(Icons.copy, size: 15),
              label: Text(tr('copy_btn')),
            ),
          ),
          const Divider(height: 18, color: Colors.white10),
          _metaRow(tr('lic_key_id'), license.keyId.isEmpty ? '—' : license.keyId),
          const SizedBox(height: 4),
          _metaRow(tr('lic_expires'), _formatExpiry(license.expiresAt)),
          if (license.leaseToken.isNotEmpty) ...[
            const SizedBox(height: 10),
            _cryptoBlock(
              context,
              title: tr('lic_token_lbl'),
              value: license.leaseToken,
              valueKey: const Key('license_lease_token_value'),
              copyKey: const Key('copy_lease_token'),
              copyLabel: tr('lic_copy_token'),
              maxLines: 3,
            ),
          ],
          if (license.signature.isNotEmpty) ...[
            const SizedBox(height: 10),
            _cryptoBlock(
              context,
              title: tr('lic_sig_lbl'),
              value: license.signature,
              valueKey: const Key('license_signature_value'),
              copyKey: const Key('copy_license_signature'),
              copyLabel: tr('lic_copy_sig'),
              maxLines: 2,
            ),
          ],
          if (license.publicKey.isNotEmpty) ...[
            const SizedBox(height: 10),
            _cryptoBlock(
              context,
              title: tr('lic_pub_lbl'),
              value: license.publicKey,
              valueKey: const Key('license_public_key_value'),
              copyKey: const Key('copy_public_key'),
              copyLabel: tr('lic_copy_pub'),
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: FTColors.muted),
          ),
        ),
        Expanded(
          flex: 6,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: FTColors.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cryptoBlock(
    BuildContext context, {
    required String title,
    required String value,
    required Key valueKey,
    required Key copyKey,
    required String copyLabel,
    required int maxLines,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FTColors.night,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: FTColors.ink2,
                  ),
                ),
              ),
              TextButton.icon(
                key: copyKey,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => _copyValue(context, value, title),
                icon: const Icon(Icons.copy, size: 13),
                label: Text(
                  copyLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              value,
              key: valueKey,
              maxLines: maxLines,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: FTColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
