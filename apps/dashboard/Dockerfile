# syntax=docker/dockerfile:1
# Panoul web (README §18): Flutter web compilat într-o etapă separată, servit de nginx
# neprivilegiat (port 8080, utilizator non-root). Contextul de build e rădăcina repo-ului
# (workspace-ul Dart are nevoie de pachetele comune):
#   docker build -f apps/dashboard/Dockerfile --build-arg API_URL=https://api.exemplu.ro/api/v1 .

FROM ghcr.io/cirruslabs/flutter:3.47.2 AS build
WORKDIR /src
# Întâi doar manifestele: `pub get` rămâne în cache cât timp dependențele nu se schimbă.
COPY pubspec.yaml pubspec.lock ./
COPY packages/licurici_core/pubspec.yaml packages/licurici_core/
COPY packages/game_content/pubspec.yaml packages/game_content/
COPY apps/child_app/pubspec.yaml apps/child_app/
COPY apps/dashboard/pubspec.yaml apps/dashboard/
RUN flutter pub get --enforce-lockfile
COPY packages packages
COPY apps/dashboard apps/dashboard
ARG API_URL=http://localhost:3000/api/v1
WORKDIR /src/apps/dashboard
# --no-web-resources-cdn: CanvasKit servit de noi (fără cereri către alte domenii, CSP strict).
RUN flutter build web --release --no-web-resources-cdn --dart-define=API_URL=${API_URL}

FROM nginxinc/nginx-unprivileged:1.29-alpine AS runtime
# Șablonul primește API_ORIGIN la pornire (envsubst din imaginea nginx) → antetul CSP.
ENV API_ORIGIN=http://localhost:3000
COPY apps/dashboard/docker/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /src/apps/dashboard/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
