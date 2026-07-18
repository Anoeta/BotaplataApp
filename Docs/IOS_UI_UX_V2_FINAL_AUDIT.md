# Botaplata iOS — Audit final UI/UX Premium V2

## Lots UI/UX réalisés
- Design System Premium V2 appliqué aux parcours principaux : onboarding, login, 2FA, dashboard, sessions, détail session, journal, alertes et profil.
- Dernier lot V1 : profil, sécurité locale, appareils autorisés, préférences de notifications, diagnostic léger, à propos et déconnexion.

## Écrans refondus
- Profil : header premium, carte utilisateur, sections sécurité, appareils, notifications, serveur, à propos et déconnexion.
- Appareils autorisés : cartes dédiées, identification de l’iPhone courant, confirmation avant révocation.
- Préférences de notifications : cartes premium avec Toggle SwiftUI natif, état de sauvegarde local et rollback visuel si erreur.
- Diagnostic et À propos : informations pédagogiques non sensibles.

## Design System utilisé
- `PremiumBackground`, `PremiumCard`, `GlassCard` compatible via les cartes premium, `StatusPill`, `IconBadge`, `SeverityBadge` dans le centre d’alertes, `PremiumSecondaryButton`, `PremiumDangerButton`, `PremiumOfflineBanner`, `PremiumErrorState`, `PremiumEmptyState` et `PremiumSkeletonCard`.
- Hiérarchie dark navy / teal, padding homogène, `LazyVStack`, microcopy courte et lisible.

## Éléments Lovable repris
- Header profil premium.
- Carte utilisateur claire.
- Sections lisibles et rassurantes.
- Badges d’état.
- Appareils autorisés sous forme de cartes.
- Réglages simples avec toggles natifs.

## Éléments Lovable exclus
- Modification d’email, mot de passe, photo ou compte.
- Ajout de compte Kraken ou saisie de clé API.
- Réglages stratégie/capital.
- Création, pause, stop ou modification de session.
- Paper trading, Binance, BUY/SELL ou pilotage manuel.

## Données réelles utilisées
- Utilisateur : `AuthenticatedSession.user.displayName` lorsque disponible.
- Appareils : liste `authorizedDevices` du backend mobile V1.
- Device courant : `AuthorizedDevice.isCurrent`.
- Face ID : `BiometricAuthenticating` et `SecurityPreferencesStore` existants.
- Notifications : permission iOS et préférences backend `PushPreferences`.
- Serveur : `AppEnvironment`, bundle version/build et état de configuration.

## Garanties read-only
- L’iPhone affiche uniquement les données du serveur Botaplata.
- Aucune valeur financière n’est simulée par le profil.
- Aucune action de trading n’est exposée.

## Navigation
- Navigation SwiftUI existante conservée.
- Onglet Profil utilise le `NavigationStack` fourni par `RootView`.
- Destinations profil : appareils, préférences, diagnostic et à propos.

## Accessibilité
- Libellés VoiceOver ajoutés pour Face ID, appareils, révocation et déconnexion.
- Les états ne reposent pas uniquement sur la couleur : badges et textes explicites.
- Toggles natifs conservés.
- Boutons danger nommés clairement.
- Dynamic Type respecté via les polices SwiftUI existantes.

## Sécurité
- Aucun token, Authorization header, mot de passe, TOTP, device secret, signature, nonce ou clé Kraken affiché.
- Le refresh token reste géré par le TokenStore/Keychain existant.
- L’access token reste dans `AuthenticationSession` et n’est pas exposé à l’UI.
- Logout et révocation courante conservent la purge existante.

## Offline/cache
- Le profil et les appareils affichent le dernier état connu lorsque possible.
- Les préférences de notifications affichent un message local si la sauvegarde échoue.
- Les écrans utilisent les états premium loading, empty, offline et error.

## Limites backend
- Aucun changement d’email/mot de passe n’est proposé.
- Aucune suppression de compte n’est proposée.
- Aucune suppression locale séparée n’est ajoutée car la purge locale est déjà liée au logout/session revoked.
- L’état 2FA est affiché en lecture seule comme exigence de connexion réelle.

## Tests
- Tests de présentation ajoutés pour initiales, fallback utilisateur, Face ID, permission notifications, préférences, version bundle et absence de libellés sensibles.
- Tests existants conservés pour purge profil, diagnostic sanitizé, chargement appareils et Face ID.

## Checklist manuelle finale
1. Installation propre.
2. Onboarding.
3. Login.
4. 2FA.
5. Dashboard.
6. Alertes.
7. Sessions.
8. Détail session.
9. Journal.
10. Profil.
11. Activer Face ID.
12. Verrouiller/déverrouiller.
13. Ouvrir Appareils.
14. Révoquer un autre appareil.
15. Modifier une préférence notification.
16. Refuser permission notifications iOS.
17. Tester offline avec cache.
18. Tester offline sans cache.
19. Tester session expirée.
20. Tester appareil révoqué.
21. Se déconnecter.
22. Vérifier purge locale.
23. Se reconnecter.
24. Vérifier onboarding non répété.
25. Tester Dynamic Type.
26. Tester VoiceOver.
27. Tester petit iPhone.
28. Tester grand iPhone.
29. Tester mode sombre.
30. Vérifier absence de données fictives.

## Ce que l’app iOS ne fait pas
- Ne contacte pas Kraken.
- Ne stocke pas de clé Kraken.
- Ne crée pas d’ordre.
- Ne modifie pas les sessions.
- Ne modifie pas la stratégie.
- Ne modifie pas le capital.
