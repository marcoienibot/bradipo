# bradipo

<img src="Resources/Sloth.png" alt="bradipo logo" width="240" align="right">

bradipo is a menu-bar break reminder for macOS. A monospaced countdown keeps its place in the bar. Every 20 minutes, a soft green glow frames each display and a sleeping sloth reminds you to take a break. By default, you get three 20-second short breaks, then one 5-minute long break, and the cycle repeats. You can keep typing or clicking elsewhere on the screen. Drag the center of the sloth card to move it. Drag an edge to change its width or height, or a corner to change both. Bradipo remembers its size and position on each display for future breaks. Click the center to end the break early and start a fresh work interval.

At launch, the sloth peeks up from the menu bar for 1.5 seconds before your first work interval starts. With Reduce Motion enabled, the countdown appears immediately.

Click the countdown to pause reminders, start the next short or long break early, or restart the timer. While reminders are paused, the countdown dims behind a pause symbol. The break action shows how many short breaks remain before the next long break. While a short break is next, **Take a Long Break** starts a long break now and begins a new cycle. During a break, **Restart Timer** resets the break to its full length. **Stop short break** or **Stop long break** ends it early and starts a fresh work interval. The banner identifies which kind of break is running. Ending a break early still counts it toward the cycle. Time away keeps your place in the cycle. Relaunching bradipo starts a new cycle with your saved settings.

<br clear="right">

### Settings

Choose **Settings…** in the menu to open the settings window, and pick a section in its sidebar. To find a setting by name, type in the search field above the sections: the sidebar lists the sections and settings that match, with the matching letters highlighted. Choose one with the pointer or the arrow keys to open its section with that setting marked for a moment. Clear the field or press Esc to get the sections back. Changes are saved as you make them and remembered after relaunch. Most apply at once. Changing the work interval restarts the current one, and a break that's already running keeps its length.

