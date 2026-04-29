import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// فتح رابط — على الويب في نافذة جديدة، على الهاتف بالمتصفح
Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  if (kIsWeb) {
    await launchUrl(uri, webOnlyWindowName: '_blank');
  } else {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// تنزيل ملف على الويب (CSV, ZIP, ...)
Future<void> downloadFile(String url, String filename) async {
  // على الويب: نفتح الرابط مباشرة — المتصفح يتولى التنزيل
  // على الهاتف: نفتح بالمتصفح
  await openUrl(url);
}
