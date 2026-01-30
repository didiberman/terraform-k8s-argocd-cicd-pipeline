FROM node:22-alpine

WORKDIR /app
COPY src/index.js .

CMD ["node", "index.js"]
