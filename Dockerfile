FROM crystallang/crystal:1.15.0-alpine AS dev
WORKDIR /app
CMD [ "sh" ]
COPY . .
