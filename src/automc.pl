#!/usr/bin/perl -s
	use SamOpt qw(SamOpt);  &SamOpt();
	my $prog;
#	$prog = "parl CATAR.par ";
	$prog = "perl -s ";

# Multistage clustering (MC) for paper mining. 2008/04/26, by Yuen-Hsien Tseng
	use File::Copy;
	if (defined $main::Omin)   { $Omin = $main::Omin;    } else { $Omin = 2; }
	if (defined $main::OTable) { $Table = $main::OTable; } else { $Table = 'TPaper'; }

# perl -s automc.pl -OISI2DB envi01 D:\TIER\data\envi\envi_01
# perl -s automc.pl -OISI2DB -Odb SC_LIS
#	&ISI2DB(@ARGV) if $main::OISI2DB;
	&ISI2DB(@ARGV) if $main::OOA; # 2011/04/16

# perl -s automc.pl -Ofield SciLit TPaper ../Source_Data/SciLit/SciLit.mdb
	&FieldAggregation(@ARGV) if $main::Ofield;

# perl -s automc.pl -OBC=manual Phar ..\Source_Data\Phar\Phar.mdb ..\Source_Data\Phar\PlaintextFormat
# perl -s automc.pl -OBC -Omin=1 -Osi envi01 ..\Source_Data\envi01\envi01.mdb
# perl -s automc.pl -OBC=JBC SC_Edu ..\Source_Data\SC_Edu\SC_Edu.mdb
	&BibCpl_MC(@ARGV) if $main::OBC;

# perl -s automc.pl -OCW -Osi -OTable=Patent ItaA ../Source_Data/ItaA/ItaA.mdb
# perl -s automc.pl -OCW envi01 ..\Source_Data\envi01\envi01.mdb
	&DC_MC(@ARGV) if $main::OCW; # document clustering based on co-word (CW) analysis
	exit;

	use strict; use vars;

sub myexec {
	my($cmd) = @_; print STDERR "$cmd\n"; system($cmd)==0 or die "'$cmd' failed: $?\n";
}

sub ISI2DB {
	my($DSN, $dir) = @_;
	my($cmd, $DB_Path, $Table);
	$Table = ($main::OTable)?$main::OTable:'TPaper';

# 1. 將下載下來的資料存放到D:\TIER\data\food\food_03，然後執行：
#	$cmd="mkdir ..\\Source_Data\\$DSN"; &myexec($cmd);
	$cmd="../Source_Data/$DSN";
	mkdir($cmd) if not -d $cmd;

# May skip this step, if the data is already in the MDB
#	$DB_Path = $cmd . "/${DSN}.mdb" unless -r $DB_Path;
	$DB_Path = $cmd . "/${DSN}.db" unless -r $DB_Path;
	goto SkipDBcreation if ($main::Odb);


# perl -s filelist4.pl -html ..\Source_Data\food03\food03.lst  D:\TIER\data\food\food_03
	my $list = "../Source_Data/$DSN/${DSN}.lst";
	$cmd="$prog filelist4.pl -html $list $dir";
	&myexec($cmd);

# 2.	將12個欄位存到大檔案(同時刪除UT重複資料)
# perl -s ISI.pl -OdelDup -OBioAbs ..\Source_Data\food03\food03.lst > ..\Source_Data\food03\food03_all.txt
#	$cmd="$prog ISI.pl -OdelDup -OBioAbs ../Source_Data/$DSN/${DSN}.lst > ../Source_Data/$DSN/${DSN}_all.txt";
	my $all_rec = "../Source_Data/$DSN/${DSN}_all.txt";
	$cmd="$prog ISI.pl -OdelDup $list > $all_rec";
	&myexec($cmd);
#   => There are 1210 records. It takes 0 seconds.
#
# 3.	匯入資料庫：拷貝樣板資料庫d:\demo\STPIWG\src\Paper_org.mdb到
#	Copy Paper_org.mdb  ..\Source_Data\food03\food03.mdb
#	$DB_Path = "..\\Source_Data\\$DSN\\${DSN}.mdb"; # use DOS format due to Copy
#	$cmd="Copy Paper_org.mdb $DB_Path";
#	&myexec($cmd);
	if (not -e $DB_Path) {
#	link('Paper_org.mdb', $DB_Path);
#		copy('Paper_org.mdb', $DB_Path) or die "File cannot be copied";
#		print STDERR "Copy Paper_org.mdb to $DB_Path\n";
		copy('Paper_org.db', $DB_Path) or die "File cannot be copied";
		print STDERR "Copy Paper_org.db to $DB_Path\n";
	}
	$cmd="$prog ISI.pl -O2DB $DSN $Table $DB_Path $all_rec";
	&myexec($cmd);
# d:\demo\STPIWG\Source_Data\food03\food03.mdb，設定其ODBC的DSN = food03。
# 將food03_all.txt的資料，匯入到food03.mdb的TPaper資料表中（要先改TPaper成TPaper_org）。

SkipDBcreation :
# 4.	執行下列命令，可以從 food03.mdb中
# （1）統計MC、CC、MI、C1、PY等欄位各項目的次數；
# （2）統計標題、摘要、MC、CC、MI等欄位之空值數量、字數等統計值；
	$cmd = "../Result/$DSN";
	if (not -d $cmd) {
		mkdir($cmd);  print STDERR "create a dir: ../Result/$DSN\n";
	}
# perl -s automc.pl -Ofield -OBioAbs food03
#	$cmd="$prog automc.pl -Ofield -OBioAbs $DSN";
	$cmd="$prog automc.pl -Ofield $DSN $Table $DB_Path";
	&myexec($cmd);
# 結果放在..\Result\food目錄下，總共9個檔案。將該些資料，拷貝到food03.xls去。
}


