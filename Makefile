
MARIADB_SERVER ?= 127.0.0.1
BINWATCH_HOST  ?= 127.0.0.1

build:
	docker build -q . -t timkay/binwatch

run:
	make build
	docker run -it --rm --network host -e MARIADB_SERVER=${MARIADB_SERVER} timkay/binwatch

verbose:
	make build
	docker run -it --rm --network host -e MARIADB_SERVER=${MARIADB_SERVER} timkay/binwatch -v

binlog:
	make build
	docker run -it --rm --network host --entrypoint=mysqlbinlog timkay/binwatch -R --host=${MARIADB_SERVER} --user=root --stop-never --base64-output=decode-rows ''

mysql:
	make build
	docker run -it --rm --network host mariadb mysql -h $(MARIADB_SERVER) -u root -e 'create database if not exists test'
	docker run -it --rm --network host mariadb mysql -h $(MARIADB_SERVER) -u root test -e 'create table if not exists test (a int, b int)'
	docker run -it --rm --network host mariadb mysql -h $(MARIADB_SERVER) -u root test -e 'insert into test values (1, 1)'
	docker run -it --rm --network host mariadb mysql -h $(MARIADB_SERVER) -u root test

shell:
	make build
	docker run -it --rm --network host mariadb /bin/bash

push:
	make build
	docker push timkay/binwatch

client:
	while true; do BINWATCH_HOST=${BINWATCH_HOST} ./client.pl; sleep 1; done
