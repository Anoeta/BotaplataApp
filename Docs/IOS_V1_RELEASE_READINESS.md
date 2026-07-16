# Botaplata iOS V1 — Release readiness

## État fonctionnel

La V1 iOS couvre login réel, 2FA, dashboard réel, sessions réelles, journal/historique, profil, appareils autorisés, biométrie locale, notifications push, centre d'alertes, deep links push, cache/offline et logout sécurisé. Le backend Raspberry reste l'unique source de vérité.

## Architecture

L'app iOS utilise des repositories distants injectés avec `APIClientProtocol`. Les mocks sont réservés aux previews, tests UI et démo debug explicite. L'app ne contacte jamais Kraken/Binance directement et ne crée aucune action de trading.

## Environnements

| Environnement | Backend | Mocks | Notes |
|---|---|---|---|
| Development | `BOTAPLATA_API_BASE_URL` si fourni | non par défaut | URL locale autorisée seulement si explicitement configurée |
| TestFlight | `BOTAPLATA_API_BASE_URL` requis | non | aucun fallback IP locale |
| Production | `BOTAPLATA_API_BASE_URL` requis | non | aucun fallback IP locale |
| UI Tests | aucun backend | oui | flag `--botaplata-ui-tests` |
| Previews | aucun backend | oui | `PreviewFixtures` |
| Debug demo | aucun backend | oui | `--botaplata-demo-authenticated` ou `BOTAPLATA_DEBUG_DEMO=1` en DEBUG uniquement |

## Réseau distant

Pour la TestFlight privée, utiliser Tailscale. Une URL HTTPS publique pourra être retenue plus tard après durcissement backend. Ne pas exposer directement le port 31119. Voir `Docs/TESTFLIGHT_NETWORK_SETUP.md`.

## TestFlight

Bundle ID actuel : `fr.ios.BotaplataApp`. Version : `1.0`. Build : `1`. Signing team actuellement présent dans le projet et à valider dans le compte Apple Developer. Push Notifications et background remote-notification sont configurés côté projet/entitlements, mais l'archive réelle doit être validée sur Mac.

## Build

Sur un Mac avec Xcode :

```bash
xcodebuild -list -project BotaplataApp.xcodeproj
xcrun simctl list devices available
xcodebuild build -project BotaplataApp.xcodeproj -scheme BotaplataApp -destination 'platform=iOS Simulator,name=<simulateur disponible>'
xcodebuild test -project BotaplataApp.xcodeproj -scheme BotaplataApp -destination 'platform=iOS Simulator,name=<simulateur disponible>' -only-testing:BotaplataAppTests
xcodebuild archive -project BotaplataApp.xcodeproj -scheme BotaplataApp -configuration Release -archivePath build/BotaplataApp.xcarchive
```

## Notifications

L'app peut demander la permission, enregistrer le device token auprès du backend, charger préférences et alertes, marquer lu/non lu et traiter les deep links. La clé APNs et le provider JWT restent côté backend uniquement.

## Sécurité

Les caches sont read-only et ne contiennent pas de secrets. Les stores utilisent le replay d'access token partagé. Logout, expiration et révocation purgent les caches métier. Le verrouillage local masque les données sans les purger.

## Cache/offline

Voir `Docs/CACHE_AND_OFFLINE_SECURITY.md`. Le mode offline affiche le dernier état connu avec mention explicite ou un état vide/erreur compréhensible sans fixture de secours.

## QA manuelle iPhone réel

### Auth
- Ouvrir l'app.
- Login.
- 2FA.
- Fermer/réouvrir l'app.
- Vérifier refresh token OK.
- Logout.

### Dashboard
- Session active visible.
- Cache immédiat.
- Freshness.
- Monitoring.
- Position.
- Données fee-aware.

### Sessions
- Liste réelle.
- Détail réel.
- Session historique.
- Offline avec cache.

### Journal
- Timeline réelle.
- Orders.
- Decisions.
- Chart sans courbe si série backend absente.
- Markers.
- Levels.

### Profil
- Vrai utilisateur.
- Devices.
- Révocation autre appareil.
- Biométrie.
- Lock background/foreground.
- Diagnostic.

### Notifications
- Permission.
- Registration APNs.
- Preferences.
- Alert center.
- Badge.
- Mark read.
- Deep link.

### Sécurité
- Device revoked.
- Session expired.
- Logout purge.
- Pas de données derrière lock.

### Réseau
- Wi-Fi maison.
- Tailscale.
- Hors Wi-Fi.
- Backend down.

## Limitations connues

- Série de prix backend potentiellement encore indisponible : le graphique peut rester sans courbe réelle.
- PnL net réalisé canonique dépend de l'état backend actuel.
- Tailscale/HTTPS doit être configuré hors code.
- APNs réel dépend de la configuration Apple et backend.
- TestFlight dépend d'un compte Apple Developer.
- `xcodebuild` peut être indisponible dans l'environnement Linux Codex.

## Checklist go/no-go

- `BOTAPLATA_API_BASE_URL` TestFlight configuré.
- Backend joignable depuis l'iPhone hors Wi-Fi via Tailscale ou HTTPS.
- Login/2FA OK.
- Dashboard, Sessions, Journal, Profil, Notifications OK.
- Logout/expired/revoked purgent les données affichées.
- Aucune fixture visible en production normale.
- Build et tests Xcode exécutés sur Mac.
- Archive uploadée dans TestFlight sans secret committé.
