import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_localizations.dart';
import '../../engine/models/enums.dart' show GamePhase;
import '../../platform/haptics.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'fun_art.dart';
import 'loaded_capabilities.dart';

/// Phase 109: eight quick reactions, in the lobby and on the result only.
///
/// ## Why never during a match
///
/// A seal floating over a seat at night is a signal from that seat while roles
/// are acting — a channel, however silly the picture on it. So the bar is not
/// built in any match phase ([reactionsOpen]), the server refuses a reaction
/// in any match phase (`send_room_reaction` → REACTION_CLOSED), and therefore
/// the feed is silent through every phase by construction.
enum ReactionKind {
  laugh('laugh', '😂'),
  shock('shock', '😱'),
  suspicious('suspicious', '🤨'),
  applause('applause', '👏'),
  rose('rose', '🌹'),
  skull('skull', '💀'),
  coffee('coffee', '☕'),
  crown('crown', '👑');

  const ReactionKind(this.code, this.glyph);
  final String code;

  /// The mark pressed into the painted seal until the art arrives.
  final String glyph;

  static ReactionKind? fromCode(String code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

String reactionLabel(AppLocalizations l, ReactionKind kind) => switch (kind) {
  ReactionKind.laugh => l.reactionLaugh,
  ReactionKind.shock => l.reactionShock,
  ReactionKind.suspicious => l.reactionSuspicious,
  ReactionKind.applause => l.reactionApplause,
  ReactionKind.rose => l.reactionRose,
  ReactionKind.skull => l.reactionSkull,
  ReactionKind.coffee => l.reactionCoffee,
  ReactionKind.crown => l.reactionCrown,
};

/// The online lobby (`setup`) and a result whose outcome is public. Nothing
/// else — every other phase is a match in progress.
bool reactionsOpen(GamePhase? phase, {bool outcomePublic = false}) =>
    phase == GamePhase.setup ||
    ((phase == GamePhase.result || phase == GamePhase.analytics) &&
        outcomePublic);

/// The client's copy of the server's limit: a burst of three, then one per
/// 1.5 s (at most three in any 4.5 s window). The server is the authority;
/// this only spares a round trip that would be refused.
class ReactionThrottle {
  final List<DateTime> _sent = [];

  bool tryTake(DateTime now) {
    final window = FunTokens.reactionInterval * FunTokens.reactionBurst;
    _sent.removeWhere((t) => now.difference(t) >= window);
    if (_sent.length >= FunTokens.reactionBurst) return false;
    _sent.add(now);
    return true;
  }
}

/// Overridable clock for the throttle.
final reactionClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The row of eight seals. Renders nothing unless [open] and the server has
/// reactions on.
class ReactionBar extends ConsumerStatefulWidget {
  final String roomId;
  final OnlineBackend backend;

  /// [reactionsOpen] for where this bar is drawn.
  final bool open;

  const ReactionBar({
    super.key,
    required this.roomId,
    required this.backend,
    required this.open,
  });

  static const Key barKey = ValueKey('reaction_bar');
  static Key seal(ReactionKind kind) => ValueKey('reaction_${kind.code}');

  @override
  ConsumerState<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends ConsumerState<ReactionBar> {
  final _throttle = ReactionThrottle();

  void _slowDown() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.reactionSlowDown)));
  }

  Future<void> _send(ReactionKind kind) async {
    if (!widget.open) return;
    if (!_throttle.tryTake(ref.read(reactionClockProvider)())) {
      _slowDown();
      return;
    }
    Haptics.select();
    try {
      await widget.backend.call('economy', {
        'action': 'react',
        'roomId': widget.roomId,
        'kind': kind.code,
      });
    } on BackendException catch (error) {
      if (error.code == 'REACTION_RATE_LIMIT' && mounted) _slowDown();
    } catch (_) {
      // A reaction is never load-bearing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    final on = caps?.fun.reactions ?? false;
    if (!widget.open || !on) return const SizedBox.shrink();
    final l = context.l10n;
    return Semantics(
      container: true,
      label: l.reactionsLabel,
      child: SingleChildScrollView(
        key: ReactionBar.barKey,
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in ReactionKind.values)
              IconButton(
                key: ReactionBar.seal(kind),
                tooltip: reactionLabel(l, kind),
                onPressed: () => unawaited(_send(kind)),
                icon: ReactionSeal(kind: kind),
              ),
          ],
        ),
      ),
    );
  }
}

/// Floats each arriving reaction up from the sender's seat.
///
/// [anchor] places a seat inside this widget's box; without one (or for a seat
/// it cannot place) the seal rises from the bottom centre with the sender's
/// name beside it. Under reduced motion the seal appears in place and fades.
class ReactionFloats extends StatefulWidget {
  final Stream<RoomReactionRow>? feed;
  final Offset? Function(int seat, Size size)? anchor;
  final String Function(int seat)? nameOf;
  final Widget child;

