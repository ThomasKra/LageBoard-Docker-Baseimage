# Einsatzleitsoftware Docker Image Builder für Base-Image

Dieses Respository enthält alle notwendigen Daten um das Basis-Image für die Einsatzverwaltung zu bauen.
Dieses besteht aus dem Apache Webserver mit PHP und einer TexLive LaTeX-Umgebung mit den für die Einsatzleitsoftware notwendigen Paketen.
Außerdem wird ein Startscript eingebunden, das beim ersten Start des Containers den Storage initialisiert, die definierte APP_URL in den Scripten ersetzt, sowie die notwendigen Umgebungsvariablen im .env-File überschrieben.

Der Bau des Images läuft über einen Docker-Workflow.
Das Image wird für die Platformen "linux/amd64,linux/arm64,linux/arm/v7" gebaut und als Multi-Platform-Image in den Docker-Hub geladen.