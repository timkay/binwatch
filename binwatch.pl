#!/usr/bin/perl -s

# Read the binlog on the server specified by the environment variable
# MYSQL_SERVER (user:password@host), and send notifications to clients
# as tables are modified.

use experimental 'smartmatch';

use Socket;
use IO::Select;
use IO::Handle;
use Time::HiRes qw(time);

use constant {
    MINDELAY => 0.05,            # wait 50ms for more of same
    MAXDELAY => 0.50,            # send at least once per second
};

{
    STDOUT->autoflush(1);

    my($mysqlbinlog_pid);

    sub cleanup {
        kill 'KILL', $mysqlbinlog_pid;
        die;
    }

    $SIG{INT} = *cleanup;
    $SIG{TERM} = *cleanup;


    my($buffer);
    my $seq = 'C00';            # name each client for easier log reading

    my($USER, $PASS, $HOST) = ($ENV{MARIADB_SERVER} || $ENV{MYSQL_SERVER}) =~ /^(?: ([^\@\:]*)? (?:\:([^\@]*))? \@)? (.*)$/x;
    $HOST ||= '127.0.0.1';
    $USER ||= 'root';


    # listen for clients

    my $port = ${BINWATCH_PORT} || 9888;
    my $proto = getprotobyname('tcp');
    socket(my $server, PF_INET, SOCK_STREAM, $proto) or die "socket: $!\n";
    setsockopt($server, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsockopt: $!\n";
    bind($server, sockaddr_in($port, INADDR_ANY)) or die "bind: $!\n";
    listen($server, SOMAXCONN);
    print "Listening on $port\n" if $v;


    my(%client);

    for (;;) {


        # wait for MariaDB server

        my($binlog, %topic);

        # add --start-position or --start-datetime
        my $read = "--read-from-remote-server";
        my $host = "--host=$HOST";
        my $user = "--user=$USER";
        my $password = "--password=$PASS";
        my $rand = int rand 9e6 + 1e6;
        my $id = "--stop-never-slave-server-id=$rand";
        my $base64 = "--base64-output=decode-rows";
        #my $database = "--database test";
        #my $counts = "--print-row-count";
        my $short = "--short-form";
        my $verbose = "--verbose";
        # The '' at the end says to start with the first binlog. We
        # really only need to start with the last binlog, but then we
        # would have to do a mysql query to get that
        # information. Could add later.
        my $cmd = "mysqlbinlog $read $host $user $password $base64 $database $counts $short $verbose --stop-never $id ''";
        print "$cmd\n" if $v;
        $mysqlbinlog_pid = open($binlog, "$cmd|") || die "mysqlbinlog: $!\n";

        # process IO events

      healthy:
        for (;;) {
            my $rin = IO::Select->new();
            my $win = IO::Select->new();

            $rin->add($binlog);
            $rin->add($server);
            $rin->add($_->{handle}) for values %client;

            # Assume clients are always writeable. If a client blocks,
            # then everything will block. Could be modified to queue
            # up notifications.
            #$win->add($_->{handle}) for values %client;

            my($r, $w, $e) = IO::Select->select($rin, $win, $ein, MINDELAY);

            my $now = time;
            for my $topic (keys %topic) {
                #print "testing --- $topic --- @{[$now - $topic{$topic}{min}]} $topic{$topic}{max}\n";
                my $dmin = $now - $topic{$topic}{min};
                my $dmax = $now - $topic{$topic}{max};
                if ($dmax > MAXDELAY) {
                    print "$topic (MAXDELAY) $dmin $dmax\n" if $vv;
                    print {$_->{handle}} "$topic\n" for values %client;
                    delete $topic{$topic};
                }
                if ($dmin > MINDELAY) {
                    print "$topic (MINDELAY) $dmin $dmax\n" if $vv;
                    print {$_->{handle}} "$topic\n" for values %client;
                    delete $topic{$topic};
                }

            }

            for my $handle (@$r) {
                if ($handle eq $server) {
                    my $paddr = accept(my $handle, $server);
                    my($port, $iaddr) = sockaddr_in($paddr);
                    $handle->autoflush;
                    $seq++;
                    $client{$handle} = {seq => $seq, handle => $handle};
                    print "Accepted connection from @{[inet_ntoa($iaddr)]}:$port  $client{$handle}{seq}\n";
                } elsif ($handle eq $binlog) {
                    # Doesn't work this way: runs one line behind. Seems like a buffering problem.
                    #my $data = <$binlog>;
                    #my $n = length($data);
                    my $n = sysread($binlog, my $data, 4096);
                    print "binlog sysread $n bytes\n" if $vv;
                    print "---\n", $data if $vv;
                    if ($n == 0) {
                        warn "binlog EOF\n";
                        last healthy;
                    }
                    $buffer .= $data;
                    for (;;) {
                        my @lines = split(/\r?\n/, $buffer, 2);
                        last if @lines < 2;
                        (my $line, $buffer) = @lines;
                        # print "binlog line (@{[length $line]} bytes) $line\n" if $v;
                        $line =~ s/^#Q> //;
                        if ($line !~ /^#/) {
                            my($table);
                            my($st, @token) = split(/\s+/, lc $line);
                            if ($st ~~ [qw(alter delete insert replace update)]) {
                                shift @token while $token[0] ~~ [qw(delayed from high_priority ignore into low_priority quick table)];
                                $topic = $token[0];

                                # record the beg time (if no entry for $topic)
                                # and now time.
                                #print "$topic\n";
                                #print {$_->{handle}} "$topic\n" for values %client;
                                my $now = time;
                                $topic{$topic}{max} = $now unless $topic{$topic};
                                $topic{$topic}{min} = $now;
                            }
                        }
                    }
                } else {
                    my $n = sysread($handle, my $data, 4096);
                    print "client sysread on $handle ($n bytes)\n" if $vv;
                    if ($n == 0) {
                        # Client sends an empty package when closed.
                        $handle->close();
                        print "Closed $client{$handle}{seq}\n" if $v;
                        delete $client{$handle};
                    } else {
                        print "Subscriptions aren't supported yet.\n";
                    }
                }
            }

            for my $handle (@$w) {
                # Send next queued notice.
                print "write on $client{$handle}{seq}\n";
            }

        }

        sleep 3;
    }

    print "Exiting...\n";
    exit;
}
