import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import '../table/table_scene.dart' show BandDivider;
import 'council_geometry.dart';

/// The council's bands in a lobby-shaped page: a header, then the council,
/// the words and the hand, one under the other.
///
/// On a phone held on its side that is too narrow for the wide council (see
/// [CouncilGeometry.compactLandscape]) those four bands cannot all have
/// height, and the council came out ten pixels wide. There the header keeps
/// the full width, and under it the words and the hand take the left column
/// and the council the right one. The same bands, the same content, for
/// everybody.
class CompactBands extends StatelessWidget {
  final Widget header;
  final Expanded council;
  final Expanded voice;
  final Expanded hand;

  const CompactBands({
    super.key,
    required this.header,
    required this.council,
    required this.voice,
    required this.hand,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (CouncilGeometry.compactLandscape(box.maxWidth, box.maxHeight)) {
          return Column(
            children: [
              header,
              const BandDivider(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: CouncilTokens.compactTextFlex,
                      child: Column(children: [voice, hand]),
                    ),
                    SizedBox(width: context.spacing.md),
                    Expanded(
                      flex: CouncilTokens.compactCouncilFlex,
                      child: council.child,
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [header, const BandDivider(), council, voice, hand],
        );
      },
    );
  }
}
