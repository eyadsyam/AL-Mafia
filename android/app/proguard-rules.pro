# R8 full mode (the AGP 9 default) no longer keeps a class's no-arg
# constructor just because a `-keep class` rule names the class.
#
# Google Mobile Ads pulls in WorkManager 2.7.0 and Room 2.2.5. Their bundled
# consumer rules predate full mode: they keep `* extends RoomDatabase` and
# `* extends InputMerger` by name only. Room creates `WorkDatabase_Impl`, and
# WorkManager creates its input mergers, by reflection through `<init>()`, so
# R8 strips the only constructor either is ever called with. The release build
# then dies in `androidx.startup.InitializationProvider` before Flutter starts
# ("Failed to create an instance of androidx.work.impl.WorkDatabase"), on every
# device, on first launch.
#
# `tool/check_android_r8.py` fails the build scripts if these go missing again.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.InputMerger { public <init>(); }
-keep public class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
