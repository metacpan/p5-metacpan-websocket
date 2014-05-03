package MetaCPAN::WebSocket;

use lib qw(lib);
use MetaCPAN::WebSocket::Log;

use Plack::Builder;
use PocketIO;
use PocketIO::Sockets;
use Moo;

has pocketio => ( is => "ro", lazy => 1, builder => "_build_pocketio" );
has sockets  => ( is => "rw", lazy => 1, builder => "_build_sockets" );

sub _build_pocketio {
	PocketIO->new( handler => sub { } );
}

sub _build_sockets {
	PocketIO::Sockets->new( pool => shift->pocketio->pool );
}

my $ws = __PACKAGE__->new;

MetaCPAN::WebSocket::Log->new( ws => $ws )->initialize;

builder {
	mount '/socket.io' => $ws->pocketio;
	mount "/"          => sub {
		[   200,
			[ "Content-Type", "text/html" ],
			[   qq{
<script src="//cdnjs.cloudflare.com/ajax/libs/socket.io/0.9.16/socket.io.min.js"></script>
<script>
  var socket = io.connect();
  socket.on('log', function (data) {
    console.log(data);
  });
</script>
}
			]
		];
	};
};

=head1 NAME

MetaCPAN::WebSocket - Real-time interface to MetaCPAN

=head1 DESCRIPTION

L<PocketIO> server that provides real time information from
MetaCPAN processes to web clients.

=head1 SYNOPSIS

  cpanm --installdeps .
  twiggy

	<script src="//cdnjs.cloudflare.com/ajax/libs/socket.io/0.9.16/socket.io.min.js"></script>
	<script>
	  var socket = io.connect();
	  socket.on('log', function (data) {
	    console.log(data);
	  });
	</script>

=head1 AVAILABLE EVENTS

=head2 log

As of now, only the indexer's log file is provided in real time.
Look out for more in the near future.

  {
  	message: "[ERROR] Elasticsearch timeout",
  	script: "release",
  	level: "F",
  	date: "2014/05/02 18:22:36 GMT+0100"
  }
