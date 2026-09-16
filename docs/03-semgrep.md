1. Objectif

Dans cette étape, Semgrep est intégré au pipeline DevSecOps afin d'effectuer une analyse statique du code source (SAST — Static Application Security Testing).

L'objectif est de détecter automatiquement des vulnérabilités dans le code avant qu'une modification puisse être considérée comme acceptable par le pipeline CI/CD.

Contrairement à un simple scan de sécurité exécuté manuellement, l'intégration dans GitHub Actions permet d'automatiser le contrôle de sécurité à chaque modification du projet.

Objectifs spécifiques

Cette étape permet de :

- analyser automatiquement le code source ;
- détecter des patterns de code potentiellement dangereux ;
- identifier les vulnérabilités introduites par une nouvelle modification ;
- éviter de bloquer le pipeline uniquement à cause des vulnérabilités historiques du projet ;
- mettre en place un mécanisme de comparaison avec une version de référence (baseline) ;
- bloquer automatiquement le pipeline lorsqu'une nouvelle vulnérabilité est détectée ;
- vérifier qu'une correction permet ensuite au pipeline de repasser au vert.

Le principe mis en œuvre est donc :

Modification du code
        |
        v
    Semgrep SAST
        |
        v
Comparaison avec baseline
        |
        +--------------------+
        |                    |
        v                    v
Nouvelle vulnérabilité    Aucun nouveau problème
        |                    |
        v                    v
   SECURITY GATE         SECURITY GATE
        |                    |
        v                    v
      BLOCK                 PASS

2. Pourquoi Semgrep ?

Semgrep est utilisé comme outil SAST afin d'analyser le code source à la recherche de patterns correspondant à des pratiques dangereuses ou à des vulnérabilités connues.

Dans notre projet, Semgrep est particulièrement adapté car l'application Juice Shop contient volontairement de nombreuses vulnérabilités.

Un scan complet du projet peut donc produire de nombreux résultats légitimes provenant du code original de Juice Shop.

Le problème serait alors de considérer toutes les vulnérabilités existantes comme de nouvelles vulnérabilités.

Pour éviter cela, nous avons mis en place une analyse différentielle basée sur un commit de référence.

L'objectif devient :

Détecter et bloquer principalement les problèmes de sécurité nouvellement introduits par une modification du code.

Cette approche est particulièrement importante dans un projet pédagogique basé sur une application volontairement vulnérable.

3. Position de Semgrep dans notre architecture DevSecOps

Semgrep intervient dans la deuxième phase de notre pipeline :

                    Developer
                        |
                        | git push / Pull Request
                        v
                  GitHub Repository
                        |
                        v
              +-------------------+
              |       BUILD       |
              |-------------------|
              | Node.js           |
              | npm install       |
              | Tests             |
              +-------------------+
                        |
                        v
              +-------------------+
              |     SECURITY      |
              |-------------------|
              | Semgrep           |
              | Gitleaks          |
              | npm audit         |
              | Docker Scout     |
              | OWASP ZAP         |
              +-------------------+
                        |
                        v
                 Security Gate
                   /       \
                 FAIL      PASS
                  |          |
                  v          v
                STOP      Deployment

Semgrep correspond au contrôle SAST de cette architecture.

4. Préparation de l'environnement
4.1 Vérification de Git

Le projet est versionné avec Git.

Commande utilisée :

git --version

Résultat obtenu :

git version 2.55.0.windows.2
4.2 Vérification de Python

Semgrep est installé à l'aide de Python/pip.

Commande :

python --version

Résultat obtenu :

Python 3.14.7

Vérification de pip :

pip --version

Résultat obtenu :

pip 26.2.1

5. Installation de Semgrep

Semgrep a été installé localement avec pip.

Commande :

python -m pip install semgrep

Vérification :

semgrep --version

Version utilisée pendant le projet :

Semgrep 1.177.0

Cette installation permet de tester les scans localement avant leur exécution dans GitHub Actions.

6. Premier scan local

Avant de mettre en place le Security Gate, un scan complet du projet a été effectué afin d'observer la situation initiale.

Commande :

semgrep --config=auto

L'option :

--config=auto

permet à Semgrep de sélectionner automatiquement une configuration de règles adaptée au code analysé.

7. Résultats du premier scan

Le premier scan local a détecté plusieurs résultats de sécurité.

Résultat initial :

Findings: 70

Répartition observée :

ERROR      18
WARNING    47
MEDIUM      2
INFO        3

Les résultats concernaient notamment :

