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
import '../../account/embedded_browser_sheet.dart' show sentToRealBrowser;
import '../../account/account_sheet.dart'
    show accountAuthProvider, accountProfileProvider, showAccountSheet;
import '../../account/handle_rules.dart';
import '../../account/onboarding_account_step.dart';
import '../../social/directory.dart'
    show DirectoryMe, HandleRefusal, directoryApiProvider;
import '../../../platform/device/time_zone.dart';
import '../../l10n_ext.dart';
import '../setup/player_name.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../../widgets/deck/seat_card.dart';
import '../../widgets/legal_documents.dart';
import '../../widgets/mafia_kit.dart';

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

/// The first launch, with progress dots: the deck fans into the logo, then,
/// only where the build has a server, the account (Google, email, or a guest
/// in plain sight), «نكلّمك إزاي؟» (two big avatar cards and the one box for
/// 18+ and the terms) and «اسمك إيه؟» (the name is written on the chosen card
/// as it is typed; a new account also picks its username there).
///
/// An account that already has a name is welcomed back under it and never
/// asked again. There is no permissions page: the system dialogs open by
/// themselves as the app starts (`startup_permissions.dart`).
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
  static const handleKey = ValueKey('first_run_handle');
  static const welcomeKey = ValueKey('first_run_welcome');
  static const playKey = ValueKey('first_run_play');

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

enum _Step { intro, account, kind, name }

