import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Uygulama genelinde kullanılan icon'ların merkezi yönetimi
final class AppIcons {
  AppIcons._();

  // Genel İşlemler
  static const IconData close = Icons.close_outlined;
  static const IconData info = Icons.info_outlined;
  static const IconData add = Icons.add_outlined;
  static const IconData delete = Icons.delete_outlined;
  static const IconData edit = Icons.edit_outlined;
  static const IconData save = Icons.save_outlined;

  // Navigasyon
  static const IconData home = Icons.home;
  static const IconData search = Icons.search_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData back = Icons.arrow_back;
  static const IconData forward = Icons.arrow_forward;
  static const IconData menu = Icons.menu_outlined;

  // İletişim
  static const IconData phone = Icons.phone;
  static const IconData email = Icons.email_outlined;
  static const IconData share = Icons.share_rounded;
  static const IconData sendMessage = FontAwesomeIcons.whatsapp;

  // Konum
  static const IconData location = Icons.location_on;
  static const IconData map = Icons.map_outlined;

  // Medya
  static const IconData camera = Icons.camera_alt_outlined;
  static const IconData gallery = Icons.image_outlined;
  static const IconData photo = Icons.photo_outlined;
  static const IconData video = Icons.videocam_outlined;

  // Zaman
  static const IconData calendar = Icons.calendar_today;
  static const IconData time = Icons.access_time;

  // Kullanıcı
  static const IconData person = Icons.person_outlined;
  static const IconData group = Icons.group_outlined;

  // Favoriler
  static const IconData favorite = Icons.favorite;
  static const IconData favoriteBorder = Icons.favorite_border_outlined;

  // Bildirimler
  static const IconData notifications = Icons.notifications_outlined;
  static const IconData notificationsOff = Icons.notifications_off_outlined;

  // Diğer
  static const IconData filter = Icons.filter_list_outlined;
  static const IconData sort = Icons.sort_outlined;
  static const IconData download = Icons.download_outlined;
  static const IconData upload = Icons.upload_outlined;

  // Oda & Video
  static const IconData room = Icons.meeting_room_outlined;
  static const IconData videoCall = Icons.video_call_outlined;
  static const IconData chat = Icons.chat_bubble_outline;
  static const IconData chair = Icons.chair;

  // Sosyal Medya (Font Awesome)
  static const IconData facebook = FontAwesomeIcons.facebook;
  static const IconData twitter = FontAwesomeIcons.twitter;
  static const IconData instagram = FontAwesomeIcons.instagram;
  static const IconData youtube = FontAwesomeIcons.youtube;
  static const IconData linkedin = FontAwesomeIcons.linkedin;
}
