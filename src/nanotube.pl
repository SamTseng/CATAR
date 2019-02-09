#!/usr/bin/perl -s


    &PrepareTrecEval(@ARGV) if $Otrec;

# D:\demo\lwp>perl -s nanotube.pl -Oana 	\
#   D:\Sam\papers\2005\IACIS\data\tech_CatTerm30.txt
    &AnalyzeTermOccurrence(@ARGV) if $Oana; # use option -Ocheck
    
# D:\demo\lwp>perl -s nanotube.pl -Oterm 	\
#  D:\Sam\papers\2005\IACIS\data\effect_*_CT50.txt	\
#  > D:\Sam\papers\2005\IACIS\data\effect_CatTerm.txt
    &FindTermOccurrence(@ARGV) if $Oterm; # use option -Onum


# D:\demo\lwp>perl -s nanotube.pl -Oempty D:\Sam\papers\2005\IACIS\data
    &FindEmptySegment(@ARGV) if $Oempty;
    
# D:\demo\lwp>perl -s nanotube.pl -OPatSeg -Oabs -Oseg=1 \
#   D:\Sam\papers\2005\IACIS\data\nanotube  	\
#   D:\Sam\papers\2005\IACIS\data\nano_seg    
    &GetPatentSegment(@ARGV) if $OPatSeg; # use option $Oabs, $Oseg

# 把 doccatlist3.htm 內容拷貝到 doccatlist3.txt，修改「(新分子)」成「[新分子]」，
# 然後執行下面命令產生「文件─類別」檔。
# D:\Sam\papers\2005\IACIS\data>perl -s nanotube.pl -Od2c=3 doccatlist3.txt
#  > effect_d2c.txt 
    &Create_d2c(@ARGV) if $Od2c;

# ex: D:\Sam\papers\2005\IACIS\data>perl -s nanotube.pl -Oexport nanotube
# D:\demo\lwp>perl -s nanotube.pl -Oexport D:\Sam\papers\2005\IACIS\data\nanotube
# Before run this command, you should start MS-SQL
    &GetPatentFromMSSQL(@ARGV) if $Oexport;

sub PrepareTrecEval {
    my($file, $OutDir) = @_;
    if (not -d $OutDir) { mkdir($OutDir, 0755) or die "cannot mkdir:'$OutDir'"; }
    open F, $file or die "Cannot read file:'$file'";
    while (<>) {
    	chomp;
    	($Cid, $Cname, $Cdf, $CTid, $term, $AllSeg, $AllCoef, @Seg) = split /\t/, $_;
	$AnsOut .= "$cid q0 ". join("_", $CTid, $AllSeg, $term) . " 1\n";
    }
    close(F);
    
}

