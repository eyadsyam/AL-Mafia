import 'ad_placement_registry.dart';

/// Adapter ownership token: route/identity/consent changes invalidate loads.
class AdIntentV4 {
  final int generation, revision;
  final String placementId, unitId;
  const AdIntentV4(
    this.generation,
    this.revision,
    this.placementId,
    this.unitId,
  );
}

class AdSessionV4 {
  int _generation = 0;
  final Set<AdIntentV4> _loads = {};
  final Set<AdIntentV4> _ready = {};
  AdIntentV4? _showing;
  bool _disposed = false;
  bool get fullscreenBusy => _showing != null;
  int get pendingLoads => _loads.length;

  AdIntentV4? beginLoad(AdPlacementV4 placement, AdRegistryV4 registry) {
    final unit = registry.units[placement.id];
    if (_disposed ||
        unit == null ||
        _loads.length + _ready.length >= 2 ||
        {..._loads, ..._ready}.any((t) {
          final existing = adInventoryV4.singleWhere(
            (p) => p.id == t.placementId,
          );
          return t.placementId == placement.id ||
              (placement.automatic && existing.automatic) ||
              (placement.format == AdFormatV4.rewarded &&
                  existing.format == AdFormatV4.rewarded) ||
              (!placement.fullscreen && !existing.fullscreen);
        })) {
      return null;
    }
    final token = AdIntentV4(
      _generation,
      registry.revision,
      placement.id,
      unit,
    );
    _loads.add(token);
    return token;
  }

  bool valid(AdIntentV4 token, AdRegistryV4 registry) =>
      !_disposed &&
      token.generation == _generation &&
      token.revision == registry.revision &&
      token.unitId == registry.units[token.placementId];
  bool finishLoad(AdIntentV4 token, AdRegistryV4 registry) {
    if (!_loads.remove(token) || !valid(token, registry)) {
      return false;
    }
    _ready.add(token);
    return true;
  }

  bool acquireFullscreen(AdIntentV4 token, AdRegistryV4 registry) {
    if (_showing != null ||
        !valid(token, registry) ||
        !_ready.contains(token) ||
        !adInventoryV4
            .singleWhere((p) => p.id == token.placementId)
            .fullscreen) {
      return false;
    }
    _ready.remove(token);
    _showing = token;
    return true;
  }

  void releaseFullscreen(AdIntentV4 token) {
    if (identical(_showing, token)) _showing = null;
  }

  /// A visible SDK ad retains the mutex until its dismissal callback.
  void invalidate() {
    _generation++;
    _loads.clear();
    _ready.clear();
  }

  void dispose() {
    invalidate();
    _disposed = true;
  }
}
