import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/moderation/bloc/moderation_bloc.dart';
import 'package:emotional/features/moderation/data/report_model.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A dialog that allows users to report objectionable content or abusive users.
class ReportDialog extends StatefulWidget {
  final String reporterUserId;
  final String reportedUserId;
  final String reportedUserName;
  final String roomId;
  final String? messageId;
  final String? messageText;

  const ReportDialog({
    super.key,
    required this.reporterUserId,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.roomId,
    this.messageId,
    this.messageText,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String _selectedReason = 'inappropriate';
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  static const _reasons = [
    'inappropriate',
    'harassment',
    'spam',
    'other',
  ];

  String _getReasonLabel(String reason) {
    switch (reason) {
      case 'inappropriate':
        return LocaleKeys.moderation_report_reasons_inappropriate.tr();
      case 'harassment':
        return LocaleKeys.moderation_report_reasons_harassment.tr();
      case 'spam':
        return LocaleKeys.moderation_report_reasons_spam.tr();
      case 'other':
        return LocaleKeys.moderation_report_reasons_other.tr();
      default:
        return reason;
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final report = ReportModel(
      id: '',
      reporterUserId: widget.reporterUserId,
      reportedUserId: widget.reportedUserId,
      reportedUserName: widget.reportedUserName,
      messageId: widget.messageId,
      messageText: widget.messageText,
      roomId: widget.roomId,
      reason: _selectedReason,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    context.read<ModerationBloc>().add(SubmitReportRequested(report));

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.moderation_report_success.tr()),
          backgroundColor: ColorsCustom.darkABlue,
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMessageReport = widget.messageId != null;

    return AlertDialog(
      backgroundColor: ColorsCustom.darkABlue,
      shape: RoundedRectangleBorder(borderRadius: ProjectRadius.xlarge()),
      title: Row(
        children: [
          const Icon(Icons.flag_outlined, color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          Text(
            isMessageReport
                ? LocaleKeys.moderation_report_reportMessage.tr()
                : LocaleKeys.moderation_report_reportUser.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show reported message preview if reporting a message
            if (isMessageReport && widget.messageText != null) ...[
              Container(
                padding: const ProjectPadding.allMedium(),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: ProjectRadius.medium(),
                ),
                child: Text(
                  '"${widget.messageText}"',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Reason selection
            Text(
              LocaleKeys.moderation_report_reason.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._reasons.map((reason) => RadioListTile<String>(
                  title: Text(
                    _getReasonLabel(reason),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  value: reason,
                  groupValue: _selectedReason,
                  activeColor: ColorsCustom.skyBlue,
                  onChanged: (value) {
                    setState(() => _selectedReason = value!);
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
            const SizedBox(height: 12),
            // Description
            Text(
              LocaleKeys.moderation_report_description.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: LocaleKeys.moderation_report_descriptionHint.tr(),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: ProjectRadius.medium(),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            LocaleKeys.button_cancel.tr(),
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitReport,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(LocaleKeys.moderation_report_submit.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: ProjectRadius.medium(),
            ),
          ),
        ),
      ],
    );
  }
}
