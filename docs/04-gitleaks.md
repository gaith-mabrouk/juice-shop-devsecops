1. Objectif

Cette étape consiste à intégrer **Gitleaks** dans le pipeline DevSecOps afin de détecter automatiquement les secrets, clés API, tokens et autres informations sensibles susceptibles d'être introduits dans le dépôt Git.

L'objectif n'est pas uniquement d'installer un outil de détection, mais de mettre en place un véritable **Security Gate** dans le pipeline CI/CD.

Le comportement recherché est le suivant :

Développeur
    │
    │ git push / Pull Request
    ▼
GitHub
    │
    ▼
Build
    │
    ▼
Gitleaks
    │
    ├── Secret détecté
    │       │
    │       ▼
    │      ❌ BLOCK
    │
    └── Aucun nouveau secret
            │
            ▼
           ✅ PASS

Dans le cadre de ce projet, une démonstration contrôlée a également été réalisée avec un faux secret afin de vérifier le comportement réel du Security Gate.

2. Pourquoi utiliser Gitleaks ?

Les secrets peuvent accidentellement être ajoutés au code source par un développeur.

Exemples :

clés API ;
tokens d'authentification ;
mots de passe ;
clés privées ;
credentials ;
secrets utilisés par des services cloud ;
tokens JWT ;
variables contenant des informations sensibles.

Un secret présent dans un dépôt Git peut représenter un risque important, notamment si le dépôt est partagé ou public.

Gitleaks permet d'automatiser la recherche de ces informations sensibles.

Dans notre pipeline, Gitleaks intervient donc comme une étape de Secret Scanning.

3. Position de Gitleaks dans l'architecture DevSecOps

L'architecture globale du pipeline est :

                         Git Push / Pull Request
                                  │
                                  ▼
                         ┌─────────────────┐
                         │     GitHub      │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │      BUILD      │
                         │                 │
                         │ Node.js         │
                         │ npm install     │
                         │ npm test        │
                         └────────┬────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │      SECURITY TESTS       │
                    │                           │
                    │ Semgrep     → SAST        │
                    │ Gitleaks    → Secrets     │
                    │ npm audit   → SCA         │
                    │ Docker Scout → Container  │
                    │ OWASP ZAP   → DAST        │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ SECURITY GATE   │
                         └────────┬────────┘
                                  │
                       ┌──────────┴──────────┐
                       │                     │
                    ❌ FAIL                ✅ PASS
                       │                     │
                       ▼                     ▼
                    STOP                 Deployment
                                             │
                                             ▼
                                        Docker Hub
                                             │
                                             ▼
                                          Render

Gitleaks constitue donc l'un des contrôles de sécurité automatisés du pipeline.

4. Installation de Gitleaks
4.1 Installation sous Windows

Gitleaks a été installé sur l'environnement de développement Windows avec Windows Package Manager (winget).

Commande utilisée :

winget install Gitleaks.Gitleaks

Après l'installation, la version a été vérifiée avec :

gitleaks version

Version utilisée dans le projet :

8.30.1

Cette version est également utilisée dans le workflow GitHub Actions afin de conserver une version explicite de l'outil.

5. Test local de Gitleaks

Avant l'intégration dans GitHub Actions, un test local a été effectué.

Un fichier de démonstration contenant volontairement un faux secret a été créé :

security-demo/
└── secret-example.js

Son contenu était :

const apiKey = "DEMO_API_KEY_PLACEHOLDER";

module.exports = { apiKey };

Une valeur fictive simulant une clé API a été utilisée pour tester Gitleaks. Elle ne correspond pas à une véritable clé d'accès à un service.

5.1 Scan du fichier de démonstration

La commande utilisée était :

gitleaks dir .\security-demo\secret-example.js

Gitleaks a détecté le secret présent dans le fichier.

Le résultat obtenu a confirmé que l'outil était capable d'identifier automatiquement une valeur correspondant à un secret.

Cette première vérification valide le fonctionnement de Gitleaks dans l'environnement local.

Preuve

Capture associée :

docs/screenshots/04-gitleaks/GITLEAKS-01-secret-detected.png
6. Pourquoi utiliser un scan différentiel ?

