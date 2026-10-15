import 'package:flutter/material.dart';

import '../../../../data/story_v2_memory.dart';
import '../../../../platform/narration_controller.dart';
import '../../../../stories/v2/table.dart';
import '../../../../stories/v2/world.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import 'lamp_kit.dart';

enum _LobbyPage { file, names, howTo }

/// Before the deal: the story file with its narrator, the table's size and
/// names, then the mode's how-to cards (required the first time per mode).
class StoryLobbyScreen extends StatefulWidget {
  const StoryLobbyScreen({
    super.key,
    required this.world,
    required this.coverImage,
    required this.narration,
    required this.memory,
    required this.onExit,
    required this.onPlay,
  });

  static const friendsKey = ValueKey('sv2_play_friends');
  static const soloKey = ValueKey('sv2_play_solo');
  static const continueKey = ValueKey('sv2_names_continue');
  static const nextKey = ValueKey('sv2_howto_next');
  static const skipKey = ValueKey('sv2_howto_skip');
  static Key countKey(int n) => ValueKey('sv2_count_$n');
  static Key nameKey(int i) => ValueKey('sv2_name_$i');

  final StoryWorld world;
  final String coverImage;
  final NarrationController narration;
  final StoryV2Memory memory;
  final VoidCallback onExit;

  /// The table is ready: [players] in hand-off order (one blank name solo).
  /// The last how-to button waits on it (the deal may ask the server).
  final Future<void> Function(List<String> players) onPlay;

  @override
  State<StoryLobbyScreen> createState() => _StoryLobbyScreenState();
}

class _StoryLobbyScreenState extends State<StoryLobbyScreen> {
  _LobbyPage _page = _LobbyPage.file;
  int _count = 5;
  final List<TextEditingController> _names = [
    for (var i = 0; i < 10; i++) TextEditingController(),
  ];
  String? _namesError;
  List<String> _players = const [];
  int _card = 0;
  bool _howToSeen = false;
  bool _dealing = false;

