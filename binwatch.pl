#!/usr/bin/perl -s

# Read the binlog on the server specified by the environment variable
# MYSQL_SERVER (user:password@host), and send notifications to clients
# as tables are modified.

use experimental 'smartmatch';

use Socket;
use IO::Select;
use IO::Handle;

$SIG{INT} = sub {die};

{
    my($buffer);
    my $seq = 'C00';            # name each client for easier log reading

    my($USER, $PASS, $HOST) = ($ENV{MARIADB_SERVER} || $ENV{MYSQL_SERVER}) =~ /^(?: ([^\@\:]*)? (?:\:([^\@]*))? \@)? (.*)$/x;
    $HOST ||= '127.0.0.1';
    $USER ||= 'root';

    my $cmd = "mysqlbinlog -R --host=$HOST --user=$USER --password=$PASS --stop-never --base64-output=decode-rows ''";
    print "docker run --rm -it --network host binwatch $cmd\n" if $v;
    open(my $binlog, "$cmd|") || die "mysqlbinlog: $!\n";

    my $port = ${BINWATCH_PORT} || 9888;
    my $proto = getprotobyname('tcp');
    socket(my $server, PF_INET, SOCK_STREAM, $proto) or die "socket: $!\n";
    setsockopt($server, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsockopt: $!\n";
    bind($server, sockaddr_in($port, INADDR_ANY)) or die "bind: $!\n";
    listen($server, SOMAXCONN);
    print "Listening on $port\n" if $v;

    my(%clients);

    for (;;) {
        my $rin = IO::Select->new();
        my $win = IO::Select->new();

        $rin->add($binlog);
        $rin->add($server);
        $rin->add($_->{handle}) for values %clients;

        # Assume clients are always writeable. If a client blocks,
        # then everything will block. Could be modified to queue
        # up notifications.
        #$win->add($_->{handle}) for values %clients;

        my($r, $w, $e) = IO::Select->select($rin, $win, $ein, undef);
        for my $handle (@$r) {
            if ($handle eq $server) {
                my $paddr = accept(my $handle, $server);
                my($port, $iaddr) = sockaddr_in($paddr);
                $handle->autoflush;
                $seq++;
                $clients{$handle} = {seq => $seq, handle => $handle};
                print "accept from @{[inet_ntoa($iaddr)]}:$port  $handle  $clients{$handle}{seq}\n" if $v;
            } elsif ($handle eq $binlog) {
                # Doesn't work this way: runs one line behind. Seems like a buffering problem.
                #my $data = <$binlog>;
                #my $n = length($data);
                my $n = sysread($binlog, my $data, 4096);
                print "sysread $n bytes\n" if $v;
                $buffer .= $data;
                for (;;) {
                    my @lines = split(/\r?\n/, $buffer, 2);
                    last if @lines < 2;
                    (my $line, $buffer) = @lines;
                    # print "binlog line (@{[length $line]} bytes) $line\n" if $v;
                    if ($line =~ /^#Q>/) {
                        my($table);
                        my($q, $st, @token) = split(/\s+/, lc $line);
                        if ($st ~~ [qw(alter delete insert replace update)]) {
                            shift @token while $token[0] ~~ [qw(delayed from high_priority ignore into low_priority quick table)];
                            $table = $token[0];
                            print {$_->{handle}} "$table\n" for values %clients;
                        }
                    }
                }
            } else {
                my $n = sysread($handle, my $data, 4096);
                print "sysread on $handle ($n bytes)\n" if $v;
                if ($n == 0) {
                    # Client sends an empty package when closed.
                    $handle->close();
                    print "closing $clients{$handle}{seq}\n" if $v;
                    delete $clients{$handle};
                } else {
                    print "Subscriptions aren't supported yet.\n";
                }
            }
        }
        for my $handle (@$w) {
            # Send next queued notice.
            print "write on $clients{$handle}{seq}\n";
        }
    }

    print "Exiting...\n";
    exit;
}
