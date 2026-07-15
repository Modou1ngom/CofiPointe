#!/usr/bin/env bash
# Build IPA CofiPointe (a lancer sur un Mac avec Xcode + compte Apple Developer).
# Usage: ./scripts/build-ios-ipa.sh
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release

echo ""
echo "IPA: build/ios/ipa/*.ipa"
echo "Ensuite:"
echo "  1. Ouvrir Xcode → Window → Organizer → Distribute App"
echo "  2. Envoyer vers TestFlight (App Store Connect)"
echo "  3. Partager le lien TestFlight / QR App Store Connect"
echo ""
echo "Impossible de sideloader un IPA comme un APK Android sans compte Apple."
