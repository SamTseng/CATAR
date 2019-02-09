#!/usr/bin/perl -s
	use SamOpt;  &SamOpt();
	use vars; use strict;
	use SAMtool::Stem;

# Step 2. Convert the Term-Relationship into Pajek's format
# perl -s filterRT.pl -Opajek InfoBank_kr_u.txt > InfoBank_kr_u.net
# perl -s filterRT.pl -Opajek InfoBank_kr_p.txt > InfoBank_kr_p.net
# perl -s filterRT.pl -Opajek InfoBank_kr_t.txt > InfoBank_kr_t.net
# perl -s filterRT.pl -Opajek InfoBank_kr_e.txt > InfoBank_kr_e.net
# perl -s filterRT.pl -Opajek InfoBank_kr_pte.txt > InfoBank_kr_pte.net
# perl -s filterRT.pl -Opajek InfoBank_kr_pte_banana.txt > InfoBank_kr_pte_banana.net
# perl -s ..\InfoBank\filterRT.pl -Opajek esi_kr_up.txt > esi_kr_up.net
# perl -s filterRT.pl -Opajek -Oyear ..\Result\ICT\CiteJ9.txt > ..\Result\ICT\CiteJ9.net
	if ($main::Opajek) { &ToPajekFormat(@ARGV); exit; }
# perl -s filterRT.pl -OpajekPos ..\Result\ScientoDE ..\Result\ScientoDE\DE_DocList.txt 0.1 1.5 > ..\Result\ScientoDE\SimPairs.net
	if ($main::OpajekPos) { &ToPajekFormat_from_SimPairs(@ARGV); exit; }
# perl -s filterRT.pl -ORT2RT 1897 5 0 ..\Result\SCIENTO_dc\RelatedTerms.txt ..\Result\SCIENTO_dc\Inv.txt > ..\Result\SCIENTO_dc\Key_RT.txt
	if ($main::ORT2RT) { &FromRelatedTerms2RT(@ARGV); exit; }

# Step 3 (less useful). Filter out the translation
# perl -s filterRT.pl -Otrf InfoBank_kr_e.net_tr.txt > InfoBank_kr_e_en.net
	if ($main::Otrf) { &FilterTranslatedResult(@ARGV); exit; }
# Step 3. Translate the Pajek's file into an English version by looking up the translation file
# perl -s filterRT.pl -Otr InfoBank_kr_e.net_tr.txt InfoBank_kr_e.net > InfoBank_kr_e_en.net
	if ($main::Otr) { &TranslateResult(@ARGV); exit; }

# Step 1-2: Extract desired Term-Relationship from larger Term-Relationship
# perl -s filterRT.pl -Ostar ­»¿¼ InfoBank_kr_pte.txt > InfoBank_kr_pte_banana.txt
	if ($main::Ostar) { &ExtractStar(@ARGV); exit; }
# Step 1-3: Extract desired Term-Relationship from larger Term-Relationship
#	extract those who cite $Ocited="Tsai, CC" as the root citation
# perl -s filterRT.pl -Ocited="Tsai, CC" ..\Result\ICT\CiteAU.txt > ..\Result\ICT\CiteTsaiCC.txt
	if ($main::Ocited) { &ExtractCited(@ARGV); exit; }
# perl -s filterRT.pl -OallAU AU.txt CR.txt CiteRT.txt > AU_CiteStat.txt
# C:\CATAR_src\src>perl -s filterRT.pl -OallAU ..\Result\sam\AU.txt ..\Result\sam\CR.txt ..\Result\sam\CiteRT.txt > ..\Result\sam\AU_CiteStat.txt
	if ($main::OallAU) { &ExtractAllAuthorCited(@ARGV); exit; }
# perl -s filterRT.pl -Oany ..\Result\ItaA\ItaA_key_rt.txt d:\IEK\2009\product.txt > ..\Result\ItaA\ItaA_key_rt_p_any.txt
	if ($main::Oany) { &ExtractRelatedTerms_Any(@ARGV); exit; }

