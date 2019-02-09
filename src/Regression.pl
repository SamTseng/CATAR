#!/usr/bin/perl -s
    use vars; use strict;
    use Statistics::Regression;
    my $reg = Statistics::Regression->new(2, "linear regression", ["const", "x"]);
    for(my $i=0; $i<6; $i++){ $reg->include( -2*$i, [ 1.0, $i ] ); }
    
    
    my @coeff= $reg->theta();
    print STDERR join(", ", @coeff), "\n";
    exit;
