# Mobile V1 real Kraken contract mapping for iOS

Backend contract commit: `4d5fb53e31d9f4023ae8c3fb8224862a37bbd9f5`.

Test-only fixtures live under `BotaplataAppTests/Fixtures/MobileV1/` and are not loaded by Production code.

## Endpoints

- `GET /api/mobile/v1/real/sessions`
- `GET /api/mobile/v1/real/sessions/active-snapshot`
- `GET /api/mobile/v1/real/sessions/{session_id}`

## Rules

IDs are strings, `execution_mode` maps to `.real`, dates use the shared ISO-8601 decoder, and financial values remain decimal strings decoded through `DecimalString` into `Decimal`. Null backend values stay absent in the domain/UI; iOS does not replace missing financial values with zero and does not recalculate market, fee-aware, or PnL figures.

Warnings are structured as `{code,message}` through `APIWarning`; the backend `message` is displayed rather than reconstructed from `code`.

A `position: null` means no open position. A received position is mapped only when `base_qty` is positive. Orders are never used to synthesize positions. `exchange_order_id` has priority over `kraken_order_id`; `average_execution_price` has priority over `average_fill_price`.

## Backend/iOS table

| Champ backend | CodingKey iOS | DTO iOS | Modèle domaine | Écran |
|---|---|---|---|---|
| `id` | `id` | `RealSessionDetailDTO`, `RealSessionSummaryDTO` | `SessionDetail.id`, `SessionSummary.id` | Dashboard, Sessions |
| `execution_mode` | `executionMode` | session DTOs | `ExecutionMode.real` | Dashboard, Sessions |
| `warnings[]` | `warnings` | `APIWarning` | `Warning` | Banners |
| `decision.*` | `RealDecisionDTO.CodingKeys` | `RealDecisionDTO` | `StrategyDecisionSummary` | Decision cards |
| `position.*` | `RealPositionDTO.CodingKeys` | `RealPositionDTO` | `OpenPosition?` | Position cards |
| `active_order.*` | `RealOrderDTO.CodingKeys` | `RealOrderDTO` | `TradingOrderSummary?` | Order cards |
| `reconciliation.*` | `RealReconciliationDTO.CodingKeys` | `RealReconciliationDTO` | `Warning?` | Health/order cards |
| `fee_aware.*` | `RealFeeAwareDTO.CodingKeys` | `RealFeeAwareDTO` | `FeeAwareSummary` | Fee cards |
| `pnl.*` | `RealSessionPnLDTO.CodingKeys` | `RealSessionPnLDTO` | `ProfitAndLoss?` | Financial cards |

## Errors and safety

Contract decoding failures are represented distinctly from network/server/authentication failures by repository/store error mapping. Diagnostics may include endpoint, request id, DTO type, coding path, and `DecodingError` in Debug only. Logs must never contain Authorization, tokens, passwords, TOTP values, or full sensitive payloads.

## Utilisation dans l’interface

Le Dashboard et la vue d’ensemble de session consomment les modèles domaine déjà issus du contrat Mobile V1, sans DTO concurrent et sans recalcul iOS. Les champs absents sont masqués au lieu d’être remplacés par des zéros ou des cartes `Indisponible`.

| Domaine | Utilisation UI | Règle de masquage |
| --- | --- | --- |
| Dashboard | Header, alertes, hero, session suivie, décision, conditions, position, ordre/réconciliation, PnL, fee-aware, santé, warnings et dernière actualisation. | Aucune `List`; une structure `ScrollView` + `LazyVStack`. |
| Overview session | Réutilise les cartes métier du Dashboard avec davantage de lignes, notamment frais, rentabilité, santé et décision détaillée. | Chaque carte masque les lignes `nil`; fee-aware est absent si aucune valeur backend n’est fournie. |
| Décision | Affiche `title`, `detail`, `score`, `scoreMin`, `favorableConditions`, `requiredConditions`, `controller`, `advice`, `price`, `createdAt` lorsqu’ils existent. | Pas de ratio `0 / 0`; pas de décision recalculée localement. |
| Conditions | Sépare conditions d’achat, conditions de vente et blockers. | Aucune section vide; valeurs numériques affichées seulement si le backend les fournit. |
| Position | Affichée comme ouverte uniquement avec une quantité positive. | Aucune position synthétique depuis un ordre soumis. |
| Ordre | Affiche sens, statut pédagogique, quantités, prix et dates réellement disponibles. | `submitted`, `open` et `partially_filled` restent des états en attente, pas des exécutions confirmées. |
| PnL | Priorise résultat net estimé, latent brut et réalisé net. | Le latent est masqué sans position; `nil` n’est jamais transformé en zéro. |
| Fee-aware | Affiche frais d’achat, taux effectif, frais de vente estimés, source, slippage, frais du cycle, rentabilité et prix minimum rentable. | Carte masquée si aucune valeur non nulle n’est disponible. |
| Warnings | Les warnings backend structurés sont affichés avec leur message d’origine et sans doublon volontaire. | Aucun message reconstruit quand le backend fournit déjà `message`. |
| Sections | Le détail conserve `SessionRoute.detail(id:section:)` pour l’entrée et utilise une sélection locale ensuite. | Les pills ne créent plus de nouvelle route; le store de détail et le store d’historique sont conservés. |
| Graphique | Affiche l’état “Graphique en préparation” quand `points` est vide et liste les marqueurs/niveaux disponibles. | Aucune série OHLCV, RSI, Bollinger, ADX, EMA200, ATR ou courbe fictive n’est inventée sur iPhone. |
