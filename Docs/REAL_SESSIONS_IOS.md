# Real Sessions iOS

## Architecture
L'onglet Sessions utilise `RealSessionsStore`, injecté depuis `BotaplataApp`, avec `RemoteRealSessionsRepository` en application normale, `MockRealSessionsRepository` uniquement en previews/UI tests/démo explicite, et `UnconfiguredRealSessionsRepository` sans base URL.

## Routes
- `GET /api/mobile/v1/real/sessions?page=1&page_size=25`
- `GET /api/mobile/v1/real/sessions/{session_id}`

Les appels passent par `APIClientProtocol` et utilisent exclusivement l'access token courant comme Bearer.

## DTO et mapping
Les DTO réutilisent `DecimalString`, `RealMonitoringDTO`, `RealFreshnessDTO`, `RealMarketDTO`, `RealDecisionDTO`, `RealPositionDTO`, `RealOrderDTO`, `RealReconciliationDTO` et `RealFeeAwareDTO`. Les types spécifiques de liste/détail sont dans `RealSessionsDTO.swift`.

Le mapping réutilise les enums domaine existantes pour lifecycle, monitoring, freshness, orders et fee-aware. Les décimaux invalides échouent au décodage; `null` reste `nil` et n'est jamais transformé en zéro.

## Store
`RealSessionsStore` gère liste, refresh, pagination, détails mémoire, single-flight, déduplication d'IDs, stale protection par génération, replay auth unique, erreurs et purge.

## Pagination
Le chargement initial utilise page 1 et `page_size=25`. `loadNextPageIfNeeded` charge la page suivante si `has_more=true`, évite les appels concurrents, déduplique les IDs et conserve les pages visibles en cas d'erreur.

## Cache
`FileRealSessionsCache` écrit un fichier JSON versionné `botaplata-real-sessions-cache-v1.json` dans Application Support. Il contient uniquement les summaries, la pagination et la date de sauvegarde. Aucun token, mot de passe, TOTP, clé Kraken, secret ou nonce n'est stocké. Le cache est purgé au logout.

## Auth replay
Une requête utilise `AuthenticationSession.validAccessTokenRefreshingIfNeeded()`. Si le backend retourne `AUTH_TOKEN_EXPIRED`, le store effectue un seul refresh puis un seul replay. Une seconde expiration passe l'app en état expiré. `AUTH_DEVICE_REVOKED` passe l'app en état révoqué sans refresh inutile.

## Offline
Avec cache ou contenu visible, l'UI conserve les sessions et affiche un message de connexion momentanément indisponible. Sans cache, elle affiche un état de retry pédagogique.

## Sécurité
L'app iOS ne contacte pas Kraken/Binance directement, ne possède aucune clé exchange, ne signe aucune requête exchange, ne gère aucun nonce et n'envoie aucun ordre. Les routes Sessions sont strictement read-only.

## Procédure de test manuel
1. Lancer backend Botaplata.
2. Authentification réelle iOS.
3. Ouvrir onglet Sessions.
4. Vérifier vraie session active Kraken.
5. Vérifier sessions historiques.
6. Ouvrir une session.
7. Vérifier lifecycle.
8. Vérifier monitoring.
9. Vérifier fraîcheur.
10. Vérifier prix.
11. Vérifier position.
12. Vérifier fee-aware.
13. Revenir à la liste.
14. Pull-to-refresh.
15. Couper le réseau.
16. Vérifier dernier état connu.
17. Rétablir le réseau.
18. Vérifier refresh.
19. Logout.
20. Vérifier purge du contenu authentifié.
