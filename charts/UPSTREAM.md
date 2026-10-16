Charts officiels issus du code officiel depuis coder/coder, tag v2.26.0, commit a056cb6577417b71f432084ff2a62a617a5246d9. Source : https://github.com/coder/coder/tree/v2.26.0/helm
Le numéro de chart dans les sources est 0.1.0 ; image Coder fixée explicitement à v2.26.0. Licence upstream : LICENSE.coder.

Adaptation locale : ajout du rendu optionnel de coder.startupProbe dans templates/_coder.tpl. Les valeurs du lab accordent jusqu’à cinq minutes au démarrage avant les sondes normales. Cette sonde a permis le démarrage sur la VM personnelle ; HTTP 200 /healthz et rollout réussi confirmés par son utilisateur le 16 octobre 2026.