des injections SQL ;
l'utilisation de eval() ;
des problèmes potentiels liés à Express ;
des secrets ou valeurs ressemblant à des secrets ;
des problèmes de configuration GitHub Actions ;
des problèmes dans des fichiers Terraform ;
des JWT présents dans des fichiers de test.

8. Pourquoi nous ne bloquons pas immédiatement tous les résultats

Le projet utilisé est OWASP Juice Shop.

Cette application est volontairement vulnérable à des fins pédagogiques et de sécurité.

Une partie des findings détectés par Semgrep correspond donc au comportement attendu du projet source.

Par exemple, le scan détecte des problèmes dans :

routes/login.ts
routes/search.ts
routes/userProfile.ts
data/static/codefixes/
.github/workflows/

Si nous appliquions naïvement la règle :

Si Semgrep trouve un résultat
        |
        v
      FAIL

le pipeline serait constamment bloqué à cause de vulnérabilités déjà présentes dans le projet.

Cette approche serait peu pertinente pour notre démonstration DevSecOps.

Nous avons donc choisi une approche différentielle.

9. Mise en place d'une baseline
9.1 Définition

Une baseline correspond à une version de référence du projet.

Dans notre cas, nous utilisons le commit :

92fea16db

comme référence.

Le principe est :

                 BASELINE
             92fea16db
                  |
                  | comparaison
                  v
              Nouveau commit
                  |
                  v
        Nouvelles vulnérabilités

Les problèmes déjà présents dans la baseline ne sont pas considérés comme nouvellement introduits par la modification courante.

10. Test de la baseline en local

Un fichier volontairement vulnérable a été créé afin de démontrer le fonctionnement du mécanisme :

security-demo/vulnerable-example.js

Version vulnérable :

function evaluateExpression(userInput) {
  return eval(userInput)
}

module.exports = { evaluateExpression }

Le problème vient de :

eval(userInput)

eval() permet d'interpréter une chaîne comme du code JavaScript et peut conduire à une injection de code lorsque son contenu peut être contrôlé par une source externe.

11. Premier test Semgrep sur la vulnérabilité

Commande :

semgrep --config=auto security-demo\vulnerable-example.js

Semgrep a détecté :

javascript.browser.security.eval-detected.eval-detected

avec le code :

return eval(userInput)

Le résultat a été classé comme :

Blocking

Ce résultat confirme que Semgrep détecte bien la vulnérabilité volontairement introduite.

12. Importance du suivi Git

Pour utiliser correctement le mécanisme de baseline, le fichier doit être suivi par Git.

Le fichier a donc été ajouté à l'index :

git add security-demo\vulnerable-example.js

Puis le scan différentiel a été exécuté :

semgrep scan --config=auto --baseline-commit 92fea16db

Résultat :

Current version has 1 finding.

Semgrep a identifié le fichier comme nouveau par rapport à la baseline.

Résultat :

Findings: 1 (1 blocking)

Cela valide le fonctionnement du mécanisme différentiel.

13. Intégration dans GitHub Actions

Le workflow DevSecOps utilisé est :

.github/workflows/devsecops.yml

Il contient notamment les jobs :

build
semgrep

Le job Semgrep dépend du job Build.

La structure est donc :

build
  |
  v
semgrep

Le scan de sécurité ne démarre donc qu'après validation de la phase de build.

14. Configuration du job Semgrep

La configuration utilisée est la suivante :

semgrep:
  runs-on: ubuntu-latest
  needs: build

  steps:
    - name: Checkout repository
      uses: actions/checkout@v5
      with:
        fetch-depth: 0

    - name: Setup Python
      uses: actions/setup-python@v6
      with:
        python-version: "3.x"

    - name: Install Semgrep
      run: python -m pip install semgrep

    - name: Determine baseline commit
      id: baseline
      shell: bash
      run: |
        if [ "${{ github.event_name }}" = "pull_request" ]; then
          BASELINE_COMMIT="${{ github.event.pull_request.base.sha }}"
        else
          BASELINE_COMMIT="${{ github.event.before }}"
        fi

        echo "Baseline commit: $BASELINE_COMMIT"
        echo "commit=$BASELINE_COMMIT" >> "$GITHUB_OUTPUT"

    - name: Run Semgrep differential scan
      run: |
        semgrep scan \
          --config=auto \
          --baseline-commit "${{ steps.baseline.outputs.commit }}" \
          --error

15. Explication de la configuration
15.1 needs: build
needs: build

Cette instruction signifie que le job Semgrep dépend du job Build.

Le pipeline suit donc :

Build
  |
  | SUCCESS
  v
Semgrep