sub FieldAggregation {
	my($DSN, $Table, $DB_Path) = @_; my($cmd, @Fields, $f, $ff, $option);
	$Table = 'TPaper' if $Table eq '';
	$option = '-OBioAbs' if $main::OBioAbs;

# 從 SciLit.mdb中，統計各欄位內容（詞彙）的出現次數（篇數）：
	@Fields = split ' ', "PY AU CR DE ID"; # SC SO J9 在與年代做交叉分析時會做統計
	# AU 會在 filterRT.pl 中會用到，不要在此省略掉
	@Fields = split ' ', "PY MC CC MI" if $main::OBioAbs;
	foreach $f (@Fields) {
		$cmd="$prog ISI.pl -OISIt $DSN $Table $f $DB_Path > ../Result/$DSN/$f.txt";
		&myexec($cmd);
	}
	$cmd="$prog ISI.pl -OISIt -OSC2C=ISI_SC2C.txt $DSN $Table SC $DB_Path > ../Result/$DSN/SC2C.txt";
	&myexec($cmd) if (defined $main::OSC2C); # added on 2019/08/25

# 與年代作交叉分析：
	@Fields = split ' ', "AF AU DP IU C1 SC SO J9 TC";
	foreach $f (@Fields) {
		$ff = $f; $ff = "[$ff]" if $f eq 'IU';
		$cmd="$prog ISI.pl -OISIt -Ocr=100 $DSN $Table $ff $DB_Path > ../Result/$DSN/${f}_PY.txt";
		&myexec($cmd);
# fractional count 是指同一篇文章有n個作者時，每個作者累計1/n次
# 相對於 normal count，是指同一篇文章有n個作者時，每個作者累計1次
		$cmd="$prog ISI.pl -OISIt -OfracCount -Ocr=100 $DSN $Table $ff $DB_Path > ../Result/$DSN/${f}_PY_fc.txt";
		# add if condition in the next line on 2019/08/25
		&myexec($cmd) if ($f eq 'AF' or $f eq 'AU'  or $f eq 'IU' or $f eq 'C1'); 
	}
	if (defined $main::OSC2C) { # added on 2019/08/25
		$cmd="$prog ISI.pl -OISIt -Ocr=100 -OSC2C=ISI_SC2C.txt $DSN $Table SC $DB_Path > ../Result/$DSN/SC2C_PY.txt";
		&myexec($cmd);
		$cmd="$prog ISI.pl -OISIt -OfracCount -Ocr=100 -OSC2C=ISI_SC2C.txt $DSN $Table SC $DB_Path > ../Result/$DSN/SC2C_PY_fc.txt";
		&myexec($cmd);
	}

# 與被引用次數做交叉分析
  if (not $main::OBioAbs) {
	@Fields = split ' ', "AF AU DP IU C1 SC SO J9";
	foreach $f (@Fields) {
		$ff = $f; $ff = "[$ff]" if $f eq 'IU';
		$cmd="$prog ISI.pl -OISIt -Ocr=100 $DSN $Table \"$ff, TC\" $DB_Path > ../Result/$DSN/${f}_PY_TC.txt";
		&myexec($cmd);
# fractional count 是指同一篇文章有n個作者時，每個作者累計1/n次
# 相對於 normal count，是指同一篇文章有n個作者時，每個作者累計1次
		$cmd="$prog ISI.pl -OISIt -OfracCount -Ocr=100 $DSN $Table \"$ff, TC\" $DB_Path > ../Result/$DSN/${f}_PY_TC_fc.txt";
		# add if condition in the next line on 2019/08/25
		&myexec($cmd) if ($f eq 'AF' or $f eq 'AU' or $f eq 'IU' or $f eq 'C1');
# 計算 CPP （Citations per Paper）指標
		$cmd="$prog ISI.pl -Omfd $f ../Result/$DSN > ../Result/$DSN/${f}_CPP.txt";
		# add if condition in the next line on 2019/08/25
		&myexec($cmd) if ($f eq 'AF' or $f eq 'AU' or $f eq 'IU' or $f eq 'C1');
	}
  }

	if ($main::OY5) { # added on 2019/0825
		&Aggregate5Year($DSN, $Table, $DB_Path);
	}

# 瞭解 DE、ID、SC等欄位內的詞彙，在標題與內文中出現的比例：
	$cmd="$prog ISI.pl -Ochktm $DSN $Table $DB_Path "
		."> ../Result/$DSN/_${DSN}_stat.txt";
	&myexec($cmd) if not $main::OBioAbs;
# 統計標題、摘要等欄位之字數與統計值：
	$cmd="$prog ISI.pl -OavgCnt $option $DSN $Table $DB_Path "
		.">> ../Result/$DSN/_${DSN}_stat.txt";
	&myexec($cmd);

# 最後，將結果目錄下的所有文字檔案，轉入到 Excel 中
	$cmd="$prog ISI.pl -O2xls -OmaxR=500 $DSN ../Result/$DSN "
	."../Result/$DSN/_${DSN}_by_field.xls";
	&myexec($cmd);
}

sub Aggregate5Year {
	my($DSN, $Table, $DB_Path, ) = @_; my($cmd, $f);
# 與年代做交叉分析的資料，做每五年累計的統計
	foreach $f ('C1', 'SC', 'SC2C', 'SO', 'J9') {
		$cmd="$prog ISI.pl -OY5 ../Result/$DSN/${f}_PY.txt > ../Result/$DSN/${f}_PY_5.txt";
		&myexec($cmd);
		$cmd="$prog ISI.pl -OY5 ../Result/$DSN/${f}_PY_fc.txt > ../Result/$DSN/${f}_PY_fc_5.txt";
		&myexec($cmd);
	}
#perl -s ISI.pl -OY5 ../Result/Edu09/C1_PY_TC.txt > ../Result/Edu09/C1_PY_TC_5.txt
#perl -s ISI.pl -OY5 ../Result/Edu09/C1_PY_TC_fc.txt > ../Result/Edu09/C1_PY_TC_fc_5.txt
	$cmd="$prog ISI.pl -OY5 ../Result/$DSN/C1_PY_TC.txt > ../Result/$DSN/C1_PY_TC_5.txt";
	&myexec($cmd);
	$cmd="$prog ISI.pl -OY5 ../Result/$DSN/C1_PY_TC_fc.txt > ../Result/$DSN/C1_PY_TC_fc_5.txt";
	&myexec($cmd);
	$cmd="$prog ISI.pl -OPYCPP ../Result/$DSN/C1_PY_5.txt ../Result/$DSN/C1_PY_TC_5.txt > ../Result/$DSN/C1_PY_CPP_5.txt";
	&myexec($cmd); # This two lines were added on 2013/07/29

	if ($main::OBioAbs) {
		$cmd="$prog ISI.pl -Omi=5 ../Result/$DSN/MI.txt > ../Result/$DSN/MI.htm";
		&myexec($cmd);
	}
}


sub PromptMsg1 {
	my($DSN, $n, $cut) = @_; my($ans);
	print "\nDo you want to cluster again (using the above threshold: '$cut')?\n"
	, "Enter 'Y' or 'y' for Yes and 'N' or 'n' for No:";
	$ans = <STDIN>; chomp $ans; exit if $ans =~ /n/i;
}

sub PromptMsg2 {
	my($DSN, $n, $BC) = @_; my($cut, $nn, $threshold);
	$nn = ($n<2)?'':'_S'.$n;
	$threshold = 0.01;
	$threshold = 0.1 if $main::OCW;
#	$cmd = "$prog Cluster.pl -Osi ${DSN}_${BC}$nn ../Result/${DSN}_${BC}$nn";
#	&myexec($cmd) if $main::Osi;
	print "\nPlease consult the .html and .png files in the folder: ../Result/${DSN}_${BC}$nn "
	, "(and the above Silhouette values if available).\n"
	, "Then choose a threshold to cut the current clustering .\n"
#	, "Type 0.0 instead of 0 if your threhsold is zero.\n"
	, "Enter the threshold here (default=$threshold):";
	$cut = <STDIN>; chomp $cut;
	$cut = ($cut eq '' or $cut<0 or $cut>1)?$threshold:$cut;
	$cut .= '.0' if $cut !~ /\./; # if integer, append '.0' to make it a float number
	print "Now use the threshold: '$cut' for processing ...\n";
	return $cut;
}

sub PromptMsg2_2 {
	my($DSN, $minDF) = @_; my($in);
print "Please consult ../Result/$DSN/AU.txt to decide the number of authors \n"
	. "for clustering. Authors whose publications less than a threshold \n"
	. "will be excluded from clustering.\n"
	. "Enter the threshold here:";
	$in = <STDIN>; chomp $in; $minDF = ($in<1)?$minDF:$in;
	print "Now use the threshold: '$minDF' for processing ...\n";
	return $minDF;
}

