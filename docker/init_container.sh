#!/bin/bash
set -e # Beende das Skript bei Fehlern

# Prüfen, ob das Volume leer ist, und initialisieren
if [ ! "$(ls -A /var/www/html/storage)" ]; then
  echo "Initialisiere Storage-Verzeichnis..."
  cp -r /var/www/html/storage_default/* /var/www/html/storage/
  chown -R www-data:www-data /var/www/html/storage
fi
targetFolder="/var/www/html"

env_file="$targetFolder/.env"

# Funktion, um einen Schlüssel in der .env-Datei zu aktualisieren oder hinzuzufügen
update_env_value() {
  local key="$1"
  local new_value="$2"

  # Prüfen, ob die .env-Datei existiert
  if [ ! -f "$env_file" ]; then
    echo "Die Datei $env_file wurde nicht gefunden!"
    exit 1
  fi

  # Prüfen, ob der Schlüssel existiert
  if grep -q "^$key=" "$env_file"; then
    # Schlüssel existiert, ersetze den Wert
    temp_file=$(mktemp)
    sed "s|^$key=.*|$key=$new_value|" "$env_file" > "$temp_file"
    cat "$temp_file" > "$env_file"
    rm "$temp_file"
    echo "Der Wert von $key wurde auf $new_value gesetzt."
  else
    # Schlüssel existiert nicht, füge ihn hinzu
    echo "$key=$new_value" >> "$env_file"
    echo "$key wurde zur .env-Datei hinzugefügt."
  fi
}

# Funktion, um die localhost-URLs in den Build-Assets zu ersetzen
replace_localhost_url_in_build_assets() {
  local buildAssetsDir="$targetFolder/public/build/assets"
  local pattern="http(:[\/\\\\]*)localhost"
  # APP_URL extrahieren
  app_url=$(grep -E '^APP_URL=' "$env_file" | cut -d '=' -f2-)
  if [ -z "$app_url" ]; then
    echo "APP_URL wurde nicht in der .env-Datei gefunden!"
    exit 2
  fi

  # APP_URL mit Regex analysieren
  if [[ "$app_url" =~ ^(http[s]?):\/\/([-a-zA-Z0-9@:%._\+~#=]{1,256}) ]]; then
    app_url_protocol="${BASH_REMATCH[1]}"
    app_url_domain="${BASH_REMATCH[2]}"
  else
    echo "Probleme beim Evaluieren der APP_URL aus der .env-Datei!"
    exit 2
  fi

  echo "App URL Protocol: $app_url_protocol, App URL Domain: $app_url_domain"
  local replacement="${app_url_protocol}\1${app_url_domain}"
  if [ ! -d "$buildAssetsDir" ]; then
    echo "Das Verzeichnis $buildAssetsDir existiert nicht!"
    exit 2
  fi

  # Durchlaufe alle Dateien im Build-Assets-Verzeichnis
  find "$buildAssetsDir" -type f \( -name "*.js" -o -name "*.map" \) | while read -r filepath; do
    if [ -f "$filepath" ]; then
      # Dateiinhalt lesen und Regex anwenden
      content=$(<"$filepath")
      modified_content=$(echo "$content" | sed -E "s|$pattern|$replacement|g")

      # Wenn Änderungen vorgenommen wurden, Datei aktualisieren
      if [ "$modified_content" != "$content" ]; then
        echo "$modified_content" > "$filepath"
        echo "Die Datei '$filepath' wurde erfolgreich geändert."
      fi
    fi
  done
}
# App immer in Production-Mode starten
echo "Setze APP_ENV auf production"
update_env_value "APP_ENV" "production"
echo "Setze APP_DEBUG auf false"
update_env_value "APP_DEBUG" "false"

# Funktion aufrufen
echo "Ersetze localhost-URLs in den Build-Assets"
replace_localhost_url_in_build_assets

# Pfad zu pdflatex ohne Dateinamen ermitteln
pdflatex_path=$(dirname "$(command -v pdflatex)")
# Pfad zu pdflatex anpassen
update_env_value "LAGEBOARD_PDFLATEX_PATH" "$pdflatex_path/"

# Pfad zu pdflatex ohne Dateinamen ermitteln
mysqldump_path=$(dirname "$(command -v mysqldump)")
# Pfad zu mysqldump anpassen
update_env_value "LAGEBOARD_MYSQLDUMP_PATH" "$mysqldump_path/"

echo "Artisan: optimize"
php artisan optimize

echo "Starte Webserver"
# Starte den ursprünglichen Container-Prozess
exec apache2-foreground
