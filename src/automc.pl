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

# 1. �N�U���U�Ӫ���Ʀs���D:\TIER\data\food\food_03�A�M�����G
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

# 2.	�N12�����s��j�ɮ�(�P�ɧR��UT���Ƹ��)
# perl -s ISI.pl -OdelDup -OBioAbs ..\Source_Data\food03\food03.lst > ..\Source_Data\food03\food03_all.txt
#	$cmd="$prog ISI.pl -OdelDup -OBioAbs ../Source_Data/$DSN/${DSN}.lst > ../Source_Data/$DSN/${DSN}_all.txt";
	my $all_rec = "../Source_Data/$DSN/${DSN}_all.txt";
	$cmd="$prog ISI.pl -OdelDup $list > $all_rec";
	&myexec($cmd);
#   => There are 1210 records. It takes 0 seconds.
#
# 3.	�פJ��Ʈw�G�����˪O��Ʈwd:\demo\STPIWG\src\Paper_org.mdb��
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
# d:\demo\STPIWG\Source_Data\food03\food03.mdb�A�]�w��ODBC��DSN = food03�C
# �Nfood03_all.txt����ơA�פJ��food03.mdb��TPaper��ƪ��]�n����TPaper��TPaper_org�^�C

SkipDBcreation :
# 4.	����U�C�R�O�A�i�H�q food03.mdb��
# �]1�^�έpMC�BCC�BMI�BC1�BPY�����U���ت����ơF
# �]2�^�έp���D�B�K�n�BMC�BCC�BMI����줧�ŭȼƶq�B�r�Ƶ��έp�ȡF
	$cmd = "../Result/$DSN";
	if (not -d $cmd) {
		mkdir($cmd);  print STDERR "create a dir: ../Result/$DSN\n";
	}
# perl -s automc.pl -Ofield -OBioAbs food03
#	$cmd="$prog automc.pl -Ofield -OBioAbs $DSN";
	$cmd="$prog automc.pl -Ofield $DSN $Table $DB_Path";
	&myexec($cmd);
# ���G��b..\Result\food�ؿ��U�A�`�@9���ɮסC�N�ӨǸ�ơA������food03.xls�h�C
}


