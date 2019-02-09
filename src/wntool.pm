#!/usr/bin/perl -s
# Written by Yeun-Hsien Tseng on 2005/08/07
# Given a set of terms (each term may be a multiple-word phrase),
#   return a set of common hypernyms ordered by specificity and counts
# After a series of tests, I found that this method's effectiveness 
#   is similar to that of 
#   http://infomap.stanford.edu/cgi-bin/semlab/infomap/classes/print_class.pl?args=$term1+$term2

# perl -s wntool.pm rpm disk atomize splat Atomizing disk
#    use wntool;
#    ($rFnode, $rWeight, $rSense) = &wntool::SemanticClass(@ARGV);

package wntool;
    use Lingua::Wordnet;
    use Lingua::Wordnet::Analysis;
    use strict;

    my $wn = new Lingua::Wordnet;
    my $analysis = new Lingua::Wordnet::Analysis;
    my $root = '#WnRoot#';
    my $debug = 0;
    
# Given a set of word, find the semantic categories based these words
#   by use of WordNet.
sub SemanticClass {
    my(@Words) = @_;
    my (@Synsets, $synset, $word, %Sense, %Count, %Cnt, %Papas);
    my ($k, $c, $maxNumValidWords, @A, %H);

    foreach $word (@Words) {
	@Synsets = $wn->lookup_synset(lc $word, 'n');
#print "\@Synsets='@Synsets'\n";
	$Sense{$word} = scalar @Synsets; # number of sense of a word
	next if @Synsets == 0 or not defined $Synsets[0];
	$maxNumValidWords ++; # for computing weights of nodes
	%Cnt = (); # reset the accumulation of occurrence of papas
	foreach $synset (@Synsets) {
print STDERR 'sw=', $synset->words, "\n" if $main::Odebug;
	    &Hypernyms($synset, \%Papas, \%Cnt, 0);
	}
	# accumulate occurrence of papas upward the tree for different word
	while (($k, $c) = each %Cnt) { $Count{$k}++; }
    }
# Now we have their hypernyms in %Count and relations in %Papas
    if ($maxNumValidWords == 0) {return (\@A, \%H, \%H);}
    my($rFnode, $rWeight) = &FindCommonTerms(\%Count, \%Papas, $maxNumValidWords);
    return($rFnode, $rWeight, \%Sense);
}


# Given a synset, trace upwards in the semantic tree to find all its hypernyms.
#   Records and count the node encountered during this tracing for later use.
sub Hypernyms {
    my($synset, $rPapas, $rCount, $level) = @_;
    my ($st, @list, $synwords, @words, $words, $word);
    @words = $synset->words; $synwords = join "\t", @words;
#    eval("\@list = \$synset->hypernyms"); # next seems to be more efficient
    eval { @list = $synset->hypernyms };
    die ($@) if ($@);
    $level++;
    $rPapas->{$synwords} = $root if @list == 0;
    foreach $st (@list) {
    	@words = $st->words; $words = join "\t", @words;
    	# words in the same papa node are separated by "\t"
print STDERR " "x$level, "st=", $words, "\n" if $main::Odebug;
	$rCount->{$words}++;
	$rPapas->{$synwords} .= $words . "\n"; 
	# multiple papas are separated by "\n"
	&Hypernyms($st, $rPapas, $rCount, $level);
    }
#    return ($rPapas, $rCount); 
}


sub FindCommonTerms {
    my($rCount, $rPapas, $maxNumTerms) = @_;
    my(@Term, $k, $v, %h, @Pa, $w, $pa, $word, %Sons, $son);
    # delete duplicate papas,  sort by count, and then create the %Sons
    while (($k, $v) = each %$rPapas) {
    	%h = ();
    	@Pa = split /\n/, $v;
    	foreach (@Pa) { $h{$_}++; }
    	@Pa = sort {$h{$b} <=> $h{$a}} keys %h;
#print "k=$k => Pa=", join("; ", @Pa), "\n" if @Pa>1;
    	$rPapas->{$k} = join("\n", @Pa);
    # create the %Sons hash for later use
    	foreach $pa (@Pa) {
    	    $Sons{$pa} .= "\n" if defined $Sons{$pa};
    	    $Sons{$pa} .= $k;
    	}
    }
# select those nodes in lowest level but have most occurrence
    my ($node, @Nodes, @FilteredNodes, %Weight, $MaxWeight, $i);
    # Create weights based on $rCount and depth to the root;
    $MaxWeight = &CreateWeight($root, \%Sons, $rCount, $maxNumTerms, \%Weight, 0, 0);
    # Filter nodes by &EqualWithMaxSon(); and $maxNumTerms
    foreach $node (keys %Sons) {
    	next if &EqualWithMaxSon($node, \%Sons, $rCount) 
#    		or $rCount->{$node} < $maxNumTerms * 0.25;
		or $Weight{$node} < 0.35*$MaxWeight;
    	push @FilteredNodes, $node;
    }
    $i = 0; $v = @FilteredNodes;
    $v = $v>$maxNumTerms?$maxNumTerms:$v;
#print "\nSelected nodes... root='$root' \n"; #Son_of_root=$Sons{$root}\n\n";
    foreach $node (sort {$Weight{$b} <=> $Weight{$a}} @FilteredNodes) {
    	push @Nodes, $node; $i++; 
#    	print "$rCount->{$node} : ", &ts($Weight{$node}), " : $node \n";
	last if $i >= $v;
    }
#print "End of Selected nodes...\n";
    return (\@Nodes, \%Weight);
}

sub EqualWithMaxSon {
    my($node, $rSons, $rCount) = @_;
    my($max, $n);
    foreach $n (split /\n/, $rSons->{$node}) {
    	return 1 if $rCount->{$node} == $rCount->{$n}
    }
    return 0;
}

sub CreateWeight {
    my($node, $rSons, $rCount, $maxNumTerms, $rWeight, $level, $MaxWeight) = @_;
    my($n, @Sons, $w);
    $rWeight->{$node} = &ts($rCount->{$node}/$maxNumTerms 
    			* 2*(-0.5+1/(1+exp(-0.125*$level)))); # sigmoid function
    $MaxWeight = $rWeight->{$node} if $MaxWeight < $rWeight->{$node};
    @Sons = split /\n/, $rSons->{$node};
    foreach $n (@Sons) {
	$MaxWeight = &CreateWeight($n, $rSons, $rCount, $maxNumTerms, $rWeight, $level+1, $MaxWeight);
    }
    return $MaxWeight;
}

sub ts { 
#    my($me, $x, $n) = @_; 
    my($x, $n) = @_; 
    $n=4 if not $n; return sprintf("%0.".$n."f", $x); 
}

1;