  const ReactionFloats({
    super.key,
    required this.feed,
    required this.child,
    this.anchor,
    this.nameOf,
  });

  static const Key floatKey = ValueKey('reaction_float');

  /// The most seals in the air at once; a flood drops the oldest.
  static const int maxFloats = 12;

  @override
  State<ReactionFloats> createState() => _ReactionFloatsState();
}

class _Float {
  final int id;
  final int seat;
  final ReactionKind kind;
  const _Float(this.id, this.seat, this.kind);
}

class _ReactionFloatsState extends State<ReactionFloats> {
  StreamSubscription<RoomReactionRow>? _sub;
  final List<_Float> _floats = [];
  final Map<int, Timer> _timers = {};

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ReactionFloats old) {
    super.didUpdateWidget(old);
    if (old.feed != widget.feed) {
      unawaited(_sub?.cancel());
      _listen();
    }
  }

  void _listen() {
    _sub = widget.feed?.listen((row) {
      final kind = ReactionKind.fromCode(row.kind);
      if (kind == null || !mounted) return;
      if (_floats.any((f) => f.id == row.id)) return;
      setState(() {
        _floats.add(_Float(row.id, row.seat, kind));
        while (_floats.length > ReactionFloats.maxFloats) {
          _timers.remove(_floats.removeAt(0).id)?.cancel();
        }
      });
      _timers[row.id] = Timer(FunTokens.reactionFloatDuration, () {
        _timers.remove(row.id);
        if (mounted) setState(() => _floats.removeWhere((f) => f.id == row.id));
      });
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    // One tree shape whether or not anything is in the air: returning the
    // bare child when empty re-parented it on the first reaction, which
    // rebuilt the award ribbon and reset the result's scroll.
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: _floats.isEmpty
              ? const SizedBox.shrink()
              // Its own Material: the floats are an overlay and must not rely
              // on whatever sits above this scope for a DefaultTextStyle.
              : IgnorePointer(
                  child: Material(
                    type: MaterialType.transparency,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        const half = FunTokens.reactionFloat / 2;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final f in _floats)
                              _floatAt(context, f, size, half, reduce),
                          ],
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _floatAt(
    BuildContext context,
    _Float f,
    Size size,
    double half,
    bool reduce,
  ) {
    final at = widget.anchor?.call(f.seat, size);
    final origin =
        at ?? Offset(size.width / 2, size.height - FunTokens.reactionFloat);
    final name = at == null ? widget.nameOf?.call(f.seat) : null;
    final seal = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReactionSeal(kind: f.kind, size: FunTokens.reactionFloat),
        if (name != null && name.isNotEmpty) ...[
          SizedBox(width: context.spacing.xs),
          Text(
            name,
            style: context.typography.caption.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ],
    );
    return Positioned(
      key: ValueKey('reaction_float_${f.id}'),
      left: origin.dx - half,
      top: origin.dy - half,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: KeyedSubtree(
            key: ReactionFloats.floatKey,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: FunTokens.reactionFloatDuration,
              builder: (context, t, child) {
                final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
                return Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, reduce ? 0 : -FunTokens.reactionRise * t),
                    child: Transform.scale(
                      scale: reduce ? 1 : 0.8 + 0.2 * (t * 4).clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: seal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Subscribes to a room's reactions while [open] and the server has them on,
/// and floats them over [child]. Holds one feed per room, so a rebuild never
/// opens a second channel.
class ReactionScope extends ConsumerStatefulWidget {
  final String? roomId;
  final OnlineBackend? backend;
  final bool open;
  final Offset? Function(int seat, Size size)? anchor;
  final String Function(int seat)? nameOf;
  final Widget child;

  const ReactionScope({
    super.key,
    required this.roomId,
    required this.backend,
    required this.open,
    required this.child,
    this.anchor,
    this.nameOf,
  });

  @override
  ConsumerState<ReactionScope> createState() => _ReactionScopeState();
}

class _ReactionScopeState extends ConsumerState<ReactionScope> {
  String? _for;
  Stream<RoomReactionRow>? _feed;

  bool _reactionsOn() {
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    return caps?.fun.reactions ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.roomId;
    final backend = widget.backend;
    // The server switch is asked only where a feed could exist at all, so a
    // closed scope costs nothing — not even a capabilities read.
    final live =
        widget.open && room != null && backend != null && _reactionsOn();
    if (!live) {
      _for = null;
      _feed = null;
    } else if (_for != room) {
      _for = room;
      _feed = backend.reactions(room);
    }
    return ReactionFloats(
      feed: _feed,
      anchor: widget.anchor,
      nameOf: widget.nameOf,
      child: widget.child,
    );
  }
}
