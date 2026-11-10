// En la web no hay anuncios: estas versiones no hacen nada.
import 'package:flutter/widgets.dart';

class AdsService {
  AdsService._();
  static bool get supported => false;
  static Future<void> init() async {}
}

class AdBanner extends StatelessWidget {
  const AdBanner({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
