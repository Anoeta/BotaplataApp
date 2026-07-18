# Real trading chart iOS

Backend contract commit: `599bb55b4b7c51969f74ca45c3821c01be42a4be`.

The iOS chart reads only `GET /api/mobile/v1/real/sessions/{session_id}/chart` with `range` (`1h`, `6h`, `24h`, `7d`) and optional `before`/`limit`. The phone never calls Kraken and never calculates VWAP, EMA200, Bollinger, break-even, trailing stop, PnL or OHLC.

DTOs decode `series`, `markers`, `levels`, `has_more`, `next_before`, `generated_at`, `data_source`, `timeframe` and envelope warnings. Financial values use `DecimalString`/`Decimal`; `Double` exists only in `ChartRenderableCandle` for Swift Charts rendering.

`RealSessionChartMapper` filters invalid candles without correcting them, sorts candles and markers chronologically, deduplicates candles by id and preserves backend warnings. Empty series is valid and displays “Graphique en préparation”. Pagination is not automatic in V1; the requested page is displayed first and `has_more`/`next_before` are retained.

`RealSessionChartStore` owns a bounded memory cache keyed by session/range with TTLs 30s, 60s, 120s and 300s. It handles single-flight, cancellation on section close, fast range taps, refresh, offline-with-cache and incompatible contracts. No polling runs while the chart section is closed.

The Swift Charts UI renders candlestick wicks and bodies from OHLC candles, optional volume, backend indicators, backend markers and backend financial levels with labels/legend/accessibility. Missing indicator values remain absent; nil segments are not interpolated.
