// Media capture harness: real release widgets and interactions, seeded backend.
// This is not evidence of a real multi-user network session.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'file:///D:/Flutter%20Data/Projects/AL%20Mafia/.claude/worktrees/epic-roentgen-094f21/test/support/fake_backend.dart';
import 'file:///D:/Flutter%20Data/Projects/AL%20Mafia/.claude/worktrees/epic-roentgen-094f21/test/support/localized.dart';

const out='D:/Flutter Data/Projects/AL Mafia/.claude/worktrees/mafia-game-design-system-fca2a6/design-system/reel/revision-v3/production/project/assets/video';
Future<void> fonts() async {
  const paths={'Roboto':'assets/fonts/IBMPlexSansArabic-Regular.ttf','IBM Plex Sans Arabic':'assets/fonts/IBMPlexSansArabic-Regular.ttf','Cairo':'assets/fonts/Cairo-Variable.ttf','Aref Ruqaa':'assets/fonts/ArefRuqaa-Bold.ttf','Bebas Neue':'assets/fonts/BebasNeue-Regular.ttf','MaterialIcons':'fonts/MaterialIcons-Regular.otf'};
  for(final e in paths.entries){await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();}
}
Future<void> warm(WidgetTester t) async {
  await t.runAsync(() async {
    for(final e in find.byType(Image).evaluate()){await precacheImage((e.widget as Image).image,e).timeout(const Duration(seconds:2),onTimeout:(){});}
  });
  await t.pump(const Duration(milliseconds:350));
}
Future<void> record(WidgetTester t,String name,int count,{Future<void> Function(int)? action}) async {
  late Process enc; final logs=StringBuffer();
  await t.runAsync(() async {
    enc=await Process.start('ffmpeg',['-v','warning','-y','-f','rawvideo','-pixel_format','rgba','-video_size','780x1688','-framerate','30','-i','pipe:0','-an','-c:v','libx264','-preset','fast','-crf','16','-pix_fmt','yuv420p','-movflags','+faststart','$out/$name.mp4']);
    enc.stderr.transform(const SystemEncoding().decoder).listen(logs.write);
    enc.stdout.drain<void>();
  });
  for(var i=0;i<count;i++){
    if(action!=null) await action(i);
    await t.pump(const Duration(microseconds:33333));
    final b=t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
    final im=b.toImageSync(pixelRatio:2);
    await t.runAsync(() async {
      final bytes=await im.toByteData(format:ui.ImageByteFormat.rawRgba);
      enc.stdin.add(bytes!.buffer.asUint8List());
      await enc.stdin.flush();
    });
    im.dispose();
    if(i%30==0) print('$name frame $i/$count');
  }
  await t.runAsync(() async {await enc.stdin.close(); final code=await enc.exitCode; if(code!=0) throw StateError(logs.toString());});
  expect(t.takeException(),isNull,reason:name);
}
void main(){
  setUp(() {SharedPreferences.setMockInitialValues({});});
  Future<void> surface(WidgetTester t) async {t.view.physicalSize=const Size(780,1688);t.view.devicePixelRatio=2;addTearDown(t.view.reset);await t.runAsync(fonts);}
  for(final row in [('online-discussion','discuss','citizen'),('online-mafia','night','mafia'),('online-doctor','night','doctor'),('online-detective','night','detective'),('online-vote','vote','citizen')]){
    testWidgets(row.$1,(t) async {
      await surface(t);
      final now=DateTime.now().toUtc();
      final backend=FakeBackend(roomId:'demo-room',state:roomState(phase:row.$2,phaseNumber:4,endsAt:now.add(const Duration(minutes:4)),serverNow:now),players:[for(var s=0;s<6;s++) RoomPlayer(userId:'u$s',seat:s,name:['سلمى','كريم','عمر','نور','ليلى','يوسف'][s],alive:true,gender:(s==0||s==4)?'female':'male',cosmetics:SeatCosmetics(frame:s.isEven?'frame_crimson':'frame_moonlit',plate:s.isEven?'plate_ember':'plate_gilded'))],own:OwnSeat(seat:0,role:row.$3));
      final transport=await OnlineTransport.connect(backend:backend,roomId:'demo-room',heartbeatInterval:Duration.zero);
      addTearDown(transport.dispose);
      final container=ProviderContainer(overrides:[gameTransportProvider.overrideWithValue(transport),audioDirectorProvider.overrideWithValue(AudioDirector())]);
      addTearDown(container.dispose);
      container.read(matchControllerProvider.notifier).adoptSnapshot();
      await t.pumpWidget(RepaintBoundary(key:const ValueKey('capture'),child:UncontrolledProviderScope(container:container,child:localizedApp(Scaffold(body:OnlineTableFlow(onExit:(){},onAnalytics:(){},onStepCommitted:(){}))))));
      await warm(t);
      await record(t,row.$1,180,action:(f) async {
        if(f==65 && row.$2!='discuss') {final seat=find.byKey(CouncilBand.seatKey(2));if(seat.evaluate().isNotEmpty) await t.tap(seat);}
        if(f==70 && row.$2=='discuss'){final card=find.text('كارتي');if(card.evaluate().isNotEmpty) await t.tap(card);}
        if(f==105 && row.$2=='vote') await t.tap(find.byKey(OnlineTableFlow.confirmAction));
      });
    },timeout:const Timeout(Duration(minutes:8)));
  }
  testWidgets('story-search',(t) async {
    await surface(t);
    final story=StoryDefinition.decode(File('assets/stories/qahwet_el_moallem.json').readAsStringSync());
    await t.pumpWidget(RepaintBoundary(key:const ValueKey('capture'),child:ProviderScope(child:localizedApp(StoryFlowScreen(story:story,playerCount:1,onExit:(){},onComplete:(_)async{})))));
    await warm(t);
    await record(t,'story-search',240,action:(f) async {
      if(f==35) await t.tap(find.text(story.actions.first.title));
      if(f==110) await t.tap(find.byKey(StoryFlowScreen.accusationButtonKey));
      if(f==155) await t.dragFrom(const Offset(300,650),const Offset(0,-140));
      if(f==200) await t.dragFrom(const Offset(300,550),const Offset(0,80));
    });
  },timeout:const Timeout(Duration(minutes:8)));
}
