#!/usr/bin/perl -s
# https://stackoverflow.com/questions/728597/how-can-my-perl-script-find-its-module-in-the-same-directory
use File::Basename;
use lib dirname (__FILE__);
    use SamOpt qw(SamOpt);  &SamOpt();
# This program is an example of using the APIs of DocCluster.pm. 2004/01/27
# You need SAM module or SAMtool module.
# You also need ShowDoc.pl for showing full text content in a CGI environment.
# This program is copied from d:\dem\SAM\cluster\DocCluster.pm 
# Except documents in files, this program allow documents in DB.
    $stime = time();
    ($IndexName, $IndexPath, $FileList) = @ARGV;
    $Olow_df	 = 2 if $Olow_df eq '';
    $Ohigh_df	 = 30000 if $Ohigh_df eq '';
    $Olow_tf     = 1 if $Olow_tf eq '';
    $Oct_low_tf  = 1 if $Oct_low_tf eq '';
    $Ocut	 = 0.0 if $Ocut eq '';
    $ONumCatTitleTerms = 5 if $ONumCatTitleTerms eq '';
#    $Otfc = 'TFC' if $Otfc eq '';
    $OMaxCluster = 1000 if not $RunInCGI; # in DOS there is no limit
    $OSM = 'Cosine' if $OSM eq ''; # default is 'Cosine'
    &Init();

# perl -s cluster.pl -OdelStop -Odebug NSC_Seg_Abs6 Result/NSC_Seg_Abs6
    if ($OdelStop) { &DeleteStopwords(); &myexit(); } # delete stopwords in the index:
# perl -s cluster.pl -Oconvert NSC_DocCluster Result\NSC_DocCluster
    if ($Oconvert) { $rDC->ConvertIndex(); &myexit(); }
    
# D:\demo\File>perl -s Cluster.pl -Oall -Odebug=1 -Osrc=Dir doc Result\doc > Result\doc.html
# perl -s Cluster.pl -Oall -Odebug -Osrc=Dir NSC_DocCluster Result\NSC_DocCluster NSC_DocCluster.lst
    if ($Oall) { &FromDoc2CutTree(); &myexit(); }

# perl -s cluster.pl -Oidx -Odebug -Olow_tf=1 -Oct_low_tf=2 -Ocut=0.005 
#   NSC_Seg_Abs6 Result/NSC_Seg_Abs6 > Result\NSC_Seg_Abs6_2_1_5_2_0.005.html
    if ($Oidx) { &FromIndex2CutTree(); &myexit(); }

# D:\demo\File>perl -s Cluster.pl -Osim -Odebug=1 doc Result\doc > Result\doc.html
    if ($Osim) { &FromSim2CutTree(); &myexit(); }

# perl -s Cluster.pl -Osi SciE_BibCpl_S4 ..\Result\SciE_BibCpl_S4
    if ($Osi) { &Compute_Silhouette_Index($Ocut); &myexit(); }

# ex: perl -s Cluster.pl -Odebug=1 -Ocut cdn d:\cdn cdn_lst.txt > cdn.html
# perl -s Cluster.pl -Odebug -Ocut=0.1 NSC_DocCluster Result\NSC_DocCluster NSC_DocCluster.lst > NSC_DocCluster_0.1.html
# perl -s Cluster.pl -Odebug -ObigDoc=manual Phar "select UT, TI, AB from TPaper where UT=?" ..\Source_Data\Phar\PlaintextFormat ..\doc\Phar_BibCpl_S2
    if ($ObigDoc eq 'manual') { 
    	&FromManualCluster2BigDoc(@ARGV); #($DSN, $sql, $InDir, $OutDir);
    } elsif ($ObigDoc) {
		&FromFile2BigDoc($FileList);
    } else {
		&FromFile2CutTree();
    }
    &myexit(); 
    
sub myexit {
    $etime = time();
    print STDERR "\nIt takes ", $etime - $stime, " seconds for all the steps.\n" if $Odebug;
    exit;
}

