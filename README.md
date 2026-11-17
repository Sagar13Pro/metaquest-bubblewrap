# metaquest-bubblewrap

Turn a hosted WebXR site into an immersive Meta Quest APK with Meta's
Bubblewrap CLI, in two scripts.

The APK is a thin wrapper (a Trusted Web Activity). It opens your site in
immersive mode using the Quest Browser engine, so the app stays in sync with
whatever the site serves.

## Scripts

| Script | What it does |
|---|---|
| `setup_bw.sh` | One-time setup of the build machine: installs the Bubblewrap CLI, then installs JDK 17 and the Android command-line tools and records their paths in `~/.bubblewrap/config.json`. Finishes by running `bubblewrap doctor`. |
| `apk.sh` | Builds the APK: checks the site's web manifest, runs `bubblewrap init --metaquest` and `bubblewrap build`, reads the signing fingerprint, writes `assetlinks.json` and prints the APK's SHA-256 hash. |

## Requirements

- Linux x64 (the JDK and Android tools downloaded are the Linux builds)
- Node.js 18 or later, with npm
- `curl`, `unzip`, `python3`
- A WebXR site served over HTTPS with:
  - `/manifest.webmanifest` reachable, with 192 px and 512 px icons
  - a way to serve `/.well-known/assetlinks.json` (see step 3)
- For installing: `adb` and a Quest headset with developer mode on

## Quick start

```bash
git clone <this-repo-url>
cd metaquest-bubblewrap
```

### 1. Set up the build machine (once)

```bash
bash setup_bw.sh
```

- If `bubblewrap` is not found, it offers to install Meta's CLI
  (`@meta-quest/bubblewrap-cli`) globally with npm.
- If `jdkPath` or `androidSdkPath` is empty in `~/.bubblewrap/config.json`,
  it downloads them itself:
  - JDK 17.0.11+9 (Temurin) to `~/.bubblewrap/jdk`
  - Android command-line tools to `~/.bubblewrap/android_sdk`

  It does this because Bubblewrap's built-in installer can exit silently while
  decompressing, leaving the paths empty.
- It passes when `bubblewrap doctor` succeeds.

> Make sure the CLI is Meta's `@meta-quest/bubblewrap-cli`, not Google's
> `@bubblewrap/cli`. Only Meta's package supports `--metaquest`.

### 2. Build the APK

```bash
bash apk.sh
```

It asks for two things:

| Prompt | Default |
|---|---|
| Folder path for the wrapper project | `apk` |
| Project URL | the URL set in `PROJECT_URL` at the top of the script |

Then it:

1. Checks that `<url>/manifest.webmanifest` returns HTTP 200.
2. Runs `bubblewrap init --manifest=<url>/manifest.webmanifest --metaquest`.
   Accept the values read from the manifest. When asked, create a new signing
   key and **write the passwords down**.
3. Shows the Quest settings from `twa-manifest.json`. You should see
   `"isMetaQuest": true` and `"horizonOSAppMode": "immersive"`.
4. Runs `bubblewrap build`, which writes `app-release-signed.apk`.
5. Reads the package ID and the key's SHA-256 fingerprint and writes
   `.well-known/assetlinks.json` in the wrapper folder.
6. Checks whether the site already serves `assetlinks.json`.
7. Prints the APK's SHA-256 hash, which some device-management tools ask for
   when you upload an APK.

> Meta's guide also asks for two Gradle edits before building:
> `targetSdk 32` in `app/build.gradle`, and `mavenCentral()` instead of
> `jcenter()` in `build.gradle`. Make them if `bubblewrap build` fails.

### 3. Publish the asset links file (required)

The Quest Browser will not open the app in immersive mode unless the site
vouches for it. Copy the generated file into your site so it is served at:

```
https://<your-site>/.well-known/assetlinks.json
```

For most web projects that means `public/.well-known/assetlinks.json`. If the
file already has entries, add the new one to the list instead of replacing it.

Check it:

```bash
curl -s https://<your-site>/.well-known/assetlinks.json | python3 -m json.tool
```

### 4. Install on a headset

```bash
adb devices
```

```bash
adb install -r app-release-signed.apk
```

The app appears in the Library under **Unknown Sources**. Sideloaded apps show
a text row, not tile artwork.

To remove it:

```bash
adb uninstall <package-id>
```

## Updating the app

Content changes on the site need no rebuild: the APK always loads the live
site. Rebuild only when the manifest, icons, app name or host change:

```bash
cd <wrapper-folder>
bubblewrap update
bubblewrap build
```

An update must be signed with the **same keystore**. Back up
`android.keystore` and its passwords and keep them private. Never commit them.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Black screen, then back to the Library | The asset links check failed | Step 3, then uninstall and reinstall the app |
| Bubblewrap keeps asking to install the JDK | Empty paths in `~/.bubblewrap/config.json` | Run `setup_bw.sh` again |
| `--metaquest` is not recognised | Google's `@bubblewrap/cli` is installed | Uninstall it and install `@meta-quest/bubblewrap-cli` |
| App not visible in the Library | Sideloaded apps are filtered | Choose Unknown Sources, or search by name |
| Worked before, black screen now | The site's host changed (for example a new tunnel address) | Rebuild with the new URL and publish `assetlinks.json` on the new host |

To confirm an asset links failure, watch the headset log:

```bash
adb logcat -d | grep -E "TWA verification|TwaLauncher"
```

It prints `TWA verification was unsuccessful!` when the check fails.

## Do not commit

Add these to `.gitignore`:

```
*.keystore
*.jks
*.apk
*.aab
apk/
```

## References

- [Meta: Bubblewrap for Meta Quest](https://developers.meta.com/horizon/documentation/web/pwa-packaging/)
- [Bubblewrap CLI (Meta fork)](https://www.npmjs.com/package/@meta-quest/bubblewrap-cli)
- [Digital Asset Links](https://developers.google.com/digital-asset-links/v1/getting-started)

## License

MIT. See [LICENSE](LICENSE).
