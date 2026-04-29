import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/platform_service.dart';

/// يعرض صورة المستفيد — URL على الويب، File على الهاتف
class BeneficiaryImage extends StatelessWidget {
  final String? imagePath;
  final String? imageFileName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const BeneficiaryImage({
    super.key,
    this.imagePath,
    this.imageFileName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final ph = placeholder ??
        Container(
          color: Colors.grey.shade100,
          child: const Icon(Icons.home_outlined,
              color: Colors.grey, size: 28),
        );

    if (kIsWeb) {
      // على الويب: نجلب من السيرفر
      final url = PlatformService().imageUrl(imageFileName);
      if (url == null) return ph;
      return Image.network(
        url,
        width: width, height: height, fit: fit,
        errorBuilder: (_, __, ___) => ph,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width, height: height,
            child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    } else {
      // على الهاتف: من الملف المحلي
      if (imagePath == null || imagePath!.isEmpty) return ph;
      final file = File(imagePath!);
      if (!file.existsSync()) return ph;
      return Image.file(
        file,
        width: width, height: height, fit: fit,
        errorBuilder: (_, __, ___) => ph,
      );
    }
  }
}
