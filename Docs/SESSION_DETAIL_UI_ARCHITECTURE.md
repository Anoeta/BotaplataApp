# Session detail UI architecture

La route typée `SessionRoute.detail(id:section:)` reste le point d’entrée du détail pour la liste, les deep links et les notifications. Une fois le détail ouvert, `SessionDetailContainerView` initialise un état local `selectedSection` avec `initialSection`; les pills changent cet état local au lieu d’empiler de nouvelles destinations de navigation.

Le container reçoit le contenu de `RealSessionsStore` et le `RealSessionHistoryStore` environnemental. Le changement de section ne recrée pas ces stores et ne relance pas le chargement principal de détail. Les vues historiques reçoivent le store existant et déclenchent uniquement leur pagination ou refresh de section.

Chaque section possède son propre conteneur principal :

- Overview : `ScrollView` + `LazyVStack` avec les cartes métier réutilisées.
- Journal : timeline réelle via `JournalView` et `JournalEventCard`.
- Ordres / Transactions : `ScrollView` + `LazyVStack`, sans `List` imbriquée.
- Décisions : `ScrollView` + `LazyVStack`, avec détails expansibles.
- Graphique : `ScrollView` dédié, état vide explicite si la série de prix est absente.

Aucune donnée de trading n’est inventée côté iOS : les PnL, frais, prix de rentabilité, marqueurs et conditions proviennent du backend Mobile V1. Les valeurs `nil` sont masquées localement plutôt que converties en zéros.

## Real trading chart section

The `.chart` section uses the dedicated real trading chart component and store. The selected detail section controls lifecycle: entering chart loads the selected range, leaving chart cancels in-flight work and keeps the memory cache. Range changes are local state, not navigation routes, and do not recreate the session detail store.

The section is one scrollable container containing range selector, market summary, candlestick chart, indicator controls, legend, levels, warnings and last update. It does not embed a `List` inside the detail scroll view and does not start permanent polling.
