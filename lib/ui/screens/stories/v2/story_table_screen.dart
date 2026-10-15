import 'package:flutter/material.dart';

import '../../../../platform/narration_controller.dart';
import '../../../../stories/v2/session.dart';
import '../../../../stories/v2/table.dart';
import '../../../../stories/v2/world.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import 'lamp_kit.dart';
import 'story_lobby_screen.dart' show StoryCastStrip;

/// One Stories V2 table from the deal to the result (plan §2.6–2.8, S5–S12).
class StoryTableScreen extends StatefulWidget {
  const StoryTableScreen({
    super.key,
    required this.table,
    required this.seed,
    required this.narration,
    required this.onExit,
    required this.onPlayAgain,
    this.onFinished,
    this.watchAdForSearch,
  });

  static const beginKey = ValueKey('sv2_begin');
  static const openKey = ValueKey('sv2_open_card');
  static const holdKey = ValueKey('sv2_hold');
  static const hideKey = ValueKey('sv2_hide');
  static const secretKey = ValueKey('sv2_secret');
  static const nextIntroKey = ValueKey('sv2_next_intro');
  static const decideKey = ValueKey('sv2_decide');
  static const confirmKey = ValueKey('sv2_confirm');
  static const resultKey = ValueKey('sv2_see_result');
  static const bonusKey = ValueKey('sv2_bonus_search');
  static const againKey = ValueKey('sv2_play_again');
  static const foundBackKey = ValueKey('sv2_found_back');
  static Key placeKey(String id) => ValueKey('sv2_place_$id');
  static Key pickKey(String id) => ValueKey('sv2_pick_$id');
  static Key motiveKey(String id) => ValueKey('sv2_motive_$id');
  static Key methodKey(String id) => ValueKey('sv2_method_$id');

  final StoryTable table;
  final int seed;
  final NarrationController narration;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;

  /// Called once, when the result opens.
  final void Function(StorySessionV2 session)? onFinished;

  /// A rewarded ad for solo's one extra search; true when it was watched.
  final Future<bool> Function()? watchAdForSearch;

  @override
  State<StoryTableScreen> createState() => _StoryTableScreenState();
}

