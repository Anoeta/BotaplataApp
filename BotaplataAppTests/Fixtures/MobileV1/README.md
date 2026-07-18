# Mobile V1 fixtures

Backend contract commit: 599bb55b4b7c51969f74ca45c3821c01be42a4be

These test-only fixtures cover the persisted OHLCV chart endpoint `GET /api/mobile/v1/real/sessions/{session_id}/chart` for ranges 1h, 6h, 24h and 7d plus empty, open-position, marker and partial-history cases. They are stored under `BotaplataAppTests` only and are not embedded in the production app bundle.
