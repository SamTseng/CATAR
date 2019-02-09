#!/usr/bin/perl -s
use strict; use vars; 
#    use SAM::Progress; # already used in Cluster.pm
# This program is for citation analysis for the NSC patents.
# perl -s CiteAna.pl -OBibCpl ..\Source_Data\nano_US_patent_list.txt ..\Source_Data\NanoPatentCiting.txt
# perl -s CiteAna.pl -OBibCpl ..\Result\NanoPaperTW_ID_list.txt ..\Result\NanoPaperTW_OutCitation.txt > ..\Result\NanoPaperTW_BibCpl.txt
#	There are 4490 out-degree patents that have two or more patents.
#	There are 7246 couplings.
    &BibliographicCoupling(@ARGV) if $main::OBibCpl;

# D:\Sam\project\STIC\期中報告>perl -s CiteAna.pl -OCoCite NSC_PatentNoList.txt \
#     InCitation.txt > CoCited.txt
# There are 123 patents that cites two or more desired patents.
# There are 99 cocited patents.
    &CoCitation(@ARGV) if $main::OCoCite;

# perl -s CiteAna.pl -OgetCite -Oprint File_NanoPaperTW NanoPaperTW > ..\Result\NanoPaperTW_OutCitation.txt
# perl -s CiteAna.pl -OgetCite -OsortNum File_NanoPaperTW NanoPaperTW > ..\Result\NanoPaperTW_DiffCitationN.txt
# perl -s CiteAna.pl -OgetCite -OsortText File_NanoPaperTW NanoPaperTW > ..\Result\NanoPaperTW_DiffCitationT.txt
# perl -s CiteAna.pl -OgetCite -OpaperList File_NanoPaperTW NanoPaperTW > ..\Result\NanoPaperTW_ID_list.txt
    &GetCitations(@ARGV) if $main::OgetCite;
# perl -s CiteAna.pl -Oprepare ..\Result\NanoPaperTW_BibCpl.txt ..\Result\NanoPaperTW_BibCpl
    &Prepare_for_Clustering(@ARGV) if $main::Oprepare;
# perl -s CiteAna.pl -Otitle File_NanoPaperTW NanoPaperTW ..\Result\NanoPaperTW_BibCpl
    &CreateTitleFile(@ARGV) if $main::Otitle;

# perl -s CiteAna.pl -Oclu File_NanoPaperTW NanoPaperTW NanoPaperTW_BibCpl ..\Result\NanoPaperTW_BibCpl
# perl -s CiteAna.pl -Oclu -Occ=CiteCorePaperAll CorePaper TOTAL CorePaper_CoC ..\Result\CorePaper_CoC
    &CreateIndex_for_Clustering(@ARGV) if $main::Oclu; # replace the above 3 functions

    &CreateIndex_for_Multi_Stage_Clustering(@ARGV) if $main::OMulClu;
    exit;

sub BibliographicCoupling {
    my($NSCfileList, $OutCitationFile) = @_;
    my($out, $p, $i, $j, $c, %OutCite, @P, %Couple, @T, %PatList);
    open F, $NSCfileList or die "Cannot read file:'$NSCfileList'";
    while (<F>) {
    	chomp; next if /^\s*$/;
    	$PatList{$_} = 1;
    }
    close(F);
# To know which patents pointing to the same out-degree patents
    open F, $OutCitationFile or die "Cannot read file:'$OutCitationFile'";
    while (<F>) {
#    	next if not /^\d/;
    	next if not /\d/;
    	chomp;
#    	($out, $p) = split ' ', $_;
#    	($p, $out) = split ' ', $_; # $p : desired patent, $out : older patent
    	($p, $out) = split /\t/, $_; # $p : desired patent, $out : older patent
#print STDERR "$PatList{$p}, $p, $out\n";
    	next if not $PatList{$p};
    	$OutCite{$out} .= $p . "\t"; # Out-degree patents were pointed by $p
    }
    close(F);

# Now find the coupling patents
    $c = 0;
    print "#------------- patents with common out-degrees -------------\n";
    foreach $out (keys %OutCite) {
    	@P = split /\t/, $OutCite{$out};
    	next if @P < 2; # skip those patents which have no common out-degree patents
    	$c ++;
print "$out : @P\n";
    	for($i=0; $i<@P; $i++) { # for those have common out-degree patent "$out"
    	    for($j=$i+1; $j<@P; $j++) {
    	    	@T = sort ($P[$i], $P[$j]);
		$Couple{join ("\t", @T)} .= $out . "\t";
	    }
    	}
    }
    print STDERR "There are $c out-degree patents that have two or more patents.\n";
    print STDERR "There are ", scalar keys %Couple, " couplings.\n";
    print "#------------- coupling patents -------------\n";
#    print "# coupled patents : number of common cited patents : common cited patents\n";
#    exit;
# print out the coupling patents
    foreach (sort {$Couple{$b}=~tr/\t/\t/ <=> $Couple{$a}=~tr/\t/\t/} keys %Couple) {
#    foreach (keys %Couple) {
#	print "$_ : ", ($Couple{$_}=~tr/\t/\t/)," : $Couple{$_}\n";
    	@P = split /\t/, $Couple{$_};
    	print "$_ : ", scalar @P, " : ", join("\t", sort @P), "\n";
    }
}