Un dépôt réel peut contenir un historique Git important.

Dans ce projet, l'analyse complète de l'historique Juice Shop a montré que le dépôt contient déjà de nombreux éléments détectés par Gitleaks.

Une analyse complète de l'historique a notamment produit des résultats sur plusieurs milliers de commits.

Pour un pipeline DevSecOps, analyser systématiquement tout l'historique à chaque modification n'est pas nécessaire pour notre Security Gate.

Nous avons donc choisi une approche différentielle.

Le principe est :

Ancien commit
      │
      │ comparaison
      ▼
Nouveau commit
      │
      ▼
Analyser les changements

L'objectif est de détecter principalement les nouveaux secrets introduits par les modifications récentes.

Cette approche permet de concentrer le Security Gate sur les changements apportés au projet.

7. Test du scan différentiel

Après la création du fichier contenant le faux secret, un test différentiel a été réalisé entre le commit précédent et le commit contenant le secret.

La commande utilisée localement était :

gitleaks git --log-opts="cc45794c1..18cf54e24" --redact

Le résultat a indiqué :

1 commit scanned.
leaks found: 1

Le secret nouvellement introduit a donc été détecté.

Preuve

Capture associée :

docs/screenshots/04-gitleaks/GITLEAKS-02-differential-detection.png
8. Intégration de Gitleaks dans GitHub Actions

Gitleaks a ensuite été intégré dans le workflow :

.github/workflows/devsecops.yml

Le job est exécuté après le build.

Configuration :

gitleaks:
  runs-on: ubuntu-latest
  needs: build

Cela signifie que le scan Gitleaks dépend de la réussite du job build.

Si le build échoue, le job Gitleaks n'est pas exécuté.

9. Récupération de l'historique Git

Le workflow utilise :

- name: Checkout repository
  uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09
  with:
    fetch-depth: 0
Pourquoi fetch-depth: 0 ?

Le scan différentiel doit pouvoir accéder au commit utilisé comme référence.

Avec :

fetch-depth: 0

GitHub Actions récupère l'historique complet nécessaire à la comparaison des commits.

Cette configuration permet ensuite à Gitleaks d'utiliser une plage de commits avec :

BASELINE_COMMIT..CURRENT_COMMIT
10. Pinning de l'action GitHub

Initialement, le job Gitleaks utilisait :

uses: actions/checkout@v5

Semgrep a détecté cette référence comme une utilisation d'un tag mutable.

Le problème était spécifique à la nouvelle partie Gitleaks introduite dans notre pipeline.

L'action a donc été remplacée par une référence SHA complète :

uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09

Cette modification permet de référencer précisément la version utilisée par le workflow.

Le changement a été enregistré dans le commit :

5185680fd
ci: pin Gitleaks checkout action
11. Installation de Gitleaks dans GitHub Actions

Le workflow installe explicitement Gitleaks version 8.30.1.

Configuration utilisée :

- name: Install Gitleaks
  run: |
    GITLEAKS_VERSION="8.30.1"
    curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
      | tar -xz -C "$RUNNER_TEMP"
    sudo mv "$RUNNER_TEMP/gitleaks" /usr/local/bin/gitleaks
    gitleaks version

La version est ensuite vérifiée avec :

gitleaks version

Cette approche permet d'utiliser explicitement la version prévue par le projet dans l'environnement CI.

12. Détermination du commit de référence

Le workflow détermine le commit de référence différemment selon le type d'événement.

Configuration :

if [ "${{ github.event_name }}" = "pull_request" ]; then
  BASELINE_COMMIT="${{ github.event.pull_request.base.sha }}"
else
  BASELINE_COMMIT="${{ github.event.before }}"
fi
Pull Request

Pour une Pull Request, le commit de référence correspond au commit de base de la Pull Request :

Pull Request
     │
     ├── Base commit
     │
     └── Changes
Push

Pour un événement push, le workflow utilise :

github.event.before

comme commit de référence.

Le commit actuel est :

github.sha
13. Scan différentiel dans GitHub Actions

La commande utilisée dans le workflow est :

gitleaks git \
  --log-opts="${BASELINE_COMMIT}..${{ github.sha }}" \
  --redact

