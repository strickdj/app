FROM alpine:3.19

ENV TZ=UTC

RUN apk add --no-cache mysql-client bash coreutils tzdata

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime

WORKDIR /app

COPY backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

# run cron in foreground, log to stdout
RUN echo "0 2 * * * /app/backup.sh 2>&1" > /etc/crontabs/root

CMD ["crond", "-f", "-l", "8"]
