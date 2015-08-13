#!/usr/bin/perl
use strict;
use warnings;

use feature ':5.10';
use autodie;

use JSON;

# here I read the json that comes in from the overpass query and massage it to
# be acceptable to the solver. The input comes from query.sh.


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

my $Nneighbors_total = 0;
my $node0_idx;

for my $elem (@{$osm->{elements}})
{
    if($elem->{type} eq 'node')
    {
        my $lat = $elem->{lat};
        my $lon = $elem->{lon};
        my $idx = scalar keys %nodes;

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

for my $node_id ( sort {$nodes{$a}{idx} <=> $nodes{$b}{idx}} keys %nodes )
{
    say "$nodes{$node_id}{lat} $nodes{$node_id}{lon} " .
      join(' ', @{$nodes{$node_id}{neighbors}});
}