# Use option -Ocheck
sub AnalyzeTermOccurrence {
    while (<>) {
    	chomp; 
    	if ($Ocheck) {
	    ($Cid, $Cname, $Cdf, $CTid, $check, $term, $TotalSeg, 
	    $TotalCoef, @SegName)  = split /\t/, $_;
    	} else {
	    ($Cid, $Cname, $Cdf, $CTid, $term, $TotalSeg, 
	    $TotalCoef, @SegName)  = split /\t/, $_;
	}
print STDERR "@SegName\n"; # all the field names
	last;
    }
    for ($i=0; $i<@SegName; $i+=2) {
	$ks = $SegName[$i]; $ks =~ s/_tdf//;
	push @SegN, $ks;
    }
print STDERR "@SegN\n";  # only the segment names
    while (<>) {
    	chomp;
    	if ($Ocheck) {
	    ($Cid, $Cname, $Cdf, $CTid, $check, $term, $TotalSeg, 
	    $TotalCoef, @Seg)  = split /\t/, $_;
	    next if $check eq '';  # skip if not checked, i.e., no 'V'
    	} else {
	    ($Cid, $Cname, $Cdf, $CTid, $term, $TotalSeg, 
	    $TotalCoef, @Seg)  = split /\t/, $_;
	}
    	$k = "$Cid\t$Cname\t$Cdf";
    	$ClassTf{$k} ++;   # number of checked terms in a category
    	$TotalTerm++;	   # total number of checked terms
    	for ($i=0; $i<@Seg; $i+=2) {
    	    $ks = $SegN[$i/2];  # segment name
# accumulate the occurrence of a checked term in segment $i of category $k
    	    $SegCount->{$k}{$ks} ++ if $Seg[$i] ne '';
# record the maximum correlation coefficients of segment $i of category $k
    	    $SegMax->{$k}{$ks} = $Seg[$i+1] if $SegMax->{$k}{$ks} < $Seg[$i+1];
    	}
    }
# Now for each category, print its statistics and acumulate the results
    @Class = sort {$a<=>$b} keys %$SegCount;
print "Cid\tCname\tCdf\tNumTerm\t", join("\t", @SegN, @SegN), "\n";
    $cn = 0;  # number of non-empty categories
    foreach $k (@Class) {
    	@Out = ();  $cn++;
    	foreach $ks (@SegN) {
# accmulate the occurrence of a checked term in segment $ks over all categories
# next line is for micro-average
    	    $scs{$ks} += $SegCount->{$k}{$ks}; 
# accmulate the maximum corr. coef. of a checked term in segment $ks over all categories
# next line is for macro-average
    	    $scsp{$ks} += $SegCount->{$k}{$ks}/$ClassTf{$k} * 100;
    	    $SegCount->{$k}{$ks} = 0 if $SegCount->{$k}{$ks} eq '';
    	    push @Out, $SegCount->{$k}{$ks}.'/'. #uncomment for micro-average
    	    	&ts($SegCount->{$k}{$ks}/$ClassTf{$k} * 100, 1) . '%'; # macro
    	}
# next for is to output Maximum correlation coefficient
	foreach $ks (@SegN) { 
	    $ms{$ks} += $SegMax->{$k}{$ks};
#	    push @Out, &ts($SegMax->{$k}{$ks}, 4); 
	}
    	print "$k\t$ClassTf{$k}\t", join("\t", @Out), "\n";
    }

# Now print Total and average results
#   first, print the micro- and macro-average of segment counts
    @Out = ();
    foreach $ks (@SegN){ 
#    	push @Out, &ts($scs{$ks}/$cn, 2) . '/' . #uncomment for micro-average
    	push @Out, # &ts($scs{$ks}/$cn, 2) . '/' . #uncomment for micro-average
    		&ts($scsp{$ks}/$cn, 2) . '%'; # this is for macro-average
    }
#   second, print the average of maximum correlation coefficients
    foreach $ks (@SegN) { push @Out, &ts($ms{$ks}/$cn, 2); }
    print "Cid\tCname\tCdf\t", join("\t", @SegN, @SegN), "\n";
    print "Cid\tCname\tCdf/$cn\t", join("\t", @Out), "\n"; 
    print "Total Terms: $TotalTerm, total categories: $cn => avg=", 
    	&ts($TotalTerm/$cn, 2) ,"\n";
}

# score truncation function
sub ts { my($x, $n)=@_;  $n= 6 if $n eq ""; return sprintf("%0.".$n."f", $x); }

