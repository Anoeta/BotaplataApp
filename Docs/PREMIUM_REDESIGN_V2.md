# Botaplata iOS · Premium redesign V2

## Audit et périmètre

Base iOS : `7c47ed5` (main). Backend inspecté : `1eeecfb9b61659890b2cf70f0397bd75b3a1fb2a`, dernier main observé, intégrant la PR #169 RSI/OHLC. Le backend, le Raspberry et la production n’ont pas été modifiés. Aucune connexion à la session de production n’a servi à la validation.

L’architecture existante comprend des modèles DTO/domain, des repositories HTTP, des stores Observation sur MainActor et quatre NavigationStack dans une TabView. Le Dashboard charge le snapshot réel ; les détails ont déjà des sections analyse, graphiques, ordres, journal et décisions. Les chandeliers Swift Charts et les overlays VWAP/EMA200/Bollinger existaient déjà, mais le dashboard n’affichait aucun graphique et répétait de nombreuses cartes textuelles. La navigation du détail utilisait une rangée horizontale de six boutons. Les couleurs et l’apparence étaient forcées en sombre ; le profil présentait une adresse configurée comme une connexion établie.

L’authentification repose sur le login/2FA du backend, les jetons opaques, leur rotation via `AuthenticationSession.withAccessTokenReplay`, Keychain, la gestion des appareils et le verrouillage biométrique local. Les caches de snapshot, sessions et historique restent en place. Le cache graphique est en mémoire. L’analyse conserve un cache par session avec TTL. Les mocks sont également désactivés dans le root Release, même en présence des arguments de lancement de test. Les changements préservent ces mécanismes et purgent aussi l’analyse et les graphiques lors de la déconnexion/révocation/expiration.

Projet Xcode avec groupes synchronisés : les nouveaux fichiers Swift sont inclus par les groupes application/tests existants. Swift language mode 5.0, deployment target **iOS 26.5** conservé. Charts est un framework Apple ; aucune dépendance iOS externe ajoutée. Aucun pipeline CI n’existait dans les deux dépôts. Deux scripts de validation sont ajoutés sans prétendre disposer d’un runner macOS.

## Expérience implémentée

- Dashboard : identité compacte, connexion/réponse HTTP séparée de la surveillance, de la sécurité et de la fraîcheur ; graphique du marché de la session réelle suivie ; décision et accès à l’analyse ; grille financière ; détails d’ordre/réconciliation uniquement lorsqu’ils existent.
- Cours : quatre périodes réellement acceptées par le backend, sélection tactile prix/heure, axes, marqueurs d’exécutions BUY/SELL avec distinction de forme, Audio Graph VoiceOver. Les timestamps de clôture sont utilisés, pas des prix inventés aux dates d’ouverture. Une observation unique est un point, un historique vide a un état explicite. Les trous séparent les segments, sont ombrés et invalident le calcul de variation. La variation concerne seulement les observations affichées, dont les bornes sont visibles ; elle n’est pas annoncée comme une variation certifiée de 24 h.
- Graphiques détaillés : chandeliers, volume, sélection et overlays existants conservés ; périodes adaptées aux petits écrans et Dynamic Type. La courbe compacte est également disponible dans l’aperçu de session.
- Analyse : score d’entrée segmenté borné, seuil fourni par le backend, rebond présenté séparément sans ajouter de points, grille RSI/ADX/VWAP/Bollinger/EMA200/ATR, jauge RSI 0–100 sans seuil calculé sur l’iPhone. Conditions et indicateurs distinguent disponibilité et validation stratégique. Régime, momentum, blocages et bougie clôturée restent visibles. Aucun historique RSI n’est simulé.
- Sessions : sessions actives et historiques séparées, cours, date de début et quantité ouverts quand fournis. La navigation du détail devient un menu natif explicitement libellé : Aperçu, Analyse, Graphique, Ordres, Journal, Décisions, sans rangée tronquée.
- Journal : chronologie compacte avec icônes et libellés, détail au toucher. Une décision enregistrée n’est pas décrite comme recalculée sur l’iPhone. Ordres : exécution, frais, résultat et timestamps ; détails secondaires dans une disclosure. `open` est présenté comme **état local**, sans preuve d’ouverture actuelle chez Kraken ; une date manquante ne devient plus la date du jour.
- Profil : appareils, Face ID, notifications et déconnexion conservés ; serveur/diagnostics regroupés. Une URL configurée est simplement « configurée ». Sombre par défaut, avec choix Système/Sombre/Clair persistant. Palette adaptative bleu nuit/turquoise, surfaces unies, contraste des libellés système, absence de grands halos décoratifs.
- Accessibilité : tailles de texte sémantiques, grilles à une colonne en tailles d’accessibilité, périodes en deux colonnes, contrôles de 44 pt, descriptions de graphique et états nommés. Pas de nouvelle animation répétitive ; les skeletons existants respectent Reduce Motion.

