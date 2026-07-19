# Audit configuration réseau ATS / HTTPS / Tailscale

Commande d'audit utilisée :

```sh
rg -n 'baseURL|BaseURL|serverURL|apiURL|Environment|Configuration|NetworkConfiguration|AppConfiguration|100\.|192\.168|localhost|31119|URLSession'
```

| Fichier | URL | HTTP/HTTPS | Utilisation |
| --- | --- | --- | --- |
| `BotaplataApp.xcodeproj/project.pbxproj` | `http://192.168.x.x:31119` | HTTP local uniquement | Valeur placeholder `BOTAPLATA_DEVELOPMENT_LOCAL_BASE_URL` pour `DevelopmentLocal`; à remplacer localement par l'IP Wi‑Fi du backend. |
| `BotaplataApp.xcodeproj/project.pbxproj` | `https://xxxxx.ts.net` | HTTPS | Valeur placeholder Tailscale Funnel/Serve pour `DevelopmentRemote` et `Release`; à remplacer par le domaine `.ts.net` réel. |
| `BotaplataApp/Info.plist` | `$(BOTAPLATA_DEVELOPMENT_LOCAL_BASE_URL)` | Selon build setting | Injection Info.plist de la base URL locale. |
| `BotaplataApp/Info.plist` | `$(BOTAPLATA_DEVELOPMENT_REMOTE_BASE_URL)` | HTTPS attendu | Injection Info.plist de la base URL distante. |
| `BotaplataApp/Info.plist` | `$(BOTAPLATA_RELEASE_BASE_URL)` | HTTPS attendu | Injection Info.plist de la base URL Release/TestFlight. |
| `BotaplataAppTests/NetworkConfigurationTests.swift` | `http://192.168.x.x:31119` | HTTP local uniquement | Vérifie que `URL(string:)` conserve exactement l'URL `DevelopmentLocal`. |
| `BotaplataAppTests/NetworkConfigurationTests.swift` | `https://xxxxx.ts.net` | HTTPS | Vérifie que `URL(string:)` conserve exactement les URLs `DevelopmentRemote` et `Release`. |
| `BotaplataAppTests/*RepositoryTests.swift` | `https://botaplata.test` | HTTPS | Hôte fictif de tests unitaires injecté dans `APIClient`; aucune requête réseau réelle. |

Aucune entrée `NSAllowsArbitraryLoads` ou `NSExceptionDomains` n'est utilisée. Les requêtes applicatives passent par `APIClient`, lui-même construit avec `NetworkConfiguration.baseURL` via `AppEnvironment`.
