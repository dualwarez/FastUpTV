# Contributing

Two ways to help, both useful.

## 1. Add your TV's brand list (best contribution, no coding)

Ten minutes, and the next person with your TV skips the guesswork.

1. Run the setup once so debugging is on:
   ```
   setup.bat
   ```
2. List what your TV has:
   ```powershell
   .\scripts\inspect.ps1
   ```
3. Open `lists\<brand>.txt` (create it if missing) and add one package per line - only things that are
   clearly junk: telemetry, ads, promo rows, preloaded apps nobody opens.
   Put your model and Android version in the header comment.
4. Run `setup.bat`, use the TV for a day. Anything broken? Remove that line and run `restore.bat`.
5. Open a PR with the list file and one line in `docs/BRANDS.md`.

**Hard rules for lists:**

- Never list `com.android.*`, `com.google.android.tv.settings`, the keyboard/IME, the setup wizard,
  or the app that owns *Home*.
- One package per line, `#` for comments.
- Say what you tested on (model, Android version, firmware).

The script refuses the dangerous ones anyway, but a good list should never need that safety net.

## 2. Report a bug

Open an issue with:

- TV brand, model, Android version (`adb shell getprop ro.product.model` and `ro.build.version.release`)
- What you expected vs what happened
- The console output of `setup.bat` (it prints everything it does)
- If a screen looks wrong, a photo of the TV

## Code

- PowerShell 5.1, Windows only, no external modules. Keep it that way - that is the whole point.
- ASCII only in `.ps1` files (Windows PowerShell reads UTF-8 without BOM as ANSI; a stray em dash
  breaks the parser).
- Every destructive action needs a guard and a line in `restore.ps1`.
- Test with `-DryRun` before testing for real.
