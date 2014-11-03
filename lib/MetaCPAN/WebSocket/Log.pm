package MetaCPAN::WebSocket::Log;

use Moo;
use AnyEvent::Filesys::Notify;
use Path::Tiny ();
use Data::Dumper;
use JSON;

has ws    => ( is => "ro" );
has seek  => ( is => "rw" );
has path  => ( is => "ro" );
has stash => ( is => "ro", default => sub { [] } );

sub initialize {
	my $self     = shift;

	-d $self->path or die "Log dir ${\ $self->path } not found";
	print STDERR $self->path, $/ if ( $self->ws->debug );

	my $notifier = AnyEvent::Filesys::Notify->new(
		dirs         => [ $self->path ],
		interval     => 1,
		filter       => sub { shift =~ /metacpan\.log$/ },
		cb           => sub { $self->process_events($_) for @_ },
		parse_events => 1,
	);
	return $self;
}

sub handler {
	my ( $self, $conn ) = @_;
	$conn->on("log.stash", sub {
		my $conn = shift;
		$conn->emit( "log", $_ ) for @{ $self->stash };
	});
}

sub process_events {
	my ( $self, $event ) = @_;
	if ( $event->type eq "created" ) {
		$self->seek(0);
	}
	elsif ( $event->type eq "deleted" ) {
		$self->seek(0);
	}
	else {
		my $file = Path::Tiny::path( $event->path );
		$self->seek( $file->stat->size ) unless defined $self->seek;
		my $fh    = $file->openr_raw;
		my $lines = "";
		sysseek( $fh, $self->seek, 0 );
		while ( sysread( $fh, my $buffer, 4096 ) ) {
			$lines .= $buffer;
		}
		return unless $lines =~ /\n/;
		$lines =~ s/(?<=\n).*(?!\n)$//;
		$self->seek( $self->seek + length($lines) );
		while (
			$lines =~ m{
				(^\d\d\d\d)/(\d\d)/(\d\d)\s
				(\d\d:\d\d:\d\d)\s
				(\w)\s
				(\w+):\s
				((?: (?!\n\d\d\d\d/\d\d/\d\d) .)*)
			}gsmx
			)
		{
			chomp( my $message = $7 );
			$self->emit(
				{   date    => "$1-$2-$3T$4+0000",
					level   => $5,
					script  => $6,
					message => $message
				}
			);
		}
	}
}

sub emit {
	my ( $self, $message ) = @_;
	print STDERR encode_json($message), $/ if ( $self->ws->debug );
	$self->ws->sockets->emit( "log", $message );
	push( @{ $self->stash }, $message );
	shift @{ $self->stash } if @{ $self->stash } > 20;
}

1;