Si le Build échoue, le contrôle SAST ne doit pas être considéré comme l'étape suivante du pipeline.

15.2 actions/checkout
uses: actions/checkout@v5

Cette action récupère le dépôt Git dans l'environnement du runner GitHub Actions.

15.3 fetch-depth: 0
fetch-depth: 0

Cette option permet de récupérer l'historique Git nécessaire au fonctionnement de la comparaison avec le commit de référence.

Elle est importante pour notre approche basée sur une baseline Git.

15.4 Installation de Python
uses: actions/setup-python@v6

Cette étape prépare l'environnement Python utilisé pour installer Semgrep.

15.5 Installation de Semgrep
python -m pip install semgrep

Semgrep est installé directement dans l'environnement du runner.

16. Détermination dynamique de la baseline

La baseline est déterminée différemment selon le type d'événement GitHub.

Pour une Pull Request :

BASELINE_COMMIT="${{ github.event.pull_request.base.sha }}"

La comparaison se fait donc avec le commit de base de la Pull Request.

Pour un push :

BASELINE_COMMIT="${{ github.event.before }}"

La comparaison se fait avec le commit précédent.

Le principe est donc :

Pull Request
     |
     v
Commit de base
     |
     v
Commit modifié


Push
     |
     v
Commit précédent
     |
     v
Nouveau commit

Cette logique permet d'éviter de coder manuellement un commit de référence différent à chaque modification.

17. Le paramètre --baseline-commit

La commande principale est :

semgrep scan \
  --config=auto \
  --baseline-commit "${{ steps.baseline.outputs.commit }}" \
  --error

Le paramètre :

--baseline-commit

permet de comparer l'état actuel du code avec une version de référence.

Dans notre démonstration, cela permet de distinguer :

Vulnérabilités historiques
        |
        v
       BASE
        |
        | comparaison
        v
Nouvelles vulnérabilités

18. Le paramètre --error

Le paramètre :

--error

est utilisé pour transformer la présence de findings bloquants en échec du processus.

C'est ce comportement qui permet de transformer Semgrep en véritable Security Gate.

Sans ce mécanisme, Semgrep pourrait simplement afficher les résultats sans empêcher la poursuite du pipeline.

Avec :

--error

le pipeline peut recevoir un code de sortie différent de zéro lorsqu'un finding bloquant est présent.

19. Validation du Security Gate — scénario FAIL

Pour démontrer que le Security Gate fonctionne réellement, nous avons volontairement introduit une vulnérabilité.

Fichier :

security-demo/vulnerable-example.js

Code vulnérable :

function evaluateExpression(userInput) {
  return eval(userInput)
}

module.exports = { evaluateExpression }

Commit utilisé :

eb3c5ec1d

Message :

test: introduce vulnerable code for Semgrep gate

20. Résultat du scénario FAIL

GitHub Actions a exécuté :

semgrep scan

Semgrep a détecté :

security-demo/vulnerable-example.js

avec la règle :

javascript.browser.security.eval-detected.eval-detected

et :

return eval(userInput)

Résultat :

Current version has 1 finding.

Puis :

Findings: 1 (1 blocking)

Enfin :

Error: Process completed with exit code 1.

Le Security Gate a donc correctement bloqué la modification.

21. Interprétation du résultat FAIL

Le résultat peut être représenté ainsi :

Commit
  |
  v
security-demo/vulnerable-example.js
  |
  v
eval(userInput)
  |
  v
Semgrep
  |
  v
1 finding
  |
  v
1 blocking
  |
  v
--error
  |
  v
Exit code 1
  |
  v
❌ SECURITY GATE FAIL

Cette étape démontre que le pipeline ne se contente pas de détecter une vulnérabilité.

Il est capable de :

détecter ;
qualifier ;
bloquer.

22. Remédiation de la vulnérabilité

Après avoir validé le scénario FAIL, le code a été corrigé.

Ancienne version :

function evaluateExpression(userInput) {
  return eval(userInput)
}

Nouvelle version :

function evaluateExpression(userInput) {
  return userInput
}

La modification consiste à ne plus interpréter userInput comme du code.

Le programme retourne désormais directement la valeur fournie.

23. Vérification locale après correction

Avant de pousser la correction vers GitHub, un nouveau scan local a été effectué :

semgrep scan --config=auto security-demo\vulnerable-example.js

Résultat :

Findings: 0 (0 blocking)

et :

Ran 200 rules on 1 file: 0 findings.

Cette étape permet de vérifier localement que le problème détecté précédemment n'est plus présent.

24. Vérification du changement Git

Avant le commit, la différence a été vérifiée avec :

