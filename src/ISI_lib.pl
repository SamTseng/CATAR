# These functions are to be required (or use) by others
# Written by Yuen-Hsien Tseng on 2011/02/20


# Given two journal titles, see if the first is the abbreviation of the second
sub ISI_Journal_Match {
	my($j1, $j2) = @_; my(@Stopword, $sw);
#	$j1 = uc $j1; $j2 = uc $j2; # input string should already be in upper case
	$j1 =~ s/(\w)\-(\w)/$1 \- $2/g; # insert space before and after dash to make dash a word
	$j2 =~ s/(\w)\-(\w)/$1 \- $2/g; # insert space before and after dash to make dash a word
	@Stopword = qw(OF AND THE IN ON FOR WITH PART SECTION & A AN DES DE);
	foreach $sw (@Stopword) { $j2 =~ s/ $sw / /g; }
# ACOUST PHYS+ vs ACOUSTICAL PHYSICS
# ACTA ACUST UNITED AC vs ACTA ACUSTICA UNITED WITH ACUSTICA
# 4OR-Q J OPER RES <=> 4OR-A QUARTERLY JOURNAL OPERATIONS RESEARCH
	my($i, $i1, $i2, $w1, $w2, @J1, @J2);
	$i1 = $i2 = 0;
	@J1 = split ' ', $j1;
	@J2 = split ' ', $j2;
#print  "$j1 <=> $j2\n";
	for ($i=0; $i<@J2; $i++) {
		last if $i1 >= @J1; # index $i1 is out of range
#print "\$J1[$i1]=$J1[$i1], \$J2[$i2]=$J2[$i2]\n";
#		if ($J2[$i2] =~ /^$J1[$i1]/) { $i1++; $i2++; next; }
		if (substr($J2[$i2], 0, length($J1[$i1])) eq $J1[$i1]) { $i1++; $i2++; next; }
		else {last if $i==0;}
		$w1 = $J1[$i1];
		$w1 =~ s/\W+$//; # delete last non-word letters
#		if ($J2[$i2] =~ /^$w1/) { $i1++; $i2++; next; } # try again
		if (substr($J2[$i2], 0, length($w1)) eq $w1) { $i1++; $i2++; next; } # try again
	}
	return 1 if ($i1 == @J1 and $i2 == @J2);
	return 0;
}

1;
