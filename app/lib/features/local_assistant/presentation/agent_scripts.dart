import '../../../core/agent/agent_controller.dart';
import '../../../core/agent/agent_targets.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../search/domain/nearby_category.dart';
import '../domain/intent_router.dart';
import 'ai_reply_builder.dart' show nearbyCategoryLabel;

/// Tekan alat peta: terus jika kelihatan pada kapsul alat, jika tidak melalui menu "lagi".
Future<bool> _tapTool(AgentRunner r, String id) async {
  if (AgentTargets.has(id)) return r.tap(id);
  if (!await r.tap('tool.more', timeout: const Duration(seconds: 2))) {
    return false;
  }
  return r.tap('menu.$id');
}

/// Langkah ejen untuk [intent]. Setiap langkah menekan/menaip pada kawalan sebenar; langkah pertama
/// sentiasa kembali ke peta (menutup halaman AI) supaya pengguna melihat semuanya berlaku.
List<AgentStep> agentStepsFor(OpenScreenIntent intent, AppLocalizations l10n) {
  final toMap = AgentStep(l10n.agentStepMap, (r) async {
    await r.popToMap();
    return r.waitFor('map.search');
  });
  AgentStep tool(String label, String id) =>
      AgentStep(label, (r) => _tapTool(r, id));
  final arg = intent.arg?.trim();
  switch (intent.screen) {
    case AppScreen.weather:
      return [
        toMap,
        tool(l10n.agentStepOpen(l10n.weatherOpen), 'tool.weather'),
        if (arg != null && arg.isNotEmpty) ...[
          AgentStep(l10n.agentStepSearch(arg), (r) async {
            if (!await r.tap('weather.search')) return false;
            return r.type('weather.search.input', arg);
          }),
          AgentStep(
            l10n.agentStepPickFirst,
            (r) async =>
                await r.tapResult(
                  'weather.result.0',
                  inputId: 'weather.search.input',
                ) &&
                await r.waitGone('weather.search.input'),
          ),
        ],
      ];
    case AppScreen.masjidDirectory:
      return [
        toMap,
        tool(l10n.agentStepOpen(l10n.masjidOpen), 'tool.masjid'),
        if (arg != null && arg.isNotEmpty)
          AgentStep(
            l10n.agentStepSearch(arg),
            (r) => r.type('masjid.search.input', arg),
          ),
      ];
    case AppScreen.qibla:
      return [toMap, tool(l10n.agentStepOpen(l10n.qiblaOpen), 'tool.qibla')];
    case AppScreen.airQuality:
      return [toMap, tool(l10n.agentStepOpen(l10n.airQualityOpen), 'tool.air')];
    case AppScreen.music:
      return [toMap, tool(l10n.agentStepOpen(l10n.musicOpen), 'tool.music')];
    case AppScreen.offlineMaps:
      return [
        toMap,
        tool(l10n.agentStepOpen(l10n.offlineMapsOpen), 'tool.offline'),
      ];
    case AppScreen.prayerTimes:
      return [
        toMap,
        AgentStep(
          l10n.agentStepOpen(l10n.azanTitle),
          (r) => r.tap('map.prayer'),
        ),
      ];
    case AppScreen.settings:
      return [
        toMap,
        AgentStep(
          l10n.agentStepOpen(l10n.settingsTitle),
          (r) => r.tap('map.settings'),
        ),
      ];
    case AppScreen.report:
      return [
        toMap,
        AgentStep(
          l10n.agentStepOpen(l10n.agentReport),
          (r) => r.tap('map.report'),
        ),
      ];
    case AppScreen.recenter:
      return [
        toMap,
        AgentStep(l10n.agentStepRecenter, (r) => r.tap('map.locate')),
      ];
    case AppScreen.findPlace:
      final q = arg ?? '';
      return [
        toMap,
        AgentStep(l10n.agentStepOpenSearch, (r) => r.tap('map.search')),
        AgentStep(
          l10n.agentStepType(q),
          (r) => r.type('planner.destination', q),
        ),
        AgentStep(
          l10n.agentStepPickFirst,
          (r) => r.tapResult(
            'planner.result.0',
            inputId: 'planner.destination',
            timeout: const Duration(seconds: 10),
          ),
        ),
        AgentStep(
          l10n.agentStepRouteReady,
          (r) => r.waitFor('route.start', timeout: const Duration(seconds: 25)),
        ),
      ];
    case AppScreen.nearbyGo:
      final category = NearbyCategory.values
          .where((c) => c.name == arg)
          .firstOrNull;
      if (category == null) return [toMap];
      final label = nearbyCategoryLabel(l10n, category);
      return [
        toMap,
        AgentStep(l10n.agentStepOpenSearch, (r) => r.tap('map.search')),
        AgentStep(
          l10n.agentStepCategory(label),
          (r) => r.tap('planner.category.${category.name}'),
        ),
        AgentStep(
          l10n.agentStepPickNearest,
          (r) =>
              r.tap('planner.result.0', timeout: const Duration(seconds: 15)),
        ),
        AgentStep(
          l10n.agentStepRouteReady,
          (r) => r.waitFor('route.start', timeout: const Duration(seconds: 25)),
        ),
        if (intent.start)
          AgentStep(l10n.agentStepStart, (r) => r.tap('route.start')),
      ];
  }
}

/// Tajuk kad status ejen.
String agentTitleFor(OpenScreenIntent intent, AppLocalizations l10n) {
  final arg = intent.arg?.trim() ?? '';
  return switch (intent.screen) {
    AppScreen.weather =>
      arg.isEmpty ? l10n.weatherOpen : '${l10n.weatherOpen}: $arg',
    AppScreen.qibla => l10n.qiblaOpen,
    AppScreen.masjidDirectory =>
      arg.isEmpty ? l10n.masjidOpen : '${l10n.masjidOpen}: $arg',
    AppScreen.airQuality => l10n.airQualityOpen,
    AppScreen.music => l10n.musicOpen,
    AppScreen.prayerTimes => l10n.azanTitle,
    AppScreen.offlineMaps => l10n.offlineMapsOpen,
    AppScreen.settings => l10n.settingsTitle,
    AppScreen.report => l10n.agentReport,
    AppScreen.recenter => l10n.agentStepRecenter,
    AppScreen.findPlace => l10n.agentFindTitle(arg),
    AppScreen.nearbyGo => l10n.agentFindTitle(
      NearbyCategory.values
              .where((c) => c.name == arg)
              .map((c) => nearbyCategoryLabel(l10n, c))
              .firstOrNull ??
          arg,
    ),
  };
}
