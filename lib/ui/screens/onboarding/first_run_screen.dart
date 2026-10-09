import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../app/l10n/app_localizations.dart';
import '../../../app/locale_controller.dart';
import '../../../data/player_profile.dart';
import '../../../data/repository_provider.dart';
import '../../../data/terms_consent.dart';
import '../../../engine/models/player.dart';
import '../../../transport/account_auth.dart' show AccountProfile;
import '../../../transport/account_service.dart' show AccountFailure;
import '../../account/account_sheet.dart'
    show accountAuthProvider, accountProfileProvider, showAccountSheet;
import '../../account/onboarding_account_step.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../../widgets/deck/seat_card.dart';
import '../../widgets/legal_documents.dart';
import '../../widgets/mafia_kit.dart';
import '../../widgets/warm_palette.dart';

/// Holds every route that needs a finished setup: a saved profile and an
/// acceptance of the current terms.
///
/// Inline rather than a redirect, so a deep link (`/join/CODE`) keeps its
/// destination: once setup completes, the same route shows its real screen.
/// An install that already has a profile but predates the terms gets the
/// compact form (the box only), once. A later app build with unchanged terms
/// never asks again.
class SetupRequired extends ConsumerWidget {
  final Widget child;
  const SetupRequired({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final terms = ref.watch(termsAcceptanceProvider);
    if (profile.isLoading || terms.isLoading) return const _Waiting();
    if (profile.valueOrNull == null) {
      return const FirstRunScreen(key: FirstRunScreen.screenKey);
    }
    if (terms.valueOrNull?.current != true) {
      return const FirstRunScreen(
        key: FirstRunScreen.screenKey,
        termsOnly: true,
      );
    }
    return child;
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();
  @override
  Widget build(BuildContext context) =>
      const MafiaScaffold(body: Center(child: CircularProgressIndicator()));
}

/// The first launch, in three questions with progress dots: the deck fans
/// into the logo, «نكلّمك إزاي؟» (two big avatar cards and the one box for
/// 18+ and the terms), «اسمك إيه؟» (the name is written on the chosen card as
/// it is typed) and, only where the build has a server, «نحفظ لعبك؟».
///
/// Nothing asks for a birth date, phone or email, and the microphone is asked
/// for only when voice is first used. Sound, music and motion keep their
/// defaults and live in settings.
class FirstRunScreen extends ConsumerStatefulWidget {
  /// Existing installs that have a profile: only the box.
  final bool termsOnly;
  const FirstRunScreen({super.key, this.termsOnly = false});

  static const screenKey = ValueKey('first_run');
  static const nameKey = ValueKey('first_run_name');
  static const agreeKey = ValueKey('first_run_agree');
  static const boyKey = ValueKey('first_run_boy');
  static const girlKey = ValueKey('first_run_girl');
  static const languageKey = ValueKey('first_run_language');
  static const termsLinkKey = ValueKey('first_run_terms_link');
  static const privacyLinkKey = ValueKey('first_run_privacy_link');
  static const continueKey = ValueKey('first_run_continue');
  static const nextKey = ValueKey('first_run_next');
  static const googleKey = ValueKey('first_run_google');
  static const emailKey = ValueKey('first_run_email');
  static const guestKey = ValueKey('first_run_guest');
  static const backKey = ValueKey('first_run_back');
  static const failedKey = ValueKey('first_run_failed');
  static const dotsKey = ValueKey('first_run_dots');
  static const myCardKey = ValueKey('first_run_my_card');

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

enum _Step { intro, kind, name, save }

class _FirstRunScreenState extends ConsumerState<FirstRunScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _name;
  PlayerGender _gender = PlayerGender.unspecified;
  bool _agreed = false;
  bool _highlightAgree = false;
  bool _saving = false;
  bool _failed = false;
  bool _googleBusy = false;
  int _step = 0;
  late final List<_Step> _steps;

  late final AnimationController _intro = AnimationController(vsync: this);
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: FirstRunTokens.shake,
  );
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: FirstRunTokens.flip + FirstRunTokens.hold,
  );
  bool _introStarted = false;