Le polling du snapshot cesse à la sortie du dashboard ; les chargements actifs sont annulés lorsque l’application quitte l’état actif. Le graphique et l’analyse ne sont rafraîchis que pendant leur visibilité au premier plan, avec TTL/single-flight. Les réponses d’une autre session/plage sont rejetées. Le cache d’analyse ne change pas sa date de réception à chaque lecture et les réponses tardives ne ressuscitent pas des données après purge.

## Matrice des contrats utilisés

Toutes les routes ci-dessous sont sous `/api/mobile/v1`. Les repositories de supervision utilisent GET avec authentification existante.

| Route réelle | Modèles iOS | Utilisation / limite |
| --- | --- | --- |
| `/real/sessions/active-snapshot` | `RealActiveSnapshotDTO`, `RealSessionDetailDTO`, `RealActiveSnapshot`, `SessionDetail` | Session suivie, monitoring, fraîcheur, marché, décision, position, ordre actif, réconciliation, fee_aware et pnl. Le backend choisit la session ; l’iPhone ne force pas une fausse session SOL. |
| `/real/sessions` et `/real/sessions/{id}` | `RealSessionsPageDTO`, `RealSessionSummaryDTO`, `RealSessionDetailDTO` | Liste, pagination, détails, historique/actif. Capital et solde de session absents. |
| `/real/sessions/{id}/chart?range=1h\|6h\|24h\|7d` | `RealSessionChartDTO`, `TradingChart` | OHLC persisté, volume, VWAP/EMA200/Bollinger optionnels ; marqueurs avec quantités appliquées/exécutions et niveaux financiers. Historique limité/paginé signalé ; pas de RSI/ADX/ATR historique. |
| `/real/sessions/{id}/strategy-explanation` | `RealStrategyExplanationDTO`, `StrategyExplanation` | Décision Star V3, score, conditions, blockers, indicateurs et protection ; aucun calcul stratégique local. |
| `/real/sessions/{id}/timeline`, `/orders`, `/decisions`, `/journal-page` | `RealSessionHistoryDTO`, modèles timeline/ordres/décisions | Historique paginé existant réutilisé ; statuts reçus du backend, pas de requêtes directes Kraken. |
| `/auth/*`, `/me`, routes appareils/notifications existantes | `AuthenticationSession`, `ProfileStore`, `PushNotificationsStore` | Authentification, rotation, appareils et notifications préservés. Aucune fonction de trading mobile ajoutée. |

Le `/health` général et le `/api/mobile/v1/health` existent, mais une réponse HTTP n’atteste pas l’ensemble du fonctionnement réel du bot. La V2 utilise les champs de monitoring/fraîcheur/statut de la session pour « Surveillance OK » ; la disponibilité de la réponse est libellée séparément. Un backend sans session ne devient jamais « opérationnel » sur cette seule base.

### Écarts backend/iOS corrigés

Les anciennes fixtures ne couvraient pas tous les champs du sérialiseur actuel. Le décodage accepte désormais :

- `analysis.decision_timeframe` et `analysis.is_stale`, ainsi que l’ancienne forme `timeframe`/`freshness`.
- `decision.technical_reason`, conservé dans le niveau de détail technique.
- Bollinger `upper`, `middle`, `lower`, conservés en tant que valeurs reçues.
- Protection `unrealized_pnl_quote`, `minimum_profitable_exit_price`, `trailing_stop_price`, avec les anciens aliases.
- Warnings `{code, message}` du backend et l’ancienne forme `{id, severity, title, message}`. Un warning d’analyse périmée ne casse plus tout le décodage.

`realized_pnl_quote` est conservé comme résultat **brut** ; il ne remplace pas silencieusement le réalisé net. Le cours conserve son `market.observed_at`/`updated_at`. Les données nulles restent nulles, avec un libellé indisponible.