# Use global variable : $Odebug, $IndexName, $IndexPath
# set global variables : $pro, $rDC
sub Init {
    use Cluster;
    $rDC = Cluster->new( { 'debug'=>0 } );
    $rDC->SetValue('debug', $Odebug) if $Odebug;

    $rDC->SetValue('DocType', 'doc'); # 'doc' or 'term' (clustering)
#    $value = $rDC->GetValue('DocType'); # get attribute's value if needed
    $rDC->SetValue('IndexBy', 'me'); # or by 'WG' or 'me' (this program)
    $rDC->SetValue('Save2File', 1); # default is 0
    # if you want to save the results to files for fast later re-use, 
    # set 'Save2File' to 1 (0 otherwise), and set the next 2 attributes.
    $rDC->SetValue('IndexName', $IndexName);
    $rDC->SetValue('IndexPath', $IndexPath); # needed if 'IndexBy' is 'me'
    $rDC->SetValue('Sim', $OSM); # set similarity, default is 'Cosine'
    $rDC->SetValue('OphraseOnly', $OphraseOnly); # only phrases for cluster titles
    if ($OEng_Seg_Phrase) {# if using (only) manual-selected terms for indexing
      $rDC->SetValue('Eng_Seg_Phrase', $OEng_Seg_Phrase);
      if (-f $OEng_Seg_Phrase) {
	      require "./SetManualTerms.pl"; # You can add terms here
  	    &SetManualTerms($rDC, $rDC->{'Seg'}, $OEng_Seg_Phrase);
      } else {
        die "Cannot read file:'$OEng_Seg_Phrase'";
      }
    }
    $rDC->SetValue('OutputRelatedTerms', $ORT) if $ORT;
    $rDC->SetValue('IdxTnoStem', $IdxTnoStem) if $IdxTnoStem;

# You can add Chinese stop words here
    require "./StopWords.pl";
    &SetStopWords($rDC, $rDC->{'Seg'});
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
}


sub DeleteStopwords {
    $NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
    $rDC->DeleteStopword();
    $rDC->SaveDocIndex();
}

# This function shows how to cluster the documents from the begining to the end.
sub FromDoc2CutTree {
# if 'IndexBy' is 'me' and not yet built the index, insert docs for later use
#   foreach $term (@Term) { $rDC->AddIndexTerm( $term );#if extra terms needed
    $sot = time();
    if ($Osrc eq 'Dir') {
    	$tfn = $rDC->InitDocSrc('Dir', $FileList);
    } else { # if ($Osrc eq 'DB')
#	$DSN = 'File'; $sql = "select ID from Src_Data order by ID";
    	$DSN = $rDC->{DSN};
    	$sql = "select ID from $rDC->{Table} order by ID";
    	$DB_Path = ($main::ODB eq '') ? $rDC->{DB_Path} : $main::ODB;
    	$tfn = $rDC->InitDocSrc('DB', $DSN, $sql, $DB_Path);
    }
    $sql = "select ID, SNo, Fname, Dname, Dscpt from $rDC->{Table} where ID = ?";
    $fi = 0; 
# In NextDoc(), it uses $me->{'Src'} eq 'Dir' to know $sql is valid or not
    while (($DocPath, $title, $text) = $rDC->NextDoc($sql)) { 
    	$fi++; last if $DocPath eq '';

=no more used    	
    	if ($IndexName eq 'NSC_DocCluster') { # special for NSC_DocCluster
# 69 : 2筆,0.27(immobilize:0.71, reactor:0.50, enzyme:0.42)
    	    if ($text =~ /\s(\d+.+\(.+\))/)
    	    {	$title = $1;   } else { $title = ''; }
    	}
=cut

#    for ($fi = 0; $fi < $tfn; $fi++) {
#        ($DocPath, $title, $text) = $rDC->NextDoc($sql);
    	$rDC->AddDoc($DocPath, $title, $text); # insert those to be clustered
    	$percent = $pro->ShowProgress($fi/$tfn, $percent) if $Odebug;
    }
    $percent = $pro->ShowProgress($fi/$tfn, $percent) if $Odebug;
    $NumDoc = $rDC->SaveDocIndex() if $rDC->GetValue('Save2File');
    $NumDoc = $rDC->GetValue('NumDoc'); # return number of documents inserted
    $eot = time();
print STDERR "  It takes ", $eot - $sot, " seconds to insert $tfn documents\n" if $Odebug;
    &FromIndex2CutTree(); # Use option $Olow_tf, $Oct_low_tf
}



# If you have already saved the results, just read them back to compute
# another ways of clustering using different thresholds.
# Use option $Olow_df, $Olow_tf, $Oct_low_tf
sub FromIndex2CutTree {
    $rDC->SetValue('Method', 'CompleteLink'); # 'SingleLink', 'Cluto', or 'SOM'
    $rDC->SetValue("low_df", $Olow_df); # do not use term whose df <= 2
    $rDC->SetValue("high_df", $Ohigh_df); # do not use term whose df >= 30000
    $rDC->SetValue("low_tf", $Olow_tf); # do not use those term whose tf in doc is<=0
    $NumDoc = $rDC->ReadDocIndex() if $rDC->GetValue('Save2File');
#    $rDC->ReadSimilarity() if $rDC->GetValue('Save2File');
    $root = $rDC->DocSimilarity();
    $rDC->SaveSimilarity() if $rDC->GetValue('Save2File');
    &FromSim2CutTree(); # Use option $Oct_low_tf
}

