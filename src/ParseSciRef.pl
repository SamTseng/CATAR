#!/usr/bin/perl -s
# read in the Scientific citations extract from the "Other References" in 
#   U.S. patents, classified the citation formats
#   Written on 2005/06/12 by Yuen-Hsien Tseng
# D:\demo\lwp>perl -s ParseSciRef.pl nanoSciRefs.txt >nanoSciRefs_3.txt
# perl -s ParseSciRef.pl nanoSciRefs.txt > nanoSciRefs_2.txt
    use SamOpt;  &SamOpt();
    use ParseSciRef;
    $SciRef = ParseSciRef->new( );

    &ParseSingleCitation(@ARGV) if $O1;

    print "Patent\tType\tYear\tVol\tStartPage\tAuthor\tJouTitle\tPubTitle\tOrgCitation\n";
    %Type = ();
    while (<>) {
    	chomp;
	($pn, $c) = split /\t/, $_;
	$rSciRef = $SciRef->ParseSciRef($c);
	$Type{$rSciRef->[0]} ++; # 1st element is Type
	print "$pn\t", join("\t", @$rSciRef), "\t$c\n";
    }
    @T = sort {$a<=>$b} keys %Type;
    foreach $t (@T) {
	print STDERR "$t =>",  $Type{$t}, "\n";
    }

sub ParseSingleCitation {
    #my() = @_;
    print "Input:";
    $citation = <STDIN>; chomp $citation;
    print "Output:\n";
    $rSciRef = $SciRef->ParseSciRef($citation);
#    print join("\n", @$rSciRef), "\n"; # "\n\n$citation\n";
print <<ToEnd;
PubYear=$rSciRef->[1]
Vol=$rSciRef->[2]
StartPage=$rSciRef->[3]
FirstAuthor=$rSciRef->[4]
PubTitle=$rSciRef->[5]
JouTitle=$rSciRef->[6]
ToEnd
    exit;
}
