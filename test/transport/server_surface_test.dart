import 'dart:io';

import 'package:test/test.dart';

/// **The security review of the online surface, written down as assertions.**
///
/// Doc 11 §10 asks for a security review before release. A review is a moment;
/// this is the part of it that survives the moment. Every group below is a
/// finding from that review — either a hole that was found and closed, or a
/// property that held and would be silently easy to lose.
///
/// # Why static scans and not integration tests
///
/// `supabase/tests/e2e_match.py` already plays a whole match against the real
/// server and tries the rude things: a Doctor submitting a kill, a Citizen
/// asking who the Mafia are, a guest driving the phase, a stranger joining a
/// match in progress. What it cannot do is notice a **new** function that
/// forgot a guard, or a **new** policy that forgot a role — those are absences,
/// and an absence is invisible to a test that walks a known path.
///
/// So this file reads the server the way a reviewer would, and fails when the
/// shape stops matching. It runs on the Dart VM in a couple of milliseconds and
/// needs no network, which is the only reason it is honest to say it runs on
/// every commit.
///
/// # The two holes this file exists because of
///
/// Both were real, both were found by reading rather than by any test, and both
/// were the same mistake in different clothes:
///
///   1. `claim_speaking_floor` shipped `security definer`, taking a `p_user`
///      argument, executable by `authenticated`. Anyone signed in who knew a
///      room id could have handed the floor to any player in any phase — the
///      night included — with none of the policy table in the way. The cause
///      was that `revoke ... from public` does not remove the *explicit* grants
///      the project's default privileges hand to `anon` and `authenticated`.
///
///   2. Every RLS policy was written without a `to` clause, which means
///      `to public`, which includes `anon` — the role a request carries when it
///      presents the publishable key and no session at all. Not exploitable,
///      because every `using` clause funnels through `auth.uid()`; but the
///      boundary was being held by arithmetic instead of by a grant, and the
///      next policy to be written would have inherited the same silence.
void main() {
  final functionsDir = Directory('supabase/functions');
  final migrationsDir = Directory('supabase/migrations');

  List<Directory> edgeFunctions() =>
      functionsDir
          .listSync()
          .whereType<Directory>()
          .where((d) => !d.path.endsWith('_shared'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String nameOf(FileSystemEntity e) =>
      e.uri.pathSegments.where((s) => s.isNotEmpty).last;

  List<File> migrations() =>
      migrationsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String allMigrations() =>
      migrations().map((f) => f.readAsStringSync()).join('\n');

  setUpAll(() {
    // Every group below reads from disk, so a wrong working directory would
    // make the whole file pass by finding nothing.
    expect(
      functionsDir.existsSync(),
      isTrue,
      reason: 'run from the repository root',
    );
    expect(
      migrationsDir.existsSync(),
      isTrue,
      reason: 'run from the repository root',
    );
    expect(edgeFunctions().length, greaterThan(15));
    expect(migrations().length, greaterThan(10));
  });

  // ───────────────────────────────────────────────────────────────────────

  group('no Edge Function has its own front door', () {
    test('every function is served through handler()', () {
      // `handler()` is where authentication lives: it rejects a request with no
      // valid bearer token before the body is even read. A function that called
      // `Deno.serve` directly would be reachable by anybody with the URL, and
      // would look completely normal doing it.
      // Not player endpoints, and each proves who is calling another way:
      // Google's signed AdMob callback, and a scheduler's shared secret.
      // `tester_signup` is the one deliberately public door: the /beta form
      // for people with no session. It can only append a name and email, and
      // every request passes its atomic per-address limit first.
      const ownAuth = {
        'admob_ssv': 'verifySsv(url, loadKeys)',
        'play_voided_sync': 'request.headers.get("x-sync-secret") !== secret',
        'tester_signup': 'db.rpc("tester_signup_attempt"',
      };
      final bare = <String>[];
      for (final dir in edgeFunctions()) {
        final source = File('${dir.path}/index.ts').readAsStringSync();
        final own = ownAuth[nameOf(dir)];
        if (own != null && source.contains(own)) continue;
        if (!source.contains('Deno.serve(handler(')) bare.add(nameOf(dir));
      }
      expect(
        bare,
        isEmpty,
        reason: 'these functions bypass the authentication wrapper: $bare',
      );
    });

    test('every function that names a room checks the caller is in it', () {
      // The two exceptions are the two that cannot check: `create_room` has no
      // room yet, and `join_room` is how you stop being a stranger. Everything
      // else either loads the caller's membership or compares them to the host.
      const beforeMembership = {'create_room', 'join_room'};

      final unguarded = <String>[];
      for (final dir in edgeFunctions()) {
        final name = nameOf(dir);
        if (beforeMembership.contains(name)) continue;
        final source = File('${dir.path}/index.ts').readAsStringSync();
        // A function that never names a room has no membership to check. It is
        // still behind `handler`, which is the test above, so it is still
        // authenticated — it simply has nothing room-shaped to be wrong about.
        if (!source.contains('roomId')) continue;
        final guarded =
            source.contains('loadMembership(') ||
            source.contains('host_id !== userId') ||
            // Ad claims: the SQL joins room_players on the caller, and the
            // status read is keyed on the caller's own claim.
            (name == 'economy' &&
                File('supabase/migrations/20260921000800_ad_rewards.sql')
                    .readAsStringSync()
                    .contains('where r.id=p_room and p.user_id=p_user')) ||
            (name == 'player_safety' &&
                source.contains('submit_player_safety') &&
                File('supabase/migrations/20260920000200_player_safety.sql')
                    .readAsStringSync()
                    .contains('where room_id=p_room and user_id=p_user') &&
                // F11: the v11 report checks the same membership in SQL.
                File('supabase/migrations/20260928001100_safety_v11.sql')
                    .readAsStringSync()
                    .contains(
                      'from public.room_players where room_id=p_room and user_id=p_user',
                    ));
        if (!guarded) unguarded.add(name);
      }
      expect(
        unguarded,
        isEmpty,
        reason:
            'these functions accept a roomId without establishing who is '
            'asking: $unguarded',
      );
    });

    test('the service key is read in exactly one file', () {
      // Every function runs as the service role, which is what makes "submit a
      // vote for somebody else" unreachable rather than merely validated. The
      // cost of that is that a single function constructing its own client with
      // a caller-supplied header would hold the keys to the whole schema.
      final readers = <String>[];
      for (final file
          in functionsDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.ts'))) {
        if (file.readAsStringSync().contains('SUPABASE_SERVICE_ROLE_KEY')) {
          readers.add('${nameOf(file.parent)}/${nameOf(file)}');
        }
      }
      expect(readers, equals(['_shared/api.ts']));
    });

    test('no function returns what it caught', () {
      // A stack trace from a function that touched the role table is a leak of
      // a different kind. `handler()` logs the exception and answers with a
      // fixed sentence; nothing may widen that.
      final echoes = <String>[];
      for (final dir in edgeFunctions()) {
        final source = File('${dir.path}/index.ts').readAsStringSync();
        if (RegExp(r'fail\([^)]*\b(?:e|err|error)\.message').hasMatch(source) ||
            source.contains('String(e)')) {
          echoes.add(nameOf(dir));
        }
      }
      expect(
        echoes,
        isEmpty,
        reason: 'these functions echo an exception to the client: $echoes',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────

  group('security definer functions are not part of the client surface', () {
    /// Every `security definer` function declared anywhere in the migrations,
    /// mapped to whether its header pins a `search_path`.
    Map<String, bool> declared() {
      final out = <String, bool>{};
      final pattern = RegExp(
        r'create\s+(?:or\s+replace\s+)?function\s+([\w.]+)\s*\(.*?\)\s*returns(.*?)as\s*\$\$',
        caseSensitive: false,
        dotAll: true,
      );
      for (final m in pattern.allMatches(allMigrations())) {
        final header = m.group(2)!;
        if (!RegExp(
          r'security\s+definer',
          caseSensitive: false,
        ).hasMatch(header)) {
          continue;
        }
        out[m.group(1)!] = RegExp(
          r'set\s+search_path',
          caseSensitive: false,
        ).hasMatch(header);
      }
      return out;
    }

    test('the scan finds the functions it is supposed to', () {
      // Without this, a regex that stopped matching would report a perfectly
      // clean server made of nothing.
      final names = declared().keys.toSet();
      expect(names, contains('public.claim_speaking_floor'));
      expect(names, contains('public.purge_finished_rooms'));
      expect(names.length, greaterThanOrEqualTo(10));
    });

    test('each one pins its search_path', () {
      // A definer function that resolved `room_players` through the caller's
      // search_path would be a way to feed it a different table.
      final loose = declared().entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();
      expect(
        loose,
        isEmpty,
        reason:
            'these run as the owner with a caller-controlled '
            'search_path: $loose',
      );
    });

    test('each one is revoked from anon AND authenticated by name', () {
      // The trap, verbatim from `20260902000700` §2: this project carries a
      // default-privileges rule granting EXECUTE on new functions in `public`
      // to both client roles. A function therefore arrives with an inherited
      // PUBLIC grant *and* two explicit ones, and `revoke ... from public`
      // removes only the first. The revoke has to name all three.
      final sql = allMigrations();

      final revoked = <String>{};
      final pattern = RegExp(
        r'revoke\s+all\s+on\s+function\s+([\w.]+)\s*\([^)]*\)\s*from\s+([^;]+);',
        caseSensitive: false,
        dotAll: true,
      );
      for (final m in pattern.allMatches(sql)) {
        final from = m.group(2)!;
        if (from.contains('anon') && from.contains('authenticated')) {
          revoked.add(m.group(1)!);
        }
      }

      final dropped = RegExp(
        r'drop\s+function\s+(?:if\s+exists\s+)?([\w.]+)',
        caseSensitive: false,
      ).allMatches(sql).map((m) => m.group(1)!).toSet();

      final exposed = <String>[];
      for (final name in declared().keys) {
        if (revoked.contains(name)) continue;
        if (dropped.contains(name)) continue;
        // The `private` schema is revoked wholesale rather than per function,
        // which is stronger: a new helper added there is covered on arrival.
        if (name.startsWith('private.')) continue;
        exposed.add(name);
      }

      expect(
        exposed,
        isEmpty,
        reason:
            'these are callable by a signed-in client through '
            '/rest/v1/rpc: $exposed',
      );
    });

    test('the private schema really is revoked wholesale', () {
      expect(
        RegExp(
          r'revoke\s+all\s+on\s+schema\s+private\s+from[^;]*anon[^;]*authenticated',
          caseSensitive: false,
        ).hasMatch(allMigrations()),
        isTrue,
        reason: 'the per-function exemption above rests on this',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────

  group('every policy names the role it is for', () {
    test('no policy is left on the default of `to public`', () {
      // `to public` includes `anon`, the role of a request that presented the
      // publishable key — which ships inside the APK — and nothing else. Every
      // player is signed in, so `authenticated` is the whole audience.
      final sql = allMigrations();

      final altered = RegExp(
        r'alter\s+policy\s+(\w+)\s+on\s+[\w.]+\s+to\s+authenticated',
        caseSensitive: false,
      ).allMatches(sql).map((m) => m.group(1)!).toSet();

      final dropped = RegExp(
        r'drop\s+policy\s+(?:if\s+exists\s+)?(\w+)\s+on',
        caseSensitive: false,
      ).allMatches(sql).map((m) => m.group(1)!).toSet();

      final wide = <String>[];
      final pattern = RegExp(
        r'create\s+policy\s+(\w+)\s+on\s+[\w.]+(.*?);',
        caseSensitive: false,
        dotAll: true,
      );
      for (final m in pattern.allMatches(sql)) {
        final name = m.group(1)!;
        final body = m.group(2)!;
        if (RegExp(
          r'\bto\s+authenticated\b',
          caseSensitive: false,
        ).hasMatch(body)) {
          continue;
        }
        if (altered.contains(name) || dropped.contains(name)) continue;
        // The single deliberate exception: the update gate's two-integer
        // minimum-build row is public config, read with the bare key so a
        // launch never has to create an anonymous user (20261001000100).
        if (name == 'app_config_public_read' &&
            RegExp(
              r'\bon\s+public\.app_config\s+for\s+select\s+to\s+anon\s+using\s*\(\s*true\s*\)',
              caseSensitive: false,
            ).hasMatch(m.group(0)!)) {
          continue;
        }
        wide.add(name);
      }

      expect(
        wide,
        isEmpty,
        reason:
            'these policies are evaluated for unauthenticated callers: '
            '$wide',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────

  group('nothing that unlocks the project is committable', () {
    test('the file holding this build\'s project keys is ignored by git', () {
      final ignore = File('.gitignore').readAsStringSync();
      expect(ignore.contains('dart_defines.json'), isTrue);
      // And the committed template really is a template.
      final example = File('dart_defines.example.json').readAsStringSync();
      expect(example.contains('<project-ref>'), isTrue);
      expect(example.contains('sb_publishable_...'), isTrue);
    });

    test('no tracked source carries a secret key', () {
      // The publishable key is not a secret and is allowed to ship; the secret
      // key would let its holder read every role in every room.
      final suspects = <String>[];
      for (final dir in [
        'lib',
        'test',
        'supabase/functions',
        'supabase/migrations',
        'tool',
      ]) {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        for (final f in d.listSync(recursive: true).whereType<File>()) {
          if (!(f.path.endsWith('.dart') ||
              f.path.endsWith('.ts') ||
              f.path.endsWith('.sql') ||
              f.path.endsWith('.py'))) {
            continue;
          }
          final source = f.readAsStringSync();
          if (RegExp(r'sb_secret_[A-Za-z0-9_-]{10,}').hasMatch(source) ||
              RegExp(r'\beyJ[A-Za-z0-9_-]{20,}\.').hasMatch(source)) {
            suspects.add(f.path);
          }
        }
      }
      expect(suspects, isEmpty, reason: 'a key is committed in: $suspects');
    });
  });

  group('every phase move is one compare-and-set', () {
    String fn(String name) =>
        File('supabase/functions/$name/index.ts').readAsStringSync();

    test('no phase mover writes room_state directly', () {
      // The phase, the day, the deadline and the payload land in one
      // statement under the room lock (`commit_phase_open`,
      // `commit_confrontation`, `commit_accusation`, `commit_resolution`). A
      // handler that updated `room_state` by hand again would be a handler
      // that could move a room two drivers had already moved, or reset a
      // clock that had already run.
      for (final name in [
        'open_phase',
        'advance_phase',
        'generate_confrontation',
        'submit_accusation',
        'resolve_night',
        'resolve_vote',
      ]) {
        final source = fn(name);
        expect(
          RegExp(r'from\("room_state"\)\s*\.update\(').hasMatch(source),
          isFalse,
          reason: '$name updates room_state outside a transaction',
        );
        expect(
          source.contains('.rpc("commit_'),
          isTrue,
          reason: '$name does not commit through an RPC',
        );
      }
    });

    test('the resolvers commit only the moves they counted', () {
      expect(fn('resolve_night'), contains('p_fingerprint: fingerprint'));
      expect(fn('resolve_vote'), contains('p_fingerprint: fingerprint'));
      final sql = allMigrations();
      expect(sql, contains('public.night_fingerprint(p_room,p_number)'));
      expect(sql, contains('public.vote_fingerprint(p_room,p_number,p_round)'));
    });

    test('an expiry default never overwrites a move the player made', () {
      final source = fn('advance_phase');
      final defaults = RegExp(r'\.upsert\(').allMatches(source).length;
      final guarded = RegExp(
        r'ignoreDuplicates:\s*true',
      ).allMatches(source).length;
      expect(defaults, greaterThanOrEqualTo(2));
      expect(
        guarded,
        equals(defaults),
        reason:
            'a default upsert without ignoreDuplicates can replace a '
            'real action that landed after the read',
      );
    });

    test('moves and ballots are guarded by phase on the table itself', () {
      final sql = allMigrations();
      expect(sql, contains('create trigger night_action_phase_guard'));
      expect(sql, contains('create trigger vote_phase_guard'));
      // Both guards hold the state row shared while they check, so a
      // resolution that wants it exclusively waits for the move to land.
      expect(
        RegExp(r'guard_night_action_phase[\s\S]*?for share').hasMatch(sql),
        isTrue,
      );
      expect(
        RegExp(r'guard_vote_phase[\s\S]*?for share').hasMatch(sql),
        isTrue,
      );
      // ...and the handlers that write those rows say what the guard said.
      for (final name in [
        'submit_night_action',
        'submit_vote',
        'advance_phase',
      ]) {
        expect(
          fn(name),
          contains('PHASE_CLOSED'),
          reason: '$name would surface the guard as a generic failure',
        );
      }
    });

    test('the roles reach the payload only with the result', () {
      final sql = allMigrations();
      expect(
        sql,
        contains("if p_next <> 'result' and p_patch ? 'standings' then"),
      );
    });

    test('one seat per user across rooms', () {
      final sql = allMigrations();
      expect(sql, contains('public.vacate_other_rooms(p_host, null)'));
      expect(sql, contains('public.vacate_other_rooms(p_user, r.id)'));
      expect(sql, contains("pg_advisory_xact_lock(hashtext('room_entry:'"));
    });

    test('a failed read is never an empty success', () {
      // Every `.from(...).select(...)` in the phase movers and the history
      // builder is followed by a check of its error before the data is used.
      for (final name in [
        'open_phase',
        'advance_phase',
        'generate_confrontation',
        'submit_accusation',
        'submit_night_action',
        'submit_vote',
        'resolve_night',
        'resolve_vote',
      ]) {
        final source = fn(name);
        final unchecked = RegExp(
          r'const \{ data: (\w+) \} = await db',
        ).allMatches(source).map((m) => m.group(1)!).toList();
        expect(
          unchecked,
          isEmpty,
          reason: '$name reads $unchecked without checking the error',
        );
      }
      final history = File(
        'supabase/functions/_shared/history.ts',
      ).readAsStringSync();
      expect(
        RegExp(r'const \{ data: (\w+) \} = await db').hasMatch(history),
        isFalse,
      );
    });
  });
}
