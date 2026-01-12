# Hook Auto-Détection de Bugs MCP Serenity

> Système intelligent de détection automatique et de création d'issues GitHub pour les bugs dans les outils MCP Serenity, piloté par l'analyse de Claude.

## 🎯 Objectif

Détecter automatiquement les bugs dans les outils MCP Serenity et créer des issues GitHub, tout en ignorant les erreurs d'utilisation courantes.

## ✨ Fonctionnalités

- ✅ **Détection automatique** des erreurs dans tous les outils `mcp__mcp-serenity__*`
- 🧠 **Analyse intelligente** par Claude pour différencier bug vs erreur utilisateur
- 🐛 **Création automatique** d'issues GitHub avec contexte complet
- 🔄 **Déduplication** pour éviter les doublons
- 📊 **Logging** de toutes les erreurs pour audit
- ⚙️ **Désactivation** temporaire possible

## 🚀 Quick Start

### 1. Créer le hook

```bash
# Créer le dossier
mkdir -p ~/.claude/hooks

# Copier le hook depuis la DevBox
cp /home/claude/hook-claude/post-tool-use.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/post-tool-use.sh
```

### 2. Configurer Claude Code

Créer ou modifier `.claude/settings.json` :

```json
{
  "hooks": {
    "PostToolUse": ".claude/hooks/post-tool-use.sh"
  }
}
```

### 3. Vérifier l'installation

```bash
# Vérifier que jq est installé
which jq || sudo apt-get install -y jq

# Tester la configuration
cat .claude/settings.json | jq '.hooks.PostToolUse'
```

## 📖 Comment ça marche

```
Erreur MCP Serenity détectée
         ↓
Hook PostToolUse activé
         ↓
Injection du contexte à Claude
         ↓
Claude analyse: Bug ou Erreur utilisateur?
         ↓
    ┌────┴────┐
    │         │
   Bug    Erreur user
    │         │
    ↓         ↓
Issue créée   Continue
```

### Exemples de classification

**Bug de code** (issue créée) :
- Internal Server Error 500
- Traceback Python non géré
- Null reference exception
- Crash serveur inattendu

**Erreur utilisateur** (pas d'issue) :
- Fichier inexistant (404)
- Paramètres manquants (400)
- Permission refusée (403)
- Commande invalide

## 📁 Structure du projet

```
/home/claude/hook-claude/
├── README.md              # Ce fichier
├── SPECIFICATION.md       # Documentation complète
├── post-tool-use.sh       # Le hook à installer
├── analyze-errors.sh      # Script d'analyse des logs
└── examples/
    └── test-scenarios.md  # Exemples de tests
```

## 🧪 Tests rapides

### Test 1 : Erreur utilisateur

```bash
# Devrait pas créer d'issue
"Utilise devbox_read pour lire /fichier/inexistant"
```

**Résultat attendu** : Pas d'issue, message d'erreur normal

### Test 2 : Bug serveur (simulé)

Si un outil retourne une erreur 500, une issue devrait être créée automatiquement.

## ⚙️ Configuration avancée

### Désactiver temporairement

```bash
touch ~/.claude/.disable-auto-issue
```

### Réactiver

```bash
rm ~/.claude/.disable-auto-issue
```

### Voir les statistiques

```bash
cp /home/claude/hook-claude/analyze-errors.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/analyze-errors.sh
~/.claude/scripts/analyze-errors.sh
```

## 📊 Logs

Les logs sont stockés dans `~/.claude/logs/error-analysis.log` au format JSON Lines.

```bash
# Voir tous les logs
cat ~/.claude/logs/error-analysis.log | jq -s '.'

# Compter les erreurs
cat ~/.claude/logs/error-analysis.log | jq -s 'map(select(.is_error == true)) | length'
```

## 🐛 Dépannage

### Le hook ne se déclenche pas

```bash
# Vérifier la config
cat .claude/settings.json | jq '.hooks.PostToolUse'

# Vérifier les permissions
ls -l ~/.claude/hooks/post-tool-use.sh
```

### jq non trouvé

```bash
# Ubuntu/Debian
sudo apt-get install -y jq

# macOS
brew install jq
```

## 📚 Documentation complète

Pour plus de détails, consultez `SPECIFICATION.md` :
- Architecture détaillée
- Spécifications techniques
- Guide d'implémentation complet
- Scénarios de tests
- Maintenance et évolutions

## 🔗 Liens utiles

- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks.md)
- [MCP Serenity Repository](https://github.com/Serenity-System/mcp-serenity)
- [Guide des Hooks](https://code.claude.com/docs/en/hooks-guide.md)

## 📝 Version

**v1.0** - 2026-01-12
- Version initiale avec détection, analyse et création d'issues automatique

---

**Auteur:** tincenv  
**Status:** Prêt pour implémentation  
**License:** MIT License

