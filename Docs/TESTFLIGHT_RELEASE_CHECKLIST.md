# Checklist TestFlight Botaplata iOS

## Prérequis Apple Developer

- Compte Apple Developer actif.
- Bundle ID `fr.ios.BotaplataApp` enregistré.
- Capability Push Notifications activée pour le Bundle ID.
- Background Modes > Remote notifications cohérent avec le projet.
- Certificats/profils gérés par Xcode ou CI, sans commit de provisioning profile ni certificat.
- Clé APNs `.p8` et secrets App Store Connect conservés hors dépôt. La clé APNs est côté backend uniquement.

## Configuration app

- Display name généré par Xcode si nécessaire.
- Version marketing : `1.0`.
- Build number actuel : `1`.
- Entitlement push : `aps-environment` présent. Adapter `development`/`production` via la configuration Apple/Xcode au moment de l'archive.
- `BOTAPLATA_NETWORK_ENVIRONMENT + environment-specific base URL=<À_CONFIGURER>` défini pour TestFlight.

## Archive et upload

```bash
xcodebuild -list -project BotaplataApp.xcodeproj
xcrun simctl list devices available
xcodebuild build -project BotaplataApp.xcodeproj -scheme BotaplataApp -destination 'platform=iOS Simulator,name=<simulateur disponible>'
xcodebuild test -project BotaplataApp.xcodeproj -scheme BotaplataApp -destination 'platform=iOS Simulator,name=<simulateur disponible>' -only-testing:BotaplataAppTests
xcodebuild archive -project BotaplataApp.xcodeproj -scheme BotaplataApp -configuration Release -archivePath build/BotaplataApp.xcarchive
```

Uploader ensuite l'archive via Xcode Organizer ou `xcrun altool`/Transporter selon la configuration Apple disponible.

## Tests internes

- Installer via TestFlight interne.
- Vérifier login, 2FA, dashboard, sessions, journal, profil, biométrie, notifications et logout.
- Vérifier hors Wi-Fi avec Tailscale.

## Tests externes si nécessaire

Préparer la revue Beta App Review, les coordonnées de support, la description des données affichées et les instructions réseau privées si les testeurs doivent rejoindre le tailnet.
