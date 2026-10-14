import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/system_share/system_share.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Room invites: the link people share and how the app reads it back.
abstract final class RoomInvite {
  /// The landing page: opens the app if it's installed, otherwise offers
  /// the store or the web app. Invites point here.
  static const String landingHost = 'emotional-app-b42af.web.app';

  /// The web app (Firebase Hosting site `emoti-izle`).
  static const String webAppHost = 'emoti-izle.web.app';

  /// Android registers `emotional`; iOS used to register only `emoti`.
  static const Set<String> appSchemes = {'emotional', 'emoti'};

  static Uri link(String roomId) => Uri.https(landingHost, '/join/$roomId');

  static Uri webAppLink(String roomId) =>
      Uri.https(webAppHost, '/join/$roomId');

  static final RegExp _roomId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The room in an invite link, or null if [uri] isn't one:
  /// `emotional://join/123`, `emotional://join?id=123`,
  /// `https://<landing or web app>/join/123`. [ownHost] also accepts the
  /// page the web app runs on (preview channels, custom domains).
  static String? roomIdFrom(Uri uri, {String? ownHost}) {
    String? roomId;
    if (appSchemes.contains(uri.scheme)) {
      final segments = [
        if (uri.host.isNotEmpty) uri.host,
        ...uri.pathSegments.where((s) => s.isNotEmpty),
      ];
      final index = segments.indexWhere((s) => s == 'join' || s == 'room');
      if (index != -1) {
        roomId = index + 1 < segments.length
            ? segments[index + 1]
            : uri.queryParameters['id'];
      }
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        {landingHost, webAppHost, ?ownHost}.contains(uri.host)) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final index = segments.indexOf('join');
      if (index != -1 && index + 1 < segments.length) {
        roomId = segments[index + 1];
      }
    }
    roomId = roomId?.trim();
    return roomId != null && _roomId.hasMatch(roomId) ? roomId : null;
  }

  /// Opens the share sheet with the invite; browsers without one copy the
  /// link instead of falling back to an email draft.
  static Future<void> share(
    BuildContext context,
    String roomId, {
    @visibleForTesting bool? systemShareAvailable,
  }) async {
    if (kIsWeb && !(systemShareAvailable ?? canUseSystemShare)) {
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: link(roomId).toString()));
      messenger.showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.room_inviteLinkCopied.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        text: LocaleKeys.room_inviteMessage.tr(args: [roomId, roomId]),
        subject: LocaleKeys.room_inviteTitle.tr(),
      ),
    );
  }
}
