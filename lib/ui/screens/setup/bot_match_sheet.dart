import '../../widgets/mafia_kit.dart';
import 'package:flutter/material.dart';

import '../../../engine/bots/bot_brain.dart';
import '../../../engine/presets.dart';
export '../../../data/bot_names.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';

/// What the player picked for a table against bots.
typedef BotMatchPick = ({int players, MatchPreset preset, BotLevel level});

const _minPlayers = 5;
const _maxPlayers = 12;

/// «العب ضد البوتات»: table size and preset, in a sheet.
Future<BotMatchPick?> showBotMatchSheet(BuildContext context) =>
    showMafiaSheet<BotMatchPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _BotMatchSheet(),
    );

class _BotMatchSheet extends StatefulWidget {
  const _BotMatchSheet();

  @override
  State<_BotMatchSheet> createState() => _BotMatchSheetState();
}

class _BotMatchSheetState extends State<_BotMatchSheet> {
  int _players = 8;
  MatchPreset _preset = MatchPreset.classic;
  BotLevel _level = BotLevel.normal;

  static const startKey = ValueKey('bot_match_start');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          s.screenMargin,
          0,
          s.screenMargin,
          s.screenMargin,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.modeBotsTitle, style: type.headline),
            SizedBox(height: s.xs),
            Text(l.modeBotsBody, style: type.bodySmall),
            SizedBox(height: s.md),
            VaultHeading(title: l.botSheetPlayers, compact: true),
            SizedBox(height: s.sm),
            Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (var n = _minPlayers; n <= _maxPlayers; n++)
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _players == n,
                    onSelected: (_) => setState(() => _players = n),
                  ),
              ],
            ),
            SizedBox(height: s.md),
            VaultHeading(title: l.presetLabel, compact: true),
            SizedBox(height: s.sm),
            Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (final p in MatchPreset.values)
                  ChoiceChip(
                    label: Text(EngineCopy.presetName(l, p)),
                    selected: _preset == p,
                    onSelected: (_) => setState(() => _preset = p),
                  ),
              ],
            ),
            SizedBox(height: s.xs),
            Text(EngineCopy.presetHint(l, _preset), style: type.caption),
            SizedBox(height: s.md),
            VaultHeading(title: l.botSheetLevel, compact: true),
            SizedBox(height: s.sm),
            Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (final v in BotLevel.values)
                  ChoiceChip(
                    label: Text(switch (v) {
                      BotLevel.easy => l.botLevelEasy,
                      BotLevel.normal => l.botLevelNormal,
                      BotLevel.hard => l.botLevelHard,
                    }),
                    selected: _level == v,
                    onSelected: (_) => setState(() => _level = v),
                  ),
              ],
            ),
            SizedBox(height: s.lg),
            FilledButton(
              key: startKey,
              onPressed: () => Navigator.of(
                context,
              ).pop((players: _players, preset: _preset, level: _level)),
              child: Text(l.botSheetStart),
            ),
          ],
        ),
      ),
    );
  }
}
