#!/usr/bin/perl
# 從「不確定之產品與應用.xls」提供的詞彙，找出其出現的專利連結或專利號，
#   以便以人工判斷是否為衣康酸之應用
    use Cluster;
    use SAMtool::Stem;
    $rDC = Cluster->new( { 'debug'=>0 } );
    $rDC->SetValue('IndexName', shift @ARGV);
    $rDC->SetValue('IndexPath', shift @ARGV);

# D:\demo\STPIWG\src>perl -s UnsureTerm.pl ItaA_dc ..\Result\ItaA_dc d:\IEK\2009\UnsureTerm.txt > d:\IEK\2009\UnsureTerm2Title.txt
    &RetrieveTitle(pop @ARGV);

sub RetrieveTitle {
    my($TermListFile) = @_;
    my $NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
    my $rInv = $rDC->{'Inv'}; # a ref to a hash, with a term as its key
    my $rTitle = $rDC->{'Title'}; # a ref to an array
    my($t, $df, $p, @Posting, $DocID, $tf, @A, %Title, $i, $j, $k);
    @ARGV = ($TermListFile);
    while (<>) {  
	chomp; ($t, $df) = split /\t/, $_;
    	@A = map {Stem::stem(lc $_)} split ' ', $t;
    	$t = join ' ', @A;
#    	$t = $_;
	$p = $rInv->{$t};
	if ($p eq '') { print STDERR "Not indexed : ",++$ie, " : $_ : $t\n"; next; }
	@Posting = split /,/, $p;
	print "\n$_ =>\n";
	for($i=0, $k=0; $i<@Posting; $i+=2) {
	    print ++$k, " : ", $rTitle->[$Posting[$i]], "\n";
	    $Title { $rTitle->[$Posting[$i]] }++;
	}
    }
# print non-duplicate titles
    print "\nTitles after deleting duplications:\n";
    print "No : Number_of_Duplicate : PatNo : Title\n";
    while (my($k, $v) = each %Title) {
    	print ++$j, " : $v : $k\n";
    }
#    print STDERR "NumDoc=$NumDoc\n", $rDC->GetValue('IndexName'), 
#    ", ", $rDC->GetValue('IndexPath');
}

=Comments until next =cut

When "#    	$t = $_;", we got:
D:\demo\STPIWG\src>perl -s UnsureTerm.pl ItaA_dc ..\Result\ItaA_dc d:\IEK\2009\UnsureTerm.txt > d:\IEK\2009\UnsureTerm2Title.txt
Not indexed : 1 : AD : ad
Not indexed : 2 : radical initiator : radical initiator
Not indexed : 3 : lens : len
Not indexed : 4 : agriculture : agriculture

When "    	$t = $_;", we got:
D:\demo\STPIWG\src>perl -s UnsureTerm.pl ItaA_dc ..\Result\ItaA_dc d:\IEK\2009\UnsureTerm.txt > d:\IEK\2009\UnsureTerm2Title.txt
Not indexed : 1 : AD : AD
Not indexed : 2 : Catalysts : Catalysts
Not indexed : 3 : gels : gels
Not indexed : 4 : radical initiator : radical initiator
Not indexed : 5 : lens : lens
Not indexed : 6 : aqueous suspension : aqueous suspension
Not indexed : 7 : agriculture : agriculture

=cut
