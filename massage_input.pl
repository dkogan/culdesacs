#!/usr/bin/perl
use strict;
use warnings;

use feature ':5.10';
use autodie;

use JSON;
use PDL;
use PDL::NiceSlice;
my $pi     = 3.14159265359;
my $Rearth = 6371000.0; # meters



# here I read the json that comes in from the overpass query and massage it to
# be acceptable to the solver. The input comes from query.sh. To make things
# simpler for the next layer, I pass on the coords not as latlon, but as x,y in
# a tangent plane. The tangent plane is centered on a "center" point computed as
# the average of all latlon nodes (sloppy, but good enough for the purpose).





my $infile = shift
  //die ".json input must appear on the commandline";

my $node0_id;
if( @ARGV )
{
    $node0_id = shift
}
else
{
    say STDERR "node0 not given, so assuming the intersection of 3rd/New Hampshire in Los Angeles";
    $node0_id = 123667672;
}


# slurp input. Assuming it's not too large
my $osm = decode_json(scalar `cat $infile`);
my %nodes;

my $accum_lat = 0;
my $accum_lon = 0;

my $Nneighbors_total = 0;
my $node0_idx;

for my $elem (@{$osm->{elements}})
{
    if($elem->{type} eq 'node')
    {
        my $lat = $elem->{lat};
        my $lon = $elem->{lon};
        my $idx = scalar keys %nodes;

        $accum_lat += $lat;
        $accum_lon += $lon;

        $nodes{$elem->{id}} = { lat       => $lat,
                                lon       => $lon,
                                idx       => $idx,
                                neighbors => []};

        $node0_idx = $idx if $elem->{id} == $node0_id;
    }
    elsif($elem->{type} eq 'way')
    {
        my $nodeid_last;

        for my $nodeid(@{$elem->{nodes}})
        {
            die "Way $elem->{id} references not-yet-seen node $nodeid"
              unless exists $nodes{$nodeid};

            if( defined $nodeid_last )
            {
                push @{$nodes{$nodeid}     {neighbors}}, $nodes{$nodeid_last}{idx};
                push @{$nodes{$nodeid_last}{neighbors}}, $nodes{$nodeid}     {idx};
                $Nneighbors_total += 2;
            }

            $nodeid_last = $nodeid;
        }
    }
}


if( !defined $node0_idx )
{
    die "Query did not contain the desired node 0";
}




my $Nnodes = scalar keys %nodes;
say "Nnodes: $Nnodes";
say "Nneighbors: $Nneighbors_total";
say "Node0_idx: $node0_idx";


# I transform my points to a 2d plane tangent to my Earth sphere (good enough)
# at the center of the query rectangle. This coordinate system has
#   x pointing East,  as observed by a viewer at this location
#   y pointing North, as observed by a viewer at this location
#   z pointing up,    as observed by a viewer at this location
my @latlon_center = ($accum_lat / $Nnodes,
                     $accum_lon / $Nnodes);
my $v_center = v_from_latlon(@latlon_center);
my $p_center = $v_center * $Rearth;
my $R = PDL::cat( east_at_latlon (@latlon_center),
                  north_at_latlon(@latlon_center),
                  $v_center )->transpose;



for my $node_id ( sort {$nodes{$a}{idx} <=> $nodes{$b}{idx}} keys %nodes )
{
    my @xy = map_latlon( $nodes{$node_id}{lat}, $nodes{$node_id}{lon} )->list;

    say join(' ', @xy, @{$nodes{$node_id}{neighbors}});
}





sub v_from_latlon
{
    my ($lat, $lon) = @_;

    my $clon = cos($lon * $pi / 180.0);
    my $slon = sin($lon * $pi / 180.0);
    my $clat = cos($lat * $pi / 180.0);
    my $slat = sin($lat * $pi / 180.0);
    return pdl( $clon*$clat, $slon*$clat, $slat);
}

sub north_at_latlon
{
    my ($lat, $lon) = @_;

    my $clon = cos($lon * $pi / 180.0);
    my $slon = sin($lon * $pi / 180.0);
    my $clat = cos($lat * $pi / 180.0);
    my $slat = sin($lat * $pi / 180.0);

    return pdl( -$clon*$slat, -$slon*$slat, $clat );
}

sub east_at_latlon
{
    my ($lat, $lon) = @_;

    my $clon = cos($lon * $pi / 180.0);
    my $slon = sin($lon * $pi / 180.0);
    my $clat = cos($lat * $pi / 180.0);
    my $slat = sin($lat * $pi / 180.0);

    return pdl( -$slon, $clon, 0);
}

sub map_latlon
{
    # input is ($lat,$lon)

    my $p = $Rearth * v_from_latlon(@_);

    my $p_mapped = ($p - $p_center) x $R;

    # locally the surface is flat-enough, and I just take the (E,N)
    # tuple, and ignore the height (deviation from flat)
    return $p_mapped->(0:1);
}
