# 🎣 Spécification : Hook Auto-Détection de Bugs MCP Serenity

**Projet:** Hook intelligent pour détection et création automatique d'issues GitHub  
**Cible:** Erreurs dans les outils MCP Serenity  
**Date:** 2026-01-12  
**Version:** 1.0

---

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Objectifs](#objectifs)
3. [Architecture](#architecture)
4. [Spécifications techniques](#spécifications-techniques)
5. [Implémentation](#implémentation)
6. [Tests](#tests)
7. [Déploiement](#déploiement)
8. [Maintenance](#maintenance)

---

## 🎯 Vue d'ensemble

### Problème
Les outils MCP Serenity peuvent échouer de deux façons :
- **Bugs de code** : erreurs serveur, exceptions non gérées, comportements inattendus
- **Erreurs d'utilisation** : mauvais paramètres, ressources inexistantes, permissions manquantes

Actuellement, **tous les types d'erreurs** nécessitent une intervention manuelle pour être signalés.

### Solution
Implémenter un **hook PostToolUse** qui :
1. Détecte automatiquement les erreurs MCP Serenity
2. Utilise l'intelligence de Claude pour analyser la nature de l'erreur
3. Crée automatiquement une issue GitHub pour les bugs de code
4. Ignore les erreurs d'utilisation (déjà visibles pour l'utilisateur)

### Bénéfices
- ✅ Détection proactive des bugs
- ✅ Réduction du temps de signalement
- ✅ Documentation automatique des erreurs
- ✅ Traçabilité complète
- ✅ Pas de faux positifs (intelligence de Claude)

---

## 🎯 Objectifs

### Objectifs principaux
1. **Détecter** automatiquement les erreurs dans les outils `mcp__mcp-serenity__*`
2. **Analyser** intelligemment via Claude si c'est un bug ou une erreur utilisateur
3. **Créer** automatiquement une issue GitHub pour les bugs uniquement
4. **Documenter** chaque erreur avec contexte complet

### Objectifs secondaires
1. Éviter les doublons d'issues
2. Logger toutes les analyses pour audit
3. Permettre la désactivation temporaire du système
4. Fournir des métriques sur les erreurs détectées

### Non-objectifs
- ❌ Corriger automatiquement les bugs
- ❌ Bloquer l'exécution en cas d'erreur
- ❌ Remplacer la revue humaine des bugs complexes

---

## 🏗️ Architecture

### Schéma de flux

```
┌─────────────────────────────────────────────────────────────────┐
│                    Utilisateur demande action                    │
└──────────────────────────────┬──────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│            Claude exécute outil mcp__mcp-serenity__*            │
└──────────────────────────────┬──────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
            ┌──────────────┐        ┌──────────────┐
            │   Succès     │        │    Erreur    │
            └──────────────┘        └──────┬───────┘
                                           │
                                           ▼
            ┌──────────────────────────────────────────────┐
            │    Hook PostToolUse activé automatiquement   │
            └──────────────────┬───────────────────────────┘
                               │
                               ▼
            ┌──────────────────────────────────────────────┐
            │  Hook extrait : tool_name, tool_input,       │
            │                 tool_response, error         │
            └──────────────────┬───────────────────────────┘
                               │
                               ▼
            ┌──────────────────────────────────────────────┐
            │  Hook injecte contexte d'analyse à Claude    │
            │  avec prompt d'analyse de l'erreur           │
            └──────────────────┬───────────────────────────┘
                               │
                               ▼
            ┌──────────────────────────────────────────────┐
            │     Claude analyse l'erreur intelligemment   │
            └──────────────────┬───────────────────────────┘
                               │
                   ┌───────────┴───────────┐
                   │                       │
                   ▼                       ▼
           ┌───────────────┐      ┌────────────────┐
           │  BUG DE CODE  │      │ ERREUR UTILIS. │
           └───────┬───────┘      └────────┬───────┘
                   │                       │
                   ▼                       ▼
    ┌──────────────────────────┐  ┌───────────────────┐
    │ Claude crée issue GitHub │  │ Continue normal   │
    │ via MCP github_*         │  │ (pas d'issue)     │
    └──────────┬───────────────┘  └───────────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Issue créée avec labels: │
    │ - bug                    │
    │ - auto-detected          │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Claude informe utilisat. │
    │ "✅ Issue #42 créée"     │
    └──────────────────────────┘
```

### Composants

#### 1. Hook PostToolUse (`post-tool-use.sh`)
- **Rôle** : Détection d'erreurs et injection de contexte
- **Langage** : Bash
- **Localisation** : `.claude/hooks/post-tool-use.sh`
- **Dépendances** : `jq`

#### 2. Analyse Claude
- **Rôle** : Classification intelligente bug vs erreur utilisateur
- **Déclencheur** : Contexte injecté par le hook
- **Outils utilisés** : `mcp__mcp-serenity__github_catalog_execute_tool`

#### 3. Logger (optionnel)
- **Rôle** : Traçabilité et audit
- **Localisation** : `.claude/logs/error-analysis.log`
- **Format** : JSON Lines

#### 4. Configuration
- **Fichier** : `.claude/settings.json`
- **Section** : `hooks.PostToolUse`

---

## 🔧 Spécifications techniques

### 1. Format d'entrée du hook

Le hook reçoit via **stdin** un JSON avec cette structure :

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript",
  "cwd": "/home/tincenv/vide",
  "permission_mode": "auto",
  "hook_event_name": "PostToolUse",
  "tool_name": "mcp__mcp-serenity__devbox_exec",
  "tool_input": {
    "command": "ls -la /nonexistent",
    "timeout": 30
  },
  "tool_response": {
    "isError": true,
    "error": "Command failed: ls: cannot access '/nonexistent': No such file or directory",
    "exit_code": 2
  }
}
```

### 2. Critères de détection d'erreur

Une erreur MCP Serenity est détectée si :
1. `tool_name` commence par `mcp__mcp-serenity__`
2. ET `tool_response.isError == true`
3. OU `tool_response.error` est non vide
4. OU `tool_response.exit_code != 0` (pour devbox_exec)

### 3. Prompt d'analyse pour Claude

Le hook doit injecter ce contexte structuré qui guide Claude dans son analyse :

```markdown
🔍 **ERREUR MCP-SERENITY DÉTECTÉE**

**Outil:** `{tool_name}`
**Paramètres:** 
\`\`\`json
{tool_input}
\`\`\`

**Erreur:**
\`\`\`
{error_message}
\`\`\`

**Détails techniques:**
- Exit code: {exit_code}
- Session: {session_id}
- Timestamp: {timestamp}

---

**ACTION REQUISE:** Analyse cette erreur et détermine sa nature.

## Critères de classification

### ✅ C'est un BUG de code si :
- Erreur serveur interne (500, 502, 503)
- Exception/Traceback non gérée
- Crash inattendu du serveur
- Comportement incohérent vs documentation
- Null/undefined reference
- Timeout côté serveur (pas client)
- Erreur de base de données inattendue
- Erreur de syntaxe dans le code du serveur

**Exemples de bugs :**
- "Internal Server Error 500"
- "Traceback (most recent call last):"
- "AttributeError: 'NoneType' object has no attribute"
- "Unexpected token in JSON"
- "Server crashed during operation"

### ❌ C'est une ERREUR D'UTILISATION si :
- Ressource non trouvée (404)
- Paramètres invalides/manquants (400)
- Permission refusée (401, 403)
- Ressource déjà existante (409)
- Timeout côté client (configuration utilisateur)
- Limite de quota atteinte
- Commande invalide dans devbox_exec
- Fichier inexistant dans devbox_read

**Exemples d'erreurs utilisateur :**
- "Repository not found"
- "Invalid parameter: command is required"
- "Permission denied"
- "File does not exist: /path/to/file"
- "Command not found: nonexistentcommand"

## Actions à prendre

### Si c'est un BUG :
1. Crée immédiatement une issue sur `Serenity-System/mcp-serenity`
2. Utilise l'outil : `mcp__mcp-serenity__github_catalog_execute_tool`
3. Outil à appeler : `github_issue_create`
4. Paramètres :
   - **owner:** "Serenity-System"
   - **repo:** "mcp-serenity"
   - **title:** "[Auto] Bug détecté dans {tool_name_short}"
   - **body:** (voir template ci-dessous)
   - **labels:** ["bug", "auto-detected"]

### Si c'est une ERREUR D'UTILISATION :
1. N'ouvre PAS d'issue
2. Continue normalement
3. L'erreur est déjà visible pour l'utilisateur

## Template du corps de l'issue

\`\`\`markdown
# Bug auto-détecté dans {tool_name}

## 🔍 Contexte
- **Outil MCP:** `{tool_name}`
- **Date:** {timestamp}
- **Session:** `{session_id}`
- **Détecté par:** Claude Code Hook v1.0

## ❌ Erreur

\`\`\`
{error_message}
\`\`\`

## 📝 Paramètres de l'appel

\`\`\`json
{tool_input}
\`\`\`

## 🔄 Reproduction

[Claude, décris ici comment reproduire le bug étape par étape]

## 💡 Analyse préliminaire

[Claude, analyse ici la cause probable du bug]

## ⚙️ Environnement
- Working directory: {cwd}
- Permission mode: {permission_mode}

---
*Issue créée automatiquement par Claude Code Hook*
\`\`\`

**Maintenant, analyse l'erreur et agis en conséquence.**
```

### 4. Format de sortie du hook

Le hook doit sortir sur **stdout** un JSON :

```json
{
  "add_context": "Le prompt d'analyse complet ici"
}
```

Et terminer avec **exit code 0** pour que Claude traite le contexte injecté.

### 5. Gestion des erreurs du hook

Si le hook échoue :
- **Exit code 2** : Erreur bloquante (affichée à l'utilisateur)
- **Autres codes** : Erreur non-bloquante (logguée en mode verbose)

### 6. Déduplication des issues

Pour éviter les doublons :
1. Avant de créer une issue, chercher via `github_issue_list` :
   - Filter par label `auto-detected`
   - Chercher dans le titre le nom de l'outil
   - Vérifier que l'erreur n'est pas déjà reportée
2. Si doublon trouvé : commenter l'issue existante au lieu de créer une nouvelle

---

## 🛠️ Implémentation

### Phase 1 : Setup de base

#### Étape 1.1 : Créer la structure de dossiers

```bash
# Sur la machine locale (sera sync avec DevBox si besoin)
mkdir -p .claude/hooks
mkdir -p .claude/logs
```

#### Étape 1.2 : Créer le hook PostToolUse

**Fichier:** `.claude/hooks/post-tool-use.sh`

```bash
#!/bin/bash
# Hook PostToolUse - Auto-détection de bugs MCP Serenity
# Version: 1.0
# Date: 2026-01-12

set -euo pipefail

# Configuration
LOG_FILE="${HOME}/.claude/logs/error-analysis.log"
DISABLE_FILE="${HOME}/.claude/.disable-auto-issue"

# Vérifier si le système est désactivé
if [[ -f "$DISABLE_FILE" ]]; then
  exit 0
fi

# Lire l'input JSON depuis stdin
input=$(cat)

# Extraire les champs nécessaires
tool_name=$(echo "$input" | jq -r '.tool_name')
is_error=$(echo "$input" | jq -r '.tool_response.isError // false')
error_msg=$(echo "$input" | jq -r '.tool_response.error // empty')
exit_code=$(echo "$input" | jq -r '.tool_response.exit_code // 0')

# Logger tous les appels d'outils MCP Serenity (pour audit)
if [[ $tool_name == mcp__mcp-serenity__* ]]; then
  echo "$input" | jq -c '{
    timestamp: now | strftime("%Y-%m-%d %H:%M:%S"),
    tool: .tool_name,
    is_error: .tool_response.isError,
    logged_by: "post-tool-use-hook"
  }' >> "$LOG_FILE" 2>/dev/null || true
fi

# Détecter si c'est une erreur MCP Serenity
if [[ $tool_name == mcp__mcp-serenity__* ]] && 
   ([[ "$is_error" == "true" ]] || [[ -n "$error_msg" ]] || [[ "$exit_code" != "0" ]]); then
  
  # Extraire les données complètes
  tool_input=$(echo "$input" | jq -c '.tool_input')
  session_id=$(echo "$input" | jq -r '.session_id')
  cwd=$(echo "$input" | jq -r '.cwd')
  permission_mode=$(echo "$input" | jq -r '.permission_mode')
  timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
  
  # Extraire le nom court de l'outil (sans le préfixe mcp__mcp-serenity__)
  tool_name_short=${tool_name#mcp__mcp-serenity__}
  
  # Construire le prompt d'analyse pour Claude
  analysis_prompt=$(cat <<'EOF'
🔍 **ERREUR MCP-SERENITY DÉTECTÉE**

**Outil:** \`$tool_name\`
**Paramètres:** 
\`\`\`json
$tool_input
\`\`\`

**Erreur:**
\`\`\`
$error_msg
\`\`\`

**Détails techniques:**
- Exit code: $exit_code
- Session: $session_id
- Timestamp: $timestamp

---

**ACTION REQUISE:** Analyse cette erreur et détermine sa nature.

## Critères de classification

### ✅ C'est un BUG de code si :
- Erreur serveur interne (500, 502, 503)
- Exception/Traceback non gérée
- Crash inattendu du serveur
- Comportement incohérent vs documentation
- Null/undefined reference
- Timeout côté serveur (pas client)
- Erreur de base de données inattendue
- Erreur de syntaxe dans le code du serveur

**Exemples de bugs :**
- "Internal Server Error 500"
- "Traceback (most recent call last):"
- "AttributeError: 'NoneType' object has no attribute"
- "Unexpected token in JSON"
- "Server crashed during operation"

### ❌ C'est une ERREUR D'UTILISATION si :
- Ressource non trouvée (404)
- Paramètres invalides/manquants (400)
- Permission refusée (401, 403)
- Ressource déjà existante (409)
- Timeout côté client (configuration utilisateur)
- Limite de quota atteinte
- Commande invalide dans devbox_exec
- Fichier inexistant dans devbox_read

**Exemples d'erreurs utilisateur :**
- "Repository not found"
- "Invalid parameter: command is required"
- "Permission denied"
- "File does not exist: /path/to/file"
- "Command not found: nonexistentcommand"

## Actions à prendre

### Si c'est un BUG :
1. Crée immédiatement une issue sur \`Serenity-System/mcp-serenity\`
2. Utilise l'outil : \`mcp__mcp-serenity__github_catalog_execute_tool\`
3. Outil à appeler : \`github_issue_create\`
4. Paramètres :
   - **owner:** "Serenity-System"
   - **repo:** "mcp-serenity"
   - **title:** "[Auto] Bug détecté dans $tool_name_short"
   - **body:** (utilise le template ci-dessous)
   - **labels:** ["bug", "auto-detected"]

### Template du corps de l'issue

\`\`\`markdown
# Bug auto-détecté dans $tool_name

## 🔍 Contexte
- **Outil MCP:** \`$tool_name\`
- **Date:** $timestamp
- **Session:** \`$session_id\`
- **Détecté par:** Claude Code Hook v1.0

## ❌ Erreur

\`\`\`
$error_msg
\`\`\`

## 📝 Paramètres de l'appel

\`\`\`json
$tool_input
\`\`\`

## 🔄 Reproduction

[Claude, décris ici comment reproduire le bug étape par étape]

## 💡 Analyse préliminaire

[Claude, analyse ici la cause probable du bug]

## ⚙️ Environnement
- Working directory: $cwd
- Permission mode: $permission_mode

---
*Issue créée automatiquement par Claude Code Hook*
\`\`\`

### Si c'est une ERREUR D'UTILISATION :
1. N'ouvre PAS d'issue
2. Continue normalement
3. L'erreur est déjà visible pour l'utilisateur

**Maintenant, analyse l'erreur et agis en conséquence.**
EOF
)
  
  # Remplacer les variables dans le prompt
  analysis_prompt=$(echo "$analysis_prompt" | sed "s/\$tool_name/$tool_name/g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s/\$tool_name_short/$tool_name_short/g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s|\$tool_input|$tool_input|g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s|\$error_msg|$error_msg|g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s/\$exit_code/$exit_code/g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s/\$session_id/$session_id/g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s|\$cwd|$cwd|g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s/\$permission_mode/$permission_mode/g")
  analysis_prompt=$(echo "$analysis_prompt" | sed "s/\$timestamp/$timestamp/g")
  
  # Injecter le contexte d'analyse à Claude via stdout
  jq -n \
    --arg context "$analysis_prompt" \
    '{add_context: $context}'
  
  exit 0
fi

# Pas d'erreur MCP Serenity détectée, continuer normalement
exit 0
```

#### Étape 1.3 : Rendre le hook exécutable

```bash
chmod +x .claude/hooks/post-tool-use.sh
```

#### Étape 1.4 : Configurer Claude Code

**Fichier:** `.claude/settings.json`

```json
{
  "hooks": {
    "PostToolUse": ".claude/hooks/post-tool-use.sh"
  }
}
```

### Phase 2 : Amélioration avec déduplication

#### Étape 2.1 : Modifier le prompt pour ajouter la déduplication

Ajouter dans le prompt d'analyse, **avant** la section "Actions à prendre" :

```markdown
## Avant de créer une issue

1. **Vérifie d'abord** s'il existe déjà une issue similaire :
   - Utilise \`mcp__mcp-serenity__github_catalog_execute_tool\`
   - Outil : \`github_issue_list\`
   - Paramètres :
     - owner: "Serenity-System"
     - repo: "mcp-serenity"
     - state: "open"
     - labels: "bug,auto-detected"
   - Cherche dans les titres si le même outil est mentionné
   - Lis le corps des issues récentes pour vérifier si l'erreur est identique

2. **Si doublon trouvé** :
   - N'ouvre PAS de nouvelle issue
   - Ajoute un commentaire sur l'issue existante avec :
     - "🔄 Erreur reproduite le {timestamp}"
     - Les nouveaux paramètres d'appel
     - Tout détail supplémentaire pertinent

3. **Si pas de doublon** :
   - Crée l'issue normalement
```

### Phase 3 : Logging et monitoring

#### Étape 3.1 : Créer un script d'analyse des logs

**Fichier:** `.claude/scripts/analyze-errors.sh`

```bash
#!/bin/bash
# Analyse les logs d'erreurs MCP Serenity

LOG_FILE="${HOME}/.claude/logs/error-analysis.log"

echo "📊 Statistiques des erreurs MCP Serenity"
echo "========================================"
echo

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Aucun log trouvé."
  exit 0
fi

echo "Total d'appels MCP Serenity loggés:"
jq -s 'length' "$LOG_FILE"
echo

echo "Nombre d'erreurs:"
jq -s 'map(select(.is_error == true)) | length' "$LOG_FILE"
echo

echo "Top 5 des outils avec le plus d'erreurs:"
jq -s 'map(select(.is_error == true)) | group_by(.tool) | map({tool: .[0].tool, count: length}) | sort_by(.count) | reverse | .[0:5]' "$LOG_FILE"
echo

echo "Erreurs des dernières 24h:"
jq -s --arg since "$(date -d '24 hours ago' -u +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -u +"%Y-%m-%d %H:%M:%S")" 'map(select(.is_error == true and .timestamp >= $since))' "$LOG_FILE"
```

```bash
chmod +x .claude/scripts/analyze-errors.sh
```

### Phase 4 : Mécanisme de désactivation

#### Étape 4.1 : Désactiver temporairement

Pour désactiver le système (utile lors de tests ou debugging) :

```bash
touch ~/.claude/.disable-auto-issue
```

Pour réactiver :

```bash
rm ~/.claude/.disable-auto-issue
```

---

## 🧪 Tests

### Test 1 : Erreur utilisateur (ne doit PAS créer d'issue)

**Commande de test:**
```bash
# Depuis Claude Code, demander:
"Utilise devbox_read pour lire /fichier/qui/nexiste/pas"
```

**Résultat attendu:**
- Hook détecte l'erreur
- Claude analyse : "C'est une erreur d'utilisation (fichier inexistant)"
- Aucune issue créée
- Message à l'utilisateur : "Le fichier n'existe pas"

### Test 2 : Bug serveur (doit créer une issue)

**Scénario simulé:**
Si un outil MCP retourne une vraie erreur 500 ou un crash

**Résultat attendu:**
- Hook détecte l'erreur
- Claude analyse : "C'est un bug serveur"
- Issue créée automatiquement sur GitHub
- Message à l'utilisateur : "✅ Issue #X créée automatiquement"

### Test 3 : Déduplication

**Scénario:**
1. Provoquer le même bug deux fois de suite

**Résultat attendu:**
1. Première fois : Issue créée (#42)
2. Deuxième fois : 
   - Claude détecte le doublon
   - Ajoute un commentaire sur #42
   - Message : "🔄 Erreur déjà reportée dans #42, commentaire ajouté"

### Test 4 : Désactivation

**Commande:**
```bash
touch ~/.claude/.disable-auto-issue
# Provoquer une erreur
# Vérifier qu'aucune issue n'est créée
rm ~/.claude/.disable-auto-issue
```

### Test 5 : Logging

**Vérification:**
```bash
cat ~/.claude/logs/error-analysis.log | jq -s 'length'
# Doit afficher le nombre d'événements loggés
```

---

## 🚀 Déploiement

### Étape 1 : Préparer l'environnement

```bash
# S'assurer que jq est installé
which jq || sudo apt-get install -y jq

# Créer les dossiers nécessaires
mkdir -p ~/.claude/hooks
mkdir -p ~/.claude/logs
mkdir -p ~/.claude/scripts
mkdir -p ~/.claude/tests
```

### Étape 2 : Copier les fichiers

```bash
# Copier le hook depuis la DevBox
cp /home/claude/hook-claude/post-tool-use.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/post-tool-use.sh

# Copier les scripts
cp /home/claude/hook-claude/analyze-errors.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/analyze-errors.sh
```

### Étape 3 : Configurer Claude Code

```bash
# Modifier .claude/settings.json (ou créer si inexistant)
cat > .claude/settings.json <<'EOF'
{
  "hooks": {
    "PostToolUse": ".claude/hooks/post-tool-use.sh"
  }
}
EOF
```

### Étape 4 : Vérifier l'installation

```bash
# Vérifier que le hook est bien configuré
cat .claude/settings.json | jq '.hooks.PostToolUse'

# Vérifier que le hook est exécutable
test -x ~/.claude/hooks/post-tool-use.sh && echo "✅ Hook exécutable" || echo "❌ Hook non exécutable"

# Vérifier que jq fonctionne
echo '{"test": true}' | jq '.test'
```

---

## 🔧 Maintenance

### Rotation des logs

**Fichier:** `.claude/scripts/rotate-logs.sh`

```bash
#!/bin/bash
# Rotation des logs (à exécuter via cron ou manuellement)

LOG_FILE="${HOME}/.claude/logs/error-analysis.log"
MAX_LINES=10000

if [[ -f "$LOG_FILE" ]]; then
  line_count=$(wc -l < "$LOG_FILE")
  
  if [[ $line_count -gt $MAX_LINES ]]; then
    echo "🔄 Rotation du log ($line_count lignes)"
    mv "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d-%H%M%S).old"
    touch "$LOG_FILE"
    echo "✅ Log rotationné"
  else
    echo "✓ Log OK ($line_count lignes)"
  fi
fi
```

### Mise à jour du hook

Lorsqu'une nouvelle version du hook est disponible :

```bash
# Sauvegarder l'ancienne version
cp ~/.claude/hooks/post-tool-use.sh ~/.claude/hooks/post-tool-use.sh.backup

# Remplacer par la nouvelle version
cp /home/claude/hook-claude/post-tool-use.sh ~/.claude/hooks/

# Tester
# Si problème, restaurer:
# cp ~/.claude/hooks/post-tool-use.sh.backup ~/.claude/hooks/post-tool-use.sh
```

---

## 📚 Documentation complémentaire

### Ressources Claude Code
- [Guide des Hooks](https://code.claude.com/docs/en/hooks-guide.md)
- [Référence Hooks](https://code.claude.com/docs/en/hooks.md)
- [Settings Configuration](https://code.claude.com/docs/en/settings.md)

### MCP Serenity
- Repository : https://github.com/Serenity-System/mcp-serenity
- Documentation des outils GitHub : voir catalogue MCP

### Outils utilisés
- **jq** : Traitement JSON en ligne de commande
- **bash** : Shell scripting
- **git** : Versionning du code

---

## 🐛 Dépannage

### Problème : Le hook ne se déclenche pas

**Diagnostic:**
```bash
# Vérifier la configuration
cat .claude/settings.json | jq '.hooks.PostToolUse'

# Vérifier les permissions
ls -l ~/.claude/hooks/post-tool-use.sh
```

**Solutions:**
- S'assurer que le chemin dans settings.json est correct
- Vérifier que le hook est exécutable : `chmod +x ~/.claude/hooks/post-tool-use.sh`
- Redémarrer Claude Code

### Problème : jq non trouvé

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install -y jq

# macOS
brew install jq
```

### Problème : Issues créées en double

**Solution:**
- S'assurer que Claude recherche bien les issues existantes avant de créer
- Améliorer les critères de recherche de doublons dans le prompt

---

## 📊 Métriques de succès

### KPIs à surveiller

1. **Taux de détection** : >80% des bugs détectés automatiquement
2. **Précision** : >95% d'issues valides (pas de faux positifs)
3. **Temps de signalement** : <10 secondes
4. **Déduplication** : 0 doublon
5. **Performance** : <2 secondes d'exécution du hook

---

## 🔮 Évolutions futures

### Version 1.1
- Ajout de labels automatiques selon le type d'erreur
- Assignation automatique selon le composant affecté
- Priorité automatique (P0, P1, P2) selon la sévérité

### Version 1.2
- Intégration avec Slack pour notifications
- Dashboard web de monitoring
- Métriques en temps réel

### Version 2.0
- Auto-correction pour certains types de bugs connus
- Suggestions de fix basées sur l'historique
- ML pour améliorer la classification

---

## ✅ Checklist de déploiement

- [ ] Environnement préparé (jq installé, dossiers créés)
- [ ] Hook créé et exécutable
- [ ] Settings.json configuré
- [ ] Tests manuels passés
- [ ] Logging fonctionnel
- [ ] Déduplication testée
- [ ] Mécanisme de désactivation testé
- [ ] Documentation lue et comprise
- [ ] Monitoring en place

---

## 📝 Notes de version

### v1.0 - 2026-01-12 (Cette version)
- 🎉 Version initiale
- ✅ Détection automatique des erreurs MCP Serenity
- ✅ Analyse intelligente via Claude
- ✅ Création automatique d'issues GitHub
- ✅ Déduplication des issues
- ✅ Système de logging
- ✅ Mécanisme de désactivation

---

**Auteur:** tincenv  
**Contact:** via GitHub @tincenv  
**License:** MIT License  
**Status:** 📋 Spécification - Prêt pour implémentation

