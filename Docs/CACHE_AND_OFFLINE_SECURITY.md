# Cache et sécurité offline iOS

## Caches identifiés

| Domaine | Implémentation | Emplacement | Contenu | Purge |
|---|---|---|---|---|
| Dashboard | `FileActiveSessionCache` | Application Support | snapshot consolidé read-only | logout, session expirée, appareil révoqué |
| Sessions | `FileRealSessionsCache` | Application Support | liste de sessions et pagination | logout, session expirée, appareil révoqué |
| History / Journal | `FileRealSessionHistoryCache` | Application Support | première page timeline et chart par session | logout, session expirée, appareil révoqué |
| Push Notifications | `FilePushNotificationsCache` | Application Support | alertes, summary unread, préférences | logout, session expirée, appareil révoqué |
| Profile memory | `ProfileStore` | mémoire process | utilisateur, appareils, diagnostic non secret | purge mémoire logout/expired/revoked |
| Security preferences | `UserDefaultsSecurityPreferencesStore` | UserDefaults | préférence biométrie locale | pas un secret, conservé après logout |

## Données interdites en cache

Les caches ne doivent pas stocker de password, code 2FA, access token, refresh token, APNs token, Authorization header, clé Apple, clé exchange, secret exchange ou nonce. Les tokens d'authentification restent dans le Keychain via `KeychainTokenStore`.

## Comportements attendus

- Logout : purge Dashboard, Sessions, History, Push et profil mémoire.
- Device revoked : même purge que logout, puis écran révoqué.
- Session expired : même purge que logout, puis écran expiré.
- Locked locally : ne purge pas les caches, mais masque les données derrière l'écran biométrique.
- Corruption cache : les chargeurs retournent nil/état vide et l'app recharge depuis le backend sans écran blanc.

## Offline / réseau instable

Avec cache valide, l'app peut afficher le dernier état connu avec microcopy explicite. Sans cache, elle affiche une erreur compréhensible. Elle ne bascule jamais vers une fixture métier en production normale.
