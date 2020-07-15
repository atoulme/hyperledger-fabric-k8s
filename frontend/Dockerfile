FROM node:12-alpine

COPY package.json .

RUN yarn install

COPY app app
COPY artifacts artifacts
COPY app.js config.js config.json /

ENV HFC_LOGGING='{"debug":"console","info":"console"}'

CMD node app.js