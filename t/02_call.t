use strict;

use Wiki::Toolkit;
use Wiki::Toolkit::TestConfig;

use Wiki::Toolkit::Plugin::Ping;

use IO::Socket;

use Test::More tests => 4;


# Create a test wiki
require Wiki::Toolkit::Setup::SQLite;
my %config = %{$Wiki::Toolkit::TestConfig::config{"SQLite"}};
Wiki::Toolkit::Setup::SQLite::setup($config{dbname});

require Wiki::Toolkit::Store::SQLite;
my $store = Wiki::Toolkit::Store::SQLite->new(%config);
my $wiki = Wiki::Toolkit->new( store=>$store );


# Listen on a special port, so we can check a ping happened
my $sock = new IO::Socket::INET (
                    LocalPort => 112233,
                    Proto => 'tcp',
                    Listen => 1,
);
unless($sock) {
    die("Can't listen on port 112233 for test");
}


# Create, to call localhost
my $plugin = Wiki::Toolkit::Plugin::Ping->new(
    node_to_url => "http://wiki.org/\$node",
    services => {
        test => "http://localhost:112233/url=\$url"
    }
);
ok( $plugin, "Plugin was created OK with the local URL" );

# Register it
$wiki->register_plugin(plugin=>$plugin);

# Call post_write on it
$plugin->post_write(
        node => "TestNode",
        id => 12,
        version => 1,
        content => "Stuff",
        metadata => {}
);

# Check they actually sent us something
my $rsock = $sock->accept();
my @req;
my $going = 1;
while($going && (my $line = <$rsock>)) {
    $line =~ s/\r?\n$//;
    unless($line) { $going = 0; }

    push @req,$line;
    warn "**$line**\n";
}

# Check they requested the right thing
my $allreq = join "\n", @req;
like( $req[0], qr/^GET \/url=http:\/\/wiki.org\/TestNode/, "Did right get" );
like( $allreq, qr/^Host: localhost:112233/m, "Correct http/1.1 host" );

# Send them an OK
print $rsock "HTTP/1.0 200 OK\r\n\r\n";

# Close
close($rsock);
close($sock);

# All happy
ok( "Happy" );