sub FindTermOccurrence {
    my($FilePat) = @_;
    @Files = glob($FilePat);
    print STDERR join("\n", @Files), "\n";
    $i = 0;
    foreach $f (@Files) {
    	open F, $f; 
    	if ($f=~m#(effect|tech|cluster)_(.+)_CT50\.txt#) { $SegName = $2; } 
    	else { die "Cannot match 'seg name'";}
print STDERR "$SegName\n";
    	$i++;
    	while (<F>) {
    	    chomp;
    	    next if /category=/;
#	1 : 1 : 材料 : 52 : metal : 6 : 0.231662
    	    ($Cid, $CTid, $Cname, $Cdf, $term, $tdf, $coef) = split / : /, $_;
    	    $k = "$Cid\t$Cname\t$Cdf";
    	    push @OutOrder, $k if $i == 1 and $OutOrder[-1] ne $k;
    	    $SegTdfCoef{"$k\t$term\t$SegName"} = "$tdf\t$coef";
    	    $SegFreq->{$k}{$term}++;
    	    $TotalCoef->{$k}{$term} += $coef;
	}
    	close(F);
    }
    @SegName = ('abs', 'app', 'task', 'sum', 'fea', 'cla', 'seg_abs6', 'seg');
    @SNcap =   ('abs_tdf', 'abs_coef', 'app_tdf', 'app_coef', 
    		'task_tdf', 'task_coef', 'sum_tdf', 'sum_coef', 
    		'fea_tdf', 'fea_coef', 'cla_tdf', 'cla_coef',
    		'seg_abs6_tdf', 'seg_abs6_coef', 
    		'seg_tdf', 'seg_coef');
    $Onum = 10000 if not defined $Onum;
    print "Cid\tCname\tCdf\tCTid\tterm\tTotalSeg\tTotalCoef\t", join("\t", @SNcap), "\n";
    foreach $k (@OutOrder) {
    	@Terms=sort{$SegFreq->{$k}{$b}<=>$SegFreq->{$k}{$a}}keys%{ $SegFreq->{$k} };
    	$ti = 0;
    	foreach $t (@Terms) {
    	    $ti++;  last if $ti > $Onum; # output only first $Onum terms
    	    $out = "$k\t$ti\t$t\t$SegFreq->{$k}{$t}\t$TotalCoef->{$k}{$t}\t";
    	    foreach $sn (@SegName) {
    	    	if ($SegTdfCoef{"$k\t$t\t$sn"}) {
		    $out .= $SegTdfCoef{"$k\t$t\t$sn"} . "\t";
		} else { $out .= "\t\t"; }
    	    }
    	    $out =~ s/\t$//; # delete last '\t'
    	    print $out . "\n";
    	}
    }    
}

sub FindEmptySegment {
    my($DirPath) = @_;
    @SegName = ('abs', 'app', 'task', 'sum', 'fea', 'cla'); #, 'seg_abs6', 'seg');
#    @DIR = map {$DirPath . '/nano_' . $_} @SegName;
    @DIR = map {$DirPath . '/' . $_} @SegName; # 2006/11/30
    print STDERR join("\n", @DIR), "\n";
    for($i=0; $i<@SegName; $i++) { # for each directory
    	@Files = glob($DIR[$i]. '/*.htm');
    	foreach $f (@Files) {  # for each file in that directory
    	    if ($f =~ m#/(\d+)\.htm$#) { $PatNo = $1; }
    	    else { warn "Cannot find patent no. for '$f'"; }
	    open F, $f; 
	    $_=<F>; $_=<F>; $_=<F>; $_=<F>; chomp;
	    if ($_ eq '') {
	    	$Empty{$PatNo} .= "$SegName[$i]\t";
	    }
	    close(F);
    	}
    }
    @PatNo = sort {$a <=> $b} keys %Empty;
    foreach $p (@PatNo) {
    	chop $Empty{$p}; # chop off last "\t"
    	$count = ($Empty{$p} =~ tr/\t/\t/)+1;
    	print "$p\t$count\t$Empty{$p}\n";
    }
}

# Use option -Oabs : indicating output the abstracts (top MaxAbsSen sentences)
# rather than the full paragraphs of each segment.
sub GetPatentSegment {
    my($InDir, $OutDir) = @_;
    use Patent;
    $me = Patent->new( { 'Patent_INI'=>'Patent.ini' } );
    $me->SetValue('MaxAbsSen', 6);
    $me->SetValue('MaxAbsSen_Application', 6);
    $me->SetValue('MaxAbsSen_Task', 6);
    $me->SetValue('MaxAbsSen_Abstract', 6);
    $me->SetValue('MaxAbsSen_Summary', 6);
    $me->SetValue('MaxAbsSen_Features', 6);
    $me->{debug} = $Odebug if $Odebug;
    if (not -d $OutDir) {
    	mkdir $OutDir, 0755 or die "Cannot mkdir:'$OutDir'";
    }
    @Files = glob("$InDir/*.*");
    foreach $f (@Files) {
#    	$i++; last if $i > 3;
	open F, $f or die "Cannot read file:'$f'";
	undef($/); $r = <F>; close(F); $/ = "\n";
	$rPatent = $me->Parse_Patent($r);
	$rPatentAbs = $me->GetPatentAbstract( $rPatent );
    	if ($f =~ m#([^/\\]+)$#) { $fname = $1 } else { die "$!"; }
    	$ff = "$OutDir/$fname";
print "$f=>$ff\n\n";
    	&WriteOut($me, $rPatent, $rPatentAbs, $ff);
    }
}

# Use option -Oabs, $Oseg
sub WriteOut {
    my($me, $rPatent, $rPatentAbs, $file) = @_; my($f);
    open F, ">$file" or die "Cannot write to file:'$file', $!";
    print F "<HTML><head><title>$rPatent->{Title}</title></head><body>\n";
    print F "<h1>$rPatent->{Title}</h1>\n";
    if ($Oabs) { $rP = $rPatentAbs; } else { $rP = $rPatent; }
    @Segment = ('Abstract', 'Application','Task','Summary','Features', 'Claims');
# Oseg=0 : all; 1=>Abstract, 2=>Application, 3=>Task, 4=>Summary, 5=>Features
    if ($Oseg==0) { @Seg = @Segment; } else { @Seg = ( $Segment[$Oseg-1] ); }
#    foreach $f (@{$me->{Patent_Fields}}) {
#    foreach $f ('Abstract', 'Application','Task','Summary','Features') { #,'Claims') {
    foreach $f (@Seg) {
    	next if ($Oseg==0 and $f eq 'Claims'); # no claims for seg_abs6
	print F "<h3>$f</h3>\n";
	if (ref $rP->{$f}) {
	    print F join "<br>\n", @{$rP->{$f}};
	} else {
	    print F $rP->{$f};
	    # next line is added on 2005/01/31
	    warn $rPatent->{PatNum}." has empty $f\n" if $rP->{$f} eq '';
	}
        print F "\n<HR>\n";
# next line is for dubegging
#print STDERR "warning: $rPatent->{PatNum} : '$f' has no content\n" if $rPatent->{$f} eq "";
    }
    print F "</body></html>\n";
    close(F);
}


sub Create_d2c {
# Next line is for doccatlist3.txt
    if ($Od2c==1000) {
	%MidClass = ('碳奈米管'=>'材料', '衍生[新分子]'=>'材料',
    	'高表面積'=>'性能', '高純度'=>'性能', '電性'=>'性能', 
    	'磁性'=>'性能', '儲能'=>'性能', 'FED'=>'產品', '元件'=>'產品');
    }
    $_ = <>; chomp;
    @Class = split ' ', $_;
#print STDERR "@Class\n";
    $c = 0;
    while (<>) {
    	next if not / S\s$/;
    	if (/^ /) { $c++; s/^ //; }
    	s/ S\s//i;
#print STDERR "$_ : $Class[$c] : $MidClass{$Class[$c]}\n";
    	$d2c->{$_}{$Class[$c]} = 1;
#    	$d2c->{$_}{$MidClass{$Class[$c]}} = 1;
    }
    @Pat = sort keys %$d2c;
#print STDERR "@Pat\n";
    foreach $p (@Pat) {
    	@C = sort keys %{ $d2c->{$p} };
    	print "$p\t", join("\t", @C), "\n";
    }
}


sub GetPatentFromMSSQL {
    my($dir) = @_;
    use DBI;
    if (not -d $dir) { mkdir($dir, 0755) or die "cannot mkdir:'$dir'"; }
#    my $dbh = DBI->connect('DBI:ODBC:PatentDB')
#    my $dbh = DBI->connect('DBI:'.$me->{'DSN'}, $me->{'user'}, $me->{'password'})
    my $dbh = DBI->connect( "DBI:ODBC:Patent", "PatentUser", "12345678" )
             or die "Can't make database connect: $dbh::errstr\n";
#    $sql = "SELECT PatentNo, FullText FROM TFullText WHERE UpdateDate >= ?";
    $sql = "SELECT PatentNo, FullText FROM TFullText ";
    $dbh->{LongReadLen} = 10000000;
    $sth = $dbh->prepare($sql)
	or die "Couldn't prepare statement: " . $dbh->errstr;
#    $sth->execute( '2005/01/10' )
    $sth->execute(  )
	or die "Couldn't execute statement: " . $sth->errstr;
    $r = $sth->rows();
    print "# There are $r patents\n";
    $r = 0;
    while (($PatNum, $FullText) = $sth->fetchrow_array()) {
    	$r++;
    	$file = $dir . '/' . $PatNum . '.htm';
    	open F, ">$file" or die "Cannot write file:'$file'";
    	print F $FullText;
    	close(F);
    	print "$PatNum\n";
    }
    print "# There are $r patents\n";
    $sth->finish;
}
