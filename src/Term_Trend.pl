#!/usr/bin/perl -s
    use SamOpt qw(SamOpt);  &SamOpt();
# Given a set of term clusters (or a set of terms), the frequency
#   of each term (for filtering terms), and the index of time-stamped documents
#   where these terms come from, find the trend of each cluster (term).
# Then categorize each trend into fading (descreasing), promising (increasing),
#   or spike-like (increasing first and then descreasing later).
    use strict;
    use SAMtool::Stem;
    use SAMtool::Progress;
#    use wntool;
    use SAMtool::Stopword; # do not use SAM::Stopword;
    my $Stop = Stopword->new();
    use MDS;

# perl -s Term_Trend.pl -Omap Result/NSC_DocCluster
# On 2011/04/25:
# perl -s Term_Trend.pl -Ocolor -Ocut=0.01 -Omap -Oscale=2.5 -ONoOL -OhtmlTree=..\Result\SC_Edu_JBC_S2\0_0.01.html ..\Result\SC_Edu_JBC_S3
    &CreateMap(@ARGV) if $main::Omap;


=comment until next =cut
#D:\demo\File>perl -s Term_Trend.pl -Ott NSC NSC_TermCluster\NSC_TermCluster.txt \
#  NSC_WG_RK.txt > NSC_TermCluster\NSC_TC_T1.txt
    &ClusterTitle1(@ARGV) if $main::Ott; # get cluster titles from cluter terms

# D:\demo\File>perl -s term_trend.pl -Oct2 NSC_TermCluster\NSC_TC_T1.txt  \
#  > NSC_TermCluster\NSC_TC_T2.txt
    &ClusterTitle2(@ARGV) if $main::Oct2; # get cluster titles from InfoMap

# D:\demo\File>perl -s term_trend.pl -Oct3 NSC_TermCluster\NSC_TC_T1.txt  \
#  > NSC_TermCluster\NSC_TC_T3.txt
    &ClusterTitle3(@ARGV) if $main::Oct3; # get cluster titles from WordNet

#D:\demo\File>perl -s Term_Trend.pl -Oct4 NSC NSC_TermCluster\NSC_TermCluster.txt \
#  NSC_WG_RK.txt > NSC_TermCluster\NSC_TC_T4.txt
    &ClusterTitle4(@ARGV) if $main::Oct4; # get cluster titles from WordNet

#D:\demo\File>perl -s Term_Trend.pl -Oct5 NSC_DocCluster > NSC_DocCluTitle.txt
    &ClusterTitle5(@ARGV) if $main::Oct5; # get cluster titles from WordNet
    