# This function is basically the same as that without any option
#   The only difference is that the keyword and all its related terms 
#   will be extracted as long as ANY of the keyword or its related terms
#   matches the term in the given lexicon
sub ExtractRelatedTerms_Any {
	my($RT, %H, $id, $t, $t0, $t1, $df, $r, @R, @NR, $i, $line);
	$RT = shift @ARGV;
# read in the lexicons, store them in a hash
	while ($line = <>) {  
		chomp; next if $line =~ /^\s*$/; # skip if empty line
		if ($line =~ /^\s*\w/) { # assume each line contains only one English term
			$t = join ' ', map {Stem::stem(lc $_)} split ' ', $line;
			$H{$t} = 1 if $t ne '';
	  } else {
			foreach $t (split ' ', $line) { $H{$t} = 1 if $t ne ''; } 
		}
	}
	print STDERR "There are ", scalar keys %H, " terms.\n";
# read in the related terms
	@ARGV = ($RT);
	while ($line = <>) {
		chomp; next if $line =~ /^\s*$/; # skip if empty line
#print "$line\n";
		($id, $t0, $df, $r) = split / : /, $line;
		if ($t0 =~ /^\s*\w/) { # if English keyword
#			$t = join ' ', map {ord($_)<128?Stem::stem(lc $_):$_} split ' ', $t0;
			$t = join ' ', map {Stem::stem(lc $_)} split ' ', $t0;
		} else { # if Chinese
			$t = $t0;
		}
		next if not $H{$t}; # skip if the keyword is not a lexical term
		@NR = (); @R = split /\t/, $r;
		for($i=0; $i<@R; $i+=2) { # foreach related term
			next if $R[$i+1] =~ /^\s*$/; # skip if last element is empty
			$t = $R[$i];
			if ($t =~ /^\s*\w/) { # if English term
				$t1 = join ' ', map {Stem::stem(lc $_)} split ' ', $t;
				next if $main::Oany==2 and not $H{$t1}; # skip if not a lexical term
			# if a term in lexicon, upper case the term
				push @NR, ($H{$t1}?uc $R[$i]:$R[$i]), $R[$i+1];
			} else { # if Chinese term
				next if $main::Oany==2 and not $H{$t}; # skip if not a lexical term
				push @NR, @R[$i..($i+1)]; 
			}
		}
#		next if @NR == 0 and not $main::Oany==2;# remarked on 2015/11/03
		next if @NR == 0; # if no related terms, skip this keyword
		next if $NR[$#NR] =~ /^\s*$/; # skip if last element is empty
		if ($t0 =~ /^\s*\w/) { # if English term
			print "$id\t", uc $t0, "\t$df\t", join("\t", @NR), "\n";
		} else {	
			print "$id\t", $t0, "\t$df\t", join("\t", @NR), "\n";
		}
	}
}

# Step 1. Extract desired Term-Relationship from larger Term-Relationship
# perl -s filterRT.pl InfoBank_kr.txt unit.txt > InfoBank_kr_u.txt
# perl -s filterRT.pl InfoBank_kr.txt effect.txt > InfoBank_kr_e.txt
# perl -s filterRT.pl InfoBank_kr.txt product.txt > InfoBank_kr_p.txt
# perl -s filterRT.pl InfoBank_kr.txt technique.txt > InfoBank_kr_t.txt
# perl -s filterRT.pl InfoBank_kr.txt product.txt technique.txt effect.txt > InfoBank_kr_pte.txt
# perl -s filterRT.pl InfoBank_kr.txt product.txt technique.txt effect.txt unit.txt > InfoBank_kr_pteu.txt
# perl -s ..\InfoBank\filterRT.pl esi_kr.txt up.txt > esi_kr_up.txt
	my($RT, %H, $id, $t, $df, $r, @R, @NR, $i);
	$RT = shift @ARGV;
# read in the lexicons, store them in a hash
	while (<>) {  chomp; $H{$_} = 1;  }
# read in the related terms
	@ARGV = ($RT);
	while (<>) {
	chomp; 
#print "$_\n";
	($id, $t, $df, $r) = split / : /, $_;
	next if not $H{$t}; # skip if not a lexical term
	@NR = (); @R = split /\t/, $r;
	for($i=0; $i<@R; $i+=2) { # foreach related term
		next if not $H{$R[$i]}; # skip if not a lexical term
		push @NR, @R[$i..($i+1)];
	}
	next if @NR == 0;
	print "$id\t$t\t$df\t", join("\t", @NR), "\n";
	}
	exit;

=head Comment until next =cut
http://iv.slis.indiana.edu/lm/lm-pajek.html

File Data Format  	

The file format accepted by Pajek provides information on vertices, arcs 
(directed edges), and undirected edges. A short example showing the file format 
is given below:

Note: the white space should be space, not tab.
-------------------------------------
*Vertices 3
1 "Doc1" 0.0 0.0 0.0 ic Green bc Brown
2 "Doc2" 0.0 0.0 0.0 ic Green bc Brown
3 "Doc3" 0.0 0.0 0.0 ic Green bc Brown 
*Arcs
1 2 3 c Green
2 3 5 c Black
*Edges
1 3 4 c Green
-------------------------------------

In the example there are 3 vertices Doc1, Doc2 and Doc3 denoted by numbers 1, 2 
and 3. The (fill) color of these nodes is Green and the border color is Brown. 
The initial layout location of the nodes is (0,0,0). Note that the (x,y,z) 
values can be changed interactively after drawing.

There are two arcs (directed edges). The first goes from node 1 (Doc1) to node 2 
(Doc2) with a weight of 3 and in color Green. 

For edges, there is one from node 1 (Doc1) to node 3 (Doc3) of weight of 4, and 
is colored green.

Imagine you want to layout a set of nodes according to a given similarity 
matrix. Given the similarity matrix, e.g., the sample file generated using 
Latent Semantic Analysis, you can use a Perl parser pajekConv.pl to generate the 
Pajek input file. To execute the Perl scrip on 'ella' or 'iuni', simply type at 
the command prompt:

perl pajekConv.pl inputFileName outputFileName 

Make sure to replace inputFileName with the name of the similarity matrix file. 
The generated Pajek input file will be named outputFileName.

=cut

=head Comment until next =cut
/* Pajek network data format:						  */
/*													 */
/* An example of non directed or simple social network */
/* It has two parts (each marked by asterisk) which	*/
/*   closely followed Graph theory definition of graph */
/* Source: Roethlisberger and Dickson 1939 :501ff	  */

The first part after the comments must start with *Vertices, that is asterisk 
and Vertices without a space between them, and the number of vertices. 

It is followed by a sequence of integers and labels, where the integer sequence 
starts from 1. The labels are one word or more, in which case it has to be 
double quoted like: 1 "Inspector 1". 

The second part is marked by *Edges, that is an asterisk and Edges without a 
space between them, which is followed by edges list, and ends with a blank line. 
Please include the last and only one blank line, otherwise Pajek will be 
confused.

*Vertices 2637
1212 "2001:Chan, TW" 0.5909 0.7908 x_fact 1.92 y_fact 1.92  ic Emerald
1312 "2003:Chang, CY" 0.6818 0.4819 x_fact 1.55 y_fact 1.55  ic Emerald
1584 "2005:Lin, CB" 0.7727 0.1520 x_fact 1.25 y_fact 1.25  ic Emerald
*Edges
1212 1312
1212 1584

=cut


sub ToPajekFormat {
	my($Nnode, $id, $t, $df, @R, %T2N, @N, $e, %Edge, %Degree, $tt, %Cite);
	my(%T2Gid, %Gid2T, $gid, %T2df, @Term, $rTerm2Cid, %T2Degree, %Cited,%Node);
	my($maxDF, $minDF) = (0, 10000000);  
	($Nnode, $gid) = (0, 0);
	if ($main::OcluTerm) { $rTerm2Cid = &ReadCluTerm($main::OcluTerm); }
	while (<>) { # read from files listed in the command line
		chomp; next if /^\s*$/; # skip if empty line
		($id, $t, $df, @R) = split /\t| : /, $_;
		$maxDF = $df if $maxDF < $df; $minDF = $df if $minDF > $df;
		$T2N{$t} = ++$Nnode if ($T2N{$t} eq ''); # a new term (node)
		$T2df{$t} = $df;
#		next if @R == 0; # skip if no related term
	@Term = ($t); $Node{$t}++;
	unshift @R, $t, $df if $main::Ocir;
	for($i=0; $i<@R; $i+=2) {
		next if $t eq $R[$i]; # 2009/07/05, remove self-citation
	# if $main::Ocir, create a circular net, otherwise create a star net
		last if ($main::Ocir and $i+2==@R);
		$df = $R[$i+1];
		$maxDF = $df if $maxDF < $df; $minDF = $df if $minDF > $df;
		$T2N{$R[$i]} = ++$Nnode if ($T2N{$R[$i]} eq ''); # a new term (node)
		$T2df{$R[$i]} = $df;
	  if ($main::Ocir) {
		$df = $R[$i+3];
		$maxDF = $df if $maxDF < $df; $minDF = $df if $minDF > $df;
		$T2N{$R[$i+2]} = ++$Nnode if ($T2N{$R[$i+2]} eq ''); # a new term (node)
		$T2df{$R[$i+2]} = $df;
	  }
##print  "\$rTerm2Cid->{$t}=$rTerm2Cid->{$t}, \$rTerm2Cid->{$R[$i]}=$rTerm2Cid->{$R[$i]}\n";
#print STDERR "\$rTerm2Cid->{$t}=$rTerm2Cid->{$t}, \$rTerm2Cid->{$R[$i]}=$rTerm2Cid->{$R[$i]}\n";
		if ($main::Ocir) { $tt = $R[$i+2]; } else { $tt = $t; }
		next if ($main::OcluTerm) and ($rTerm2Cid->{$tt} != $rTerm2Cid->{$R[$i]});
		$e = join (' ', sort ($T2N{$tt}, $T2N{$R[$i]}));
		if ($t ne $R[$i]) {
			$Node{$R[$i]}++;
		$Cited{$R[$i]} .= "$t\t"; #$R[$i] is cited by $t
		$Cite{$t} .= "$R[$i]\t"; # $t cites $R[$i]
		}
		next if $Edge{$e}; # skip if already in %Edge
		next if $main::OmaxDegree and 
			($T2Degree{$tt}>=$main::OmaxDegree or 
			 $T2Degree{$R[$i]}>=$main::OmaxDegree);
		$T2Degree{$tt}++; $T2Degree{$R[$i]}++;
		$Edge{$e} = 1;
		push @Term, $R[$i]; push @Term, $R[$i+2] if ($main::Ocir);
	}
# Now find all the terms in @Term to know their group
	$gid = &AssignGroup($gid, \@Term, \%T2Gid, \%Gid2T);
#print STDERR "nid=$T2N{$t}, \$T2Gid{$t}=$T2Gid{$t}, \@R=@R\n";
	}

#print "T2Gid=\n", join(";\n", map {"$_ => $T2Gid{$_}"} keys %T2Gid), "\n";
#print "Cite=\n",  join(";\n", map {"$_ => $Cite{$_}"}  keys %Cite), "\n";
#print "Cited=\n", join(";\n", map {"$_ => $Cited{$_}"} keys %Cited), "\n";

# Get those Nids (in %Nid) that were selected by the user
	my(%N2T, @Nid, %Nid, $i, $size,@G, $k, $v, $gw, @GW, $rT2XY, $rT2Gid);
	if ($main::Oyear) {
	$rT2Gid = &FindRoots(\%Cite, \%Cited, \%Node);
	undef %T2Gid;
	while (($k, $v) = each %$rT2Gid) { $T2Gid{$k} = $v; }
	}
#print "T2Gid=", join('; ', map {"$_:$T2Gid{$_}"} keys %T2Gid), "\n";
	@GW = sort keys %T2Gid;
	foreach $k (@GW) { $v=$T2Gid{$k}; $G[$v].="$k,"; $Nid[$v].="$T2N{$k},";}
	$v = ($main::Om)?$main::Om:1;
	for($i=1; $i<@G; $i++) {
		$k = ($Nid[$i]=~tr/,/,/); next if $k<$v;
		next if $main::Opat ne '' and not ($G[$i] =~ /${main::Opat}/i);
		print STDERR "$i $G[$i]\n$i $Nid[$i]\n"; 
	}
print STDERR "\n\$main::Opat=$main::Opat\n";
	print STDERR "Which groups do you want (e.g.: 1 3 9 11, 0 for all):";
	$gw = <STDIN>; chomp $gw; @GW = split ' ', $gw;
	if ($gw) { @Nid = @Nid[@GW]; }
	foreach $k (@Nid) { foreach $v (split/,/,$k) {$Nid{$v} = 1;} }
	undef @Nid; undef @G; # no more use like a hash : key to value
#print STDERR "\@Nid=@Nid\n";
#print STDERR "Nid=", (sort {$a<=>$b} keys %Nid), "\n";
# Now %Nid has those Nids we need. But @Nid can be forget

# Next segment uses the following variables whose values are set in the above:
# %T2N : Term to TermID
# %T2df : Term to Document Frequency
# %T2Gid : Term to Group ID
# %Edige : a hash whose key is "TermID1\tTermID2" and whose value is always 1
# %Nid : key=TermID (needed), value=1
	my $aColor = &SetColor();
	print "*Vertices ", scalar keys %T2N, "\n";
#	print "*Vertices ", scalar keys %Nid, "\n";
	%N2T = reverse %T2N;
	@G = sort {$a <=> $b} keys %N2T;
	foreach $i (@G) { 
#		next if not $Nid{$i}; 
$t = $N2T{$i}; 
#if ($t=~/(\d\d\d\d)/) { (delete $Nid{$i} and next) if ($1<1999);  print STDERR "$1,"; }
#if ($t=~/19\d\d/) { delete $Nid{$i}; next; }
		push @Nid, $i; 
	}
#print STDERR "\nNid= @Nid\n";
	# Now @Nid has those Nids that were selected
	$rT2XY = &ComputeXY(\@Nid, \%N2T) if $main::Oyear;
	foreach $i (@Nid) {
		next if not $Nid{$i}; 
#print STDERR "\$Nid{$i}=$Nid{$i}\n";
		$t = $N2T{$i}; 
#if ($t=~/(\d\d\d\d)/) { (delete $Nid{$i} and next) if ($1<1999);  print STDERR "$1,"; }
#		next if $Gid2T{$T2Gid{$t}} !~ /\t/; # skip if only singleton
#		$size = sprintf("%1.2f", (5*(log($T2df{$t})-log($minDF))/(log($maxDF)-log($minDF))+1));
		$size = sprintf("%1.2f", (4*(sqrt($T2df{$t})-sqrt($minDF))/(sqrt($maxDF)-sqrt($minDF))+1));
#		$size = sprintf("%1.2f", (5*($T2df{$t}-$minDF)/($maxDF-$minDF)+1));
#	print "$i \"$t\"\n"; # print node id and node label
	print "$i \"$t\" ";
	print $rT2XY->{$t} if $main::Oyear;
	print " x_fact $size y_fact $size  ic " . 
	$aColor->[$T2Gid{$t}%@$aColor]. "\n";
#	$aColor->[$T2Gid{$t}%@$aColor]. " bc Mahogany\n";
	}
	print "*Edges\n";
	@Nid = sort {$a <=> $b} keys %Edge;
	foreach $i (@Nid) {
	($k, $v) = split ' ', $i;
#	next if not ($Nid{$k} or $Nid{$v});  # 2009/02/22
	next if not ($Nid{$k} and $Nid{$v}); # 2009/02/22
	print "$i\n";
	}
	print "\n";

	while (($k, $v)=each %T2Degree) { $Degree{$v}++; }
print STDERR "\nDegree\tNumOfNodes\n";
print STDERR join("\n", map{$_."\t".$Degree{$_}} sort {$b<=>$a} keys %Degree), "\n";
}

sub SetColor {
	my @Color = sort 
	{substr($a,-1,1).substr($a,0,1) cmp substr($b,-1,1).substr($b,0,1)} 
	split ' ', qq{
GreenYellow Yellow Goldenrod Dandelion Apricot Peach Melon YellowOrange Orange 
BurntOrange Bittersweet RedOrange Mahogany Maroon BrickRed Red OrangeRed 
RubineRed WildStrawberry Salmon CarnationPink Magenta VioletRed Rhodamine 
Mulberry RedViolet Fuchsia Lavender Thistle Orchid DarkOrchid Purple Plum Violet 
RoyalPurple BlueViolet Periwinkle CadetBlue CornflowerBlue MidnightBlue NavyBlue 
RoyalBlue Blue Cerulean Cyan ProcessBlue SkyBlue Turquoise TealBlue Aquamarine 
BlueGreen Emerald JungleGreen SeaGreen Green ForestGreen PineGreen LimeGreen 
YellowGreen SpringGreen OliveGreen RawSienna Sepia Brown Tan Gray Black White 
LightYellow LightCyan LightMagenta  LightPurple LightGreen LightOrange Canary 
LFadedGreen Pink LSkyBlue Gray40};
#print STDERR "Color=@Color\n";
	return \@Color;
}

sub AssignGroup {
	my($gid, $rT, $rT2Gid, $rGid2T) = @_;  my($t, $i, $j, %Gid, @Gid);
	# remember all the old gids in %Gid
	foreach $t (@$rT) { $Gid{$rT2Gid->{$t}} = 1 if ($rT2Gid->{$t} ne ''); }
	@Gid = sort {$a <=> $b} keys %Gid; # sort the gids in ascending order
	if (@Gid == 0) {# no any group id has been found
	$i = ++$gid; # it is a new group
	} else { # it should assign to an old group (with lowest gid)
	$i = $Gid[0];
	for($j=1; $j<@Gid; $j++) { # change those terms' gids to the first gid
		foreach $t (split /\t/, $rGid2T->{$Gid[$j]}) { 
			$rT2Gid->{$t} = $i; $rGid2T->{$i} .= "$t\t";
		}
		undef $rGid2T->{$Gid[$j]};
	}
	}
	foreach $t (@$rT) { $rT2Gid->{$t} = $i; $rGid2T->{$i} .= "$t\t"; }
	return $gid;
}

sub FindRoots {
	my($rCite, $rCited, $rNode) = @_;  my($gid, $t, $tt, %T2Gid);
	while (($t, $tt) = each %$rNode) {
		next if $rCite->{$t} # $t cites others, so it is not a root
			 or (not $rCite->{$t} and not $rCited->{$t}); # single node
		$T2Gid{$t} = ++$gid;
		&SetGid($t, $rCited, $gid, \%T2Gid);
	}
#print "T2Gid=", join('; ', map {"$_:$T2Gid{$_}"} keys %T2Gid), "\n";
	return \%T2Gid;
}

sub SetGid {
	my($t, $rCited, $gid, $rT2Gid) = @_; my($tt, @Citing);
	@Citing = split /\t/, $rCited->{$t};
#	foreach $tt (@Citing) {  $rT2Gid->{$tt} = $gid; }
#	foreach $tt (@Citing) {  &SetGid($tt, $rCited, $gid, $rT2Gid); }
	foreach $tt (@Citing) {  
		next if $rT2Gid->{$tt}; # skip if already visited
		$rT2Gid->{$tt} = $gid; 
		&SetGid($tt, $rCited, $gid, $rT2Gid); 
	}
}


sub ReadCluTerm {
	my($File) = @_; my($id, $tn, $t, @Terms, %Term2Cid);
	open F, $File or die "Cannot read file:'$File'";
	while (<F>) {
	chomp; ($id, $tn, @Terms) = split /\t|,/, $_;
	for $t (@Terms) { $Term2Cid{$t} = $id; }
	}
	close(F);
	return \%Term2Cid;
}


sub FromRelatedTerms2RT {
	my($NumDoc, $WgtCut, $RTcut, $RTfile, $InvFile) = @_; 
	
	my($rT2DF, $rT2Dlist) = &GetDF_from_InvFile($InvFile);
	
	my($k, $r, $w, @W, %Sim, %K2RT);
	open F, $RTfile or die "Cannot read file:'$RTfile'";
	while (<F>) {
	chomp; 
#	($k, $r, $w) = split /\t/, $_; # "taiwan	singapore	7.2724"
#	next if $w < 2;
	($k, $r, @W) = split /\t/, $_; # "taiwan	singapore	2.14	3.12	1.01"	
#	next if @W < 2; # if only co-occur in one document
	$w=0; foreach (@W) { $w += $_; }
	if ($main::Oidf) {
#print "\$Sim{$k\t$r}  = $w * log($NumDoc/$rT2DF->{$r})\n";
#		$Sim{"$k\t$r"} = &ts($w * log($NumDoc/$rT2DF->{$r}));
#		$Sim{"$r\t$k"} = &ts($w * log($NumDoc/$rT2DF->{$k}));
		$Sim{"$k\t$r"} = &ts($w * 
			( log($NumDoc/$rT2DF->{$r}) + log($NumDoc/$rT2DF->{$k}) )/2);
	} elsif ($main::OidfMax) {
		$Sim{"$k\t$r"} = &ts($w * 
			&Max( log($NumDoc/$rT2DF->{$r}), log($NumDoc/$rT2DF->{$k})) );
	} else {
		$Sim{"$k\t$r"} = $w;
	}
	if ($main::Oidf or $main::OidfMax) {
		next if $Sim{"$k\t$r"} < $WgtCut;
	} else {
		next if $w < $WgtCut; # skip if accumulated weight is less than $WgtCut
	}
	$K2RT{$k} .= "$r\t"; # collect $k's RTs
	}
	close(F);
	my(@RT, $i, $n);
	foreach $k (keys %K2RT) {
		$i++;
		@RT = split /\t/, $K2RT{$k}; # sort the RTs in decreasing order
		$n = @RT = sort {$Sim{"$k\t$b"}<=>$Sim{"$k\t$a"}} @RT;
	$n = ($n<$RTcut)?$n:($RTcut) if $RTcut > 0;
	@RT = @RT[0..$n-1]; # limit the number of related terms a keyword can have
#	@RT = @RT[0..$RTcut-1] if $RTcut>0; # this line leads to a bug.
		print "$i\t$k\t$rT2DF->{$k}\t", 
#		join("\t", map {"$_\t".sprintf("%1.4f", $Sim{"$k\t$_"})} @RT), "\n";
		join("\t", map {"$_\t".$rT2DF->{$_}} @RT), "\n";
	}
	&OutputNodePairSim($main::OpairSim, \%Sim, $rT2Dlist) if ($main::OpairSim);
}

sub Max { my($c, $d) = @_; return ($c>$d)?$c:$d; }

# print "taiwan\tusa\tsimilarity\tNumOfcommonDoc\tDF(taiwan)\tDF(usa)\n";
sub OutputNodePairSim {
	my($File, $rSim, $rT2Dlist) = @_;  my($k, $i, $n);
	open FF, ">$File" or die "Cannot write to file:'$File'";
	foreach $k (sort {$rSim->{$b}<=>$rSim->{$a}} keys %$rSim) {
#		($i, $n) = sort split /\t/, $k;
		($i, $n) = split /\t/, $k;
		print FF join("\t", $i, $n, $rSim->{$k},
		&CommonDetail($i, $n, $rT2Dlist)), "\n";
	}
	close(FF);
}

sub GetDF_from_DocList {  
	my($File) = @_;  
	my($id, $t, $df, $r, %DF, %T2Dlist);
	open F, $File or die "Cannot read file:'$File'";
	while (<F>) { # 1 : russia : 9 : ISI_000072877000011_	1 ...
		($id, $t, $df, $r) = split / : /, $_;
		next if $df <= 0;
		$DF{$t} = $df;  
		$r=~s/\t$//; # remove last tab
		$T2Dlist{$t} = $r;
	}	
	close(F);
	return (\%DF, \%T2Dlist);
}

sub GetDF_from_InvFile {  
	my($InvFile) = @_;  
	my($t, $df, $r, @R, %DF, %T2Dlist);
	open F, $InvFile or die "Cannot read file:'$InvFile'";
	while (<F>) { # slovenia	122,1,513,7,1241,1,1253,1,
		($t, $r) = split /\t/, $_;
		$DF{$t} = int(($r=~tr/,/,/)/2); 
		$r=~s/,$//; # remove last comma
		$T2Dlist{$t} = $r;
	}	
	close(F);
	return (\%DF, \%T2Dlist);
}


sub Common {
	my($e, $rT2Dlist1, $rT2Dlist2) = @_;
	my($t1, $t2) = split /\t/, $e;
	my($df_1, $df1_1, $df2_1) = &CommonDetail($t1, $t2, $rT2Dlist1);
	my($df_2, $df1_2, $df2_2) = &CommonDetail($t1, $t2, $rT2Dlist2);
	print STDERR 
	"\$df=($df_1,$df_2), \$df1=($df1_1,$df1_2), \$df2=($df2_1,$df2_2)\n"
		if ($df_1 != $df_2) or ($df1_1 != $df1_2) or ($df2_1 != $df2_2); 
	return "$df1_1\t$df2_1\t$df_1\t".&ts(2*$df_1/($df1_1+$df2_1));
}

sub CommonDetail{
	my($t1, $t2, $rT2Dlist) = @_;  my(%D1, %D2, $df1, $df2, $df, $d);
	%D1 = split /,|\t/, $rT2Dlist->{$t1};
	%D2 = split /,|\t/, $rT2Dlist->{$t2};
	$df1 = keys %D1; $df2 = keys %D2;
	foreach $d (keys %D1) { $df++ if $D2{$d}; }
	return ($df, $df1, $df2);
}


sub FilterTranslatedResult {
	while (<>) { chomp;
		next if not ((/\."/) or /\*[VE]/ or / \d+$/); #"#skip if not the English line
		$_ =~ s/\."/"/;
		print "$_\n";
	}
}

sub TranslateResult {
	my($TF, $PF) = @ARGV; my(%C2E, $e, $c);
	@ARGV =($TF);
	while (<>) { # set %C2E
		if (/"(.+)"/) { 
		$c = $1; $_ = <>; # read next line
		if (/"(.+)\."/) { $e = $1; $C2E{$c} = $e; }
		}
	}
	@ARGV = ($PF);
	while (<>) {
		$_ =~ s/"(.+)"/"$C2E{$1}"/;
		print $_;
	}
}

# Given a term (star term) and the related-term file, 
#   extract all the related terms starting from the star term
# The result should be able to show a star network.
sub ExtractStar {
	my($star, $File) = @_; my($id, $t, $df, %T2L, %K2L);
	@ARGV = ($File); 
	while (<>) { # store all the related terms in %R
	chomp; ($id, $t, $df) = split /\t| : /, $_;
	$K2L{$t} = $_;
	}
# Now we have %R and $star, recursively extract all the related terms
	$T2L{$star} = 0; # Term-to-Level
	&TraverseTree($star, \%K2L, 0, \%T2L);
}

sub TraverseTree {
	my($t, $rK2L, $depth, $rT2L) = @_;  my($id, $df, @R, $i, $w, @RT);
	last if $depth>1;
	($id, $t, $df, @R) = split /\t| : /, $rK2L->{$t};
	for($i=0; $i<@R; $i+=2) {
	$w = $R[$i];
	if ($rT2L->{$w} eq '') {
		$rT2L->{$w} = $depth+1;
		push @RT, $w, $R[$i+1];
		}
	}
	print "$id\t$t\t$df\t", join("\t", @RT), "\n" if @RT > 0;
	foreach $w (@RT) { # Now recursively traverse the tree
		&TraverseTree($w, $rK2L, $depth+1, $rT2L);
	}
}

# For each author, call ExtractCited to know their citation track.
#   Sort the citation track in decreasing order of size of citation track.
sub ExtractAllAuthorCited {
	my($AU, $CR, $CiteCR) = @_;  
	my(%Auo, %Auc, %AuAll, $au, $df, $flag, $nau, $nauc);
	($flag, $nau, $nauc) = (0, 0, 0);
	open F, $AU or die "Cannot read file from :'$AU'";
	while (<F>) { 
		chomp; next if /^\s*$/;
		($au, $df) = split /\t/, $_; 
		$nau++; $Auo{$au} += $df; $AuAll{$au} += $df;
	}
	close(F);
	open F, $CR or die "Cannot read file from :'$AU'";
	while (<F>) { 
		chomp; next if /^\s*$/; 
		if (/Cited Authors/)  { $flag = 1;  next; }
		if (/Cited Journals/) { $flag = 0;  last; }
		next if not $flag;
		($au, $df) = split /\t/, $_;
		$au =~ s/ (\w+)$/, $1/; # add a comma btn the Surname and middle name
		$nauc++; $Auc{$au} += $df; $AuAll{$au} += $df;
	}
	close(F);
	print STDERR "Number of authors: $nau, number of cited authors: $nauc\n";
# Now we have all the authors in %Au, we can call &ExtractCited() 
#   to know all the citation tracks
	my(@Au, $size);
	@Au = sort {$AuAll{$b} <=> $AuAll{$a}} keys %AuAll;
	$main::Oall = 1;
	foreach $au (@Au) {
		$main::Ocited = $au;
		$size = &ExtractCited($CiteCR);
		print "$au\t$Auo{$au}\t$Auc{$au}\t$size\n";
	}
}

# Given a term (start term) and the related-term file, 
#   extract all the related terms starting from the start term
# The result should be able to show a citation track.
sub ExtractCited {
	my($File) = @_;  my($cited, $id, $t, $df, @R, $rCited, $rC, $i, @Lines);
	$cited = $main::Ocited;
print STDERR "cited=$cited\n";
	@ARGV = ($File);
	while (<>) { # store all the related terms in %R
		chomp; ($id, @R) = split /\t| : /, $_; push @Lines, $_;
#		for($i=0; $i<@R; $i+=2) { # will include those cited by $cited
		for($i=2; $i<@R; $i+=2) { # will only include those cite $cited
			if ($R[$i] =~ /$cited/i) { 
				$rCited->{$R[0]} = 1; $rCited->{$R[$i]} = 1; 
			}
		}
	}
	$i = 0;  
#	goto SkipLoop;
	while (scalar keys %$rCited != scalar keys %$rC) {
		$rC = $rCited; $i++;
		$rCited = &FindCited(\@Lines, $rC);
#print STDERR join(', ', keys %$rCited), "\n";
print STDERR "i=$i, ", scalar keys %$rC,"=>", scalar keys %$rCited, "\n";
	}
SkipLoop:
	if ($main::Oall) { return scalar keys %$rCited; }
# Now we have %Cited containing all the articles cite $cited as a root
#print STDERR join("\n", sort keys %$rCited), "\n";
	my($line, @NR);
	foreach $line (@Lines) {
		($id, @R) = split /\t| : /, $line;
#print STDERR "$R[0]\n";
		next if not $rCited->{$R[0]};
#print STDERR "   $R[0]\n";
		@NR = (); 
		for($i=2; $i<@R; $i+=2) { # foreach related term
			next if not $rCited->{$R[$i]}; # skip if not a desired term
			push @NR, @R[$i..($i+1)];
		}
		next if @NR == 0;
		print "$id\t", join("\t", @R[0..1], @NR), "\n";
	}
}

sub FindCited {
	my($rLines, $rCited) = @_; my(%Cited, $line, $id, @R, $i, @Cited, $c);
	@Cited = keys %$rCited;
	foreach $line (@$rLines) {
		($id, @R) = split /\t| : /, $line;
#		for($i=0; $i<@R; $i+=2) { 
		for($i=2; $i<@R; $i+=2) { 
			if ($rCited->{$R[$i]}) { $Cited{$R[0]} = 1; $Cited{$R[$i]} = 1; }
#			foreach $c (@Cited) {
#				if ($R[$i] =~ /$c/i) { $Cited{$R[0]} = 1; goto HERE; }
#			}
		}
		HERE:
	}
#print STDERR join(', ', keys %Cited), "\n";
#	while (($id, $i) = each %$rCited) { $Cited{$id} = $i; }
	return \%Cited;
}

sub ComputeXY {
	my($rNid, $rN2T) = @_; my($i, $t, $year, $range, $actor, %T2XY);
	my($MaxYear, $MinYear, %Year, %Count, $xpos, $ypos);
	$MaxYear = 0; $MinYear = 100000000;
#print "\nComputeXY, ", @$rNid,"\n";
	foreach $i (@$rNid) {
		$t = $rN2T->{$i}; 
		($year, $actor) = split /:/, $t;
		$MaxYear = $year if $year > $MaxYear;
		$MinYear = $year if $year < $MinYear;
		$Year{$year}++;
	}
	$range = $MaxYear-$MinYear+3;
print STDERR "Min=$MinYear, Max=$MaxYear, range=$range\n";
	foreach $i (@$rNid) {
		$t = $rN2T->{$i}; 
		($year, $actor) = split /:/, $t;
		$xpos = &ts(($year-$MinYear+1)/$range);
		$Count{$year}++;
		$ypos = &ts($Count{$year}/($Year{$year}+1));
		$T2XY{$t} = "$xpos $ypos";
#print STDERR "$t=>$xpos $ypos, range=$range\n";
	}	
	return \%T2XY;
}

sub ts { my($x, $n) = @_; $n=2 if not $n; return sprintf("%0.".$n."f", $x);  }
#sub ts { 
#	my($x, $n) = @_;	if ($x == int($x)) { return $x; }
#	else { $n=4 if not $n; return sprintf("%0.".$n."f", $x); }
#}
