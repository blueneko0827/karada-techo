#!/usr/bin/env bash
# Same steps as setup.ps1, for macOS / Linux / GitHub Actions. Needs Flutter 3.32+.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --org jp.kaitosoft --project-name karada_techo --platforms android,ios .

G=android/app/build.gradle.kts
if [ ! -f "$G" ]; then
  echo "android/app/build.gradle.kts not found - Flutter 3.32 or newer is required." >&2
  exit 1
fi

cp platform_setup/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
mkdir -p android/app/src/main/res/drawable android/app/src/main/res/raw
cp platform_setup/android/res/drawable/ic_stat_notify.xml android/app/src/main/res/drawable/
cp platform_setup/android/res/raw/keep.xml android/app/src/main/res/raw/
cp platform_setup/android/MainActivity.kt android/app/src/main/kotlin/jp/kaitosoft/karada_techo/MainActivity.kt

sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = 26/' "$G"
if ! grep -q isCoreLibraryDesugaringEnabled "$G"; then
  sed -i.bak 's/compileOptions {/compileOptions {\n        isCoreLibraryDesugaringEnabled = true/' "$G"
fi
if ! grep -q desugar_jdk_libs "$G"; then
  printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$G"
fi
rm -f "$G.bak"

flutter pub get
dart run flutter_launcher_icons
echo "Android setup done."