Les trois nouvelles fixtures `backend_rsi_43`, `backend_stale`, `backend_position` ont été générées avec `build_strategy_explanation` du commit backend indiqué, des objets synthétiques et SQLite en mémoire. Elles sont exclusivement destinées aux tests. Elles ne contiennent ni secrets ni données de production.

## Lacunes API et proposition de PR backend indépendante

Cette PR ne change pas le backend. Les valeurs non exposées sont marquées non fournies ou non certifiées : capital autorisé, capital réellement engagé, solde de session, performance %, score/validation détaillés du rebond et provenance certifiée des bougies. `persisted_ohlcv` indique une persistance ; il ne certifie pas une origine de flux Kraken. Aucun solde global exchange n’est substitué au solde de session.

Proposition de PR distincte : `feat(api): expose read-only session financial metrics and strategy history`.

Contrat minimal à discuter séparément, avec valeurs décimales en chaînes ou null et timestamps/source explicites :

1. Détail/snapshot : capital autorisé, engagé et disponible **dans la portée de la session**, méthode de calcul, réalisé net avec qualité des frais, performance avec dénominateur et période clairement définis.
2. Explication : confirmation/score/seuil de rebond distincts du score d’entrée, et provenance OHLC vérifiée quand les diagnostics du moteur le permettent. Ne pas exposer de credentials ou inventer une certification.
3. Série de graphique : RSI/ADX/ATR optionnels alignés sur chaque bougie clôturée et leur date de calcul. Pagination/couverture temporelle explicites pour un véritable historique d’indicateurs.

En attendant, aucun mini-graphique RSI fictif, aucune extrapolation du capital, aucun appel direct Kraken et aucune nouvelle route présumée n’entrent dans l’app.

## Validation réalisée

Dans l’environnement Linux :

- **26 tests XCTest exécutés, 26 réussis** : 18 modèles/contrats V2, 5 tests de store d’analyse, 2 tests de mapper de graphique existants, 1 test de décodage de toutes les fixtures de graphique existantes.
- Production Foundation/DTO/mapper/store compilés avec Swift 6.2 en mode Swift 5 via `Scripts/validate-foundation.sh` ; les fichiers testés sont copiés sans réécriture dans un package temporaire supprimé ensuite. La couche Observation est conditionnée à la présence de SwiftUI : ces tests Linux valident le comportement du store, pas ses bindings SwiftUI.
- Parsing avec le frontend Swift de **toutes les sources application et tests**, sans SDK iOS ; pas de revendication de type checking SwiftUI.
- Syntaxe des scripts shell, structure XML plist/entitlements/scheme et `git diff --check`.
- Inspection du diff pour credentials/clé privée et routes de trading : aucune nouvelle valeur secrète ou fonction de trading détectée. Backend Git inchangé.

Des erreurs préexistantes dans les tests ont été corrigées : valeurs `await` évaluées avant les autoclosures XCTest, appels throwing du test de contrats précédés de `try`, et résolution `Bundle.module` compatible Xcode. Les assertions sur les nouveaux libellés ont été adaptées. Les nouveaux tests de cache graphique sont ajoutés au target Xcode ; leur exécution reste à faire sur Mac.

**Non exécutés ici** : build Xcode, suite complète du target iOS, tests simulateur/UI, rendu des previews, captures et mesure des performances sur appareil. Les previews SwiftUI sont fournies dans `PremiumRedesignPreviews.swift`, mais aucune image générée n’est présentée comme un rendu réel.

Pour reproduire les 26 tests dans cette machine :

```bash
PATH=/workspace/swift-6.2-toolchain/usr/bin:$PATH Scripts/validate-foundation.sh
```

Sur une autre machine, utiliser une toolchain Swift 6.2 installée et lancer le même script avec `swift` dans le PATH.

## Vérification sur Mac avant fusion

```bash
cd BotaplataApp
xcodebuild -list -project BotaplataApp.xcodeproj
Scripts/validate-ios.sh
```

Utiliser Xcode et un runtime simulateur compatibles avec le deployment target existant **iOS 26.5**. Le script choisit un iPhone compatible disponible, ou accepte `BOTAPLATA_SIMULATOR_ID`. Il lance build+tests et écrit un `.xcresult` hors du dépôt ; `BOTAPLATA_TEST_RESULTS_DIR` permet de choisir le dossier de résultats. Il échoue explicitement si Xcode ou un simulateur compatible manque. Ce script a uniquement été vérifié syntaxiquement sur Linux.

