#!/usr/bin/perl -s

use Socket;

$SIG{INT} = sub {die};

{
    my $HOST = $ARGV[0] || '127.0.0.1';
    my $PORT = $ARGV[1] || '8888';
    my $proto = getprotobyname('tcp');
    socket(my $client, PF_INET, SOCK_STREAM, $proto) or die "socket: $!\n";
    connect($client, sockaddr_in($PORT, inet_aton($HOST))) or die "connect: $!\n";
    print "Connected to $HOST:$PORT\n";
    while (<$client>) {
        print;
    }
}