class _StoryTableScreenState extends State<StoryTableScreen>
    with WidgetsBindingObserver {
  late StorySessionV2 _session = StorySessionV2.start(widget.table);
  String? _pick;
  String? _motive;
  String? _method;
  bool _watching = false;

  StoryTable get _t => widget.table;
  StoryWorld get _w => widget.table.world;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    widget.narration.stop();
    final covered = _session.coverForInterruption();
    if (!identical(covered, _session)) setState(() => _session = covered);
  }

  void _go(StorySessionV2 next) {
    final private = {StoryStage.handoff, StoryStage.card, StoryStage.secret};
    if (private.contains(next.stage)) widget.narration.stop();
    setState(() => _session = next);
    if (next.stage == StoryStage.result) widget.onFinished?.call(next);
  }

  Future<void> _confirmExit() async {
    final l = context.l10n;
    final leave = await showLampSheet<bool>(context, (context) {
      final s = context.spacing;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(s.screenMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LampTitle(l.sv2ExitTitle, small: true),
              LampMeta(l.sv2ExitBody),
              SizedBox(height: s.md),
              LampButton(
                label: l.sv2ExitNo,
                onPressed: () => Navigator.pop(context, false),
              ),
              SizedBox(height: s.sm),
              LampButton(
                label: l.sv2ExitYes,
                kind: LampButtonKind.ghost,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      );
    });
    if (leave == true) {
      await widget.narration.stop();
      widget.onExit();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (_session.stage == StoryStage.result) {
        widget.onExit();
      } else if (_session.stage == StoryStage.decision) {
        _go(_session.backToDesk());
      } else {
        _confirmExit();
      }
    },
    // Each page keeps its own scroll: one ListView's offset never carries
    // into the next page (the decision opened scrolled past its faces), and
    // each seat's card starts at the top. The desk keeps its place.
    child: KeyedSubtree(
      key: PageStorageKey<String>(switch (_session.stage) {
        StoryStage.handoff ||
        StoryStage.card ||
        StoryStage.secret ||
        StoryStage.introductions => '${_session.stage.name}${_session.turn}',
        _ => _session.stage.name,
      }),
      child: _page(context),
    ),
  );

  Widget _page(BuildContext context) => switch (_session.stage) {
    StoryStage.cast => _cast(context),
    StoryStage.handoff => _handoff(context),
    StoryStage.card => _card(context),
    StoryStage.secret => _secret(context),
    StoryStage.introductions => _introduction(context),
    StoryStage.desk => _desk(context),
    StoryStage.decision => _decision(context),
    StoryStage.reveal => _reveal(context),
    StoryStage.result => _result(context),
  };

  // ---- public: who plays whom -------------------------------------------

  Widget _cast(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final detective = _t.mode == StoryTableMode.detective;
    return LampScaffold(
      onBack: _confirmExit,
      title: _w.title,
      footer: LampButton(
        key: StoryTableScreen.beginKey,
        label: detective ? l.sv2CastDetGo : l.sv2CastAllGo,
        onPressed: () => _go(_session.begin()),
      ),
      body: LampScroll(
        children: [
          LampTitle(l.sv2CastTitle, small: true),
          for (final seat in _t.seats)
            Container(
              padding: EdgeInsets.all(s.xs),
              decoration: BoxDecoration(
                color: seat.isDetective ? StoriesLampTokens.raised : null,
                borderRadius: BorderRadius.circular(
                  StoriesLampTokens.radiusPaper,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: StoriesLampTokens.pickFaceWidth,
                    child: Text(
                      seat.player,
                      style: type.body.copyWith(
                        color: StoriesLampTokens.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  LampFace(_image(seat)),
                  SizedBox(width: s.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name(seat),
                          style: type.body.copyWith(
                            color: StoriesLampTokens.text,
                          ),
                        ),
                        LampMeta(
                          seat.isDetective
                              ? l.sv2Detective
                              : _w.suspect(seat.suspectId!).tag,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          LampMeta(detective ? l.sv2CastDetNote : l.sv2CastAllNote),
        ],
      ),
    );
  }

  // ---- 5–10: the one pass ------------------------------------------------

  Widget _handoff(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final seat = _session.currentSeat;
    return LampScaffold(
      footer: LampButton(
        key: StoryTableScreen.openKey,
        label: l.sv2IAm(seat.player),
        onPressed: () => _go(_session.openCard()),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(s.screenMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LampMeta(
                l.sv2PassCount(_session.turn + 1, _t.seats.length),
                center: true,
              ),
              SizedBox(height: s.md),
              LampMeta(l.sv2PassTo, center: true),
              Text(
                seat.player,
                textAlign: TextAlign.center,
                style: StoryTokens.ruqaa(context.typography.display).copyWith(
                  color: StoriesLampTokens.paper,
                  fontSize: StoriesLampTokens.handoffName,
                ),
              ),
              LampMeta(
                l.sv2LookAway,
                center: true,
                color: StoriesLampTokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The card on screen while its player reads it aloud. One layout for the
  /// detective's seat and every suspect's.
  Widget _card(BuildContext context, {bool dimmed = false, Widget? bottom}) {
    final l = context.l10n;
    final s = context.spacing;
    final seat = _session.currentSeat;
    final female = _female(seat);
    return LampScaffold(
      footer:
          bottom ??
          LampHoldPad(
            key: StoryTableScreen.holdKey,
            label: female ? l.sv2HoldSecretF : l.sv2HoldSecretM,
            hint: female ? l.sv2HoldWhenF : l.sv2HoldWhenM,
            onHeld: () => _go(_session.revealSecret()),
          ),
      body: LampScroll(
        children: [
          Row(
            children: [
              LampFace(
                _image(seat),
                width: StoriesLampTokens.cardFaceWidth,
                height: StoriesLampTokens.cardFaceHeight,
              ),
              SizedBox(width: s.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LampTitle(_name(seat), small: true),
                    LampMeta(_tag(seat)),
                  ],
                ),
              ),
            ],
          ),
          LampPaper(
            dimmed: dimmed,
            label: female ? l.sv2ReadAloudF : l.sv2ReadAloudM,
            child: Text(_cardText(seat)),
          ),
          LampPaper(
            dimmed: dimmed,
            label: l.sv2GoalLabel,
            child: Text(_goal(seat)),
          ),
        ],
      ),
    );
  }

  /// The private line: same shape, colour and timing for every role.
  Widget _secret(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final seat = _session.currentSeat;
    final (title, sub, note) = _secretLines(context, seat);
    final last = _session.turn + 1 == _t.seats.length;
    return _card(
      context,
      dimmed: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Transform.rotate(
            angle: StoriesLampTokens.secretTilt,
            child: Container(
              key: StoryTableScreen.secretKey,
              height: StoriesLampTokens.holdPad,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StoriesLampTokens.secret,
                borderRadius: BorderRadius.circular(
                  StoriesLampTokens.radiusPaper,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: type.title.copyWith(
                      color: StoriesLampTokens.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    sub,
                    style: type.caption.copyWith(
                      color: StoriesLampTokens.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: s.sm),
          SizedBox(
            height: StoriesLampTokens.secretNoteHeight,
            child: Text(
              note,
              textAlign: TextAlign.center,
              maxLines: StoriesLampTokens.secretNoteLines,
              style: type.bodySmall.copyWith(color: StoriesLampTokens.text2),
            ),
          ),
          SizedBox(height: s.sm),
          LampButton(
            key: StoryTableScreen.hideKey,
            label: last ? l.sv2HideToDetective : l.sv2HidePass,
            kind: LampButtonKind.ghost,
            onPressed: () => _go(_session.hideSecret()),
          ),
        ],
      ),
    );
  }

  (String, String, String) _secretLines(
    BuildContext context,
    StoryTableSeat seat,
  ) {
    final l = context.l10n;
    final f = _female(seat);
    switch (_t.roleOf(seat)) {
      case StorySeatRole.detective:
        return (
          l.sv2SecretDetective,
          l.sv2SecretDetectiveSub,
          l.sv2SecretDetectiveNote,
        );
      case StorySeatRole.killer:
        final partner = _t.partnerId;
        final sub = partner == null
            ? (f ? l.sv2KillerSubF : l.sv2KillerSubM)
            : (_w.suspect(partner).gender == WorldGender.female
                  ? l.sv2PartnerIsF(_w.suspect(partner).name)
                  : l.sv2PartnerIsM(_w.suspect(partner).name));
        return (
          f ? l.sv2KillerF : l.sv2KillerM,
          sub,
          f ? l.sv2KillerNoteF : l.sv2KillerNoteM,
        );
      case StorySeatRole.partner:
        final killer = _w.suspect(_t.culpritId);
        return (
          f ? l.sv2PartnerF : l.sv2PartnerM,
          killer.gender == WorldGender.female
              ? l.sv2KillerIsF(killer.name)
              : l.sv2KillerIsM(killer.name),
          f ? l.sv2PartnerNoteF : l.sv2PartnerNoteM,
        );
      case StorySeatRole.innocent:
      case StorySeatRole.unknown:
        return (
          f ? l.sv2InnocentF : l.sv2InnocentM,
          f ? l.sv2InnocentSubF : l.sv2InnocentSubM,
          f ? l.sv2InnocentNoteF : l.sv2InnocentNoteM,
        );
    }
  }

  // ---- 2–4: public introductions ----------------------------------------

  Widget _introduction(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final suspect = _w.suspect(_session.introducedSuspect);
    final reader = _t.seatOf(suspect.id)?.player ?? '';
    final last = _session.turn + 1 == _t.suspectIds.length;
    final f = suspect.gender == WorldGender.female;
    return LampScaffold(
      onBack: _confirmExit,
      title: l.sv2IntroCount(_session.turn + 1, _t.suspectIds.length),
      footer: LampButton(
        key: StoryTableScreen.nextIntroKey,
        label: last ? l.sv2ToTable : l.sv2Next,
        onPressed: () => _go(_session.nextIntroduction()),
      ),
      body: LampScroll(
        children: [
          LampMeta(l.sv2IntroReader(reader), center: true),
          Center(
            child: LampFace(
              suspect.image,
              width: StoriesLampTokens.revealFaceWidth,
              height: StoriesLampTokens.revealFaceHeight,
            ),
          ),
          LampTitle(suspect.name, small: true, center: true),
          LampMeta(suspect.tag, center: true),
          LampPaper(
            label: f ? l.sv2ReadAloudF : l.sv2ReadAloudM,
            child: Text(suspect.card),
          ),
          LampPaper(label: l.sv2GoalLabel, child: Text(suspect.goal)),
          SizedBox(height: s.xs),
          LampMeta(
            l.sv2CastAllNote,
            center: true,
            color: StoriesLampTokens.muted,
          ),
        ],
      ),
    );
  }

  // ---- the desk -----------------------------------------------------------

  Widget _desk(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final mode = _t.mode;
    final title = switch (mode) {
      StoryTableMode.detective => l.sv2DeskDetective(_t.detectiveSeat!.player),
      StoryTableMode.allSuspects => l.sv2DeskTable,
      StoryTableMode.solo => l.sv2DeskSolo(_w.detective.name),
    };
    final factsLabel = switch (mode) {
      StoryTableMode.detective => l.sv2ReadToAll,
      StoryTableMode.allSuspects => l.sv2ReadTogether,
      StoryTableMode.solo => l.sv2WhatYouKnow,
    };
    return LampScaffold(
      onBack: _confirmExit,
      title: title,
      trailing: _w.openingAudio == null
          ? null
          : TextButton.icon(
              onPressed: () => _replay(context),
              icon: const Icon(
                Icons.replay_rounded,
                color: StoriesLampTokens.amberHi,
              ),
              label: Text(
                l.sv2Replay,
                style: type.caption.copyWith(color: StoriesLampTokens.amberHi),
              ),
            ),
      footer: LampButton(
        key: StoryTableScreen.decideKey,
        label: mode == StoryTableMode.allSuspects ? l.sv2Agree : l.sv2Decide,
        kind: LampButtonKind.verdict,
        onPressed: () => _go(_session.openDecision()),
      ),
      body: LampScroll(
        children: [
          LampPaper(
            label: factsLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final fact in _t.caseFacts) Text('• $fact')],
            ),
          ),
          StoryCastStrip(world: _w, only: _t.suspectIds, withDetective: false),
          LampMeta(
            l.sv2TapToRead,
            center: true,
            color: StoriesLampTokens.muted,
          ),
          LampMeta(
            l.sv2SearchesLeft(_session.searchesLeft, _session.searchBudget),
          ),
          for (final place in _w.places)
            InkWell(
              key: StoryTableScreen.placeKey(place.id),
              onTap: _session.searched.contains(place.id)
                  ? () => _showFound(context, place.id)
                  : _session.canSearch(place.id)
                  ? () {
                      _go(_session.search(place.id));
                      _showFound(context, place.id);
                    }
                  : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: s.sm),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: StoriesLampTokens.line),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: type.body.copyWith(
                              color: StoriesLampTokens.text,
                            ),
                          ),
                          LampMeta(place.line, color: StoriesLampTokens.muted),
                        ],
                      ),
                    ),
                    Text(
                      _session.searched.contains(place.id)
                          ? l.sv2Searched
                          : l.sv2Search,
                      style: type.body.copyWith(
                        color: _session.searched.contains(place.id)
                            ? StoriesLampTokens.muted
                            : _session.canSearch(place.id)
                            ? StoriesLampTokens.amberHi
                            : StoriesLampTokens.line,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_session.canBuySearch && widget.watchAdForSearch != null)
            LampButton(
              key: StoryTableScreen.bonusKey,
              label: l.sv2BonusSearch,
              kind: LampButtonKind.ghost,
              onPressed: _watching ? null : _buySearch,
            ),
        ],
      ),
    );
  }

  Future<void> _buySearch() async {
    setState(() => _watching = true);
    final watched = await widget.watchAdForSearch!();
    if (!mounted) return;
    setState(() => _watching = false);
    if (watched && _session.canBuySearch) _go(_session.grantBonusSearch());
  }

  void _replay(BuildContext context) {
    final audio = _w.openingAudio;
    if (audio == null) return;
    showLampSheet<void>(context, (context) {
      final s = context.spacing;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(s.screenMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StoryNarratorPlayer(
                controller: widget.narration,
                asset: audio,
                title: context.l10n.sv2NarratorName,
              ),
              SizedBox(height: s.sm),
              LampPaper(child: Text(_w.opening)),
            ],
          ),
        ),
      );
    }).whenComplete(widget.narration.stop);
  }

  void _showFound(BuildContext context, String placeId) {
    final l = context.l10n;
    final place = _w.place(placeId);
    showLampSheet<void>(context, (context) {
      final s = context.spacing;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(s.screenMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LampTitle(place.name, small: true),
              LampMeta(l.sv2FoundTitle),
              SizedBox(height: s.sm),
              for (final trace in _t.tracesAt(placeId)) ...[
                LampPaper(child: Text(trace)),
                SizedBox(height: s.sm),
              ],
              LampButton(
                key: StoryTableScreen.foundBackKey,
                label: l.sv2Back,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ---- the decision -------------------------------------------------------

  Widget _decision(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final solo = _t.mode == StoryTableMode.solo;
    final title = switch (_t.mode) {
      StoryTableMode.detective => l.sv2DecisionDetective,
      StoryTableMode.allSuspects => l.sv2DecisionTable,
      StoryTableMode.solo => l.sv2DecisionSolo,
    };
    final ready =
        _pick != null && (!solo || (_motive != null && _method != null));
    return LampScaffold(
      onBack: () => _go(_session.backToDesk()),
      footer: LampButton(
        key: StoryTableScreen.confirmKey,
        label: _pick == null
            ? l.sv2PickSomeone
            : l.sv2Confirm(_w.suspect(_pick!).name),
        kind: LampButtonKind.verdict,
        onPressed: ready
            ? () => _go(
                _session.accuse(
                  StoryAccusationV2(
                    suspectId: _pick!,
                    motiveId: solo ? _motive : null,
                    methodId: solo ? _method : null,
                  ),
                ),
              )
            : null,
      ),
      body: LampScroll(
        children: [
          LampTitle(title, small: true),
          LampMeta(solo ? l.sv2Who : l.sv2DecisionFree),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: s.md,
            runSpacing: s.md,
            children: [
              for (final id in _t.suspectIds)
                GestureDetector(
                  key: StoryTableScreen.pickKey(id),
                  onTap: () => setState(() => _pick = id),
                  child: Column(
                    children: [
                      LampFace(
                        _w.suspect(id).image,
                        width: StoriesLampTokens.pickFaceWidth,
                        height: StoriesLampTokens.pickFaceHeight,
                        picked: _pick == id,
                      ),
                      LampMeta(
                        _w.suspect(id).name,
                        color: _pick == id ? StoriesLampTokens.amberHi : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (solo) ...[
            LampMeta(l.sv2Why),
            for (final m in _t.motives(widget.seed))
              _option(
                context,
                StoryTableScreen.motiveKey(m.id),
                m.label,
                _motive == m.id,
                () => setState(() => _motive = m.id),
              ),
            LampMeta(l.sv2How),
            for (final m in _t.methods(widget.seed))
              _option(
                context,
                StoryTableScreen.methodKey(m.id),
                m.label,
                _method == m.id,
                () => setState(() => _method = m.id),
              ),
          ],
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context,
    Key key,
    String label,
    bool on,
    VoidCallback onTap,
  ) {
    final s = context.spacing;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
        decoration: BoxDecoration(
          color: on ? StoriesLampTokens.raised : null,
          borderRadius: BorderRadius.circular(StoriesLampTokens.radiusPaper),
          border: Border.all(
            color: on ? StoriesLampTokens.amber : StoriesLampTokens.line,
          ),
        ),
        child: Text(
          label,
          style: context.typography.bodySmall.copyWith(
            color: on ? StoriesLampTokens.text : StoriesLampTokens.text2,
          ),
        ),
      ),
    );
  }

  // ---- the reveal and the result -----------------------------------------

  Widget _reveal(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final culprit = _w.suspect(_t.culpritId);
    final player = _t.seatOf(culprit.id)?.player;
    final partner = _t.partnerId == null ? null : _w.suspect(_t.partnerId!);
    return LampScaffold(
      footer: LampButton(
        key: StoryTableScreen.resultKey,
        label: l.sv2SeeResult,
        onPressed: () => _go(_session.showResult()),
      ),
      body: LampScroll(
        children: [
          Container(
            padding: EdgeInsets.all(s.md),
            decoration: BoxDecoration(
              color: StoriesLampTokens.velvet,
              borderRadius: BorderRadius.circular(
                StoriesLampTokens.radiusPaper,
              ),
            ),
            child: Column(
              children: [
                Text(
                  l.sv2RevealWho(culprit.name),
                  style: type.title.copyWith(
                    color: StoriesLampTokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (player != null && player.isNotEmpty)
                  LampMeta(l.sv2RevealPlayedBy(player), center: true),
                if (partner != null)
                  LampMeta(l.sv2RevealWith(partner.name), center: true),
              ],
            ),
          ),
          Center(
            child: LampFace(
              culprit.image,
              width: StoriesLampTokens.revealFaceWidth,
              height: StoriesLampTokens.revealFaceHeight,
            ),
          ),
          for (final part in _t.reveal) LampPaper(child: Text(part)),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final solved = _session.solved;
    final picked = _w.suspect(_session.accusation!.suspectId).name;
    final culprit = _w.suspect(_t.culpritId);
    final title = switch (_t.mode) {
      StoryTableMode.detective =>
        solved ? l.sv2DetectiveWon : l.sv2KillerEscaped,
      StoryTableMode.allSuspects => solved ? l.sv2TableWon : l.sv2TableLost,
      StoryTableMode.solo =>
        solved
            ? l.sv2SoloWon
            : _session.whoRight
            ? l.sv2SoloClose
            : l.sv2SoloLost,
    };
    return LampScaffold(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LampButton(
            key: StoryTableScreen.againKey,
            label: l.sv2PlayAgain,
            onPressed: widget.onPlayAgain,
          ),
          SizedBox(height: s.sm),
          LampButton(
            label: l.sv2OtherCase,
            kind: LampButtonKind.ghost,
            onPressed: widget.onExit,
          ),
        ],
      ),
      body: LampScroll(
        children: [
          LampTitle(title, small: true),
          LampMeta(
            _session.whoRight
                ? l.sv2PickRight(picked)
                : l.sv2PickWrong(picked, culprit.name),
          ),
          if (_t.mode == StoryTableMode.solo) ...[
            _mark(
              context,
              _session.motiveRight == true,
              l.sv2ResultMotive(culprit.guilty.motive.label),
            ),
            _mark(
              context,
              _session.methodRight == true,
              l.sv2ResultMethod(culprit.guilty.method.label),
            ),
          ] else
            for (final seat in _t.seats)
              Container(
                padding: EdgeInsets.symmetric(vertical: s.xs),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: StoriesLampTokens.line),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${seat.player} · ${_name(seat)}',
                        style: type.body.copyWith(
                          color: StoriesLampTokens.text,
                        ),
                      ),
                    ),
                    _roleChip(context, seat),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _mark(BuildContext context, bool right, String text) => Row(
    children: [
      Icon(
        right ? Icons.check_rounded : Icons.close_rounded,
        color: right ? StoriesLampTokens.amberHi : StoriesLampTokens.muted,
      ),
      SizedBox(width: context.spacing.sm),
      Expanded(child: LampMeta(text)),
    ],
  );

  Widget _roleChip(BuildContext context, StoryTableSeat seat) {
    final l = context.l10n;
    final f = _female(seat);
    final guilty = !seat.isDetective && _t.isGuilty(seat.suspectId!);
    final label = seat.isDetective
        ? l.sv2RoleDetective
        : _t.mode == StoryTableMode.allSuspects
        ? (guilty
              ? (f ? l.sv2RoleCulpritF : l.sv2RoleCulpritM)
              : (f ? l.sv2RoleInnocentF : l.sv2RoleInnocentM))
        : seat.suspectId == _t.culpritId
        ? (f ? l.sv2RoleKillerF : l.sv2RoleKillerM)
        : seat.suspectId == _t.partnerId
        ? (f ? l.sv2RolePartnerF : l.sv2RolePartnerM)
        : (f ? l.sv2RoleInnocentF : l.sv2RoleInnocentM);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      decoration: BoxDecoration(
        color: guilty ? StoriesLampTokens.velvet : StoriesLampTokens.raised,
        borderRadius: BorderRadius.circular(StoriesLampTokens.radiusButton),
      ),
      child: Text(
        label,
        style: context.typography.caption.copyWith(
          color: StoriesLampTokens.text,
        ),
      ),
    );
  }

  // ---- helpers --------------------------------------------------------------

  String _image(StoryTableSeat seat) =>
      seat.isDetective ? _w.detective.image : _w.suspect(seat.suspectId!).image;
  String _name(StoryTableSeat seat) =>
      seat.isDetective ? _w.detective.name : _w.suspect(seat.suspectId!).name;
  String _tag(StoryTableSeat seat) =>
      seat.isDetective ? _w.detective.tag : _w.suspect(seat.suspectId!).tag;
  String _cardText(StoryTableSeat seat) =>
      seat.isDetective ? _w.detective.card : _w.suspect(seat.suspectId!).card;
  String _goal(StoryTableSeat seat) =>
      seat.isDetective ? _w.detective.goal : _w.suspect(seat.suspectId!).goal;
  bool _female(StoryTableSeat seat) =>
      (seat.isDetective
          ? _w.detective.gender
          : _w.suspect(seat.suspectId!).gender) ==
      WorldGender.female;
}