sub PromptMsg3 {
	my($n, $low_df, $low_tf, $ct_low_tf) = @_;
	my($a, $b, $c);
	$low_df = ($low_df eq '')?2:$low_df;
	if ($low_tf eq '') {
		$low_tf = 1;
		$low_tf = 2*($n-1) if $n > 1;
		$low_tf = 6 if $n > 4;
	}
	if ($ct_low_tf eq '') {
		$ct_low_tf = 1;
		$ct_low_tf = 2*($n-1) if $n > 1;
		$ct_low_tf = 6 if $n > 4;
	}
	print "\nEnter low_df, low_tf, and ct_low_tf for clustering\n"
	, "You can just press <ENTER> to accept the default values:\n"
	, "low_df=$low_df, low_tf=$low_tf, ct_low_tf=$ct_low_tf\n";
	print "low_df="; $a = <STDIN>; chomp $a;
	print "low_tf="; $b = <STDIN>; chomp $b;
	print "ct_low_tf="; $c = <STDIN>; chomp $c;
	($low_df, $low_tf, $ct_low_tf) = ($a eq ''?$low_df:$a, $b eq ''?$low_tf:$b, $c eq ''?$ct_low_tf:$c);
	return ($low_df, $low_tf, $ct_low_tf);
}

sub BibCpl_MC {
	my($DSN, $DB_Path, $InDir) = @_;  my($cmd, $cut, $BC, $minDF);
	$BC = 'BC';
# /*--書目對分析----------------------------------------------------------------------*/
	if ($main::OBC eq 'manual') { # 將待歸類文件，轉換放到 doc/ 目錄下
		$cmd = "$prog Cluster.pl -Odebug -ObigDoc=manual -ODB=$DB_Path $DSN "
. "\"select UT, TI, AB from TPaper where UT=?\" $InDir ../doc/${DSN}_${BC}_S2";
		&myexec($cmd);
		$cut = &Clustering_BibCpl($DSN, $DB_Path, 2, $BC);
	} elsif ($main::OBC =~ /^JBC$|^ABC$/i) { # 期刊書目對 、 作者書目對
		$BC = $main::OBC; $BC = uc $BC;
# 依照期刊名稱將論文分類，使每一類包含一個期刊的論文
# perl -s ISI.pl -OBigDoc SC_Edu_JBC ..\Source_Data\SC_Edu\SC_Edu.mdb Journal ..\doc\SC_Edu_JBC_S2
  # # It takes 304 seconds
# perl -s ISI.pl -OBigDoc=5 SC_Edu_Au ..\Source_Data\SC_Edu\SC_Edu.mdb Author ..\doc\SC_Edu_Au_S2
#	There are 972 Author(s)...   It takes 438 seconds
		if ($main::OBC eq 'ABC') { $minDF = &PromptMsg2_2($DSN, 1); } else { $minDF=1; }
		$cmd = "$prog ISI.pl -OBigDoc=$minDF ${DSN}_$BC $DB_Path $BC ../doc/${DSN}_${BC}_S2";
		&myexec($cmd);
		$cut = &Clustering_BibCpl($DSN, $DB_Path, 2, $BC);		
	} else {
#goto Stage5;
		$cut = &Clustering_S1($DSN, $DB_Path, $BC);
Stage2:
		&PromptMsg1($DSN, 1, $cut);
		$cut = &Clustering_S1toS2($DSN, $DB_Path, 2, $cut, $BC);
	}

Stage3:
#$cut=0.05;
	&PromptMsg1($DSN, 2, $cut);
	$cut = &Clustering_S2toS3($DSN, $DB_Path, 3, $cut, $BC);

	&PromptMsg1($DSN, 3, $cut);
	$cut = &Clustering_S2toS3($DSN, $DB_Path, 4, $cut, $BC);

Stage5:
	&PromptMsg1($DSN, 4, $cut);
	$cut = &Clustering_S2toS3($DSN, $DB_Path, 5, $cut, $BC);

	&PromptMsg1($DSN, 5, $cut);
	$cut = &Clustering_S2toS3($DSN, $DB_Path, 6, $cut, $BC);
}

sub Clustering_S1 {
	my($DSN, $DB_Path, $BC) = @_;	my($cmd, $cut, $OutDir, $option);
# 執行書目對分析（記得先設定 DSN for $DSN.mdb.）
# 條件：尚未有Result目錄下的任何索引檔，且文件在DBMS中
# D:\demo\STPIWG\src>perl -s CiteAna.pl -Oclu $DSN TPaper $DSN_BibCpl ..\Result\$DSN_BibCpl
# Remark:
# $DSN : data source name (DSN)
# TPaper : table name in $DSN.mdb
# $DSN_BibCpl : index name (for internal system use)
# ..\Result\$DSN_BibCpl : index path name (real file folder name, created by CiteAna.pl. Note: index path should under STPIWG\Result\ )
	$OutDir = "../Result/${DSN}_$BC";
	$option = "-OmaxDF=$main::OmaxDF" if $main::OmaxDF > 0;
# 1. 文件以及引用資料都在DBMS中，產生歸類所需之索引檔案：
#	 Titles.txt, Inv.txt, DocPath.txt, SortedPairs.txt
	$cmd = "$prog CiteAna.pl -Oclu $option -ODB=$DB_Path $DSN TPaper "
	 . "${DSN}_$BC $OutDir";
	&myexec($cmd);

# 2.進行相似度分析與歸類運算（根據前一步驟的書目對分析結果, 產生 Tree.txt）
# perl -s Cluster.pl -Osim -Ocut=0.0 -Oct_low_tf=0 $DSN_BibCpl ..\Result\$DSN_BibCpl > ..\Result\$DSN_BibCpl\0_0.0.html
	$cmd = "$prog Cluster.pl -Osim -Odebug=1 -Ocut=0.0 -Oct_low_tf=0 "
		 . "${DSN}_$BC $OutDir > $OutDir/0_0.0.html";
	&myexec($cmd);

# 3. 用不同相似度門檻切割歸類結果，並畫出主題圖（產生 SimPairs.txt, Coordinate.txt）：
# perl -s Cluster.pl -Ocut=0.01 -Oct_low_tf=0 $DSN_BibCpl ..\Result\$DSN_BibCpl > ..\Result\$DSN_BibCpl\0_0.01.html
# perl -s Term_Trend.pl -Ocolor -Ocut=0.01 -Omap ../Result/$DSN_BibCpl
	&Cluster_Map_MultiCut($DSN, $DB_Path, 1, $BC);
	$cmd = "$prog Cluster.pl -Osi ${DSN}_$BC $OutDir";
	&myexec($cmd) if $main::Osi;
	$cut = &PromptMsg2($DSN, 1, 'BC');
#$cut = "0.0";
	&Cluster_Map_Cut($DSN, $DB_Path, 1, $cut, 1, $BC);
	&CrossTab_by_Cluster_and_Field($DSN, $DB_Path, $OutDir, $cut, '', $BC);
	return $cut; # for next stage clustering
}