Le paramètre :

--log-opts

permet de définir la plage de commits analysée.

Le paramètre :

--redact

permet de masquer les valeurs sensibles dans la sortie du scanner.

Le résultat attendu est :

leaks found: 0

lorsqu'aucun nouveau secret n'est détecté.

Si un secret est détecté, Gitleaks retourne un code d'erreur et le job GitHub Actions échoue.

14. Security Gate

Le comportement du Security Gate est volontairement simple :

Nouveau secret détecté
        │
        ▼
   Gitleaks
        │
        ▼
     ❌ FAIL
        │
        ▼
Pipeline arrêté

À l'inverse :

Aucun nouveau secret
        │
        ▼
   Gitleaks
        │
        ▼
     ✅ PASS
        │
        ▼
Pipeline peut continuer

Gitleaks est donc utilisé comme un mécanisme de contrôle bloquant.

15. Démonstration : introduction volontaire d'un secret

Afin de vérifier que le Security Gate fonctionne réellement, un faux secret a volontairement été introduit dans :

security-demo/secret-example.js

Le commit correspondant était :

18cf54e24
test: introduce secret for Gitleaks gate

Le secret a été détecté lors du scan différentiel.

Le pipeline GitHub Actions a alors échoué au niveau du job Gitleaks.

Résultat :

build      ✅
semgrep    ❌
gitleaks   ❌

Le résultat Gitleaks indiquait :

leaks found: 1
Error: Process completed with exit code 1.

Cette exécution démontre que le pipeline est capable de bloquer une modification contenant un secret détecté.

Preuve

Capture associée :

docs/screenshots/04-gitleaks/GITLEAKS-03-github-actions-blocked.png
16. Remédiation

Après la détection, le faux secret a été supprimé du dépôt.

Le fichier de démonstration :

security-demo/secret-example.js

a été supprimé.

Le commit de remédiation est :

1bd6dffa9
fix: remove test secret

Cette modification représente le cycle classique :

Détection
    ↓
Blocage
    ↓
Analyse
    ↓
Remédiation
    ↓
Nouveau commit
    ↓
Nouvelle analyse
17. Validation après remédiation

Après la suppression du faux secret, le pipeline GitHub Actions a été exécuté à nouveau.

Le job Gitleaks a réussi.

Le résultat du scan était :

0 commits scanned.
scanned ~0 bytes (0) ...
no leaks found

Le pipeline complet était également vert :

build      ✅
semgrep    ✅
gitleaks   ✅

Cette exécution confirme que la correction a supprimé le secret de la modification analysée.

Preuve

Capture associée :

docs/screenshots/04-gitleaks/GITLEAKS-04-secret-fixed.png
18. Résumé de la démonstration

Le scénario complet réalisé est :

                 ┌──────────────────────────┐
                 │  Introduction d'un secret │
                 └─────────────┬────────────┘
                               │
                               ▼
                         Gitleaks Scan
                               │
                               ▼
                         Secret détecté
                               │
                               ▼
                           ❌ BLOCK
                               │
                               │
                               ▼
                    Suppression du secret
                               │
                               ▼
                         Nouveau commit
                               │
                               ▼
                         Gitleaks Scan
                               │
                               ▼
                       No leaks found
                               │
                               ▼
                           ✅ PASS

Cette démonstration permet de valider le fonctionnement du Security Gate sur un cas contrôlé.

19. Configuration finale

La partie Gitleaks du workflow est actuellement structurée comme suit :

gitleaks:
  runs-on: ubuntu-latest
  needs: build

  steps:
    - name: Checkout repository
      uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09
      with:
        fetch-depth: 0

    - name: Install Gitleaks
      run: |
        GITLEAKS_VERSION="8.30.1"
        curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
          | tar -xz -C "$RUNNER_TEMP"
        sudo mv "$RUNNER_TEMP/gitleaks" /usr/local/bin/gitleaks
        gitleaks version

    - name: Run Gitleaks differential scan
      shell: bash
      run: |
        if [ "${{ github.event_name }}" = "pull_request" ]; then
          BASELINE_COMMIT="${{ github.event.pull_request.base.sha }}"
        else
          BASELINE_COMMIT="${{ github.event.before }}"
        fi

        echo "Baseline commit: $BASELINE_COMMIT"

        gitleaks git \
          --log-opts="${BASELINE_COMMIT}..${{ github.sha }}" \
          --redact
