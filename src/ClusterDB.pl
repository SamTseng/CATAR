#!/usr/bin/perl -s
# https://stackoverflow.com/questions/728597/how-can-my-perl-script-find-its-module-in-the-same-directory
use File::Basename;
use lib dirname (__FILE__);
	use SamOpt qw(SamOpt);  &SamOpt();
	
# This program is an example of using the APIs of DocCluster.pm. 2004/01/27
# You need SAM module or SAMtool module.
# You also need ShowDoc4.pl for showing full text content in a CGI environment.
# This program is copied from d:\dem\SAM\cluster\DocCluster.pm 
# Except documents in files, this program allow documents in DB.
	$Out2File = 0 if not defined $Out2File; # cluster results saved in DBMS
	$Ogrp = 'Src_Data' if not defined $Ogrp; # set defualt group
# option $Ogrp is required if you want to change 'group' without changing INI
	# if $Out2File is set to 1 then cluster output goes to an HTML file
	$RunInCGI = (@ARGV > 0) ? 0 : 1;
	$RunInCGI = 0 if $Odel; # this DOS command option needs no arguments
	if ($RunInCGI) {
		&RunInCGI();
	} else { # if run in DOS
	($IndexName, $IndexPath, $FileList) = @ARGV;
# $IndexName and $IndexPath are overrided by Cluster.ini
	&RunInDOS();
	}
	exit;

sub RunInCGI {
	use CGI qw/:standard/;
	print "Content-type: text/html\n\n";
# Get and Set all necessary variables
#	$IndexName = param('IndexName');
#	$IndexPath = param('IndexPath');
#	if ($IndexName eq '' or $IndexPath eq '') { # if not defined
#		($IndexName, $IndexPath) = ('doc', 'Result\doc');
#	}
	$Ogrp = param('Ogrp'); # this can override $IndexName and $IndexPath
# command options
	$Ocut = param('Ocut');
	$Odel = param('Odel');
	$ORT = param('ORT');
# parameters for DBMS 
	$Ouid = param('Ouid');
#	$Odsn = param('Odsn'); # DSN is set in Cluster.ini, 2005/08/17
#	$Odsn = 'File' if $Odsn eq ''; # if not defined
# paramenters for clustering effect
	$Oct_low_tf = param('Oct_low_tf');
	$Olow_tf	= param('Olow_tf');
	$Otfc	= param('Otfc');
	$ONumCatTitleTerms = param('NumCatTitleTerms');
	$OMaxCluster = param('MaxCluster');
	$Othreshold  = param('threshold');
	$Ocut = $Othreshold if ($Othreshold >= 0 and $Othreshold <= 1.0);

#print "Ocut=$Ocut, Odsn=$Odsn, Ouid=$Ouid, ($IndexName, $IndexPath)<br>\n";
#print "thre=$Othreshold, MaxClu=$OMaxCluster, NumCat=$ONumCatTitleTerms<br>\n";
	$htmlstr = &RunInDOS();	
	&OutPutResult($htmlstr);
}

# Use global: $Ouid, $Odsn, $Ogrp
sub OutPutResult { 
	my($htmlstr) = @_;
	print <<END_OF_HTML;
	<HTML>
	<HEAD><META content='text/html; charset=big5'>
	<META HTTP-EQUIV="Refresh" Content="0;URL=ListCluster.pl?UID=$Ouid&Action=0&Odsn=$rDC->{DSN}&Otable=$rDC->{Table}">
	</HEAD>
	<body>
	</body></html>		   
END_OF_HTML
}

