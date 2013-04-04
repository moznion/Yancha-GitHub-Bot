#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use 5.012000;
use FindBin;

my $config = do("$FindBin::Bin/config.pl");

my $github_config = $config->{GitHub};
my $api_url       = 'https://api.github.com/hub';
my $base_url      = 'https://github.com';
my $user          = $github_config->{user};
my $pass          = $github_config->{pass};
my $callback      = $github_config->{callback_url};

foreach my $repository ( @{ $github_config->{repositories} } ) {
    foreach my $hook ( @{ $github_config->{hooks} } ) {
        my $curl = <<CURL;
curl -u $user:$pass -i $api_url \\
-F "hub.mode=subscribe" \\
-F "hub.topic=$base_url/$repository/events/$hook" \\
-F "hub.callback=$callback"
CURL

        system($curl);
    }
}