git diff -- .\security-demo\vulnerable-example.js

Diff obtenu :

-  return eval(userInput)
+  return userInput

Cette vérification permet de s'assurer que seule la correction attendue est appliquée.

25. Commit de remédiation

La correction a été enregistrée avec le commit :

412952d72

Message :

fix: remediate Semgrep eval vulnerability

Le commit contient :

1 file changed
1 insertion(+)
1 deletion(-)

26. Validation finale dans GitHub Actions

Après le push du commit de correction, GitHub Actions a relancé le pipeline.

Semgrep a obtenu :

Current version has 0 findings.

Puis :

Findings: 0 (0 blocking)

et :

Scan completed successfully.

Résultat final :

Ran 200 rules on 1 file: 0 findings.

Le Security Gate est donc passé de :

❌ FAIL

à :

✅ PASS

27. Démonstration complète du cycle DevSecOps

Cette expérience permet de démontrer un cycle complet :

              Développement
                    |
                    v
        Introduction d'une vulnérabilité
                    |
                    v
              Git commit
                    |
                    v
             GitHub Actions
                    |
                    v
               Semgrep
                    |
                    v
             Vulnerability
                    |
                    v
          ❌ Security Gate FAIL
                    |
                    v
               Remédiation
                    |
                    v
             Nouveau commit
                    |
                    v
             GitHub Actions
                    |
                    v
               Semgrep
                    |
                    v
              0 findings
                    |
                    v
          ✅ Security Gate PASS

Ce scénario constitue la démonstration principale de l'intégration SAST dans notre pipeline.

28. Pourquoi cette approche est adaptée à Juice Shop ?

OWASP Juice Shop est volontairement vulnérable.

Par conséquent, un simple scan complet avec :

semgrep --config=auto

peut détecter de nombreuses vulnérabilités déjà présentes dans le projet.

Le rôle de notre mécanisme de baseline est de distinguer :

Vulnérabilités existantes

de :

Vulnérabilités nouvellement introduites

Ainsi, nous ne cherchons pas à rendre Juice Shop totalement exempt de vulnérabilités.

L'objectif est de démontrer une pratique DevSecOps réaliste :

empêcher l'introduction de nouvelles vulnérabilités tout en tenant compte de la dette de sécurité existante.

29. Politique de sécurité envisagée

Dans la suite du pipeline, Semgrep constitue le premier Security Gate SAST.

La philosophie retenue est :

Situation	Décision
Vulnérabilité historique	Ne pas bloquer automatiquement
Nouvelle vulnérabilité critique	BLOCK
Nouvelle vulnérabilité élevée	BLOCK
Nouveau problème moyen	WARNING / analyse
Problème faible ou informatif	INFORMATION
Nouveau secret détecté	BLOCK

Cette politique pourra être renforcée ou adaptée lorsque les autres outils de sécurité seront intégrés.

30. Captures d'écran

Les preuves de cette étape sont conservées dans :

docs/screenshots/03-semgrep/

Structure :

03-semgrep/
├── SEMGREP-01-github-actions-success.png
├── SEMGREP-02-scan-summary.png
├── SEMGREP-03-baseline-pass.png
├── SEMGREP-04-new-vulnerability-blocked.png
└── SEMGREP-05-vulnerability-fixed.png

Les captures documentent les différentes étapes de mise en place du SAST, depuis l'intégration dans GitHub Actions jusqu'à la détection, au blocage et à la correction d'une vulnérabilité.

31. Description des preuves

SEMGREP-01 — Intégration de Semgrep dans GitHub Actions

Cette capture montre l'exécution réussie du workflow GitHub Actions après l'intégration de Semgrep dans le pipeline DevSecOps.

Elle constitue la preuve que :

Semgrep est correctement intégré dans GitHub Actions ;
le job dédié à l'analyse SAST est exécuté automatiquement ;
l'analyse de sécurité fait désormais partie du processus CI/CD ;
le pipeline peut exécuter Semgrep dans un environnement automatisé.

Cette étape valide l'intégration technique de Semgrep dans notre pipeline.

SEMGREP-02 — Résultats du scan Semgrep

Cette capture présente le résumé des résultats produits par Semgrep lors de l'analyse du projet.

Elle permet de visualiser notamment :

le nombre de règles exécutées ;
le nombre de fichiers analysés ;
le nombre de findings détectés ;
les différents problèmes de sécurité identifiés dans le code source.

Cette capture constitue la preuve que Semgrep est capable d'analyser le code du projet et d'identifier automatiquement des patterns de sécurité potentiellement dangereux.