sub Clustering_BibCpl {
	my($DSN, $DB_Path, $n, $BC) = @_;  my($cmd, $cut, $nn, $OutDir, $option);
#	$BC = 'BibCpl'; # bibliometric coupling based on documents
#	$BC = 'JBC'; # bibliometric coupling based on Journals
#	$BC = 'ABC'; # bibliometric coupling based on Authors
	$nn = ($n<2)?'':'_S'.$n;
	$OutDir = "../Result/${DSN}_$BC$nn";
	$option = "-OmaxDF=$main::OmaxDF" if $main::OmaxDF > 0;
# 5.2 文件在 doc/ 目錄下，但引用資料在DBMS中，產生歸類所需之索引檔案：
#	 Titles.txt, Inv.txt, DocPath.txt, SortedPairs.txt
# perl -s CiteAna.pl -OMulClu $DSN TPaper $DSN_BibCpl_S2 ..\Result\$DSN_BibCpl_S2 ..\doc\$DSN_BibCpl_S2
# perl -s CiteAna.pl -OMulClu $DSN TPaper $DSN_BibCpl_S3 ..\Result\$DSN_BibCpl_S3 ..\doc\$DSN_BibCpl_S3
	$cmd = "$prog CiteAna.pl -OMulClu $option -ODB=$DB_Path $DSN TPaper "
	  . "${DSN}_$BC$nn $OutDir ../doc/${DSN}_$BC$nn";
	&myexec($cmd);

# 5.3 進行相似度分析與歸類運算（根據前一步驟的書目對分析結果, 產生 Tree.txt）
# perl -s Cluster.pl -Osim -Ocut=0.0 -Oct_low_tf=0 -Odebug $DSN_BibCpl_S2 ..\Result\$DSN_BibCpl_S2 > ..\Result\$DSN_BibCpl_S2\0_0.0.html
# perl -s Cluster.pl -Osim -Ocut=0.01 -Oct_low_tf=0 -Odebug $DSN_BibCpl_S3 ..\Result\$DSN_BibCpl_S3 > ..\Result\$DSN_BibCpl_S3\0_0.01.html
	$cmd = "$prog Cluster.pl -Osim -Ocut=0.0 -Oct_low_tf=0 -Odebug "
		 . "${DSN}_$BC$nn $OutDir > $OutDir/0_0.0.html";
	&myexec($cmd);

# 5.4用不同相似度門檻切割歸類結果，並畫出主題圖（產生 SimPairs.txt, Coordinate.txt）：
	&Cluster_Map_MultiCut($DSN, $DB_Path, $n, $BC);

# 5.5詢問最後選擇的門檻，並依此門檻切割分類結果
	$cmd = "$prog Cluster.pl -Osi ${DSN}_$BC$nn $OutDir";
	&myexec($cmd) if $main::Osi;
	$cut = &PromptMsg2($DSN, $n, $BC);
	&Cluster_Map_Cut($DSN, $DB_Path, $n, $cut, 3, $BC);
	&CrossTab_by_Cluster_and_Field($DSN, $DB_Path, $OutDir, $cut, $nn, $BC);
	return $cut;
}

sub Clustering_S1toS2 {
	my($DSN, $DB_Path, $n, $cut, $BC) = @_;
# 5. 將小類歸成中類（條件：歸類結果在Result\下，但文件在DBMS）：
# 5.1 先將歸類後的文件輸出到 doc\ 目錄下
# perl -s Cluster.pl -Odebug -ObigDoc -Ocut=0.0 -Oct_low_tf=0 -Odsn=$DSN
#   -Osql="select UT, TI, AB from TPaper where UT=?" $DSN_BibCpl
#   ../Result/$DSN_BibCpl ../doc/$DSN_BibCpl_S2
	my $cmd =  "$prog Cluster.pl -Odebug -ObigDoc -Ocut=$cut -Oct_low_tf=0 "
. "-Odsn=$DSN -ODB=$DB_Path -Osql=\"select UT, TI, AB from TPaper where UT=?\" "
	. "${DSN}_$BC ../Result/${DSN}_$BC ../doc/${DSN}_${BC}_S2";
	&myexec($cmd);
	return &Clustering_BibCpl($DSN, $DB_Path, $n, $BC);
	# return $cut for next stage clustering
}

sub Clustering_S2toS3 { # or S3toS4 or S4toS5 or S5toS6
	my($DSN, $DB_Path, $n, $cut, $BC) = @_;
	my $n1 = $n - 1;
# 6. 將中類歸成更大類（條件：歸類結果在Result\下，但文件在 doc\）：
# 6.1先將歸類後的文件輸出到 doc\ 目錄下
# perl -s Cluster.pl -Odebug -ObigDoc -Ocut=0.01 -Oct_low_tf=0 $DSN_BibCpl_S2 ../Result/$DSN_BibCpl_S2 ../doc/$DSN_BibCpl_S3
	my $cmd = "$prog Cluster.pl -Odebug -ObigDoc -Ocut=$cut -Oct_low_tf=0 "
	. "${DSN}_${BC}_S$n1 ../Result/${DSN}_${BC}_S$n1 ../doc/${DSN}_${BC}_S$n";
	&myexec($cmd);
	return &Clustering_BibCpl($DSN, $DB_Path, $n, $BC);
}

# Use global variables : -Omin ($main::Omin)
sub CrossTab_by_Cluster_and_Field {
	my($DSN, $DB_Path, $OutDir, $cut, $nn, $BC) = @_;  my($out, $option, $cmd);
# 5.6針對上述（5.5）得出的類別，印出每個類別的各種資料的分佈狀況，執行：
# perl -s tool.pl -OSC=all -Omin=2 $DSN TPaper ..\Result\$DSN_BibCpl\0_0.01.html > ..\Result\$DSN_BibCpl\0_0.01_all_2.html
	$out = "$OutDir/0_${cut}";
	$option = '-OBioAbs' if $main::OBioAbs;
# Generate HTML file
	$cmd = "$prog tool.pl -OSC=all -Omin=$main::Omin $option -ODB=$DB_Path "
		 . "$DSN TPaper ${out}.html > ${out}_all_${main::Omin}.html";
	&myexec($cmd);
  # 其中all代表如下的欄位：PY AU SO SC CR C1。事實上，-OSC也可以設定為你想要的多個欄位，
  #   只要用「雙引號」括起來，欄位名稱之間用空格隔開即可。例如：
  #perl -s tool.pl -OSC="PY AU SO CR" -Omin=2 $DSN TPaper ..\Result\$DSN_BibCpl\0_0.01.html > ..\Result\$DSN_BibCpl\0_0.01_4.html
  #若要就個別國家來分析，執行：在上列命令中多加 -Country=國家代號 即可，如下：
  #perl -s tool.pl -OSC=all -Omin=2 -Country=USA ICT TPaper ..\Result\ICT_BibCpl_S5\0_0.01.html > ..\Result\ICT_BibCpl_S5\0_0.01_all_2_USA.html
# Generate Text file
#	$cmd = "$prog tool.pl -OSC=\"PY C1 AU CR [IU]\" -Otxt=30 -Omin=${main::Omin} $DSN TPaper "
    #perl -s tool.pl -OSC="PY C1 AU CR" -Otxt=30 -Omin=0 -Country=USA ICT TPaper ..\Result\ICT_BibCpl_S5\0_0.01.html > ..\Result\ICT_BibCpl_S5\0_0.01_all_1_USA.txt
	$cmd = "$prog tool.pl -OSC=all -Omin=$main::Omin $option -ODB=$DB_Path -Otxt=100 "
		 . "$DSN TPaper ${out}.html > ${out}_all_${main::Omin}.txt";
	&myexec($cmd);
# Generate Excel file
# perl -s ISI.pl -O2xls=2 -Of=..\Result\envi01_dc_S4\2_6_6_0.05_all_2.txt envi01_dc_S4 ..\Result\envi01_dc_S4
	$cmd = "$prog ISI.pl -O2xls=2 -Of=${out}_all_${main::Omin}.txt "
		 . "${DSN}_$BC$nn $OutDir $OutDir/${DSN}_$BC${nn}_by_field\.xls";
	&myexec($cmd);

# 5.7針對上述得出的類別，印出每個類別的文件標題以及關鍵詞，執行：
# perl -s tool.pl -Otitle ..\Result\$DSN_BibCpl_S2\0_0.01.html > ..\Result\$DSN_BibCpl_S2\0_0.01_titles.html
	$cmd = "$prog tool.pl -Otitle=${out}_titles.xls -Odsn=$DSN -ODB=$DB_Path "
		 . "${out}.html > ${out}_titles.html";
#	&myexec($cmd) if $nn; # 2010/11/06
	&myexec($cmd);
}