  /// Set by the player's first move, so a slow read never drags them back.
  bool _touched = false;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _steps = [
      _Step.intro,
      _Step.kind,
      _Step.name,
      if (ref.read(accountsAvailableProvider)) _Step.save,
    ];
    final profile = ref.read(playerProfileProvider).valueOrNull;
    _name = TextEditingController(text: profile?.name ?? '');
    _gender = profile?.gender ?? PlayerGender.unspecified;
    _flip.addStatusListener((status) {
      if (status == AnimationStatus.completed && _step == 1 && mounted) {
        _move(2);
      }
    });
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _step == 0 &&
          !_touched &&
          !widget.termsOnly &&
          mounted) {
        setState(() => _step = 1);
      }
    });
    if (!widget.termsOnly) _restore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted || widget.termsOnly) return;
    _introStarted = true;
    _intro.duration = _still ? FirstRunTokens.introStill : FirstRunTokens.intro;
    if (_step == 0) _intro.forward();
  }

  /// Back where the player was before the app was closed under them (the
  /// Google browser trip): the step, the name and gender, and the box.
  Future<void> _restore() async {
    final saved = await FirstRunProgress.load();
    if (saved == null || _touched || !mounted) return;
    final index = _steps.indexWhere((c) => c.name == saved.chapter);
    if (index <= 0) return;
    _intro.stop();
    setState(() {
      _step = index;
      _agreed = saved.agreed;
      if (_name.text.trim().isEmpty) {
        _name.text = saved.name.characters
            .take(FirstRunTokens.nameMax)
            .toString();
      }
      if (_gender == PlayerGender.unspecified) _gender = saved.gender;
    });
    final profile = ref.read(accountProfileProvider).valueOrNull;
    if (_steps[_step] == _Step.save &&
        (profile?.signedIn ?? false) &&
        _readyToFinish) {
      _finish();
    }
  }

  void _saveProgress() {
    if (widget.termsOnly) return;
    FirstRunProgress(
      chapter: _steps[_step].name,
      name: _name.text,
      gender: _gender,
      agreed: _agreed,
    ).save();
  }

  @override
  void dispose() {
    _name.dispose();
    _intro.dispose();
    _shake.dispose();
    _flip.dispose();
    super.dispose();
  }

  bool get _nameOk => _name.text.trim().length >= FirstRunTokens.nameMin;

  bool get _readyToFinish =>
      widget.termsOnly ||
      (_nameOk && _gender != PlayerGender.unspecified && _agreed);

  void _move(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    _touched = true;
    _flip.value = 0;
    setState(() => _step = step);
    _saveProgress();
    // Already signed in (the browser trip came back first): nothing to ask.
    if (_steps[step] == _Step.save &&
        (ref.read(accountProfileProvider).valueOrNull?.signedIn ?? false)) {
      _finish();
    }
  }

  void _toggleAgree() {
    if (_saving) return;
    _touched = true;
    setState(() {
      _agreed = !_agreed;
      _highlightAgree = false;
    });
    _saveProgress();
  }

  void _pick(PlayerGender gender) {
    if (_flip.isAnimating) return;
    if (!_agreed) {
      setState(() => _highlightAgree = true);
      if (!_still) _shake.forward(from: 0);
      return;
    }
    _touched = true;
    setState(() => _gender = gender);
    if (_still) {
      _move(2);
    } else {
      _flip.forward(from: 0);
    }
  }

  Future<void> _finish() async {
    if (_saving || !_readyToFinish) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      if (!widget.termsOnly) {
        await ref
            .read(playerProfileProvider.notifier)
            .save(PlayerProfile(name: _name.text.trim(), gender: _gender));
        await WelcomeGreeting.arm();
        // The first launch no longer plays the film, so the first-run
        // markers the app-open policy reads are set here.
        try {
          await ref.read(profileStoreProvider).markIntroSeen();
          await ref.read(matchRepositoryProvider).markOnboardingSeen();
        } catch (_) {}
      }
      // Last, and required: the gate opens when this lands. The one box
      // answers both 18+ and the terms.
      await ref.read(termsAcceptanceProvider.notifier).accept(adult: true);
      await FirstRunProgress.clear();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _failed = false;
    });
    try {
      await ref.read(accountAuthProvider).google();
    } on AccountFailure {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_steps.contains(_Step.save) && !widget.termsOnly) {
      ref.listen<AsyncValue<AccountProfile>>(accountProfileProvider, (
        previous,
        next,
      ) {
        final now = next.valueOrNull;
        if (next.hasError || now == null || !now.signedIn) return;
        if (previous?.valueOrNull?.signedIn ?? false) return;
        if (_steps[_step] == _Step.save) _finish();
      });
    }
    final step = widget.termsOnly ? _Step.kind : _steps[_step];
    return PopScope(
      canPop: widget.termsOnly || _step <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _step > 1) _move(_step - 1);
      },
      child: WarmPalette(
        child: MafiaScaffold(
          backgroundColor: DeckTokens.ground,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.spacing.maxContentWidth,
                ),
                child: widget.termsOnly
                    ? _termsOnly(context, l)
                    : Stack(
                        children: [
                          AnimatedSwitcher(
                            duration: _still
                                ? Duration.zero
                                : FirstRunTokens.stepSlide,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                            child: KeyedSubtree(
                              key: ValueKey(step),
                              child: switch (step) {
                                _Step.intro => _introStep(context, l),
                                _Step.kind => _kindStep(context, l),
                                _Step.name => _nameStep(context, l),
                                _Step.save => _saveStep(context, l),
                              },
                            ),
                          ),
                          if (step != _Step.intro) _dots(context),
                          if (step == _Step.name || step == _Step.save)
                            PositionedDirectional(
                              start: context.spacing.sm,
                              top: context.spacing.xs,
                              child: IconButton(
                                key: FirstRunScreen.backKey,
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                onPressed: _saving
                                    ? null
                                    : () => _move(_step - 1),
                                icon: const BackButtonIcon(),
                              ),
                            ),
                          if (step == _Step.kind)
                            PositionedDirectional(
                              end: context.spacing.md,
                              top: context.spacing.xs,
                              child: _LanguageChip(
                                label: l.firstRunLangOther,
                                onTap: () => ref
                                    .read(localeProvider.notifier)
                                    .select(
                                      Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'ar'
                                      ? 'en'
                                      : 'ar',
                                    ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── progress dots ──────────────────────────────────────────────────────────

  Widget _dots(BuildContext context) {
    final count = _steps.length - 1;
    final s = context.spacing;
    return Positioned(
      top: s.md,
      left: 0,
      right: 0,
      child: Semantics(
        label: context.l10n.arrivalStep(_step, count),
        child: ExcludeSemantics(
          child: Row(
            key: FirstRunScreen.dotsKey,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: _still ? Duration.zero : FirstRunTokens.dotMove,
                  margin: EdgeInsets.symmetric(horizontal: s.xs / 2),
                  width: i == _step - 1
                      ? FirstRunTokens.dotWide
                      : FirstRunTokens.dot,
                  height: FirstRunTokens.dot,
                  decoration: BoxDecoration(
                    color: i == _step - 1
                        ? DeckTokens.bone
                        : DeckTokens.silver,
                    borderRadius: BorderRadius.circular(FirstRunTokens.dot / 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── step 0: the deck fans into the logo ────────────────────────────────────

  Widget _introStep(BuildContext context, AppLocalizations l) {
    final type = context.typography;
    final s = context.spacing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _touched = true;
        _intro.stop();
        setState(() => _step = 1);
      },
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final total = _intro.duration!.inMilliseconds;
          final fanT = _still
              ? 1.0
              : (_intro.value * total / FirstRunTokens.fan.inMilliseconds)
                    .clamp(0.0, 1.0);
          final logoT = _still
              ? 1.0
              : ((_intro.value * total - FirstRunTokens.fan.inMilliseconds) /
                        FirstRunTokens.fan.inMilliseconds)
                    .clamp(0.0, 1.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                child: SizedBox(
                  height: FirstRunTokens.deckCard.height * 1.4,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < FirstRunTokens.deckCount; i++)
                        _deckCard(i, Curves.easeOutCubic.transform(fanT)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: s.lg),
              Opacity(
                opacity: logoT,
                child: Transform.translate(
                  offset: Offset(0, (1 - logoT) * FirstRunTokens.landRise / 2),
                  child: Column(
                    children: [
                      Text(
                        context.l10n.appTitle,
                        style: StoryTokens.ruqaa(
                          type.display,
                        ).copyWith(color: context.colors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        context.l10n.firstRunTagline,
                        style: DeckTokens.meta(
                          type,
                        ).copyWith(color: context.colors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _deckFaces = [
    AppImages.cardBack,
    AppImages.cardFaceElder,
    AppImages.cardFaceCitizen,
    AppImages.cardFaceDoctor,
    AppImages.cardFaceMafia,
    AppImages.cardFaceDetective,
    AppImages.cardBack,
  ];

  Widget _deckCard(int i, double t) {
    const mid = (FirstRunTokens.deckCount - 1) / 2;
    final k = i - mid;
    const size = FirstRunTokens.deckCard;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return Transform.translate(
      offset: Offset(
        k * FirstRunTokens.deckSpread * t,
        (k * k) * FirstRunTokens.deckDrop / mid * t / mid,
      ),
      child: Transform.rotate(
        angle: k * FirstRunTokens.deckTilt * t,
        child: SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SeatTokens.radius),
              border: Border.all(
                color: SeatTokens.rim,
                width: SeatTokens.rimWidth,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SeatTokens.radius),
              child: Image(
                image: ResizeImage(
                  AssetImage(_deckFaces[i]),
                  width: (size.width * dpr).round(),
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── step 1: how do we address you ──────────────────────────────────────────

  Widget _heading(BuildContext context, String title, String? hint) {
    final type = context.typography;
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: StoryTokens.ruqaa(
              type.headline,
            ).copyWith(color: context.colors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ),
        if (hint != null)
          Text(
            hint,
            style: DeckTokens.meta(
              type,
            ).copyWith(color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _kindStep(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    final type = context.typography;
    return LayoutBuilder(
      builder: (context, box) {
        final cardH = (box.maxHeight - 330)
            .clamp(150.0, FirstRunTokens.pickMaxHeight)
            .toDouble();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            s.screenMargin,
            s.xl + s.md,
            s.screenMargin,
            s.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(context, l.firstRunKindTitle, l.firstRunKindHint),
              SizedBox(height: s.lg),
              SizedBox(
                height: cardH,
                child: Row(
                  children: [
                    Expanded(child: _pickCard(PlayerGender.male, cardH)),
                    const SizedBox(width: FirstRunTokens.pickGap),
                    Expanded(child: _pickCard(PlayerGender.female, cardH)),
                  ],
                ),
              ),
              SizedBox(height: s.lg),
              _agreeRow(context, l),
              SizedBox(height: s.sm),
              Text(
                l.firstRunKindNote,
                style: type.caption.copyWith(color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickCard(PlayerGender g, double height) {
    final l = context.l10n;
    final male = g == PlayerGender.male;
    final label = male ? l.firstRunBoy : l.firstRunGirl;
    final chosen = _gender == g && (_flip.isAnimating || _flip.value > 0);
    final other = !chosen && (_flip.isAnimating || _flip.value > 0);
    return GestureDetector(
      key: male ? FirstRunScreen.boyKey : FirstRunScreen.girlKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _pick(g),
      child: Semantics(
        button: true,
        label: label,
        child: AnimatedBuilder(
          animation: Listenable.merge([_shake, _flip]),
          builder: (context, _) {
            final dx = _shake.isAnimating
                ? math.sin(_shake.value * math.pi * 4) *
                      FirstRunTokens.shakeShift
                : 0.0;
            final turn = chosen
                ? Curves.easeInOutCubic.transform(
                    (_flip.value *
                            (FirstRunTokens.flip + FirstRunTokens.hold)
                                .inMilliseconds /
                            FirstRunTokens.flip.inMilliseconds)
                        .clamp(0.0, 1.0),
                  )
                : 0.0;
            final angle = turn * math.pi;
            final front = angle <= math.pi / 2;
            final card = RepaintBoundary(
              child: front
                  ? SeatCard(
                      name: label,
                      seat: 0,
                      gender: g,
                      showSeat: false,
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _welcomeBack(male),
                    ),
            );
            return Opacity(
              opacity: other
                  ? FirstRunTokens.passedAlpha
                  : (_agreed ? 1 : FirstRunTokens.dimmedAlpha),
              child: Transform.translate(
                offset: Offset(dx, -turn * FirstRunTokens.chosenLift),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, ModeTokens.perspective)
                    ..rotateY(angle),
                  child: card,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _welcomeBack(bool male) {
    final l = context.l10n;
    final type = context.typography;
    return SeatCardFrame(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.sm),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                male ? l.firstRunWelcomeBoy : l.firstRunWelcomeGirl,
                style: DeckTokens.card(
                  type,
                ).copyWith(color: context.colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              Text(
                male ? l.firstRunWelcomeBoyHint : l.firstRunWelcomeGirlHint,
                style: type.caption.copyWith(
                  color: context.colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agreeRow(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    final colors = context.colors;
    final body = DeckTokens.meta(
      context.typography,
    ).copyWith(color: colors.textSecondary);
    final link = body.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.underline,
      decorationColor: colors.textPrimary,
    );
    Widget linkText(Key key, String text, VoidCallback onTap) => InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.xs),
        child: Text(text, style: link),
      ),
    );
    final full =
        '${l.firstRunAgreePrefix}${l.firstRunAgreeTerms}${l.firstRunAgreeAnd}${l.firstRunAgreePrivacy}';
    return Container(
      padding: EdgeInsets.all(s.sm + s.xs),
      decoration: BoxDecoration(
        color: DeckTokens.panel,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(
          width: FirstRunTokens.agreeBorder,
          color: _highlightAgree ? colors.accentCrimson : DeckTokens.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: FirstRunScreen.agreeKey,
            checked: _agreed,
            label: full,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleAgree,
              child: SizedBox.square(
                dimension: IdentityTokens.target,
                child: Center(
                  child: AnimatedContainer(
                    duration: _still ? Duration.zero : DeckTokens.press,
                    width: FirstRunTokens.box,
                    height: FirstRunTokens.box,
                    decoration: BoxDecoration(
                      color: _agreed ? DeckTokens.bone : IdentityTokens.transparent,
                      borderRadius: BorderRadius.circular(
                        FirstRunTokens.boxRadius,
                      ),
                      border: Border.all(
                        width: DeckTokens.rimBorder,
                        color: _agreed
                            ? DeckTokens.bone
                            : DeckTokens.silverLight,
                      ),
                    ),
                    child: _agreed
                        ? const Icon(
                            Icons.check,
                            size: DeckTokens.check,
                            color: DeckTokens.ground,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: s.xs),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleAgree,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.firstRunAgreePrefix, style: body),
                  linkText(
                    FirstRunScreen.termsLinkKey,
                    l.firstRunAgreeTerms,
                    () => showTermsDocument(context),
                  ),
                  Text(l.firstRunAgreeAnd, style: body),
                  linkText(
                    FirstRunScreen.privacyLinkKey,
                    l.firstRunAgreePrivacy,
                    () => showPrivacyDocument(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── step 2: your name, written on your card ────────────────────────────────

  Widget _nameStep(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    final type = context.typography;
    final finalStep = _steps.last == _Step.name;
    return LayoutBuilder(
      builder: (context, box) {
        final roomy = box.maxHeight > FirstRunTokens.roomyAbove;
        final cardH = (box.maxHeight - 360)
            .clamp(
              roomy ? FirstRunTokens.myCardMin : FirstRunTokens.myCardTiny,
              FirstRunTokens.myCardWidth / SeatTokens.aspect,
            )
            .toDouble();
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  s.screenMargin,
                  roomy ? s.xl + s.md : s.xl,
                  s.screenMargin,
                  s.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heading(
                      context,
                      l.firstRunNameTitle,
                      roomy ? l.firstRunNameHint : null,
                    ),
                    SizedBox(height: s.md),
                    Center(
                      child: _Lander(
                        still: _still,
                        child: SizedBox(
                          key: FirstRunScreen.myCardKey,
                          width: cardH * SeatTokens.aspect,
                          height: cardH,
                          child: ListenableBuilder(
                            listenable: _name,
                            builder: (context, _) {
                              final typed = _name.text.trim();
                              return SeatCard(
                                name: typed.isEmpty
                                    ? l.firstRunNamePlate
                                    : typed,
                                seat: 0,
                                gender: _gender == PlayerGender.unspecified
                                    ? PlayerGender.male
                                    : _gender,
                                showSeat: false,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: s.md),
                    Container(
                      height: DeckTokens.primaryHeight + s.xs,
                      padding: EdgeInsets.symmetric(horizontal: s.md),
                      decoration: BoxDecoration(
                        color: DeckTokens.panel,
                        borderRadius: BorderRadius.circular(context.radii.card),
                        border: Border.all(color: DeckTokens.line),
                      ),
                      child: TextField(
                        key: FirstRunScreen.nameKey,
                        controller: _name,
                        autofocus: true,
                        maxLength: FirstRunTokens.nameMax,
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.done,
                        style: type.title.copyWith(
                          color: context.colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: l.firstRunNameField,
                          hintStyle: type.body.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                        onChanged: (_) {
                          _touched = true;
                          setState(() {});
                          _saveProgress();
                        },
                        onSubmitted: (_) {
                          if (_nameOk) finalStep ? _finish() : _move(_step + 1);
                        },
                      ),
                    ),
                    if (_failed && finalStep) _failure(context, l),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                s.screenMargin,
                0,
                s.screenMargin,
                s.md,
              ),
              child: BoneButton(
                key: finalStep
                    ? FirstRunScreen.continueKey
                    : FirstRunScreen.nextKey,
                label: _saving ? l.arrivalSaving : l.continueAction,
                disabledReason: l.firstRunNameNeed,
                onPressed: _nameOk && !_saving
                    ? () => finalStep ? _finish() : _move(_step + 1)
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _failure(BuildContext context, AppLocalizations l) => Padding(
    padding: EdgeInsets.only(top: context.spacing.sm),
    child: Text(
      key: FirstRunScreen.failedKey,
      l.profileSaveFailed,
      textAlign: TextAlign.center,
      style: context.typography.body.copyWith(
        color: context.colors.accentCrimson,
      ),
    ),
  );

  // ── step 3: keep your game ─────────────────────────────────────────────────

  Widget _saveStep(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    final type = context.typography;
    final signedIn =
        ref.watch(accountProfileProvider).valueOrNull?.signedIn ?? false;
    final keep = DeckTokens.meta(
      type,
    ).copyWith(color: context.colors.textSecondary);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.xl + s.md,
        s.screenMargin,
        s.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(context, l.firstRunSaveTitle, l.firstRunSaveHint),
          SizedBox(height: s.lg),
          Center(
            child: Container(
              width: FirstRunTokens.safeRing,
              height: FirstRunTokens.safeRing,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: DeckTokens.rimBorder,
                  color: DeckTokens.silverLight,
                ),
              ),
              child: Image.asset(
                AppEconomyArt.coinLarge,
                width: FirstRunTokens.safeCoin,
                cacheWidth:
                    (FirstRunTokens.safeCoin *
                            (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1))
                        .round(),
                excludeFromSemantics: true,
              ),
            ),
          ),
          SizedBox(height: s.md),
          Text(
            l.firstRunKeepCoins,
            style: keep,
            textAlign: TextAlign.center,
          ),
          Text(
            l.firstRunKeepLevel,
            style: keep,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: s.lg),
          if (signedIn)
            const Center(child: OnboardingAccountChoice())
          else ...[
            RimButton(
              key: FirstRunScreen.googleKey,
              label: l.firstRunGoogle,
              onPressed: _googleBusy || _saving ? null : _google,
            ),
            SizedBox(height: s.sm),
            RimButton(
              key: FirstRunScreen.emailKey,
              label: l.firstRunEmail,
              onPressed: _saving
                  ? null
                  : () => showAccountSheet(context, onboarding: true),
            ),
          ],
          SizedBox(height: s.sm),
          TextButton(
            key: FirstRunScreen.guestKey,
            onPressed: _saving ? null : _finish,
            child: Text(
              _saving ? l.arrivalSaving : l.firstRunGuest,
              style: type.body.copyWith(
                color: context.colors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            l.firstRunLater,
            style: type.caption.copyWith(color: context.colors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (_failed) _failure(context, l),
        ],
      ),
    );
  }

  // ── the compact form for installs that predate the terms ───────────────────

  Widget _termsOnly(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(s.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: s.xl),
                _heading(context, l.termsUpdatedTitle, l.termsUpdatedHint),
                SizedBox(height: s.lg),
                _agreeRow(context, l),
                if (_failed) _failure(context, l),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(s.screenMargin),
          child: BoneButton(
            key: FirstRunScreen.continueKey,
            label: _saving ? l.arrivalSaving : l.continueAction,
            onPressed: _agreed && !_saving ? _finish : null,
          ),
        ),
      ],
    );
  }
}

/// «English» / «العربي» in the corner of the first question.
class _LanguageChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LanguageChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: FirstRunScreen.languageKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: IdentityTokens.target,
            minHeight: IdentityTokens.target,
          ),
          child: Center(
            child: Container(
              height: DeckTokens.pill,
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DeckTokens.pill / 2),
                border: Border.all(color: DeckTokens.silver),
              ),
              child: Text(
                label,
                style: DeckTokens.meta(
                  context.typography,
                ).copyWith(color: context.colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card arriving from above, tilted, and settling. Transform and opacity
/// only; with animations off it is simply there.
class _Lander extends StatelessWidget {
  final bool still;
  final Widget child;
  const _Lander({required this.still, required this.child});

  @override
  Widget build(BuildContext context) {
    if (still) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: FirstRunTokens.land,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -(1 - t) * FirstRunTokens.landRise),
          child: Transform.rotate(
            angle: -(1 - t) * FirstRunTokens.landTilt,
            child: child,
          ),
        ),
      ),
    );
  }
}
