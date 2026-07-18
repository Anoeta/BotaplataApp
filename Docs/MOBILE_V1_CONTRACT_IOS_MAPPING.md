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