sub Cluster_Map_Cut {
# $option == 1 means only tree will be cut
# $option == 2 means only map will be generated
# $option == 3 means both of the above will be done
	my($DSN, $DB_Path, $n, $cut, $option, $BC) = @_; 
	my($OutDir, $nn, $cmd, $OutDir_1, $n_1);
	$option = 3 if $option eq '';
	$nn  =     ($n<2)?'':'_S' . $n;  
	$n_1 = (($n-1)<2)?'':'_S' . ($n-1);	# to draw circle label with 類別順序號
	$cut = '0.0' if $cut == 0;
	$OutDir   = "../Result/${DSN}_$BC$nn";
	$OutDir_1 = "../Result/${DSN}_$BC${n_1}";
# 用不同相似度門檻切割歸類結果：
# perl -s Cluster.pl -Ocut=0.01 -Oct_low_tf=0 $DSN_BibCpl ..\Result\$DSN_BibCpl > ..\Result\$DSN_BibCpl\0_0.01.html
	$cmd = "$prog Cluster.pl -Ocut=$cut -Oct_low_tf=0 ${DSN}_$BC$nn "
	. "$OutDir > $OutDir/0_${cut}.html";
	&myexec($cmd) if $option % 2 == 1; # if 1 or 3

	my($NumItems, $mapYes);
	$NumItems = &GetNumItems("$OutDir/0_${cut}.html");
# 畫出主題圖：
# perl -s Term_Trend.pl -Ocolor -Omap -Ocut=0.01 ../Result/$DSN_BibCpl
	$cmd = "$prog Term_Trend.pl -Ocolor -Omap -Ocut=$cut $OutDir";
	if (int($option / 2) == 1) { # if 2 or 3
		 # if small number of items, create maps unconditionally
		#myexec($cmd) if ($NumItems < 1000); # comment on 2019/08/27
	}  # if too many items, create MDS map may wait too long
	
# 畫出MDS圖，但是圓圈中的編號是類別順序號，不是內部歸類的編號:
# perl -s Term_Trend.pl -Ocolor -Ocut=0.0 -Omap -Oscale=1.5 -OCNo -OhtmlTree=../Result/ATR3_BC_S4/0_0.01.html ../Result/ATR3_BC_S5
	$cmd = "$prog Term_Trend.pl -Ocolor -Omap -Ocut=$cut -OCNo -OhtmlTree="
		.	"${OutDir_1}/0_${cut}.html $OutDir";
	if (int($option / 2) == 1) { # if 2 or 3
		 # if small number of items, create maps unconditionally
		myexec($cmd) if (($NumItems < 1000) and ($OutDir !~ /JBC_S2/));
	}  # if too many items, create MDS map may wait too long
}

sub GetNumItems {
	my($file) = @_; my $NumItems = 0;
	open F, $file or "Cannot read from file:'$file'";
	while (<F>) { if (/clusters, (\d+) items<p>$/) { $NumItems = $1; last; } }
	close(F);
	return $NumItems;
}

sub Cluster_Map_MultiCut {
	my($DSN, $DB_Path, $n, $BC) = @_; my($option);
	$option = ($n<2)?1:3; # skip drawing the topic map if $n too low
	&Cluster_Map_Cut($DSN, $DB_Path, $n, 0.0, $option, $BC);
	&Cluster_Map_Cut($DSN, $DB_Path, $n, 0.01, $option, $BC);
	&Cluster_Map_Cut($DSN, $DB_Path, $n, 0.02, $option, $BC);
#	&Cluster_Map_Cut($DSN, $DB_Path, $n, 0.05, $option, $BC);
#	&Cluster_Map_Cut($DSN, $DB_Path, $n, 0.07, $option, $BC);
#	&Cluster_Map_Cut($DSN, $DB_Path, $n, 0.10, $option, $BC);
}


#----共現字分析 - Co-Word Analysis -----------------------------------------------
sub DC_MC { # DC : Document Clustering (or Co-Word analysis)
	my($DSN, $DB_Path) = @_;
	my($cut, $low_df, $low_tf, $ct_low_tf, $old_ct_low_tf, $CW, $cmd, $minDF);
	$CW = 'CW';
	if ($main::OCW =~ /JCW|ACW/i) { # Journal Co-Word or Author Co-Word analysis
		$CW = $main::OCW; $CW = uc $CW;
		if ($main::OCW eq 'ACW') { $minDF = &PromptMsg2_2($DSN, 1); } else { $minDF=1; }
		$cut = &Clustering_JCW_ACW($DSN, $DB_Path, $CW, $minDF);
	} else { # for ordinary co-word analysis
		($low_df, $low_tf, $ct_low_tf) = (2, 1, 1);
		$cut = &Clustering_S1_dc($DSN, $DB_Path, $low_df, $low_tf, $ct_low_tf, $CW);
		$old_ct_low_tf = $ct_low_tf;

		&PromptMsg1($DSN, 1, $cut);
		$old_ct_low_tf = $ct_low_tf;
		($low_df, $low_tf, $ct_low_tf) = (2, 2, 2);
		($low_df, $low_tf, $ct_low_tf) = &PromptMsg3(2, $low_df, $low_tf, $ct_low_tf);
		$cut = &Clustering_S1toS2_dc($DSN, $DB_Path, 2, $cut, $low_df, $low_tf,
				$ct_low_tf, $old_ct_low_tf, $CW);
	}
  
	&PromptMsg1($DSN, 2, $cut);
	$old_ct_low_tf = $ct_low_tf;
	($low_df, $low_tf, $ct_low_tf) = (2, 3, 3);
	($low_df, $low_tf, $ct_low_tf) = &PromptMsg3(3, $low_df, $low_tf, $ct_low_tf);
	$cut = &Clustering_S2toS3_dc($DSN, $DB_Path, 3, $cut, $low_df, $low_tf, 
			$ct_low_tf, $old_ct_low_tf, $CW);

	&PromptMsg1($DSN, 3, $cut);
	$old_ct_low_tf = $ct_low_tf;
	($low_df, $low_tf, $ct_low_tf) = (2, 4, 4);
	($low_df, $low_tf, $ct_low_tf) = &PromptMsg3(4, $low_df, $low_tf, $ct_low_tf);
	$cut = &Clustering_S2toS3_dc($DSN, $DB_Path, 4, $cut, $low_df, $low_tf,
			$ct_low_tf, $old_ct_low_tf, $CW);

	&PromptMsg1($DSN, 4, $cut);
	$old_ct_low_tf = $ct_low_tf;
	($low_df, $low_tf, $ct_low_tf) = (2, 5, 5);
	($low_df, $low_tf, $ct_low_tf) = &PromptMsg3(5, $low_df, $low_tf, $ct_low_tf);
	$cut = &Clustering_S2toS3_dc($DSN, $DB_Path, 5, $cut, $low_df, $low_tf,
			$ct_low_tf, $old_ct_low_tf, $CW);

	&PromptMsg1($DSN, 5, $cut);
	$old_ct_low_tf = $ct_low_tf;
	($low_df, $low_tf, $ct_low_tf) = (2, 6, 6);
	($low_df, $low_tf, $ct_low_tf) = &PromptMsg3(6, $low_df, $low_tf, $ct_low_tf);
	$cut = &Clustering_S2toS3_dc($DSN, $DB_Path, 6, $cut, $low_df, $low_tf,
			$ct_low_tf, $old_ct_low_tf, $CW);
}

