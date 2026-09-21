1. Objectif

Cette étape a pour objectif d'intégrer une analyse de la composition logicielle, ou Software Composition Analysis (SCA), dans le pipeline DevSecOps du projet.

L'analyse SCA permet d'identifier les vulnérabilités de sécurité connues présentes dans les dépendances tierces utilisées par l'application.

Dans ce projet, l'outil retenu pour l'analyse SCA est npm audit, intégré au pipeline GitHub Actions.

L'objectif n'est pas de supprimer toutes les vulnérabilités existantes du projet OWASP Juice Shop, celui-ci étant volontairement vulnérable.

L'objectif est plutôt de mettre en place un mécanisme permettant de :

- connaître l'état de sécurité initial des dépendances ;
- conserver cet état sous forme de baseline ;
- détecter les nouvelles vulnérabilités introduites par les modifications ;
- détecter les augmentations de sévérité ;
- bloquer automatiquement le pipeline lorsqu'une nouvelle vulnérabilité critique est introduite.

---

2. Principe de l'analyse SCA

Une application moderne utilise de nombreuses bibliothèques et dépendances tierces.

Une vulnérabilité peut donc être introduite indirectement par une dépendance, même si le développeur n'a pas écrit lui-même le code vulnérable.

Le principe de l'analyse est le suivant :

Application
     |
     v
Dépendances Node.js
     |
     v
npm audit
     |
     v
Vulnérabilités connues
     |
     v
Security Gate
     |
     +---- PASS
     |
     +---- WARNING
     |
     +---- BLOCK

Cette analyse complète les autres contrôles de sécurité du pipeline :

Contrôle	Outil	Objectif
SAST	Semgrep	Analyse du code source
Secret Scanning	Gitleaks	Détection de secrets
SCA	npm audit	Analyse des dépendances
DAST	OWASP ZAP	Analyse dynamique de l'application
Container Security	Docker Scout	Analyse de l'image Docker
3. Analyse initiale des dépendances

Une première analyse locale a été réalisée avec :

npm audit

Cette analyse a identifié 45 vulnérabilités dans l'état initial des dépendances.

La répartition obtenue est la suivante :

Niveau de sévérité	Nombre
Low	3
Moderate	16
High	19
Critical	7
Total	45

L'état initial peut donc être représenté ainsi :

Low       : 3
Moderate  : 16
High      : 19
Critical  : 7
----------------
Total     : 45
Preuve

La capture du scan initial est disponible dans :

docs/screenshots/05-npm-audit/NPM-AUDIT-01-local-scan.png

Cette analyse constitue le point de départ de la stratégie de baseline.

4. Pourquoi utiliser une baseline ?

Une première approche pourrait consister à utiliser directement :

npm audit --audit-level=critical

Cependant, cette approche n'est pas adaptée au contexte de ce projet.

En effet, l'analyse initiale contient déjà :

7 vulnérabilités Critical

Un contrôle basé uniquement sur le nombre total de vulnérabilités provoquerait donc l'échec du pipeline même lorsqu'aucune nouvelle vulnérabilité n'a été introduite.

Le projet utilise donc une stratégie basée sur une baseline de sécurité.

La baseline représente l'état connu des vulnérabilités au moment de l'intégration du contrôle SCA.

Elle est stockée dans :

npm-audit-baseline.json

Cette baseline contient :

Low       : 3
Moderate  : 16
High      : 19
Critical  : 7
Total     : 45

Le principe devient alors :

              BASELINE
                  |
                  v
       Vulnérabilités connues
                  |
                  |
          Nouvelle version
                  |
                  v
             npm audit
                  |
                  v
          Rapport courant
                  |
                  v
          Comparaison
                  |
                  v
        Security Gate

Ainsi, les vulnérabilités historiques connues ne sont pas considérées comme de nouvelles introductions.

5. Rapport d'analyse courant

Lors de l'exécution du pipeline, npm audit est exécuté avec la génération d'un rapport JSON :

npm audit --json > npm-audit-current.json

Le fichier :

npm-audit-current.json

contient l'état actuel des vulnérabilités détectées dans les dépendances.

Il est ensuite comparé au fichier de référence :

npm-audit-baseline.json
6. Security Gate personnalisé

La logique de comparaison est implémentée dans :

scripts/compare-npm-audit.ps1

Le script reçoit deux rapports :

npm-audit-baseline.json
          |
          | comparaison
          v
npm-audit-current.json
          |
          v
compare-npm-audit.ps1
          |
          v
Security Gate

Le script analyse notamment :

les nouveaux identifiants d'advisories ;
les changements de niveau de sévérité ;
les nouvelles vulnérabilités Critical.

Les advisories sont comparés à partir de leur identifiant.

La hiérarchie utilisée pour comparer les sévérités est :

Low < Moderate < High < Critical
7. Test de validation — absence de nouvelle vulnérabilité

Une première validation a été réalisée en comparant le rapport courant avec la baseline sans introduire de nouvelle vulnérabilité.

Le résultat obtenu est :

Baseline vulnerabilities : 45
Current vulnerabilities  : 45

PASS: No new advisories or severity increases detected.

Le code de retour obtenu est :

0

Ce résultat démontre que le Security Gate autorise le passage lorsque l'état actuel ne présente aucune nouvelle vulnérabilité ou augmentation de sévérité par rapport à la baseline.

Preuve
docs/screenshots/05-npm-audit/NPM-AUDIT-02-baseline-pass.png
8. Test de blocage d'une vulnérabilité Critical

Afin de vérifier le fonctionnement du mécanisme de blocage, une vulnérabilité Critical synthétique a été ajoutée à une copie du rapport courant.

