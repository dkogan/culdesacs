#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Euclid;
use IPC::Run 'run';
use feature ':5.10';


my $lat         = $ARGV{'--center'}{lat};
my $lon         = $ARGV{'--center'}{lon};

# I want radius in meters
my ($rad,$unit) = $ARGV{'--rad'} =~ /([0-9\.]+)(.*?)/;
if   ($unit =~ /mile/) { $rad *= 5280 * 12 * 2.54 / 100; }
elsif($unit =~ /km/ )  { $rad *= 1000; }


my $cachefile = "query_${lat}_${lon}_${rad}.json";
if( -e $cachefile )
{
    say "Cache file '$cachefile' exists. Doing nothing";
    exit 0;
}


my $query = <<EOF;
[out:json];

way
 ["highway"]
 (around:$rad,$lat,$lon);

(._;>;);

out;
EOF

my $api = "http://overpass-api.de/api/interpreter";
my $cmd = [qw(curl -X POST --data @-), $api];

run($cmd, \$query, '>', $cachefile) or die "Error querying the server";






__END__

=head1 NAME

query.pl - queries OSM ways from the global database in a radius around a point

=head1 SYNOPSIS

 $ ./query.pl --radius 20miles

=head1 DESCRIPTION

Contacts the OSM server, returns all road data at most a given radius from a
given point. The query is saved (as JSON) into query_lat_lon_radius.json. If
such a file exists, we treat it as a cache and do NOT query the server.

=head1 OPTIONAL ARGUMENTS

=over

=item --center <lat>,<lon>

Center point. Defaults to 3rd/New Hampshire in Los Angeles

=for Euclid:
  lat.type: number
  lat.default: 34.0690448
  lon.type: number
  lon.default: -118.292924

=item --rad <radius>

How far around the center to query. This must include units (no whitespace
between number and units). If not given, I use a radius of 20 miles

=for Euclid:
  radius.type: /[0-9]+(?:\.[-9]*)?(?:miles?|km|m)/
  radius.default: "20miles"

=back

=head1 AUTHOR

Dima Kogan, C<< <dima@secretsauce.net> >>
