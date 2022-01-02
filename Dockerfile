FROM alpine
RUN apk --update add mariadb
RUN apk --update add perl
WORKDIR /app
COPY binwatch.pl .
COPY client.pl .
ENTRYPOINT ["./binwatch.pl"]