# If you have already saved the pairs with similarity sorted, 
# just read them back to compute another ways of clustering 
#  using different thresholds.
# Use option $Oct_low_tf
sub FromSim2CutTree {
    $rDC->ReadSimilarity() if $rDC->GetValue('Save2File');
    $rDC->CompleteLink();
    $rDC->SaveTree() if $rDC->GetValue('Save2File');
    &FromFile2CutTree(); # Use option $Oct_low_tf
}


# Given the clustered index and data in a directory, read these data back
#  use a given threshold, cut the single cluster into small clusters.
# Use option $Oct_low_tf, $Ocut 'NumCatTitleTerms'
sub FromFile2CutTree {
    $NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
#    $root = $rDC->ReadSimilarity(); # no longer needed for re-cluster
    $rDC->ReadTree();
# set the URL to show the full content of the inserted file (using its )
    $rDC->SetValue("ShowDoc", "http://localhost/demo/STPIWG/src/ShowDoc.pl");
    $rDC->SetValue('NumCatTitleTerms', $ONumCatTitleTerms);
    $rDC->SetValue("ct_low_tf", $Oct_low_tf); # do not use term whose tf <= 1
    $rDC->SetValue('ClusterTitle', $Otfc); # 'TFC');
    $htmlstr = $rDC->CutTree($Ocut);
    $htmlstr = "<html><head><META content='text/html; charset=big5'></head>"
    		. "<body bgcolor=white>" . $htmlstr . "\n<br></body></html>";
    print $htmlstr; # print out to the browser in CGI environment
}


# Given the clustered index and data in a directory, read these data back
#  use a given threshold, cut the single cluster into small clusters.
# Then save each of the smaller clusters in a big document under a directory.
# Use option $Oct_low_tf, $Ocut 'NumCatTitleTerms'
# Use option $Odsn, $Osql for fetching (bib_cpl)documents in DBMS
#     也就是：如果歸類後的結果在 Result\ 中，但文件在 DBMS 裡，就用上面的選項
sub FromFile2BigDoc {
    my($OutDir) = @_;
    if (-d $OutDir) { &DelAllFile($OutDir); }    
    &CreateDir($OutDir);
    $NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
#    $root = $rDC->ReadSimilarity(); # no longer needed for re-cluster
    $rDC->ReadTree();
    $rDC->SetValue('NumCatTitleTerms', $ONumCatTitleTerms);
    $rDC->SetValue("ct_low_tf", $Oct_low_tf); # do not use term whose tf <= 1
    $rDC->SetValue('ClusterTitle', $Otfc); # 'TFC');
    $rDC->SetValue('MinCluSize', $OMinCluSize) if defined $OMinCluSize;
    # do not output the clusters containing <= $OMinCluSize documents 
# 2006/10/22 To dump the document from a DBMS we need next if
    if ($Odsn) {
    	$rDC->{DSN} = $Odsn; 
    	$rDC->{DB_Path}= $main::ODB; # 2010/05/09
    	$rDC->{SQL} = $Osql; 
    }
# By calling CutTree() with a second argument, the documents 
#   in the same cluster are saved to the same file under folder:$OutDir
    $htmlstr = $rDC->CutTree($Ocut, $OutDir);
}

