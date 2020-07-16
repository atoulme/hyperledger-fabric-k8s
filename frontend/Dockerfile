FROM node:12-alpine

COPY package.json .

RUN yarn install

COPY app app
COPY artifacts artifacts
COPY app.js config.js config.json /
COPY public /public

ENV HFC_LOGGING='{"debug":"console","info":"console"}'

CMD node --max-old-space-size=256 app.js