- **Rhythm.** Under **Work interval**, **Short break length**, or **Long break length**, choose a preset, or choose **Custom** to type minutes and seconds in the row, up to 99:59. They're saved when you press Return or leave the fields. **Short breaks before a long break** sets how many short breaks come before each long one. Turn off **Long breaks** to take only short breaks; a long break already running still finishes. While it's off, the other long-break settings are greyed out, **Take a Long Break** is hidden in the menu, and the break action doesn't show the remaining count. Turning it on again starts a new cycle.
- **Break Screen.** Turn off **Show the break banner** to use just the border glow during breaks. **Reset on All Displays** restores the banner's original size and bottom-center position on every display. Click the **Accent color** well to change the glow and banner, or **Restore Default Green** to bring back the original colors. Drag the **Border glow intensity** slider to preview the glow on every display until you let go. At 0% the border disappears. Above 50% it spreads farther into the screen. By default, the glow and the banner are left out of screen sharing, recordings, and screenshots, though some capture apps might still show them. The countdown in the menu bar stays visible. Turn on **Show breaks in screen sharing** to include them.
- **Sounds.** Turn on **Play a sound when a break starts** to hear a sound when a break begins, or **Play a sound when a break ends** to hear one when it has run its full length. Both are off by default. Neither plays when you start or stop a break yourself, or when time away ends one.
- **Meetings.** See [Meetings and time away](#meetings-and-time-away).
- **General.** Turn on **Launch at login** to have macOS open bradipo when you sign in. The section also shows the installed version and links to the GitHub commit used to build it. **Check for Updates…** offers to install the latest release from GitHub and relaunch bradipo; bradipo never checks on its own.

### Meetings and time away

- **Defer breaks during meetings**, in the Meetings section of Settings, is on by default. The countdown keeps running during calls and dictation. If a break comes due while another app uses the microphone or camera, the timer holds at zero. The menu and the countdown's tooltip name the app using the microphone, for example **Short break due · Discord is using the mic**, or say **Camera in use**. If the app can't be identified, they say **Mic in use**. The full break starts as soon as the camera is off and only ignored apps, if any, use the microphone. If either device turns on during a break, the reminder stays visible and the break finishes on schedule. Detection uses Core Audio and AVFoundation, so a call with both devices off can go undetected. You can turn this setting off.
- Some apps, such as Discord, OBS, or a dictation tool, can keep the microphone on for hours, so breaks never come. **Ignored apps**, below **Defer breaks during meetings**, lists the apps using the microphone when you open the section. Turn one on to ignore it. Ignored apps stay listed, turned on, even when they aren't running. Turn one off to stop ignoring it. While **Defer breaks during meetings** is off, **Ignored apps** is greyed out. Ignoring an app only covers the microphone: macOS doesn't tell other apps which app uses the camera, so an ignored app with the camera on still holds breaks. Apps that record through a helper, such as Discord or Chrome, are listed under the app's name. Some record through a shared macOS service instead, such as Safari through `com.apple.WebKit.GPU`. Ignoring that service ignores every app that records through it.
- The countdown keeps running when you aren't typing or moving the pointer, for example while you read or watch a video.
- Locking the screen, putting the Mac or its display to sleep, or switching user sessions starts a fresh interval when you return, as does the screen saver, which macOS can start while you read.

### Install

bradipo requires macOS 27.2.1 or later. To install the latest release, run this in Terminal:

```sh
curl -fL https://github.com/marcoieni/bradipo/releases/latest/download/bradipo.tar.gz -o "$TMPDIR/bradipo.tar.gz" &&
  rm -rf /Applications/bradipo.app &&
  tar -xzf "$TMPDIR/bradipo.tar.gz" -C /Applications
```

Then open bradipo from Applications. To update, choose **Check for Updates…** in the General section of Settings, or quit bradipo and run the command again.

Releases aren't notarized by Apple, so macOS blocks copies downloaded with a browser until you allow them. Files downloaded with `curl` or **Check for Updates…** aren't quarantined, so macOS skips that check. Install and update this way only if you trust this repository.

#### Install with Homebrew

If bradipo is already in Applications and you installed it without Homebrew, quit it and move it to the Trash first. You keep your settings, though you might need to turn Launch at login back on. Then run:

```sh
brew install --cask marcoieni/tap/bradipo
```

The cask removes the quarantine that Homebrew adds, so macOS skips its check, as it does with the Terminal command. Install it only if you trust this repository and [the tap](https://github.com/marcoieni/homebrew-tap).

To update, run `brew upgrade --cask marcoieni/tap/bradipo`. With the short name, Homebrew can take a day to notice a new release. To uninstall, run `brew uninstall --cask bradipo`, or add `--zap` to delete your settings too.

#### Install from the disk image

Download `bradipo-<version>.dmg` from the [latest release](https://github.com/marcoieni/bradipo/releases/latest), open it, and drag bradipo into Applications.

macOS blocks bradipo the first time you open each newly downloaded version. In the warning, click **Done**, not **Move to Trash**. Then open **System Settings > Privacy & Security**, click **Open Anyway** next to the message about bradipo, and confirm. If macOS instead reports that bradipo is damaged and you downloaded it from this repository's [Releases](https://github.com/marcoieni/bradipo/releases) page, remove the download quarantine in Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/bradipo.app
```

If your copy came from anywhere else, move it to the Trash and download it again from the Releases page. If you update from a new disk image, allow that version the same way. Versions installed with **Check for Updates…** don't need this step.

### Build and run

Requires macOS 27.2.1 or later and Swift 6.4 from Xcode or the Command Line Tools. The app uses Apple frameworks and builds without downloading any packages.

```sh
./scripts/build-app.sh
open .build/bradipo.app
```

To install it, drag the built `bradipo.app` into Applications.

### Test

Run `swift test` with Xcode selected. With the standalone Command Line Tools, supply the bundled Swift Testing plug-in path.

```sh
swift test -Xswiftc -plugin-path -Xswiftc "$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
```

### Release

Push a tag of the form `vMAJOR.MINOR.PATCH`:

```sh
git tag v0.2.0
git push origin v0.2.0
```

The release workflow runs the tests, builds bradipo with the tag's version, and publishes `bradipo-0.2.0.dmg` and `bradipo.tar.gz` on a GitHub release for the tag. The archive is for the Terminal command in [Install](#install) and **Check for Updates…**, so its name stays the same in every release. You don't need to edit `Resources/Info.plist`; its version only applies to local builds. To package a local build the same way, run `./scripts/build-app.sh 0.2.0`, then `./scripts/package-dmg.sh` and `./scripts/package-tarball.sh`.

The cask lives in [marcoieni/homebrew-tap](https://github.com/marcoieni/homebrew-tap). After publishing, the **Update the Homebrew cask** job commits the new version and the checksum of the disk image there. It pushes with the `HOMEBREW_TAP_DEPLOY_KEY` secret, the private half of a deploy key with write access to the tap. If that job fails, re-run only the failed job.

Releases are signed ad hoc and not notarized, which is why users of the disk image need the Gatekeeper step in [Install from the disk image](#install-from-the-disk-image). Notarizing requires a paid Apple Developer ID.
