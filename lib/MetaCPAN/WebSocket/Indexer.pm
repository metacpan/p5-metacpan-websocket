package MetaCPAN::WebSocket::Indexer;

use Moo;
use AnyEvent::Filesys::Notify;
use Path::Tiny qw(path);
use Data::Dumper;

has ws => ( is => "ro" );

has seek => ( is => "rw" );

sub initialize {
	my $self     = shift;
	my $notifier = AnyEvent::Filesys::Notify->new(
		dirs         => [qw( ../cpan-api/var/log )],
		interval     => 1,
		filter       => sub { shift =~ /metacpan\.log$/ },
		cb           => sub { $self->process_events($_) for @_ },
		parse_events => 1,
	);
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
		my $file = path( $event->path );
		$self->seek( $file->stat->size ) unless defined $self->seek;
		my $fh    = $file->openr_raw;
		my $lines = "";
		warn $self->seek;
		sysseek( $fh, $self->seek, 0 );
		while ( sysread( $fh, my $buffer, 4096 ) ) {
			$lines .= $buffer;
		}
		warn $lines;
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
			$self->emit(
				{   date    => "$1-$2-$3T$4+0000",
					level   => $5,
					script  => $6,
					message => $7
				}
			);
		}
	}
}

sub emit {
	shift->ws->sockets->emit( "log", shift );
}

1;