sub FieldAggregation {
	my($DSN, $Table, $DB_Path) = @_; my($cmd, @Fields, $f, $ff, $option);
	$Table = 'TPaper' if $Table eq '';
	$option = '-OBioAbs' if $main::OBioAbs;

# �q SciLit.mdb���A�έp�U��줺�e�]���J�^���X�{���ơ]�g�ơ^�G
	@Fields = split ' ', "PY AU CR DE ID"; # SC SO J9 �b�P�~�N����e���R�ɷ|���έp
	# AU �|�b filterRT.pl ���|�Ψ�A���n�b���ٲ���
	@Fields = split ' ', "PY MC CC MI" if $main::OBioAbs;
	foreach $f (@Fields) {
		$cmd="$prog ISI.pl -OISIt $DSN $Table $f $DB_Path > ../Result/$DSN/$f.txt";
		&myexec($cmd);
	}
	$cmd="$prog ISI.pl -OISIt -OSC2C=ISI_SC2C.txt $DSN $Table SC $DB_Path > ../Result/$DSN/SC2C.txt";
	&myexec($cmd) if (defined $main::OSC2C); # added on 2019/08/25

# �P�~�N�@��e���R�G
	@Fields = split ' ', "AF AU DP IU C1 SC SO J9 TC";
	foreach $f (@Fields) {
		$ff = $f; $ff = "[$ff]" if $f eq 'IU';
		$cmd="$prog ISI.pl -OISIt -Ocr=100 $DSN $Table $ff $DB_Path > ../Result/$DSN/${f}_PY.txt";
		&myexec($cmd);
# fractional count �O���P�@�g�峹��n�ӧ@�̮ɡA�C�ӧ@�̲֭p1/n��
# �۹�� normal count�A�O���P�@�g�峹��n�ӧ@�̮ɡA�C�ӧ@�̲֭p1��
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

# �P�Q�ޥΦ��ư���e���R
  if (not $main::OBioAbs) {
	@Fields = split ' ', "AF AU DP IU C1 SC SO J9";
	foreach $f (@Fields) {
		$ff = $f; $ff = "[$ff]" if $f eq 'IU';
		$cmd="$prog ISI.pl -OISIt -Ocr=100 $DSN $Table \"$ff, TC\" $DB_Path > ../Result/$DSN/${f}_PY_TC.txt";
		&myexec($cmd);
# fractional count �O���P�@�g�峹��n�ӧ@�̮ɡA�C�ӧ@�̲֭p1/n��
# �۹�� normal count�A�O���P�@�g�峹��n�ӧ@�̮ɡA�C�ӧ@�̲֭p1��
		$cmd="$prog ISI.pl -OISIt -OfracCount -Ocr=100 $DSN $Table \"$ff, TC\" $DB_Path > ../Result/$DSN/${f}_PY_TC_fc.txt";
		# add if condition in the next line on 2019/08/25
		&myexec($cmd) if ($f eq 'AF' or $f eq 'AU' or $f eq 'IU' or $f eq 'C1');
# �p�� CPP �]Citations per Paper�^����
		$cmd="$prog ISI.pl -Omfd $f ../Result/$DSN > ../Result/$DSN/${f}_CPP.txt";
		# add if condition in the next line on 2019/08/25
		&myexec($cmd) if ($f eq 'AF' or $f eq 'AU' or $f eq 'IU' or $f eq 'C1');
	}
  }

	if ($main::OY5) { # added on 2019/0825
		&Aggregate5Year($DSN, $Table, $DB_Path);
	}

# �A�� DE�BID�BSC����줺�����J�A�b���D�P���夤�X�{����ҡG
	$cmd="$prog ISI.pl -Ochktm $DSN $Table $DB_Path "
		."> ../Result/$DSN/_${DSN}_stat.txt";
	&myexec($cmd) if not $main::OBioAbs;
# �έp���D�B�K�n����줧�r�ƻP�έp�ȡG
	$cmd="$prog ISI.pl -OavgCnt $option $DSN $Table $DB_Path "
		.">> ../Result/$DSN/_${DSN}_stat.txt";
	&myexec($cmd);

# �̫�A�N���G�ؿ��U���Ҧ���r�ɮסA��J�� Excel ��
	$cmd="$prog ISI.pl -O2xls -OmaxR=500 $DSN ../Result/$DSN "
	."../Result/$DSN/_${DSN}_by_field.xls";
	&myexec($cmd);
}

sub Aggregate5Year {
	my($DSN, $Table, $DB_Path, ) = @_; my($cmd, $f);
# �P�~�N����e���R����ơA���C���~�֭p���έp
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
# /*--�ѥع���R----------------------------------------------------------------------*/
	if ($main::OBC eq 'manual') { # �N���k�����A�ഫ��� doc/ �ؿ��U
		$cmd = "$prog Cluster.pl -Odebug -ObigDoc=manual -ODB=$DB_Path $DSN "
. "\"select UT, TI, AB from TPaper where UT=?\" $InDir ../doc/${DSN}_${BC}_S2";
		&myexec($cmd);
		$cut = &Clustering_BibCpl($DSN, $DB_Path, 2, $BC);
	} elsif ($main::OBC =~ /^JBC$|^ABC$/i) { # ���Z�ѥع� �B �@�̮ѥع�
		$BC = $main::OBC; $BC = uc $BC;
# �̷Ӵ��Z�W�ٱN�פ�����A�ϨC�@���]�t�@�Ӵ��Z���פ�
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
# ����ѥع���R�]�O�o���]�w DSN for $DSN.mdb.�^
# ����G�|����Result�ؿ��U����������ɡA�B���bDBMS��
# D:\demo\STPIWG\src>perl -s CiteAna.pl -Oclu $DSN TPaper $DSN_BibCpl ..\Result\$DSN_BibCpl
# Remark:
# $DSN : data source name (DSN)
# TPaper : table name in $DSN.mdb
# $DSN_BibCpl : index name (for internal system use)
# ..\Result\$DSN_BibCpl : index path name (real file folder name, created by CiteAna.pl. Note: index path should under STPIWG\Result\ )
	$OutDir = "../Result/${DSN}_$BC";
	$option = "-OmaxDF=$main::OmaxDF" if $main::OmaxDF > 0;
# 1. ���H�Τޥθ�Ƴ��bDBMS���A�����k���һݤ������ɮסG
#	 Titles.txt, Inv.txt, DocPath.txt, SortedPairs.txt
	$cmd = "$prog CiteAna.pl -Oclu $option -ODB=$DB_Path $DSN TPaper "
	 . "${DSN}_$BC $OutDir";
	&myexec($cmd);

# 2.�i��ۦ��פ��R�P�k���B��]�ھګe�@�B�J���ѥع���R���G, ���� Tree.txt�^
# perl -s Cluster.pl -Osim -Ocut=0.0 -Oct_low_tf=0 $DSN_BibCpl ..\Result\$DSN_BibCpl > ..\Result\$DSN_BibCpl\0_0.0.html
	$cmd = "$prog Cluster.pl -Osim -Odebug=1 -Ocut=0.0 -Oct_low_tf=0 "
		 . "${DSN}_$BC $OutDir > $OutDir/0_0.0.html";
	&myexec($cmd);

# 3. �Τ��P�ۦ��ת��e�����k�����G�A�õe�X�D�D�ϡ]���� SimPairs.txt, Coordinate.txt�^�G
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
# 5.2 ���b doc/ �ؿ��U�A���ޥθ�ƦbDBMS���A�����k���һݤ������ɮסG
#	 Titles.txt, Inv.txt, DocPath.txt, SortedPairs.txt
# perl -s CiteAna.pl -OMulClu $DSN TPaper $DSN_BibCpl_S2 ..\Result\$DSN_BibCpl_S2 ..\doc\$DSN_BibCpl_S2
# perl -s CiteAna.pl -OMulClu $DSN TPaper $DSN_BibCpl_S3 ..\Result\$DSN_BibCpl_S3 ..\doc\$DSN_BibCpl_S3
	$cmd = "$prog CiteAna.pl -OMulClu $option -ODB=$DB_Path $DSN TPaper "
	  . "${DSN}_$BC$nn $OutDir ../doc/${DSN}_$BC$nn";
	&myexec($cmd);

# 5.3 �i��ۦ��פ��R�P�k���B��]�ھګe�@�B�J���ѥع���R���G, ���� Tree.txt�^
# perl -s Cluster.pl -Osim -Ocut=0.0 -Oct_low_tf=0 -Odebug $DSN_BibCpl_S2 ..\Result\$DSN_BibCpl_S2 > ..\Result\$DSN_BibCpl_S2\0_0.0.html
# perl -s Cluster.pl -Osim -Ocut=0.01 -Oct_low_tf=0 -Odebug $DSN_BibCpl_S3 ..\Result\$DSN_BibCpl_S3 > ..\Result\$DSN_BibCpl_S3\0_0.01.html
	$cmd = "$prog Cluster.pl -Osim -Ocut=0.0 -Oct_low_tf=0 -Odebug "
		 . "${DSN}_$BC$nn $OutDir > $OutDir/0_0.0.html";
	&myexec($cmd);

# 5.4�Τ��P�ۦ��ת��e�����k�����G�A�õe�X�D�D�ϡ]���� SimPairs.txt, Coordinate.txt�^�G
	&Cluster_Map_MultiCut($DSN, $DB_Path, $n, $BC);

# 5.5�߰ݳ̫��ܪ����e�A�è̦����e���Τ������G
	$cmd = "$prog Cluster.pl -Osi ${DSN}_$BC$nn $OutDir";
	&myexec($cmd) if $main::Osi;
	$cut = &PromptMsg2($DSN, $n, $BC);
	&Cluster_Map_Cut($DSN, $DB_Path, $n, $cut, 3, $BC);
	&CrossTab_by_Cluster_and_Field($DSN, $DB_Path, $OutDir, $cut, $nn, $BC);
	return $cut;
}

sub Clustering_S1toS2 {
	my($DSN, $DB_Path, $n, $cut, $BC) = @_;
# 5. �N�p���k�������]����G�k�����G�bResult\�U�A�����bDBMS�^�G
# 5.1 ���N�k���᪺����X�� doc\ �ؿ��U
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
# 6. �N�����k����j���]����G�k�����G�bResult\�U�A�����b doc\�^�G
# 6.1���N�k���᪺����X�� doc\ �ؿ��U
# perl -s Cluster.pl -Odebug -ObigDoc -Ocut=0.01 -Oct_low_tf=0 $DSN_BibCpl_S2 ../Result/$DSN_BibCpl_S2 ../doc/$DSN_BibCpl_S3
	my $cmd = "$prog Cluster.pl -Odebug -ObigDoc -Ocut=$cut -Oct_low_tf=0 "
	. "${DSN}_${BC}_S$n1 ../Result/${DSN}_${BC}_S$n1 ../doc/${DSN}_${BC}_S$n";
	&myexec($cmd);
	return &Clustering_BibCpl($DSN, $DB_Path, $n, $BC);
}

# Use global variables : -Omin ($main::Omin)
sub CrossTab_by_Cluster_and_Field {
	my($DSN, $DB_Path, $OutDir, $cut, $nn, $BC) = @_;  my($out, $option, $cmd);
# 5.6�w��W�z�]5.5�^�o�X�����O�A�L�X�C�����O���U�ظ�ƪ����G���p�A����G
# perl -s tool.pl -OSC=all -Omin=2 $DSN TPaper ..\Result\$DSN_BibCpl\0_0.01.html > ..\Result\$DSN_BibCpl\0_0.01_all_2.html
	$out = "$OutDir/0_${cut}";
	$option = '-OBioAbs' if $main::OBioAbs;
# Generate HTML file
	$cmd = "$prog tool.pl -OSC=all -Omin=$main::Omin $option -ODB=$DB_Path "
		 . "$DSN TPaper ${out}.html > ${out}_all_${main::Omin}.html";
	&myexec($cmd);
  # �䤤all�N��p�U�����GPY AU SO SC CR C1�C�ƹ�W�A-OSC�]�i�H�]�w���A�Q�n���h�����A
  #   �u�n�Ρu���޸��v�A�_�ӡA���W�٤����ΪŮ�j�}�Y�i�C�Ҧp�G
  #perl -s tool.pl -OSC="PY AU SO CR" -Omin=2 $DSN TPaper ..\Result\$DSN_BibCpl\0_0.01.html > ..\Result\$DSN_BibCpl\0_0.01_4.html
  #�Y�n�N�ӧO��a�Ӥ��R�A����G�b�W�C�R�O���h�[ -Country=��a�N�� �Y�i�A�p�U�G
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

# 5.7�w��W�z�o�X�����O�A�L�X�C�����O�������D�H��������A����G
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
	$n_1 = (($n-1)<2)?'':'_S' . ($n-1);	# to draw circle label with ���O���Ǹ�
	$cut = '0.0' if $cut == 0;
	$OutDir   = "../Result/${DSN}_$BC$nn";
	$OutDir_1 = "../Result/${DSN}_$BC${n_1}";
# �Τ��P�ۦ��ת��e�����k�����G�G
# perl -s Cluster.pl -Ocut=0.01 -Oct_low_tf=0 $DSN_BibCpl ..\Result\$DSN_BibCpl > ..\Result\$DSN_BibCpl\0_0.01.html
	$cmd = "$prog Cluster.pl -Ocut=$cut -Oct_low_tf=0 ${DSN}_$BC$nn "
	. "$OutDir > $OutDir/0_${cut}.html";
	&myexec($cmd) if $option % 2 == 1; # if 1 or 3

	my($NumItems, $mapYes);
	$NumItems = &GetNumItems("$OutDir/0_${cut}.html");
# �e�X�D�D�ϡG
# perl -s Term_Trend.pl -Ocolor -Omap -Ocut=0.01 ../Result/$DSN_BibCpl
	$cmd = "$prog Term_Trend.pl -Ocolor -Omap -Ocut=$cut $OutDir";
	if (int($option / 2) == 1) { # if 2 or 3
		 # if small number of items, create maps unconditionally
		#myexec($cmd) if ($NumItems < 1000); # comment on 2019/08/27
	}  # if too many items, create MDS map may wait too long
	
# �e�XMDS�ϡA���O��餤���s���O���O���Ǹ��A���O�����k�����s��:
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


#----�@�{�r���R - Co-Word Analysis -----------------------------------------------
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
# /*--�ֶq����k�����R�]�̾ڤ�󪺼��D�B�K�n�ε��ۦ��ר��k���^
#  �]�֩�3000�g�A���O����RAM�j�p�өw�^--------------------------*/
# 1. �ǳƸ�ơG
# 1.1 �bSciE.mdb���A����d�ߡuInsert_Into_TSeg�v
#	 ��SQL�R�O���G
# INSERT INTO TSeg SELECT UT AS SNO, PY & ':' & TI AS Dname, AB AS Dscpt FROM TPaper;
#	 �H�K�N��ƪ�TPaper�������D�]TI�^�B�K�n�]AB�^�H�ΥD��]UT�^���J��ƪ�TSeg���C
# 1.2 �s��cluster.ini�H�W�[ SciE_dc ���s�աA�p�U�G
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

# 2. �����k���R�O�]���b��Ʈw���A�k�����G�]��b��Ʈw���A�ӫD Result/ �ؿ��U�^�G
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

# 5.4�Τ��P�ۦ��ת��e�����k�����G�A�õe�X�D�D�ϡG
	&Cluster_Map_MultiCut_dc($DSN, $DB_Path, $n, $low_df, $low_tf, $ct_low_tf, $CW);

# 5.5�߰ݳ̫��ܪ����e�A�è̦����e���Τ������G
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
# �̷Ӵ��Z�W�ٱN�פ�����A�ϨC�@���]�t�@�Ӵ��Z���פ�
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
# 5. �N���G�k����j���]�q��Ʈw��Ū�X���P�k�����G��ơA�ݭn��Ʈw�ﶵ�GOdsn�POtable�^
# 5.1�]���ΦA�s��cluster.ini�^�������橳�U���R�O�G
# perl -s auto.pl -Ocut=0.0 -Oold_cut=0.05 -Ouid=20 -Otfc=ChixTFC -Odsn=SciE -Otable=TSeg -Oold_ct_low_tf=1 -Olow_tf=2 -Oct_low_tf=2 SciE_dc SciE_dc_S2
# �W�z�R�O�|�bSTPIWG\src\Result\�U���ͷs��Ƨ�SciE_dc_S2�A
# ��Ƨ�����(DocPath.txt�BInv.txt�BSortedPairs.txt�BTitle.txt�BTree.txt)5���ɮ�
# ��(Coordinate.txt�BSimPairs.txt�Bmap_2_0.0.png�B2_2_2_0.0.html)
#	�PBibCpl���R�O���P
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
# 6. �N���G�k����j���]��󤣬O�b��Ʈw���A�ӬO�bSTPIWG\doc\�U�A�]���S��Odsn�POtable�ﶵ�^
# 6.1 �����k���G
# perl -s auto.pl -Ocut=0.0 -Oold_cut=0.05 -Otfc=ChixTFC -Oold_ct_low_tf=2 -Olow_tf=4 -Oct_low_tf=4 SciE_dc_S2 SciE_dc_S3
#	�P�B�J5���P
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
# 5.6�w��W�z�o�X�����O�A�L�X�C�����O���U�ظ�ƪ����G���p�A����G
# perl -s tool.pl -OSC=CR -Omin=2 SciE TPaper ..\Result\SciE_dc\2_1_1_0.05.html > ..\Result\SciE_dc\2_1_1_0.05_CR_2.html
	$option = '-OBioAbs' if $main::OBioAbs;
	$out = "$OutDir/${low_df}_${low_tf}_${ct_low_tf}_${cut}";
# Generate HTML file
	$cmd = "$prog tool.pl -OSC=all -Omin=$main::Omin $option -ODB=$DB_Path "
		 . "$DSN $main::Table ${out}.html > ${out}_all_${main::Omin}.html";
	&myexec($cmd);
  #�Y�n�N�ӧO��a�Ӥ��R�A����G�b�W�C�R�O���h�[ -Country=��a�N�� �Y�i�A�p�U�G
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

# 5.7�w��W�z�o�X�����O�A�L�X�C�����O�������D�H��������A����G
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
# �Τ��P�ۦ��ת��e�����k�����G�G
# perl -s Cluster.pl -Ocut=0.01 -Oct_low_tf=1 SciE_dc ..\Result\SciE_dc > ..\Result\SciE_dc\2_1_1_0.01.html
	$cmd = "$prog Cluster.pl -Ocut=$cut -Oct_low_tf=$ct_low_tf ${DSN}_${CW}$nn "
	. "$OutDir > $OutDir/${low_df}_${low_tf}_${ct_low_tf}_${cut}.html";
	&myexec($cmd) if $option % 2 == 1; # if 1 or 3

# �e�X�D�D�ϡG
# perl -s Term_Trend.pl -Ocolor -Ocut=0.05 -Omap ../Result/SciE_dc
	$cmd = "$prog Term_Trend.pl -Ocolor -Ocut=$cut -Omap $OutDir";
	#&myexec($cmd) if int($option / 2) == 1; # if 2 or 3 # comment on 2019/08/27
# �e�XMDS�ϡA���O��餤���s���O���O���Ǹ��A���O�����k�����s��:
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
# 5.	����@�{�r�k�����R�]�O�ofood03.mdb��DNS=food03�^
# (1)���]�w cluster.ini���s�աA�p�U�G
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

# (2)�}�Ҹ�Ʈw�ɮ�d:\demo\STPIWG\Source_Data\food03.mdb�A
#	����䤤���d�ߡuInsert_Into_TSeg�v�C
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

# �N�u��󶰡v���Ҧ�Cited References�^���X�Өò֭p��b�u��󶰡v�̳Q�ޥΪ����ơG
# 1. ����U�C�R�O�G�]�Y���e����L�A�i�H�ٲ��^
	if (not -r "../Result/$DSN/CR.txt") {
		$cmd = "$prog ISI.pl -OISIt $DSN $Table CR $DB_Path > ../Result/$DSN/CR.txt";
		&myexec($cmd);
	}
# 2. ���C��Cited Reference�ҹ����� UT. �`�N�G�o�@�B�ʧ@�]�\�|��O�ܤ[���ɶ��I�I�I 
# perl -s ISI_CR.pl -Omatch sam ..\Source_Data\sam\sam.mdb TPaper ../Result/sam/CR.txt ../Result/sam/CR_UT.txt > ..\Result\sam\CR_UT_stderr.txt
	my $CUf =  "../Result/$DSN/CR_UT"; my $CUfe = $CUf . '_stderr.txt'; $CUf .= '.txt';
	$cmd = "$prog ISI_CR.pl -Omatch $DSN $DB_Path $Table ../Result/$DSN/CR.txt $CUf > $CUfe";
	&myexec($cmd);
	print STDERR "\nPlease check $CUf to see if anything abnormal!\n" if ((-s $CUf)>0);
	# Total number of cited references: 72723 # It takes 1453 seconds
	# ���G�bCR_UT.txt�̡A�N��פJ��ICT.mdb��CR_UT��ƪ�̡C
# 3. �Q�ΤW�z���G�A�N�C�Ӥ��P��Cited References�ন��Ʈw���榡
# 	Note: the CR_UT below is a field name, not the file name
#   perl -s ISI_CR.pl -Ocite -Opair ICT TPaper CR_UT Cite > ..\Result\ICT\Cite.txt
#   �W�z���G Cite.txt �]�|�P�ɴ��J���Ʈw��Cite��ƪ�
	$cmd = "$prog ISI_CR.pl -Ocite -Opair $DSN $DB_Path $Table CR_UT > ../Result/$DSN/Cite.txt";
	&myexec($cmd);
# 4. �Q�ΤW�z���G�A�N�C�Ӥ�󪺻P��Cited References�ন���p�����榡�A�ѤU�@�B����
	$cmd = "$prog ISI_CR.pl -Ocite $DSN $DB_Path $Table CR_UT > ../Result/$DSN/CiteRT.txt";
	&myexec($cmd);
	$cmd = "$prog ISI_CR.pl -Ocite -Oau $DSN $DB_Path $Table CR_UT > ../Result/$DSN/CiteAU.txt";
	&myexec($cmd);
	$cmd = "$prog ISI_CR.pl -Ocite -Oj9 $DSN $DB_Path $Table CR_UT > ../Result/$DSN/CiteJ9.txt";
	&myexec($cmd);
# 5. �Y���ݭn�A�i�H�z��Hcited=Tsai, CC�����Y���Ҧ����G
#   perl -s filterRT.pl -Ocited="Tseng, YH" ..\Result\sam\CiteAU.txt > ..\Result\sam\CiteTsengYH.txt
	my $Oau = "Tseng, YH"; $Oau = $main::Oau if $main::Oau;
	$cmd = "$prog filterRT.pl -Ocited=\"$Oau\" ../Result/$DSN/CiteAU.txt > ../Result/$DSN/Cite${Oau}.txt";
	&myexec($cmd);
# 6. �N�W�z���G�নPajek���榡�A�ǳƵ�ı�ơG
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

#	�Ѽ�Oyear�i����ı�ƮɡA�`�I���Ө�~�N�ƧǡC�Ѽ�Opat�i��Jregular expression�r��A�H�K�u��ܥX�{�Ӧr�ꪺ�ޥ����Y�ϡC
#7. �N�W�z���G�A�নPajek�������榡�ɡA�H��s�u�]�ӫD�P���^�覡�s�����p���A�í���C�Ӹ`�I�̦h���s���ơG
#	perl -s filterRT.pl -Opajek -Ocir -OmaxDegree=4 ..\Result\ICT\CiteRT.txt > ..\Result\ICT\CiteRT_cir_4.net
}
