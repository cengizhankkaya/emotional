import 'package:flutter/material.dart';
import '../utility/validator/version_validator.dart';
import '../widget/dialog/force_update_dialog.dart';

class VersionCheckWrapper extends StatefulWidget {
  const VersionCheckWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersion();
    });
  }

  Future<void> _checkVersion() async {
    if (await VersionValidator.check()) {
      if (mounted) {
        await ForceUpdateDialog.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