SEMGREP-03 — Validation du mécanisme de baseline

Cette capture montre la validation du mécanisme de comparaison avec une baseline Git.

Le scan différentiel compare l'état actuel du projet avec un commit de référence afin d'identifier les problèmes nouvellement introduits.

Dans cette étape, les findings déjà présents dans la version de référence ne sont pas considérés comme de nouvelles vulnérabilités.

Cette approche est particulièrement importante pour OWASP Juice Shop, qui contient volontairement de nombreuses vulnérabilités.

La capture constitue donc la preuve que le mécanisme de baseline permet d'effectuer une analyse ciblée sur les changements introduits dans le code.

SEMGREP-04 — Détection et blocage d'une nouvelle vulnérabilité

Cette capture présente le scénario de test dans lequel une vulnérabilité a volontairement été introduite dans :

security-demo/vulnerable-example.js

Le code introduit contenait l'utilisation de :

eval(userInput)

Semgrep a détecté cette utilisation à l'aide de la règle :

javascript.browser.security.eval-detected.eval-detected

Le résultat indique :

Findings: 1 (1 blocking)

L'utilisation du paramètre --error entraîne ensuite l'échec du processus :

Process completed with exit code 1

Cette capture constitue la preuve du fonctionnement du Security Gate : lorsqu'une nouvelle vulnérabilité bloquante est introduite, le pipeline est arrêté.

Le scénario démontré est donc :

Nouvelle vulnérabilité
        ↓
Semgrep
        ↓
1 finding
        ↓
1 blocking
        ↓
Exit code 1
        ↓
Security Gate FAIL

SEMGREP-05 — Correction et validation de la vulnérabilité

Cette capture présente le résultat obtenu après la correction de la vulnérabilité précédemment détectée.

L'utilisation dangereuse de :

eval(userInput)

a été supprimée et remplacée par une utilisation directe de la valeur :

return userInput

Un nouveau scan Semgrep a ensuite été exécuté afin de vérifier la correction.

Le résultat obtenu est :

Current version has 0 findings.

ainsi que :

Findings: 0 (0 blocking)

Cette capture constitue la preuve que :

la vulnérabilité précédemment détectée a été corrigée ;
Semgrep ne détecte plus le problème dans le fichier concerné ;
le Security Gate peut désormais valider la modification ;
le pipeline peut poursuivre son exécution.

Le scénario complet est donc :

Vulnérabilité détectée
        ↓
Security Gate FAIL
        ↓
Correction du code
        ↓
Nouveau scan Semgrep
        ↓
0 finding
        ↓
Security Gate PASS

32. Résumé technique
Élément	Valeur
Outil	Semgrep
Fonction	SAST
Intégration	GitHub Actions
Configuration	--config=auto
Mode	Analyse différentielle
Baseline	Commit Git de référence
Security Gate	--error
Vulnérabilité de démonstration	eval(userInput)
Résultat avant correction	1 finding / 1 blocking
Résultat après correction	0 finding
Action en cas de finding bloquant	Pipeline FAIL
Action après correction	Pipeline PASS

33. Commandes principales utilisées
Installation
python -m pip install semgrep
Vérification de la version
semgrep --version
Scan complet
semgrep --config=auto
Scan ciblé
semgrep --config=auto security-demo\vulnerable-example.js
Scan différentiel
semgrep scan --config=auto --baseline-commit 92fea16db
Vérification Git
git status
Vérification du diff
git diff -- .\security-demo\vulnerable-example.js
Ajout de la correction
git add .\security-demo\vulnerable-example.js
Commit
git commit -m "fix: remediate Semgrep eval vulnerability"
Push
git push origin master

34. Résultat de l'étape

L'intégration de Semgrep dans le pipeline DevSecOps est validée.

Les objectifs suivants ont été atteints :

 Installation de Semgrep
 Premier scan local
 Analyse des résultats
 Identification du problème des vulnérabilités historiques
 Mise en place d'une baseline Git
 Configuration du scan différentiel
 Intégration dans GitHub Actions
 Détection d'une nouvelle vulnérabilité
 Blocage automatique du pipeline
 Correction de la vulnérabilité
 Vérification locale après correction
 Validation de la correction dans GitHub Actions
 Passage du Security Gate de FAIL à PASS
 Conservation des preuves sous forme de captures d'écran

35. Conclusion

Semgrep est désormais intégré comme mécanisme SAST du pipeline DevSecOps.

L'approche retenue ne consiste pas simplement à exécuter un scan de sécurité, mais à intégrer les résultats du scan dans le processus de livraison.