# use global variable: -Table ($main::Table)
sub Clustering_S1_dc {
	my($DSN, $DB_Path, $low_df, $low_tf, $ct_low_tf, $CW) = @_;
	my($cmd, $cut, $option, $OutDir);
# /*--少量文件之歸類分析（依據文件的標題、摘要用詞相似度來歸類）
#  （少於3000篇，視記憶體RAM大小而定）--------------------------*/
# 1. 準備資料：
# 1.1 在SciE.mdb中，執行查詢「Insert_Into_TSeg」
#	 其SQL命令為：
# INSERT INTO TSeg SELECT UT AS SNO, PY & ':' & TI AS Dname, AB AS Dscpt FROM TPaper;
#	 以便將資料表TPaper中的標題（TI）、摘要（AB）以及主鍵（UT）插入資料表TSeg中。
# 1.2 編輯cluster.ini以增加 SciE_dc 的群組，如下：
#	  [SciE_dc]
#	  DSN=SciE
#	  Table=TSeg
#	  IndexName=SciE_dc
#	  IndexPath=../Result/SciE_dc
# Remark:
#   $DSN : data source name (DSN)
#   TSeg : table name in $DSN.mdb
#   ..\Result\$DSN_dc : index path name (real file folder name,
#   Note: index path should under CATAR\Result\ )
	&Prepare_for_Clustering($DSN, $main::Table, $DB_Path, $CW);

# 2. 執行歸類命令（文件在資料庫中，歸類結果也放在資料庫中，而非 Result/ 目錄下）：
# perl -s ClusterDB.pl -Oall -Ouid=20 -Olow_tf=1 -Oct_low_tf=1 -Odebug=1 -Ogrp=${DSN}_dc 1
	$OutDir = "../Result/${DSN}_$CW";
	$option = '-OBioAbs' if $main::OBioAbs;
	$cmd = "$prog ClusterDB.pl -Oall -Ouid=20 -Olow_tf=$low_tf "
		 . "-Oct_low_tf=$ct_low_tf -Odebug=1 -Ogrp=${DSN}_$CW -ODB=$DB_Path 1";
	&myexec($cmd);

	&Cluster_Map_MultiCut_dc($DSN, $DB_Path, 1, $low_df, $low_tf, $ct_low_tf, $CW);
	$cmd = "$prog Cluster.pl -Osi ${DSN}_$CW $OutDir";
	&myexec($cmd) if $main::Osi;
	$cut = &PromptMsg2($DSN, 1, $CW);
#$cut = "0.0";
	&Cluster_Map_Cut_dc($DSN,$DB_Path,1,$cut,1,$low_df,$low_tf,$ct_low_tf, $CW);
	&Cluster8Field($DSN,$DB_Path,$OutDir,$cut,'',$low_df,$low_tf,$ct_low_tf, $CW);
	return $cut; # for next stage clustering
}

sub Clustering_dc {
	my($DSN, $DB_Path, $n, $low_df, $low_tf, $ct_low_tf, $CW) = @_;
	my($cmd, $cut, $nn, $option, $out, $OutDir);
	$nn = ($n<2)?'':'_S'.$n;
	$OutDir = "../Result/${DSN}_${CW}$nn";

# 5.4用不同相似度門檻切割歸類結果，並畫出主題圖：
	&Cluster_Map_MultiCut_dc($DSN, $DB_Path, $n, $low_df, $low_tf, $ct_low_tf, $CW);

# 5.5詢問最後選擇的門檻，並依此門檻切割分類結果
	$cmd = "$prog Cluster.pl -Osi ${DSN}_${CW}$nn $OutDir";
	&myexec($cmd) if $main::Osi;
	$cut = &PromptMsg2($DSN, $n, $CW);
	&Cluster_Map_Cut_dc($DSN,$DB_Path,$n,$cut,3,$low_df,$low_tf,$ct_low_tf, $CW);
	&Cluster8Field($DSN,$DB_Path,$OutDir,$cut,$nn,$low_df,$low_tf,$ct_low_tf, $CW);
	return $cut;
}

sub Clustering_JCW_ACW {
	my($DSN, $DB_Path, $CW, $minDF) = @_;	 my($cmd, $option, $result, $NewIdx); 
	$NewIdx = "${DSN}_${CW}_S2";
# 依照期刊名稱將論文分類，使每一類包含一個期刊的論文
#	perl -s ISI.pl -OBigDoc SC_Edu_JBC ..\Source_Data\SC_Edu\SC_Edu.mdb Journal ..\doc\SC_Edu_JBC_S2
#	# # It takes 304 seconds
	$cmd = "$prog ISI.pl -OBigDoc=$minDF ${DSN}_$CW $DB_Path $CW ../doc/$NewIdx";
	&myexec($cmd);
	$cmd = "$prog filelist4.pl ../doc/$NewIdx\.lst ../doc/$NewIdx";
	&myexec($cmd);
	&CreateDir("../Result/$NewIdx");

	my($low_df, $low_tf, $ct_low_tf, $cut) = (2, 1, 1, 0.0);
	($low_df, $low_tf, $ct_low_tf) = &PromptMsg3(2, $low_df, $low_tf, $ct_low_tf);
	$option = "-Olow_tf=$low_tf -Oct_low_tf=$ct_low_tf ";
#	$option .= "-OEng_Seg_Phrase" if $OEng_Seg_Phrase ne '';
	$result = $low_df . "_". $low_tf ."_". $ct_low_tf ."_". $cut .".html";
	$cmd = "$prog Cluster.pl -Oall $option -Odebug -Osrc=Dir $NewIdx "
		. "../Result/$NewIdx ../doc/$NewIdx\.lst > ../Result/$NewIdx/$result";
	&myexec($cmd);
	return &Clustering_dc($DSN, $DB_Path, 2, $low_df, $low_tf, $ct_low_tf, $CW);
}

sub Clustering_S1toS2_dc {
	my($DSN,$DB_Path,$n,$cut,$low_df,$low_tf,$ct_low_tf,$old_ct_low_tf, $CW) = @_;
# 5. 將結果歸成更大類（從資料庫中讀出文件與歸類結果資料，需要資料庫選項：Odsn與Otable）
# 5.1（不用再編輯cluster.ini）直接執行底下的命令：
# perl -s auto.pl -Ocut=0.0 -Oold_cut=0.05 -Ouid=20 -Otfc=ChixTFC -Odsn=SciE -Otable=TSeg -Oold_ct_low_tf=1 -Olow_tf=2 -Oct_low_tf=2 SciE_dc SciE_dc_S2
# 上述命令會在STPIWG\src\Result\下產生新資料夾SciE_dc_S2，
# 資料夾中有(DocPath.txt、Inv.txt、SortedPairs.txt、Title.txt、Tree.txt)5個檔案
# 及(Coordinate.txt、SimPairs.txt、map_2_0.0.png、2_2_2_0.0.html)
#	與BibCpl的命令不同
	my $cmd = "$prog auto.pl -Ocut=0.0 -Oold_cut=$cut -Ouid=20 -Otfc=ChixTFC "
		 . "-Odsn=$DSN -ODB=$DB_Path -Otable=TSeg -Oold_ct_low_tf=$old_ct_low_tf "
		 . "-Olow_tf=$low_tf -Oct_low_tf=$ct_low_tf ${DSN}_$CW ${DSN}_${CW}_S2";
	&myexec($cmd);
	return &Clustering_dc($DSN, $DB_Path, $n, $low_df, $low_tf, $ct_low_tf, $CW);
	# return $cut for next stage clustering
}


