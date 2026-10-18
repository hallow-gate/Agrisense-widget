# AgriSense Widget (Flutter, Android)

One-screen app + resizable home / lock screen widget showing live **temperature, humidity, soil moisture** and **device online / offline**.
Button on the screen opens the AgriSense Dashboard (https://agrisense-1-0.onrender.com/).

## Build (3 steps)

This folder is an *overlay*: you generate the standard Flutter project shell first, then copy this folder over it.

```bash
flutter create --org com.agrisense --project-name agrisense_widget agrisense_widget_app
# copy EVERYTHING from this folder into agrisense_widget_app/ and choose "overwrite"
cd agrisense_widget_app
flutter pub get
flutter run            # or: flutter build apk --release
```

The `--org` and `--project-name` values matter: they make the Android namespace `com.agrisense.agrisense_widget`, which the Kotlin files use.

## Build in GitHub (no local Flutter needed)
Push this folder as a repo (files at the repo root). The workflow `.github/workflows/build-apk.yml` generates the Flutter shell, applies the overlay and builds a release APK.
- Run it from the **Actions** tab (Run workflow) or just push to `main`.
- Download the APK from the run's **Artifacts** (`AgriSense-Widget-apk`).
- Push a tag like `v1.0.0` to also attach the APK to a GitHub Release.

## Using it
1. Open the app, sign in once (same account as the dashboard; the Cloudflare check runs inside the app).
2. Tap **Add widget** (or long-press home screen -> Widgets -> AgriSense).
3. Resize the widget freely. Layouts switch automatically: mini, strip, wide, large, stack.
4. **Live updates** (on by default): refreshes every ~8 s while the screen is on, with a silent notification. Turn it off to save battery; the widget then refreshes on tap and about every 30 min.

## Notes
- Lock screen: the widget is declared for `home_screen|keyguard`. Android only shows lock screen widgets on devices/versions that support them (e.g. Android 14+ tablets, some Samsung / Pixel releases).
- The app uses the same `/api/status` endpoint as the web dashboard, via the dashboard host, so no extra server URL is needed.
- Session tokens are kept in the app's private storage (backup disabled) so the widget can refresh them in the background.
- Render's free tier sleeps; the first refresh after a long idle can take up to ~50 s.
- iOS is not included (it needs a WidgetKit extension built in Xcode).