sub CoCitation {
    my($NSCfileList, $InCitationFile) = @_;
    my($in, $p, $i, $j, $c, %InCite, @P, %CoCited, @T, %PatList);
    open F, $NSCfileList or die "Cannot read file:'$NSCfileList'";
    while (<F>) {
    	chomp; next if /^\s*$/;
    	$PatList{$_} = 1;
    }
    close(F);
# To know which patents cite the desired patents
    open F, $InCitationFile or die "Cannot read file:'$InCitationFile'";
    while (<F>) {
#    	next if not /^\d/;
    	next if not /\d/;
    	chomp;
    	($in, $p) = split ' ', $_; # $in : the newer patent, $p : the desired patent
    	next if not $PatList{$p};
    	$InCite{$in} .= $p . "\t"; # In-degree patents pointing to $p
    }
    close(F);

# Now find the co-cited desired patents
    $c = 0;
    print "#------------- desired patents with common in-degrees -------------\n";
    foreach $in (keys %InCite) {
    	@P = split /\t/, $InCite{$in};
    	next if @P < 2; # skip those patents which cite only one desired patent
    	$c ++;
print "$in : @P\n";
    	for($i=0; $i<@P; $i++) { # for those having common in-degree patent "$in"
    	    for($j=$i+1; $j<@P; $j++) {
    	    	@T = sort ($P[$i], $P[$j]);
		$CoCited{join ("\t", @T)} .= $in . "\t";
	    }
    	}
    }
    print STDERR "There are $c patents that cites two or more desired patents.\n";
    print STDERR "There are ", scalar keys %CoCited, " cocited patents.\n";
    print "#------------- cocited patents -------------\n";
#    print "# cocited patents : number of common citing patents : common citing patents\n";
#    exit;
# print out the cocited patents
    foreach (sort {$CoCited{$b}=~tr/\t/\t/ <=> $CoCited{$a}=~tr/\t/\t/} keys %CoCited) {
#    foreach (keys %CoCited) {
#	print "$_ : ", ($CoCited{$_}=~tr/\t/\t/)," : $CoCited{$_}\n";
    	@P = split /\t/, $CoCited{$_};
    	print "$_ : ", scalar @P, " : ", join("\t", sort @P), "\n";
    }
}

