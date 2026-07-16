# Configuration réseau TestFlight Botaplata iOS

## Décision recommandée pour la TestFlight privée

Option A — Tailscale privé est recommandée pour la première TestFlight privée. Le Raspberry reste dans un réseau privé, l'iPhone rejoint le même tailnet et aucun port public n'est ouvert directement sur Internet.

À configurer dans Xcode ou dans la configuration de build TestFlight :

```text
BOTAPLATA_API_BASE_URL=<À_CONFIGURER>
```

Ne pas inventer l'URL finale tant que le mode Tailscale exact n'est pas choisi. Exemples possibles selon l'installation :

```text
https://<raspberry-tailnet-name>:<port>
https://<nom-tailscale-serve>
```

Si le backend n'expose que HTTP local, privilégier un reverse proxy local/Tailscale Serve avec HTTPS avant TestFlight.

## Option A — Tailscale privé recommandé

1. Installer Tailscale sur le Raspberry et sur l'iPhone de test.
2. Connecter les deux appareils au même tailnet.
3. Exposer le backend uniquement dans le tailnet, idéalement via HTTPS ou Tailscale Serve.
4. Définir `BOTAPLATA_API_BASE_URL` avec l'URL privée réellement vérifiée.
5. Depuis l'iPhone, ouvrir l'URL de santé backend dans Safari ou vérifier via l'app avec un login réel.

## Option B — HTTPS public plus tard

Pour une distribution plus large, utiliser un nom de domaine public HTTPS avec reverse proxy, certificats valides, rate limiting et durcissement backend. Cette option demande une revue sécurité backend séparée.

## Pourquoi ne pas exposer 31119 directement

Le port backend ne doit pas être publié tel quel sur Internet. Une exposition directe augmente le risque de scan, d'attaque brute force, de fuite de surface d'administration et de mauvaise configuration TLS.

## Choix de `BOTAPLATA_API_BASE_URL`

- Development peut pointer vers une URL locale uniquement quand elle est explicitement configurée.
- TestFlight et Production doivent recevoir une URL explicite et ne doivent jamais retomber silencieusement vers `http://192.168.1.47:31119`.
- Previews, UI tests et démo debug explicite peuvent utiliser des mocks sans backend.

## Vérification depuis l'iPhone

- Wi-Fi maison : vérifier que l'URL configurée répond.
- Hors Wi-Fi : désactiver le Wi-Fi, activer Tailscale, puis vérifier le login et le dashboard.
- Backend down : vérifier que l'app affiche une erreur compréhensible ou un cache existant, jamais des données fictives.