# variables begin with $O are options, they are given in command line
sub RunInDOS {
	$stime = time();
	$Olow_df	 = 2 if $Olow_df eq '';
	$Ohigh_df	 = 30000 if $Ohigh_df eq '';
	$Olow_tf	 = 1 if $Olow_tf eq '';
	$Oct_low_tf  = 1 if $Oct_low_tf eq '';
	$Ocut	 = 0.0 if $Ocut eq '';
	$ONumCatTitleTerms = 10 if $ONumCatTitleTerms eq '';
	$OMaxCluster = 1000 if not $RunInCGI; # in DOS there is no limit
	&Init();

# D:\demo\File>perl -s ClusterDB.pl -Odel -Odsn=File -Ouid=10 -Odebug 
#print "<br>Ocut=$Ocut, Odel=$Odel<br>\n";
	if ($Odel) { &DeleteRecords(@ARGV); &myexit(); }

# perl -s ClusterDB.pl -Oall -Ocut=0.5 -Ouid=20 -Odebug=1 -Ogrp=WG_RK 1 > term2\term2_0.5.html
# perl -s ClusterDB.pl -Oall -Ouid=20 -Odebug=1 -Ogrp=NSC_Seg_Abs6 1
# perl -s ClusterDB.pl -Oall -Ouid=20 -Olow_tf=1 -Oct_low_tf=1 
#   -Odebug=1 -Ogrp=envi01_dc -ODB=..\Source_Data\envi01\envi01.mdb 1
	if ($Oall) { &FromDoc2CutTree(); &myexit(); }

	if ($Oidx) { &FromIndex2CutTree(); &myexit(); }

# perl -s ClusterDB.pl -Osim -Ocut=0.9 -Ogrp=Src_Data -Odebug=1 1 > Result\doc5_0.9.html
	if ($Osim) { &FromSim2CutTree(); &myexit(); }

# perl -s ClusterDB.pl -Ocut=0.98 -Oct_low_tf=0 -Odsn=File -Ouid=10 doc Result\doc
# perl -s ClusterDB.pl -Ocut=0.0 -Ouid=20 -Odebug=1 -Ogrp=NSC_Seg_Abs6 1
	if ($Ocut) { $htmlstr = &FromFile2CutTree(); &myexit(); }
}
sub myexit {
	$htmlstr = "<html><head><META content='text/html; charset=big5'></head>"
			. "<body bgcolor=white>" . $htmlstr . "\n<br></body></html>";
	#print $htmlstr; # comment on 2019/08/27
	$etime = time();
	print STDERR "\nIt takes ", $etime - $stime, " seconds for all the steps.\n" if $Odebug;
	if ($RunInCGI) { return $htmlstr; }
}

