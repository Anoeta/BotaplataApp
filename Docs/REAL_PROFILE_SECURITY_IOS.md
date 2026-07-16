# Profil réel, appareils autorisés et sécurité locale iOS

Le profil iOS est alimenté par `AuthenticationSession.user` et par les routes d'appareils déjà exposées dans `AuthenticationSession`. Aucune vue de production ne consomme `PreviewFixtures` pour afficher des données métier de profil.

## Architecture

`ProfileStore` est un store `@MainActor` et `@Observable` injecté depuis `BotaplataApp` avec la même `AuthenticationSession` que `AuthenticationStore`. Il centralise l'utilisateur, les appareils autorisés, la biométrie, la préférence locale, le diagnostic sanitisé, les erreurs, la purge et les opérations single-flight.

## Utilisateur

L'écran principal affiche le `displayName` et un résumé lisible de l'accès. L'identifiant brut, les permissions techniques, les mots de passe, codes TOTP et tokens ne sont pas affichés.

## Appareils et révocation

Les appareils proviennent de `GET /api/mobile/v1/auth/devices` via `AuthenticationSession.authorizedDevices()`. La liste est conservée en mémoire uniquement. L'appareil courant est identifié exclusivement avec `isCurrent`. Les appareils révoqués sont filtrés.

La révocation utilise `AuthenticationSession.revokeDevice(id:)`. Un autre appareil affiche une confirmation de révocation d'accès. L'appareil courant affiche une confirmation plus explicite et purge la session locale lorsque le backend renvoie `currentDeviceRevoked`.

## Auth et refresh

Les appels devices utilisent l'access token courant. En cas de `AUTH_TOKEN_EXPIRED`, `AuthenticationSession` effectue au plus un refresh single-flight puis un replay unique. Un second `AUTH_TOKEN_EXPIRED` purge et expire la session.

## Biométrie et scenePhase

La préférence `biometricLockEnabled` est stockée dans `SecurityPreferencesStore` via UserDefaults. Ce n'est pas un secret. L'activation exige une biométrie disponible puis une authentification réussie. Une annulation, un refus ou une indisponibilité laisse la préférence désactivée.

Le cycle de vie marque un vrai passage en arrière-plan. Au retour au premier plan, le verrouillage local est déclenché uniquement si la biométrie est activée et la session est authentifiée. Les états login, 2FA, révoqué, expiré et déconnecté sont exclus.

## Diagnostic

Le diagnostic expose uniquement version, build, environnement, état d'authentification, backend configuré ou non, et état biométrique. Il n'expose ni access token, ni refresh token, ni installation ID complet, ni device ID complet, ni clés Kraken, ni secret, ni nonce, ni credentials.

## Audit fixtures

Fixtures trouvées avant modification : `ProfileView(profile: PreviewFixtures.profile)` en production dans `RootView`, mocks explicites pour UI tests/démo dans `BotaplataApp`, et fixtures conservées dans previews/tests. Action : le profil de production utilise désormais `ProfileContainerView(store:)`; les fixtures restent autorisées pour previews, XCTest, UI tests et démo debug explicite.

## Validation manuelle

1. Authentification réelle.
2. Ouvrir Profil.
3. Vérifier vrai nom utilisateur.
4. Ouvrir Appareils autorisés.
5. Vérifier cet iPhone.
6. Vérifier les autres appareils.
7. Révoquer un autre appareil test.
8. Vérifier disparition/statut.
9. Activer verrouillage biométrique.
10. Vérifier demande Face ID/Touch ID.
11. Annuler et vérifier préférence inchangée.
12. Réactiver avec succès.
13. Mettre app en background.
14. Revenir foreground.
15. Vérifier lock biométrique.
16. Tester Verrouiller maintenant.
17. Vérifier Diagnostic.
18. Vérifier version/build/environnement.
19. Vérifier absence de secret.
20. Se déconnecter.
21. Vérifier disparition de toutes les données authentifiées.

## Release readiness

Voir `Docs/IOS_V1_RELEASE_READINESS.md` pour la checklist finale V1, TestFlight, réseau distant et sécurité cache/offline.
