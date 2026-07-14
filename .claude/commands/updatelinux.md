Build the current app as a Linux desktop release wired to **homebase**, and install it to the stable launcher location so the **CRM+** desktop shortcut runs the latest code. Use when the user says "update the linux app" / "update my desktop app" / "refresh the linux shortcut".

## Why this exists
The Linux desktop shortcut (`~/.local/share/applications/crm-plus.desktop`) launches a **prebuilt release bundle**, not the source — so it does NOT pick up code changes until you rebuild. It also must point at the **live homebase** backend (over Tailscale), not the default `localhost` defines. And the bundle lives at a **stable path off the T7 drive** (`~/Apps/crm-plus/bundle/`) so the shortcut keeps working even when the external drive is unmounted. This command captures all of that so it doesn't have to be re-explained.

## Fixed locations (don't change without updating the .desktop)
- **Install dir:** `~/Apps/crm-plus/bundle/` (executable `first_android_app`)
- **Icon:** `~/.local/share/icons/crm-plus.png` (the square logo, `assets/icon/crm-plus-dark-1024.png`)
- **Shortcut:** `~/.local/share/applications/crm-plus.desktop`

## What to do
1. **Build the Linux release against homebase** (from the project root):
   ```bash
   ~/flutter/bin/flutter build linux --release --dart-define-from-file=dev-defines.homebase.json
   ```
   If `dev-defines.homebase.json` is missing it's gitignored — tell the user to restore it, don't silently fall back to `dev-defines.json` (that's `localhost` and won't reach the live DB).

2. **Verify the live URL got baked in** (guards against a stale/localhost build):
   ```bash
   grep -rao "https://homebase[a-z0-9.-]*\|localhost:8000" build/linux/x64/release/bundle/lib/libapp.so | sort -u
   ```
   Expect `https://homebase.tail7ab4bc.ts.net` and NO `localhost:8000`. If localhost appears, the define file didn't apply — stop and investigate.

3. **Install to the stable location** (mirror the fresh bundle, prune stale files):
   ```bash
   mkdir -p ~/Apps/crm-plus/bundle
   rsync -a --delete build/linux/x64/release/bundle/ ~/Apps/crm-plus/bundle/
   ```

4. **Ensure the icon + shortcut exist** (idempotent — safe to re-run):
   ```bash
   cp assets/icon/crm-plus-dark-1024.png ~/.local/share/icons/crm-plus.png
   update-desktop-database ~/.local/share/applications 2>/dev/null || true
   ```
   If `~/.local/share/applications/crm-plus.desktop` is missing, recreate it (see the block at the bottom). Uses `Icon=` as an **absolute path** — the hicolor theme name doesn't resolve reliably on this machine.

5. **Report** the installed git HEAD (`git log --oneline -1`) and remind the user: the desktop needs **Tailscale up** to reach homebase (same as the phone).

## Notes
- Release build (AOT-compiled) — genuinely reflects production, unlike the debug APK on the phone.
- Installs whatever is checked out (usually `main`). For a specific branch, check it out first.
- Optional smoke test: `(cd ~/Apps/crm-plus/bundle && ./first_android_app & sleep 4; kill %1)` — launches then closes.

## The .desktop file (recreate if missing)
```ini
[Desktop Entry]
Type=Application
Name=CRM+
Comment=Light CRM — learning app (Flutter)
Exec=/home/sasha/Apps/crm-plus/bundle/first_android_app
Path=/home/sasha/Apps/crm-plus/bundle
Icon=/home/sasha/.local/share/icons/crm-plus.png
Terminal=false
Categories=Office;ProjectManagement;
StartupWMClass=first_android_app
```
