# Said

A dictation app for macOS. Hold Fn, speak, let go, and the text is typed wherever your cursor is.

Speech is turned into text on your Mac by [whisper.cpp](https://github.com/ggml-org/whisper.cpp) using the `small.en` model. While you're still talking, Said transcribes in pieces at natural pauses, so a long dictation is ready about a second or two after you let go. If you add an Anthropic API key, Claude Haiku then tidies the text: it takes out filler words and stutters, keeps only what you meant when you correct yourself, and fixes spellings from your word list. You can turn the tidy step off in the menu, and if it fails Said pastes the raw text.

Swift 5, AppKit and AVFoundation. macOS 14 or later.

## Build and run

```bash
./scripts/bundle.sh          # builds whisper.cpp the first time, then build/Said.app
open build/Said.app
```

The first build clones whisper.cpp into `vendor/` and needs CMake. Download a model into `~/Library/Application Support/Said/` (or `~/.local/whisper-models/`):

```bash
curl -L -o ~/Library/Application\ Support/Said/ggml-small.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
```

If `small.en` isn't there, Said falls back to `ggml-base.en.bin`, which is faster but makes more mistakes.

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

Store your key in the Keychain:

```bash
security add-generic-password -s com.arenaapps.said -a anthropic-api-key -w
```

The transcript is sent to the Anthropic API with your word list. Nothing else leaves your Mac.

## Word list

Choose Edit Word List… in the menu. Put one name or term per line. Whisper gets the list as a hint before it listens, and Claude uses it to fix near-misses.

## Files

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
