#!/usr/bin/perl -s

use Socket;

$SIG{INT} = sub {die};

{
    my($HOST, $PORT) = split(/:/, $ENV{BINWATCH_HOST});
    $HOST ||= '127.0.0.1';
    $PORT ||= 9888;

    my $proto = getprotobyname('tcp');
    socket(my $client, PF_INET, SOCK_STREAM, $proto) or die "socket: $!\n";
    connect($client, sockaddr_in($PORT, inet_aton($HOST))) or die "connect: $!\n";
    print "Connected to $HOST:$PORT\n";
    while (<$client>) {
        print;
    }
}
