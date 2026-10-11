# Botaplata iOS — Midnight Premium V3

## Références et audit

Base : `main` iOS `b7fd5f5`, après fusion de la PR #50 (V2). Backend consulté en lecture seule : `origin/main` `0c479fe`, intégrant les PR #169 à #173. Le diff de `app/mobile_api` entre #169 et #173 est vide : cette refonte ne dépend pas du déploiement de ces évolutions backend. Aucun accès au Raspberry, aux sessions réelles ou aux données SQLite n’a été effectué.

Référence demandée : [projet Lovable Botaplata Lab](https://lovable.dev/projects/a2dcd76f-27d0-4923-928d-2184c20e9673). La tentative d’accès a échoué au niveau du proxy cloud (`CONNECT 403`). Les sept captures mentionnées dans le cahier des charges ne sont pas présentes dans les pièces jointes disponibles ; seules les demandes textuelles V2/V3 sont disponibles. **Aucune comparaison pixel à pixel avec ces captures ni consultation du CSS/OKLCH n’est revendiquée.** L’implémentation suit les HEX sRGB, la structure et les règles ergonomiques explicitement fournis dans la demande V3. Le contrôle de fidélité aux captures reste à effectuer lorsqu’elles sont disponibles.

| Élément audité | Décision V3 |
| --- | --- |
| DTO, repositories et authentification | Conserver les routes et contrats ; conserver login, 2FA, Keychain, rotation, Face ID et révocation |
| Snapshot réel / caches / stores | Conserver ; lire le journal pour les derniers événements ; protéger les retours d’historique après purge |
| Swift Charts OHLC, volume, marqueurs et niveaux | Conserver le moteur ; l’intégrer aussi dans l’accueil et le résumé de session |
| Palette et styles V2 | Adapter aux tokens Midnight centralisés, avec aliases pour les composants existants |
| Cartes, filtres, titres, timeline, montants | Consolider en composants réutilisables ; chiffres tabulaires et couleurs sémantiques |
| Routeur et quatre stacks V2 | Conserver les stacks ; ajouter Analyse et sa stack, dans une TabView native à cinq onglets |
| Choix de section du détail | Adapter : quatre accès principaux + menu complet, incluant graphique et décisions |
| Ordres / Journal / Profil | Adapter les vues ; conserver pagination, messages backend, réglages de notification et sécurité |
| Police du prototype | Utiliser SF / police système. Aucun fichier Manrope de licence non vérifiée n’est embarqué |

## Design system

`MidnightPalette.swift` est la source sRGB de la palette sombre :

| Token | HEX |
| --- | --- |
| background | `#0D1422` |
| surface | `#172234` |
| surfaceElevated | `#1D2B40` |
| border | `#2A3548` |
| textPrimary | `#F2F5FB` |
| textSecondary | `#9AAAC0` |
| accentMint | `#79D9C1` |
| success / loss | `#69CFA3` / `#E87973` |
| warning / info | `#E8B35C` / `#79A7EA` |

Les couleurs UIKit adaptatives conservent le mode clair et le choix Système/Sombre/Clair existants. Les tests calculent le contraste sRGB de chaque couleur de texte sombre sur les trois surfaces : minimum 4,5:1. Cela ne remplace pas la vérification des états désactivés, des opacités et du rendu sur appareil.

Typographie système sémantique : largeTitle bold, title pour les titres d’écran et grandes valeurs, title3 semibold pour les sections, body/subheadline pour le texte et caption pour les repères. Ces styles suivent Dynamic Type ; les chiffres utilisent `monospacedDigit`. Les cartes ont des coins de 16 pt, des fonds unis et des bordures de 1 pt. Aucun halo ou ombre lourde n’est ajouté.

Composants : `PremiumScreenBackground`, `PremiumCard`, `PremiumSectionHeader`, `PremiumMetricCard`, `PremiumStatusBadge`, `PremiumSegmentedControl`, `PremiumFilterChip`, `PremiumEmptyState`, `PremiumErrorState`, `PremiumLoadingSkeleton`, `PremiumTimelineRow`, `PremiumChartContainer`, `PremiumBottomNavigation`, `PremiumAssetIcon`, `PremiumValueLabel`. Les anciens noms sont des aliases ou des wrappers pour garder les écrans d’authentification cohérents.

Les contrôles ont une cible de 44 pt. Les grilles passent à une colonne aux tailles d’accessibilité ; le détail utilise alors son menu natif pour garder de la place au contenu. Les légendes de graphique peuvent se répartir sur plusieurs lignes. Les tooltips apparaissent sous le graphique en grand texte. Le skeleton existant respecte Reduce Motion.

## Comparatif avant / après

Comparatif structurel des vues, sans prétendre disposer de captures rendues ici :

| Écran | V2 | V3 |
| --- | --- | --- |
| Navigation | Dashboard / Sessions / Journal / Profil | Accueil / Sessions / Analyse / Journal / Profil ; TabView et NavigationStack natives |
| Accueil | Courbe compacte de cours, décision, grille dans une carte | État du moteur de session, stratégie/version, quatre cartes KPI, OHLC + volume, décision, derniers événements, état vide de performance |
| Sessions | Filtres horizontaux, cartes textuelles | Toutes / En cours / Terminées, recherche sur les éléments chargés, filtre de surveillance secondaire, icône d’actif, version persistée et résultat coloré |
| Détail | Menu de six sections et nombreuses cartes ouvertes | Header de session avec badge, quatre KPI, OHLC central ; Résumé / Analyse / Ordres / Journal ; graphique et décisions dans le menu ; détails financiers déroulants |
| Graphique | OHLC réservé à une section secondaire, petits libellés et toggles alignés | Même moteur aussi dans l’accueil/résumé, axes caption, indicateurs dans un menu, sélection conservée après toucher, trous respectés dans les overlays |
| Analyse | Longue suite de cartes ; disponibilité des indicateurs après les conditions | Décision, score et seuil séparés, indicateurs, rebond, régime/momentum, veto, conditions et détails techniques |
| Ordres | Liste de cartes sans filtre de sens | Tous / Achats / Ventes / En attente, icône, montant exécuté, frais, statuts finaux/partiels/réconciliation distincts |
| Journal | Événements isolés et filtres horizontaux | Timeline regroupée par date, Tous / Signaux / Système / Erreurs, filtres détaillés Ordres/Positions, titre et message backend conservés |
| Profil | Longues cartes de sécurité/notifications, serveur regroupé en bas | Identité réelle, serveur configuré, affichage/langue/devise, notifications, sécurité/appareils accessibles par disclosure, version et déconnexion |

Les filtres portent sur les pages chargées. Un bouton de pagination reste visible lorsque le serveur indique `has_more`, même si le filtre masque tous les éléments de la page. Les catégories Ordres/Positions du Journal restent disponibles en navigation secondaire.

## Vérité des données et fonctionnalités conservées

Toutes les routes restent sous `/api/mobile/v1`, avec l’authentification partagée existante :

- `/real/sessions/active-snapshot` : supervision, fraîcheur, moteur **de la session réelle** et session choisie par le backend.
- `/real/sessions` et `/real/sessions/{id}` : liste/détail, provider, statuts, dates et stratégie. Les champs de version déjà présents dans les DTO sont désormais conservés dans les modèles de présentation et les caches ; aucun DTO n’est modifié.
- `/real/sessions/{id}/chart?range=1h|6h|24h|7d` : OHLC persisté, timeframe retourné, volumes et overlays optionnels, exécutions BUY/SELL et niveaux. Les périodes sont celles du contrat ; l’iPhone ne propose pas un timeframe inexistant.
- `/real/sessions/{id}/strategy-explanation` : score, seuil, conditions, indicateurs, rebond s’il est exposé, régime/momentum, blockers et fraîcheur. Le score ne valide jamais à lui seul un achat. L’absence d’une valeur ne devient pas une condition défavorable.
- Timeline, ordres et décisions : historique et pagination existants. Le journal présente le titre/message backend ; le libellé pédagogique figure uniquement dans le détail et reste identifié comme tel.
- Authentification, appareils et notifications : repositories et mécanismes existants conservés. Le routeur de notifications conserve ses destinations ; le Journal dispose maintenant de la destination de détail correspondante. Les stacks existantes sont conservées lors du changement d’onglet ; aucune nouvelle persistance de navigation sur disque n’est ajoutée.

Une session arrêtée, archivée, terminée ou possédant un timestamp d’arrêt reste historique même si son dernier lifecycle indique une position ou une attente d’achat. La classification n’utilise aucun identifiant spécial : la session 28 n’est jamais codée comme active. Les previews utilisent des identifiants de fixtures, pas des données de production.

Les quatre KPI proviennent du réalisé net (ou du brut **explicitement nommé brut**), du latent net estimé, de la valeur estimée de position et des frais d’achat constatés. Les valeurs manquantes sont « Indisponible ». Capital autorisé/engagé, solde de session, performance % et P&L cumulé net restent non fournis/non certifiés. Aucun solde global ni capital théorique ne leur est substitué. **L’API ne fournit pas de série historique de P&L/valorisation : la courbe de performance a un état vide premium, sans courbe fictive ni transformation des prix en rendement de portefeuille.**

Le graphique conserve Decimal pour les données financières et Double pour le rendu. Le prix de sélection dans les headers est retrouvé dans la bougie Decimal d’origine. Les overlays ne relient plus deux observations séparées par un intervalle manquant ; une sélection dans un trou ou hors de la couverture ne renvoie pas artificiellement la bougie la plus proche. La source `persisted_ohlcv` reste une indication de persistance, pas une certification de provenance Kraken. Aucun historique RSI/ADX n’est simulé.

Le profil conserve la véritable identité authentifiée. « Adresse configurée » ne signifie pas « connecté ». L’interface actuelle est en français et les montants restent dans la devise du backend ; aucune conversion FX ni nouveau réglage serveur n’est introduit. Les préférences d’apparence restent locales.

Les retours de réseau/cache de l’historique sont protégés par les générations lors d’une purge. Les lectures du cache ne remplacent pas un historique plus récent déjà en mémoire. Les requêtes de snapshot/graphique/analyse gardent leurs mécanismes de visibilité, TTL et annulation ; le journal récent se charge au premier plan.

Aucun bouton d’achat/vente, modification de stratégie/capital, clé Kraken, appel direct à Kraken ou contrôle opérationnel n’est ajouté. Les nouvelles compositions de previews sont sous `#if DEBUG`, clairement marquées comme fictives, et absentes du root Release. Aucun fichier backend, Raspberry ou SQLite n’est modifié.

## Vérifications

Exécuté sur Linux avec Swift 6.2, language mode Swift 5 :

- **41 tests XCTest réussis** via `Scripts/validate-foundation.sh` : 26 validations V2 existantes + 15 tests Midnight (navigation déclarative, archive/statuts, versions réellement décodées et mappées, précision du signe Decimal, filtres d’ordres et contraste sRGB).
- Compilation des sources Foundation utilisées par ces tests, copiées sans réécriture dans le package temporaire. Le mapper de sessions est maintenant inclus ; son logging OSLog reste compilé sur iOS.
- Parsing Swift de toutes les sources application/tests, `git diff --check`, syntaxe des scripts, validation plist/scheme.
- `Scripts/validate-ios.sh` confirme explicitement l’absence de Xcode/SDK simulateur et s’arrête. **Aucun build/type checking SwiftUI, rendu de preview, test iOS complet, test de navigation sur simulateur ou capture iPhone n’a été exécuté ici.**

```bash
PATH=/workspace/swift-6.2-toolchain/usr/bin:$PATH Scripts/validate-foundation.sh
```

Ajouté pour Xcode, **non exécuté ici** :

- `MidnightRenderTests` : héberge les vues natives avec fixtures, capture les onze scénarios (sept écrans + offline/empty/error/loading) en 320/430 pt, six écrans en accessibilité3 et en clair, et mesure l’acceptation d’une largeur de 320 pt pour les composants financiers. Les captures sont conservées comme pièces jointes XCTest dans le `.xcresult`. Elles doivent être examinées ; aucune baseline visuelle approuvée ni garantie d’absence de clipping n’est revendiquée.
- `MidnightNavigationTests` : destinations de notifications et maintien des stacks.
- `MidnightHistoryLifecycleTests` : réponse réseau et lecture cache suspendues, purge, puis réponse tardive ; l’historique ne doit pas réapparaître.
- Tests existants de présentation de graphique/Journal : sélection hors couverture et dans un trou, segments d’indicateurs discontinus, filtre Erreurs. Les assertions de largeur/sélection incompatibles avec le comportement du graphique sont adaptées, ainsi que l’assertion de composition du profil devenue obsolète après V2.
- `MidnightPreviews.swift` : écrans, navigation native, chandeliers, timeline, performance absente, clair et grand texte ; fixtures explicitement identifiées.

## Contrôle sur Mac avant fusion

Le deployment target existant **iOS 26.5** reste inchangé. Utiliser un Xcode et un runtime iPhone compatibles :

```bash
Scripts/validate-ios.sh
# Facultatif : BOTAPLATA_SIMULATOR_ID et BOTAPLATA_TEST_RESULTS_DIR
# Ouvrir TestResults.xcresult et examiner les pièces jointes Midnight-V3-*-FIXTURE.
```

Examiner les sept écrans sur petit/grand iPhone, aux tailles normales et d’accessibilité, en sombre/clair/système. Vérifier VoiceOver, les axes OHLC, la sélection et les marqueurs, les périodes, les trous et l’absence de bougies. Vérifier la navigation secondaire, les notifications vers une session archivée, le chargement des pages après filtrage, offline/cache, passage en arrière-plan, retour sur un onglet, logout/révocation et authentification avec l’environnement autorisé habituel. Les tests d’images ne remplacent pas ces interactions.

Risques restant à lever avant fusion : compilation SwiftUI et suite iOS complète, rendu réel sur appareil/simulateur et fidélité aux captures Lovable manquantes. Aucune capture de maquette générée n’est présentée comme une capture iPhone.
