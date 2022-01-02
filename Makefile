build:
	docker build . -t binwatch

run:
	docker run -it --rm --network host -e MARIADB_SERVER=${MARIADB_SERVER} binwatch

verbose:
	docker run -it --rm --network host -e MARIADB_SERVER=${MARIADB_SERVER} binwatch perl ./binwatch.pl -v

client:
	while true; do ./client.pl; sleep 1; done
