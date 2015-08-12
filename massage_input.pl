#!/usr/bin/perl
use strict;
use warnings;

use feature ':5.10';
use autodie;

use JSON;

# here I read the json that comes in from the overpass query and massage it to
# be acceptable to the solver. The input comes from query.sh.


my $infile = shift
  or die ".json input must appear on the commandline";

# slurp input. Assuming it's not too large
my $osm = decode_json(scalar `cat $infile`);
my %nodes;

my $Nneighbors_total = 0;

for my $elem (@{$osm->{elements}})
{
    if($elem->{type} eq 'node')
    {
        my $lat = $elem->{lat};
        my $lon = $elem->{lon};
        $nodes{$elem->{id}} = { lat       => $lat,
                                lon       => $lon,
                                idx       => scalar keys %nodes,
                                neighbors => []};
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


my $Nnodes     = scalar keys %nodes;
say "Nnodes: $Nnodes";
say "Nneighbors: $Nneighbors_total";

for my $node_id ( sort {$nodes{$a}{idx} <=> $nodes{$b}{idx}} keys %nodes )
{
    say "$nodes{$node_id}{lat} $nodes{$node_id}{lon} " .
      join(' ', @{$nodes{$node_id}{neighbors}});
}
