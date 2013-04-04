#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use 5.012000;
use AnyEvent;
use AnyEvent::HTTP::Request;
use Encode;
use FindBin;
use JSON::XS;
use Plack::Request;
use Twiggy::Server;
use Yancha::Bot;

my $cv = AnyEvent->condvar;

my %option;
$option{host} ||= '0.0.0.0'; #FIXME optional
$option{port} ||= 6600; # FIXME optional

my $config = do("$FindBin::Bin/config.pl");
my $bot = Yancha::Bot->new($config);
$bot->get_yancha_auth_token();

my $app = sub {
    my $req = Plack::Request->new(shift);

    if ($req->method eq 'POST' and my $payload = $req->param('payload')) {
        my $json = decode_json($payload);

        if ($json->{issue}) {
            my $issue   = $json->{issue};

            my $number = $issue->{number};
            my $title  = $issue->{title};
            my $state  = $json->{action};
            my $url    = $issue->{html_url};
            if ($json->{comment}) {
                $state = "posted";
                $url   = $json->{comment}->{html_url};
            }

            my $message =decode_utf8("[Issue $state] $title(No.$number) $url");

            $bot->post_yancha_message($message);
        }
        elsif ($json->{pull_request}) {
            my $pull_request = $json->{pull_request};
            my $title        = encode_utf8($pull_request->{title});
            my $number       = $pull_request->{number};
            my $state        = $json->{action};
            my $url          = $pull_request->{html_url};

            my $message = decode_utf8("[Pull-Request $state] $title(No.$number) $url");

            $bot->post_yancha_message($message);
        }
        return [200, [], ['']];
    }
    return [403, [], ['Forbidden']];
};

my $server = Twiggy::Server->new(%option);
$server->register_service($app);

$cv->recv;
