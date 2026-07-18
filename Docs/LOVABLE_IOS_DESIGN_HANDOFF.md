# Lovable → Botaplata iOS Design Handoff

Source visuelle : Trading Buddy, projet Lovable `https://lovable.dev/projects/576a0038-f362-4afc-8a2c-66cf08be29f0`.

> Principe directeur : **Design repris, logique métier non reprise**. Botaplata iOS reste une application SwiftUI native connectée au backend réel Kraken, en lecture et pilotage selon l'architecture existante. Lovable sert uniquement de laboratoire visuel.

## Palette traduite

| Lovable | Hex | SwiftUI Botaplata V2 |
| --- | --- | --- |
| Navy profond | `#003781` | `backgroundNavy` |
| Teal | `#00998D` | `primaryTeal` |
| Mint | `#5FCD8A` | `primaryMint`, `success` |
| Cyan | `#13A0D3` | `accentCyan` |
| Magenta | `#A6276F` | `accentMagenta` |
| Red | `#F62459` | `danger` |
| Orange | `#F86200` | base de gradient warning |
| Yellow | `#FAB600` | `warning` |
| Graphite | `#414141` | `graphite` |
| White | `#FFFFFF` | `textPrimary` |

Compatibilité conservée : `background`, `card`, `success`, `warning`, `danger`, `accent`, `surface`, `elevated` restent disponibles pour les écrans existants.

## Gradients

- `appBackground` : fond sombre navy avec profondeur non animée.
- `cardHero` : carte principale bleu/teal.
- `cardTeal` : succès ou état opérationnel.
- `cardDanger` : erreur ou critique.
- `cardWarning` : attention et dernier état connu.
- `buttonPrimary` : CTA mint/teal.
- `tabBar` : helper pour tab bar glass native.

## Composants SwiftUI V2

- Background : `PremiumBackground`.
- Cards : `PremiumCard`, `GlassCard`, `MetricCard`.
- Badges/pills : `StatusPill`, `FilterPill`, `LiveBadge`, `SeverityBadge`, `IconBadge`, `ProviderBadge`, `FreshnessBadge`.
- Buttons : `PremiumPrimaryButton`, `PremiumSecondaryButton`, `PremiumDangerButton`, `IconTextButton`.
- États : `PremiumEmptyState`, `PremiumOfflineBanner`, `PremiumErrorState`, `PremiumLoadingState`, `PremiumSkeletonCard`.
- Typographie : `BotaplataTypography` avec titres larges, titres écran, titres cartes, valeurs monospaced digit, body et caption.
- Iconographie : `BotaplataSymbol` basé sur SF Symbols.

## Écrans de référence Lovable

- Onboarding : ambiance illustrée, à traiter dans un lot suivant sans importer les screenshots en production.
- Login : carte premium et CTA mint/teal, à traiter dans un lot dédié.
- Dashboard : hero card et métriques visuelles, à traiter ensuite avec données réelles uniquement.
- Sessions : cartes et pills de filtre, à traiter sans ajouter d'action de trading.
- Alertes : sévérités Attention/Critique plus visibles.
- Profil : settings premium, sécurité, biométrie et appareils.

## Ce qu'on reprend

- Dark navy premium.
- Gradients bleu/teal/mint mesurés.
- Glassmorphism léger et performant.
- Gros titres blancs lisibles.
- Badges LIVE, Attention, Critique.
- Pills de filtre.
- États transverses premium.
- Tab bar native teintée teal avec apparence glass.

## Ce qu'on ne reprend pas

- Binance comme source fonctionnelle ou nouvelle intégration.
- Paper trading, simulation, wishlist, objectifs.
- Boutons BUY/SELL ou actions qui suggèrent un trading manuel depuis l'iPhone.
- Start/pause/stop/delete/création de session dans ce lot UI.
- WebView Lovable.
- Données fictives en production.
- Screenshots Lovable importés massivement dans le bundle.

## Assets

Assets Lovable utiles à considérer plus tard :

- `botaplata-icon-1024.png` : éventuel polish AppIcon.
- `botaplata-icon-money-1024.png` : illustration onboarding si validée.
- `botaplata-screen-onboarding.png` : référence de composition uniquement.
- `botaplata-screen-login.png` : référence login.
- `botaplata-screen-dashboard.png` : référence dashboard.
- `botaplata-screen-sessions.png` : référence sessions.
- `botaplata-screen-alerts.png` : référence alertes.
- `botaplata-screen-profil.png` : référence profil/settings.

Aucun asset lourd n'est importé dans cette PR afin de préserver la taille du bundle.

## Mapping Lovable → SwiftUI

| Lovable | SwiftUI natif |
| --- | --- |
| Fond navy/halo | `PremiumBackground` + `BotaplataGradients.appBackground` |
| Cartes glass | `PremiumCard` / `GlassCard` |
| Cards métriques | `MetricCard` |
| Badges LIVE/Attention/Critique | `LiveBadge` / `SeverityBadge` |
| Pills filtres | `FilterPill` |
| CTA mint/teal | `PremiumPrimaryButton` |
| Boutons contour | `PremiumSecondaryButton` |
| Danger maîtrisé | `PremiumDangerButton` |
| Empty/offline/loading | `PremiumEmptyState`, `PremiumOfflineBanner`, `PremiumLoadingState` |
| Tab bar flottante | apparence native via `BotaplataTheme.applyTabBarAppearance()` |

## Accessibilité et performance

- Typographie basée sur `Font` système pour Dynamic Type.
- Valeurs financières en `monospacedDigit`.
- Badges avec icône + libellé : l'information ne dépend pas uniquement de la couleur.
- Labels VoiceOver explicites pour LIVE, sévérités, fournisseurs et skeleton.
- Pas de gradients animés lourds.
- Blur limité au décor du background, pas appliqué massivement dans les listes.
- Ombres douces et composants simples, compatibles iPhone réel.

## Limites et prochains lots UI/UX

1. Refonte onboarding/login avec illustration validée.
2. Refonte dashboard réel Kraken avec hero card et métriques.
3. Refonte sessions et détail session en cartes premium.
4. Refonte journal/alertes avec timeline et badges V2.
5. Polish profil/settings, appareils, biométrie et notifications.
