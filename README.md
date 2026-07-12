# BotaplataApp iOS

BotaplataApp est l'application iOS native SwiftUI de supervision du robot Botaplata. Cette fondation affiche une expérience locale premium avec des fixtures fictives uniquement.

## Principes de sécurité

- Provider principal futur : Kraken Spot Production, via le backend Botaplata uniquement.
- L'app iOS ne contacte jamais Kraken ou Binance directement.
- Aucun secret exchange, token, mot de passe ou TOTP n'est stocké dans ce lot.
- Le backend restera la source de vérité pour sessions, prix, balances, décisions, ordres, frais, break-even, PnL et monitoring.

## Architecture

Sources sous `BotaplataApp/` :

- `App/` : point d'entrée, état global `AppState`, routeur et `RootView`.
- `Core/DesignSystem/` : tokens et composants SwiftUI partagés.
- `Core/Formatting/` : formatage financier sans convertir `nil` en zéro.
- `Domain/` : modèles indépendants des futurs DTO réseau.
- `Features/` : Dashboard, Sessions, Journal, Profil, Authentication placeholder.
- `PreviewSupport/` : fixtures explicitement fictives `BOTAPLATA_PREVIEW_FIXTURE`.

## Design system

Palette sobre : bleu nuit, surfaces calmes, accent turquoise, vert uniquement pour succès, rouge pour danger, orange pour warning. Les composants supportent Dynamic Type, libellés accessibles et évitent les statuts transmis uniquement par la couleur.

## Lancer le projet

Ouvrir `BotaplataApp.xcodeproj` dans Xcode, sélectionner le scheme `BotaplataApp`, puis un simulateur iPhone disponible.

Commandes macOS recommandées :

```bash
xcodebuild -list -project BotaplataApp.xcodeproj
xcodebuild -project BotaplataApp.xcodeproj -scheme BotaplataApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild -project BotaplataApp.xcodeproj -scheme BotaplataApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Adapter le simulateur si `iPhone 16 Pro` n'est pas installé.

## État actuel

Implémenté : navigation racine, TabView Dashboard/Sessions/Journal/Profil, design system initial, modèles domaine, fixtures, cible de tests unitaires.

Non implémenté volontairement : authentification réelle, 2FA, réseau, Mobile API V1, Keychain production, cache persistant, polling, APNs, ordres, achat, vente, TestFlight.
