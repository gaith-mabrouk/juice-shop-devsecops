1. Objectif

GitHub Actions est utilisé comme moteur CI/CD du projet DevSecOps.

Il permet d'automatiser l'exécution des différentes étapes du pipeline à chaque modification du dépôt GitHub.

Dans cette première étape, GitHub Actions est utilisé pour automatiser la phase de Build et vérifier que l'application peut être installée et testée correctement dans un environnement propre.

Cette première version constitue la base du pipeline DevSecOps. Les différents contrôles de sécurité seront intégrés progressivement dans les étapes suivantes.

2. Pourquoi GitHub Actions ?

GitHub Actions a été choisi comme outil CI/CD car il est directement intégré à GitHub, qui héberge le dépôt du projet.

Cette intégration permet de déclencher automatiquement le pipeline lors :

d'un push sur le dépôt ;
de la création ou modification d'une Pull Request.

L'utilisation de GitHub Actions permet également d'exécuter le pipeline dans un environnement Linux fourni par GitHub, sans avoir besoin de maintenir une infrastructure CI dédiée.

Alternative étudiée : Jenkins

Jenkins a également été considéré comme une solution CI/CD possible.

Cependant, il n'a pas été retenu dans cette architecture afin d'éviter d'ajouter une infrastructure CI supplémentaire au projet. GitHub Actions répond directement au besoin d'automatisation tout en restant intégré au dépôt GitHub.

3. Architecture du pipeline

L'architecture globale prévue pour le projet est la suivante :

Developer
    |
    | git push / Pull Request
    v
GitHub Repository
    |
    v
GitHub Actions
    |
    v
+-----------------------+
|        BUILD          |
|-----------------------|
| Checkout              |
| Node.js 24            |
| npm install           |
| npm test              |
+-----------------------+
    |
    v
+-----------------------+
|      SECURITY         |
|-----------------------|
| Semgrep               |
| Gitleaks              |
| npm audit             |
| Docker Scout          |
| OWASP ZAP             |
+-----------------------+
    |
    v
+-----------------------+
|    SECURITY GATE      |
+-----------------------+
    |
    +------ FAIL ------> STOP
    |
    +------ PASS ------> Deployment

La première version de GitHub Actions implémente uniquement la partie Build.

Les outils de sécurité seront ajoutés progressivement.

4. Emplacement du workflow

Le workflow personnalisé est situé dans :

.github/workflows/devsecops.yml

Le projet contient également plusieurs workflows provenant du projet Juice Shop. Le workflow devsecops.yml est notre workflow personnalisé pour le projet DevSecOps.

5. Configuration initiale du workflow

Le workflow utilisé pour cette première étape est :

name: DevSecOps Pipeline

on:
  push:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Setup Node.js
        uses: actions/setup-node@v5
        with:
          node-version: 24

      - name: Install dependencies
        run: npm install

      - name: Run tests
        run: npm test

6. Déclenchement du workflow

Le workflow contient :

on:
  push:
  pull_request:
6.1 Push

Lorsqu'un nouveau commit est envoyé vers GitHub avec :

git push

GitHub Actions détecte automatiquement la modification et démarre le workflow.

C'est ce mécanisme qui a permis de déclencher automatiquement notre première exécution après l'envoi du workflow sur GitHub.

6.2 Pull Request

Le workflow peut également être exécuté lorsqu'une Pull Request est créée ou mise à jour.

Cela permettra par la suite de vérifier automatiquement les modifications avant leur intégration dans la branche principale.

7. Job Build

Le workflow contient actuellement un job appelé :

jobs:
  build:

Le job est exécuté sur :

runs-on: ubuntu-latest

Cela signifie que GitHub fournit un runner Linux temporaire pour exécuter les différentes commandes du pipeline.

Le runner récupère le code du projet, configure Node.js, installe les dépendances puis exécute les tests.

8. Étape 1 : Checkout du dépôt

La première étape est :

- name: Checkout repository
  uses: actions/checkout@v5

Cette action permet de récupérer le contenu du dépôt GitHub dans l'environnement du runner.

Le runner doit disposer du code source du projet avant de pouvoir exécuter les commandes suivantes.

Le processus est donc :

GitHub Repository
       |
       v
actions/checkout
       |
       v
Code source disponible sur le runner

La version v5 de l'action est utilisée afin d'utiliser la version actuelle de l'action basée sur Node.js 24.

9. Étape 2 : Configuration de Node.js

La deuxième étape est :

- name: Setup Node.js
  uses: actions/setup-node@v5
  with:
    node-version: 24

Cette étape configure Node.js 24 dans l'environnement GitHub Actions.

Le choix de Node.js 24 est cohérent avec l'environnement utilisé localement pour le projet.

L'objectif est de réduire les différences entre l'environnement de développement et l'environnement CI.

Runner GitHub
      |
      v
Setup Node.js
      |
      v
Node.js 24
10. Étape 3 : Installation des dépendances

L'étape suivante est :

- name: Install dependencies
  run: npm install

Cette commande installe les dépendances nécessaires au projet Juice Shop.

Pourquoi npm install et non npm ci ?

Dans l'état actuel du projet, le dépôt ne contient pas de fichier :

package-lock.json

Le fichier .npmrc du projet contient également :

package-lock=false

Par conséquent, npm ci n'est pas adapté à la configuration actuelle du projet puisqu'il nécessite un lockfile compatible.

Nous avons donc conservé :

npm install

Cette commande a été validée avec succès dans l'environnement local puis dans GitHub Actions.

11. Étape 4 : Exécution des tests

Après l'installation des dépendances, le workflow exécute :

- name: Run tests
  run: npm test

