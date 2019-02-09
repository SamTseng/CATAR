#!/usr/bin/perl -s
	use SamOpt qw(SamOpt);  &SamOpt();
	my $prog;
#	$prog = "parl CATAR.par "; 
	$prog = "perl -s ";

#	use strict; use vars;
#	my($Ocut, $Oold_cut, $Olow_tf, $Oct_low_tf, $Oold_ct_low_tf, $Ouid, $Odsn, $Otable);
	
# perl -s auto.pl -Ocut=0.1 -Oold_cut=0.0825 -Ouid=20 -Odsn=File -Otable=NSC_Seg_Abs6 -Oold_ct_low_tf=1 -Olow_tf=2 -Oct_low_tf=2 NSC_Seg_Abs6 NSC_DocCluster
	&main(@ARGV);

# Use options: -Ocut, -Olow_tf, -Oct_low_tf, -Otfc
sub main {
	my($OldIdxName, $NewIdxName) = @_;
	my($cmd, $option, $result);
	$option = "";
	if ($Ouid or $Odsn or $Otable) {
		if ($Ohtml) { # use option -Ohtml
# perl -s auto.pl -Ohtml=path_to_html -Odsn=DSN -Otable=Table OldIdxName NewIdxName
# 2007/11/17歸類結果（主題樹）在 HTML 檔案裡，而全文文件在資料庫裡
# perl -s tool.pl -Ohtml -Odir=..\doc\IEK1 IEK1 Patent ..\Result\IEK1\kr_t_0.01_doc.html
			$cmd = "$prog tool.pl -Ohtml -ODB=$main::ODB "
			 . "-Odir=../doc/$NewIdxName $Odsn $Otable $Ohtml";
		} else {
# Step 1. 
#  1.1 Cluster the documents in the DBMS:
#   D:\demo\File>perl -s ClusterDB.pl -Oall -Ouid=20 -Odebug=1 -Ogrp=NSC_Seg_Abs6 1
#	The number 1 in the argument is to let ClusterDB.pl to run in DOS mode, not in CGI mode.
#  1.1 Cut the tree and save in the DBMS
#   D:\demo\File>perl -s ClusterDB.pl -Ocut=0.0 -Ogrp=NSC_Term -Ouid=20 \
#	 -Oct_low_tf=1 -Olow_tf=1 -Odebug NSC_Term Result\NSC_Term 
			$option .= "-Otfc=$Otfc " if $Otfc ne '';
			$option .= "-Ocut=$Oold_cut " if $Oold_cut ne '';
			$option .= "-Oct_low_tf=$Oold_ct_low_tf " if $Oold_ct_low_tf ne '';
			$option .= "-ODB=$main::ODB " if $main::ODB ne '';
			$cmd = "$prog ClusterDB.pl -Ogrp=$OldIdxName -Ouid=$Ouid "
			 . "$option -Odebug $OldIdxName ../Result/$OldIdxName ";
			&myexec($cmd);
# 如果歸類的結果在 DBMS 中，而且文件也在 DBMS 中：
#  1.2 Then dump the clustered tree from DBMS into a directory 
#	  where each cluster is saved in a file, (consult table CTree 
#	  in File_NSC.mdb to know the UID=20), then run:
#   D:\demo\File>perl -s tool.pl -Odoc -Odir=doc/NSC_TermCluster -Ouid=20 \
#	 -Odsn=File -Otable=NSC_Term
			if (-d "../doc/$NewIdxName") { &DelAllFile("../doc/$NewIdxName"); }
			$cmd = "$prog tool.pl -Odoc -Odir=../doc/$NewIdxName -Ouid=$Ouid "
			 . "-Odsn=$Odsn -ODB=$main::ODB -Otable=$Otable";
		} # 2007/11/17
	} else {
# 如果歸類的結果在 Result\IndexName 中，而文件在 doc\ 中：
# 2006/10/22增加：如果歸類的結果在 Result\IndexName 中，而文件在 DBMS 中，則用 -Odsn 與 -Osql
# Step 1. create the documents in doc\
#   perl -s Cluster.pl -Odebug -ObigDoc -Ocut=0.0 NSC_TermCluster \
#	  Result\NSC_TermCluster doc\NSC_TermBigCluster 
#   perl -s Cluster.pl -Odebug -ObigDoc -Ocut=0.02 Gov_DocBigCluster \
#	  Result\Gov_DocBigCluster doc\Gov_DocBig2
		$option .= "-Otfc=$Otfc " if $Otfc ne '';
		$option .= "-Ocut=$Oold_cut " if $Oold_cut ne '';
		$option .= "-Oct_low_tf=$Oold_ct_low_tf " if $Oold_ct_low_tf ne '';
		$cmd = "$prog Cluster.pl -Odebug -ObigDoc $option $OldIdxName "
			 . "../Result/$OldIdxName ../doc/$NewIdxName";
	}
	&myexec($cmd);
	
# Step 2. Edit cluster.ini to add a new group [NSC_TermCluster]
# Step 2. Edit cluster.ini to add a new group [NSC_TermBigCluster]
# Step 2. Edit cluster.ini to add a new group [NSC_TermBig2]

# Step 3. create a file list:
#  perl -s d:\demo\ig\filelist4.pl doc/NSC_TermCluster.lst doc/NSC_TermCluster
#  perl -s d:\demo\ig\filelist4.pl doc/NSC_TermBigCluster.lst doc/NSC_TermBigCluster
#  perl -s d:\demo\ig\filelist4.pl doc/Gov_DocBig2.lst doc/Gov_DocBig2
	$cmd = "$prog filelist4.pl ../doc/$NewIdxName\.lst ../doc/$NewIdxName";
	&myexec($cmd);

# Step 4 Use the setting to compute the similarity of these 566 new documents:
#	$Olow_df	 = 2 if $Olow_df eq '';
#	$Olow_tf	 = 2 if $Olow_tf eq '';
#	$Oct_low_tf  = 2 if $Oct_low_tf eq '';
#	$Ocut	 = 0.0 if $Ocut eq '';
#	$ONumCatTitleTerms = 5 if $ONumCatTitleTerms eq '';
#	perl -s Cluster.pl -Oall -Odebug -Osrc=Dir NSC_TermCluster \
#		Result\NSC_TermCluster doc\NSC_TermCluster.lst \
#		> Result\NSC_TermCluster\2_2_2_0.0.html 
#	perl -s Cluster.pl -Oall -Odebug -Osrc=Dir NSC_TermBigCluster \
#		Result\NSC_TermBigCluster doc/NSC_TermBigCluster.lst \
#		> Result\NSC_TermBigCluster\2_4_4_0.0.htm
#	perl -s Cluster.pl -Oall -Odebug -Osrc=Dir Gov_DocBig2 \
#		Result\Gov_DocBig2 doc/Gov_DocBig2.lst 
	&CreateDir("../Result/$NewIdxName");
	$option = "";
	$option .= "-Otfc=$Otfc " if $Otfc ne '';
	$option .= "-Ocut=$Ocut " if $Ocut ne '';
	$option .= "-Olow_tf=$Olow_tf " if $Olow_tf ne '';
	$option .= "-Oct_low_tf=$Oct_low_tf " if $Oct_low_tf ne '';
	$option .= "-OEng_Seg_Phrase" if $OEng_Seg_Phrase ne '';
	$result = "2_". $Olow_tf ."_". $Oct_low_tf ."_". $Ocut .".html";
	$cmd = "$prog Cluster.pl -Oall $option -Odebug -Osrc=Dir $NewIdxName "
		. "../Result/$NewIdxName ../doc/$NewIdxName\.lst"
		. " > ../Result/$NewIdxName/$result";
	&myexec($cmd);

#  Step 5 to see the clustered results, run
#		Create a cluster tree by running:   
#	perl -s Cluster.pl -Ocut=0.0 -Odebug NSC_TermCluster \
#	  Result\NSC_TermCluster > Result\NSC_TermCluster\2_2_2_0.0.html   
#	perl -s Cluster.pl -Ocut=0.02 -Odebug Gov_DocBig2 \
#		Result\Gov_DocBig2 > Result\Gov_DocBig2\2_9_6_0.02.htm


#  Step 6 Now we have Result\Gov_DocCluster\*.*, use these file to create a map
#  Step 6. Create a 2-D map of the 8 big documents (clusters) by MDS:
#   perl -s Term_Trend.pl -Ocolor -Ocut=0.0 -Omap -Odebug Result/NSC_TermCluster
#   perl -s Term_Trend.pl -Ocolor -Ocut=0.0 -Omap -Odebug Result/NSC_TermBigCluster
#   perl -s Term_Trend.pl -Ocolor -Ocut=0.1 -Omap -Odebug Result/Gov_DocBig2
	$option = '';
	$option .= "-Oct_low_tf=$Oct_low_tf " if $Oct_low_tf;
	$cmd = "$prog Term_Trend.pl -Ocolor -Ocut=$Ocut $option -Omap -Odebug ";
	$cmd .= "../Result/$NewIdxName";
	myexec($cmd);
}

sub myexec {
	my($cmd) = @_;
	print STDERR "$cmd\n";
	system($cmd)==0 or die "'$cmd' failed: $?\n";
}

sub DelAllFile {
	my($dir) = @_;	my(@Files, $f, $i);
	@Files = glob("$dir/*.*");
print STDERR "Deleting all files in dir:'$dir'\n";
#print STDERR "\@Files=@Files\n";
	foreach $f (@Files) {
		next if $f !~ m#\.(htm|txt)l?$#i;
#		print STDERR "$f, ";
		unlink $f or die "Cannot delete file:'$f'";
		$i++;
	}
#	print STDERR "\n";
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
