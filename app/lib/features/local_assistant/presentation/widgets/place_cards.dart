import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../route_preview/presentation/route_format.dart';
import '../../../search/domain/nearby_category.dart';
import '../../domain/assistant_message.dart';

/// Ikon kategori tempat (kad hasil, cip pantas). Carian nama biasa (tiada kategori) = penanda lokasi.
IconData categoryIcon(NearbyCategory? c) => switch (c) {
  NearbyCategory.fuel => Icons.local_gas_station_rounded,
  NearbyCategory.food => Icons.restaurant_rounded,
  NearbyCategory.mosque => Icons.mosque_rounded,
  NearbyCategory.toilets => Icons.wc_rounded,
  NearbyCategory.parking => Icons.local_parking_rounded,
  NearbyCategory.hospital => Icons.local_hospital_rounded,
  NearbyCategory.clinic => Icons.medical_services_rounded,
  NearbyCategory.barber => Icons.content_cut_rounded,
  NearbyCategory.pharmacy => Icons.local_pharmacy_rounded,
  NearbyCategory.atm => Icons.atm_rounded,
  NearbyCategory.bank => Icons.account_balance_rounded,
  NearbyCategory.convenience => Icons.storefront_rounded,
  NearbyCategory.supermarket => Icons.shopping_cart_rounded,
  NearbyCategory.mall => Icons.local_mall_rounded,
  NearbyCategory.carWash => Icons.local_car_wash_rounded,
  NearbyCategory.workshop => Icons.build_rounded,
  NearbyCategory.tyres => Icons.tire_repair_rounded,
  NearbyCategory.laundry => Icons.local_laundry_service_rounded,
  NearbyCategory.hotel => Icons.hotel_rounded,
  NearbyCategory.police => Icons.local_police_rounded,
  NearbyCategory.postOffice => Icons.local_post_office_rounded,
  NearbyCategory.evCharging => Icons.ev_station_rounded,
  NearbyCategory.trainStation => Icons.train_rounded,
  null => Icons.place_rounded,
};

/// Warna lencana kategori: kumpulan yang sama berkongsi warna supaya senarai mudah diimbas.
Color categoryTint(NearbyCategory? c) => switch (c) {
  NearbyCategory.fuel => const Color(0xFFEA580C),
  NearbyCategory.food => const Color(0xFFE11D48),
  NearbyCategory.mosque => const Color(0xFF059669),
  NearbyCategory.toilets => const Color(0xFF0284C7),
  NearbyCategory.parking => const Color(0xFF2563EB),
  NearbyCategory.hospital => const Color(0xFFDC2626),
  NearbyCategory.clinic => const Color(0xFFDC2626),
  NearbyCategory.pharmacy => const Color(0xFF0D9488),
  NearbyCategory.barber => const Color(0xFF7C3AED),
  NearbyCategory.atm => const Color(0xFF16A34A),
  NearbyCategory.bank => const Color(0xFF16A34A),
  NearbyCategory.convenience => const Color(0xFFD97706),
  NearbyCategory.supermarket => const Color(0xFFD97706),
  NearbyCategory.mall => const Color(0xFFD97706),
  NearbyCategory.carWash => const Color(0xFF0891B2),
  NearbyCategory.workshop => const Color(0xFF475569),
  NearbyCategory.tyres => const Color(0xFF475569),
  NearbyCategory.laundry => const Color(0xFF0891B2),
  NearbyCategory.hotel => const Color(0xFF9333EA),
  NearbyCategory.police => const Color(0xFF1D4ED8),
  NearbyCategory.postOffice => const Color(0xFFDC2626),
  NearbyCategory.evCharging => const Color(0xFF22C55E),
  NearbyCategory.trainStation => const Color(0xFF4F46E5),
  null => const Color(0xFF2563EB),
};

/// Senarai kad tempat dalam jawapan: ikon kategori, nama, kawasan (untuk membezakan dua "Caltex"),
/// jarak, dan butang bulat "pergi". Seluruh kad boleh diketik.
class PlaceCards extends StatelessWidget {
  const PlaceCards({
    super.key,
    required this.places,
    required this.accent,
    required this.onGo,
  });

  final List<ChatPlace> places;
  final Color accent;
  final ValueChanged<ChatPlace> onGo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < places.length; i++)
          _Appear(
            index: i,
            child: Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _PlaceCard(
                key: ValueKey('ai-place-card-$i'),
                index: i,
                place: places[i],
                accent: accent,
                nearest:
                    i == 0 && places.length > 1 && places[i].distanceM != null,
                onGo: () => onGo(places[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    super.key,
    required this.index,
    required this.place,
    required this.accent,
    required this.nearest,
    required this.onGo,
  });

  final int index;
  final ChatPlace place;
  final Color accent;
  final bool nearest;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = categoryTint(place.category);
    final meters = place.distanceM;
    final distance = meters == null ? null : formatDistance(l10n, meters);
    final area = place.area;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [place.name, ?area, ?distance].join(', '),
      onTap: onGo,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onGo,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: nearest
                    ? tint.withValues(alpha: 0.55)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
                width: nearest ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tint.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.24 : 0.14,
                    ),
                  ),
                  child: Icon(
                    categoryIcon(place.category),
                    color: tint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (nearest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tint.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.aiPlaceNearest,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: tint,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (area != null || distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [?distance, ?area].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.aiActionRouteTo(place.name),
                  child: Container(
                    key: ValueKey('ai-place-go-$index'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent,
                          Color.lerp(accent, const Color(0xFF1D4ED8), 0.45)!,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.directions_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadangan yang boleh diketik ("Stesen minyak terdekat"): menghantar teksnya sebagai mesej pengguna.
class AskChip extends StatelessWidget {
  const AskChip({
    super.key,
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon,
    this.tint,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;
  final IconData? icon;

  /// Warna ikon (lalai: [accent]); cip kategori memakai warna kategori.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final iconColor = tint ?? accent;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        color: accent.withValues(alpha: dark ? 0.16 : 0.08),
        shape: StadiumBorder(
          side: BorderSide(color: accent.withValues(alpha: dark ? 0.45 : 0.3)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? Icons.auto_awesome_rounded,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dark
                          ? Color.lerp(accent, Colors.white, 0.45)
                          : accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kad masuk satu demi satu (fade + naik sedikit), setiap satu sedikit lebih lambat daripada yang
/// sebelumnya. Satu tween setiap kad: tiada pemasa, jadi `pumpAndSettle` selesai dan ia senyap
/// bila gerakan dikurangkan.
class _Appear extends StatelessWidget {
  const _Appear({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Motion.of(context, Motion.normal);
    if (base == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: base + Duration(milliseconds: 70 * index),
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
