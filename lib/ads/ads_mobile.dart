// Anuncios en Android y iPhone (Google AdMob).
// En la web se usa ads_stub.dart (no hay anuncios), ver ads.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import '../theme/app_colors.dart';

/// Anuncios con Google AdMob (solo en Android y iPhone; en la web no hay).
///
/// Filtro de contenido: se piden SOLO anuncios clasificados "G" (aptos para
/// todo público). Eso deja fuera anuncios para adultos. Además, en la consola
/// de AdMob se bloquean las categorías sensibles (apuestas y casinos,
/// citas, contenido sexual, etc.); ver ANUNCIOS.md.
class AdsService {
  AdsService._();

  static bool get supported =>
      AdsConfig.enabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS ? AdsConfig.iosBanner : AdsConfig.androidBanner;

  static Future<void> init() async {
    if (!supported) return;
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
    } catch (_) {
      // Si los anuncios fallan, la app sigue funcionando normal.
    }
  }
}

/// Espacio para un anuncio. Si no hay anuncio (web, sin internet o sin
/// anuncios disponibles) no ocupa lugar.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.large = false});

  /// true = rectángulo mediano (300 × 250); false = banner (320 × 50).
  final bool large;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!AdsService.supported) return;
    _ad = BannerAd(
      adUnitId: AdsService.bannerUnitId,
      size: widget.large ? AdSize.mediumRectangle : AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('Publicidad', style: TextStyle(fontSize: 10, color: AppColors.muted)),
        ),
        SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ],
    );
  }
}