20. Résultats obtenus

Les tests réalisés permettent de résumer le comportement de Gitleaks comme suit :

Scénario	Résultat
Installation locale de Gitleaks	✅
Détection d'un faux secret en local	✅
Scan différentiel local	✅
Intégration dans GitHub Actions	✅
Détection d'un nouveau secret	✅
Blocage du pipeline	✅
Suppression du secret	✅
Validation après correction	✅
Pipeline complet après remédiation	✅
21. Captures d'écran

Les principales preuves de cette étape sont stockées dans :

docs/screenshots/04-gitleaks/

Organisation :

04-gitleaks/
├── GITLEAKS-01-secret-detected.png
├── GITLEAKS-02-differential-detection.png
├── GITLEAKS-03-github-actions-blocked.png
└── GITLEAKS-04-secret-fixed.png
GITLEAKS-01 — Secret détecté

Démonstration locale de la capacité de Gitleaks à identifier un faux secret.

GITLEAKS-02 — Scan différentiel

Démonstration de la détection du secret introduit entre deux commits.

GITLEAKS-03 — Pipeline bloqué

Démonstration du Security Gate dans GitHub Actions lorsqu'un secret est détecté.

GITLEAKS-04 — Secret corrigé

Démonstration du passage au vert après suppression du secret.

22. Limites et bonnes pratiques
22.1 Ne jamais utiliser de vrais secrets pour les tests

La démonstration réalisée dans ce projet utilise volontairement une valeur fictive.

Un véritable secret ne doit jamais être ajouté au dépôt, même temporairement.

22.2 La suppression d'un secret ne suffit pas toujours

Lorsqu'un véritable secret a été publié dans un dépôt Git, supprimer la ligne dans le dernier commit ne garantit pas que le secret n'existe plus dans l'historique Git.

Dans un contexte réel, un secret compromis doit être considéré comme exposé et doit généralement être révoqué ou renouvelé.

La gestion de l'historique Git et la rotation des credentials constituent donc des mesures complémentaires.

22.3 Le secret scanning ne remplace pas les autres contrôles

Gitleaks se concentre sur la détection de secrets.

Il ne remplace pas :

le SAST ;
le SCA ;
le scan des images Docker ;
le DAST ;
les tests unitaires ;
les contrôles de configuration ;
les mécanismes de gestion des secrets.

C'est pourquoi Gitleaks constitue seulement une partie de la stratégie de sécurité du pipeline.

23. Contribution de Gitleaks à la démarche DevSecOps

L'intégration de Gitleaks permet de déplacer la détection des secrets vers les premières étapes du cycle de développement.

Sans automatisation :

Développement
      ↓
Commit
      ↓
Déploiement
      ↓
Problème découvert tardivement

Avec le Security Gate :

Développement
      ↓
Commit
      ↓
GitHub Actions
      ↓
Gitleaks
      ↓
Secret détecté
      ↓
❌ Pipeline bloqué
      ↓
Correction
      ↓
Pipeline validé

Cette approche permet d'identifier les problèmes avant qu'une modification contenant un secret ne puisse poursuivre le pipeline vers les étapes suivantes.

24. Conclusion

Gitleaks a été intégré au pipeline DevSecOps afin d'assurer une fonction de Secret Scanning.

L'intégration réalisée permet :

d'identifier les secrets introduits dans les modifications ;
d'effectuer un scan différentiel ;
d'exécuter automatiquement le contrôle dans GitHub Actions ;
de bloquer le pipeline lorsqu'un nouveau secret est détecté ;
de vérifier le comportement après remédiation.

La démonstration réalisée suit un cycle complet :

Secret introduit
      ↓
Détection
      ↓
❌ Security Gate
      ↓
Remédiation
      ↓
Nouvelle analyse
      ↓
✅ Security Gate

Gitleaks constitue ainsi un contrôle complémentaire au SAST Semgrep et participe à la mise en place d'une chaîne CI/CD intégrant progressivement la sécurité.