# binwatch

Notifies when MariaDB tables change.

binwatch has been tested with MariaDB, not MySQL.

binwatch accepts client connections (TCP) on a specified
host:port. When a database table changes, binwatch writes the name of
the table to each client (followed by \n).

One use case is that a node/express webserver connects to a React
webapp via webSockets and to binwatch via TCP. Any message received
from binwatch is forwarded to the webapp via webSockets, which causes
a useEffect to poll the database and update the state, and the state
change causes React to render the new data.

The Makefile has targets for build, run, verbose, and client.

## Build

```make build```

or

```docker build . -t binwatch```

## Run

To run:

```MYSQL_SERVER=[user[:pass]@]host make run```
or

```MYSQL_SERVER=[user[:pass]@]host make verbose```

or

```docker run -it --rm --network host -e MYSQL_SERVER=[user[:pass]@]host binwatch```

For example:

```docker run -it --rm --network host -e MYSQL_SERVER=alice:secret@sql.example.com binwatch```

The user, password, and host default to root@127.0.0.1 (empty password).

## Sample Client

A sample client is provided by client.pl. To run:

```BINWATCH_HOST=bob.example.com:9999 make client```

The host and port default to 127.0.0.1:9888.

