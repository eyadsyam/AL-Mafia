import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// «عملات المافيا»: the antique-gold coin with the game's mask.
///
/// [shine] passes one slow light over the face when it appears (the "earn"
/// moment), once, never looping; it is
/// off under reduced motion, where the coin is simply still.
class MafiaCoin extends StatefulWidget {
  final double size;
  final bool shine;
  const MafiaCoin({
    super.key,
    this.size = CosmeticTokens.coinInline,
    this.shine = false,
  });

  @override
  State<MafiaCoin> createState() => _MafiaCoinState();
}

class _MafiaCoinState extends State<MafiaCoin>
    with SingleTickerProviderStateMixin {
  AnimationController? _shine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.shine && !MediaQuery.disableAnimationsOf(context);
    if (animate && _shine == null) {
      _shine = AnimationController(
        vsync: this,
        duration: CosmeticTokens.coinShineCycle,
      )..forward();
    } else if (!animate && _shine != null) {
      _shine!.dispose();
      _shine = null;
    }
  }

  @override
  void dispose() {
    _shine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.size > CosmeticTokens.coinHeader
          ? AppEconomyArt.coinLarge
          : AppEconomyArt.coinSmall,
      width: widget.size,
      height: widget.size,
      filterQuality: FilterQuality.medium,
      // A missing file must not break a price line.
      errorBuilder: (context, _, _) =>
          Icon(Icons.toll, size: widget.size, color: CosmeticTokens.coinGold),
    );
    final shine = _shine;
    return Semantics(
      label: context.l10n.coinsName,
      image: true,
      child: ExcludeSemantics(
        child: shine == null
            ? image
            : AnimatedBuilder(
                animation: shine,
                child: image,
                builder: (context, child) => ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment(-1 + shine.value * 3, -1),
                    end: Alignment(shine.value * 3, 1),
                    colors: const [
                      Colors.transparent,
                      CosmeticTokens.coinShine,
                      Colors.transparent,
                    ],
                  ).createShader(rect),
                  child: child,
                ),
              ),
      ),
    );
  }
}

/// «١٢٠٠ 🪙» — an amount with the coin beside it.
class CoinAmount extends StatelessWidget {
  final int amount;
  final TextStyle? style;
  final double size;
  const CoinAmount(
    this.amount, {
    super.key,
    this.style,
    this.size = CosmeticTokens.coinInline,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      MafiaCoin(size: size),
      SizedBox(width: context.spacing.xs),
      Text('$amount', style: style),
    ],
  );
}
