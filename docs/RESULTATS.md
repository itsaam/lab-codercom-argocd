# Résultats réels du lab temporaire OpenAI

Vérification finale : 15 octobre 2026. Ces résultats concernent cette instance ; ni une publication d'environnement ni une restauration dans une nouvelle tâche n'ont été testées.

| Vérification exécutée | Résultat |
|---|---|
| Identité et capacités du processus | UID 1000, aucune capacité Linux directe ; accès utilisable au socket Docker |
| Docker client/serveur | 28.4.0, conteneur Kind privilégié réellement lancé |
| Ressources | Quota cgroup 4 CPU, limite mémoire 32 Gio ; disque système 32 Gio, environ 5,9 Gio libres en fin d'essai |
| Kubernetes | 1.32.2, nœud Ready ; composants système Running |
| DNS interne | Résolution de coder.coder.svc.cluster.local depuis le workspace réussie |
| Réseau sortant utile | Images Docker/Quay/GHCR, sources GitHub et providers Terraform effectivement téléchargés avec vérification TLS |
| PostgreSQL | Requête SQL SELECT version() réussie : 16.8 ; PVC de 2 Gio Bound |
| Argo CD | Application coder Synced et Healthy ; installation effective du chart Helm officiel vendored dans Git interne |
| HTTP Coder | GET / et /healthz : HTTP 200 ; /healthz contient OK |
| Authentification Coder | Administrateur local créé puis connexion API réussie |
| Template Terraform | Publication explicite par CLI Coder réussie ; init avec signatures puis validate réussis ; lockfile conservé et publié |
| Workspace | go-lab running, healthy, version active à jour ; agent connected, lifecycle ready |
| Session via Coder | coder ssh exécuté avec succès, Git 2.39.5 et Go 1.24.2 |
| Programme Go via Coder SSH | Affiche « Bonjour SUEZ : workspace Go opérationnel » |
| Persistance | stop/start Coder réel ; aucun pod pendant l'arrêt, nouveau UID de pod ensuite, même UID de PVC, mêmes SHA-256 de main.go et persistence.txt |
| Droits positifs | Le compte de service Coder peut créer des pods dans workspaces |
| Droits négatifs | Création de secrets dans workspaces et de pods dans kube-system refusée pour ce compte |
| Reprise locale | resume.py exécuté deux fois avec succès sur l'instance active ; cela ne teste pas une nouvelle machine |
| Dépôt utilisateur | git status --short vide ; aucun fichier source modifié |

Le programme Go et les fichiers restent présents après la mise à jour finale du workspace avec le template verrouillé. Voir `final-ssh.log`, `final-status.json`, `before-restart.txt`, `after-restart.txt` et `versions-observed.json`.

## Corrections de configuration nécessaires

- Répertoire personnel en lecture seule : outils, kubeconfig et fichiers sous /workspace.
- Création réseau IPv6 Kind refusée par ip6tables : réseau Docker IPv4 kind créé explicitement.
- Kubelet arrêté faute de /dev/kmsg : création du périphérique réel dans le conteneur Kind.
- Montage overlayfs imbriqué refusé : utilisation du snapshotter containerd native, plus coûteux en disque.
- Proxy non résolu et certificat inconnu dans le nœud : résolution du proxy et ajout des autorités publiques fournies par l'environnement. Aucun contournement TLS.
- Image Redis sur public.ecr.aws bloquée : même version de l'image officielle sur Docker Hub.
- Récupération du grand dépôt Coder dépassant le délai Argo CD : petit Git interne contenant uniquement le chart et sa dépendance officielle, à version fixée.
- Service LoadBalancer inadapté au lab : valeur Helm ClusterIP.
- Premier template : erreur de syntaxe corrigée, puis attente de PVC incompatible avec WaitForFirstConsumer. Correction avec wait_until_bound=false, comme dans le template officiel ; premier essai supprimé et volume nettoyé.
- Agent sur l'image Go avec UID sans entrée utilisateur : ajout de USER, LOGNAME et SHELL. Pour une image personnelle durable, construire une image avec un véritable utilisateur coder.

Les contrôleurs Argo CD optionnels Dex, notifications et ApplicationSet sont à zéro réplique pour économiser le disque. Le serveur, le contrôleur d'applications, le repo-server et Redis fonctionnent. Docker n'est pas installé dans le workspace ; les messages de découverte Docker de l'agent sont donc attendus et ne constituent pas une validation de Docker dans le workspace.

## Non testé ou non fourni

- URL publique ou accès entrant depuis le poste utilisateur : aucun mécanisme de publication fourni dans cette session.
- Connexion réelle depuis VS Code desktop sur le poste utilisateur.
- code-server, volontairement optionnel et non installé.
- Azure DevOps privé, identité SUEZ, systèmes d'entreprise : aucun accès utilisé.
- Deux workspaces simultanés, charge, haute disponibilité, sauvegarde/restauration ou isolation réseau de production.
- Recréation depuis une machine vierge et restauration du snapshot dans une nouvelle tâche.

La persistance vérifiée couvre un arrêt/redémarrage du workspace, pas une suppression de cluster ni une perte de disque.

## Configuration sauvegardée

Les champs `install_script` (vérification et rafraîchissement des dépendances conservées) et `start_skill` (reprise des processus et vérifications) ont été enregistrés dans le brouillon. Les domaines documentaires et de téléchargement nécessaires ont également été ajoutés au brouillon réseau. Cette sauvegarde ne publie pas l'environnement et n'a pas débloqué automatiquement ces domaines dans l'instance actuelle.

Pour conserver cet environnement via le produit, examiner et enregistrer les changements dans les paramètres de l'environnement, puis publier. La conservation des processus et une restauration réussie dans une nouvelle tâche ne sont pas présumées.
