# Real Session History iOS

Cette PR connecte l'historique read-only des sessions Kraken réelles via quatre routes Mobile API V1 : timeline, orders, decisions et chart. Le téléphone ne contacte jamais Kraken/Binance, ne détient aucun secret exchange et ne crée/annule aucun ordre.

## Architecture

`RealSessionHistoryRepository` expose les quatre chargements. `RemoteRealSessionHistoryRepository` utilise uniquement `APIClientProtocol`, les mocks servent aux previews/tests/démo, et `UnconfiguredRealSessionHistoryRepository` échoue explicitement sans base URL.

`RealSessionHistoryStore` est `@MainActor @Observable`. Il conserve l'état par `sessionID`, une pagination indépendante pour timeline/orders/decisions, le chart sans pagination, du single-flight par ressource/session, une protection par génération contre les réponses obsolètes, un replay auth unique, et une purge logout.

## DTO et mapping

Tous les montants critiques utilisent `DecimalString` puis `Decimal`. Les statuts d'ordres conservent `submitted`, `open`, `partially_filled`, `filled`, `reconciliation_required`, `reconciliation_blocked`, `canceled`, `rejected` et `unknown`. Les PnL `null` restent `nil` et sont affichés comme indisponibles, jamais comme zéro.

## Cache

`FileRealSessionHistoryCache` persiste uniquement la première page de timeline et le chart, avec version de cache, limite simple à cinq sessions et cinquante événements par session. Il ne stocke aucun token, mot de passe, TOTP, clé/secret Kraken, Authorization header ou nonce. Le logout purge Dashboard, Sessions et History.

## UI

Le Journal global sélectionne une session réelle : active d'abord, puis première session backend, puis état vide. Les événements affichent les titres/messages pédagogiques backend, groupés par jour, avec icône, couleur sémantique et texte accessible. Le détail de session ajoute `Activité et historique` vers Journal, Ordres, Décisions et Graphique, chargés paresseusement.

Orders affiche side, type, statut, dates, quantités, prix, montants, frais et PnL indisponible si `nil`. Decisions privilégie `summary_title` et `summary_message`, les blockers/conditions/advice restant dans un disclosure. Chart affiche Swift Charts quand `points` existe. Quand `points` est vide, aucune courbe n'est inventée : une carte explique que la courbe de prix est indisponible, puis les levels et markers backend confirmés sont affichés.

## Auth

Chaque route utilise l'access token courant via `AuthenticationSession.validAccessTokenRefreshingIfNeeded()`. Sur `accessTokenExpired`, un seul `refresh()` puis un seul replay sont tentés. Une deuxième expiration conduit à l'état `expired`; `deviceRevoked` conduit à l'état `revoked` sans refresh inutile.

## Sécurité et sentinelles

Les tests utilisent `ACCESS_TOKEN_SENTINEL`, `REFRESH_TOKEN_SENTINEL`, `PASSWORD_SENTINEL`, `TOTP_SENTINEL`, `KRAKEN_API_KEY_SENTINEL`, `KRAKEN_SECRET_SENTINEL` et `NONCE_SENTINEL` comme valeurs factices à rechercher. Elles ne doivent jamais être persistées en cache, affichées ou loggées.

## Validation manuelle

1. Authentification réelle.
2. Ouvrir Journal.
3. Vérifier sélection de session.
4. Vérifier vraie timeline.
5. Scroll jusqu'à pagination.
6. Ouvrir une session.
7. Ouvrir Journal de la session.
8. Ouvrir Ordres.
9. Vérifier BUY/SELL et statuts.
10. Ouvrir Décisions.
11. Vérifier wording pédagogique.
12. Ouvrir Graphique.
13. Vérifier état sans courbe.
14. Vérifier niveaux fee-aware.
15. Vérifier markers BUY/SELL confirmés.
16. Couper réseau.
17. Vérifier dernier état connu.
18. Reconnecter.
19. Vérifier refresh.
20. Logout.
21. Vérifier purge du contenu authentifié.
