FROM node:22-alpine

WORKDIR /app
COPY src/package.json .
RUN npm install

COPY src/index.js .
# We don't copy test.js into the final production image to keep it small

CMD ["node", "index.js"]
