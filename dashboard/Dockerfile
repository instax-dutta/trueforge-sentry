FROM node:22.14-alpine
WORKDIR /app
COPY package.json package-lock.json ./
COPY tsconfig.json next.config.mjs ./
RUN corepack enable && npm ci
COPY lib ./lib
COPY app ./app
ENV NODE_ENV=production
ENV PORT=3002
RUN npm run build
EXPOSE 3002
CMD ["npx", "next", "start", "-p", "3002"]
