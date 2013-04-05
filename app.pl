#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use 5.012000;
use AnyEvent;
use AnyEvent::HTTP::Request;
use Encode;
use FindBin;
use Getopt::Long;
use JSON::XS;
use Plack::Request;
use Twiggy::Server;
use Yancha::Bot;

my $config = do("$FindBin::Bin/config.pl");
my $bot    = Yancha::Bot->new($config);
$bot->up();

# Setting for host and port.
GetOptions( \my %option, qw/host=s port=i/, );
my $server_conf = $config->{Server};
$option{host} ||= $server_conf->{host};
$option{port} ||= $server_conf->{port};
unless ( $option{host} && $option{port} ) {
    die '! Please specify host and port in config.pl';
}

# FIXME a little duplicated!!
my $app = sub {
    my $req = Plack::Request->new(shift);

    if ( $req->method eq 'POST' and my $payload = $req->param('payload') ) {
        my $json = decode_json($payload);

        if ( $json->{issue} ) {
            my $issue = $json->{issue};

            my $repo_name = $json->{repository}->{name};
            my $number    = $issue->{number};
            my $title     = $issue->{title};
            my $state     = $json->{action};
            my $url       = $issue->{html_url};
            if ( $json->{comment} ) {
                $state = "posted";
                $url   = $json->{comment}->{html_url};
            }

            my $message = decode_utf8(
                _construct_message(
                    type      => 'Issue',
                    repo_name => $repo_name,
                    state     => $state,
                    title     => $title,
                    number    => $number,
                    url       => $url,
                )
            );

            print encode_utf8($message) . "\n";
            $bot->post_yancha_message($message);
        }
        elsif ( $json->{pull_request} ) {
            my $pull_request = $json->{pull_request};

            my $repo_name = $json->{repository}->{name};
            my $number    = $pull_request->{number};
            my $title     = $pull_request->{title};
            my $state     = $json->{action};
            my $url       = $pull_request->{html_url};

            my $message = decode_utf8(
                _construct_message(
                    type      => 'Pull-Request',
                    repo_name => $repo_name,
                    state     => $state,
                    title     => $title,
                    number    => $number,
                    url       => $url,
                )
            );

            print encode_utf8($message) . "\n";
            $bot->post_yancha_message($message);
        }
        return [ 200, [], [''] ];
    }

    print "! Received illegal data.\n";
    return [ 403, [], ['Forbidden'] ];
};

my $cv = AnyEvent->condvar;

my $server = Twiggy::Server->new(%option);
$server->register_service($app);
say "Ready...";

$cv->recv;

sub _construct_message {
    my %contents = @_;

    my $message = "[$contents{type} $contents{state}] "
      . "$contents{repo_name}/$contents{title}(No.$contents{number}) $contents{url}";

    return $message;
}
__END__
