package Giraffa::CLI;

use 5.014002;
use warnings;

our $VERSION = '0.01';

use Moose;
with 'MooseX::Getopt';

use Giraffa;
use Giraffa::Logger::Entry;
use Giraffa::Translator;
use JSON::XS;

our %numeric = Giraffa::Logger::Entry->levels;
my $json = JSON::XS->new;

has 'level' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 0,
    default       => 'NOTICE',
    documentation => 'The minimum severity level to display'
);
has 'lang' =>
  ( is => 'ro', isa => 'Str', required => 0, default => 'tech', documentation => 'The language to show messages in. Can be tech, raw, json or any installed translation.' );

sub run {
    my ( $self ) = @_;
    my @accumulator;

    my ( $domain ) = @{ $self->extra_argv };
    if ( not $domain ) {
        die "Must give the name of a domain to test.\n";
    }

    my $translator;
    $translator = Giraffa::Translator->new( { lang => $self->lang } ) unless ($self->lang eq 'raw' or $self->lang eq 'json');
    eval { $translator->data } if $translator; # Provoke lazy loading of translation data
    if ( $@ ) {
        if ( $@ =~ /Cannot read translation file/ ) {
            say "Cannot find a translation for language " . $self->lang . ".";
            exit( 1 );
        }
        else {
            die "Oops: $@";
        }
    }

    Giraffa->logger->callback(
        sub {
            my ( $entry ) = @_;

            return if $numeric{ uc $entry->level } < $numeric{ uc $self->level };

            if ( $translator ) {
                say $translator->translate_tag( $entry );
            }
            elsif ($self->lang eq 'json') {
                push @accumulator, {
                    timestamp => $entry->timestamp,
                    module => $entry->module,
                    tag => $entry->tag,
                    args => $entry->args,
                };
            }
            else {
                say "$entry";
            }
        }
    );

    Giraffa->test_zone( $domain );

    if ($self->lang eq 'json') {
        say $json->encode(\@accumulator);
    }

    return;
} ## end sub run

1;