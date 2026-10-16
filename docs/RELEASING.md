# Releasing playtest builds

Builds are published as **GitHub Releases** on the public repo
[Tristan2828/vertical-scroller](https://github.com/Tristan2828/vertical-scroller/releases) and, once the
announced automatically in Discord `#builds`. Copied from Medieval Survival's process.

## Every release

1. Bump `config/version` in `project.godot` (e.g. `0.0.9` -> `0.0.10`). Friends can only play
   together on the same version, so every build you send needs a new number.
2. Optional: write `docs/releases/v<version>.md` with highlights and "what to test".
   It becomes the top of the release notes; the commits since the last release are listed under it.
3. Commit and push `main`.
4. Preview, then publish:
   ```powershell
   pwsh tools/release.ps1 -DryRun   # checks + shows the notes, publishes nothing
   pwsh tools/release.ps1           # builds, creates release v<version> with the zip
   ```
5. About a minute later, the release appears in Discord `#builds`.
6. Players on an older version see "Version X is out!" with an **Update now** button on the
   title screen. It downloads the zip from this release, swaps the running exe and restarts. So keep
   the asset name `VerticalScroller-<version>-windows.zip` with `VerticalScroller.exe` at its root
   (what `build.ps1` makes), and never publish a release with a lower version than the last one.
   **v0.0.9 and older have no updater**: friends download the first release that has one by hand
   (say so in its notes).

`release.ps1` refuses to run unless you are on `main`, have no uncommitted changes, are pushed
to GitHub, and the version's tag doesn't exist yet.

## How it works

- `tools/release.ps1` runs `tools/build.ps1`, then `gh release create v<version>` with the zip.
- `build.ps1` draws the exe icon (`tools/make_icon.gd`), stamps `build_info.cfg` (version, commit,
  date, feedback webhook; git-ignored, inside the exported game only) and exports.
- Publishing a release triggers `.github/workflows/discord-release.yml` (GitHub Actions), which
  posts the notes and download link to the `#builds` webhook. Without the secret it skips with a warning.
- The webhook URL is the repo secret `DISCORD_BUILDS_WEBHOOK`. Only GitHub Actions can read it;
  it is never stored on your PC or in the code.
- Commits use the GitHub noreply email (set in this repo's git config) so your real email stays private.

## One-time setup

- **`#builds` announcements (done 2026-10-15):** in Discord, the channel's gear -> Integrations -> Webhooks -> New Webhook
  -> Copy URL, then run `gh secret set DISCORD_BUILDS_WEBHOOK --repo Tristan2828/vertical-scroller` and
  paste it. To replace a leaked or deleted webhook, make a new one and run the same command.
- **In-game feedback:** the game's "Send feedback" screen (title menu and pause menu) posts to a Discord
  channel. In Discord, `#feedback` gear -> Integrations -> Webhooks -> New Webhook (name it
  "Vertical Scroller feedback") -> Copy URL. Paste the link alone into `feedback_webhook.txt` in the repo
  folder (git-ignored: it is **never** committed). `build.ps1` bakes it into the exported game; without it
  the screen copies messages to the clipboard instead. Anyone determined could dig the link out of the
  exe and post to that one channel: if that ever happens, delete the webhook in Discord, make a new one,
  update the file and release again.
- **No commit feed:** the owner wants only releases in Discord (decided 2026-10-15), so there is no GitHub
  repo webhook for pushes.

## Troubleshooting

- **"Sending isn't set up in this build"** on the feedback screen: `feedback_webhook.txt` was missing or not a
  Discord webhook link when the build was made (build.ps1 prints a note). Fix the file and rebuild.
- **No post in `#builds`:** the repo's **Actions** tab -> "Announce release in Discord" shows each run
  (a yellow warning = the secret isn't set). After fixing, re-send with **Run workflow** and the tag.
- **Wrong release:** delete it on GitHub (Releases -> the release -> Delete) and delete its tag
  (`git push origin :refs/tags/v<version>` then `git tag -d v<version>`), fix, and run the script again.
- **"Windows protected your PC" (SmartScreen):** expected. The exe isn't code-signed and few people have
  downloaded it. Friends can **Unblock** the zip before extracting (right-click > Properties) or click
  **More info -> Run anyway**; the README and every release's notes say so. In-game updates don't get the
  warning. Only code signing removes it (Medieval Survival's `docs/RELEASING.md` has the options).
- **Windows Defender quarantines the exe:** a false positive. Submit it at
  https://www.microsoft.com/en-us/wdsi/filesubmission ("Software developer", "Incorrectly detected as malware").
