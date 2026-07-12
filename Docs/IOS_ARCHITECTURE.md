# Architecture iOS Botaplata

Cette V1 est une fondation SwiftUI native sans dépendance externe. Elle prépare un affichage immédiat du dernier état connu puis un futur refresh backend, sans implémenter de réseau.

## Flux prévu

Dernier snapshot local connu → affichage immédiat → refresh réseau asynchrone futur → mise à jour douce.

`LoadedContent<Value>` modélise les états `idle`, `loading`, `loaded`, `loadedFromCache`, `refreshing`, `partial`, `stale`, `offline` et `error` pour éviter une accumulation de booléens incohérents.

## Navigation

`RootView` sélectionne l'expérience selon `AppSessionState`. L'état authentifié affiche quatre onglets exacts : Dashboard, Sessions, Journal et Profil. Chaque onglet utilise un `NavigationStack` indépendant.

## Domaine

Les modèles `SessionLifecycleState`, `OrderStatus`, `FeeAwareSummary` et `SystemHealth` sont des modèles iOS préparatoires. Ils ne prétendent pas que Mobile API V1 expose déjà tous ces champs. Les montants utilisent `Decimal` et les valeurs absentes restent optionnelles.

## Exchanges

Kraken est le provider principal futur, mais uniquement via le backend Botaplata. Binance est représenté comme historique legacy en lecture seule. Aucun appel direct exchange n'est autorisé côté iOS.
