# iOS Home/Work ETA widget (WidgetKit)

Dart + `home_widget` already write keys (`eta_home_*`, `eta_work_*`) into the
App Group `group.com.fguniversalempire.fgmaps`.

To finish on a Mac with Xcode:

1. File → New → Target → Widget Extension, product name `EtaWidget`, kind
   `FgmapEtaWidget` (must match `HomeWidgetSink.iosKind`).
2. Enable App Group on Runner **and** the extension.
3. Read SharedPreferences / UserDefaults suite for the keys in
   `EtaWidgetKeys` and render two rows (Home / Work).
4. Tap opens the main app (`fgmaps://eta_widget`).

Until the target exists, Android widgets still work; iOS simply has no widget
to install.