# Given a set of term clusters savesd in a file,
#   try to figure out most representative cluster titles 
#   based on the terms in the clusters.
sub ClusterTitle1 {
    my($IndeName, $TCfile, $DFfile) = @_;
    my($c, @TermLine, $title, %Title, %Term, $w, $line, $k, $df, @RT, @T);
    my($rCatTitle, $CatTitle, $rDF, %T);
    $rCatTitle = \%T;
    $rDF = &ReadDFfile($DFfile);
    $/ = "\n\n\n"; # separator of each cluster
    open F, $TCfile or die "Cannot read file:'$TCfile', $!";
    while ($c = <F>) {
    	next if $c =~ /\d\(\)/; # skip those which don't have cluster titles
    	# a cluster having no title computed by correlation coefficient
    	# means no cluster-specific terms can be extracted.
    	# Such clusters tend to be bad cluters of terms.
	@TermLine = split /\n/, $c;
# Separate the cluster title and the other content
	$title = ''; while ($title !~ /\d\(/) { $title = shift @TermLine; }
# Get cluster title terms in $title
	undef %Title; undef %Term;
	while ($title =~ /(\w+):/g) { $Title{$1}++; $Term{$1}++; }
# Get other content in @TermLine
	foreach $line (@TermLine) {
	# format: keyword : df : related terms separated by ','
	    ($k, $df, @RT) = split / : |,|\./, $line;
	    $Title{$k} ++; $Term{$k}++;
	    foreach $w (@RT) {
	    	next if $w =~ /^\s*$/;
# delete those terms which contain the stop words
	    	next if $Stop->IsESW($w);
	    	next if $Stop->IsESW(substr($w, 0, index($w, ' ')));
	    	next if $Stop->IsESW(substr($w, rindex($w, ' ')+1, length($w)));
	    	$Term{$w}++; 
	    }
	}
# Now only those Title words and repeated occurring terms are needed
	undef @T;
	foreach $w (sort {$Title{$b} <=> $Title{$a}} keys %Title)
	{ push @T, $w; }
	($CatTitle, $rCatTitle) = &FindCatTitle(\@T, $rDF, $rCatTitle);
#	{ push @T, "$w:$Term{$w}"; } 
#	push @T, "\n=>";
#	foreach $w (sort {$Term{$b} <=> $Term{$a}} keys %Term) {
#	    push @T, "$w:$Term{$w}" if $Term{$w} > 1;
#	}
#	print "=>$CatTitle : ", join(', ', @T), "\n$c";
	print "=>$CatTitle : ", join('; ', map{"'$_'"}@T), "\n";
#	last;
    }
    close(F);
#$w = 'the'; print "$w is a stop word\n" if ($Stop->IsESW($w));
#$w = 'invention'; print "$w is a stop word\n" if ($Stop->IsESW($w));
#$w = 'presented invention'; print "$w is a stop word\n" if $Stop->IsESW(substr($w, 0, index($w, ' ')));
}

sub ReadDFfile {
    my($DFfile) = @_; my(%DF, $t, $df);
    local $/ = "\n";
    open F, $DFfile or die "Cannot read file:'$DFfile', $!";
    while (<F>) {
    	chomp; ($t, $df) = split /\t/, $_;
    	$DF{$t} = $df;
    }
    close(F);
    return \%DF;
}

# %$rCatTitle : record those used cluster titles
# return a cluster title that has not yet been used by previous clusters
sub FindCatTitle {
    my($rT, $rDF, $rCatTitle) = @_;  my($t, $title, @T);
#    @T = sort {$rDF->{$b} <=> $rDF->{$a}} @$rT;
    @T = @$rT;
    if ($T[0] ne '' and not $rCatTitle->{$T[0]}) {
	$title = $T[0]; $rCatTitle->{$title} = 1; 
    } elsif ($T[1] ne '' and not $rCatTitle->{$T[1]}) {
	$title = $T[1]; $rCatTitle->{$title} = 1; 
    } elsif ($T[0] ne '' and $T[1] ne '' and not $rCatTitle->{$T[0] . '_' . $T[1]}) {
	$title = $T[0] . '_' . $T[1]; $rCatTitle->{$title} = 1; 
    } else {
    	$title = int (rand()*1000);  $rCatTitle->{$title} = 1; 
    }
    return ($title, $rCatTitle);
#    return ($title . '_' . $rDF->{$title}, $rCatTitle);
}


# Given the output from the above process, find the cluter category by use of 
#  external resources such as InfoMap (which seems to use WordNet).
# That is,  try to figure out most representative cluster titles 
#   based on the terms using outside resources.
sub ClusterTitle2 {
    my($InFile) = @_;  my($url, $line, @W, $str, %CatID, $c, %Cat2Cluster);
    my(@Cats, $rCats, $rScore, $i, $percent, $li, $Total, $pro, @Words);
    use SAMtool::Stem;
    use SAMtool::Progress;
    use LWP::Simple;
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
    $CatID{'ID'} = 0;
    $url = "http://infomap.stanford.edu/cgi-bin/semlab/infomap/classes/print_class.pl?args=";
    open F, $InFile or die "Cannot read file:'$InFile', $!";
    $Total = $li = $percent = 0; while ($line = <F>) { $Total ++; } close(F);
    open F, $InFile or die "Cannot read file:'$InFile', $!";
    while ($line = <F>) {
    	if ($line =~ /^#/) { print $line; next; }
    	chomp $line; 
    	@Words = (); @W = (); $i = 0; $li++;
    	$percent = $pro->ShowProgress($li/$Total, $percent);
#    	while ($line =~ /'([\w ]+)'/g) { push @W, Stem::stem_lc($1); }
#    	while ($line =~ /(\w+)/g) { 
    	while ($line =~ /([a-zA-Z]+)/g) { 
    	    push @Words, $1;
    	    push @W, &Stem::stem_lc($1); 
    	    $i++; 
    	    last if $i>10;
    	}
#=c
#$line = <<ENDF;
#hydrogenated : 94 : photo,sensor,arylalkyl hydroxylamine,activity,C1,rate,halides,alkyl phenyl,integer,trap,alkoxy phenyl nitro amino,C6,silicon bond,alkoxycarbonyl halogen,Si,substituents,DNA,stream,Schottky diode,halo,bond,plasma,halogen,benzyl,derive,membrane,silicon,substrate,Pd,gas,time,biphenyl,alkoxy phenyl,compounding,phenyl,group,methyl,trifluoromethyl,ppm,phenoxy,hydrogen atom,alkyl,isodethiaazacephem derivative,isodethiaazacephems,SiC,WATER,formulas,aryl,Air,sulfide,flowing rate,ethanol,alkoxy,six carbon atoms,semiconductor,capping layer. 
#ENDF
#    while ($line =~ /(\w+)/g) { push @W, $1; }
#=cut
    	$str = get($url . join("+", @W));
#print "   W=@W  =>  str=$str\n";
    	($rCats, $rScore) = &ParseInfoMap($str);
    	&SetCatID($rCats, \%CatID);
    	print "$li:$line\n",
    	"# ", join(", ", @Words), "\n",
    	"  =>", join("; ", map{"$CatID{$_}:$_:$rScore->{$_}"}@$rCats), "\n\n";
    	# Next accumulate number of element covered by this category
    	foreach $c (@$rCats) {   $Cat2Cluster{$c}++;  }

    	for($i=1; $i<=@$rCats and $i<=3; $i++) {
    	    $str = $rCats->[$i-1];
    	    $str =~ s/%\d+//g;  $str =~ s/\t/, /g; $str =~ s/\_/ /g;
    	    print $i . ':'.$str. ':'. $rScore->{$rCats->[$i-1]}."\n";
    	} print "\n\n";
#last;
    }
    $percent = $pro->ShowProgress($li/$Total, $percent);
    # Now sort and print out the categories
    @Cats = sort {$Cat2Cluster{$b} <=> $Cat2Cluster{$a}} keys %Cat2Cluster;
    foreach $c (@Cats) {
    	print "$c : $Cat2Cluster{$c}\n";
    }
}

# Given the original HTML source of the InfoMap' Semantic Classes
#  at: http://infomap.stanford.edu/cgi-bin/semlab/infomap/classes/print_class.pl?args=$term1+$term2
#  parse the source to get the categories
sub ParseInfoMap {
    my($str) = @_;  my(@Cats, %Score, $score);
    $score = -10; # initial value
    while ($str =~ m#<TD>([\w ,]+)\s*</TD><TD>\s*([\d\.]+)</TD></TR>#g) {
    	last if $2 < $score * 0.25;
    	push @Cats, $1; # $1 : term, $2 : score
    	$Score{$1} = $2;
    	$score = $2 if $score == -10;
    }
    return (\@Cats, \%Score);
}

# Given a set of categories, update their ID in %CatID.
#  If the category is new, give it a new ID and save in %CatID
#  Do nothing if it is already in %CatID
sub SetCatID {
    my($rCat, $rCatID) = @_; my($c);
    foreach $c (@$rCat) {
    	next if $rCatID->{$c};
    	$rCatID->{'ID'}++;
    	$rCatID->{$c} = $rCatID->{'ID'};
    }	
}


# Given the output from ClusterTitle1, find the cluter category by use of 
#  external resources such as WordNet.
# That is,  try to figure out most representative cluster titles 
#   based on the terms using outside resources.
sub ClusterTitle3 {
    my($InFile) = @_;  my($url, $line, @W, $str, %CatID, $c, %Cat2Cluster);
    my(@Cats, $rCats, $rScore, $i, $percent, $li, $Total, $pro, @Words);
    my($rFnode, $rWeight, $rSense);
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
    $CatID{'ID'} = 0;
    open F, $InFile or die "Cannot read file:'$InFile', $!";
    $Total = $li = $percent = 0; while ($line = <F>) { $Total ++; } close(F);
    open F, $InFile or die "Cannot read file:'$InFile', $!";
    while ($line = <F>) {
    	if ($line =~ /^#/) { print $line; next; }
    	chomp $line; 
    	@Words = (); @W = (); $i = 0; $li++;
    	$percent = $pro->ShowProgress($li/$Total, $percent);
#    	while ($line =~ /'([\w ]+)'/g) { push @W, Stem::stem_lc($1); }
#    	while ($line =~ /(\w+)/g) { 
    	while ($line =~ /([a-zA-Z]+)/g) { 
    	    push @Words, $1;
    	    push @W, &Stem::stem_lc($1); 
    	    $i++; 
    	    last if $i>10;
    	}
	($rCats, $rScore, $rSense) = &wntool::SemanticClass(@W);
    	&SetCatID($rCats, \%CatID);
    	print "$li:$line\n",
    	"# ", join(", ", @Words), "\n",
    	"  =>", join("; ", map{"$CatID{$_}:$_:$rScore->{$_}"}@$rCats), "\n\n";
    	# Next accumulate number of element covered by this category
    	foreach $c (@$rCats) {   $Cat2Cluster{$c}++;  }

    	for($i=1; $i<=@$rCats and $i<=3; $i++) {
    	    $str = $rCats->[$i-1];
    	    $str =~ s/%\d+//g;  $str =~ s/\t/, /g; $str =~ s/\_/ /g;
    	    print $i . ':'.$str. ':'. $rScore->{$rCats->[$i-1]}."\n";
    	} print "\n\n";
    }
    $percent = $pro->ShowProgress($li/$Total, $percent);
    # Now sort and print out the categories
    @Cats = sort {$Cat2Cluster{$b} <=> $Cat2Cluster{$a}} keys %Cat2Cluster;
    foreach $c (@Cats) {
    	print "$c : $Cat2Cluster{$c}\n";
    }
}


# Given a set of term clusters savesd in a file (same input as ClusterTitle1)
#   try to figure out most representative cluster titles 
#   by using the terms in the clusters to search WordNet domain.
sub ClusterTitle4 {
    my($IndeName, $InFile, $DFfile) = @_;
    my(@W, $str, %CatID, %Cat2Cluster);
    my($c, @TermLine, $title, %Title, %Term, $w, $line, $k, $df, @RT, @T);
    my(@Cats, $rCats, $rScore, $i, $percent, $li, $Total, $pro);
    my($rCatTitle, $CatTitle, $rDF, %T);
    my($rFnode, $rWeight, $rSense);
    $rCatTitle = \%T;
    $rDF = &ReadDFfile($DFfile);
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
    $CatID{'ID'} = 0;
    $/ = "\n\n\n"; # separator of each cluster
    open F, $InFile or die "Cannot read file:'$InFile', $!";
    $Total = $li = $percent = 0; while ($line = <F>) { $Total ++; } close(F);
    open F, $InFile or die "Cannot read file:'$InFile', $!";
    while ($c = <F>) {
    	$li++; $c =~ s/\n\n\n$//g; 
	$percent = $pro->ShowProgress($li/$Total, $percent);
    	next if $c =~ /\d\(\)/; # skip those which don't have cluster titles
    	# a cluster having no title computed by correlation coefficient
    	# means no cluster-specific terms can be extracted.
    	# Such clusters tend to be bad cluters of terms.
	@TermLine = split /\n/, $c;
# Separate the cluster title and the other content
	$title = ''; while ($title !~ /\d\(/) { $title = shift @TermLine; }
# Get cluster title terms in $title
	undef %Title; undef %Term;
	while ($title =~ /(\w+):/g) { $Title{$1}++; $Term{$1}++; }
# Get other content in @TermLine
	foreach $line (@TermLine) {
	# format: keyword : df : related terms separated by ','
	    ($k, $df, @RT) = split / : |,|\./, $line;
	    $Title{$k} ++; $Term{$k}++;
	    foreach $w (@RT) {
	    	next if $w =~ /^\s*$/;
# delete those terms which contain the stop words
	    	next if $Stop->IsESW($w);
	    	next if $Stop->IsESW(substr($w, 0, index($w, ' ')));
	    	next if $Stop->IsESW(substr($w, rindex($w, ' ')+1, length($w)));
	    	$Term{$w}++; 
	    }
	}
# Now only those Title words and repeated occurring terms are needed
	undef @T; undef @RT; $i = 0;
	foreach $w (sort {$Title{$b} <=> $Title{$a}} keys %Title)
	{ push @T, $w; }
	foreach $w (sort {$Term{$b} <=> $Term{$a}} keys %Term)
	{ push @T, $w if $Term{$w}>1; }
	foreach $w (map{split ' ',$_} @T) {
	    push @RT, &Stem::stem_lc($w); 
    	    $i++; 
#    	    last if $i>10;
    	}
	($rCats, $rScore, $rSense) = &wntool::SemanticClass(@RT);
    	&SetCatID($rCats, \%CatID);
    	print "$c\n  =>", join("; ", 
    		map{"$CatID{$_}:$_:$rScore->{$_}"}@$rCats), "\n";
    	# Next accumulate number of element covered by this category
    	foreach $c (@$rCats) {   $Cat2Cluster{$c}++;  }
# Map cluster title terms to broader WordNet domain
    	undef $rCats; undef $rScore; undef @T;
	while ($title =~ /(\w+):/g) { push @T, $1; }
	($rCats, $rScore, $rSense) = &wntool::SemanticClass(@T);
    	&SetCatID($rCats, \%CatID);
    	print "  =>", join("; ", 
    		map{"$CatID{$_}:$_:$rScore->{$_}"}@$rCats), "\n\n";
    	# Next accumulate number of element covered by this category
    	foreach $c (@$rCats) {   $Cat2Cluster{$c}++;  }
    }
    $percent = $pro->ShowProgress($li/$Total, $percent);
    close(F);
    # Now sort and print out the categories
    @Cats = sort {$Cat2Cluster{$b} <=> $Cat2Cluster{$a}} keys %Cat2Cluster;
    foreach $c (@Cats) {
    	print "$c : $Cat2Cluster{$c}\n";
    }
}

# Given a directory having a number of files, each of which is a cluster
#   of a set of documents, find the cluster domain by searching WordNet's 
#   hypernyms based on the cluster titles and the document terms in the cluster.
sub ClusterTitle5 {
    my($InDir) = @_;  
    my($url, $line, @W, $str, %CatID, $c, %Cat2Cluster, @Files, $InFile);
    my(@Cats, $rCats, $rScore, $i, $percent, $li, $Total, $pro, $head);
    my($rFnode, $rWeight, $rSense);
    use SAMtool::SegWord;
    my $seg = SegWord->new( {'WantRT'=>0, 'UseDic'=>1} );
    my($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN);

    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
    $CatID{'ID'} = 0;
    $Total = @Files = glob("$InDir/*.htm");
    if ($Total == 0) {
	print STDERR "There is no file:'*.htm', in '$InDir',$!"; exit;
    }
    $li = $percent = 0; undef($/);
    foreach $InFile (@Files) {
    	next if $InFile =~/\.+$/; 
    	$li++; 	$percent = $pro->ShowProgress($li/$Total, $percent);
	open F, $InFile or die "Cannot read file:'$InFile', $!";
	$line = <F>; close(F);
	if ($line =~ /\s(\d+.+\(.+\))/) {
	    $head = $1; $line = $'; # 'to uncomment for UltraEdit
	} else {
	    $head = ''; warn "$InFile : cluster head not found\n";
	}
	undef @W; while ($head =~ /([a-z]+)/g) { push @W, $1; }
	($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN) 
	    = $seg->ExtractKeyPhrase( $line );

	($rCats, $rScore, $rSense) = &wntool::SemanticClass(@W);
    	&SetCatID($rCats, \%CatID);
    	$str = join(";  ", map{"$CatID{$_}:$_:$rScore->{$_}"}@$rCats);
    	$str =~ s/\t/ /g;
    	print "$li : $head\n  =>", join(", ", @W), "\n  ===>", $str, "\n";
    	# Next accumulate number of element covered by this category
    	foreach $c (@$rCats) {   $Cat2Cluster{$c}++;  }

	($rCats, $rScore, $rSense) = &wntool::SemanticClass(@$rWL[0..9]);
    	&SetCatID($rCats, \%CatID);
    	$str = join(";  ", map{"$CatID{$_}:$_:$rScore->{$_}"}@$rCats);
    	$str =~ s/\t/ /g;
	print "  =>", join(", ", @$rWL[0..9]), "\n  ===>", $str, "\n\n";
    	foreach $c (@$rCats) {   $Cat2Cluster{$c}++;  }
    }
    $percent = $pro->ShowProgress($li/$Total, $percent);
    # Now sort and print out the categories
    @Cats = sort {$Cat2Cluster{$b} <=> $Cat2Cluster{$a}} keys %Cat2Cluster;
    foreach $c (@Cats) {
    	print "$c : $Cat2Cluster{$c}\n";
    }    
}
=cut

# On 2012/03/27
#畫出MDS圖，但是圓圈中的編號是類別順序號，不是內部歸類的編號:
#perl -s Term_Trend.pl -Ocolor -Ocut=0.0 -Omap -Oscale=2.25 -OCNo -OhtmlTree=../Result/ATR1_BC_S4/0_0.01.html ../Result/ATR1_BC_S5
#
#perl term_trend.pl -Ocolor -Omap -Ocut=0.0 -Oscale=1.0 ..\Result\SC_LIS_JBC_S2
# Given the clustered results in the index path, create 2-D map by MDS.
# use options: -Ocolor, -Ocut, -Oct_low_tf, -Odebug,
#  Owant="ClusterID1 ClusterID2 ClusterID3 ..."
#  Ounwant="ClusterID1 ClusterID2 ClusterID3 ..."
sub CreateMap {
    my($IndexPath, $InitialMap) = @_; 
    my($mds, $rDC, $rDid2Cid, $rCid2Dids, $rCid2Cno, $Cno, $NoOL);
    my($rWanted, $rUnWanted) = ({}, {}); # set reference to a hash to a var.
    my $stime = time();
    $mds = MDS->new( ); # or $mds = MDS->new();
#    $mds->SetValue('mds_exe', 'D:\demo\File\L04\bin\mds.exe');
    $mds->SetValue('mds_exe', 'mds.exe');
    $mds->SetValue('SimFile', $IndexPath .  '/SimPairs.txt'); # 2012/01/11
    $mds->SetValue('Coordinate', $IndexPath . '/Coordinate.txt'); # change backslash into slash
    $mds->SetValue('dendrogramTemplate', 'dendrogramTemplate.html');
    $mds->SetValue('dendrogramJS', 'dendrogram.js'); # 2012/01/11
    $mds->SetValue('Width', 600);
    $mds->SetValue('Height', 450);
    $mds->SetValue('scale', 1.5); # zoom-in (>1) or zoom-out (<1) factor
    $mds->SetValue('scale', $main::Oscale) if $main::Oscale;
    $mds->SetValue('BaseSize', 300); # default is 600, control the circle size
    $mds->SetValue('AbsSize', $main::OAbsSize); # useful to show grow map or evolve map
    $mds->SetValue('fill', $main::Ofill); # to fill the circle area or not, 1=Yes,0=No
    $mds->SetValue('NoOL', $main::ONoOL); # to omit the drawing of the outliers 2007/05/09
    $mds->SetValue('CNo', $main::OCNo) if $main::OCNo; # lable with Cluster No, not ID 2011/04/19
    $NoOL = 'NoOL_' if $main::ONoOL;
    $mds->SetValue('InitialMap', $InitialMap); # to draw the map based on a previous one
    if ($main::Owant) { # 2009/03/07 # or reserve those wanted clusters
    	foreach my $cid (split ' ', $main::Owant) { $rWanted->{$cid} = 1; }
    }
    if ($main::Ounwant) { # 2009/03/07 # remove those unwanted clusters
    	foreach my $cid (split ' ', $main::Ounwant) { $rUnWanted->{$cid} = 1; }
    }
    if ($main::Ocolor) { # if want to map different colors for different clusters
		use Cluster;
		$rDC = Cluster->new( { 'debug'=>$main::Odebug } );
		$rDC->SetValue('IndexPath', $IndexPath);
		$rDC->ReadTree();
		$rDC->SetValue("ct_low_tf", $main::Oct_low_tf) if $main::Oct_low_tf ne '';
		($rDid2Cid, $rCid2Dids) = $rDC->CutCollection($main::Ocut);
		# $rCid2Dids may have Cids which contain empty documents, while the 
		# Cids in $rDid2Cid do not have empty documents # 2012/01/11
#		($rDid2Cid, $rCid2Dids, $rCid2Cno) = $rDC->CutCollection($main::Ocut);
# The above $rCid2Cno contains current stage information, not that in the previous stage
		$main::OhtmlTree = $main::OHT if $main::OHT;#option OHT is equivalent to OhtmlTree
		if (-r $main::OhtmlTree) { # if the HTML Tree from previous stage is given
			$rCid2Cno = $rDC->GetCid2Cno($main::OhtmlTree);
			$mds->{'Cid2Cno'} = 1; # indicates there is a mapping to be used
			$Cno = 'Cno'; # for appending to the file name
		}
    }
# We need a way to determine the information in $rCid2Cno
    my($DocNum, $CatNum) = (scalar keys %$rDid2Cid, scalar keys %$rCid2Dids);
    print STDERR "  It takes ", time()-$stime, " seconds to cut tree having "
	, "$DocNum records and $CatNum internal nodes\n";

    $mds->SetValue('dendrogramOut', $IndexPath .  
    	"/dendrogram_${Cno}_${NoOL}$main::Ocut.html"); # 2012/01/11
    $mds->{PajekFile} = "$IndexPath/pajek_".$mds->{scale}
    	."_${Cno}_${NoOL}$main::Ocut.net";
    $mds->{VOSFile} = "$IndexPath/VOS_".$mds->{scale}
    	."_${Cno}_${NoOL}$main::Ocut.txt";
    	
    $mds->mdsmap(2, 
	"$IndexPath/SortedPairs.txt", 
	"$IndexPath/Title.txt", 
	"$IndexPath/map_".$mds->{scale}."_${Cno}_${NoOL}$main::Ocut.png", 
	$rDid2Cid, $rCid2Cno, $rWanted, $rUnWanted);
    print STDERR "  These files have been created under $IndexPath:\n",
    	"    SimPairs.txt, Coordinate.txt, ", 
    	"map_$mds->{scale}_${Cno}_${NoOL}$main::Ocut.png,\n",
    	"    dendrogram_${Cno}_${NoOL}$main::Ocut.html, ", 
    	"pajek_$mds->{scale}_${Cno}_${NoOL}$main::Ocut.net, ",
    	"VOS_$mds->{scale}_${Cno}_${NoOL}$main::Ocut.txt\n";
    print STDERR "  It takes ", time()-$stime, " seconds for MDS mapping\n";
}
