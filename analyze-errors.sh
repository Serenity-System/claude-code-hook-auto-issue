#!/bin/bash
# Script d'analyse des logs d'erreurs MCP Serenity
# Version: 1.0
# Date: 2026-01-12

LOG_FILE="${HOME}/.claude/logs/error-analysis.log"

echo "📊 Statistiques des erreurs MCP Serenity"
echo "========================================"
echo

# Vérifier si le fichier de log existe
if [[ ! -f "$LOG_FILE" ]]; then
  echo "❌ Aucun log trouvé à : $LOG_FILE"
  echo
  echo "Le hook n'a peut-être pas encore été exécuté, ou le chemin est incorrect."
  exit 0
fi

# Total d'appels MCP Serenity loggés
total_calls=$(jq -s 'length' "$LOG_FILE" 2>/dev/null || echo "0")
echo "📞 Total d'appels MCP Serenity loggés: $total_calls"
echo

# Nombre d'erreurs
error_count=$(jq -s 'map(select(.is_error == true)) | length' "$LOG_FILE" 2>/dev/null || echo "0")
echo "❌ Nombre d'erreurs: $error_count"
echo

# Taux d'erreur
if [[ $total_calls -gt 0 ]]; then
  error_rate=$(echo "scale=2; $error_count * 100 / $total_calls" | bc 2>/dev/null || echo "N/A")
  echo "📈 Taux d'erreur: ${error_rate}%"
  echo
fi

# Top 5 des outils avec le plus d'erreurs
echo "🔝 Top 5 des outils avec le plus d'erreurs:"
jq -s '
  map(select(.is_error == true)) | 
  group_by(.tool) | 
  map({
    tool: .[0].tool, 
    count: length
  }) | 
  sort_by(.count) | 
  reverse | 
  .[0:5] | 
  .[] | 
  "  - \(.tool): \(.count) erreur(s)"
' "$LOG_FILE" 2>/dev/null | tr -d '"' || echo "  Aucune erreur trouvée"
echo

# Erreurs des dernières 24h
echo "🕐 Erreurs des dernières 24h:"
since_timestamp=$(date -d '24 hours ago' -u +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -u +"%Y-%m-%d %H:%M:%S")
recent_errors=$(jq -s --arg since "$since_timestamp" '
  map(select(.is_error == true and .timestamp >= $since)) | 
  length
' "$LOG_FILE" 2>/dev/null || echo "0")
echo "  $recent_errors erreur(s)"
echo

# Détails des dernières erreurs (5 dernières)
echo "🔍 Détails des 5 dernières erreurs:"
jq -s '
  map(select(.is_error == true)) | 
  reverse | 
  .[0:5] | 
  .[] | 
  "
  📅 \(.timestamp)
  🔧 Outil: \(.tool)
  ❌ Erreur: \(.error // "Non spécifiée")
  "
' "$LOG_FILE" 2>/dev/null | tr -d '"' || echo "  Aucune erreur récente"

echo
echo "✅ Analyse terminée"
echo
echo "💡 Pour voir le log complet:"
echo "   cat $LOG_FILE | jq -s '.'"

