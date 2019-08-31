#!/usr/bin/perl -s
# https://stackoverflow.com/questions/728597/how-can-my-perl-script-find-its-module-in-the-same-directory
use File::Basename;
use lib dirname (__FILE__);
	use SamOpt qw(SamOpt);  &SamOpt();
	use Spreadsheet::WriteExcel; 
	# see http://lena.franken.de/perl_hier/excel.html for more examples
	use Encode::TW; # this line must exist, despite we have the next line
	use Encode qw/encode decode from_to/;
	use Encode::Detect::Detector;
	use DBI ':sql_types';
	use InitDBH qw(InitDBH);

# 讀取歸類結果的HTML檔，插入文件的標題，以方便解讀此HTML檔
# perl -s tool.pl -Otitle ..\Result\NanoPaperTW_S3\2_1_1_0.0.html > ..\Result\NanoPaperTW_S3\2_1_1_0.0_titles.html
# perl -s tool.pl -Otitle -Odsn=SciC ..\Result\SciC_S3\2_1_1_0.0.html > ..\Result\SciC_S3\2_1_1_0.0_titles.html
	if ($main::Otitle) { &InsertTitle_to_Cluster_Results(@ARGV); exit; }

# 讀取歸類結果的HTML檔，插入文件的SC標題詞，以方便解讀此HTML檔
# perl -s tool.pl -OSC="SC" File_NanoPaperTW NanoPaperTW ..\Result\NanoPaperTW_BibCpl\0_0.0.html > ..\Result\NanoPaperTW_BibCpl\0_0.0_SC.html
# perl -s tool.pl -OSC="PY" File_NanoPaperTW NanoPaperTW ..\Result\NanoPaperTW_BibCpl\0_0.0.html > ..\Result\NanoPaperTW_BibCpl\0_0.0_SC.html
# perl -s tool.pl -OSC=all -Omin=2 -ODB=..\Source_Data\envi01\envi01.mdb 
#   envi01 TPaper ../Result/envi01_dc_S2/2_2_2_0.1.html > ../Result/envi01_dc_S2/2_2_2_0.1_all_2.html
	if ($main::OSC) { &InsertSC_to_Cluster_Results(@ARGV); exit; }

# 讀取歸類結果的HTML檔，插入文件的標題title與SC標題詞，以方便解讀此HTML檔 
#有上面的函數後，可以不再使用此函數
# perl -s tool.pl -OSC2 CorePaper TOTAL ..\Result\CorePaper_S3\2_1_1_0.05.html > ..\Result\CorePaper_S3\2_1_1_0.05_SC2.html
	if ($main::OSC2) { &Insert_SC_to_Another_Cluster_Results(@ARGV); exit; }

# 讀取歸類結果的HTML檔，以及不需要的類別編號，從HTML檔中刪除不需要的類別再輸出
# perl -s tool.pl -OrmC=..\Result\IEK_A\rmC.txt -Oid=..\Result\IEK_A\list.txt ..\Result\IEK_A\0.0.html > ..\Result\IEK_A\0.0_rmC.html
# perl -s tool.pl -OrmC=..\Result\IEK_A_S2\rmC.txt -Oid=..\Result\IEK_A_S2\list.txt ..\Result\IEK_A_S2\2_2_2_0.0.html > ..\Result\IEK_A_S2\2_2_2_0.0_rmC.html
	if ($main::OrmC) { &Remove_Designated_Clusters(@ARGV); exit; }
# 從歸類的結果檔案中，發現有些類別不需要進一步分析，可手動列舉刪除，然後再從頭進行上述各項步驟。刪除某些指定類別的範例命令如下：
# perl -s tool.pl -OrmC=..\Result\IEK_A\rmC.txt -Oid=..\Result\IEK_A\list.txt  ..\Result\IEK_A\0.0.html > ..\Result\IEK_A\0.0_rmC.html
# 其中選項-Oid=..\Result\IEK_A\list.txt，表示刪除後所剩的類別，其所包含的文件編號，表列在list.txt檔案裡，這個檔案可以方便從頭進行各項分析。而選項-OrmC=..\Result\IEK_A\rmC.txt，表示「待刪除的類別編號」所在的檔案，其內容為純文字，格式範例如下：
# 1
# 5
# 21-25
# 代表在..\Result\IEK_A\0.0.html檔案中，要被刪除的類別為編號1、5以及21到25的類別。「待刪除的類別編號」也可列舉在命令列上，如下的範例：
# D:\demo\STPIWG\src>perl -s tool.pl -OrmC=”1 5 21-25 30-60” -Oid=..\Result\IEK_A_S2\list.txt ..\Result\IEK_A_S2\2_2_2_0.0.html > ..\Result\IEK_A_S2\2_2_2_0.0_rmC.html
# 上一步做完，可做下一步：
# 讀取歸類結果的HTML檔，按照其類別內容，將類別的文件存到 doc 目錄下（每個類別一個檔），以便進行歸類
# perl -s tool.pl -Ohtml -Odir=..\doc\IEK1 IEK1 Patent ..\Result\IEK1\kr_t_0.01_doc.html
	if ($main::Ohtml) { &ExtractDoc2Dir(@ARGV); exit; }

# 將分散在各個資料表的專利資訊，插入到一個資料表中，使論文與專利的欄位交叉分析，可以用相同的程式
# 已過時，可不用，因為有新版的 &InsertSC_to_Cluster_Results();
# perl -s tool.pl -Ojoin -Odsn=IEK_A Tinfo
	if ($main::Ojoin) { &JoinInsert_to_PatentTable(@ARGV); exit; }

# 插入文件到資料表中，準備歸類
# D:\demo\File>perl -s tool.pl -Oroc d:\data\rocling\org
# On 2004/11/19 run :
# d:\demo\File>perl -s tool.pl -Oroc -Ontcir c:\NTCIR4_Patent\Data\007P.lst
# Before running the above command, create a table named ROC according to WG_RK
#  on 2005/06/07
# perl -s tool.pl -Oroc -Ocnt D:\Sam\papers\2005\IACIS\data\nano_seg_abs6
# delete * from CNT_Seg_Abs6;
# perl -s tool.pl -Oroc -Onsc -Otable=NSC_Seg_Abs6 d:\demo\lwp\NSC\NSC_Seg_Abs6
	if ($main::Oroc) { &InsertRocLingDoc(@ARGV); exit; }
# perl -s tool.pl -Ocib InfoBank D:\STPI\2008_Project\GCINFOBANK.txt
# This function does not work. I don't know why. #2008/06/18
	if ($main::Ocib) { &InsertInfoBankDoc(@ARGV); exit; }

# 從專利資料庫（從USPTO下載回來）中，每段取6句摘要放入File_org.mdb中，準備進行歸類
# perl -s tool.pl -OP2F NanoPatent File_NanoPatent
	if ($main::OP2F) { &Insert_into_File_from_Patent(@ARGV); exit; }
# perl -s tool.pl -OgetID ..\doc\NanoPat_S2
	if ($main::OgetID) { &GetClusterPatentID(@ARGV); exit; } # 雜項功能，特定情況需要

# Given the clustered documents, represented in the DBMS, fetch them out
# and save them in files under directory $Odir. ，準備進行檔案文件的歸類
# tool.pl -Odir=NSC_TermCluster -Ouid=174 -Odsn=File_NSC -Otable=NSC_Term
# Use global : $Odsn, $Ouid, $Odir, $Odoc, $Otable
	if ($main::Ouid and $main::Odir){ &GetClusteredDoc(@ARGV); exit; }


# 從已取得的關鍵詞和其關聯詞插入到資料表中，準備進行歸類
# perl -s tool.pl -OInRK [-Odsn=File] -Otable=NSC_Term NSC_WG_RK.txt
	if ($main::OInRK) { &InsertRKterms(@ARGV); exit; }  
# perl -s tool.pl -Orw -OmaxDF=200 -OminDF=2 NSC_WG_RKterms.txt > NSC_WG_RK.txt
	if ($main::Orw) { &FilterRKterms(@ARGV); exit; }
# perl -s tool.pl -Odic WG_RKterms.txt > DicTerm.txt
	if ($main::Odic) { &GetDicTerm(@ARGV); exit; } # 雜項功能，特定情況需要
# 從歸類的反向索引檔中，取出索引詞，依照篇數排序，選項-Ophrase表示只輸出多字詞片語
# perl -s tool.pl -Oinv ..\Result\NanoPaperTW\Inv.txt > ..\Result\NanoPaperTW\df.txt
# perl -s tool.pl -Oinv -Ophrase ..\Result\NanoPaperTW\Inv.txt > ..\Result\NanoPaperTW\df_phrase.txt
	if ($main::Oinv) { &SortInvertedFile(@ARGV); exit; } # 雜項功能，特定情況需要
# perl -s tool.pl -Ophrase D:\demo\File\Result\CNT_Seg_Abs6\Inv.txt > Result\CNT_Seg_Abs6_phrase.txt
	if ($main::Ophrase) { &GetPhrasefromIndex(@ARGV); exit; } # 雜項功能，特定情況需要


# Compute the distribution of selected IPC codes in some major clusters
# 612篇NSC專利歸成6大類後，每一大類的IPC分佈
# perl -s tool.pl -Oipc NSC_PatentDB doc\NSC_DocBigCluster Result\NSC_DocBigCluster\0.05_91_2_1_1_0.1_21_2_3_3_0.2.html > Result\NSC_6clusters_IPC_dist.txt
	if ($main::Oipc) { &IPC_DIST(@ARGV); exit; } 
	
# 612篇NSC專利歸成6大類後，每一大類的field分佈
# perl -s tool.pl -Ofield Result\NSC_Fields.txt doc\NSC_DocBigCluster Result\NSC_DocBigCluster\0.05_91_2_1_1_0.1_21_2_3_3_0.2.html > Result\NSC_6cluster_Field_dist.txt
	if ($main::Ofield) { &Field_DIST(@ARGV); exit; }
	
# 刪除612篇NSC專利某年代之外的論文，以便製作 topic map
# perl -s tool.pl -OrmPat NSC_PatentDB 1970 1999 doc\NSC_DocBigCluster doc\NSC_DBC2000
	if ($main::OrmPat) { &RemovePatents(@ARGV); exit; }

	exit;

sub ts { 
	my($x, $n) = @_;
	if ($x == int($x)) { return $x; }
	else { $n=1 if not $n; return sprintf("%0.".$n."f", $x); }
}


# ----------------- &GetClusteredDoc() -----------------
# 從資料庫中，將已歸類好的的文件，輸出到檔案系統中，準備進行歸類
#   在資料庫中，歸類好的資訊放在這幾個資料表： Catalog, CTree, Classify，
#	 而文件放在資料表 Seg_Abs6 或 TSeg (Paper_org.mdb) 中。
# 參見 File_org.mdb 或 Patent_org.mdb 或 Paper_org.mdb
# Use global : $Odsn, $Ouid, $Odir, $Odoc, $Otable
# Given the clustered documents, represented in the DBMS, fetch them out
# and save them in files under directory $Odir.
# perl -s tool.pl -Odir=NSC_TermCluster -Odsn=File -Ouid=174 -Otable=NSC_Term
sub GetClusteredDoc {
	my $DBH = &InitDBH($Odsn, $main::ODB);
	if (-d $main::Odir) { &DelAllFile($main::Odir, 'all'); }
	&CreateDir($main::Odir); 
	my($rRCIDs, $cid);
	$rRCIDs = &GetRootCID($DBH, $Ouid);
	foreach $cid (@$rRCIDs) {
		&DocList($DBH, $Ouid, $cid);	
	}
	$DBH->disconnect;
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

sub DelAllFile {
	my($dir, $all) = @_;	my(@Files, $f, $i);
	@Files = glob("$dir/*.*");
print STDERR "Deleting all existing files in dir:'$dir'\n";
#print STDERR "\@Files=@Files\n";
	foreach $f (@Files) {
		next if not $all and $f !~ m#\.(htm|txt)l?$#i;
#		print STDERR "$f, ";
		unlink $f or die "Cannot delete file:'$f'";
		$i++;
	}
#	print STDERR "\n";
	print STDERR "\nThere are ", scalar @Files, 
	  " old files, but only $i files are deleted\n" if $i<@Files;
}


# Given $UID, return all the root nodes' id for getting clustered documents
sub GetRootCID {
	my($DBH, $UID) = @_; my($cid, @RCIDs);
	my $sql = "SELECT CID FROM Catalog where CUID = ? and CPID = ?";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute($UID, -1)
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	while ($cid = $STH->fetchrow_array) {
		push @RCIDs, $cid;
	}
	$STH->finish;
	return \@RCIDs;
}


# Use global : $DBH
# Get Class Name by Class ID
sub CID2CName {
	my($DBH, $UID, $CID) = @_;
	my $sql = "SELECT CName FROM Catalog WHERE CUID = ? and CID = ?";
	my $STH = $DBH->prepare($sql)
				 or die "Can't prepare SQL statement: $DBI::errstr\n";
	$STH->execute($UID, $CID)
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	my ($CName) = $STH->fetchrow_array;
	my $encoding_name = Encode::Detect::Detector::detect($CName);
	if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#		$CName = encode("big5", $CName);
#	if ($encoding_name !~ /big5/i) { # if utf8-encoded
		from_to($CName, $encoding_name, 'big5'); 
	}	
	$STH->finish;
#print "CUID=$UID, CID=$CID, CName=$CName\n";
	return $CName;
}