sub Clustering_S2toS3_dc { # or S3toS4 or S4toS5 or S5toS6
	my($DSN,$DB_Path,$n,$cut,$low_df,$low_tf,$ct_low_tf,$old_ct_low_tf, $CW) = @_;
	my $n1 = $n - 1;
# 6. 將結果歸成更大類（文件不是在資料庫中，而是在STPIWG\doc\下，因此沒有Odsn與Otable選項）
# 6.1 執行歸類：
# perl -s auto.pl -Ocut=0.0 -Oold_cut=0.05 -Otfc=ChixTFC -Oold_ct_low_tf=2 -Olow_tf=4 -Oct_low_tf=4 SciE_dc_S2 SciE_dc_S3
#	與步驟5不同
	my $cmd = "$prog auto.pl -Ocut=0.0 -Oold_cut=$cut -Otfc=ChixTFC "
		 . "-Oold_ct_low_tf=$old_ct_low_tf -Olow_tf=$low_tf -Oct_low_tf=$ct_low_tf "
		 . "-ODB=$DB_Path ${DSN}_${CW}_S$n1 ${DSN}_${CW}_S$n";
	&myexec($cmd);
	return &Clustering_dc($DSN, $DB_Path, $n, $low_df, $low_tf, $ct_low_tf, $CW);
}

# use global variable: -Table ($main::Table)
sub Cluster8Field {
	my($DSN, $DB_Path, $OutDir, $cut, $nn, $low_df, $low_tf, $ct_low_tf, $CW) = @_;
	my($cmd, $option, $out);
# 5.6針對上述得出的類別，印出每個類別的各種資料的分佈狀況，執行：
# perl -s tool.pl -OSC=CR -Omin=2 SciE TPaper ..\Result\SciE_dc\2_1_1_0.05.html > ..\Result\SciE_dc\2_1_1_0.05_CR_2.html
	$option = '-OBioAbs' if $main::OBioAbs;
	$out = "$OutDir/${low_df}_${low_tf}_${ct_low_tf}_${cut}";
# Generate HTML file
	$cmd = "$prog tool.pl -OSC=all -Omin=$main::Omin $option -ODB=$DB_Path "
		 . "$DSN $main::Table ${out}.html > ${out}_all_${main::Omin}.html";
	&myexec($cmd);
  #若要就個別國家來分析，執行：在上列命令中多加 -Country=國家代號 即可，如下：
  #perl -s tool.pl -OSC=all -Omin=2 -Country=USA ICT TPaper ..\Result\ICT_dc_S5\0_0.01.html > ..\Result\ICT_dc_S5\0_0.01_all_2_USA.html
  #perl -s tool.pl -OSC="PY C1 AU CR" -Otxt=30 -Omin=0 -Country=USA ICT TPaper ..\Result\ICT_dc_S5\0_0.01.html > ..\Result\ICT_dc_S5\0_0.01_all_1_USA.txt
# Generate Text file
	$cmd = "$prog tool.pl -OSC=all -Omin=$main::Omin $option -ODB=$DB_Path -Otxt=100 "
		 . "$DSN $main::Table ${out}.html > ${out}_all_${main::Omin}.txt";
	&myexec($cmd);
# Generate Excel file
# perl -s ISI.pl -O2xls=2 -Of=..\Result\envi01_dc_S4\2_6_6_0.05_all_2.txt envi01_dc_S4 ..\Result\envi01_dc_S4
	$cmd = "$prog ISI.pl -O2xls=2 -Of=${out}_all_${main::Omin}.txt "
		 . "${DSN}_${CW}$nn $OutDir $OutDir/${DSN}_${CW}${nn}_by_field\.xls";
	&myexec($cmd);

# 5.7針對上述得出的類別，印出每個類別的文件標題以及關鍵詞，執行：
# perl -s tool.pl -Otitle ..\Result\SciE_dc_S2\2_2_2_0.05.html > ..\Result\SciE_dc_S2\2_2_2_0.05_titles.html
	$cmd = "$prog tool.pl -Otitle=${out}_titles.xls -Odsn=$DSN -OTable=$main::Table "
		 . "-ODB=$DB_Path ${out}.html > ${out}_titles.html";
#	&myexec($cmd) if $nn; # 2010/11/06
	&myexec($cmd);
}


sub Cluster_Map_Cut_dc {
# $option == 1 means only tree will be cut
# $option == 2 means only map will be generated
# $option == 3 means both of the above will be done
	my($DSN, $DB_Path, $n, $cut, $option, $low_df, $low_tf, $ct_low_tf, $CW) = @_;
	my($cmd, $nn, $OutDir);
	$nn = ($n<2)?'':'_S' . $n;  $option = 3 if $option eq '';
	$cut = '0.0' if $cut == 0;
	$OutDir = "../Result/${DSN}_${CW}$nn";
# 用不同相似度門檻切割歸類結果：
# perl -s Cluster.pl -Ocut=0.01 -Oct_low_tf=1 SciE_dc ..\Result\SciE_dc > ..\Result\SciE_dc\2_1_1_0.01.html
	$cmd = "$prog Cluster.pl -Ocut=$cut -Oct_low_tf=$ct_low_tf ${DSN}_${CW}$nn "
	. "$OutDir > $OutDir/${low_df}_${low_tf}_${ct_low_tf}_${cut}.html";
	&myexec($cmd) if $option % 2 == 1; # if 1 or 3

# 畫出主題圖：
# perl -s Term_Trend.pl -Ocolor -Ocut=0.05 -Omap ../Result/SciE_dc
	$cmd = "$prog Term_Trend.pl -Ocolor -Ocut=$cut -Omap $OutDir";
	#&myexec($cmd) if int($option / 2) == 1; # if 2 or 3 # comment on 2019/08/27
# 畫出MDS圖，但是圓圈中的編號是類別順序號，不是內部歸類的編號:
# perl -s Term_Trend.pl -Ocolor -Ocut=0.0 -Omap -Oscale=1.5 -OCNo -OhtmlTree=../Result/ATR3_BC_S4/0_0.01.html ../Result/ATR3_BC_S5
	$cmd = "$prog Term_Trend.pl -Ocolor -Ocut=$cut -Omap -OCNo -OhtmlTree="
		.	"$OutDir/${low_df}_${low_tf}_${ct_low_tf}_${cut}.html $OutDir";
	&myexec($cmd) if int($option / 2) == 1; # if 2 or 3
}

sub Cluster_Map_MultiCut_dc {
	my($DSN, $DB_Path, $n, $low_df, $low_tf, $ct_low_tf, $CW) = @_; my($op);
	$op = ($n<2)?1:3; # skip drawing the topic map if $n too low
	#&Cluster_Map_Cut_dc($DSN,$DB_Path,$n,0.01,$op,$low_df,$low_tf,$ct_low_tf, $CW);
	#&Cluster_Map_Cut_dc($DSN,$DB_Path,$n,0.02,$op,$low_df,$low_tf,$ct_low_tf, $CW);
	&Cluster_Map_Cut_dc($DSN,$DB_Path,$n,0.05,$op,$low_df,$low_tf,$ct_low_tf, $CW);
	&Cluster_Map_Cut_dc($DSN,$DB_Path,$n,0.07,$op,$low_df,$low_tf,$ct_low_tf, $CW);
	&Cluster_Map_Cut_dc($DSN,$DB_Path,$n,0.10,$op,$low_df,$low_tf,$ct_low_tf, $CW);
}