# Given a directory ($InDir) where documents have been manual clustered
#   (e.g., files downloaded from ISI's research fronts),
#   convert the manual clusters into the format and strucutre ready for 
#   the next stage's automatic clustering.
sub FromManualCluster2BigDoc {
    my($DSN, $sql, $InDir, $OutDir) = @_;
    my(@Files, $f, @UT, $str, $nr, $terms, $t, $tt, @terms, $i);
    my($percent, $fi, $tfn) = (0.0, 0, 0); my($DBH, $STH);

    use SAMtool::SegWord;
    my $SegWord = SegWord->new( { 'WordDir'=>'SAM/word' } );
    $SegWord->Value('WantRT', 0); # no related terms, no abstract
    my($rIWL,$rIFL,$rWL,$rFL,$rName,$rSWL,$rSFL,$rSN,$rLinkValue,$rTitleSen);

#print "DSN=$DSN, InDir=$InDir\n"; exit;
    if (-d $OutDir) { &DelAllFile($OutDir); }    
    &CreateDir($OutDir);

#    $DSN = "driver=Microsoft Access Driver (*.mdb, *.accdb);dbq=$main::ODB" if $main::ODB ne '';
#    $DBH = DBI->connect( "DBI:ODBC:$DSN",,, {
#       RaiseError => 1, AutoCommit => 0
#     } ) or die "Can't make database connect: $DBI::errstr\n";
#    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
#    $DBH->{LongTruncOk} = 1;
    $DBH = &InitDBH($DSN, $main::ODB); # added on 2017/08/28

    $STH = $DBH->prepare($sql)
	or die "Can't prepare SQL statement: $DBI::errstr\n";

    $tfn = @Files = glob("$InDir/*.*");
    print STDERR "There are ", scalar @Files, " files\n";
    my($txt, $encoding_name);
    foreach $f (@Files) {
    	$percent = $pro->ShowProgress(++$fi/$tfn, $percent) if $Odebug;
# Get @UT to know which documents are in the same cluster
    	@UT = (); $str = ''; # reset @UT and $str to empty
    	open F, $f or die "Cannot read file:'$f'";
    	# the pattern is "UT ISI:000233774400029"
    	while (<F>) { chomp; if (/^UT\s*(.+)\s*$/) { push @UT, $1; } }
    	close(F);
# Read their Title, ID, and Abstract to write to the output directory
	foreach $did (@UT) {
	    $STH->execute($did);
	    while (($id, $title, $content) = $STH->fetchrow_array) {
	   		foreach $txt ($title, $content) {
				$encoding_name = Encode::Detect::Detector::detect($txt);
				if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
					$txt = encode("big5", $txt);
				}
			} 
#			$str .= "$title : $id : $content. \n"; # title, $id, $content
			$str .= "$title\t:\t$id\t:\t$content. \n"; # title, $id, $content
	    }
	}
# Get keywords for cluster title
	($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
	    $rLinkValue, $rTitleSen) = $SegWord->ExtractKeyPhrase( $str );
	@terms = (); $i = 0;
	foreach $t (@$rWL) {
	    next if $t =~ /^(li|isi)$/;
	    $tt = $t; $tt =~ s/ (\W)/$1/g; # delete space before Chinese char.
	    push @terms, "$tt: $rFL->{$t}"; last if ++$i >=5; 
	} $terms = join(", ", @terms);
# Write the result
	$nr = @UT; $ff = "$OutDir/${fi}_${nr}.htm";
	open FF, ">$ff" or die "Cannot write to file:'$ff'";
# example : <html><head><title>7373 : 8筆 : 0.050000(tangier-disease: 13.1, cholesterol:  9.7, apoa-i:  8.6, efflux:  6.8, cassette:  4.5)</title></head>
#	print FF "<html><head><title>$fi : $nr筆 : 0.5($terms)</title></head>\n";
	print FF "<html><head><title>$fi : $nr Docs. : 0.5($terms)</title></head>\n";
	print FF "<body>\n$str\n</body></html>\n";
	close(FF);
    }
#    $percent = $pro->ShowProgress($fi/$tfn, $percent) if $Odebug;
}


sub Compute_Silhouette_Index {
    my($prev_si);
    $rDC->ReadTree();
    $root = $rDC->ReadSimilarity(); # no longer needed for re-cluster
    $prev_si = -2;
#    for ($cut=0.0; $cut<=0.1; $cut+=0.01) { # remark on 2012/06/24
    for ($cut=0.0; $cut<=0.1; $cut+=0.005) { # 2013/07/28
	($si, $rsi_k, $rsi_k_i, $rDid2Cids, $rCid2Dids, $NumClu, $NumDoc) 
    	    = $rDC->Silhouette($cut);
#    	if ($prev_si != $si) {
	    print "cut=", sprintf("%0.3f", $cut), "\tsi=",sprintf("%+0.4f",$si), 
	    "\tCluster=$NumClu\tDoc=$NumDoc\n";
#	}
	$prev_si = $si;
	if ($cut>=0.4) { $cut+=0.005; } # 2013/07/28
    }
}

sub DelAllFile {
    my($dir) = @_;    my(@Files, $f, $i);
    @Files = glob("$dir/*.*");
print STDERR "Deleting all files in dir:'$dir'\n";
#print STDERR "\@Files=@Files\n";
    foreach $f (@Files) {
    	next if $f !~ m#\.(htm|txt)l?$#i;
#    	print STDERR "$f, ";
    	unlink $f or die "Cannot delete file:'$f'";
    	$i++;
    }
#    print STDERR "\n";
    print STDERR "\nThere are ", scalar @Files, 
      " old files, but only $i files are deleted\n" if $i<@Files;
}

sub CreateDir {
    my($OutDir) = @_; my(@Path, $path, $i);
    @Path = split /[\/\\]/, $OutDir;
    for($i=0; $i<@Path; $i++) {
    	$path = join('/', @Path[0..$i]);
    	if (not -d $path) {
    	    print STDERR "Creating the folder:'$path'\n";
    	    mkdir($path, 0755) or warn "Cannot mkdir: '$path', $!";
    	}
    }
}