# Given a CID, return all the CIDs who are the descendants of the given CID
sub ExpandCID {
	my($DBH, $UID, $CID) = @_; my($STH, $sql, @CIDs, $cid, @SubCIDs);
	$sql = "SELECT CID FROM Catalog WHERE CUID = ? AND CPID = ? order by CID";
	$STH = $DBH->prepare($sql)
		or die "Can't prepare SQL statement: $DBI::errstr\n";
	$STH->execute($UID, $CID)
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	while($cid = $STH->fetchrow_array) {
		push(@CIDs, $cid); # push document IDs into @NIDS
	}
	$STH->finish;
	foreach $cid (@CIDs) { 
		push @SubCIDs, &ExpandCID($DBH, $UID, $cid); 
	}
	return @CIDs, @SubCIDs;
}

sub DocList {
	my($DBH, $UID, $CID) = @_;
	my ($NID, @NIDS, $CName, $PID, $STH, $sql, @CIDs, $cid, $Size);
	$CName = &CID2CName($DBH, $UID, $CID); # Get Class Name
	if ($CName =~ /^(\d+)/) { $Size = $1; } else { $Size = 0; }
	@CIDs = ($CID, sort {$a <=> $b} &ExpandCID($DBH, $UID, $CID));
print STDERR "$CName, CID=$CID, CIDs=@CIDs<p>\n";

# Given $CID and $UID, Set @NIDS : list of record IDs
	foreach $cid (@CIDs) {
		$sql = "SELECT NID FROM Classify WHERE CTID = ? AND CID = ? order by NID";
		$STH = $DBH->prepare($sql)
			or die "Can't prepare SQL statement: $DBI::errstr\n";
		$STH->execute($UID, $cid);
		while($NID = $STH->fetchrow_array) {
			push(@NIDS, $NID); # push document IDs into @NIDS
		}
		$STH->finish;
	}
	my($Counts, $I, @D, $DocList, $j, $txt, $encoding_name);
	$Global_i ++;
	$DocList = "<title>$Global_i : $CName</title>\n";
	$Counts = @NIDS = sort @NIDS; $j=1;
	return if (scalar @NIDS) <= $OMinCluSize; # 2006/07/19
# Fetch each Record's Content, ID is pk for $Otable only
	$STH = $DBH->prepare("SELECT ID, Dscpt, FName, DName, SNo FROM $Otable WHERE ID = ?")
		 or die "Can't prepare SQL statement: $DBI::errstr\n";
	for($I = 0; $I < @NIDS; $I++) {
		$STH->execute($NIDS[$I]);
		@D = $STH->fetchrow_array;
		foreach $txt (@D) {
			$encoding_name = Encode::Detect::Detector::detect($txt);
			if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#				$txt = encode("big5", $txt);
#    	if ($encoding_name !~ /big5/i) { # if utf8-encoded
    		from_to($txt, $encoding_name, 'big5'); 
			}		
		}
		$D[4] =~ s/\s*$//; # SNo is the record's true primary key
		$D[3] =~ s/\n+//g;
		$D[1] =~ s/\n+//g;
#		$DocList .= "$D[3] : $D[4] : $D[1] . \n"; # title, $id, $content
		$DocList .= "$D[3]\t:\t$D[4]\t:\t$D[1] . \n"; # title, $id, $content
		if (($I+1) % 150000 == 0) {
			if ($main::Odoc) {
				&Save2File("$CID-$Size-$j.htm", $DocList);
			} else {
				&Save2File("NSC_TermCluster.txt", $DocList);
			}
			undef $DocList; $j++;
		}
	}
	$DocList .= "\n";
	if ($main::Odoc) {
		&Save2File("$CID-$Size-$j.htm", $DocList) if $DocList ne '';
	} else {
		&Save2File("NSC_TermCluster.txt", $DocList) if $DocList ne '';
	}
} # End of &DocList


# Use global $Odir
sub Save2File {
	my($file, $text) = @_;
	if ($main::Odoc) {
	open F, ">$main::Odir/$file" or die "Cannot write to file:'$main::Odir/$file', $!";
	} else {
	open F, ">>$main::Odir/$file" or die "Cannot write to file:'$main::Odir/$file', $!";
	}
	print F $text;
	close(F);
}
# ----------------- &GetClusteredDoc() -----------------

	use vars; use strict;