Cette étape permet de vérifier automatiquement que les tests du projet passent dans l'environnement CI.

Lors de la validation locale, les tests ont produit le résultat suivant :

537 tests
530 réussis
0 échec
7 ignorés

L'exécution GitHub Actions a également été terminée avec succès.

Le test permet donc de vérifier que l'installation et la compilation du projet n'ont pas introduit de problème bloquant.

12. Première exécution du workflow

Après avoir créé le fichier :

.github/workflows/devsecops.yml

le workflow a été enregistré dans Git avec le commit :

ci: add initial DevSecOps workflow

Puis le commit a été envoyé vers GitHub.

GitHub Actions a automatiquement détecté le push et exécuté le workflow.

La première exécution a réussi.

13. Warning concernant Node.js 20

Lors de la première exécution, le job a réussi mais GitHub Actions a affiché un avertissement :

Node.js 20 is deprecated.
The following actions target Node.js 20 but are being forced to run on Node.js 24:
actions/checkout@v4
actions/setup-node@v4

Il est important de distinguer deux éléments :

Node.js utilisé par notre application
        |
        +--> Node.js 24

et :

Runtime utilisé par certaines versions des GitHub Actions
        |
        +--> Node.js 20

Le warning ne signifiait donc pas que notre application utilisait Node.js 20.

Il concernait les versions des actions utilisées par le workflow.

14. Correction du warning

Afin d'utiliser les versions récentes des actions GitHub, les versions suivantes ont été mises à jour :

actions/checkout@v4
        ↓
actions/checkout@v5

et :

actions/setup-node@v4
        ↓
actions/setup-node@v5

Le changement a été enregistré dans le commit :

a4a74e739 ci: update GitHub Actions to Node 24

Puis le commit a été envoyé vers GitHub.

15. Validation après correction

Une nouvelle exécution du workflow a été automatiquement déclenchée après le push.

Le résultat obtenu est :

DevSecOps Pipeline
        |
        v
      build
        |
        +--> Checkout repository      ✓
        |
        +--> Setup Node.js            ✓
        |
        +--> Install dependencies     ✓
        |
        +--> Run tests                ✓
        |
        v
      SUCCESS

La nouvelle exécution s'est terminée avec succès et le warning concernant Node.js 20 n'est plus présent.

16. Résultat final

La première version de notre pipeline CI est donc fonctionnelle.

Le processus automatisé est actuellement :

git push
    |
    v
GitHub
    |
    v
GitHub Actions
    |
    v
Checkout repository
    |
    v
Setup Node.js 24
    |
    v
npm install
    |
    v
npm test
    |
    v
BUILD VALIDATED

Les principales étapes ont toutes été validées avec succès :

Étape	Résultat
Checkout repository	✅ SUCCESS
Setup Node.js 24	✅ SUCCESS
Install dependencies	✅ SUCCESS
Run tests	✅ SUCCESS
GitHub Actions job	✅ SUCCESS
17. Preuve d'exécution

La réussite du pipeline est documentée par la capture d'écran :

docs/screenshots/09-github-actions/GHA-01-pipeline-build-success.png

Cette capture montre l'exécution du workflow DevSecOps Pipeline ainsi que la réussite des différentes étapes du job build.

18. Commits associés

Les principales modifications réalisées pour cette étape sont :

Création du workflow
161cd4783
ci: add initial DevSecOps workflow
Mise à jour des actions GitHub
a4a74e739
ci: update GitHub Actions to Node 24

Ces commits permettent de conserver une trace des évolutions de la configuration CI.

19. Limites de cette première version

Cette première version constitue uniquement la base CI du projet.

Elle ne réalise pas encore les contrôles de sécurité.

Les étapes suivantes devront intégrer progressivement :

SAST
 |
 +--> Semgrep

Secret Scanning
 |
 +--> Gitleaks

SCA
 |
 +--> npm audit

Container Security
 |
 +--> Docker Scout

DAST
 |
 +--> OWASP ZAP

Une Security Gate sera ensuite mise en place afin de déterminer si les résultats de sécurité permettent de poursuivre ou d'arrêter le pipeline.

20. Évolution prévue

L'objectif final est d'obtenir un pipeline similaire à :

                    Git Push / Pull Request
                              |
                              v
                    +-------------------+
                    |   GitHub Actions  |
                    +-------------------+
                              |
                              v
                    +-------------------+
                    |       BUILD       |
                    |-------------------|
                    | Node.js           |
                    | npm install       |
                    | npm test          |
                    | Docker build      |
                    +-------------------+
                              |
                              v
                    +-------------------+
                    |     SECURITY      |
                    |-------------------|
                    | Semgrep           |
                    | Gitleaks          |
                    | npm audit         |
                    | Docker Scout      |
                    | OWASP ZAP         |
                    +-------------------+
                              |
                              v
                    +-------------------+
                    |  SECURITY GATE    |
                    +-------------------+
                         /          \
                      FAIL          PASS
                       |              |
                       v              v
                     STOP       Docker Hub
                                    |
                                    v
                                  Render

Cette architecture permettra d'appliquer le principe Security by Design / Shift Left, en intégrant progressivement les contrôles de sécurité directement dans le processus CI/CD.

21. Conclusion

La mise en place de GitHub Actions constitue la première étape de l'automatisation du projet DevSecOps.

Le pipeline est maintenant capable de récupérer automatiquement le code source, configurer Node.js 24, installer les dépendances et exécuter les tests.

Cette base CI permettra d'intégrer progressivement les outils de sécurité du projet.

La prochaine étape consiste à intégrer Semgrep afin d'ajouter une première analyse de sécurité de type SAST (Static Application Security Testing) au pipeline.