FROM alpine
RUN apk --update add mariadb
RUN apk --update add perl
WORKDIR /app
COPY binwatch.pl .
CMD perl binwatch.pl
