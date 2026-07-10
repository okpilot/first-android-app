Build the current app and install it on the physical phone (the S23+), which runs against **homebase** over Tailscale. Use when the user says "update the app on my phone" / "push to my phone".

## Why this exists
"Update my phone" means: build a debug APK wired to the homebase backend and install it to the *physical* device — never the emulator, which can't reach the tailnet (emulator uses `dev-defines.android.json` + `adb reverse` instead). This command captures that so it doesn't have to be re-explained each time.

## What to do
1. **Find the physical device.** Run `source ~/.android-env 2>/dev/null; adb devices`.
   - Physical device = a serial that does **not** start with `emulator-` (the S23+ has been `R5CW71HWXKK`).
   - **No physical device** → tell the user to plug in the phone / enable USB debugging and stop.
   - **More than one** physical device → ask which, don't guess.
   - Capture the serial as `$DEV` and use `adb -s $DEV …` for every adb call so the emulator is never touched.

2. **Build the debug APK against homebase:**
   ```bash
   ~/flutter/bin/flutter build apk --debug --dart-define-from-file=dev-defines.homebase.json
   ```
   (Still an unsigned debug build — a signed release is tracked in issue #12. If `dev-defines.homebase.json` is missing it's gitignored; tell the user to restore it, don't fall back to another config silently.)

3. **Install + launch on the physical device:**
   ```bash
   adb -s $DEV install -r build/app/outputs/flutter-apk/app-debug.apk
   adb -s $DEV shell am start -n com.example.first_android_app/.MainActivity
   ```

4. **Report** the git HEAD (`git log --oneline -1`) that was installed, and remind the user the phone needs the **Tailscale app connected** to reach homebase.

## Notes
- Optional sanity check before building: `adb -s $DEV shell dumpsys package com.example.first_android_app | grep -E "versionName|lastUpdateTime"` to see what's currently installed.
- This installs whatever is checked out (usually `main`). If they want a specific branch, check it out first.
