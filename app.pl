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
use Text::VisualWidth::UTF8;
use Yancha::Bot;

sub _construct_message {
    my %contents = @_;

    my $message = "[$contents{type} $contents{state}] "
      . qq!$contents{repo_name}/$contents{title}(No.$contents{number}) "$contents{body}" $contents{url}!;

    return $message;
}

sub _omit_trailing {
    my ($text, $num) = @_;

    $text = encode_utf8($text);
    my $length = Text::VisualWidth::UTF8::width($text);
    if ($length > $num) {
        return Text::VisualWidth::UTF8::trim($text, $num) . "...";
    }
    return $text;
}

sub _response {
    my ($bot, $json, $type) = @_;

    my $contents = $json->{$type};

    my $repo_name = $json->{repository}->{name};
    my $number    = $contents->{number};
    my $title     = $contents->{title};
    my $state     = $json->{action};
    my $url       = $contents->{html_url};
    my $body      = $contents->{body};
    if ( $json->{comment} ) {
        my $comment = $json->{comment};
        $state      = "posted";
        $url        = $comment->{html_url};
        $body       = $comment->{body};
    }
    $body = _omit_trailing($body, 40);

    my $message = decode_utf8(
        _construct_message(
            type      => _format_type($type),
            repo_name => $repo_name,
            state     => $state,
            title     => $title,
            number    => $number,
            body      => $body,
            url       => $url,
        )
    );

    print encode_utf8($message) . "\n";
    $bot->post_yancha_message($message);
}

sub _format_type {
    my $type = shift;

    if ($type eq 'issue') {
        return 'Issue';
    }
    elsif ($type eq 'pull_request') {
        return 'Pull-Request';
    }

    return 'UNKNOWN';
}

# Get configurations.
my $config = do("$FindBin::Bin/config.pl");

# Setting for host and port.
GetOptions( \my %option, qw/host=s port=i/, );
my $server_conf = $config->{Server};
$option{host} ||= $server_conf->{host};
$option{port} ||= $server_conf->{port};
unless ( $option{host} && $option{port} ) {
    die '! Please specify host and port in config.pl';
}

my $bot = Yancha::Bot->new($config);
$bot->up();

my $app = sub {
    my $req = Plack::Request->new(shift);

    if ( $req->method eq 'POST' and my $payload = $req->param('payload') ) {
        my $json = decode_json($payload);

        if ( $json->{issue} ) {
            _response($bot, $json, 'issue');
        }
        elsif ( $json->{pull_request} ) {
            _response($bot, $json, 'pull_request');
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
__END__