L'advisory de démonstration utilisé est :

DEMO-CRITICAL-001

avec :

Package  : demo-critical-package
Severity : critical

Le résultat du Security Gate a été :

Baseline vulnerabilities : 45
Current vulnerabilities  : 46

New advisories detected:

Advisory : DEMO-CRITICAL-001
Package  : demo-critical-package
Severity : critical
Title    : Demonstration critical vulnerability

FAIL: New critical vulnerabilities detected.

Le code de retour obtenu est :

1

Un code de retour égal à 1 indique que le Security Gate a bloqué l'exécution.

Preuve
docs/screenshots/05-npm-audit/NPM-AUDIT-03-critical-blocked.png
Important

La vulnérabilité DEMO-CRITICAL-001 est une vulnérabilité synthétique créée uniquement pour tester le mécanisme de sécurité.

Elle ne correspond pas à une nouvelle vulnérabilité introduite dans les dépendances réelles du projet.

Le fichier de test utilisé pour cette démonstration est donc uniquement un artefact de validation locale.

9. Intégration dans GitHub Actions

Le contrôle SCA a été intégré dans :

.github/workflows/devsecops.yml

Le job correspondant est :

sca:
  runs-on: ubuntu-latest
  needs: build

Le processus exécuté par GitHub Actions est le suivant :

Checkout repository
        |
        v
Setup Node.js 24
        |
        v
npm install
        |
        v
npm audit --json
        |
        v
npm-audit-current.json
        |
        v
compare-npm-audit.ps1
        |
        v
SCA Security Gate

Le résultat du contrôle dépend ensuite de la comparaison avec la baseline.

10. Gestion du code de retour de npm audit

npm audit peut retourner un code de sortie différent de zéro lorsqu'il détecte des vulnérabilités.

Dans le contexte de ce projet, cela ne doit pas provoquer directement l'arrêt du job.

La raison est que les vulnérabilités initiales sont déjà connues et documentées dans la baseline.

Le workflow utilise donc :

continue-on-error: true

pour l'étape de génération du rapport.

La décision de sécurité finale est ensuite prise par :

scripts/compare-npm-audit.ps1

Cela permet de séparer :

Détection
    |
    v
npm audit
    |
    v
Rapport JSON
    |
    v
Décision de sécurité
    |
    v
Security Gate
11. Politique de sécurité SCA

La politique mise en place est la suivante :

Situation	Résultat
Aucune nouvelle vulnérabilité	PASS
Vulnérabilité déjà présente dans la baseline	PASS
Nouvelle vulnérabilité non-Critical	WARNING
Nouvelle vulnérabilité Critical	BLOCK
Augmentation de sévérité	WARNING ou BLOCK selon la sévérité finale
Augmentation vers Critical	BLOCK

Cette politique permet de prendre en compte l'état initial volontairement vulnérable de Juice Shop tout en empêchant l'introduction de nouvelles vulnérabilités critiques.

12. Validation dans GitHub Actions

Après l'intégration du job SCA, le pipeline DevSecOps complet a été exécuté sur GitHub Actions.

L'exécution finale a obtenu le statut :

Success

Les différents contrôles ont été validés :

Build       : PASS
Semgrep     : PASS
Gitleaks    : PASS
SCA         : PASS

La capture correspondante est disponible dans :

docs/screenshots/09-github-actions/GHA-02-full-security-pipeline-success.png

Cette validation confirme que le contrôle SCA fonctionne correctement dans l'environnement CI/CD.

13. Sécurisation des GitHub Actions

Lors de la première exécution du pipeline, Semgrep a détecté deux références mutables introduites dans le nouveau job SCA :

actions/checkout@v5
actions/setup-node@v5

Afin de respecter une approche de sécurisation de la chaîne CI/CD, ces références ont été remplacées par des références immuables basées sur des commit SHA.

Le job SCA utilise désormais :

uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5.1.0

et :

uses: actions/setup-node@a0853c24544627f65ddf259abe73b1d18a591444 # v5.0.0

Cette correction a permis au contrôle Semgrep de valider le workflow.

14. Fichiers de l'implémentation

Les principaux fichiers associés à l'intégration SCA sont :

.github/workflows/devsecops.yml
npm-audit-baseline.json
scripts/compare-npm-audit.ps1

Les rapports suivants ont été utilisés lors des tests locaux :

npm-audit-current.json
npm-audit-test-critical.json

Ces fichiers de test ne constituent pas la baseline et ne doivent pas être utilisés comme référence de sécurité.

15. Commits associés

L'intégration du SCA a été enregistrée avec le commit :

50faff79c — ci: add npm audit SCA security gate

Une correction de sécurisation des références GitHub Actions a ensuite été enregistrée avec :

3232f930e — ci: pin SCA GitHub Actions

Le pipeline a ensuite été exécuté avec succès sur GitHub Actions.

16. Résultat

La fonctionnalité SCA est désormais intégrée au pipeline DevSecOps.

Elle permet de :

analyser les dépendances Node.js avec npm audit ;
conserver une baseline des vulnérabilités existantes ;
générer un rapport JSON lors de chaque exécution ;
détecter les nouvelles vulnérabilités ;
détecter les augmentations de sévérité ;
bloquer l'introduction d'une nouvelle vulnérabilité Critical ;
automatiser le contrôle dans GitHub Actions.

Le contrôle SCA constitue ainsi une couche supplémentaire de sécurité dans le pipeline CI/CD, complémentaire au SAST, au secret scanning et aux futurs contrôles DAST et de sécurité des conteneurs.