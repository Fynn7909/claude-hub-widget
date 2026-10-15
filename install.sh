#!/usr/bin/env bash
# Installiert das Plasma-6-Widget „Claude Hub“ für den aktuellen Benutzer.
# Die Zahlen kommen von `claude-hub --widget-json`, also muss Claude Hub installiert sein:
# https://github.com/Fynn7909/claude-hub
#   ./install.sh             installieren
#   ./install.sh --uninstall entfernen
set -euo pipefail
cd "$(dirname "$0")"

dest="$HOME/.local/share/plasma/plasmoids/org.franz.claudehubwidget"
rm -rf "$dest"
if [ "${1:-}" = "--uninstall" ]; then
  echo "Entfernt."
  exit 0
fi
mkdir -p "$dest"
cp -r package/. "$dest/"

[ -x "$HOME/.local/bin/claude-hub" ] || echo "Hinweis: Claude Hub fehlt noch (~/.local/bin/claude-hub). Ohne die App zeigt das Widget keine Zahlen."
echo "Installiert. Rechtsklick auf den Desktop > „Miniprogramme hinzufügen“ > „Claude Hub“."