  @override
  void initState() {
    super.initState();
    widget.memory.lastNames().then((names) {
      if (!mounted) return;
      for (final (i, name) in names.take(10).indexed) {
        _names[i].text = name;
      }
      if (names.length >= 2) setState(() => _count = names.length);
    });
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  StoryTableMode get _mode => storyTableModeFor(_players.length);

  Future<void> _toHowTo(List<String> players) async {
    await widget.narration.stop();
    final seen = await widget.memory.howToSeen(
      storyTableModeFor(players.length).name,
    );
    if (!mounted) return;
    setState(() {
      _players = players;
      _howToSeen = seen;
      _card = 0;
      _page = _LobbyPage.howTo;
    });
  }

  Future<void> _finishHowTo() async {
    if (_dealing) return;
    setState(() => _dealing = true);
    try {
      await widget.memory.markHowToSeen(_mode.name);
      await widget.onPlay(_players);
    } finally {
      if (mounted) setState(() => _dealing = false);
    }
  }

  void _submitNames() {
    final l = context.l10n;
    final names = [for (var i = 0; i < _count; i++) _names[i].text.trim()];
    if (names.any((n) => n.isEmpty)) {
      setState(() => _namesError = l.sv2NamesEmpty);
      return;
    }
    if (names.toSet().length != names.length) {
      setState(() => _namesError = l.sv2NamesDuplicate);
      return;
    }
    widget.memory.saveNames(names);
    _toHowTo(names);
  }

  void _back() {
    switch (_page) {
      case _LobbyPage.file:
        widget.narration.stop();
        widget.onExit();
      case _LobbyPage.names:
        setState(() => _page = _LobbyPage.file);
      case _LobbyPage.howTo:
        setState(
          () =>
              _page = _players.length == 1 ? _LobbyPage.file : _LobbyPage.names,
        );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: KeyedSubtree(
      key: PageStorageKey<_LobbyPage>(_page),
      child: switch (_page) {
        _LobbyPage.file => _file(context),
        _LobbyPage.names => _namesPage(context),
        _LobbyPage.howTo => _howTo(context),
      },
    ),
  );

  Widget _file(BuildContext context) {
    final l = context.l10n;
    final w = widget.world;
    final s = context.spacing;
    return LampScaffold(
      onBack: _back,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LampButton(
            key: StoryLobbyScreen.friendsKey,
            label: l.sv2PlayFriends,
            onPressed: () {
              widget.narration.stop();
              setState(() => _page = _LobbyPage.names);
            },
          ),
          SizedBox(height: s.sm),
          LampButton(
            key: StoryLobbyScreen.soloKey,
            label: l.sv2PlaySolo,
            kind: LampButtonKind.ghost,
            onPressed: () => _toHowTo(const ['']),
          ),
        ],
      ),
      body: LampScroll(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(StoriesLampTokens.radiusPaper),
            child: Image.asset(
              widget.coverImage,
              height: StoriesLampTokens.heroHeight,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const SizedBox(height: StoriesLampTokens.heroHeight),
            ),
          ),
          LampMeta('${w.category} · ${l.sv2PlayerRange}'),
          LampTitle(w.title),
          LampMeta(l.sv2Victim(w.victimName, w.victimTag)),
          if (w.openingAudio case final audio?)
            StoryNarratorPlayer(
              controller: widget.narration,
              asset: audio,
              title: l.sv2NarratorName,
            ),
          LampPaper(child: Text(w.opening)),
          LampMeta(l.sv2Characters),
          StoryCastStrip(world: w),
        ],
      ),
    );
  }

  Widget _namesPage(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final mode = storyTableModeFor(_count);
    return LampScaffold(
      onBack: _back,
      title: widget.world.title,
      footer: LampButton(
        key: StoryLobbyScreen.continueKey,
        label: l.sv2Continue,
        onPressed: _submitNames,
      ),
      body: LampScroll(
        children: [
          LampTitle(l.sv2CountTitle, small: true),
          Wrap(
            spacing: s.sm,
            runSpacing: s.sm,
            children: [
              for (var n = 2; n <= 10; n++)
                ChoiceChip(
                  key: StoryLobbyScreen.countKey(n),
                  label: Text('$n'),
                  selected: _count == n,
                  showCheckmark: false,
                  selectedColor: StoriesLampTokens.amber,
                  backgroundColor: StoriesLampTokens.panel,
                  side: const BorderSide(color: StoriesLampTokens.line),
                  labelStyle: type.body.copyWith(
                    color: _count == n
                        ? StoriesLampTokens.onAmber
                        : StoriesLampTokens.text2,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => setState(() {
                    _count = n;
                    _namesError = null;
                  }),
                ),
            ],
          ),
          LampPaper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode == StoryTableMode.detective
                      ? l.sv2CountDet(_count)
                      : l.sv2CountAll(_count),
                  style: type.body.copyWith(
                    color: StoriesLampTokens.paperInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  mode == StoryTableMode.detective
                      ? l.sv2CountDetBody(_count - 1)
                      : l.sv2CountAllBody,
                ),
              ],
            ),
          ),
          LampMeta(l.sv2NamesTitle),
          for (var i = 0; i < _count; i++)
            TextField(
              key: StoryLobbyScreen.nameKey(i),
              controller: _names[i],
              textInputAction: i + 1 < _count
                  ? TextInputAction.next
                  : TextInputAction.done,
              maxLength: 20,
              style: type.body.copyWith(color: StoriesLampTokens.text),
              decoration: InputDecoration(
                counterText: '',
                hintText: l.sv2NameHint(i + 1),
                hintStyle: type.body.copyWith(color: StoriesLampTokens.muted),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: StoriesLampTokens.line),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: StoriesLampTokens.amber),
                ),
              ),
              onChanged: (_) {
                if (_namesError != null) setState(() => _namesError = null);
              },
            ),
          if (_namesError case final error?)
            LampMeta(error, color: StoriesLampTokens.amberHi),
        ],
      ),
    );
  }

  List<(String, String)> _cards(BuildContext context) {
    final l = context.l10n;
    return switch (_mode) {
      StoryTableMode.detective => [
        (l.sv2HowDet1Title, l.sv2HowDet1Body),
        (l.sv2HowDet2Title, l.sv2HowDet2Body),
        (l.sv2HowDet3Title, l.sv2HowDet3Body),
        (l.sv2HowDet4Title, l.sv2HowDet4Body),
        (l.sv2HowDet5Title, l.sv2HowDet5Body),
      ],
      StoryTableMode.allSuspects => [
        (l.sv2HowAll1Title, l.sv2HowAll1Body),
        (l.sv2HowAll2Title, l.sv2HowAll2Body),
        (l.sv2HowAll3Title, l.sv2HowAll3Body),
        (l.sv2HowAll4Title, l.sv2HowAll4Body),
      ],
      StoryTableMode.solo => [
        (l.sv2HowSolo1Title, l.sv2HowSolo1Body),
        (l.sv2HowSolo2Title, l.sv2HowSolo2Body),
        (l.sv2HowSolo3Title, l.sv2HowSolo3Body),
      ],
    };
  }

  Widget _howTo(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final cards = _cards(context);
    final (title, body) = cards[_card];
    final last = _card + 1 == cards.length;
    return LampScaffold(
      onBack: _back,
      title: l.sv2HowToPlay,
      trailing: _howToSeen
          ? TextButton(
              key: StoryLobbyScreen.skipKey,
              onPressed: _dealing ? null : _finishHowTo,
              child: Text(
                l.sv2GotIt,
                style: const TextStyle(color: StoriesLampTokens.amberHi),
              ),
            )
          : null,
      footer: LampButton(
        key: StoryLobbyScreen.nextKey,
        label: _dealing
            ? l.sv2Dealing
            : last
            ? l.sv2LetsPlay
            : l.sv2Next,
        onPressed: _dealing
            ? null
            : last
            ? _finishHowTo
            : () => setState(() => _card++),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.screenMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LampTitle(title, small: true, center: true),
            SizedBox(height: s.md),
            LampPaper(child: Text(body)),
            SizedBox(height: s.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++)
                  Container(
                    width: s.sm,
                    height: s.sm,
                    margin: EdgeInsets.symmetric(horizontal: s.xs),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _card
                          ? StoriesLampTokens.amber
                          : StoriesLampTokens.line,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The story's people as a strip of photos; tap one to read their card.
class StoryCastStrip extends StatelessWidget {
  const StoryCastStrip({
    super.key,
    required this.world,
    this.only,
    this.withDetective = true,
  });

  final StoryWorld world;

  /// The suspects to show; all of them when null.
  final List<String>? only;

  /// The detective comes first on the story file; never among the suspects
  /// on the desk.
  final bool withDetective;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final people = <(String, String, String, String, String)>[
      if (withDetective)
        (
          world.detective.image,
          world.detective.name,
          world.detective.tag,
          world.detective.card,
          world.detective.goal,
        ),
      for (final x in world.suspects)
        if (only == null || only!.contains(x.id))
          (x.image, x.name, x.tag, x.card, x.goal),
    ];
    return SizedBox(
      height: StoriesLampTokens.faceHeight + s.xl,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: people.length,
        separatorBuilder: (_, _) => SizedBox(width: s.sm),
        itemBuilder: (context, i) {
          final (image, name, tag, card, goal) = people[i];
          return GestureDetector(
            onTap: () => showStoryCard(
              context,
              image: image,
              name: name,
              tag: tag,
              card: card,
              goal: goal,
            ),
            child: SizedBox(
              width: StoriesLampTokens.faceWidth + s.md,
              child: Column(
                children: [
                  LampFace(image),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(
                      color: StoriesLampTokens.text2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A character's public card in a sheet: never on a private page.
Future<void> showStoryCard(
  BuildContext context, {
  required String image,
  required String name,
  required String tag,
  required String card,
  required String goal,
}) => showLampSheet<void>(context, (context) {
  final s = context.spacing;
  final l = context.l10n;
  return SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.all(s.screenMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LampFace(
                image,
                width: StoriesLampTokens.cardFaceWidth,
                height: StoriesLampTokens.cardFaceHeight,
              ),
              SizedBox(width: s.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [LampTitle(name, small: true), LampMeta(tag)],
                ),
              ),
            ],
          ),
          SizedBox(height: s.md),
          LampPaper(child: Text(card)),
          SizedBox(height: s.sm),
          LampPaper(label: l.sv2GoalLabel, child: Text(goal)),
        ],
      ),
    ),
  );
});
