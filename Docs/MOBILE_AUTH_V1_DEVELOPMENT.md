# Mobile Auth V1 iOS — configuration Development

- Development utilise `http://192.168.x.x:31119` uniquement dans la configuration Debug locale.
- TestFlight et Production lisent `BOTAPLATA_NETWORK_ENVIRONMENT + environment-specific base URL` depuis l'Info.plist/build settings et n'ont aucun fallback vers l'adresse locale.
- Les previews et UI tests utilisent les mocks et ne contactent jamais le Raspberry.
- Pour tester sur simulateur ou iPhone: vérifier que le backend écoute sur `192.168.1.47:31119`, que l'iPhone/Mac est sur le même Wi‑Fi, lancer la configuration Development, saisir l'identifiant Botaplata, puis le TOTP réel, redémarrer l'app pour valider le refresh, puis logout.
- HTTP local est toléré seulement pour Development. TestFlight/Production devront utiliser un transport privé ou HTTPS (par exemple Tailscale/HTTPS) configuré via build settings. Cette PR ne configure pas Tailscale.
- Ne jamais écrire de mot de passe, TOTP, access token ou refresh token dans les logs.