class _FirstRunScreenState extends ConsumerState<FirstRunScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _name;
  final TextEditingController _handle = TextEditingController();
  PlayerGender _gender = PlayerGender.unspecified;
  bool _agreed = false;
  bool _highlightAgree = false;
  bool _saving = false;
  bool _failed = false;
  bool _googleBusy = false;
  int _step = 0;
  late final List<_Step> _steps;

  /// The signed-in account already has a name: welcomed back, never asked.
  bool _returning = false;

  /// The account's entry has been looked up (once per sign-in).
  bool _adopted = false;
  bool _adopting = false;
  String? _accountHandle;

  /// The player typed in the username field (the suggestion stops following
  /// the name).
  bool _handleTouched = false;
  HandleRefusal? _handleRefusal;

  int get _kindIndex => _steps.indexOf(_Step.kind);
  int get _nameIndex => _steps.indexOf(_Step.name);

  /// Never asked of a build without a server: reading the account there
  /// would start a backend that has nothing to talk to.
  bool get _signedIn =>
      _steps.contains(_Step.account) &&
      (ref.read(accountProfileProvider).valueOrNull?.signedIn ?? false);

  /// A new account picks its username with its name.
  bool get _asksHandle => _signedIn && !_returning;

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
      if (ref.read(accountsAvailableProvider)) _Step.account,
      _Step.kind,
      _Step.name,
    ];
    final profile = ref.read(playerProfileProvider).valueOrNull;
    _name = TextEditingController(text: profile?.name ?? '');
    _gender = profile?.gender ?? PlayerGender.unspecified;
    _name.addListener(_followName);
    _flip.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _step == _kindIndex &&
          mounted) {
        _afterKind();
      }
    });
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _step == 0 &&
          !_touched &&
          !widget.termsOnly &&
          mounted) {
        _firstQuestion();
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
    // A tick is replayed only if it was made under the terms in force now (or
    // the app has already recorded the consent). A stale one is never shown
    // pre-ticked, and the player comes back to the chapter that holds the box
    // rather than to a later one that cannot proceed.
    final agreed =
        (saved.agreed && saved.termsVersion == currentTermsVersion) ||
        ref.read(termsAcceptanceProvider).valueOrNull?.current == true;
    setState(() {
      _step = agreed ? index : math.min(index, _kindIndex);
      _agreed = agreed;
      if (_name.text.trim().isEmpty) {
        _name.text = saved.name.characters
            .take(FirstRunTokens.nameMax)
            .toString();
      }
      if (_gender == PlayerGender.unspecified) _gender = saved.gender;
    });
    // Back from the Google browser trip: the account decides what follows.
    if (_steps[_step] == _Step.account && _signedIn) await _adoptAccount();
  }

  /// The intro hands over. An install already signed in (the app came back
  /// from the browser, or a cold start through the sign-in link) goes on
  /// from the account instead of showing it again.
  void _firstQuestion() {
    setState(() => _step = 1);
    if (_steps[1] == _Step.account && _signedIn) _adoptAccount();
  }

  /// The username suggestion follows the name until the player edits it.
  void _followName() {
    if (_handleTouched) return;
    final next = suggestHandle(cleanPlayerName(_name.text));
    if (_handle.text != next) _handle.text = next;
  }

  /// After sign-in: an account with a name is welcomed back under it (the
  /// server's name wins over anything typed on this device); a new account
  /// goes on to choose its name and username.
  Future<void> _adoptAccount() async {
    if (_adopting || _adopted || !mounted) return;
    _adopting = true;
    setState(() => _googleBusy = true);
    DirectoryMe? me;
    try {
      me = await ref
          .read(directoryApiProvider)
          .me()
          .timeout(FirstRunTokens.accountLookup);
    } catch (_) {
      // Unreachable or switched off: carried on as a new account.
    }
    if (!mounted) return;
    final name = me?.name;
    setState(() {
      _adopting = false;
      _adopted = true;
      _googleBusy = false;
      _accountHandle = me?.handle;
      if (name != null) {
        _returning = true;
        _name.text = name.characters.take(FirstRunTokens.nameMax).toString();
        if (me?.gender != null) _gender = me!.gender!;
      } else {
        final offered = ref.read(accountProfileProvider).valueOrNull?.name;
        if (_name.text.trim().isEmpty && offered != null) {
          _name.text = cleanPlayerName(
            offered,
          ).characters.take(FirstRunTokens.nameMax).toString();
        }
        _followName();
      }
    });
    _move(_kindIndex);
  }

  /// The card was chosen: a returning account already has its name.
  void _afterKind() {
    if (_returning) {
      _finish();
    } else {
      _move(_nameIndex);
    }
  }

  /// The name card's button: a new account claims its username first, so a
  /// taken one is said here rather than discovered later.
  Future<void> _nameContinue() async {
    if (!_nameOk || _saving) return;
    if (_asksHandle) {
      final wanted = _handle.text.trim();
      if (!handlePattern.hasMatch(wanted)) {
        setState(() => _handleRefusal = HandleRefusal.invalid);
        return;
      }
      setState(() {
        _saving = true;
        _handleRefusal = null;
      });
      HandleRefusal? refusal;
      try {
        final api = ref.read(directoryApiProvider);
        await api.hello(
          name: cleanPlayerName(_name.text),
          gender: _gender.name,
          tz: await deviceTimeZone(),
          locale: deviceLocaleTag(),
        );
        refusal = (await api.setHandle(wanted)).$2;
      } catch (_) {
        // The server's own handle stays; the profile can change it later.
      }
      if (!mounted) return;
      setState(() => _saving = false);
      if (refusal == HandleRefusal.taken ||
          refusal == HandleRefusal.invalid ||
          refusal == HandleRefusal.refused) {
        setState(() {
          _handleRefusal = refusal;
          _handleTouched = true;
        });
        return;
      }
    }
    await _finish();
  }

  void _saveProgress() {
    if (widget.termsOnly) return;
    FirstRunProgress(
      chapter: _steps[_step].name,
      name: _name.text,
      gender: _gender,
      agreed: _agreed,
      termsVersion: currentTermsVersion,
    ).save();
  }

  @override
  void dispose() {
    _name.removeListener(_followName);
    _name.dispose();
    _handle.dispose();
    _intro.dispose();
    _shake.dispose();
    _flip.dispose();
    super.dispose();
  }

  bool get _nameOk =>
      cleanPlayerName(_name.text).characters.length >= FirstRunTokens.nameMin;

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
    if (_steps[step] == _Step.account && _signedIn && !_adopted) {
      _adoptAccount();
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
      _afterKind();
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
      // The consent is recorded first. Saving the profile opens the gate for
      // the screen behind this one; had the box not been recorded by then, the
      // gate would flip to the terms-only form in the middle of this save.
      await ref.read(termsAcceptanceProvider.notifier).accept(adult: true);
      if (!widget.termsOnly) {
        await ref
            .read(playerProfileProvider.notifier)
            .save(
              PlayerProfile(name: cleanPlayerName(_name.text), gender: _gender),
            );
        await WelcomeGreeting.arm();
        // The first launch no longer plays the film, so the first-run
        // markers the app-open policy reads are set here.
        try {
          await ref.read(profileStoreProvider).markIntroSeen();
          await ref.read(matchRepositoryProvider).markOnboardingSeen();
        } catch (_) {}
      }
      await FirstRunProgress.clear();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _google() async {
    if (await sentToRealBrowser(context, ref)) return;
    if (!mounted) return;
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
    if (_steps.contains(_Step.account) && !widget.termsOnly) {
      ref.listen<AsyncValue<AccountProfile>>(accountProfileProvider, (
        previous,
        next,
      ) {
        final now = next.valueOrNull;
        if (next.hasError || now == null || !now.signedIn) return;
        if (previous?.valueOrNull?.signedIn ?? false) return;
        if (_steps[_step] == _Step.account) _adoptAccount();
      });
    }
    final step = widget.termsOnly ? _Step.kind : _steps[_step];
    return PopScope(
      canPop: widget.termsOnly || _step <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _step > 1) _move(_step - 1);
      },
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
                              _Step.account => _accountStep(context, l),
                              _Step.kind =>
                                _returning &&
                                        _gender != PlayerGender.unspecified
                                    ? _welcomeStep(context, l)
                                    : _kindStep(context, l),
                              _Step.name => _nameStep(context, l),
                            },
                          ),
                        ),
                        if (step != _Step.intro) _dots(context),
                        if (_step > 1)
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
                        if (_step == 1)
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
                    color: i == _step - 1 ? DeckTokens.bone : DeckTokens.silver,
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
        _firstQuestion();
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
                        style: type.display.copyWith(
                          color: context.colors.textPrimary,
                        ),
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
            style: type.headline.copyWith(color: context.colors.textPrimary),
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
                  ? SeatCard(name: label, seat: 0, gender: g, showSeat: false)
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
                      color: _agreed
                          ? DeckTokens.bone
                          : IdentityTokens.transparent,
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
                              final typed = cleanPlayerName(_name.text);
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
                          if (_nameOk && !_asksHandle) _nameContinue();
                        },
                      ),
                    ),
                    if (_asksHandle) ...[
                      SizedBox(height: s.xs),
                      Text(
                        l.firstRunNameLater,
                        style: type.caption.copyWith(
                          color: context.colors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: s.md),
                      _handleField(context, l),
                    ],
                    if (_failed) _failure(context, l),
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
                key: FirstRunScreen.continueKey,
                label: _saving ? l.arrivalSaving : l.continueAction,
                disabledReason: l.firstRunNameNeed,
                onPressed: _nameOk && !_saving ? _nameContinue : null,
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

  // ── step 1: the account ────────────────────────────────────────────────────

  Widget _accountStep(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    final type = context.typography;
    final signedIn =
        ref.watch(accountProfileProvider).valueOrNull?.signedIn ?? false;
    final busy = _googleBusy || _saving || _adopting;
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
          Text(
            context.l10n.appTitle,
            style: type.display.copyWith(color: context.colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: s.lg),
          _heading(context, l.firstRunAccountTitle, null),
          SizedBox(height: s.lg),
          if (signedIn) ...[
            const Center(child: OnboardingAccountChoice()),
            SizedBox(height: s.md),
            BoneButton(
              key: FirstRunScreen.nextKey,
              label: busy ? l.arrivalSaving : l.continueAction,
              onPressed: busy ? null : _adoptAccount,
            ),
          ] else ...[
            BoneButton(
              key: FirstRunScreen.googleKey,
              label: l.firstRunGoogle,
              onPressed: busy ? null : _google,
            ),
            SizedBox(height: s.sm),
            RimButton(
              key: FirstRunScreen.emailKey,
              label: l.firstRunEmail,
              onPressed: busy
                  ? null
                  : () => showAccountSheet(context, onboarding: true),
            ),
            SizedBox(height: s.sm),
            TextButton(
              key: FirstRunScreen.guestKey,
              onPressed: busy ? null : () => _move(_kindIndex),
              child: Text(
                l.firstRunGuestPlain,
                style: type.body.copyWith(
                  color: context.colors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          SizedBox(height: s.lg),
          Container(
            padding: EdgeInsets.all(s.sm + s.xs),
            decoration: BoxDecoration(
              color: DeckTokens.panel,
              borderRadius: BorderRadius.circular(context.radii.card),
              border: Border.all(color: DeckTokens.line),
            ),
            child: Text(
              l.firstRunAccountNote,
              style: DeckTokens.meta(
                type,
              ).copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          if (_failed) _failure(context, l),
        ],
      ),
    );
  }

  // ── a returning account: welcomed back under its own name ─────────────────

  Widget _welcomeStep(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    final type = context.typography;
    final name = cleanPlayerName(_name.text);
    final terms = ref.watch(termsAcceptanceProvider).valueOrNull?.current;
    return Column(
      key: FirstRunScreen.welcomeKey,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              s.screenMargin,
              s.xl + s.md,
              s.screenMargin,
              s.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _Lander(
                    still: _still,
                    child: SizedBox(
                      width: FirstRunTokens.myCardWidth,
                      height: FirstRunTokens.myCardWidth / SeatTokens.aspect,
                      child: SeatCard(
                        name: name,
                        seat: 0,
                        gender: _gender,
                        showSeat: false,
                      ),
                    ),
                  ),
                ),
                if (_accountHandle != null)
                  Text(
                    '@$_accountHandle',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: DeckTokens.meta(
                      type,
                    ).copyWith(color: context.colors.textSecondary),
                  ),
                SizedBox(height: s.md),
                _heading(
                  context,
                  l.firstRunWelcomeBack(name),
                  l.firstRunWelcomeBackHint,
                ),
                if (terms != true) ...[
                  SizedBox(height: s.lg),
                  _agreeRow(context, l),
                ],
                if (_failed) _failure(context, l),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(s.screenMargin, 0, s.screenMargin, s.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BoneButton(
                key: FirstRunScreen.playKey,
                label: _saving ? l.arrivalSaving : l.firstRunLetsPlay,
                onPressed: _saving
                    ? null
                    : () {
                        if (terms == true && !_agreed) _agreed = true;
                        if (!_agreed) {
                          setState(() => _highlightAgree = true);
                          if (!_still) _shake.forward(from: 0);
                          return;
                        }
                        _finish();
                      },
              ),
              SizedBox(height: s.xs),
              Text(
                l.firstRunSameName,
                style: type.caption.copyWith(color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── a new account's username, under its name ──────────────────────────────

  Widget _handleField(BuildContext context, AppLocalizations l) {
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final refusal = _handleRefusal;
    final problem = switch (refusal) {
      HandleRefusal.taken => l.firstRunHandleTaken,
      HandleRefusal.invalid || HandleRefusal.refused => l.firstRunHandleInvalid,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.firstRunHandleLabel,
          style: type.body.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: s.xs),
        Container(
          height: DeckTokens.primaryHeight + s.xs,
          padding: EdgeInsets.symmetric(horizontal: s.md),
          decoration: BoxDecoration(
            color: DeckTokens.panel,
            borderRadius: BorderRadius.circular(context.radii.card),
            border: Border.all(
              color: problem == null ? DeckTokens.line : colors.accentCrimson,
            ),
          ),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Text(
                '@',
                style: type.title.copyWith(color: colors.textMuted),
              ),
              SizedBox(width: s.xs),
              Expanded(
                child: TextField(
                  key: FirstRunScreen.handleKey,
                  controller: _handle,
                  maxLength: FirstRunTokens.handleMax,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: type.title.copyWith(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {
                    _handleTouched = true;
                    _handleRefusal = null;
                  }),
                  onSubmitted: (_) => _nameContinue(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: s.xs),
        Text(
          problem ?? l.firstRunHandleHint,
          style: type.caption.copyWith(
            color: problem == null ? colors.textMuted : colors.accentCrimson,
          ),
        ),
      ],
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