Vérifier un petit iPhone et un grand iPhone, tailles normales et accessibilité, modes clair/sombre/système, VoiceOver/Audio Graph, Reduce Motion ; toucher le graphique, changer rapidement de période, examiner les trous et un historique vide. Tester loading/error/offline/stale, passage en arrière-plan, retour sur l’onglet, changement de session et purge après logout/révocation. Vérifier login/2FA/rotation/Face ID avec l’environnement habituel autorisé. L’app reste une consultation : aucun démarrage/arrêt de session réelle, ordre, annulation ou modification de stratégie.

## Fichiers

L’inventaire complet des fichiers ajoutés/modifiés figure ci-dessous ; le diff de la PR donne les détails.

- `BotaplataApp/App/BotaplataApp.swift`
- `BotaplataApp/App/RootView.swift`
- `BotaplataApp/Core/DesignSystem/Components/Components.swift`
- `BotaplataApp/Core/DesignSystem/Tokens/BotaplataTokens.swift`
- `BotaplataApp/Domain/Sessions/RealSessionsMapper.swift`
- `BotaplataApp/Domain/Sessions/SessionModels.swift`
- `BotaplataApp/Domain/Sessions/StrategyExplanationDTO.swift`
- `BotaplataApp/Domain/Sessions/StrategyExplanationMapper.swift`
- `BotaplataApp/Domain/Trading/TradingModels.swift`
- `BotaplataApp/Features/Dashboard/ActiveSessionStore.swift`
- `BotaplataApp/Features/Dashboard/DashboardContainerView.swift`
- `BotaplataApp/Features/Dashboard/DashboardView.swift`
- `BotaplataApp/Features/Journal/JournalView.swift`
- `BotaplataApp/Features/Profile/ProfileView.swift`
- `BotaplataApp/Features/Sessions/RealSessionChartRepository.swift`
- `BotaplataApp/Features/Sessions/RealSessionChartStore.swift`
- `BotaplataApp/Features/Sessions/RealStrategyExplanationRepository.swift`
- `BotaplataApp/Features/Sessions/RealStrategyExplanationStore.swift`
- `BotaplataApp/Features/Sessions/RealTradingChartView.swift`
- `BotaplataApp/Features/Sessions/SessionsView.swift`
- `BotaplataAppTests/ActiveSessionCacheTests.swift`
- `BotaplataAppTests/ActiveSessionStoreTests.swift`
- `BotaplataAppTests/AuthenticationFoundationTests.swift`
- `BotaplataAppTests/JournalAlertsPresentationTests.swift`
- `BotaplataAppTests/MobileV1ContractDecodingTests.swift`
- `BotaplataAppTests/ProfileStoreTests.swift`
- `BotaplataAppTests/RealSessionChartStoreTests.swift`
- `BotaplataAppTests/SessionsPresentationTests.swift`
- `BotaplataApp/Domain/Shared/APIWarningPresentation.swift`
- `BotaplataApp/Domain/Trading/PremiumMarketPresentation.swift`
- `BotaplataApp/Features/Dashboard/PremiumMarketView.swift`
- `BotaplataApp/Features/Sessions/PremiumSessionPerformanceCard.swift`
- `BotaplataApp/Features/Sessions/RealStrategyExplanationRepositoryProtocol.swift`
- `BotaplataApp/Features/Sessions/RealStrategyExplanationStore+Authentication.swift`
- `BotaplataApp/PreviewSupport/PremiumRedesignPreviews.swift`
- `BotaplataAppTests/Fixtures/MobileV1/StrategyExplanation/backend_position.json`
- `BotaplataAppTests/Fixtures/MobileV1/StrategyExplanation/backend_rsi_43.json`
- `BotaplataAppTests/Fixtures/MobileV1/StrategyExplanation/backend_stale.json`
- `BotaplataAppTests/PremiumRedesignTests.swift`
- `BotaplataAppTests/PremiumStrategyStoreTests.swift`
- `BotaplataAppTests/TestBundle.swift`
- `Docs/PREMIUM_REDESIGN_V2.md`
- `Scripts/validate-foundation.sh`
- `Scripts/validate-ios.sh`
