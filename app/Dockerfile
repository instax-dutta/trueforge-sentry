# Build context = repository ROOT (see infra/docker-compose.yml) so the shared
# tsconfig.base.json can be placed where app/tsconfig.json's extends expects it.
FROM node:22.14-alpine AS build
COPY tsconfig.base.json /
COPY app/package.json /app/
WORKDIR /app
RUN corepack enable && npm install --no-save
COPY app/tsconfig.json ./
COPY app/src ./src
RUN npx tsc -p tsconfig.json

FROM node:22.14-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/index.js"]
