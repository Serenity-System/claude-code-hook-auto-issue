#!/bin/bash
# Hook PostToolUse - Auto-détection de bugs MCP Serenity
# Version: 1.0
# Date: 2026-01-12
# Auteur: tincenv
#
# Ce hook détecte automatiquement les erreurs dans les outils MCP Serenity
# et demande à Claude d'analyser si c'est un bug (création d'issue) ou
# une erreur utilisateur (pas d'action).

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

LOG_FILE="${HOME}/.claude/logs/error-analysis.log"
DISABLE_FILE="${HOME}/.claude/.disable-auto-issue"

# ============================================================================
# VÉRIFICATIONS PRÉLIMINAIRES
# ============================================================================

# Vérifier si le système est désactivé
if [[ -f "$DISABLE_FILE" ]]; then
  exit 0
fi

# Créer le dossier de logs si nécessaire
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# ============================================================================
# LECTURE ET PARSING DE L'INPUT
# ============================================================================

# Lire l'input JSON depuis stdin
input=$(cat)

# Extraire les champs nécessaires
tool_name=$(echo "$input" | jq -r '.tool_name')
is_error=$(echo "$input" | jq -r '.tool_response.isError // false')
error_msg=$(echo "$input" | jq -r '.tool_response.error // empty')
exit_code=$(echo "$input" | jq -r '.tool_response.exit_code // 0')

# ============================================================================
# LOGGING (TOUS LES APPELS MCP SERENITY)
# ============================================================================

# Logger tous les appels d'outils MCP Serenity pour audit
if [[ $tool_name == mcp__mcp-serenity__* ]]; then
  echo "$input" | jq -c '{
    timestamp: now | strftime("%Y-%m-%d %H:%M:%S"),
    tool: .tool_name,
    is_error: .tool_response.isError,
    error: .tool_response.error,
    logged_by: "post-tool-use-hook"
  }' >> "$LOG_FILE" 2>/dev/null || true
fi

# ============================================================================
# DÉTECTION D'ERREUR MCP SERENITY
# ============================================================================

# Vérifier si c'est une erreur MCP Serenity
if [[ $tool_name == mcp__mcp-serenity__* ]] && 
   ([[ "$is_error" == "true" ]] || [[ -n "$error_msg" ]] || [[ "$exit_code" != "0" ]]); then
  
  # --------------------------------------------------------------------------
  # EXTRACTION DES DONNÉES COMPLÈTES
  # --------------------------------------------------------------------------
  
  tool_input=$(echo "$input" | jq -c '.tool_input')
  session_id=$(echo "$input" | jq -r '.session_id')
  cwd=$(echo "$input" | jq -r '.cwd')
  permission_mode=$(echo "$input" | jq -r '.permission_mode')
  timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
  
  # Extraire le nom court de l'outil (sans le préfixe mcp__mcp-serenity__)
  tool_name_short=${tool_name#mcp__mcp-serenity__}
  
  # --------------------------------------------------------------------------
  # CONSTRUCTION DU PROMPT D'ANALYSE POUR CLAUDE
  # --------------------------------------------------------------------------
  
  # Utiliser un heredoc avec des variables bash interpolées
  analysis_prompt=$(cat <<EOF
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
     - "🔄 Erreur reproduite le $timestamp"
     - Les nouveaux paramètres d'appel
     - Tout détail supplémentaire pertinent

3. **Si pas de doublon**, continue vers la création

## Actions à prendre

### Si c'est un BUG :
1. Crée immédiatement une issue sur \`Serenity-System/mcp-serenity\`
2. Utilise l'outil : \`mcp__mcp-serenity__github_catalog_execute_tool\`
3. Outil à appeler : \`github_issue_create\`
4. Paramètres :
   - **tool_name:** "github_issue_create"
   - **arguments:** 
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
*Issue créée automatiquement par Claude Code Hook v1.0*
\`\`\`

### Si c'est une ERREUR D'UTILISATION :
1. N'ouvre PAS d'issue
2. Continue normalement
3. L'erreur est déjà visible pour l'utilisateur

**Maintenant, analyse l'erreur et agis en conséquence.**
EOF
)
  
  # --------------------------------------------------------------------------
  # INJECTION DU CONTEXTE DANS CLAUDE
  # --------------------------------------------------------------------------
  
  # Injecter le contexte d'analyse à Claude via stdout (format JSON)
  jq -n \
    --arg context "$analysis_prompt" \
    '{add_context: $context}'
  
  exit 0
fi

# ============================================================================
# PAS D'ERREUR DÉTECTÉE
# ============================================================================

# Pas d'erreur MCP Serenity détectée, continuer normalement
exit 0

