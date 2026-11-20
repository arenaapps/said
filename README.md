# Said

A dictation app for macOS. Hold Fn, speak, let go, and the text is typed wherever your cursor is.

Speech is turned into text on your Mac by [whisper.cpp](https://github.com/ggml-org/whisper.cpp) using the `small.en` model. While you're still talking, Said transcribes in pieces at natural pauses, so a long dictation is ready about a second or two after you let go. If you add an Anthropic API key, Claude Haiku then tidies the text: it takes out filler words and stutters, keeps only what you meant when you correct yourself, and fixes spellings from your word list. You can turn the tidy step off in the menu, and if it fails Said pastes the raw text.

Swift 5, AppKit and AVFoundation. macOS 14 or later.

## Install

Download `Said-<version>.zip` from the Releases page, unzip it and drag Said into Applications. It runs on Intel and Apple silicon Macs with macOS 14 or later.

Said isn't signed with a Developer ID, so the first time you open it macOS says it can't check it for malicious software. Click Done, open System Settings › Privacy & Security, scroll down to the message about Said and click Open Anyway, then confirm. You only do this once. If you'd rather not, build it yourself from the source below.

On first launch the Said window opens on its Setup tab, which walks you through the microphone, Input Monitoring and Accessibility permissions, and asks you to set System Settings › Keyboard › "Press 🌐 key to" to Do Nothing, so holding Fn doesn't also open the emoji picker. It downloads the speech model (about 490 MB) at the same time. Once everything is ticked, try a dictation in the box at the bottom.

## Build and run

```bash
./scripts/bundle.sh          # builds whisper.cpp the first time, then build/Said.app for this Mac
open build/Said.app
./scripts/release.sh         # build/Said-<version>.zip that runs on Intel and Apple silicon
```

Building needs Xcode and CMake. The first build clones whisper.cpp into `vendor/`. `bundle.sh` tunes whisper to your own processor; `release.sh` builds a portable copy for each kind of Mac, joins them, and leaves the app unsigned with its debug symbols stripped, so the download carries no names or folder paths.

To sign with your own certificate so macOS keeps the permissions between builds, create `scripts/sign.local` (it's gitignored):

```bash
SAID_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
```

Without it the app is signed ad hoc, and macOS asks for permissions again after each rebuild.

## Permissions

Said asks for three:

- Microphone, to hear you.
- Input Monitoring, to see the Fn key. It only watches for Fn going down and up, and whether another key is pressed while Fn is held (that cancels the dictation). It never records what you type.
- Accessibility, to press ⌘V for you.

## Tidying with Claude

Choose Said… in the menu bar, open the Claude tab and paste an Anthropic API key. It's stored in your Keychain, and tidying stays off until there is one. The transcript is sent to the Anthropic API with your word list. Your audio never leaves your Mac.

## Word list

Choose Edit Word List… in the menu, or Edit… on the General tab of the Said window. Put one name or term per line. Whisper gets the list as a hint before it listens, and Claude uses it to fix near-misses.

## Files

- `~/Library/Application Support/Said/ggml-small.en.bin` is the speech model, downloaded on first launch.
- `~/Library/Application Support/Said/vocabulary.txt` is your word list.
- `~/Library/Application Support/Said/last-recording.wav` is the most recent dictation, replaced each time, so you can test with it.
- `~/Library/Logs/Said/said.log` records the steps and timings. It never contains what you said.

## Testing with a recording

```bash
build/Said.app/Contents/MacOS/Said --file clip.wav [--model ggml-base.en.bin] [--live]
```

The clip has to be 16 kHz mono. `--live` feeds it in at real speed, the way the microphone would, and prints how long the text took after the end.

## Licence

MIT