# ----------------- 插入文件到資料庫，準備進行歸類 ----------------------
# Before running this function, create a table named ROC in DBMS File
# according to table WG_RK
sub InsertRocLingDoc {
	my($dir) = @_;  my(@Files, $f, $t, $sno, $n); my($DBH, $sql, $STH);
	my($title, $body);
	$main::Oroc = 0 if $main::Ontcir or $main::Ocnt or $main::Onsc or $main::Olegal;
	$DBH = &InitDBH($main::Odsn, $main::ODB);
#	$sql = q{ INSERT INTO ROC (DName, Dscpt, Sno) values (?, ?, ?) };
  if ($main::Oroc) {
	$sql = q{ INSERT INTO ROC2 (DName, Dscpt, Sno) values (?, ?, ?) };
#  } elsif ($Ontcir) {
#	$sql = q{ INSERT INTO 007P (DName, Dscpt, Sno) values (?, ?, ?) };
#  } elsif ($Ocnt) {
#	$sql = q{ INSERT INTO CNT_Seg_Abs6 (DName, Dscpt, Sno) values (?, ?, ?) };
  } else { # $Onsc, use -Otable=NSC_Seg_Abs6
	$sql = qq{ INSERT INTO $main::Otable (DName, Dscpt, Sno) values (?, ?, ?) };
  }
# Note 'Desc' is an SQL reserved word. It must be in [] to avoid failure
	$STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
#	$STH->bind_param(2, $STH, DBI::SQL_LONGVARCHAR);  
print STDERR "dsn=$main::Odsn, sql=$sql\n";
=comment
	foreach (@{ $DBI::EXPORT_TAGS{sql_types} }) {
#	printf "%s=%d\n", $_, &{"DBI::$_"};
	print "$_\n";
	} exit;
=cut
  if ($main::Oroc or $main::Ocnt or $main::Onsc or $main::Olegal) {
	@Files = glob("$dir/*");
  } else {
	open F, $dir or die "cannot read file:'$dir'";
	@Files = <F>;	close(F);
  }
	foreach $f (@Files) {
		open F, $f or die "Cannot read file:'$f'";
		local $/; undef $/; $t = <F>; $/= "\n"; close(F);
	  if ($main::Oroc) {
		if ($f =~ m#(\d+)\.txt#) { $sno = $1; } else { $sno = 0; }
	  } else {
		if ($f =~ m#([^\\\/]+)\.htm#) { $sno = $1; } else { $sno = 0; }
		$sno = ++$n if $main::Olegal;
	  }
		($title, $body) = &InsertROC($t, $sno, $STH, $sql);
print STDERR "$sno: Sizes of title and body=", length($title), ", ", length($body), "\n" 
if $sno%10==1 or (length($title)<5 or length($body)<10);
	$STH->bind_param(1, $title);
	$STH->bind_param(2, $body, DBI::SQL_LONGVARCHAR);
	$STH->bind_param(3, $sno);
	$STH->execute($title, $body, $sno)
#	and print "sno=$sno, title=$title\n";
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
#$STH->finish; $DBH->disconnect; exit;
	$body =~ s/\n/ /g;
	print "$sno\t$sno\t\t$title\t$body\n";
	}
	$STH->finish;
	$DBH->disconnect;
}

sub InsertROC {
	my($text, $sno, $STH, $sql) = @_; my($title, $body);
#	my($title, $body) = split /\n\n/, $text; # for table 'ROC'
  if ($main::Oroc) {
	($title, $body) = split /\n\n/, $text, 2; # for table 'ROC2'
  } elsif ($main::Olegal) {
	if ($text=~m#<h4>(.+)</h4>#i) { $title = $1; $text = $'; }
	if ($text=~s#<[^>]+>#\n#g) { $body = $text; } # delete all html tags
  } else {
	if ($text=~m#<TITLE>(.+)</TITLE>#i) { $title = $1; $text = $'; }
	if ($text=~m#<body color=white>([^<]+)</body>#i) { $body = $1; }
	if ($text=~s#<h(\d)>[^<]+</h\1>##ig) { $body = $text; } # for CNT_Seg_Abs6
	if ($text=~s#<[^>]+>#\n#g) { $body = $text; } # delete all html tags
  }
	return ($title, $body);
}


#  Read parsed patents from tables in downloaded DB and then 
#	insert them into the Seg_Abs6 table in a version of File_org.mdb
sub Insert_into_File_from_Patent {
	my($dsn1, $dsn2) = @_;
	my($DBH1, $sql1, $STH1, $DBH, $sql, $STH);
# connect to the $dsn1 for reading
	$DBH1 = &InitDBH($dsn1, $main::ODB1);
	$sql1 = "SELECT TDescription.PatentNo, TypeNo, Title, Abstract FROM TDescription, "
		. "TPatentInfo where TDescription.PatentNo = TPatentInfo.PatentNo "
		. "order by TDescription.PatentNo, TypeNo";
	$STH1 = $DBH1->prepare($sql1)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH1->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";

# connect to the $dsn2 for writing
	$DBH = &InitDBH($dsn2, $main::ODB2);
#	$sql = qq{ INSERT INTO Seg_Abs6 (Sno, DName, Dscpt) values (?, ?, ?) }; # 2009/09/21
	$sql = qq{ INSERT INTO TSeg (Sno, DName, Dscpt) values (?, ?, ?) };
	$STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->bind_param(3, $STH, DBI::SQL_LONGVARCHAR); 

# Now read each row and insert the accumulated the patent into FileDB
	my($prev_pid, $pid, $Abstract, $Abs, $Title, $TypeNo, $n);
	$prev_pid = $pid; $Abstract = ""; $n = 0;
	while (($pid, $TypeNo, $Title, $Abs) = $STH1->fetchrow_array) {
		next if $TypeNo > 5; # 5: Features : DETAILED DESCRIPTION OF THE INVENTION
#print  "$pid, $TypeNo, ",substr($Title, 0, 20), ", ", length($Abs), ", ", substr($Abs, 0, 20),"\n";
	$n += length($Abs)+3;
	$Abs =~ s/<BR><BR>/\n/g;
	$Abstract .= $Abs . "\n\n";
		if ($TypeNo == 5) { # 5 : Features : DETAILED DESCRIPTION OF THE INVENTION
		$STH->execute($pid, $Title, $Abstract)
			or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
#print  "$pid, $n, ", length($Abstract),", $Title\n";
			$prev_pid = $pid; $Abstract = ""; $n = 0;
	}
	}
	$STH1->finish;
	$DBH1->disconnect;
	
	$STH->finish;
	$DBH->disconnect;
	exit;
}

# This function does not work. I don't know why.
sub InsertInfoBankDoc {
	my($dsn2, $file) = @_;  my($DBH, $sql, $STH);
	$DBH = &InitDBH($dsn2, $main::ODB2); # connect to the $dsn2 for writing
#	$sql = qq{ INSERT INTO TPaper2 (UT, TI, AB, PY, AU, SO) values (?, ?, ?, ?, ?, ?) };
	$sql = qq{ INSERT INTO TPaper2 (UT, TI) values (?, ?) };
	$STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
#	$STH->bind_param(3, $STH, DBI::SQL_LONGVARCHAR); 

# Now read each row and insert it into the table of a database
	@ARGV = ($file); my($UT, $TI, $AB, $PY, $AU, $SO, $MD, $i);
	$TI = <>; # read off the the first line
	while (<>) {
		chomp;
	($UT, $TI, $AB, $PY, $AU, $SO, $MD) = split /\t/, $_;
	$PY =~ s/ 00:00$//;
	if ($UT eq '') {
		print "$UT, $PY, $TI\n"; next;
	} else {
		$STH->execute($UT, $TI)
			or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
		print "'$STH::errstr'$UT, $PY, $TI\n"; last if $i++>=5;
#		print "sql=$sql\n"; last if $i++>=5;
	}
	}	
	$STH->finish;
	$DBH->disconnect;
	exit;
}


# Before running this function, create a table $Otable in the DBMS
# use $Odns and $Otable
sub InsertRKterms {
	my($file) = @_;	 my($t, $df, $rt);
	my $DBH = &InitDBH($main::Odsn, $main::ODB);
	my $sql = qq{ INSERT INTO $main::Otable (DName, Dscpt, Sno) values (?, ?, ?) };
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->bind_param(2, $STH, DBI::SQL_LONGVARCHAR);  
	while (<>) {
	chomp;
	($t, $df, $rt) = split /\t/, $_;
	$STH->execute($t, $rt, $df)
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	}
	$STH->finish;
	$DBH->disconnect;
	exit;
}
# ----------------- 插入文件到資料庫，準備進行歸類 --------------------

# ----------------- 雜項功能，特定情況需要 ----------------------------
# perl -s tool.pl -Orw -OmaxDF=200 -OminDF=2 NSC_WG_RKterms.txt > NSC_WG_RK.txt
sub FilterRKterms { # 雜項功能，特定情況需要
	my($id, $key, $df, $rt, %StopWord, %RT, @RT, $w);
	use SAMtool::Stopword;
	my $Stop = new Stopword->new();
	while (<>) {
		chomp; next if /^\s*$/;
		($id, $key, $df, $rt) = split / : /, $_;
		if ($df > $main::OmaxDF) { $StopWord{$key} = 1; next; }
		if ($df < $main::OminDF) { $StopWord{$key} = 1; next; }
		next if $rt eq ''; # if no related terms
# delete those terms which contain the stop words
	next if $Stop->IsESW($key);
	next if $Stop->IsESW(substr($key, 0, index($key, ' ')));
	next if $Stop->IsESW(substr($key, rindex($key, ' ')+1, length($key)));
		%RT = split /\t/, $rt; # only related terms are needed. Omit their DFs 
		undef @RT;
		foreach $w (keys %RT) { 
# delete those terms which contain the stop words
		next if $Stop->IsESW($w);
		next if $Stop->IsESW(substr($w, 0, index($w, ' ')));
		next if $Stop->IsESW(substr($w, rindex($w, ' ')+1, length($w)));
		push @RT, $w if not $StopWord{$w}; 
		}
		next if @RT == 0;
		print "$key\t$df\t", join(",", keys %RT), "\n";
	}
	exit;
}

# perl -s tool.pl -Odic WG_RKterms.txt > DicTerm.txt
# extract all the keywords in WG_RKterms.txt
sub GetDicTerm { # 雜項功能，特定情況需要
	my(%RT, $id, $key, $df, $rt, $i, @T);
	while (<>) {
		chomp; next if /^\s*$/;
		($id, $key, $df, $rt) = split / : /, $_;
		next if $rt eq '';
		$RT{$key} = $df;
		@T = split /\t/, $rt;
		for($i=0; $i<@T; $i+=2) { $RT{$T[$i]} = $T[$i+1]; }
	}
	foreach $key (sort {$RT{$b} <=> $RT{$a}} keys %RT) {
		print "$key\n";
	}
	exit;
}

# Given a directory that contains clustered documents, 
#   extract the cluster ID and their patent IDs.
sub GetClusterPatentID { # 雜項功能，特定情況需要
	my($InDir) = @_;
	my(@Files, $f, $ff, $fid, @Fid, @Segment, $ClusterID, $pid, $seg, $i);
	@Files = glob("$InDir/*.htm");  $i = 0;
print STDERR "Number of files:", scalar @Files, "\n";
# Print the format of output line. 
# Example of output:
#   6916371	7492 : 28筆 : 0.025857	12 : 6
# 其中：
#   6916371：專利號碼
#   7492：類別代號
#   28：類別篇數
#   0.025857：類別內文件之間的最小相似度
#   12：6：檔案名稱，不重要。
	print "DocID\tClusterID : ClusterDocNum : ClusterSim\tFileID : FileID2\n";
	foreach $f (@Files) {
		if ($f =~ m#([^\\\/]+)\.html?$#) { $ff = $1; }
	@Fid = split(/\-|\_/, $ff); 
	@Segment = split(/[\\\/]/, $Fid[0]); $Fid[0] = pop @Segment;
	$fid = join(" : ", @Fid[0..1]);
	open F, $f or die "Cannot read file:'$f', $!";
	local $/;  $/ = "\n. \n"; # new line separator
	@Segment = <F>; # get all the segment in one read
	if ($Segment[0] =~ /title\>([^(]+)\(/) { # "<title>4 : 6筆,0.02("
		$ClusterID = $1; 
	} 
#print STDERR "Number of segments:", scalar @Segment, "\n";
	foreach $seg (@Segment) {
		while ($seg =~ /: ((ISI:)?\d+) :/g) {
			$i++;
			print "$1\t$ClusterID\t$fid\n";
		}
	}
	close(F);
	}
}

# 從歸類的反向索引檔中，取出索引詞，依照篇數排序，選項-Ophrase表示只輸出多字詞片語
# tool.pl -Oinv ..\Result\PaperTW\Inv.txt > ..\Result\PaperTW\df.txt
# tool.pl -Oinv -Ophrase ..\Result\PaperTW\Inv.txt > ..\Result\PaperTW\df_phrase.txt
# Given an inverted file in the cluster index directory created by Cluster.pm,
#   output the indexed terms and their document frequencies (DF), sorted by DF
#   If option -Ophrase is used, output only those multi-word phrases
sub SortInvertedFile { # 雜項功能，特定情況需要
	my($InvFile) = @_;  my($t, $posting, $df, %Terms, @Terms, $i);
	@ARGV = ($InvFile);
	while (<>) {
		chomp; ($t, $posting) = split /\t/, $_;
#		next if $t =~ /^\s*$/g;
#		$i++; (next and print STDERR "i=$i, $_\n") if $t eq ' ';
# Replace the above line with the next line
		$i++; (print STDERR "i=$i, $_\n" and next) if $t eq ' ';
		next if ($main::Ophrase and ($t=~tr/ / /)==0); # skip single words if $Ophrase
		$df = ($posting =~ tr/,/,/) / 2;
		$Terms{$t} = $df;
	}
	@Terms = sort {$Terms{$b} <=> $Terms{$a}} keys %Terms;
	foreach $t (@Terms) {
		print "$t\t$Terms{$t}\n";
	}
}

# tool.pl -Ophrase Result\CNT_Seg_Abs6\Inv.txt > Result\CNT_Seg_Abs6_phrase.txt
sub GetPhrasefromIndex { # 雜項功能，特定情況需要
	my($file) = @_; my($term, $posting, $i, @DF, %DF, $df, %NT2T, $nt);
	open F, $file or die "Cannot read file:$file";
	$i=0;
	while (<F>) {
		chomp; next if /^\s*$|^#/g;
		($term, $posting) = split /\t/, $_;
		next if ($term !~ / /); # if not a phrase
	$df = ($posting =~ tr/,/,/)/2;
	$DF{$term} = $df;
	next if $df < 2; 
	$nt = ($term =~ tr/ / /)+1;
	$NT2T{$nt} ++;
	}
	close(F);
	@DF = sort { $DF{$b} <=> $DF{$a} } keys %DF;
	foreach $term (@DF) {
		$i++;	print "$i\t$DF{$term}\t$term\n";
	}
print "#--------------------------\n";
	foreach $i (sort {$b <=> $a} keys %NT2T) {
		print "$i\t$NT2T{$i}\n";
	}
}
# ----------------- 雜項功能，特定情況需要 ----------------------------


# ----------- NSC 美國專利歸類後，進行交叉統計時使用的功能 ------------
# Compute the distribution of selected IPC codes in some major clusters
=comment until next =cut
   Given the final 6 major clusters in the HTML file: 
	D:\demo\File\Result\NSC_DocBigCluster\0.05_91_2_1_1_0.1_21_2_3_3_0.2.html
	 and the directory that holds the 21 sub-clusters:
	 	D:\demo\File\doc\NSC_DocBigCluster
	 and the Table that records the IPCs of each patent,
   output the distributions of selected IPC codes for each 6 major clusters.
=cut
sub IPC_DIST {
	my($Odsn, $InDir, $HtmlFile) = @_;
# Step 1: read IPC codes for each patent from DBMS
	my $rIPC = &ReadIPC($Odsn);

# Step 2: read the HTML file to know which sub-cluster is in which major cluster
	my $rSub2Major = &ReadClustered_HTML($HtmlFile);

# Step 3 : read files in $InDir, know which major cluster they belong to,
#		  and get their patents numbers, lookup $rIPC to accumulate their
#		  occurrence frequency.
	my $rMajor2IPC = ReadCluster_Patents($InDir, $rSub2Major, $rIPC);

# Step 4.	 
#	my %SelectedIPC = ('A61'=>1, 'B01'=>1, 'B05'=>1, 'B22'=>1, 'C07'=>1, 
#		'C08'=>1, 'C12'=>1, 'F'=>1, 'G01'=>1, 'G02'=>1, 'G06'=>1, 
#		'H01L 021'=>1, 'H01L 029'=>1, 'H03'=>1, 'H04'=>1);
	my %SelectedIPC = (
'H01'=>	193	,'G02'=>	37	,'G11'=>	23	,'C22'=>	13,
'G01'=>	73	,'C23'=>	31	,'H05'=>	19	,'C25'=>	12,
'C07'=>	68	,'B01'=>	28	,'C04'=>	19	,'B32'=>	12,
'A61'=>	53	,'H04'=>	27	,'C09'=>	18	,'C30'=>	11,
'H03'=>	51	,'B05'=>	25	,'F16'=>	15	,'G03'=>	11,
'C08'=>	51	,'C01'=>	24	,'B29'=>	15,		
'G06'=>	39	,'C12'=>	24	,'B22'=>	14);		

	my @SelectedIPC = keys %SelectedIPC;
print STDERR "IPCs to count: ", join(", ", @SelectedIPC),"\n";
	my ($Major, $str, $k, @IPC, $ipc);
	foreach $k (keys %$rMajor2IPC) {
#		print "$k ==>> $rMajor2IPC->{$k}\n";
		@IPC = split /\t/, $rMajor2IPC->{$k};
		foreach $ipc (@IPC) {
#print  "$k ==>> $ipc\n";
			$str = substr($ipc, 0, 1);
			if ($SelectedIPC{$str}) { $Major->{$k}{$str}++; next; }
			$str = substr($ipc, 0, 3);
			if ($SelectedIPC{$str}) { $Major->{$k}{$str}++; next; }
			$str = substr($ipc, 0, 8);
			if ($SelectedIPC{$str}) { $Major->{$k}{$str}++; next; }
#			$Major->{$k}{'other'}++;
#			$Major->{$k}{substr($ipc, 0, 1)}++;
		}
	}
# Step 5. print out the result in 1-D format
	my(%Field, @Field);
	foreach $k (sort keys %{ $Major }) { # foreach $k (keys %Major2IPC) {
#		foreach $ipc (sort keys %{$Major->{$k}}) { # foreach $ipc (@SelectedIPC) {
		foreach $ipc (sort {$Major->{$k}{$b}<=>$Major->{$k}{$a}} keys %{$Major->{$k}}) { 
			print "$k, $ipc => $Major->{$k}{$ipc}\n" if $Major->{$k}{$ipc} > 0;
			$Field{$ipc} += $Major->{$k}{$ipc};
		}
#		print "$k, other => $Major->{$k}{'other'}\n" if $Major->{$k}{'other'}>0;
	}
# Step 6. print out the result in 2-D format	
	print "#---------- in 2-D format ------------\n";
	print "IPC\tCluster1\tCluster2\t...\tClusterN\tTotal\n";
	@Field = sort keys %Field; # redefine @Field
	my @Cluster = ();
	my ($i, $j, @Sum) = (0, 0);
	foreach $k (sort keys %{ $Major }) { 
		if ($k=~/^(\d+)/) { print "\t$1"; }
	} print "\n"; 
	foreach $ipc (@Field) {
		print "$ipc\t"; $i = 0;
	foreach $k (sort keys %{ $Major }) {
		$str = (($Major->{$k}{$ipc})?($Major->{$k}{$ipc}):0);
			print "$str\t";  $Cluster[$i++] += $str;
		}
		print "$Field{$ipc}\n"; $Cluster[$i] += $Field{$ipc};
	}
	print "Total\t", join("\t", @Cluster), "\n";
}
	

# return \%IPC for each patents
sub ReadIPC {
	my($Odsn) = @_;  my(%IPC, $pid, $pc);
	my $DBH = &InitDBH($Odsn, $main::ODB);
	my $sql = "SELECT PatentNo, PatentClass FROM TPatentClass where "
		. "CountryNo = 2";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	while (($pid, $pc) = $STH->fetchrow_array) { $IPC{ $pid } .= "$pc\t"; }
	$STH->finish;
	$DBH->disconnect;
#print STDERR join(", ", sort keys %Patents), "\n";
print STDERR "Number of Patents: ", scalar keys %IPC, "\n";
#foreach $pid (sort keys %IPC) { print "$pid : $IPC{$pid}\n"; $i++; last if $i==10; }
	return \%IPC;
}

sub ReadClustered_HTML {
	my($HtmlFile) = @_; my($seg, %Sub2Major, $k, $HTML, @Seg);
	open F, $HtmlFile or die "Cannot read file:'$HtmlFile'";
	undef $/; 
	$HTML = <F>; close(F); $/ = "\n"; # get all content in one read
	close(F);
  # now we have the informatoin in $HTML, parse it
	@Seg = split /\n<p>/i, $HTML;
	shift @Seg; # remove the first segment, it is useless
	foreach $seg (@Seg) {
		# get major cluster id
		if ($seg =~ /^(\d+\(\d+\))/) { $k = $1; } else {$k = ""; next;}
#print "$k\n";
		# get each sub-cluster id
		while ($seg =~ /html\'>\d+ : (\d+ : [^,]+),/g) {
		$Sub2Major{$1} = $k;
#print "$k => $1\n";
		}
	}
	return \%Sub2Major;
}

sub ReadCluster_Patents {
	my($InDir, $rSub2Major, $rIPC) = @_; my ($sk, %Major2IPC);
	my @Files = glob("$InDir/*.htm");
	foreach my $file (@Files) {
	open F, $file or die "Cannot read file:'$file'";
	undef $/; 
	my $HTML = <F>; close(F); $/ = "\n"; # get all content in one read
	close(F);
#	if (not $HTML =~ /<head><title>(\d+ : [^,]+),/) { 
	if (not $HTML =~ /<title>(\d+ : [^,]+),/) { 
		warn "There is a mismatch in sub-cluster title\n"; 
		next; 
	} else { $sk = $1; } # matched sub-cluster title
	# Now $Sub2Major{$sk} should be the id of major cluster
#print "$Sub2Major{$sk} ==> $sk\n";
	next if not $rSub2Major->{$sk};
	while ($HTML =~ / : (\d+) : /g) { # for each patent id in the file
#		$Major2IPC{$rSub2Major->{$sk}} .= $rIPC->{$1} . "\t";
		$Major2IPC{$rSub2Major->{$sk}} .= $rIPC->{$1}; # "\t" existed, see &ReadIPC()
	}
	}
	return \%Major2IPC;
}


# Compute the distribution of fields in some major clusters
=comment until next =cut
   Given the final 6 major clusters in the HTML file: 
	D:\demo\File\Result\NSC_DocBigCluster\0.05_91_2_1_1_0.1_21_2_3_3_0.2.html
	 and the directory that holds the 21 sub-clusters:
	 	D:\demo\File\doc\NSC_DocBigCluster
	 and the file that records the field of each patent,
   output the distributions of the fields for each 6 major clusters.
=cut
sub Field_DIST {
	my($file, $InDir, $HtmlFile) = @_;
# Step 1: read NSC Academic Division codes for each patent from a file
	my $rPid2Field = &ReadField($file);

# Step 2: read the HTML file to know which sub-cluster is in which major cluster
	my $rSub2Major = &ReadClustered_HTML($HtmlFile);

# Step 3 : read files in $InDir, know which major cluster they belong to,
#		  and get their patents numbers, lookup $rIPC to accumulate their
#		  occurrence frequency.
	my $rMajor2Field = ReadCluster_Patents($InDir, $rSub2Major, $rPid2Field);

# Step 4. For each major cluster and accumulate the occurrence for each field
	my ($Major, $str, $k, @Field, $f, $ipc);
	foreach $k (keys %$rMajor2Field) {
#		print "$k ==>> $rMajor2Field->{$k}\n";
		@Field = split /\t/, $rMajor2Field->{$k};
		foreach $f (@Field) {
			$Major->{$k}{$f}++;
#print "$k ==>> $f\n";
		}
	}
	my %Field = (); # clear fields
# Step 5: print out the result in 1-d format	
	my %FieldName2Code = (
	'微電工程'=>'Ele',	# 1 : 微電工程 : 168	  
	'化學工程'=>'Che',	# 2 : 化學工程 : 84	   
	'光電工程'=>'Opt',	# 3 : 光電工程 : 82	   
	'材料工程'=>'Mat',	# 4 : 材料工程 : 82	   
	'醫藥工程'=>'Med',	# 5 : 醫藥工程 : 61	   
	'機械工程'=>'Mec',	# 6 : 機械工程 : 42	   
	'生技食品'=>'Bio',	# 7 : 生技食品 : 33	   
	'資訊工程'=>'Inf',	# 8 : 資訊工程 : 20	   
	'通信工程'=>'Com',	# 9 : 通信工程 : 16	   
	'土木環境'=>'Civ',	# 10 : 土木環境 : 9	   
	'能源科技'=>'',	   # 11 : 能源科技 : 1	   
	'生產自動'=>''  # 12 : 生產自動化技術 : 1 
	);
	foreach $k (sort keys %{ $Major }) { # foreach $k (keys %Major2IPC) {
#		foreach $ipc (sort keys %{$Major->{$k}}) { # foreach $ipc (@SelectedIPC) {
		foreach $ipc (sort {$Major->{$k}{$b}<=>$Major->{$k}{$a}} keys %{$Major->{$k}}) { 
			if ($k=~/^(\d+)/) { $str = $1; } else { $str = $k; }
			print "$k\t$ipc\t$str\t$FieldName2Code{$ipc}\t$Major->{$k}{$ipc}\n" if $Major->{$k}{$ipc} > 0 and $FieldName2Code{$ipc};
			$Field{$ipc} += $Major->{$k}{$ipc};
		}
#		print "$k, other => $Major->{$k}{'other'}\n" if $Major->{$k}{'other'}>0;
	}
# Step 6: print out the result in 2-d format
	print "#---------- Field Distribution -------\n";
	@Field = sort {$Field{$b} <=> $Field{$a}} keys %Field; # redefine @Field
	foreach $ipc (@Field) {
		print "$ipc\t$FieldName2Code{$ipc}\t$Field{$ipc}\n";
	}
	print "#---------- in 2-D format ------------\n";
	print "\t"; foreach $k (sort keys %{ $Major }) { 
		if ($k=~/^(\d+)/) { print "\t$1"; }
	} print "\n";
	foreach $ipc (@Field) {
		$str = ($FieldName2Code{$ipc}?$FieldName2Code{$ipc}:""); print "$str\t";
	foreach $k (sort keys %{ $Major }) {
		$str = (($Major->{$k}{$ipc})?($Major->{$k}{$ipc}):0);
			print "$str\t";
		}
		print "$Field{$ipc}\n";
	}
}

sub ReadField {
	my($file) = @_;  my(%Field, %Pid2Field, $pid, $f, $i);
	my %Name = (
	'電子工程'=>'微電工程',
	'高分子'=>'材料工程', '金屬及陶瓷材料工程'=>'材料工程', 
	  '金屬及陶瓷材料'=>'材料工程', '能源材料'=>'材料工程', 
	'臨床醫學'=>'醫藥工程','醫學工程'=>'醫藥工程','藥學工程'=>'醫藥工程',
	'機械固力'=>'機械工程', 
	'食品科技'=>'生技食品','植物分子生物學'=>'生技食品','生物技術'=>'生技食品',
	'通訊工程'=>'通信工程',
	'環境工程'=>'土木環境', '土木工程'=>'土木環境',
	'生產自動化技術'=>'生產自動'
	);
	open F, $file or die "Cannot read file:'$file'";
	while (<F>) {
		chomp; next if /^#|^\s*$/g;
		($pid, $f) = split ' ', $_;
		next if $f eq '';
		$f = $Name{$f} if $Name{$f};
		$Field{$f} ++;
		$Pid2Field{$pid} .= "$f\t";
	}
	close(F);
#foreach $f (sort {$Field{$b}<=>$Field{$a}}keys %Field) { $i++; print "$i : $f : $Field{$f}\n";  }	
#$i=0;foreach $pid (sort keys %Pid2Field) { print "$pid : $Pid2Field{$pid}\n"; $i++; last if $i==10; }
#	exit;
	return \%Pid2Field;
}
# ----------- NSC 美國專利歸類後，進行交叉統計時使用的功能 ------------


# ------------------ &RemovePatents() --------------------------
# 刪除某年代範圍內的專利，準備進行逐年代範圍的歸類分析
# Given a DSN, a condition to select unwanted patents, 
#	an input folder containing the big documents (clustered doc.) such as
#	  those created by &FromFile2BigDoc()
#	and an output folder, 
#  Remove those patent documents in the files in the input folder
#	and then save the new files in the output folder
sub RemovePatents {
	my($DSN, $LowYear, $HighYear, $InDir, $OutDir) = @_;
# Step 1. select the unwanted patent ID
	my(%Patents, $pid);
	my $DBH = &InitDBH($DSN, $main::ODB);
	my $sql = "SELECT PatentNo FROM TPatentInfo where "
		. "Year(ApplyDate) < ? or Year(ApplyDate) > ?";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute($LowYear, $HighYear)
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	while ($pid = $STH->fetchrow_array) { $Patents{ $pid } = 1; }
	$STH->finish;
	$DBH->disconnect;
#print STDERR join(", ", sort keys %Patents), "\n";
print STDERR "Number of Patents to be removed:", scalar keys %Patents, "\n";
#exit;
# Step 2. Read back each file in input folder, remove those unwanted patent
#  and save them back to output folder
	&CreateDir($OutDir);
	my(@Files, $f, $of);
	@Files = glob("$InDir/*.htm");
print STDERR "Number of files:", scalar @Files, "\n";
#	print join("\n", @Files), "\n";
	foreach $f (@Files) {
		$of = $f;
		if ($f =~ /([^\/\\]+)$/) { $of = "$OutDir/$1"; }
		&RemovePat($f, $of, \%Patents);
	}
}

sub RemovePat {
	my($InFile, $OutFile, $rPatents) = @_;
	my($title, @Segment, $seg, $str, $n);
	open F, $InFile or die "Cannot read file:'$InFile', $!";
	open FF, ">$OutFile" or die "Cannot write to file:'$OutFile', $!";
	local $/;  $/ = "\n. \n"; # new line separator
	@Segment = <F>; # get all the segment in one read
#	if ($Segment[0] =~ /(<body>\n)/) { $title = $` . $1;, $Segment[0] = $'; }
	($title, $Segment[0]) = split /<body>\n/, $Segment[0];
	$n = 0;
	foreach $seg (@Segment) {
		if ($seg =~ /: (\d+) :/) { next if $rPatents->{$1}; }
		next if length($seg) < 30; # too short;
		$n++;
		$str .= $seg;
	}
#	$title =~ s/(\d+)筆/$n筆/;
	$title =~ s/(\d+) Docs./$n Docs./;
	print FF $title, "<body>\n" , $str;
	close(F);
	close(FF);
}
# ------------------ &RemovePatents() --------------------------




# ------------ 插入交叉分析資訊，到已歸類好的 HTML 檔案中 -------------
# 插入標題與標題關鍵詞到每個類別去
# Given an html file having cluster results,
#   output an html file with document titles and title keywords within each cluster
sub InsertTitle_to_Cluster_Results {
	my($file) = @_;  my($f, @Seg, $seg, @C, $c, $titles, $terms, $t, $tt);
	my($i, $cid, @Cid2Id_Num, $Id_Num_in_C, $Title_Existed, $DBH, $percent);
	my($TI, $PY, $TC, $TCsum, $segID, %Cid2TC, @Cid2Row, @Row, $did, @Did);

	my($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
		$rLinkValue, $rTitleSen);
	use SAMtool::SegWord;
	my $SegWord = SegWord->new( { 'WordDir'=>'SAM/word' } );
	$SegWord->Value('WantRT', 0); # no related terms, no abstract

	$DBH = &InitDBH($main::Odsn, $main::ODB) if $main::Odsn;
	open F, $file or die "Cannot read file:'$file'";
	undef $/; $f = <F>;  $/ = "\n"; close(F); # to get all the content in one read

	@C = split /<p>/, $f;
	use SAMtool::Progress;
	$i = 0; my $Progress = Progress->new({'OUT'=>*STDERR{IO},'Format'=>'line'});
	$cid = 0;
  foreach $c (@C) {
	$i++; $percent = $Progress->ShowProgress($i/@C, $percent);
	if ($i == 1) { print $c . '<p>';  next; } # 1st segment has no cluster
	if ($i == 2) { print $c;  next; } # 2nd segment has no cluster
	
	print "<p>"; # print out the split element for the remaining clusers
# Get the cluster id. Format: "1(6):<UL>"
	if ($c =~ /(\d+)\(\d+\):<UL>/i) { $cid = $1; } 
	else { die "Cannot match cid:'", substr($c, 0, 20), "'\n"; }
# Get the number of items in the cluster
	if ($c =~ m|<li>([^<]+) : <|)  # match first "<li>374 : 220筆 : <font"
	{ $Id_Num_in_C = $1; } else { $Id_Num_in_C = ""; }
	$Cid2Id_Num[$cid] = $Id_Num_in_C;
	# $Id_Num_in_C is in the format: "374 : 220筆". It is used with $cid
	$TCsum = 0; # total TC in cluster $c
	@Row = (); # total title list in cluster $c

	@Seg = split /<\/a>/, $c;
	foreach $seg (@Seg) {
		@Did = ();
		if ($seg =~ /html'>\d+ : (\d+) : (\d+) Docs/) # e.g. =html'>12 : 200 : 2 Docs. : 
		{ $segID = "$1 : $2 Docs."; } else { $segID = ''; }
		
		if ($seg !~ /html'>\d+ : ([\w:\d]+) : \d+ Docs./) { # 'for UntraEdit
# The document ID and title are already in the HTML file
#			while ($seg =~ /ShowDoc4.pl\?f=(.+)&st=html/g) { # ShowDoc4.pl?f=ISI:000227515100012&st=html
			while ($seg =~ /html'>\d+ : ([\w:\d]+) :/g) { # html'>650 : ISI:000189386300009 :
				push @Did, $1; 
				$Title_Existed = 1;
			}
		} else {
# The document ID needs further to be read from a file in the following URL
# http://localhost/demo/STPIWG/src/ShowDoc.pl?f=..\doc\EdCore_BibCpl_S2/121_4.htm&st=html
#warn "seg2=$seg\n";
			while ($seg =~ /pl\?f=(\S+)&st=html/g) { # for each item containing a file
#warn "match file: '$1'\n";
				open FF, $1 or warn "Cannot read file:'$1'\n"; # open the file
				while (<FF>) { # read in the file content, line by line
#					if (/ : ([\w:\d]+) : /) { # match doc ID in " : ISI:A1994PX83700011 : "
					if (/\t:\t([\w:\d]+)\t:\t/) { # match doc ID in " : ISI:A1994PX83700011 : "
						push @Did, $1;
					}
				}
				close(FF);
			}
			$Title_Existed = 0;
		}
		if (@Did == 0) {  print $seg; next;	}
=comment until =cut # 2010/11/06
	# match each URL, read the file in that URL, and insert the content of the file
		#ShowDoc4.pl?f=..\doc\CorePaper_S2\1324894-11-1.htm&st=html
		if ($seg =~ /ShowDoc4?.pl\?f=(.+)&st=html/) { 
			$titles = &GetTitles($1, $DBH);
			($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
				$rLinkValue, $rTitleSen) = $SegWord->ExtractKeyPhrase( $titles );
		} else { $titles = ""; }
		next if $titles eq '';
=cut
		$titles = $tt = '';
		foreach $did (@Did) {
			($PY, $TC, $TI) = &GetPY_TC_TI($did, $DBH); 
			$TCsum += $TC; # total TC in this cluster $c
			$tt .= $TI . ' . '; # for extracting keywords in this segment $seg
			$titles .= "<li> $did : $PY : $TI\n";
			push @Row, join("\t",$cid, $Id_Num_in_C, $segID, $did, $PY, $TC, $TI);
		}
		($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
				$rLinkValue, $rTitleSen) = $SegWord->ExtractKeyPhrase( $tt );
		$terms = '';
		foreach $t (@$rWL) {  # 2006/06/16
			$tt = $t; $tt =~ s/ (\W)/$1/g; # delete space before Chinese char.
			$terms .= "<li>$tt : $rFL->{$t}\n"; 
		}
		print $seg.'</a>' and next if $Title_Existed; # skip 
		print $seg, "</a>\n<table><tr><td valign=top width=80%><ol>\n$titles</ol>\n",
			"<td valign=top width=20%><ol>\n$terms</ol></table>";
	} # foreach $seg (@Seg) {
	$Cid2TC{$cid} = $TCsum;
	$Cid2Row[$cid] = join "\n", @Row;
  } # foreach $c (@C) {
	$DBH->disconnect if $DBH;
	$percent = $Progress->ShowProgress($i/@C, $percent);
	&PrintOutCid2Row($main::Otitle, \%Cid2TC, \@Cid2Row);
}

sub GetTitles {
	my($file, $DBH) = @_;  my($f, $titles, $title, $did, $r, $b, $py);
	$b = 'B';
	open F, $file or die "Cannot read file:'$file'";
	while (<F>) {
		if (/<body>/i) { $f = 1; next; } # begin to match
#		next if not $f;
		if (/<title>/) { 
			$_=~s/<(\/?)title>/<$1$b>/g; 
#			$titles .= '<br>' . $_ . "<br>\n"; # comment on 2006/10/20
			next; 
		}
#		next if not / : /;
#		($title, $did, $r) = split / : /, $_; # title : ISI:000089093200014 : content
		next if not /\t:\t/;
		($title, $did, $r) = split /\t:\t/, $_; # title : ISI:000089093200014 : content
#print STDERR "did=$did, title=$title, r=$r\n";
		next if $did =~ /[,\.;\(\# ]/;
#		next if $did =~ /\d+\s*[a-zA-Z]+\s*\d+/;
#		next if length($r) < 20 or length($title) < 5 or length($did)<6 or length($did)>25; # not a valid line
#		next if length($title) < 5 or length($did)<6 or length($did)>25; # not a valid line
#		next if length($title) < 5 or length($did)<1 or length($did)>25; # not a valid line
		$py = &GetPY($did, $DBH) if $DBH;
		if ($py) {
			$titles .= "<li> " .$did . ' : ' . $py .' : '. $title . "\n"; 
		} else {
			$titles .= "<li> " .$did . ' : ' . $title . "\n"; 
		}
	}
	close(F);
#exit;
	return $titles;
}

sub GetPY {
	my($did, $DBH) = @_; my($sql, $STH, $py, $year, $month, $day);
	if ($main::OTable eq 'Patent') { # 2009/07/21
		$sql = "SELECT IssuedDate FROM TPatentInfo WHERE PatentNo = ?";
	} else {
		$sql = "SELECT PY FROM TPaper where UT = ?";
	}
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($did) or die "Can't execute SQL=$sql, $STH::errstr\n";
	($py) = $STH->fetchrow_array;
	($year, $month, $day) = split(/[\- ]/, $py); # format: "1982-10-12 00:00:00"
	return $year;
}

sub GetPY_TC_TI {
	my($did, $DBH) = @_; my($sql, $STH, $PY, $year, $month, $day, $TC, $TI);
	$sql = "SELECT PY, TC, TI FROM TPaper where UT = ?";
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($did) or die "Can't execute SQL=$sql, $STH::errstr\n";
	($PY, $TC, $TI) = $STH->fetchrow_array;
	my $encoding_name = Encode::Detect::Detector::detect($TI);
	if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#		$TI = encode("big5", $TI);
#	if ($encoding_name !~ /big5/i) { # if utf8-encoded
		from_to($TI, $encoding_name, 'big5'); 
	}
	($year, $month, $day) = split(/[\- ]/, $PY); # format: "1982-10-12 00:00:00"
	return ($year, $TC, $TI);
}

sub PrintOutCid2Row {
	my($XlsF, $rCid2TC, $rCid2Row) = @_; my(@Cid, $cid, $i, $j, $v, @Row, @Col);
	my($Book, $Sheet, $r, $encoding_name);
	if (-e $XlsF) { unlink($XlsF); }
	$Book = Spreadsheet::WriteExcel->new($XlsF);
	$Sheet = $Book->add_worksheet('list');
	@Col = split ' ', qq(TCsum Cno Cid SubCid UT PY TC TI);
	for($j=0; $j<@Col; $j++) {
		$Sheet->write(0, $j, $Col[$j]);
	}
	@Cid = sort {$rCid2TC->{$b} <=> $rCid2TC->{$a}} keys %$rCid2TC;
	($i, $j) = (1, 0);
	foreach $cid (@Cid) {
		@Row = split /\n/, $rCid2Row->[$cid];
		foreach $r (@Row) {
			$Sheet->write($i, 0, $rCid2TC->{$cid});
			@Col = split /\t/, $r;
			for($j=0; $j<@Col; $j++) {
				$encoding_name = Encode::Detect::Detector::detect($Col[$j]);
				if ($encoding_name !~ /UTF-8/i) { # if not utf8-encoded
					$v = decode("big5", $Col[$j]); # from big5 to utf-8
#				if ($encoding_name !~ /big5/i) { # if utf8-encoded
#					$v = $Col[$j];
#					from_to($v, 'big5', $encoding_name); 
				} else { $v = $Col[$j]; }
				#$v = decode("big5", $Col[$j]); # This work! on 2010/12/03
				# When the texts are read from an html file, decode them to big5
				$Sheet->write($i, $j+1, $v);
			}
			$i++;
		}
	}
	$Book->close();
}

#-------------- obsolete after &InsertSC_to_Cluster_Results() ------------
# Given an html file having cluster results,
#   output an html file with document titles and SC (or PY) occurrence within each cluster
sub Insert_SC_to_Another_Cluster_Results {
	my($DSN, $table, $file) = @_;  my($f, @Seg, $seg, $titles, $SC, $t, $field);
	if ($main::OSC2 eq 'PY') { $field = 'PY'; } else { $field = 'SC'; }
	my $DBH = &InitDBH($DSN, $main::ODB);
#	my $sql = "SELECT SC FROM $table where UT = ?";
	my $sql = "SELECT $field FROM $table where UT = ?";
	my $STH = $DBH->prepare($sql)
	or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	open F, $file or die "Cannot read file:'$file'";
	undef $/; $f = <F>;  $/ = "\n"; close(F); # to get all the content in one read
	@Seg = split /<\/a>/, $f;
	foreach $seg (@Seg) {
# match each URL, read the file in that URL, and insert the content of the file
	if ($seg =~ /ShowDoc4.pl\?f=(.+)&st=html/) {
		($titles, $SC) = &GetTitles_SC($1, $STH, $sql);
	} else { $titles = ""; }
	next if $titles eq '';
	print $seg, "</a>\n<table><tr><td valign=top width=80%><ol>$titles</ol>\n",
		"<td valign=top width=20%><ol>$SC</ol></table>";
	}
	$DBH->disconnect;
}

sub GetTitles_SC {
	my($file, $STH, $sql) = @_;  my($f, $titles, $title, $did, $r, $bf, $SC);
	$bf = 'B';  my(@SC, %SC, $encoding_name); 
	open F, $file or die "Cannot read file:'$file'";
	while (<F>) {
		if (/<body>/i) { $f = 1; next; } # begin to match
#		next if not $f;
		if (/<title>/) { 
			$_=~s/<(\/?)title>/<$1$bf>/g; 
			$titles .= '<br>' . $_ . "<br>\n"; 
			next; 
		}
#		($title, $did, $r) = split / : /, $_;
		($title, $did, $r) = split /\t:\t/, $_;
#		next if length($title) < 5 or length($did)<2; # not a valid line
		$titles .= "<li> " .$did . ' : ' . $title . "\n"; 
		$STH->execute($did)
			or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
		($SC) = $STH->fetchrow_array;
		$encoding_name = Encode::Detect::Detector::detect($SC);
		if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#			$SC = encode("big5", $SC);
#		if ($encoding_name !~ /big5/i) { # if utf8-encoded
			from_to($SC, $encoding_name, 'big5'); 
		}
		@SC = split /;\s*/, $SC;
		foreach $SC (@SC) { $SC{$SC}++; }
	}
	close(F);
	$SC = '';
	foreach $r (sort {$SC{$b} <=> $SC{$a}} keys %SC) {
		$SC .= "<li>$r : $SC{$r}\n"; 
	}	
	return ($titles, $SC);
}
#-------------- obsolete after &InsertSC_to_Cluster_Results() ------------


# Given an html file having cluster results,
#   output an html file with SC occurrence inserted within each cluster
# perl -s tool.pl -OSC CorePaper TOTAL ..\Result\CorePaper_CoC\0_0.0.htm > ..\Result\CorePaper_CoC\0_0.0_SC.htm
# 針對得出的類別，印出每個類別的引用文獻分佈狀況，執行：
# perl -s tool.pl -OSC=CR -Omin=2 EdCore TPaper ..\Result\EdCore_BibCpl\0_0.01.html > ..\Result\EdCore_BibCpl\0_0.01_CR.html
# perl -s tool.pl -OSC=IssuedDate [-Omonth] IEK_A Patent ..\Result\IEK_A_S2\2_2_2_0.2.html > ..\Result\IEK_A_S2\2_2_2_0.2_Inventor.html
# 2009/01/23 加入選項 -Country=TAIWAN，以便單獨統計 TAIWAN 的OSC=all的各項資料
sub InsertSC_to_Cluster_Results {
	my($DSN, $table, $file) = @_;  
	my($f, @Seg, $seg, $i, $j, $percent, $SC, $rSC, @SC, $field, $max, @F);
	my($DBH, $STH, $sql, $str, @Field, @Did, $line, $SCt, $FD, $cid, %PY, $TCsum);
	my($Id_Num_in_C); # the cluster id and number of items in the cluster
	my(@Cid2Id_Num, $total, @HHI, $slope);
#	if ($main::OSC eq 'PY') { $field = 'PY'; } else { $field = 'SC'; }
	$field = $main::OSC; # 2007/08/08 
	$DBH = &InitDBH($DSN, $main::ODB);
	if ($field eq 'all') {
		if ($table eq 'Patent') {
			@Field = split ' ', # Title, ApplyDate are not included
				qq{IssuedDate Inventor Assignee Country PC Citation};
		} else {
#			@Field=split ' ',qq{PY AU CR C1 SO SC}; 
		# IN is a reserved word in MS Access, so it needs to be []ed
			@Field=split ' ',qq{PY AU AF DP IU C1 SO SC CR TC}; # 2009/01/30,2010/11/06,2015/12/13
			@Field=split ' ',qq{PY AU AF C1 IU MC CC DS MI} if $main::OBioAbs; #2010/03/21
		}
	} else { @Field = split ' ', $field; }

	open F, $file or die "Cannot read file:'$file'";
	undef $/; $f = <F>;  $/ = "\n"; close(F); # to get all the content in one read
	@Seg = split /<p>/, $f;
	use SAMtool::Progress;
	$i = 0; my $Progress = Progress->new({'OUT'=>*STDERR{IO},'Format'=>'line'});
	$cid = 0;
foreach $seg (@Seg) {
	$i++; $percent = $Progress->ShowProgress($i/@Seg, $percent);
	if ($i == 1) { print $seg .'<p>';  next; } # 1st segment has no cluster

# match each URL, read the file in that URL, and insert the content of the file
	@Did = ();
# The next if statement is added on 2007/08/08
#	if ($seg !~ /html'>\d+ : ([\w:\d]+) : \d+筆/) {
	if ($seg !~ /html'>\d+ : ([\w:\d]+) : \d+ Docs./) { #'
#warn "seg1=>\$1=$1\n";
# The document ID is already in the HTML file
#		while ($seg =~ /ShowDoc4.pl\?f=(.+)&st=html/g) { # ShowDoc4.pl?f=ISI:000227515100012&st=html
		while ($seg =~ /html'>\d+ : ([\w:\d]+) :/g) { # html'>650 : ISI:000189386300009 :
			push @Did, $1;
		}
	} else {
# The document ID needs further to be read from a file in the following URL
# http://localhost/demo/STPIWG/src/ShowDoc.pl?f=..\doc\EdCore_BibCpl_S2/121_4.htm&st=html
#warn "seg2=$seg\n";
		while ($seg =~ /pl\?f=(\S+)&st=html/g) { # for each item containing a file
#warn "match file: '$1'\n";
			open FF, $1 or warn "Cannot read file:'$1'\n"; # open the file
			while (<FF>) { # read in the file content, line by line
#				if (/ : ([\w:\d]+) : /) { # match doc ID in " : ISI:A1994PX83700011 : "
				if (/\t:\t([\w:\d]+)\t:\t/) { # match doc ID in " : ISI:A1994PX83700011 : "
					push @Did, $1;
				}
			}
			close(FF);
		}
	}

# Now we have @Did, print out the keys and values of %SC in a succinct way
	if (@Did == 0) { 
		print $seg; next if $seg =~ m|</html>|;  print '<p>'; next; 
	} # otherwise, we have something to be printed out

# Get the cluster id. Format: "1(6):<UL>"
	if ($seg =~ /(\d+)\(\d+\):<UL>/i) { $cid = $1; } # $cid is "1" in the above example
	else { die "Cannot match cid:'", substr($seg, 0, 20), "'\n"; }

# Get the number of items in the cluster
	if ($seg =~ m|<li>([^<]+) : <|)  # match first "<li>374 : 220筆 : <font"
	{ $Id_Num_in_C = $1; } else { $Id_Num_in_C = ""; }
	$Cid2Id_Num[$cid] = $Id_Num_in_C;
	# $Id_Num_in_C is in the format: "374 : 220筆". It is used with $cid

	# insert HTML table tab into cluster head :. e.g. "<p>181(3):<UL>"
	$seg =~ s/:<UL>/:<table border=1><tr><td valign=top><UL>/; 
	$str = ''; $line = ($seg =~ tr/\n/\n/ + 1); # maximum of information lines
	$TCsum = 0;
	foreach $field (@Field) {
		$rSC = &GetInfoByDid(\@Did, $DBH, $table, $field);
#print "i=$i, $field, Did=", @Did[0..9], join("\n", map{"$_:$rSC->{$_}"}keys%$rSC), " SC_End\n";
		$SC = ''; $SCt = '';
		if ($field eq 'PY' or $field eq 'IssuedDate' or $field eq 'ApplyDate'
			or $field eq 'TC') { # 2010/11/06
			foreach $f (sort {$a <=> $b} keys %$rSC) {
				$SC .= "<br>$f:$rSC->{$f}\n"; # sort year ascendently
				$SCt .= "$f\t$rSC->{$f}\n";
				$PY{$f} += $rSC->{$f}; # to know all possible years
				$TCsum += $rSC->{$f} if $field eq 'TC';
			}
			if ($field eq 'TC') {
				$SC .= "<br>TC_sum:$TCsum\n";
				$SCt .= "TC_sum\t$TCsum\n"; 
			}
			if ($field eq 'PY') {
				my @PY = sort {$a <=> $b} keys %PY; # must use all years
				my @PYvalue = (); # since some clusters do not have full years
				# foreach my $f (@PY) { push @PYvalue, $rSC->{$f}; }
			# The above line is replaced by the next line on 2019/08/26
				foreach my $f ($PY[0]..$PY[-1]) { push @PYvalue, $rSC->{$f}; }
#print STDERR "\n", join(', ', @PYvalue),"\n"; # important for debugging
				$slope = &Compute_Slope(\@PYvalue);
				$SC .= "<br>Slope:$slope\n";
				$SCt .= "Slope\t$slope\n"; 				
			}
		} else { # print only enough information
			$max = 0; $j = 0; $total = 0; @HHI = ();
			if ($field =~ /C1|CJ|SC|SO|IU|DP/) { # 2012/01/19
				$SC .= "<li>_Total_ : \$Total\n<li>_HHI_ : \$HHI\n<li>_1/HHI_ : \$HHIi\n";
				$SCt .= "_Total_\t\$Total\n_HHI_\t\$HHI\n_1/HHI_\t\$HHIi\n";
			}
			# When $field =~ /AF|AU|C1|IU/, need to compute additional TC and CPP
#			foreach $f (sort {$rSC->{$b} <=> $rSC->{$a}} keys %$rSC) {
#				$total += $rSC->{$f}; push @HHI, $rSC->{$f}; # 2011/04/14
			foreach $f (sort {&f($rSC->{$b}) <=> &f($rSC->{$a})} keys %$rSC) {
				my $df = &f($rSC->{$f});
				$total += $df; push @HHI, $df; # 2011/04/14
				$SC .= "<li>$f : $rSC->{$f}\n";
				$SCt .= "$f\t$rSC->{$f}\n";
#				$SC .= "<li>$f : ". &ts($rSC->{$f})."\n"; # 2009/02/11
#				$SCt .= "$f\t".&ts($rSC->{$f})."\n"; # 2009/02/11
				last if $j++ > $line and not $main::Otxt;
				last if $j >= $main::Otxt and defined $main::Otxt;
				$max = $df if $max < $df;
				last if (($max > $main::Omin and $df <= $main::Omin) 
					or ($max <= $main::Omin and $df < $max)); # 2007/08/08
#				$max = $rSC->{$f} if $max < $rSC->{$f};
#				last if (($max > $main::Omin and $rSC->{$f} <= $main::Omin) 
#					or ($max <= $main::Omin and $rSC->{$f} < $max)); # 2007/08/08
			}
			if ($field =~ /C1|CJ|SC|SO|IU|DP/) {
				my($hhi, $hhii) = &Compute_HHI($total, \@HHI);
				$hhi = &ts($hhi, 2); $hhii = &ts($hhii, 2);
				$SC =~ s/\$Total/$total/; 	$SCt =~ s/\$Total/$total/;
				$SC =~ s/\$HHI/$hhi/;		$SCt =~ s/\$HHI/$hhi/;
				$SC =~ s/\$HHIi/$hhii/;		$SCt =~ s/\$HHIi/$hhii/;
			}
		} # end of if ($field
		my $ff = $field; $ff =~ s/[\[\]]//g;
		$str .= "<td valign=top>$ff<ol>\n$SC</ol></td>\n";
		$FD->{$field}[$cid] = $SCt;
	} # End of foreach $field
	if ($main::Otxt) {
#		print "$strt\n\n";
	} else {
		if ($seg =~ m|<br></body></html>|) { # the last cluster
			$seg =~ s|<br></body></html>|$str</tr></table>\n\n<br></body></html>|;
			print $seg;
		} else { # not the last cluster
			print $seg . "$str</tr></table>\n\n<p>";
		}
	}
} # foreach $seg (@Seg) {
	$DBH->disconnect;
	if ($main::Otxt) { &PrintOutFields($FD, \%PY, \@Cid2Id_Num); }
	$percent = $Progress->ShowProgress($i/@Seg, $percent);
}

# get the first element of a string: "4 : 15" or "4 : 15 : 3.75"
sub f {my($a) = @_; my @A = split(' : ', $a); return $A[0];}

# Given a set of Dids and a field, return the accumulated information for that field
# When $field =~ /AF|AU|C1|IU/, need to compute additional TC and CPP
sub GetInfoByDid {
	my($rDid, $DBH, $table, $field) = @_;
	my($sql, $STH, $did, $SC, @SC, %SC, %TC, @TC);
	my($year, $month, $day, $n, $PY, $encoding_name);
# Prepare the SQL statement
	if ($table eq 'Patent') { # do nothing, delay to &GetPatentInfo()
	} else {
		if ($main::Country) { # on 2009/01/23
#			$sql = "SELECT $field FROM $table where UT = ? and C1 = ?";
			$sql = "SELECT $field FROM $table where UT = ? and C1 like ?";
		} else {
			$sql = "SELECT $field FROM $table where UT = ?";
		}
		$sql =~ s/ FROM/, PY FROM/ if $field eq 'TC'; # 2010/11/06
		$sql =~ s/ FROM/, TC FROM/ if $field =~ /AF|AU|C1|IU|DP/; # 2019/08/26
		$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	}
# Execute the SQL statement and save the result in @SC
	foreach $did (@$rDid) {
		if ($table eq 'Patent') {
			push @SC, &GetPatentInfo($DBH, $did, $field);
		} else {
			if ($main::Country) {
#				$STH->execute($did, $main::Country) or die "Can't execute SQL=$sql, $STH::errstr\n";
				$STH->execute($did, '%'.$main::Country.'%') or die "Can't execute SQL=$sql, $STH::errstr\n";
	  		} else {
				$STH->execute($did) or die "Can't execute SQL=$sql, $STH::errstr\n";
			}
			($SC, $PY) = $STH->fetchrow_array; # 2010/11/06
			chomp $SC; # 2012/01/19
			$encoding_name = Encode::Detect::Detector::detect($SC);
			if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
				from_to($SC, $encoding_name, 'big5'); 
			}
			if ($field eq 'TC') {
				$PY = &Normalize_PY($PY);
				$SC{$PY} += $SC; # accumulate TC for each year
			} else {
				@TC = (split /;\s*/, $SC);
				push @SC, @TC;
				if ($field =~ /AF|AU|C1|IU|DP/) { 
#warn("did=$did, field=$field, TC(PY)=$PY, \$SC=$SC, \@SC=" . join(';; ', @SC));
					foreach my $sc (@TC) { # ucfirst lc (each element in @SC)
						$TC{$sc} += $PY; # $PY is content of TC
					}
#warn(join("; ", map{"$_:$TC{$_}"} sort keys %TC));
				}
			}
		}
	}
	# $n = scalar @SC; # number of items in the field, 2009/02/11
	foreach my $sc (@SC) { 
		$sc = &Normalize_PY($sc) if ($field eq 'PY');
		$SC{$sc}++; 
#	$SC{$SC}+=1/$n; # 2009/02/11
	}
	if ($field =~ /AF|AU|C1|IU|DP/) { # modify the value of %SC
		for my $sc (keys %SC) { # change value "NC" into "NC : TC : CPP"
			if ($SC{$sc} == 0) {
warn("field=$field, SC=$SC, PY=$PY, SC{$sc}=$SC{$sc}");
				$SC{$sc} = "0 : $TC{$sc} : 0"
			} else {
				$SC{$sc} = $SC{$sc}.' : '.$TC{$sc}.' : '.&ts($TC{$sc}/$SC{$sc}, 2);
			}
		}
	}
	return \%SC;
}

sub Normalize_PY {
	my($SC) = @_;
	my($year, $month, $day) = split(/[\- ]/, $SC); # format: "1982-10-12 00:00:00"
	if ($main::Oday) { $SC = $year.sprintf("%02d", $month).sprintf("%02d", $day); } 
	elsif ($main::Omonth) { $SC = $year.sprintf("%02d", $month); }
	else { $SC = $year; }
	return $SC;
}

sub Compute_Slope {
	my($rA) = @_; my($i, @X, @Y, $avg, $sq, $sx, $slope, @A);
	@A = @$rA;
	while (@A>=1 and $A[0] <= 0) { shift @A; } # 2011/05/24
	return 0.0 if @A <= 1; # skip if less than 2 numbers
	for($i=1, $avg = 0; $i<=@A; $i++) { $avg += $i; }
	$avg = $avg / (scalar @A);
	for($i=0; $i<@A; $i++) { $X[$i] = $i+1 - $avg; }

	for($i=0, $avg = 0; $i<@A; $i++) { $avg += $A[$i]; }
	$avg = $avg / (scalar @A);
	for($i=0; $i<@A; $i++) { $Y[$i] = $A[$i] - $avg; }

	for($i=0, $sq = 0; $i<@A; $i++) { $sq += $X[$i]*$X[$i]; }
	for($i=0, $sx = 0; $i<@A; $i++) { $sx += $X[$i]*$Y[$i]; }
	return &ts($sx/$sq, 2);	
}

# compute Herfindahl-Hirschman Index, see http://en.wikipedia.org/wiki/Herfindahl_index
sub Compute_HHI { 
	my($n, $rA) = @_; my($i, $sum);
	for($i=0; $i<$n; $i++) { $sum += ($rA->[$i]/$n)**2; }
	return ($sum, ($sum>0)?1/$sum:0);
}

# Use options: Oday, Omonth if OSC=IssuedDate or OSC=ApplyDate is used
sub GetPatentInfo {
	my($DBH, $id, $field) = @_;
	my($STH, $sql, %Country, $CountryNo, $CountryName, $year, $month, $day);
	my($Title, $IssuedDate, $ApplyDate, $PC);
	my($Owner, $OwnerType, @Inventor, @Assignee, @PC, @Country, @Citation);
	my ($SC, %SC, @F, $f, $j);
# Get all CountryNo to CountryName
	$sql = qq{ select CountryNo, CountryName from TCountry };
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute() or die "Can't execute SQL=$sql, $STH::errstr\n";
	while (($CountryNo, $CountryName) = $STH->fetchrow_array) {
		$Country{$CountryNo} = $CountryName;
	}
	
# Fetch Title and IssuedDate and ApplyDate
	if ($field eq 'Title' or $field eq 'IssuedDate' or $field eq 'ApplyDate') {
	$sql = qq{ select Title, IssuedDate, ApplyDate from TPatentInfo where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	($Title, $IssuedDate, $ApplyDate) = $STH->fetchrow_array 
		or die "Can't run fetchrow_array statement: SQL=$sql, $STH::errstr\n";
		($year, $month, $day) = split(/[\- ]/, $IssuedDate); # format: "1982-10-12 00:00:00"
		if ($main::Oday) { $IssuedDate = $year.sprintf("%02d", $month).sprintf("%02d", $day); } 
		elsif ($main::Omonth) { $IssuedDate = $year.sprintf("%02d", $month); }
		else { $IssuedDate = $year; }
		($year, $month, $day) = split(/[\- ]/, $ApplyDate); # format: "1982-10-12 00:00:00"
		if ($main::Oday) { $ApplyDate = $year.sprintf("%02d", $month).sprintf("%02d", $day); } 
		elsif ($main::Omonth) { $ApplyDate = $year.sprintf("%02d", $month); }
		else { $ApplyDate = $year; }
	return $Title if $field eq 'Title';
	return $IssuedDate if $field eq 'IssuedDate';
	return $ApplyDate if $field eq 'ApplyDate';
	}
# Fetch Inventor, Assignee, Country
	if ($field eq 'Inventor' or $field eq 'Assignee' or $field eq 'Country') {
	$sql = qq{ select Owner, OwnerType, CountryNo from TOwner where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	while (($Owner, $OwnerType, $CountryNo) = $STH->fetchrow_array) {
		$Owner =~ s/^,\s*//; # delete leading comma and space
		if ($OwnerType == 1) { push @Inventor, $Owner; } 
		else { push @Assignee, $Owner; push @Country, $Country{$CountryNo}; }
	}
	return @Inventor if $field eq 'Inventor';
	return @Assignee if $field eq 'Assignee';
	return @Country if $field eq 'Country';
	}
# Fetch TPatentClass
	if ($field eq 'PC') {
	$sql = qq{ select PatentClass from TPatentClass where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	while ($PC = $STH->fetchrow_array) {
		$PC =~ s/ \(.*$//; # delete parentheses like : "H01L 21/762 (20060101)"
		push (@PC, $PC) if ($PC ne '');
	}
   	foreach $SC (@PC) { # accumulate for larger categories
		@F = split /[\/\. ]/, $SC; # delimited by '/' or '.', or ' '
		# format: "438/404" or "148/DIG.150" or "H01L 21/762"
		for ($j=$#F-1; $j>=0; $j--) { # match from right to left
			$f = substr($SC, 0, rindex($SC, $F[$j]) + length( $F[$j] ) );
		$SC{$f . '*'} = 1 if $f ne '' and $f ne $SC;
		} 
   	}
   	@F = keys %SC; push @PC, @F if @F>0;
	return @PC;
	}
# Fetch TPatentClass
	if ($field eq 'Citation') {
	$sql = qq{ select CitePatentNo from TCitePatent where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	while ($PC = $STH->fetchrow_array) {
		push @Citation, $PC;
	}
	return @Citation;
	}
}

# Print out each field's values for each cluster to generate reports
sub PrintOutFields {
	my($FD, $rPY, $rCid2Id_Num) = @_; my($au, $yr, $jl, $r, $df, %CA, %CJ);
	my($c, $F, $f, $i, @Mt, $maxi, @ar, @arCA, @arCJ, @MtCA, @MtCJ, $mca, $mcj);
	foreach $F (sort keys %$FD) { # for each field
		undef @Mt; undef @MtCA; undef @MtCJ; $maxi = $mca = $mcj = 0;
		for ($c=1; $c<@{$FD->{$F}}; $c++) { # for each cluster
			@ar = split /\n/, $FD->{$F}[$c]; # get the item set in @ar
#print STDERR "$F, c=$c, \@ar=", join(', ', @ar),"\n" if ($F eq 'PY' or $F eq 'TC');
			if ($F eq 'PY' or $F eq 'TC') { 
				@ar = sort {$a<=>$b} keys %$rPY; 
				push @ar, ($F eq 'PY')?'Slope':'TC_sum';
			}
#print STDERR "$F, c=$c, \@ar=", join(', ', @ar),"\n" if ($F eq 'PY' or $F eq 'TC');
			undef %CA; undef %CJ;
			for($i=0; $i<@ar; $i++) { # for each item (row)
				if ($F eq 'PY' or $F eq 'TC') { # put the item in a matrix for each $c
					if ($FD->{$F}[$c]=~/$ar[$i]\t([\d\.]+)\n/) # 2011/04/09
						{ $Mt[$i][$c] = $1; } else { $Mt[$i][$c] = 0; } # remove year
				} else { 
					$Mt[$i][$c] = $ar[$i];
					if ($F eq 'CR') {
						($r, $df) = split /\t/, $ar[$i];
						($au, $yr, $jl, $r) = split /,\s*/, $r;
						$CA{$au} += $df; $CJ{$jl} += $df;
					}
				} 
			}
			$maxi = @ar if $maxi < @ar; # to know the maximum rows
			if ($F eq 'CR') {
				@arCA = sort {$CA{$b} <=> $CA{$a}} keys %CA;
				$mca = @arCA if $mca < @arCA;
				$FD->{'CA'}[$c] = join("\n", map{$arCA[$i]."\t".$CA{$arCA[$i]}} @arCA);
				for($i=0; $i<@arCA; $i++) { $MtCA[$i][$c] = $arCA[$i]."\t".$CA{$arCA[$i]}; }
				@arCJ = sort {$CJ{$b} <=> $CJ{$a}} keys %CJ;
				$mcj = @arCJ if $mcj < @arCJ;
				$FD->{'CJ'}[$c] = join("\n", map{$arCA[$i]."\t".$CA{$arCA[$i]}} @arCA);
				for($i=0; $i<@arCJ; $i++) { $MtCJ[$i][$c] = $arCJ[$i]."\t".$CJ{$arCJ[$i]}; }
			}
		}
		&PrintOutField($FD, $rPY, $rCid2Id_Num, $F, $maxi, \@ar, \@Mt);
		if ($F eq 'CR') {
			&PrintOutField($FD, $rPY, $rCid2Id_Num, 'CA', $mca, \@arCA, \@MtCA);
			&PrintOutField($FD, $rPY, $rCid2Id_Num, 'CJ', $mcj, \@arCJ, \@MtCJ);
		}
	}
}

sub PrintOutField {
	my($FD, $rPY, $rCid2Id_Num, $F, $maxi, $rar, $rMt) = @_;  my($c, $i);
	print "\nField: $F\n"; # print the field name
	print "\t" if $F eq 'PY' or $F eq 'TC';
	for ($c=1; $c<@{$FD->{$F}}; $c++) { # for each cluster
		print "Cluster $c\t"; print "\t" if $F ne 'PY' and $F ne 'TC';
	} print "\n"; 

	print "\t" if $F eq 'PY' or $F eq 'TC';
	for ($c=1; $c<@{$FD->{$F}}; $c++) { # for each cluster
		print "$rCid2Id_Num->[$c]\t"; print "\t" if $F ne 'PY' and $F ne 'TC';
	} print "\n"; 

	for ($i=0; $i<$maxi; $i++) { # for each item (row)
#		print "$ar[$i]\t" if $F eq 'PY';
		print "$rar->[$i]\t" if $F eq 'PY' or $F eq 'TC';
		for ($c=1; $c<@{$FD->{$F}}; $c++) { # for each cluster
##			print "Cluster:$c\t";
#			print $Mt[$i][$c], "\t";
#			print "\t" if $Mt[$i][$c] eq '';
			print $rMt->[$i][$c], "\t";
			print "\t" if $rMt->[$i][$c] eq '';
		}
		print "\n";
	}
}


# -------------- 有了 &GetPatentInfo() 之後，底下兩個函數不需要用了 ------------
# 將分散在各個資料表的專利資訊，插入到一個資料表中，使論文與專利的分析，可以用相同的程式
# 在論文資料庫中，進行主題與欄位的交叉分析，會用到這些欄位：
#   AU TI SO DE ID AB C1 CR NR TC PY SC UT
# 在專利資料庫中，我們做如下的欄位對應（括號中為資料表名稱）：
#   UT=PatentNo		(TPatentInfo)
#   AU=Inventor	(TOwner.OwnerType=1)
#   SO=Assignee		(TOwner.OwnerType=2)
#   TI=Title		(TPatentInfo)
#   PY=IssuedDate	(TPatentInfo)
#   CR=CitePatentNo	(TCitePatent)
#   C1=AssigneeCountry	(TOwner.OwnerType=2 and TOwner.CountryNo and TCountry.CountryName)
#   SC=PatentClass(PC)	(TPatentClass)
# perl -s tool.pl -Ojoin -Odsn=IEK_A Tinfo
sub JoinInsert_to_PatentTable {
	my($Table) = @_;	my($dsn, $DBH, $STHin, $STH, $sql, $sqlin, $id, @ID);
	my($CountryNo, $CountryName, %Country, $i);
	my($Title, $IssuedDate, $Inventor, $Assignee, $PC, $Country, $Citation);
	$dsn = $main::Odsn;
	$DBH = &InitDBH($dsn, $main::ODB);
#	$sql = q{ INSERT INTO Seg_Abs6 (DName, Dscpt, Sno) values (?, ?, ?) };
	$sqlin = qq{ INSERT INTO $Table (UT, Title, IssuedDate, Inventor, Assignee,
		PC, Country, Citation) values (?, ?, ?, ?, ?, ?, ?, ?) };
	$STHin = $DBH->prepare($sqlin) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
#	$STHin->bind_param(3, $STHin, DBI::SQL_LONGVARCHAR); 

# First, delete all the existing records to avoid dupliates
	$sql = qq{ delete * from $Table };
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute() or die "Can't execute SQL=$sql, $STH::errstr\n";

# Get all the patent numbers
	$sql = qq{ select PatentNo from TPatentInfo };
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute() or die "Can't execute SQL=$sql, $STH::errstr\n";
	while ($id = $STH->fetchrow_array) {
		push @ID, $id;
	}

# Get all CountryNo to CountryName
	$sql = qq{ select CountryNo, CountryName from TCountry };
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute() or die "Can't execute SQL=$sql, $STH::errstr\n";
	while (($CountryNo, $CountryName) = $STH->fetchrow_array) {
		$Country{$CountryNo} = $CountryName;
	}

# Now foreach patent id, fetch their information to insert into $Table
	foreach $id (@ID) {
	($Title, $IssuedDate, $Inventor, $Assignee, $PC, $Country, $Citation)
		= &Fetch_Patent_Information($DBH, $id, \%Country);
	$STHin->execute($id, $Title, $IssuedDate, $Inventor, $Assignee, $PC, $Country, $Citation)
		   or die "Can't run SQL statement: SQL=$sqlin, $STH::errstr\n";
warn join("\n",($id, $Title, $IssuedDate, $Inventor, $Assignee, $PC, $Country, $Citation)), "\n\n"; exit if $i++==3;
	}
	$STH->finish;
	$STHin->finish;
	$DBH->disconnect;
}

#   AU=Inventor		(TOwner.OwnerType=1)
#   SO=Assignee		(TOwner.OwnerType=2)
#   TI=Title		(TPatentInfo)
#   PY=IssuedDate	(TPatentInfo)
#   CR=CitePatentNo	(TCitePatent)
#   C1=AssigneeCountry	(TOwner.OwnerType=2 and TOwner.CountryNo and TCountry.CountryName)
#   SC=PatentClass(PC)	(TPatentClass)
sub Fetch_Patent_Information {
	my($DBH, $id, $rCountry) = @_;  my($STH, $sql);
	my($Title, $IssuedDate, $Inventor, $Assignee, $PC, $Country, $Citation);
	my($Owner, $OwnerType, $CountryNo, @Inventor, @Assignee, @PC, @Country, @Citation);
	
# Fetch Title and IssuedDate
	$sql = qq{ select Title, IssuedDate from TPatentInfo where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	($Title, $IssuedDate) = $STH->fetchrow_array 
	or die "Can't run fetchrow_array statement: SQL=$sql, $STH::errstr\n";

# Fetch Inventor, Assignee, Country
	$sql = qq{ select Owner, OwnerType, CountryNo from TOwner where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	while (($Owner, $OwnerType, $CountryNo) = $STH->fetchrow_array) {
	$Owner =~ s/^,\s*//; # delete leading comma and space
		if ($OwnerType == 1) { push @Inventor, $Owner; } 
		else { push @Assignee, $Owner; push @Country, $rCountry->{$CountryNo}; }
	}
# Fetch TPatentClass
	$sql = qq{ select PatentClass from TPatentClass where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	while ($PC = $STH->fetchrow_array) {
		push @PC, $PC;
	}
# Fetch TPatentClass
	$sql = qq{ select CitePatentNo from TCitePatent where PatentNo = ?};
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	$STH->execute($id) or die "Can't execute SQL=$sql, $STH::errstr\n";
	while ($PC = $STH->fetchrow_array) {
		push @Citation, $PC;
	}
	$STH->finish;

# ($Title, $IssuedDate, $Inventor, $Assignee, $PC, $Country, $Citation)
	return ($Title, $IssuedDate, join('; ', @Inventor), join('; ', @Assignee), 
		join('; ', @PC), join('; ', @Country), join('; ', @Citation) );
}
# ------------ 插入交叉分析資訊，到已歸類好的 HTML 檔案中 -------------


# 從歸類結果檔案中，刪除指定的類別，並輸出剩餘類別的文件編號
# perl -s tool.pl -OrmC=rmc.txt -Oid=list.txt ..\Result\esi\0.0.html > ..\Result\esi\0.0_rm.html
#   Note : option OrmC can also be a list of cluster IDs to be removed, like these:
#	  -OrmC="1 10 20-30 35" : remove cluster 1, 10, 20 through 30, and 35
#   Note: single quotes like -OrmC='1 10 20-30 35' won't work. You must use double quotes.
sub Remove_Designated_Clusters {
	my($HtmlFile) = @_; 
	if ($main::Oid) {
		open Out, ">$main::Oid" or die "Cannot write to file:'$main::Oid'";
	}
  # Read the cluster IDs to be removed
	my($File, %Cluster, $c, $i, $j, $k, @C);
	$File = $main::OrmC;
	if (-s $File) { # cluster IDs are in the file
		open F, $File or die "Cannot read file:'$File'";
		@C = <F>; close(F); chomp @C;
	} else { # in the format: -OrmC="1 10 20-30 35"
		@C = split ' ', $File;
	}
	foreach $c (@C) {
		$c =~ s/^\s*|\s*//g; # delete leading and trailing white spaces
		($i, $j) = split /\s*\-\s*/, $c; # split by '-', i.e., we allow '3-6'
		$Cluster{$i} = 1 if $i ne '';
		$Cluster{$j} = 1 if $j ne '';
		for ($k=$i+1; $k<$j; $k++) { $Cluster{$k} = 1; }
	}
	close(F);
warn "\nCluster IDs to be removed=@C=>", join(', ', sort {$a<=>$b}keys%Cluster),"\n";
	
  # Read HTML file
	my($seg, $HTML, @Seg, @Segment, $percent, $cno, $rID);
	open F, $HtmlFile or die "Cannot read file:'$HtmlFile'";
	undef $/; $HTML = <F>; close(F); $/ = "\n"; # get all content in one read
	close(F);
  # now we have the informatoin in $HTML, parse it
	@Seg = split /<p>/i, $HTML;
	use SAMtool::Progress;
	$i = 0; my $Progress = Progress->new({'OUT'=>*STDERR{IO},'Format'=>'line'});
	foreach $seg (@Seg) {
		$i++; $percent = $Progress->ShowProgress($i/@Seg, $percent);
		if ($i <= 2) { # first two segments have no clusters
			if ($i==2) {
				print "\nRemoved Cluster IDs are: ", 
				join(", ", sort {$a<=>$b} keys %Cluster), "<br>\n";
				print "The document IDs in the remaining clusters are listed in $main::Oid<br><br>\n"
				if $main::Oid ne '';
			}
			print $seg . '<p>'; 
			next;
		}
		if ($seg =~ /(\d+)\(\d+\):<UL>/) { # format of cluster ID: '1(62):<UL>'
			$cno = $1; next if $Cluster{$1};
		}
		push @Segment, $seg; # print $seg; print "<p>" if $i < @Seg; # 2011/04/19
		next if not $main::Oid; # skip if no need to output the remaining document ids
    	$rID = &GetDocID_from_Segment($seg, $rID); # accumulate the IDs in $rID
	}
	print join("<p>", @Segment);
	print "<br></body></html>\n" if $Cluster{$cno} and $i==@Seg; # if last segment is to be omitted
	if ($main::Oid) {
		print Out join("\n", sort keys %$rID), "\n";
		close(Out);  
	}
	$percent = $Progress->ShowProgress($i/@Seg, $percent);
}

sub GetDocID_from_Segment {
	my($seg, $rID) = @_;
#		if ($seg !~ /html'>\d+ : ([\w:\d]+) : \d+筆/) { 
		if ($seg !~ /html'>\d+ : ([\w:\d]+) : \d+ Docs./) { 
		# The format is: '1116 : 6096648 : title' or '101 : ISI:000241617500013 : 2006:Title'
#warn "seg1=>\$1=$1\n";
# The document ID is already in the HTML file
#			while ($seg =~ /ShowDoc4.pl\?f=(.+)&st=html/g) { # ShowDoc4.pl?f=ISI:000227515100012&st=html
			while ($seg =~ /html'>\d+ : ([\w:\d]+) :/g) { # "html'>650 : ISI:000189386300009 :"
				$rID->{$1}++; # accumulate the document Ids in %ID
			}
		} else {
# The document ID needs further to be read from a file in the following URL
# http://localhost/demo/STPIWG/src/ShowDoc.pl?f=..\doc\EdCore_BibCpl_S2/121_4.htm&st=html
#warn "seg2=$seg\n";
			while ($seg =~ /pl\?f=(\S+)&st=html/g) { # for each item containing a file
#warn "match file: '$1'\n";
				open FF, $1 or warn "Cannot read file:'$1'\n"; # open the file
				while (<FF>) { # read in the file content, line by line
#					if (/ : ([\w:\d]+) : /) { # match doc ID in " : ISI:A1994PX83700011 : "
					if (/\t:\t([\w:\d]+)\t:\t/) { # match doc ID in " : ISI:A1994PX83700011 : "
						$rID->{$1}++; # accumulate the document Ids in %ID
					}
				}
				close(FF);
			}
		}
	return $rID;
}

sub ExtractDoc2Dir {
	my($DSN, $table, $file) = @_;  
	my($dir, $f, @Seg, $seg, $i, $j, @Doc, $cid, $ct, $did, $Ti, $Abs, $rID, @ID);
	my($txt, $encoding_name, $percent);
	if (-d $main::Odir) { &DelAllFile($main::Odir, 'all'); }
	&CreateDir($main::Odir); 
	print STDERR "Extracting docs. of each cluster into the folder: '$main::Odir'\n";
	my($DBH, $STH, $sql);
	$DBH = &InitDBH($DSN, $main::ODB);
	if ($table eq 'Patent') { # do not nothing
# Table=Seg_Abs6，主鍵值=SNo，日期=FName，標題=DName，內文=Dscpt
#	$sql = "SELECT DName, Dscpt FROM Seg_Abs6 where SNo = ?"; # 2009/09/21
		$sql = "SELECT DName, Dscpt FROM TSeg where SNo = ?";
	} else {
		$sql = "SELECT TI, AB FROM $table where UT = ?";
	}
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL=$sql, $DBI::errstr\n";
	open F, $file or die "Cannot read file:'$file'";
	undef $/; $f = <F>;  $/ = "\n"; close(F); # to get all the content in one read
	@Seg = split /<p>/, $f;
	use SAMtool::Progress;
	$i = 0; my $Progress = Progress->new({'OUT'=>*STDERR{IO},'Format'=>'line'});
	foreach $seg (@Seg) {
		$i++; $percent = $Progress->ShowProgress($i/@Seg, $percent);
#		next if ($i == 1); # first segment has no cluster
		next if ($i <= 2); # first two segments have no cluster
# match each URL, read the file in that URL, and insert the content of the file
		@Doc = (); $cid = 0; $ct = ''; undef $rID;
# The next if statement is added on 2007/08/08
#		if ($seg =~ /(\d+)\(\d+\):<UL>/) { # format of cluster ID: '1(62):<UL>'
#		if ($seg =~ /^\s*(\d+)\(\d+\):((.|\n)+)<OL>/) { # format of cluster ID: '1(62):<'
		if ($seg =~ /^\s*(\d+)\(\d+\):<UL>((.|\n)+)\n<UL>/) { # format of cluster ID: '1(62):<'
			$cid = $1; $ct = $2; 
			($ct, $j) = split /\n<UL>/, $ct; # get the first for title
			$ct =~ s/<[^>]*>//g; # delete all html tags
			$ct =~ s/\n+//g; # delete new line
		} else {
			last if $seg =~ m|</html>|;
			print STDERR "Cannot get cluster ID for seg:'", substr($seg, 0, 60), "'\n"; 
			next;
		}
		$rID = &GetDocID_from_Segment($seg, $rID);
		while (($did, $j) = each %$rID) {
			$STH->execute($did) or die "Can't execute SQL=$sql, $STH::errstr\n";
			($Ti, $Abs) = $STH->fetchrow_array;
			foreach $txt ($Ti, $Abs) {
				$encoding_name = Encode::Detect::Detector::detect($txt);
				if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#					$txt = encode("big5", $txt);
#				if ($encoding_name !~ /big5/i) { # if utf8-encoded
					from_to($txt, $encoding_name, 'big5'); 
				}
				$txt =~ s/^\s*|\s*$//g;		$txt  =~ s/\n+/ /g;
			}
#			$Ti  =~ s/^\s*|\s*$//g;			$Ti  =~ s/\n+/ /g;
#			$Abs =~ s/^\s*|\s*$//g;			$Abs =~ s/\n+/ /g;
#			push @Doc, $Ti . " : $did : " . $Abs;
			push @Doc, $Ti . "\t:\t$did\t:\t" . $Abs;
	#	Format: title : ISI:000089093200014 : content
		}
# Now write out the documents into the file named with the cluster ID
		$j = @Doc;
		$f = $main::Odir . "/$cid-$j\.htm"; # assume the doc dir is at ..\doc
		open F, ">$f" or die "Cannot write to file:'$f'";
		print F "<title>$ct</title>\n", join("\n", @Doc), "\n";
#		print STDERR "f=$f\n";
		close(F);
	}
	$STH->finish;
	$DBH->disconnect;
	$percent = $Progress->ShowProgress($i/@Seg, $percent);
}