# 從資料庫中取得論文及其引用文獻，剖析其引用文獻，以便獲得書目對資料
sub GetCitations { 
    my($Odsn, $Otable) = @_;
    my($DBH, $sql, $STH, $id, $CR, $nr, $cr, @CR, %CR, $Nnr, $n, $idn, @List);
    use DBI;
#    $DBH = DBI->connect( "DBI:ODBC:File",,, {
    $DBH = DBI->connect( "DBI:ODBC:$Odsn",,, { # use -Odsn=File_NSC
      RaiseError => 1, AutoCommit => 0
     }) or die "Can't make database connection: $DBI::errstr\n";
    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
    $DBH->{LongTruncOk} = 1;

    $sql = "SELECT UT, CR, NR FROM $Otable";
    $STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
    $STH->execute()
           or die "Can't run SQL statement: SQL=$sql, $DBI::errstr\n";
    print "Paper\tCited Paper\n" if $main::Oprint;
    while (($id, $CR, $nr) = $STH->fetchrow_array) {
    	@CR = split /;\s*/, $CR;
    	$idn++;
    	push @List, "$id\n";
	if ($nr != @CR) {
	    $Nnr++;
	    print STDERR "$id\tnr=$nr, CR=", scalar @CR, "\n"; 
	}
	foreach $cr (@CR) {
	    next if $cr !~ /,/;
	    print "$id\t$cr\n" if $main::Oprint;
	    $CR{$cr}++;
	    $n++;
	}
    }
    $STH->finish;
    $DBH->disconnect;
    if ($main::OsortNum) {
	print "#---------- Sort by number of cited papers ------------\n";
	@CR = sort {$CR{$b}<=>$CR{$a}} keys %CR;
	foreach $cr (@CR) {	print "$cr\t$CR{$cr}\n";  }    
    }
    if ($main::OsortText) {
	print "#---------- Sort by citation text ------------\n";
	@CR = sort keys %CR;
	foreach $cr (@CR) {	print "$cr\t$CR{$cr}\n";  }    
    } 
    if ($main::OpaperList) {
    	print @List;
    }
    print STDERR "Number of papers that cite others:$idn\n",
    "Number of all citations: $n\n",
    "Number of different cited papers: ", scalar keys %CR, "\n",
    "Number of papers having mismatch citation numbers: $Nnr\n";
}