# Use global variable : $Odebug, $Odsn, $Ouid, $IndexName, $IndexPath
# set global variables : $pro, $rDC
sub Init {
  if ($Out2File) { # output to files
	use Cluster; 
	$rDC = Cluster->new( { 'debug'=>1 } ); # do not support Cluster.ini
	$rDC->SetValue('debug', $Odebug) if $Odebug;
  } else { # output to DBMS
	use ClusterDB;
	$rDC = ClusterDB->new( { INI=>'Cluster.ini' } );
	$rDC->SetValue('debug', $Odebug) if $Odebug;
#	$rDC->InitDBMS($Odsn);
#	$rDC->InitDBMS(); # DSN is set in Cluster.ini , 2005/08/17
	$rDC->SetValue("MaxCluster", $OMaxCluster);
#print ", MaxCluster=$OMaxCluster<br>\n";
	$rDC->SetValue("UID", $Ouid);
  }

	$rDC->SetValue('DocType', 'doc'); # 'doc' or 'term' (clustering)
#	$value = $rDC->GetValue('DocType'); # get attribute's value if needed
	$rDC->SetValue('IndexBy', 'me'); # or by 'WG' or 'me' (this program)
	$rDC->SetValue('Save2File', 1); # default is 0
	# if you want to save the results to files for fast later re-use, 
	# set 'Save2File' to 1 (0 otherwise), and set the next 2 attributes.
	$rDC->SetValue('IndexName', $IndexName);
	$rDC->SetValue('IndexPath', $IndexPath); # needed if 'IndexBy' is 'me'
# Next lines must be the last to override the above 2 lines
	if ($Ogrp ne '') {
		$rDC->SetValue('DefaultGroup', $Ogrp);
	}
print STDERR "Ogrp=$Ogrp, ODB=$main::ODB\n" if $Odebug > 0;
	$rDC->SetAttributes_by_DefaultGroup();
  if (not $Out2File) { # output to files
#	$rDC->InitDBMS($Odsn);
#	$rDC->InitDBMS(); # DSN is set in Cluster.ini , 2005/08/17
	$rDC->InitDBMS('', $main::ODB); # 2010/05/08
  }

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

sub DeleteRecords {
	$rDC->DeleteDBMSRecords();
	print "Data has been deleted";
	exit;
}


# This function shows how to cluster the documents from the begining to the end.
sub FromDoc2CutTree {
# if 'IndexBy' is 'me' and not yet built the index, insert docs for later use
#   foreach $term (@Term) { $rDC->AddIndexTerm( $term );#if extra terms needed
	my($sot, $eot);
	$sot = time();
	if ($Osrc eq 'Dir') {
		$tfn = $rDC->InitDocSrc('Dir', $FileList);
	} else { # if ($Osrc eq 'DB')
#	$DSN = 'File'; $sql = "select ID from Src_Data order by ID";
		$DSN = $rDC->{DSN}; $sql = "select ID from $rDC->{Table} order by ID";
		$tfn = $rDC->InitDocSrc('DB', $DSN, $sql);
	}
	$sql = "select ID, SNo, Fname, Dname, Dscpt from $rDC->{Table} where ID = ?";
	$fi = 0; while (($DocPath, $title, $text) = $rDC->NextDoc($sql)) { 
		$fi++; last if $DocPath eq '';
#	for ($fi = 0; $fi < $tfn; $fi++) {
#		($DocPath, $title, $text) = $rDC->NextDoc($sql);
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
# Use option $Olow_tf, $Oct_low_tf
sub FromIndex2CutTree {
	$rDC->SetValue('Method', 'CompleteLink'); # 'SingleLink', 'Cluto', or 'SOM'
	$rDC->SetValue("low_df", $Olow_df); # do not use term whose df <= 1
	$rDC->SetValue("high_df", $Ohigh_df); # do not use term whose df >= 30000
	$rDC->SetValue("low_tf", $Olow_tf); # do not use those term whose tf in doc is<=0
	my $NumDoc = $rDC->ReadDocIndex() if $rDC->GetValue('Save2File');
#	$rDC->ReadSimilarity() if $rDC->GetValue('Save2File');
	my $root = $rDC->DocSimilarity();
	$rDC->SaveSimilarity() if $rDC->GetValue('Save2File');
	&FromSim2CutTree(); # Use option $Oct_low_tf
}

# If you have already saved the pairs with similarity sorted, 
# just read them back to compute another ways of clustering using different thresholds.
# Use option $Oct_low_tf
sub FromSim2CutTree {
	$rDC->ReadSimilarity() if $rDC->GetValue('Save2File');
	$rDC->CompleteLink();
	$rDC->SaveTree() if $rDC->GetValue('Save2File');
	&FromFile2CutTree(); # Use option $Oct_low_tf
}


# Given the clustered index and data in a directory, read these data back
#  use a given threshold, cut the single cluster into small clusters.
# Use option $Oct_low_tf, $Ocut, $ONumCatTitleTerms
sub FromFile2CutTree {
	$rDC->DeleteDBMSRecords(); # delete DBMS before inserting new records.
	$NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
#	$root = $rDC->ReadSimilarity(); # no longer needed for re-cluster
	$rDC->ReadTree();
# set the URL to show the full content of the inserted file (using its )
	$rDC->SetValue("ShowDoc", "http://localhost/cgi-ig/ShowDoc4.pl");
	$rDC->SetValue('NumCatTitleTerms', $ONumCatTitleTerms);
	$rDC->SetValue("ct_low_tf", $Oct_low_tf); # do not use term whose tf <= 1
	$rDC->SetValue('ClusterTitle', $Otfc); # 'TFC');
	$htmlstr = $rDC->CutTree($Ocut);
	return $htmlstr;
}
