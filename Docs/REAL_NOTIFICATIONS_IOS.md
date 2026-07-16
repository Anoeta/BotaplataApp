# Botaplata iOS — notifications réelles Mobile V1

Cette PR connecte l'app iOS aux notifications Mobile V1 du backend sans appeler Kraken ni Binance depuis l'iPhone.

## Architecture

- `PushNotificationPermissionManager` lit le statut `UNUserNotificationCenter`, demande l'autorisation uniquement après action utilisateur et déclenche `registerForRemoteNotifications()` dans la vraie app.
- `BotaplataAppDelegate` reçoit le device token APNs, le convertit en hex, ne le logge pas et le transmet en mémoire au `PushNotificationsStore`.
- `PushNotificationsStore` centralise permission, registration backend, préférences, centre d'alertes, unread summary, mark-read, deep links, badge, cache, single-flight et purge logout.
- `RemotePushNotificationsRepository` utilise seulement `APIClientProtocol` et les Bearer access tokens fournis par `AuthenticationSession.withAccessTokenReplay`.

## APNs et registration backend

Route utilisée : `POST /api/mobile/v1/push-ios/devices/register` avec `device_token`, `device_name`, `environment`, `app_bundle_id`, `app_version`, `os_version`. Les métadonnées proviennent de `UIDevice`, `Bundle` et `AppEnvironment`. L'environnement est `sandbox` hors production data et `production` pour TestFlight/Production.

Le token APNs n'est pas stocké en cache, pas affiché, pas écrit dans les diagnostics et pas loggé. La désactivation de cet iPhone utilise `DELETE /api/mobile/v1/push-ios/devices/current`; le logout purge seulement les données locales.

## Préférences

Routes utilisées :

- `GET /api/mobile/v1/push-ios/preferences`
- `PATCH /api/mobile/v1/push-ios/preferences`

L'UI affiche des libellés métier : Achat confirmé, Ordre de vente envoyé, Vente confirmée, Vérification prolongée, Surveillance perturbée, Protection critique. Les catégories `mandatory` sont affichées `Toujours actif` sans toggle.

## Centre d'alertes

Routes utilisées :

- `GET /api/mobile/v1/real/notifications?page=1&page_size=50&unread_only=...`
- `GET /api/mobile/v1/real/notifications/summary`
- `POST /api/mobile/v1/real/notifications/{notification_id}/read`
- `POST /api/mobile/v1/real/notifications/read-all`

Les alertes sont groupées par jour, affichent le titre, le message, le symbole, la date relative, un dot non lu et un libellé de sévérité accessible. Le badge de la cloche et le badge app utilisent `unread_count` backend.

## Deep links et verrouillage local

Le payload `botaplata.navigation_target` est décodé en `NotificationNavigationTarget`. Les sections supportées sont `overview`, `journal`, `orders`, `decisions`, `chart`; une section inconnue retombe sur `overview`. Si l'app est `lockedLocally`, la cible reste pending et s'applique après déverrouillage.

## Cache, offline et logout

Le cache versionné contient uniquement la première page d'alertes, le summary unread et les préférences. Il ne contient jamais access token, refresh token, APNs token, Authorization header, mot de passe, TOTP, clé Kraken, JWT APNs, clé Apple ou nonce. En offline avec cache, le dernier état connu reste visible. Au logout, le cache alertes est purgé.

## Foreground notifications

En V1, une notification reçue au foreground rafraîchit le summary et la liste sans bannière custom lourde. Le backend reste responsable du contenu lock-screen court.

## Validation manuelle

1. Authentification réelle.
2. Aller dans Profil > Notifications.
3. Lire l'explication.
4. Activer les notifications.
5. Accepter le prompt iOS.
6. Vérifier registration backend.
7. Ouvrir Alertes depuis Dashboard.
8. Vérifier centre vide ou alertes réelles.
9. Modifier une préférence.
10. Recevoir notification test backend en sandbox/dry-run selon environnement.
11. Tap notification.
12. Vérifier ouverture session/section cible.
13. Mark read.
14. Mark all read.
15. Couper réseau.
16. Vérifier dernier état connu.
17. Logout.
18. Vérifier purge alertes locales.

## Validation Xcode manuelle

Dans Xcode, vérifier la capability Push Notifications, Background Modes > Remote notifications, et l'entitlement `aps-environment`. Aucun `.p8`, certificat ou provisioning profile ne doit être committé.