sub Prepare_for_Clustering {
	my($DSN, $Table, $DB_Path, $CW) = @_;
# 5.	執行共現字歸類分析（記得food03.mdb的DNS=food03）
# (1)先設定 cluster.ini的群組，如下：
	my $GroupName = "${DSN}_$CW";
	if (not &HasExisted('cluster.ini', $GroupName)) {
	open F, ">>cluster.ini" or die "Cannot write to cluster.ini";
	print F <<END_OF_Group;
[$GroupName]
DSN=$DSN
DB_Type=DB
DB_Path=$DB_Path
Table=TSeg
IndexName=${DSN}_$CW
IndexPath=../Result/${DSN}_$CW

END_OF_Group
	} # End of if (...

# (2)開啟資料庫檔案d:\demo\STPIWG\Source_Data\food03.mdb，
#	執行其中的查詢「Insert_Into_TSeg」。
	my $cmd="$prog ISI.pl -O2Tseg $DSN $main::Table TSeg $DB_Path";
	&myexec($cmd);
}

sub HasExisted {
	my($IniFile, $GroupName) = @_;
	open F, $IniFile or die "Cannot read IniFile:$IniFile\n";
	while (<F>) {
		if (/^\[$GroupName\]/) {
		print STDERR "$GroupName has already existed in $IniFile\n";
		close(F);
		return 1;
		}
	}
	close(F);
	return 0;
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


# Next functions are to be finished ... (2011/04/04)
# perl -s automc.pl -OCA sam ../Source_Data/sam/sam.mdb
sub CitationAnalysis {
	my($DSN, $DB_Path) = @_;
	my($cmd, $Table);
	$Table = ($main::OTable)?$main::OTable:'TPaper';

# 將「文件集」的所有Cited References擷取出來並累計其在「文件集」裡被引用的次數：
# 1. 執行下列命令：（若之前執行過，可以省略）
	if (not -r "../Result/$DSN/CR.txt") {
		$cmd = "$prog ISI.pl -OISIt $DSN $Table CR $DB_Path > ../Result/$DSN/CR.txt";
		&myexec($cmd);
	}
# 2. 比對每個Cited Reference所對應的 UT. 注意：這一步動作也許會花費很久的時間！！！ 
# perl -s ISI_CR.pl -Omatch sam ..\Source_Data\sam\sam.mdb TPaper ../Result/sam/CR.txt ../Result/sam/CR_UT.txt > ..\Result\sam\CR_UT_stderr.txt
	my $CUf =  "../Result/$DSN/CR_UT"; my $CUfe = $CUf . '_stderr.txt'; $CUf .= '.txt';
	$cmd = "$prog ISI_CR.pl -Omatch $DSN $DB_Path $Table ../Result/$DSN/CR.txt $CUf > $CUfe";
	&myexec($cmd);
	print STDERR "\nPlease check $CUf to see if anything abnormal!\n" if ((-s $CUf)>0);
	# Total number of cited references: 72723 # It takes 1453 seconds
	# 結果在CR_UT.txt裡，將其匯入到ICT.mdb的CR_UT資料表裡。
# 3. 利用上述結果，將每個文件與其Cited References轉成資料庫的格式
# 	Note: the CR_UT below is a field name, not the file name
#   perl -s ISI_CR.pl -Ocite -Opair ICT TPaper CR_UT Cite > ..\Result\ICT\Cite.txt
#   上述結果 Cite.txt 也會同時插入到資料庫的Cite資料表中
	$cmd = "$prog ISI_CR.pl -Ocite -Opair $DSN $DB_Path $Table CR_UT > ../Result/$DSN/Cite.txt";
	&myexec($cmd);
# 4. 利用上述結果，將每個文件的與其Cited References轉成關聯詞表的格式，供下一步應用
	$cmd = "$prog ISI_CR.pl -Ocite $DSN $DB_Path $Table CR_UT > ../Result/$DSN/CiteRT.txt";
	&myexec($cmd);
	$cmd = "$prog ISI_CR.pl -Ocite -Oau $DSN $DB_Path $Table CR_UT > ../Result/$DSN/CiteAU.txt";
	&myexec($cmd);
	$cmd = "$prog ISI_CR.pl -Ocite -Oj9 $DSN $DB_Path $Table CR_UT > ../Result/$DSN/CiteJ9.txt";
	&myexec($cmd);
# 5. 若有需要，可以篩選以cited=Tsai, CC為源頭的所有文件：
#   perl -s filterRT.pl -Ocited="Tseng, YH" ..\Result\sam\CiteAU.txt > ..\Result\sam\CiteTsengYH.txt
	my $Oau = "Tseng, YH"; $Oau = $main::Oau if $main::Oau;
	$cmd = "$prog filterRT.pl -Ocited=\"$Oau\" ../Result/$DSN/CiteAU.txt > ../Result/$DSN/Cite${Oau}.txt";
	&myexec($cmd);
# 6. 將上述結果轉成Pajek的格式，準備視覺化：
#	perl -s filterRT.pl -Opajek ..\Result\ICT\CiteRT.txt > ..\Result\ICT\CiteRT.net
#   perl -s filterRT.pl -Opajek ..\Result\sam\CiteRT.txt > ..\Result\sam\CiteRT.net
# Illegal division by zero at filterRT.pl line 370, <STDIN> line 1.
# This problem need to be corrected (2011/04/04)
	$cmd = "$prog filterRT.pl -Opajek ../Result/$DSN/CiteRT.txt > ../Result/$DSN/CiteRT.net";
	&myexec($cmd);
#   perl -s filterRT.pl -Opajek -Oyear ..\Result\sam\CiteRT.txt > ..\Result\sam\CiteRT.net
# Illegal division by zero at filterRT.pl line 370, <STDIN> line 1.
	$cmd = "$prog filterRT.pl -Opajek -Oyear ../Result/$DSN/CiteRT.txt > ../Result/$DSN/CiteRT.net";
	&myexec($cmd);
	$cmd = "$prog filterRT.pl -Opajek -Oyear ../Result/$DSN/CiteAU.txt > ../Result/$DSN/CiteAU.net";
	&myexec($cmd);
	$cmd = "$prog filterRT.pl -Opajek -Oyear ../Result/$DSN/CiteJ9.txt > ../Result/$DSN/CiteJ9.net";
	&myexec($cmd);
#	perl -s filterRT.pl -Opajek -Oyear -Opat="Tsai|Chang" ..\Result\ICT\CiteAU.txt > ..\Result\ICT\CiteAU_t.net
#	perl -s filterRT.pl -Opajek -Oyear ..\Result\sam\CiteTsengYH.txt > ..\Result\sam\CiteTsengYH.net

#	參數Oyear可讓視覺化時，節點按照其年代排序。參數Opat可輸入regular expression字串，以便只顯示出現該字串的引用關係圖。
#7. 將上述結果，轉成Pajek的網路格式時，以單連線（而非星狀）方式連結關聯詞，並限制每個節點最多的連結數：
#	perl -s filterRT.pl -Opajek -Ocir -OmaxDegree=4 ..\Result\ICT\CiteRT.txt > ..\Result\ICT\CiteRT_cir_4.net
}
