# Validation manuelle du Dashboard Kraken réel

1. Lancer le backend Botaplata sur le Raspberry.
2. Lancer l'app en environnement Development avec accès au backend.
3. Se connecter avec les identifiants réels sans les noter dans les logs.
4. Valider la 2FA réelle sans documenter le code.
5. Ouvrir le Dashboard et vérifier que le snapshot réel se charge.
6. Vérifier la session SOL/USDC Kraken, le lifecycle, le monitoring, la fraîcheur et le prix.
7. Vérifier la position ouverte et les valeurs fee-aware lorsqu'elles existent.
8. Couper le réseau et vérifier le banner « Dernier état connu » / hors ligne.
9. Rétablir le réseau et vérifier la mise à jour.
10. Fermer puis rouvrir l'app : le cache doit apparaître immédiatement puis être rafraîchi.

Ne jamais documenter mot de passe, TOTP, token, clé Kraken, secret Kraken ou nonce.
