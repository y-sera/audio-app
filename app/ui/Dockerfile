FROM node:22.23.3-alpine AS build

WORKDIR /src

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.31.7-alpine

# host:port of the audio-app transcript API.
ENV API_UPSTREAM=audio-app:8000

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --chmod=755 nginx/entrypoint.sh /ui-entrypoint.sh
COPY --from=build /src/dist /usr/share/nginx/html

EXPOSE 8080

ENTRYPOINT ["/ui-entrypoint.sh"]