# 從書目對資料，產生歸類所需檔案
sub Prepare_for_Clustering {
    my($BibCplFile, $IndexPath) = @_;
    my $DocPathFile = $IndexPath . '/DocPath.txt';
    my $SortedPairsFile = $IndexPath . '/SortedPairs.txt';
    if (not -d $IndexPath) {
	mkdir($IndexPath, 0755) or die "Cannot mkdir: '$IndexPath'.";
    }
    open F, $BibCplFile or die "Cannot read file:'$BibCplFile'";
    my($flag, $max, $p1, $p2, $c, $r, %Doc2Id, @Id2Doc, $id);
    $flag = 0; $max = 0; $id = 0; # DocID begins from 0
    while (<F>) {
    	chomp; next if /^\s*$/; # skip if empty line
    	if (/^#\-+\s*coupling/) { $flag = 1; next }
    	next if (not $flag);
    	($p1, $p2, $c, $r) = split /\t| : /, $_;
    	$max = $c if $max < $c;
    	if (not defined $Doc2Id{$p1}) { $Doc2Id{$p1}=$id; $Id2Doc[$id]=$p1; $id++; }
    	if (not defined $Doc2Id{$p2}) { $Doc2Id{$p2}=$id; $Id2Doc[$id]=$p2; $id++; }
    }
    close(F);
    open F, $BibCplFile or die "Cannot read file:'$BibCplFile'";
    open SP, ">$SortedPairsFile" or die "Cannot write to file:'$SortedPairsFile'";
    $flag = 0;
    while (<F>) {
    	chomp; next if /^\s*$/; # skip if empty line
    	if (/^#\-+\s*coupling/) { $flag = 1; next }
    	next if (not $flag);
    	($p1, $p2, $c, $r) = split /\t| : /, $_;
#    	print SP "$Doc2Id{$p1}\t$Doc2Id{$p2}\t", sprintf("%1.6f", $c/$max), "\n";
	my $pair = ($Doc2Id{$p1}<$Doc2Id{$p2})?  # 2008/04/30
	"$Doc2Id{$p1}\t$Doc2Id{$p2}":"$Doc2Id{$p2}<$Doc2Id{$p1}";
    	print SP "$pair\t", sprintf("%1.6f", $c/$max), "\n";
    }
    close(F);
    open DP, ">$DocPathFile" or die die "Cannot write to file:'$DocPathFile'";
    foreach $r (@Id2Doc) {
    	print DP "$r\n";
    }
    close(DP);
}

# 產生歸類結果所需顯示的檔案
sub CreateTitleFile {
    my($Odsn, $Otable, $IndexPath) = @_;
    my($DBH, $STH, $sql, $ti);
    use DBI;
    $DBH = DBI->connect( "DBI:ODBC:$Odsn",,, { # use -Odsn=File_NSC
      RaiseError => 1, AutoCommit => 0
     }) or die "Can't make database connection: $DBI::errstr\n";
    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
    $DBH->{LongTruncOk} = 1;

    $sql = "SELECT TI FROM $Otable where UT = ?";
    $STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
    my $DocPathFile = $IndexPath . '/DocPath.txt';
    my $TitleFile = $IndexPath . '/Title.txt';
    open TI, ">$TitleFile" or die "Cannot write to file:'$TitleFile'";
    open F, $DocPathFile or die "Cannot read file:'$DocPathFile'";
    while (<F>) {
    	chomp; next if /^\s*$/;
	$STH->execute($_)
           or die "Can't run SQL statement: SQL=$sql, $DBI::errstr\n";
        ($ti) = $STH->fetchrow_array;
        print TI "$_ : $ti\n";
    }
    close(F); close(TI);
}


# From the citation data in the DBMS, create index files for clustering.
#   It handles both bibliographic coupings and co-citations.
#   It also handles tabels for patents and for papers, in which the tables
#      are defined differently.
# Given the DSN, Tables of the database, index name, and the index path,
#   Read information from the Tables, 
#   prepare the information for use in Cluster.pm,
#   output the files to the index path
# This function not only can replace the above 3 functions, 
#   (it created DocPath.txt, Title.txt, and SortedPairs.txt)
#   but also create the inv.txt for cluster title extraction.
# Use option: -Occ=TableName for co-cited relation
# The above is for paper databases. For patent databases,
# use option: $main::Opat=TableName
sub CreateIndex_for_Clustering {
    my($Odsn, $Otable, $IndexName, $IndexPath) = @_;
    my($DBH, $sql, $STH, $cr, @CR, $Nnr, $n, $nn, $idn, $pro, $rDC, $py);
    my($id, $ti, $de, $it, $CR, $rCR, $nr, $text, %CitedBy, %Couple, %NR);
    my($percent, $fn); $Nnr = 0;

    use DBI;
    $DBH = DBI->connect( "DBI:ODBC:$Odsn",,, { # use -Odsn=File_NSC
      RaiseError => 1, AutoCommit => 0
     }) or die "Can't make database connection: $DBI::errstr\n";
    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
    $DBH->{LongTruncOk} = 1;
    
# Now get the document number to know the progress
    if ($main::Opat) { # for patent documents
	$sql = "SELECT count(PatentNo) FROM TPatentInfo";
    } else { # for paper documents
	$sql = "SELECT count(UT) FROM $Otable";
    }
    $STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
    $STH->execute()
           or die "Can't run SQL statement: SQL=$sql, $DBI::errstr\n";
    ($fn) = $STH->fetchrow_array;
    print STDERR "Total number of documents to be processed: $fn\n";

# UT : paper id, TI : paper title, DE : descriptors, IT : keywords, 
# CR : citation reference, NR : number of citations
    if ($main::Opat) { # for patent documents
	if ($main::Occ) { # Co-Citation relation
	} else { # for Bibliographic Coupling, to know the tables and fields, see patent's DBMS
	    $sql = "SELECT TPatentInfo.PatentNo, Title, Descript FROM TPatentInfo, TDescription where TPatentInfo.PatentNo=TDescription.PatentNo and TDescription.TypeNo=3";
	}
    } else { # for paper documents
	if ($main::Occ) { # Co-Citation relation
#	    $sql = "SELECT UT, TI, DE, IT, UNI FROM $Otable";
	    $sql = "SELECT UT, TI, DE, ID, UNI FROM $Otable";
	} else { # for Bibliographic Coupling
#	    $sql = "SELECT UT, TI, DE, IT, CR, NR FROM $Otable order by UT";
#	    $sql = "SELECT UT, TI, DE, ID, CR, NR FROM $Otable order by UT";
	    $sql = "SELECT UT, TI, DE, ID, CR, NR, PY FROM $Otable order by UT";
	}
    }
    $STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
    $STH->execute()
           or die "Can't run SQL statement: SQL=$sql, $DBI::errstr\n";

# Prepare the needed files for clustering
    ($rDC, $pro) = &Init($IndexName, $IndexPath);
    my $SortedPairsFile = $IndexPath . '/SortedPairs.txt';
    if (not -d $IndexPath) {
	mkdir($IndexPath, 0755) or die "Cannot mkdir: '$IndexPath'.";
    }

# Get each document's information
    $idn = -1; # ID initialize to -1 in order to start from 0
    while (@CR = $STH->fetchrow_array) {
    	if ($main::Opat) { # for patent documents
    	    ($id, $ti, $de) = @CR;
    	} else { # for paper documents
#	    ($id, $ti, $de, $it, $CR, $nr) = @CR;
	    ($id, $ti, $de, $it, $CR, $nr, $py) = @CR;
	}
	$text = $ti . " . " . $de . " . " . $it; # text for cluster title extraction
#	$rDC->AddDoc($id, "$id : $ti", $text); # pass in (DocPath, Title, Text)
	$rDC->AddDoc($id, "$id : $py:$ti", $text); # pass in (DocPath, Title, Text)
	# the above line will create $TitleFile, $DocPathFile, and $InvFile
# Now process the citations, save them in @$rCR
	@$rCR = (); # initialize to an empty list
    	if ($main::Opat) { # for patent documents
	    ($rCR, $nr) = &GetCR("", $id, $DBH);
    	} else { # for paper documents
	    if ($main::Occ) {
		($rCR, $nr) = &GetCR($main::Occ, $CR, $DBH) ; # if Co-citation
	    } else { # for bibliographic couplings
		foreach $cr (split /;\s*/, $CR) {
		    push @$rCR, $cr if $cr =~ /,/; # chech if a valid citation
		}
	    }
	}
# Now we have citations in @$rCR
#    	@CR = split /;\s*/, $CR; # old format
	if ($nr != @$rCR) { # show the difference btn CR and NR if any
	    $Nnr++;  print STDERR "$id\tnr=$nr, CR=", scalar @$rCR, "\n"; 
	}
    	$idn++; # ID starts from 0
    	$NR{$idn} = scalar @$rCR; # record the number of references of paper $idn
	foreach $cr (@$rCR) {
#	    next if $cr !~ /,/; # not a valid citation, for old format
	    $n++;
	    $CitedBy{$cr} .= $idn . "\t";
	}
	$percent = $pro->ShowProgress(($idn+1)/$fn, $percent);
    }
    $STH->finish;    $DBH->disconnect;
    $rDC->SaveDocIndex(); # save TitleFile, DocPathFile, and InvFile
    $percent = $pro->ShowProgress(($idn+1)/$fn, $percent);
    $nn = scalar keys %CitedBy;
    print STDERR "Number of documents that cite (or are cited by) others:$idn\n",
    "Number of all citations: $n\n",
    "Number of different cited (or citing) papers: $nn\n",
    "Number of papers having mismatch citation numbers: $Nnr\n";

# Now find the coupling (or co-citing) documents, given %CitedBy, %NR
    print STDERR "Now find the coupling (or co-citing) pairs ...\n";
    my($cited, @P, $c, $i, $j, @T, $p1, $p2);
    $n = $percent = 0;
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    while (($p1, $p2) = each %CitedBy) {
	$n++; #print STDERR "$n", scalar @P, ","; print STDERR "\r" if $n%10==0;
	$percent = $pro->ShowProgress($n/$nn, $percent);

    	@P = split /\t/, $p2; # p1 and p2 are temp variables here
    	next if @P < 2; # skip those documents which have no common citations
    	$c ++;
    	for($i=0; $i<@P; $i++) { # for those have common citations
    	    for($j=$i+1; $j<@P; $j++) {
#		@T = sort ($P[$i], $P[$j]);
    	    	my $tmp = ($P[$i]<$P[$j])?"$P[$i]\t$P[$j]":"$P[$j]\t$P[$i]"; # 2008/05/09
		$Couple{$tmp}++; # coupling or co-citing strength
	    }
    	}
    }
print STDERR "Number of raw BibCpl (or CoCt) pairs:", scalar keys %Couple, "\n";
    while (($_, $n) = each %Couple) {
    	if ($n <= $main::Ocpl_cut) {delete $Couple{$_}; next; }
    	($p1, $p2) = split /\t/, $_;
	$Couple{$_} = 2 * $n/($NR{$p1} + $NR{$p2}); # dice similarity
    }
print STDERR "After removing, number of BibCpl (or CoCt) pairs:", scalar keys %Couple, "\n";
    @P = sort {$Couple{$b} <=> $Couple{$a}} keys %Couple;

    open SP, ">$SortedPairsFile" or die "Cannot write to file:'$SortedPairsFile'";
    foreach (@P) {
    	print SP "$_\t", sprintf("%1.6f", $Couple{$_}), "\n";
    }
    close(SP);
    if ($main::Occ) {
	print STDERR "There are $c citing papers that have two or more cited papers.\n",
     "There are ", scalar keys %Couple, " co-citations.\n";
    } else {
	print STDERR "There are $c cited papers that have two or more citing papers.\n",
     "There are ", scalar keys %Couple, " couplings.\n";
    }
}

# Given the citation table and the cited_ID, 
#   return the citing papers in the format same to the cited papers
sub GetCR {
    my($table, $id, $DBH) = @_;  my($STH, $sql, $UT, $CR, $nr, @CR);
    if ($main::Opat) { # for patent documents
        if ($main::Occ) { # select those who cite the concerned patents for Co-Citation
	    $sql = "SELECT distinct CitingPatentNo FROM TCitingPatent where PatentNo='$id'";
        } else { # select those cited by our concerned patents for Bib_Cpl
	    $sql = "SELECT distinct CitePatentNo FROM TCitePatent where PatentNo='$id'"; #5928741
	}
    } else { # for paper documents 
    	# select those papers who cite the core paper (identified by CPI)
	$sql = "SELECT UT FROM $table where CPI=$id"; 
    }
    $STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
    $STH->execute()
           or die "Can't run SQL statement: SQL=$sql, $DBI::errstr\n";
    $nr = 0;
    while (($UT) = $STH->fetchrow_array) {
#    	$CR .= $UT . ",;"; # a format required later
	push @CR, $UT;
    	$nr ++;
    }
#    return ($CR, $nr);
    return (\@CR, $nr);
}


# Use global variable : $Odebug, 
# return variables : $pro, $rDC
sub Init {
    my($IndexName, $IndexPath) = @_;  my($pro, $rDC);
    use Cluster;
    $rDC = Cluster->new( { 'debug'=>1 } );
    $rDC->SetValue('debug', $main::Odebug) if $main::Odebug;

    $rDC->SetValue('DocType', 'doc'); # 'doc' or 'term' (clustering)
#    $value = $rDC->GetValue('DocType'); # get attribute's value if needed
    $rDC->SetValue('IndexBy', 'me'); # or by 'WG' or 'me' (this program)
    $rDC->SetValue('Save2File', 1); # default is 0
    # if you want to save the results to files for fast later re-use, 
    # set 'Save2File' to 1 (0 otherwise), and set the next 2 attributes.
    $rDC->SetValue('IndexName', $IndexName);
    $rDC->SetValue('IndexPath', $IndexPath); # needed if 'IndexBy' is 'me'
#    $rDC->SetValue('Sim', $OSM); # set similarity, default is 'Cosine'

#    use SAM::Progress; # already used in Cluster.pm
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
    return ($rDC, $pro);
}



# --------- Below are to be finished ... ------------------
# Next functions are for multi-stage clustering based on 
#   bibliographic coupings and co-citations
# From the citation data in the DBMS (to know citation data) 
#   and in the doc/ folder (to know clustering data in the previous stage),
#   create index files for next-stage's clustering.
#   It handles both bibliographic coupings and co-citations.
#   It also handles tabels for patents and for papers, in which the tables
#      are defined differently.
# Given the DSN, Tables of the database, doc/ folder, index name, and the index path,
#   Read information from the Tables, 
#   prepare the information for use in Cluster.pm,
#   output the files to the index path
## Use option: -Occ=TableName for co-cited relation
## The above is for paper databases. For patent databases,
## use option: $main::Opat=TableName
#  perl -s CiteAna.pl -OMulClu EduEval EEPA318 EEPA318_BibCpl_S2 ..\Result\EEPA318_BibCpl_S2 ..\doc\EEPA318_BibCpl_S2
sub CreateIndex_for_Multi_Stage_Clustering {
    my($Odsn, $Otable, $IndexName, $IndexPath, $DocPath) = @_;
    my($DBH, $cr, @CR, $Nnr, $n, $nn, $idn, $pro, $rDC);
    my($id, $ti, $de, $it, $CR, $nr, $text, %CitedBy, %Couple, %NR);
    my($percent, $i, $fn, @ClusterFiles); $Nnr = 0;

    use DBI;
    $DBH = DBI->connect( "DBI:ODBC:$Odsn",,, { # use -Odsn=File_NSC
      RaiseError => 1, AutoCommit => 0
     }) or die "Can't make database connection: $DBI::errstr\n";
    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
    $DBH->{LongTruncOk} = 1;
    
# Now get the document number to know the progress
#   Read files from $DocPath to know how many clusters to process
    $fn = @ClusterFiles = sort {$a<=>$b} glob("$DocPath/*.*");
    print STDERR "Total number of documents to be processed: $fn\n";
# Prepare the needed files for clustering
    ($rDC, $pro) = &Init($IndexName, $IndexPath);
    my $SortedPairsFile = $IndexPath . '/SortedPairs.txt';
    if (not -d $IndexPath) {
	mkdir($IndexPath, 0755) or die "Cannot mkdir: '$IndexPath'.";
    }
# Get each cluster's information
    $idn = -1; # ID initialize to -1 in order to start from 0
    my($cfile, $rCR, $rCluDoc);
    foreach $cfile (@ClusterFiles) {
# Read each file's content to know the documents in the file
# For each document, read their citation data from DBMS
# Cascade these citation data in @CR
# Then we can use the old codes for the rest of function.
	($id, $ti, $de, $rCluDoc) = &ReadClusterFile($cfile);
	# return cluster id, cluster title, cluster text
	#  and the document ids in this cluster
#	$text = $ti . " . " . $de ; # text for cluster descriptor extraction
	$rDC->AddDoc($cfile, $ti, $de); # pass in (DocPath, Title, Text)
	# the above line will create $TitleFile, $DocPathFile, and $InvFile
# Now process the citations
	($rCR) = &GetBatchCR($rCluDoc, $DBH, $Otable);
#print STDERR "cfile=$cfile, id=$id, ti=$ti, de=$de, rCluDoc=", join(" ", @$rCluDoc), "\n",
#	"rCR=", join(' ', @$rCR), "\n"; exit;
    	$idn++; # ID starts from 0
#	$idn = $id; # how about letting idn be the cluster_id.
    	$NR{$idn} = scalar @$rCR; # record the number of references of cluster $idn
	foreach $cr (@$rCR) {
	    $n++;
	    $CitedBy{$cr} .= $idn . "\t";
	}
	$i++; $percent = $pro->ShowProgress(($i)/$fn, $percent);
    }
    $rDC->SaveDocIndex(); # save TitleFile, DocPathFile, and InvFile
    $percent = $pro->ShowProgress($i/$fn, $percent);
    $nn = scalar keys %CitedBy;
    print STDERR "Number of documents that cite (or are cited by) others:$fn\n",
    "Number of all citations: $n\n",
    "Number of different cited (or citing) papers: $nn\n",
    "Number of papers having mismatch citation numbers: $Nnr\n";
    $DBH->disconnect;


# Below are the codes that can be reused to compute bib_cpl or co-citation.
# Now find the coupling (or co-citing) documents, given %CitedBy, %NR
    print STDERR "Now find the coupling (or co-citing) pairs ...\n";
    my($cited, @P, $c, $j, @T, $p1, $p2);
    $n = $percent = 0;
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    while (($p1, $p2) = each %CitedBy) {
	$n++; #print STDERR "$n", scalar @P, ","; print STDERR "\r" if $n%10==0;
	$percent = $pro->ShowProgress($n/$nn, $percent);
#print STDERR "$p1 : $p2\n";
    	@P = split /\t/, $p2; # p1 and p2 are temp variables here
    	next if @P < 2; # skip those documents which have no common citations
    	$c ++;
    	for($i=0; $i<@P; $i++) { # for those have common citations
    	    for($j=$i+1; $j<@P; $j++) {
#    	    	@T = sort ($P[$i], $P[$j]);
    	    	my $tmp = ($P[$i]<$P[$j])?"$P[$i]\t$P[$j]":"$P[$j]\t$P[$i]"; # 2008/05/09
		$Couple{$tmp}++; # coupling or co-citing strength
	    }
    	}
    }
    while (($_, $n) = each %Couple) {
    	if ($n <= $main::Ocpl_cut) {delete $Couple{$_}; next; }
    	($p1, $p2) = split /\t/, $_;
	$Couple{$_} = 2 * $n/($NR{$p1} + $NR{$p2}); # dice similarity
    }
    @P = sort {$Couple{$b} <=> $Couple{$a}} keys %Couple;
    open SP, ">$SortedPairsFile" or die "Cannot write to file:'$SortedPairsFile'";
    foreach (@P) {
    	print SP "$_\t", sprintf("%1.6f", $Couple{$_}), "\n";
    }
    close(SP);
    if ($main::Occ) {
	print STDERR "There are $c citing papers that have two or more cited papers.\n",
     "There are ", scalar keys %Couple, " co-citations.\n";
    } else {
	print STDERR "There are $c cited papers that have two or more citing papers.\n",
     "There are ", scalar keys %Couple, " couplings.\n";
    }
}


# Given $DBH and the document id in a cluster
#   return the cited (or citing) document ids (in this cluster)
sub GetBatchCR {
    my($rCluDoc, $DBH, $Table) = @_;  my($STH, $sql, $UT, @CR, $id, %CR, $cr);
    foreach $id (@$rCluDoc) {
	if ($main::Opat) { # for patent documents
	    if ($main::Occ) { # select those who cite the concerned patents for Co-Citation
		$sql = "SELECT distinct CitingPatentNo FROM TCitingPatent where PatentNo='$id'";
	    } else { # select those cited by our concerned patents for Bib_Cpl
		$sql = "SELECT distinct CitePatentNo FROM TCitePatent where PatentNo='$id'"; #5928741
	    }
	} else { # for paper documents 
	    if ($main::Occ) {
### To be finished and tested...2006/10/22
    	# select those papers who cite the core paper (identified by CPI)
###	    $sql = "SELECT UT FROM $table where CPI=$id"; 
	    } else {
		$sql = "Select CR from $Table where UT = '$id'";
	    }
	}
	$STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
           or die "Can't run SQL statement: SQL=$sql, $DBI::errstr\n";
	while (($UT) = $STH->fetchrow_array) {
	    if ($main::Opat) {
		$CR{$UT} = 1; # to delete duplicate citations
	    } else {
		if ($main::Occ) {
# to be finished... 2006/10/22, maybe it is only "$CR{$UT} = 1;"
		} else {
		    foreach $cr (split /;\s*/, $UT) {
			$CR{$cr}=1 if $cr =~ /,/; # chech if a valid citation
		    }
		}
	    }
	}
    }
    @CR = sort keys %CR; # a format required later
    return (\@CR);
}


# Given the cluster file,
# return cluster id, cluster title, cluster text
#  and the document ids in this cluster
sub ReadClusterFile {
    my($cfile) = @_; 
    my($f, $title, $ti, @DocID, $cid, $did, $csize, $r, $text);
    $f = 0;
    open F, "$cfile" or die "Cannot read file:'$cfile'";
    while (<F>) {
    	if (m|<title>(.+)</title>|i) {
	    next if $f; # if already seen the title, other titles are subclusters'
	    $f = 1; $title = $1; next; 
	}
    	($ti, $did, $r) = split / : /, $_; # Diapers having improved acquisition rates : 6392116 : Improved diaper cores containing particles of ...
# Note: refer to &GetTitles() in tool.pl for getting the $did
    	next if $did =~ /[,\.;\(\# ]/;
    	next if length($ti) < 5 or length($did)<6 or length($did)>25; # not a valid line
    	push @DocID, $did;
	$text .= $ti . ".\t";
#    	$text .= $r;  # this may create huge text
    }
    close(F);
    if ($cfile =~ m|(\d+)[\_\-](\d+)[\_\-\d]+\.htm$|) {
    	$cid = $1; $csize = $2;
    }
    return ($cid, $title, $text, \@DocID);
}
