#!/usr/bin/perl -s
# https://stackoverflow.com/questions/728597/how-can-my-perl-script-find-its-module-in-the-same-directory
use File::Basename;
use lib dirname (__FILE__);
use SamOpt qw(SamOpt);  &SamOpt();
# This program is to process the related records on 2006/03/29 by Yuen-Hsien Tseng
use vars; use strict;
# use lib '/demo/DbXls';
# use DbXls;
use Spreadsheet::WriteExcel; 
# see http://lena.franken.de/perl_hier/excel.html for more examples
use Encode::TW; # this line must exist, despite we have the next line
use Encode qw/encode decode from_to/;
use Encode::Detect::Detector;
use Statistics::Regression;
use Math::MatrixReal; # Matrices are represented in Math::MatrixReal format
use SVD;
use SAMtool::Stem;
use SAMtool::SegWord;
use SAMtool::Progress;
use SAMtool::Stopword;
# use DBI ':sql_types';  require "InitDBH.pl"; # remark on 2019/01/24
use DBI ':sql_types'; # This is required to avoid: Bareword "DBI::SQL_LONGVARCHAR" not allowed while "strict subs" in use at ISI.pl line 591.ISI.pl had compilation errors.
use InitDBH qw(InitDBH); # Added on 2019/01/24
my $stime = time();

# perl -s ISI.pl -OBigDoc Sam_JBC c:\CATAR\Source_Data\Sam\Sam.mdb Journal ..\doc\Sam_JBC
# perl -s ISI.pl -OBigDoc Sam_ABC c:\CATAR\Source_Data\Sam\Sam.mdb Author ..\doc\Sam_ABC
if ($main::OBigDoc) { &ISI2BigDoc(@ARGV); &myexit(); }

# D:\demo\STPIWG\src>perl -s ISI.pl -OminDF=5 -OtermHis agr agr DE ..\Result\agr\agr_DE.txt  "1994 1995 1996 1997 1998 1999 2000 2001 2002 2003 2004 2005 2006"> ..\Result\agr\agr_DE_History.txt
# D:\demo\STPIWG\src>perl -s ISI.pl -OminDF=10 -OtermHis agr agr DE ..\Result\agr\agr_DE.txt  "1995 1996 1997 1998 1999 2000 2001 2002 2003 2004 2005"> ..\Result\agr\agr_DE_History95-05.txt
# Number of records: 73418. It takes 4 seconds
if ($main::OtermHis) { &Get_ISI_Term_history(@ARGV); &myexit(); }
# D:\demo\STPIWG\src>perl -s ISI.pl -OtermTrend ..\Result\agr\agr_DE_History95-05.txt "791 5448 6056 6363 6211 6773 7475 8028 7700 9187 9268" > ..\Result\agr\agr_DE_Trend95-05.txt
if ($main::OtermTrend) { &Get_ISI_Term_Trend(@ARGV); &myexit(); }
# perl -s ISI.pl -Ov -Onorm=abs ..\Result\InfoBank_S3\2_4_4_0.01_PY.txt
if ($main::Ov) { TimeSeriesMatrix_Conversion(@ARGV); &myexit(); }
# perl -s ISI.pl -OmergeTrend agr agr ..\Result\agr\agr_SC_DocList.txt ..\Result\agr_SC\term_cluster.html "1996 1997 1998 1999 2000 2001 2002 2003 2004 2005" "5448 6056 6363 6211 6773 7475 8028 7700 9187 9268" > ..\Result\agr_SC\agr_SC_clu0.0_Trend.txt
if ($main::OmergeTrend) { &MergeHistory(@ARGV); &myexit(); }

# perl -s ISI.pl -Obreakdown -Onorm=abs -Ob1=0.3371 agr agr JI ..\Result\agr\agr_SC_DocList.txt ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_Sorted_type.txt "1996 1997 1998 1999 2000 2001 2002 2003 2004 2005" "5448 6056 6363 6211 6773 7475 8028 7700 9187 9268" > ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_Sorted_type_JI.txt
# Use option: -OSkipEmpty
if ($main::Obreakdown) { &BreakDown(@ARGV); &myexit(); }
# perl -s ISI.pl -Oeet -Onorm=abs -Ob1=0.3371 ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_Sorted_type_C1_SVD.txt > ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_C1.txt
if ($main::Oeet) { &ExtractEigenTrend(@ARGV); &myexit(); }
# perl -s ISI.pl -Ofc=30 ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_Sorted_type_C1_SVD.txt > ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_Sorted_type_C1_8.txt
if ($main::Ofc) { &FilterCountry(@ARGV); &myexit(); }
	
# perl -s ISI.pl -Osample 0.5 ..\Result\agr_SC\term_cluster.html ..\Result\agr_SC\agr_SC_clu0.0_Trend.txt
if ($main::Osample) { &Sampling(@ARGV); &myexit(); }
if ($main::OmergeYear) { &MergeYear(@ARGV); &myexit(); }
if ($main::OYearRange) { &YearRange(@ARGV); &myexit(); }

if ($main::OSortByTrend) { &SortByTrend(@ARGV); &myexit(); }
if ($main::OInsertTrendType) { &InsertTrendType(@ARGV); &myexit(); }
	
# perl -s ISI.pl -OtermDoc -OminDF=10 agr agr SC ..\Result\agr\agr_SC.txt > ..\Result\agr\agr_SC_DocList.txt
if ($main::OtermDoc) { &Get_ISI_Term_DocList(@ARGV); &myexit(); }
# perl -s ISI.pl -OSFtmDoc -OminDF=2 EduEval EEPA318 "TI, AB" ..\Result\EEPA318\keys_rw.txt > ..\Result\EEPA318\keys_rw_DocList.txt
# perl -s ISI.pl -OSFtmDoc -OminDF=2 -ODBID=ID ItaA TSeg "DName, Dscpt" ..\Result\ItaA\ItaA_key_rt.txt > ..\Result\ItaA\ItaA_key_rt_DocList.txt
if ($main::OSFtmDoc) { &Get_Selected_Free_Term_DocList(@ARGV); &myexit(); }

# It seems that ACCESS cannot import ISIAll.txt due to its size.
#  So let's split ISIAll.txt into several small files.
# D:\demo\STPIWG\Source_Data>perl -s ..\src\ISI.pl -Osplit  ISIAll.txt ISI
# It takes about 120 seconds.
if ($main::Osplit) { &SplitFiles(@ARGV); &myexit(); }
if ($main::Ot2p) { &ConvertTabDelimited2PlainText(@ARGV); &myexit(); }
# perl -s ISI.pl -OISIt File_NanoPaperTW NanoPaperTW [DE|IT|SC]
# perl -s ISI.pl -OISIt NanoPaperWD ISIAll_NoDup SC
# perl -s ISI.pl -OISIt -OSC2C=SC2C.txt envi01 TPaper "SC PY" ..\Source_Data\envi01\envi01.mdb
if ($main::OISIt) { &Get_ISI_Terms(@ARGV); &myexit(); }
# perl -s ISI.pl -Oj9X SC_Edu TPaper C1 ..\Source_Data\SC_Edu\SC_Edu.mdb > ..\Result\SC_Edu\J9_C1.txt
if ($main::Oj9X) { &Get_ISI_J9X(@ARGV); &myexit(); }
# perl -s ISI.pl -OAUCA ..\Result\SC_Edu\AU.txt ..\Result\SC_Edu\CA.txt >  ..\Result\SC_Edu\AU_CA.txt
if ($main::OAUCA) { &AU_CA(@ARGV); &myexit(); }
# perl -s ISI.pl -O2xls -OmaxR=200 envi01 ..\Result\envi01 ..\Result\envi01\envi01_by_field.xls
# perl -s ISI.pl -O2xls=2 -Of=..\Result\envi01_dc_S4\2_6_6_0.05_all_2.txt envi01_dc_S4 ..\Result\envi01_dc_S4 ..\Result\envi01_dc_S4\envi01_dc_S4_by_field.xls
if ($main::O2xls) { &Insert2Excel(@ARGV); &myexit(); }
# perl -s ISI.pl -OmCR SC_EF TPaper ..\Source_Data\SC_EF\SC_EF.mdb > ..\Result\SC_EF\SOmCR.txt
if ($main::OmCR) { &Match_with_CR(@ARGV); &myexit(); }


# perl -s ISI.pl -OY5 ..\Result\food\C1_PY.txt > ..\Result\food\C1_PY_5.txt
if ($main::OY5) { &Every5Years(@ARGV); &myexit(); }
# perl -s ISI.pl -OPYCPP ..\Result\Edu0012\C1_PY_5.txt ..\Result\Edu0012\C1_PY_TC_5.txt > ..\Result\Edu0012\C1_PY_CPP_5.txt
if ($main::OPYCPP) { &ComputePYCPP(@ARGV); &myexit(); }
# perl -s ISI.pl -Om2f ..\Result\Edu0512_JBC_S2\2_eLearn.txt ..\Result\Edu0512_JBC_S2\5_SciEdu.txt > ..\Result\Edu0512_JBC_S2\2_and_5.txt
if ($main::Om2f) { &MergeTwoFields(@ARGV); &myexit(); }

# perl -s ISI.pl -Omfd DP ..\Result\NTNU > ..\Result\NTNU\DP_IF.txt
if ($main::Omfd) { &MergeFieldDistribution(@ARGV); &myexit(); }

# perl -s ISI.pl -Omi=9 ..\Result\food\MI.txt > ..\Result\food\MI.htm
if ($main::Omi) { &OrganizeMI(@ARGV); &myexit(); }
# perl -s ISI.pl -OinsTerms InfoBank TPaper "TI,AB" SC D:\STPI\2008_Project\data\product.txt 
if ($main::OinsTerms) {&InsertTerms2Field(@ARGV); &myexit(); }
# perl -s ISI.pl -Omtd ..\Result\NanoPaperTW_SC.txt ..\Result\NanoPaperWD_SC.txt
if ($main::Omtd) { &MergeTermDistribution(@ARGV); &myexit(); }
# perl -s ISI.pl -Ochktm EduEval EEPA318 (to check the overlap of terms in [DE|SC\ID] and TI+AB)
if ($main::Ochktm) { &CheckTerm(@ARGV); &myexit(); }
# perl -s ISI.pl -OavgCnt EduEval EEPA318 (to check the word count in TI and AB)
if ($main::OavgCnt) { AvgWordCount(@ARGV); &myexit(); }
# perl -s ISI.pl -O2DB food01 TPaper ..\Source_Data\food01\food01.mdb ..\Source_Data\food01\food01_all.txt
if ($main::O2DB) { &InsertIntoDBMS(@ARGV); &myexit(); }
# perl -s ISI.pl -O2Tseg food01 TPaper TSeg ..\Source_Data\food01\food01.mdb	
if ($main::O2Tseg) { &InsertIntoTseg(@ARGV); &myexit(); }
	
sub myexit { print STDERR "# It takes ", time()-$stime, " seconds\n\n"; exit; }

# Global variables :
my @AllFields = split /\s+/, "
	PT	AU	BA	ED	GP	AF	CA	TI	SO	SE	
	LA	DT	CT	CY	CL	SP	HO	DE	ID	AB	
	C1	RP	EM	CR	NR	TC	PU	PI	PA	SN	
	BN	DI	J9	JI	PD	PY	VL	IS	PN	SU	
	SI	BP	EP	AR	DI	PG	SC	GA	UT"; 
# Actually, @AllFields is not used. It is here only for human inspection.
my (%UsefulFields, @UsefulFieldIndex, $AU_idx, $AF_idx, $C1_idx, $AB_idx);
# add the field: 'IU': the institute of the authors on 2009/01/30
#my @UsefulFields = split ' ', "AU AF TI SO DE ID AB C1 CR NR TC J9 PY VL BP SC UT";
my @UsefulFields = split ' ', "AU AF TI SO DE ID AB C1 CR NR TC J9 PY VL BP SC LA UT"; # add LA on 2012/10/02, 2019/09/01
# @UsefulFields = split ' ', "AU TI SO PY VL AB C1 BP MC CC TA DS CH MQ PR MI UT"
@UsefulFields = split ' ', "AU AF TI SO PY VL AB C1 BP MC CC MI UT" 
	if $main::OBioAbs;
#print STDERR join(", ", @UsefulFields), "\n"; exit;
$AU_idx = 0; # the index is for the above, $UsefulFields{AU} = $AU_idx
$AF_idx = 1; # the index is for the above, $UsefulFields{AF} = $AF_idx
$AB_idx = 6; # the index is for the above, $UsefulFields{AB} = $AB_idx
$C1_idx = 7; # the index is for the above, $UsefulFields{C1} = $C1_idx
# These above 3 variables can be replaced with the following hash %UsefulFields
for(my $i=0;$i<@UsefulFields;$i++){$UsefulFields{$UsefulFields[$i]}=$i;}
# %UsefulFields contains, for example, AU as its key and 0 as its value
my ($n, $m) = &ParseISI(@ARGV);
print STDERR "There are $n records.\n";
print STDERR "There are $m records whose fields do not match.\n";
&myexit();

# Use option : $Ocountry : to print the countries of all papers
# Use option : $OCPI : CPI (Cited Paper Id) is the file's basename which
#	 indicates the cited paper id (the papers who cites that paper id are
#	 all listed in the file.)
sub ParseISI {
	my($FileList) = @_;
	my(@FL, $f, $line, @Fields, $iFile, $CPI);
	my(%UT, %Country, $m, $n, $TabDelimited);
#print "country=$main::Ocountry, OdelDup=$main::OdelDup\n"; exit;
	open FL, $FileList or die "Cannot read file:'$FileList'";
	@FL = <FL>; chomp @FL;
	close(FL); 
	$n = 0;  # if ($ckhfmt) {count the number of files}else{count all records}
	$m = 0; # number of records whose fields do not match
	foreach $f (@FL) {
#print STDERR "$f\n";
		next if $f =~ /^#|^\s*$/g; # skip if comment or empty lines 
		if ($f =~ /(\d+)(-\d+)?(.txt)$/i) { $CPI = $1; } else { $CPI = ''; }
		open F, $f or die "Cannot read file:'$f'";
		$line = <F>; chomp $line; $iFile++;
		@Fields = split ' ', $line; # 2007/07/27
		if ($line =~ /\tUT$/) { # tab-delimited format
			$TabDelimited = 1;
			($AU_idx, $AF_idx, $C1_idx, $AB_idx, @UsefulFieldIndex) 
			= &SetFieldIndex($line); # reset %UsefulFields
		} else { 
			$TabDelimited = 0; #<F>; # read off version line # 2012/01/04
		}
		($n++ and next) if $main::Ochkfmt; # 2011/11/11
		
		if ($iFile == 1) { # print field names at the first line
			if (not $main::Ocountry) {
				print "CPI\t" if $main::OCPI;
				#print join("\t", @UsefulFields), "\tIN\n"; # 2009/01/30
#				print join("\t", @UsefulFields), "\tIN\tDP\n"; # 2010/03/22
				print join("\t", @UsefulFields), "\tIU\tDP\n"; # 2017/08/28
			}
		}
		if ($TabDelimited) { # parsed data are print out to Standard Output
			($n,$m)=&ParseLineRecord(*F{IO},\%UT,\%Country,$n,$m,$CPI,\@Fields);
		} else { # parsed data are print out to Standard Output
			($n,$m)=&ParseMultiLineRecord(*F{IO},\%UT,\%Country,$n,$m,$CPI);
		}
		close(F);
	}
	return ($n, $m) if (not $main::Ocountry) ;
# print out authors' countries
	foreach my $addr (sort {$Country{$b} <=> $Country{$a}} keys %Country) {
		print "$addr\t$Country{$addr}\n";
	}
} # End of &ParseISI()


# Use and reset global var.: %UsefulFields
#	 return var.: @UsefulFieldIndex, $C1_idx, $AB_idx, $AU_idx, $AF_idx
sub SetFieldIndex { # given the line of fields
	my($line) = @_;  my(@Fields, $i, $j, @UsefulFieldIndex, %UF2Idx);
	@Fields = split ' ', $line; # 2007/07/27
	for($i=0, $j=0; $i<@Fields; $i++) { # $i : the index of all fields from input
		if (defined $UsefulFields{$Fields[$i]}) { # $j : the index of useful fields
			$UsefulFieldIndex[$j] = $i; 
			$C1_idx = $j if $Fields[$i] eq 'C1';
			$AB_idx = $j if $Fields[$i] eq 'AB';
			$AU_idx = $j if $Fields[$i] eq 'AU';
			$AF_idx = $j if $Fields[$i] eq 'AF';			
			$UF2Idx{$Fields[$i]} = $j; # mapping field name to field index
			$j++;
		}
	}
	die "Some important fields are missing:\n$line\n" 
		if $j != scalar keys %UsefulFields;
#	for(my $i=0;$i<@UsefulFields;$i++){$UsefulFields{$UsefulFields[$i]}=$i;}
	while (($i, $j) = each %UF2Idx) { $UsefulFields{$i} = $j; } # reset %UsefulFields
  if ($main::Odebug>1) {
	print STDERR "\%UsefulFields=\n", join("\n", map{"$_\t$UsefulFields{$_}"} 
		sort {$UsefulFields{$a}<=>$UsefulFields{$b}} keys %UsefulFields), "\n";
	print STDERR "\@UsefulFieldIndex=@UsefulFieldIndex\n";
  }
	return ($AU_idx, $AF_idx, $C1_idx, $AB_idx, @UsefulFieldIndex);
}

# Convert the data in some fields of @D to standard form 
#   and grow @D with IU, DP.
# Change @D, %Country
# Use global: $AU_idx, $C1_idx, $AB_idx, $AF_idx, %UsefulFields
sub StandardizeFields {
	my($rD, $rCountry) = @_;  
	my(@Addresses, %Cntry, $iw, @A, $addr, @IU, %IU, %DP, $d, @Au, $au);
# Add next line on 2019/09/10
	$rD->[$UsefulFields{SO}] = &Normalize_Terms($rD->[$UsefulFields{SO}], 'SO');
	$rD->[$UsefulFields{SC}] = &Normalize_Terms($rD->[$UsefulFields{SC}], 'SC');
	$rD->[$UsefulFields{DE}] = &Normalize_Terms($rD->[$UsefulFields{DE}], 'DE');
	$rD->[$UsefulFields{ID}] = &Normalize_Terms($rD->[$UsefulFields{ID}], 'ID');

#print "\$rD->[$AU_idx]=$rD->[$AU_idx]\n";
	$rD->[$AU_idx] = &Normalize_Authors( $rD->[$AU_idx] ); # authors
#print "\$rD->[$AU_idx]=$rD->[$AU_idx]\n";
# Now delete copyright information
#	$rD->[$AB_idx] =~ s/\(C\) (19|20)\d\d *Elsevier .+ All rights reserved.\s*$//i;
	$rD->[$AB_idx] =~ s/\(C\)\s*(19|20)\d\d\s*.+\s*(reserved|\w+)\.?\s*$//i;
	# (C) 2008 Elsevier B.V. All rights reserved.
	# (C) 2008 American Institute of Physics.
	# (C) 2009 Society of Chemical Industry
	# (C) 2009 by the American College of Cardiology Foundation
	# end with (J Clin Endocrinol Metab 95: 894-902, 2010)
	$rD->[$AB_idx] =~ s/\([^)]+(19|20)\d\d\)\s*$//;
	# end with FASEB J. 24, 158-172 ( 2010). www.fasebj.org
	$rD->[$AB_idx] =~ s/^\s*(Context|BACKGROUND|Objectives):?\s*//i;
#print "AB=$rD->[$AB_idx]\n";# if  $rD->[$UsefulFields{UT}] =~ /BIOABS:BACD200900471768/;

# Now get the countries of authors from field C1
#print STDERR "$Data[$C1_idx]\n";
# From WoK:
# Example 1:
#  AU Lee, LC
#     Chen, CM
#     Wang, PR
#     Su, MT
#     Lee-Chen, GJ
#     Chang, CY
#  AF Lee, Li-Ching
#     Chen, Chiung-Mei
#     Wang, Pin-Rong
#     Su, Ming-Tsan
#     Lee-Chen, Guey-Jen
#     Chang, Chun-Yen
#  C1 [Lee, Li-Ching; Wang, Pin-Rong; Su, Ming-Tsan; Lee-Chen, Guey-Jen] Natl Taiwan Normal Univ, Dept Life Sci, Taipei, Taiwan.
#     [Chen, Chiung-Mei] Chang Gung Univ, Coll Med, Dept Neurol, Chang Gung Mem Hosp, Taipei, Taiwan.
#     [Chang, Chun-Yen] Natl Taiwan Normal Univ, Sci Educ Ctr, Taipei, Taiwan.
#  PY 2014
#
# Example 2: N authors, single address
#  AU Dundes, L
#     Harlow, R
#  AF Dundes, L
#     Harlow, R
#  C1 McDaniel Coll, Dept Sociol, Westminster, MD 21157 USA.
#  PY 2015
#
# Example 3: N authors, M addresses
#  AU Monkman, K
#     Ronald, M
#     Theramene, FD
#  AF Monkman, K
#     Ronald, M
#     Theramene, FD
#  C1 Depaul Univ, Chicago, IL 60604 USA.
#     Florida State Univ, Tallahassee, FL 32306 USA.
#  RP Monkman, K (reprint author), Depaul Univ, Chicago, IL 60604 USA.
#  PY 2005
# From BioAbs
#  C1 SUMMERFIELD F W ; DEP FOOD SCI TECHNOL, UNIV CALIF, DAVIS, CA 95616, USA
#  C1 Ishigami, Akihito; Toho Univ, Dept Biochem, Fac Pharmaceut Sci, 2-2-1 Miyama, Chiba 2748510, Japan
# 
# On 2015/12/08, try to match the authors with their institutes
#  but as shown in the above Example 3, this attempt is impossible.
# I can only match those new records with the format:
#  [AF1; AF2; ..] IU, DP, ..., C1
# and change the content of AF
  my @AFs = (); my @AF = (); my($IU);
	while ($rD->[$C1_idx] =~ /\[([^\]]+)\]\s*([^,]+),/g) {
		@AF = split /;\s*/, $1; # $IU = $2; 
		# change the above line into next lines on 2019/08/26
		$IU = &Normalize_Terms($2, 'IU');
		@AF = map {&Normalize_Author($_) .": $IU"} @AF;
		push @AFs, @AF;
	}
	# $rD->[$AF_idx] = join "; ", @AFs; # remarks on 2019/01/14
	$rD->[$AF_idx] = join "; ", @AFs if @AFs > 0; # 2019/01/14
	
# Now resume to the old way:
	$rD->[$C1_idx] =~ s/\[[^\]]+\]//g; # delete parenthesized authors
#	@Addresses = split /;\s*/, $rD->[$C1_idx]; # addresses of authors
	@Addresses = split /;\s*|\.\s*\n\s*/, $rD->[$C1_idx]; # 2010/03/22
	@Addresses = ($rD->[$C1_idx]) if $main::OBioAbs; # addresses of authors
	$iw = 0; # to preserve the original order while delete duplicates
	foreach $addr (@Addresses) {
#print STDERR "addr='$addr'\n" if $rD->[@$rD-1] eq 'BIOABS:BACD198579018071';
		$iw++;
		if ($main::OBioAbs) {
			if ($addr=~/;\s*([^,]+)\s*,\s*([^,]+)\s*,/) {
				$d = join(' ', map {ucfirst lc} split(' ', $1));
				$IU{$d} += 1/($iw * $iw); 
#				$d = ucfirst lc $2;
				$d = join(' ', map {ucfirst lc} split(' ', $2));
				$DP{$d} += 1/($iw * $iw); 
			}
		} else {
			@IU = split /,\s*/, $addr; # 2009/01/30
			$IU[0] =~ s/^\s*|\s*$//g; # 2010/05/04
			$IU[0] = join(' ', map {ucfirst lc} split(' ', $IU[0])); # 2011/04/04
			$IU{$IU[0]} += 1/($iw * $iw); # the first field is the institute name
#			$d = ucfirst lc $IU[1];
			$d = join(' ', map {ucfirst lc} split(' ', $IU[1]));
			$DP{$d} += 1/($iw * $iw); # the 2nd field is the Dept name
		}
#		@A = split /\s+|,/, $addr; 
		@A = split /,\s*/, $addr; 
		$addr = $A[$#A]; # last field is country
#print STDERR "$rD->[@$rD-1]\t$rD->[$C1_idx]\n" if $addr =~ /\d/;
		$addr =~ s/\"//g; # delete abnormal character
		$addr = uc $addr; # convert to upper cases for consistency
		$addr =~ s/\.\s*$//; # delete ending period
		if ($addr =~ /\d|USA/) { $addr = 'USA'; } # rule for USA
#		if ($addr =~ /^[A-Z][A-Z]$/) { $addr = 'USA'; } # rule for USA, only valid for 1990-1999 data
# The above line is replaced by the next lines on 2019/01/14
		elsif ($addr =~ /^[A-Z][A-Z]$/ and @A<=3) { $addr = 'USA'; } # rule for USA, only valid for 1990-1999 data
		elsif ($addr =~ /ENGLAND|SCOTLAND|WALES/i) { $addr = 'UK'; }
		elsif ($addr =~ /CHINA/) { $addr = 'CHINA'; }# /PEOPLES R CHINA/
		
# For analysis of Asian countries in Science Education, last 2nd field is Hong Kong area
		if ($A[$#A-1] =~ /Hong Kong/i) { $addr = 'Hong Kong';} # added on 2014/09/18

#print STDERR join(', ', @A, "addr=$addr\n");
		$rCountry->{$addr}++;  $Cntry{$addr} += 1/($iw * $iw);
	}
	$rD->[$C1_idx]=join("; ", sort {$Cntry{$b}<=>$Cntry{$a}} keys %Cntry);
# The next two fields will grow the length of @D
#	push @$rD, join("; ", sort {$IU{$b}<=>$IU{$a}} keys %IU); # 2009/01/30
	$rD->[@$rD]=join("; ", sort {$IU{$b}<=>$IU{$a}} keys %IU); #2010/05/10
#print STDERR "$rD->[$C1_idx]\n";
#	change %Country and @D
#	push @$rD, join("; ", sort {$DP{$b}<=>$DP{$a}} keys %DP); # 2010/03/??
	$rD->[@$rD]=join("; ", sort {$DP{$b}<=>$DP{$a}} keys %DP); #2010/05/10
}

# for each file, read a record one by one
sub ParseLineRecord {
	my($Fh, $rUT, $rCountry, $n, $m, $CPI, $rFields) = @_; 
	my($i, @Data, @D, $d);
	$i=0;
	while (<$Fh>) {
		$i++; chomp; 
		@Data = split /\t/, $_;
		splice(@Data, 3, 1) if $main::Oesi; # 2007/10/15
		if (@Data != @$rFields) { 
			warn "Fields mismatch at $i-th line of file:$Fh, fields=", scalar @Data,"\n"; 
			$m++;
			next; 
		}
# Now check if it exists before? If yes, skip, if no, write it out
#print "Before: \$rUT->{\$Data[$UsefulFields{UT}]}=$rUT->{$Data[$UsefulFields{UT}]}\n" if $main::Odebug;
		if ($main::OdelDup and $rUT->{$Data[$#Data]}) { next; } # last field (UT) is the key
#		if ($main::OdelDup and $rUT->{$Data[$UsefulFields{UT}]}) { next; } 
#print "After: \$rUT->{$Data[$UsefulFields{UT}]}=$rUT->{$Data[$UsefulFields{UT}]}\n" if $main::Odebug;
		$rUT->{$Data[$#Data]} = 1;  # last field (UT) is the key
#		$rUT->{$Data[$UsefulFields{UT}]} = 1;  # 2011/04/05

		@D = @Data[@UsefulFieldIndex];
		foreach $d (@D) { $d =~ s/\s+/ /g; }
		&StandardizeFields(\@D, $rCountry);
# write it out
#print STDERR "i=$i Fh=$Fh, => $_\n";
		if (not $main::Ocountry) {
			print "$CPI\t" if $main::OCPI;
			print join("\t", @D), "\n"; 
			$n++;
		}
	}
#print STDERR "i=$i, Fh=$Fh\n";
	return ($n, $m); # change %UT, %Country
}

sub ParseMultiLineRecord {
	my($Fh, $rUT, $rCountry, $n, $m, $CPI) = @_;
	my($line, @Lines, @D, $i, $field, $j, $d, $rec);
#	local($/); $/="ER\n\n";
#	while (<$Fh>) { # read a multiline record one at a time
#		@Lines = split /\n/, $_;
	local($/); undef $/; my $all = <$Fh>;  # get all content in one read
	my @Rec = split /[\n\r]+ER[\n\r]+/, $all; # 2015/11/06
	warn "Num. of Records:", scalar (@Rec)-1, "\n"; # 2015/11/06
#	foreach $rec (split /\bER[\n\r]+/, $all) { # 2012/01/04
	foreach $rec (@Rec) { # 2015/11/06
		@Lines = split /[\n\r]+/, $rec;
		@D = (); # reset @D, set its element to empty in next line
		for($i=0; $i<@UsefulFields; $i++) { $D[$i] = ''; } # 2010/05/10
		for($i=0; $i<@Lines; $i++) {
			$field = substr($Lines[$i], 0, 2);
			if (defined $UsefulFields{$field}) { # seek to next field
				for($j=$i+1; substr($Lines[$j], 0, 2) eq '  '; $j++) {}
# Next 2 lines are remarked on 2015/11/06 for not-only-articles publications
#			} elsif ($field eq 'DT' and $Lines[$i] !~ /Article/) { # 2013/07/28
#				goto SkipTheRecord;  # 2013/07/28
			} else { next; } # seek to a useful field
#print  "field=$field, \$Lines[$i]=", substr($Lines[$i], 0, 20), ", \$Lines[$j]=", substr($Lines[$j], 0, 20), "\n";
		# Now the data in the useful field is from $i to $j-1
			$Lines[$i] =~ s/^$field/  /; # replace the field name with blanks
# Different field needs different processing
#			if ($field =~ /TI|AB|DE|ID|SO|SC|NR|TC|PY|UT|J9|VL|BP|MC|CC|MI/) {
			if ($field =~ /TI|AB|DE|ID|SO|SC|NR|TC|PY|UT|J9|VL|BP|MC|CC|MI|LA/) { # add LA on 2012/10/02, 2019/09/01
				$d = join(' ', @Lines[$i..($j-1)]);
#			} elsif ($field =~ /AU|AF|CR|C1/) { 
			} elsif ($field =~ /AU|AF|C1/) { # replace above line on 2020/02/18
				$d = join('; ', @Lines[$i..($j-1)]);
				$d = join(' ', @Lines[$i..($j-1)]) if $main::OBioAbs and $field=~/C1/;
			} elsif ($field =~ /CR/) { # add this block on 2020/02/18
				foreach my $cr (@Lines[$i..($j-1)]) {
					$cr =~ s/;.{1,5}$//; # delete trailing string of length <= 5
				}
				$d = join('; ', @Lines[$i..($j-1)]);
				$d = join(' ', @Lines[$i..($j-1)]) if $main::OBioAbs and $field=~/C1/;
#print STDERR "d=$d\n" if $d=~/DOI; /;
				$d =~ s/DOI; /DOI/g; # some DOI runs away to the next line
			} else { $d = ''; }
# Standardize fields
			$d =~ s/\s+/ /mg; # replace multiple blanks (newlines) with a blank
			$d =~ s/^\s+|\s+$//g; # delete the leading and trailing blanks
			$d =~ s/\([^)]+\)//g if ($field =~ /AU/);  # delete email in ()
			if ($field =~ /PY/ and $d =~ /(\d\d\d\d)\-\d\d\d\d/) { $d = $1; }
			if ($field eq 'SO') { # Added on 2019/09/01
				if ($d =~ /,/) {
					warn("\nSO: $d\n  trancated into '$`'");
					$d = $`;
				}
			}
# MI age influence, chicken breast fillet (poultry product, quality), cook
#	yield, fluid loss, postchill carcass aging duration, shear force values
# MI food chemistry, meat (biochemical analysis, meat product, quality),
# MI Japanese radish pickles (ethnic food, microbial analysis, preparation,
#	vegetable), food industry, food microbiology, methodology, yeast
			if ($field =~ /MI/) { 
				$d =~ s/\(([^,\)]+),\s+([^,\)]+)\)/\($1\-$2\)/g; # change comma in parenthesis into
				$d =~ s/\(([^,\)]+),\s+([^,\)]+),\s+([^,\)]+)\)/\($1\-$2\-$3\)/g;
				$d =~ s/,/;/g;	 $d = lc $d; 
			}
#			if ($field =~ /DS/) { $d =~ s/ (MeSH)//; $d = lc $d; }
#print STDERR "d=$d\n" if $field eq 'AB' and $Lines[1] =~ /BIOABS:BACD200900471768/;
			$D[$UsefulFields{$field}] = $d; # put $d in @D
#print "\$D[$UsefulFields{$field}]=$field=d=$d\n" if $Lines[1] =~ /BIOABS:BACD200900471768/;;
#print "i=$i,j=$j,\$D[$UsefulFields{$field}]=$field=d=$d\n"; 
			$i = $j-1; # move to the next field
		}
#print "i=$i, \@Lines=", scalar @Lines,", \$Lines[$#Lines]='$Lines[$#Lines]'\n";
#print "\$rec='$rec'\n";
#		next if @D == (); # replaced by next line on 2010/05/10
		next if $D[$UsefulFields{UT}] eq ''; # skip if UT field is empty
#		($m++ and next) if $D[$UsefulFields{UT}] eq ''; # 2011/11/10
# Now check if it exists before? If yes, skip, if no, write it out
		if ($main::OdelDup and $rUT->{$D[$UsefulFields{UT}]}) { next; } 
		if ($rUT->{$D[$UsefulFields{UT}]}) { # on 2015/11/06
			warn "Duplicate record in $ARGV at $.th record\n";
		}
		$rUT->{$D[$UsefulFields{UT}]} = 1;  # last field (UT) is the key
		&StandardizeFields(\@D, $rCountry); # grow @D with two fields: IU, DP
# write it out
#print STDERR "i=$i Fh=$Fh, => $_\n";
		if (not $main::Ocountry) {
			print "$CPI\t" if $main::OCPI;
			print join("\t", @D), "\n"; 
			$n++;
		}
#exit;
SkipTheRecord:  # 2013/07/28
	}
	$/ = "\n";
	return ($n, $m); # change %UT, %Country
}


# Given a folder contains tab-delimited ISI data files,
#   convert each of them into a file whose format is in plain text
# perl -s ISI.pl -Ot2p InDir OutDir
# or only a file a specified, the output should be directed to a file
# perl -s ISI.pl -Ot2p InDir/f.txt > OutDir/download_f.txt
sub ConvertTabDelimited2PlainText {
	my($dir, $dir2) = @_; my($f, @Files, $out, @Fields, $outfile, $base);
	if (-d $dir) {  @Files = glob("$dir/*.txt");
	} elsif (-r $dir) { @Files = ($dir); } 
	else { die "'$dir' is neither a folder nor a file"; }
	if ($dir2 ne '' and not -d $dir2) { 
		mkdir($dir2, 0777) or die "cannot mkdir :'$dir2'"; 
	}
	foreach $f (@Files) {
		$out = "FN ISI Export Format\nVR 1.0\n";
		open F, $f or die "Cannot read file: '$f'";
		$_ = <F>; chomp; @Fields = split /\t/, $_;
		while (<F>) {  chomp; $out .= &ToPlainText($_, \@Fields) . "ER\n\n";  }
		close(F);
		if (-d $dir2) { 
			if ($f =~ m|[\/\\]([^\/\\]+)$|) { $base = $1; } else { $base ++; }
			$outfile = "$dir2/download_$base";
			open O, ">$outfile" or die "Cannot write to file:'$outfile'";
			print O $out , "EF\n";
			close(O);
		} else { print $out; } # print to standard output
	}
}

sub ToPlainText {
	my($in, $rFields) = @_; my(@In, $i, $str, @Lines, $line, $len);
	@In = split /\t/, $in;
	die "Fields mismatch: Field_Name has ", scalar @$rFields, " fields, ",
		", but data has ", scalar @In, " fields.\n" if @$rFields != @In;
	for ($i=0; $i<@In; $i++) {
		next if $In[$i] eq '';
		if ($In[$i] =~ /;/ and $rFields->[$i] =~ /AU|AF|CR|C1/) {
			@Lines = split /; ?/, $In[$i];
			$str .= $rFields->[$i] . ' ' . join("\n   ", @Lines). "\n";
		} else { # single line would suffice
#			$str .= "$rFields->[$i] $In[$i]\n";
			$line = "$rFields->[$i] "; $len = 3;
			@Lines = split ' ', $In[$i];
			foreach $i (@Lines) { 
				if ($len >=70) { $len = 3; $line .= "\n   "; }
				$len += length($i)+1;
				$line .= $i . ' ';
			}
			$str .= $line . "\n";
		}
	}
	return $str;
}

sub InsertIntoDBMS {
	my($DSN, $Table, $DB_Path, $ISI_File) = @_;  
	my($DBH, $sql, $sth, $str, $field, @Field, @F, $line);
	my($i, $j, $k, $l) = (0, 0, 0, 0);
	my %Long = ('AB'=>'SQL_LONGVARCHAR', 'CR'=>'SQL_LONGVARCHAR'); #, ''=>1, ''=>1, ''=>1, ''=>1, );
	$DBH = &InitDBH($DSN, $DB_Path);
# Before insertion, delete the records in $Table
	$sql = "Delete from $Table";
	$sth = $DBH->prepare($sql);
	eval { $sth->execute(@F) or die $DBH->errstr; };
	print STDERR "Failed to delete: $sql" if ($@);
# Now read records and insert into $Table
	open F, $ISI_File or die "Cannot open '$ISI_File' to read\n";
	$field = <F>; chomp $field; @Field = split /\t/, $field;
	while ($line = <F>) {
#		chomp; @F = split /\t/, $line, scalar @Field; # 2011/11/10
		chomp $line; @F = split /\t/, $line; # will strip off last empty elements
		# perl -e "$a='1,,,'; @a=split/,/,$a; print scalar @a" => 1, not 4!!!
		$i++;
		if (@F < @Field) { 
			if ($line =~ /\t\t$/) { # the last two fields are empty
				push @F, "", ""; # @F<@Field if IU and DP is empty
			} elsif ($line =~ /\t$/) { # the last one field is empty
				push @F, ""; # @F<@Field if DP is empty
			}
			if (@F < @Field) {
				$k++; 
#				next if $F[$#F] !~ /ISI:|WOS:/; # skip if last element is not UT
				print STDERR "\@Field=", scalar @Field, ", \@F=", scalar @F, 
					": ", join('\t', @F),"\n";# if $main::Odebug > 0;
				next; # on 2011/11/10, remark last second line, use this line
			}
		} elsif(@F>@Field) { $l++; next; }
		$j++;
		&Insert2DB($DBH, $Table, \@Field, \@F);
	}
	close(F);
	print STDERR "$i records, $j inserted, $k less fields, $l more fields\n";
  $DBH->disconnect();
}

#sub Insert2DB {
sub Insert2DB_work_for_sqlite_and_MSAccess {
	my($DBH, $Table, $rField, $rF) = @_;
	my($sql, $sth, $i, $str, $ut, $f, @V, $j, $k);
	for($i=0; $i<@$rField; $i++) { last if $rField->[$i] eq 'UT'; }
# Create a record with UT data
	$ut = $rF->[$i];
	$sql = "INSERT INTO $Table (UT) VALUES (?)";
	$sth = $DBH->prepare($sql);
	$sth->execute($ut) or die $DBH->errstr;
# Update each field in the record with UT
	for ($i=0; $i<@$rF; $i++) {
		next if $rField->[$i] eq 'UT';
		next if $rF->[$i] eq '';
#		$f = ($rField->[$i]=~/ID|IU/)?"[$rField->[$i]]":$rField->[$i];
# Use next line instead of the above line on 2019/09/10
		$f = ($rField->[$i]=~/ID/)?"[$rField->[$i]]":$rField->[$i];
		$sql = "UPDATE $Table Set $f = ? WHERE UT = ?";
#print STDERR "sql=$sql\n";
		$sth = $DBH->prepare($sql);
		if ($f =~ /AF|AB|CR/) { # add AF on 2015/12/08
			$sth->bind_param(1, $rF->[$i], DBI::SQL_LONGVARCHAR);
		} else {
			if (length($rF->[$i])>255) { # will fail if not truncated
				$j = length($rF->[$i]);
				$rF->[$i] = substr($rF->[$i], 0, 255);
				if ($f =~ /TI|J9/) { # if TI or J9
					$rF->[$i] =~ s/ [^\s]*$//; # delete last incomplete string
				} else { # if not TI, nor J9
					if ($rF->[$i] !~ /;\s*$/) { # if not ended with ';'
						@V = split(/; /, $rF->[$i]);
						pop @V; # get rid of last (incomplete) element
						$rF->[$i] = join '; ', @V;
					}
				}
				$k = length($rF->[$i]);
				print STDERR "$f was truncated from $j chars into $k chars.\n";
			}
			$sth->bind_param(1, $rF->[$i]);
		}
		eval { 
#			$sth->execute($rF->[$i], $ut) or die $sql ."<=>($rF->[$i],$ut)\n". $DBH->errstr; 
			$sth->execute($rF->[$i], $ut); # 2011/04/04
		};
		print STDERR "Warning: $sql<=>($rF->[$i],$ut)\n" if ($@);# and $main::Odebug>1);
	} # for($i=0; ...
} # &Insert2DB()

#sub Insert2DB_old { # did not work for MS Access
sub Insert2DB { # work for SQLite
	my($DBH, $Table, $rField, $rF) = @_;
	my($sql, $sth, $i, $str, $j, $k, $f, @V);
	$str = '?,' x (scalar @$rField); 
	# compose as many '?,' as the No. of element of @Field 
	chop $str; # chop off last ','
	$sql = "INSERT INTO $Table (" . join(', ', 
#		map{$_=~/ID|IU/?"[$_]":$_}@$rField) 
# use next line instead of the above line on 2019/09/10
		map{$_=~/ID/?"[$_]":$_}@$rField) 
		. ") VALUES ($str)";
#print STDERR "sql=$sql\n";
	$sth = $DBH->prepare($sql);
	for ($i=0; $i<@$rF; $i++) {
		$f = ($rField->[$i]=~/ID|IU/)?"[$rField->[$i]]":$rField->[$i];
		if ($rField->[$i] =~ /AF|AB|CR/) { # add AF on 2015/12/08
			$sth->bind_param($i+1, $rF->[$i], SQL_LONGVARCHAR);
		} else {
			if (length($rF->[$i])>255) {
#				print STDERR "$rField->[$i]=$rF->[$i]\nwas truncated into\n";
#				$rF->[$i] = substr($rF->[$i],0,255);
#				print STDERR "$rField->[$i]=$rF->[$i]\n";
# The next lines are copied from the above on 2018/01/14
				$j = length($rF->[$i]);
				$rF->[$i] = substr($rF->[$i], 0, 255);
				if ($f =~ /TI|J9/) { # if TI or J9
					$rF->[$i] =~ s/ [^\s]*$//; # delete last incomplete string
				} else { # if not TI, nor J9
					if ($rF->[$i] !~ /;\s*$/) { # if not ended with ';'
						@V = split(/; /, $rF->[$i]);
						pop @V; # get rid of last (incomplete) element
						$rF->[$i] = join '; ', @V;
					}
				}
				$k = length($rF->[$i]);
				print STDERR "$f was truncated from $j chars into $k chars.\n";

			}
		$sth->bind_param($i+1, $rF->[$i]);
		}
#print STDERR "$rField->[$i]='$rF->[$i]'\n";
	}
	#eval { 
		$sth->execute(@$rF) or die $DBH->errstr; 
	#};
	print STDERR "Failed to add:",join ', ', @$rF,"\n" if ($@);
} # Insert2DB_old()


sub InsertIntoTseg {
	my($DSN, $Table, $TSeg, $DB_Path) = @_;  
	my($DBH, $sql, $sth);
	$DBH = &InitDBH($DSN, $DB_Path);
# Before insertion, delete the records in $Table
	$sql = "Delete from $TSeg";
	$sth = $DBH->prepare($sql);
	eval { $sth->execute() or die $DBH->errstr; };
	print STDERR "Failed to delete: $sql" if ($@);
# Now read records and insert into $Table
	$sql = "INSERT INTO $TSeg (SNO, Dname, Dscpt) "
# The next line is for MS Access
#	. "SELECT UT AS SNO, PY & ':' & TI AS Dname, AB AS Dscpt FROM $Table";
# The next line is for SQLite
	. "SELECT UT AS SNO, PY || ':' || TI AS Dname, AB AS Dscpt FROM $Table";
	$sth = $DBH->prepare($sql);
	eval { $sth->execute() or die $DBH->errstr; };
	print STDERR "Failed to insert into TSeg\n" if ($@);
}

# Given a large ISI source text file, split it into several smaller files.
sub SplitFiles {
	my($file, $OutFile) = @_;  #	my $OutFile = 'ISI";
	my($f, $Fields, $i, $size);
	@ARGV = ($file);
	$Fields = <>; $i = 1; $size = 0;
	$f = $OutFile . '_' . $i . '.txt';
	open F, ">$f" or die "Cannot write to file:'$f'";
	print F $Fields;
	while (<>) {
		print F $_;
		$size += length($_);
		if ($size > 200000000) { # 200MB
			close(F); $i++; $size = 0;
		$f = $OutFile . '_' . $i . '.txt';
		open F, ">$f" or die "Cannot write to file:'$f'";
		print F $Fields;
		}
	}
	close(F);
}

# Give a term list, a DSN, a Table in the DBMS, and the field in that table,
#   insert all the list terms which occurs in the TI and AB into the field.
sub InsertTerms2Field {
	my($DSN, $Table, $FromFields, $ToField, $TermFile, $DB_Path) = @_;
	my($t, @Terms, %Terms, $nr, @Fields, $rSeg);
#print "FromFields='$FromFields', ToField='$ToField'\n";
# Read Terms from file
	open F, $TermFile or die "Cannot read from file:'$TermFile'";
	@Terms = <F>; chomp @Terms;
	close(F); # restore back its original value
	print STDERR "Number of terms read: ", scalar @Terms, 
	"\nThe first ten are: @Terms[0..9]\n";
	
	my $seg = SegWord->new( { 'WordDir'=>'SAM/word' } );
	$seg->{'Eng_Seg_Phrase'} = 1;
	my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'});
	my $Stop = Stopword->new( );
	my $rDIC = $seg->{DIC};
	print STDERR "Before insertion, number of DIC terms: ", scalar keys %$rDIC, "\n";
	$seg->ResetSegmentationDic(\@Terms);
	print STDERR "After insertion,  number of DIC terms: ", scalar keys %$rDIC, "\n";
#print join("\n", sort keys %$rDIC), "\n"; exit;
	foreach $t (@Terms) { $Terms{ join(' ', @{$seg->Tokenize($t)}) } = 1; } 
#print "Number of terms in hash: ", scalar keys %Terms, 
#"\n"; #   "\nThe first ten are: ", join(', ', keys %Terms) ,"\n";

# Now we can insert terms into the specified $ToField if they occur in the $FormFields
	my $DBH = &InitDBH($DSN, $DB_Path);
#	my $sql = "SELECT UT, $Fields FROM $Table where PY < 2006 and PY > 2002";
	my $sql = "SELECT UT, $FromFields FROM $Table";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
# UPDATE TPaper SET SC='玉米' where UT='10' ;
	my $sql2 = "UPDATE $Table SET $ToField=? where UT=? ;";
	my $STH2 = $DBH->prepare($sql2)
		   or die "Can't prepare SQL statement: SQL=$sql2, $DBI::errstr\n";

	$nr = 0;  my(%ExistedTerms, $terms, $id, @T, $len, $i);
	while (($id, @Fields) = $STH->fetchrow_array) {
		$nr++;  undef %ExistedTerms; $len = 0; 
		$rSeg = $seg->segment(join ' . ', @Fields);
		foreach $t (@$rSeg) {
#print "id=$id, \$Terms{$t}=$Terms{$t}\n" if $id eq 'ISI:000075374400002';
		next if not $Terms{$t}; # skip if not in the $FromFields
		$ExistedTerms{ $t }++; # accumulate their number of occurrence
		} 
		@T = sort {$ExistedTerms{$b}<=>$ExistedTerms{$b}} keys %ExistedTerms;
		for($i=0; $i<@T; $i++) { 
		$len += (($T[$i]=~tr/ / /) + 1) + 2; # number of tokens + "; "
		if ($len >= 100) { 
			warn "UT=$id, Field too long. len=$len, NumOfTerms=", scalar @T, "\n"; 
			last; 
		}
	}
		$terms = join "; ", map{$seg->DelSpace($_)} @T[0..($i-1)];
#print "$id, term=$terms, @Fields\n";
#print "$id, term=$terms\n"; #, @Fields\n";
	next if $terms eq '';
	$STH2->bind_param(1, $terms);
	$STH2->bind_param(2, $id);
	$STH2->execute($terms, $id)
			or die "Can't run SQL statement: SQL=$sql2, $STH::errstr\n",
		   	  "id=$id, terms='$terms'\n";
	}
	$STH->finish; $STH2->finish;
	$DBH->disconnect;
	print STDERR "# Number of records: $nr\n";
}

# perl -s ISI.pl -OmCR SC_EF TPaper ..\Source_Data\SC_EF\SC_EF.mdb > ..\Result\SC_EF\SOmCR.txt
# Given a DSN, a Table in a DBMS, and the field,
#   Output the matched records to know records with some certain CR pattern.
# This function can be used to detect those records that are education-related.
sub Match_with_CR {
	my($DSN, $Table, $DB_Path) = @_;  my($py, $so, $au, $ti, $ab, $cr);
	my($pro, $DBH, $sql, $STH, $N, $nr, $percent);

	$pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'});
	$DBH = &InitDBH($DSN, $DB_Path);
	($N) = &TotalRecord($DBH, $Table, 'UT');
	$sql = "SELECT PY, SO, AU, TI, AB, CR FROM $Table";
	$STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	while (($py, $so, $au, $ti, $ab, $cr) = $STH->fetchrow_array) {
		$percent = $pro->ShowProgress(++$nr/$N, $percent);
		next unless $ti=~/education/i; # or $cr =~ /\bEDUC\b/;
#		print "$py\t$so\t$au\t$ti\t$ab\t$cr\n";
		print "$py\t$so\t$au\t$ti\t$ab\n";
	}
	$percent = $pro->ShowProgress(++$nr/$N, $percent);
	$STH->finish;
	$DBH->disconnect;

}


# Given a DSN, a Table in a DBMS, and the fields,
#   Output the cross-tabulation values in terms of document frequencies.
sub Get_ISI_J9X {
	my($DSN, $Table, $Fields, $DB_Path) = @_; 
	my($terms, $t, @Terms, %J9, $j9, $rJ92F);
	my($nr, $id, $n, $encoding_name);

	my $DBH = &InitDBH($DSN, $DB_Path);
	my $sql = "SELECT UT, J9, $Fields FROM $Table"; # e.g., $Fields=C1 or SC
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	$nr = 0;
	while (($id, $j9, $terms) = $STH->fetchrow_array) {
		$nr++; $J9{$j9}++; # number of $j9 in the document set
		$encoding_name = Encode::Detect::Detector::detect($terms);
		if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#			$terms = encode("big5", $terms);
#		if ($encoding_name !~ /big5/i) { # if utf8-encoded
			from_to($terms, $encoding_name, 'big5'); 
		}
		$n = @Terms = split /;\s*/, $terms;
		foreach $t (@Terms) { # for each C1 or SC
#			$t =~ s/^\"|\"$//g; # next commands accumulate their number of occurrence
			if ($main::OfracCount) {
				$rJ92F->{$j9}{$t}+=1/$n;
			} else {
				$rJ92F->{$j9}{$t}++; # accumulate frequency for each J9 and C1 (SC)
			}
		} 
	}
	$STH->finish;
	$DBH->disconnect;

	my($i, $j, $maxi, %Terms, $rTerms, $rM, @M, %J9d, @J9, @HHI, %HHI, %HHIi);
	@J9 = sort {$J9{$b} <=> $J9{$a}} keys %J9;
	for ($j=0; $j<@J9; $j++) { # for each journal
#		$rTerms = \% { $rJ92F->{$J9[$j]} };
		$rTerms = $rJ92F->{$J9[$j]};
		@Terms = sort {$rTerms->{$b} <=> $rTerms->{$a}} keys %$rTerms;
#print "$J9[$j]=>@Terms\n";
		$maxi = @Terms if $maxi < @Terms;
		@HHI = ();
		for ($i=0; $i<@Terms; $i++) { # for each C1 or SC
#			$rM->[$i][$j] = $Terms[$i] . "\t" . &ts($rJ92F->{$J9[$j]}{$Terms[$i]}, 2);
			$M[$i][$j] = $Terms[$i] . "\t" . &ts($rJ92F->{$J9[$j]}{$Terms[$i]}, 2);
# %J9d: number of j9 accumulated over all C1 (SC), due to multiple c1 (sc) in a record
			$J9d{$J9[$j]} += $rJ92F->{$J9[$j]}{$Terms[$i]};
			push @HHI, $rJ92F->{$J9[$j]}{$Terms[$i]}; 
		}
		my($hhi, $hhii) = &Compute_HHI($J9d{$J9[$j]}, \@HHI);
#print "hhi=$hhi, n=$J9d{$J9[$j]}, @HHI\n\n";
		$HHI{$J9[$j]} = $hhi;	$HHIi{$J9[$j]} = $hhii; 
		# HHIi : equivalent number of C1 (SC) in j9
	}
	print "$Fields\\J9\n",    join("\t",(map{$_."\t"} @J9)), "\n",
		join("\t", (map{"_NumRec_\t".&ts($J9{$_},2)}  @J9)), "\n",
		join("\t", (map{"_Total_\t". &ts($J9d{$_},2)} @J9)), "\n",
		join("\t", (map{"_HHI_\t".   &ts($HHI{$_},2)} @J9)), "\n",
		join("\t", (map{"_1/HHI_\t". &ts($HHIi{$_},2)}@J9)), "\n";
	for($i=0; $i<$maxi; $i++) { # foreach row (for each C1 or SC)
		for($j=0; $j<@J9; $j++) { 
#			print $rM->[$j][$i], ($j<@J9-1)?"\t":"";
			print $M[$i][$j], ($j<@J9-1)?"\t":"";
			print "\t" if $M[$i][$j] eq '';
		}
		print "\n";
	}
}

# compute Herfindahl–Hirschman Index, see http://en.wikipedia.org/wiki/Herfindahl_index
sub Compute_HHI { 
	my($n, $rA) = @_; my($i, $sum);
	for($i=0; $i<$n; $i++) { $sum += ($rA->[$i]/$n)**2; }
	return ($sum, ($sum>0)?1/$sum:0);
}

# Given a DSN, a Table in a DBMS, and the field in that table,
#   Output all the terms in that field and their document frequencies.
sub Get_ISI_Terms {
	my($DSN, $Table, $Fields, $DB_Path) = @_; 
	my($terms, @Terms, $t, %Terms);
	my($nr, $id, $py, $minpy, $maxpy, $PY_T2Freq, $i, $n, $tc, $sum);
	my($encoding_name);
	my $rSC2C = &Read_SC2C($main::OSC2C) if -e $main::OSC2C;
	my $DBH = &InitDBH($DSN, $DB_Path);
#	my $sql = "SELECT UT, $Fields FROM $Table where PY < 2006 and PY > 2002";
	my $sql = "SELECT UT, PY, $Fields FROM $Table";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	$sum = $nr = 0; $minpy = 100000000; $maxpy = 0;
#print STDERR "\$sql=$sql\n";
#	while (($id, $py, $terms) = $STH->fetchrow_array) {
	while (($id, $py, $terms, $tc) = $STH->fetchrow_array) {
		next if ($py eq '' and $main::Ocr);
		$nr++; $minpy = $py if $minpy > $py; $maxpy = $py if $maxpy < $py;
		$encoding_name = Encode::Detect::Detector::detect($terms);
		if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#			$terms = encode("big5", $terms);
#		if ($encoding_name !~ /big5/i) { # if utf8-encoded
			from_to($terms, $encoding_name, 'big5'); 
		}
		$n = @Terms = split /;\s*/, $terms;
		$sum += $n; # 2019/09/01
		foreach $t (@Terms) {
			$t =~ s/^\"|\"$//g;
#			$t = join (' ', map{ucfirst lc} split(/ /, $t)) 
#				if $Fields =~ /SC/; # 2010/05/05, already normalized 2011/04/13
			if ($main::OSC2C) {
				if ($rSC2C->{$t} eq '') {
#					print STDERR "Cannot map '$t' to a Category\n"; # remark on 2011/11/21
				} else {  $t = $rSC2C->{$t}; }
			}
			if ($main::OfracCount) {
#				$Terms{ $t }+=1/$n; # accumulate their number of occurrence
#				$PY_T2Freq->{$py}{$t}+=1/$n;
				$Terms{ $t }+=(($Fields=~/TC/)?$tc/$n:1/$n); 
				# accumulate their number of occurrence
				$PY_T2Freq->{$py}{$t}+=(($Fields=~/TC/)?$tc/$n:1/$n);
			} else {
#				$Terms{ $t }++; # accumulate their number of occurrence
#				$PY_T2Freq->{$py}{$t}++;
				$Terms{ $t }+=(($Fields=~/TC/)?$tc:1); 
				# accumulate their number of occurrence
				$PY_T2Freq->{$py}{$t}+=(($Fields=~/TC/)?$tc:1);
			}
		}
	}
	$STH->finish;
	$DBH->disconnect;
	print STDERR 
		"  Among $nr records, '$Fields' contains $sum number, avg=", 
		sprintf("%1.4f",($sum/$nr)), "\n" 
		if $Fields !~ /[, ]/ and not $main::Ocr; # if single field

	@Terms = sort {$Terms{$b} <=> $Terms{$a}} keys %Terms;
	my($au, $yr, $jl, $r, %CA, %CY, %CJ);
	foreach $t (@Terms) {
		print "$t\t".&ts($Terms{$t},1)."\n";
		if ($Fields eq 'CR') {
			($au, $yr, $jl, $r) = split /,\s*/, $t;
			if ($jl eq '') { # only two fields # 2011/04/13
				($t =~ /^\d/)?($yr, $jl) = ($au, $yr) : $jl = $yr;		
			}
#			next if $yr !~ /\d+/ or $jl eq ''; # 2011/04/13
#print  "\$t=$t\n" if $jl eq '';
			$au = &Normalize_Author($au); # added on 2014/09/18
			$CA{$au} += $Terms{$t};
			$CY{$yr} += $Terms{$t};
			$CJ{$jl} += $Terms{$t};
		}
	}
	if ($main::Ocr) { # if print cross-tabulation
		my $max = 0; my (@Slope, @A); # 2011/04/05
		$max = ($main::Ocr>@Terms) ? (@Terms - 1) : ($main::Ocr - 1);
		@Terms = @Terms[0..$max]; # 2010/03/29
		print "\nYear\\$Fields\n", "\t", (map{$_."\t"} @Terms), "\n";
		for($i=$minpy; $i<=$maxpy; $i++) {
			print "$i\t";
			foreach $t (@Terms) {
				$r = ($PY_T2Freq->{$i}{$t}ne''?$PY_T2Freq->{$i}{$t}:0);
#				print "$r\t";
				print &ts($r,1)."\t";
			}
			print "\n";
		}
		print "_Total_\t", (map{&ts($Terms{$_},1)."\t"} @Terms), "\n";
		foreach $t (@Terms) {
			@A = ();
			for($i=$minpy; $i<=$maxpy; $i++) { 
				$A[$i-$minpy] = ($PY_T2Freq->{$i}{$t}ne''?$PY_T2Freq->{$i}{$t}:0);
			}
			push @Slope, &Compute_Slope(\@A);
		}
		print "_Slope_\t", (map{&ts($_,2)."\t"} @Slope), "\n\n";
	}
	print STDERR "# Number of records: $nr\n";
	return if ($Fields ne 'CR');
	open FO, ">../Result/$DSN/CA.txt" or die "Cannot write to '../Result/$DSN/CA.txt'";
	map { print FO "$_\t".&ts($CA{$_},1)."\n"} sort {$CA{$b} <=> $CA{$a}} keys %CA;
	close(FO);
	open FO, ">../Result/$DSN/CY.txt" or die "Cannot write to '../Result/$DSN/CY.txt'";
	map { print FO "$_\t".&ts($CY{$_},1)."\n"} sort {$CY{$b} <=> $CY{$a}} keys %CY;
	close(FO);
	open FO, ">../Result/$DSN/CJ.txt" or die "Cannot write to '../Result/$DSN/CJ.txt'";
	map { print FO "$_\t".&ts($CJ{$_},1)."\n"} sort {$CJ{$b} <=> $CJ{$a}} keys %CJ;
	close(FO);
}

sub Normalize_Author { # Normalize single author
	my @AU = split /,/, $_[0]; $AU[0] = ucfirst lc $AU[0];
	return join ",", @AU;
}

sub Normalize_Authors { # Normalize multiple authors
	my @AUs = split /; /, $_[0];  my($au, @AU);
	foreach $au (@AUs) {
		@AU = split /,/, $au;
		$AU[0] = ucfirst lc $AU[0];
		$au = join ",", @AU;
	}
	return join("; ", @AUs);
}

sub Normalize_Terms { # change this function on 2019/08/26
	my($SC, $FieldName) = @_; my($sc, @SC);
	@SC = split /; /, $SC; # for multiple phrases separated by "; "
	if ($FieldName eq 'DE') {
		foreach $sc (@SC) { $sc = join(' ', map {lc Stem::stem($_)} split(' ', $sc)); }
	} elsif ($FieldName eq 'ID') {
		foreach $sc (@SC) { $sc = join(' ', map {uc Stem::stem(lc $_)} split(' ', $sc)); }
	} else { # for other fields with single multi-word phrase
		foreach $sc (@SC) { $sc = join(' ', map {ucfirst lc} split(' ', $sc)); }
	}
	return join('; ', @SC);
}

sub Read_SC2C {
	my($SC2C) = @_;  my($SC, $C, %SC2C);
	open F, $SC2C or die "Cannot read file:'$SC2C'";
	while (<F>) { 
		chomp; next if /^\s*$/; 
		($SC, $C) = split /\t/, $_; 
		$SC2C{$SC} = $C;
	}
	close(F);
	return \%SC2C;
}

# perl -s ISI.pl -OAUCA ..\Result\SC_Edu\AU.txt ..\Result\SC_Edu\CA.txt >  ..\Result\SC_Edu\AU_CA.txt
# Read AU.txt and CA.txt, and then compute common authors.
# The result may be used in Author Bibliographic Coupling (ABC).
# However, I found that common author, such as Dewey, J in "Dewey, J	2	1039"
# of AU_CA.txt may denote different people, because of the shortened name (not full name)
# So ABC is not accurate using current ISI data and is thus abandoned.
sub AU_CA {
	my($AUf, $CAf) = @_; my($rAU, $rCA, $au, $df, $ca, @DF, %DF2AU, @AU);
	$rAU = &ReadTerms($AUf);
	$rCA = &ReadTerms($CAf);
	while (($au, $df) = each %$rAU) {
		$ca = uc $au; $ca =~ s/,//;
		next if not $rCA->{$ca};
		$DF2AU{$rCA->{$ca}} .= "$au\t";
	}

	print "_Author_\tdf_AU\tdf_CA\n"; # output format
	@DF = sort {$b <=> $a} keys %DF2AU;
	foreach $df (@DF) {
		@AU = split /\t/, $DF2AU{$df};
		@AU = sort {$rAU->{$b} <=> $rAU->{$a}} @AU;
		foreach $au (@AU) {
			print "$au\t$rAU->{$au}\t$df\n"
		}
	}
}

# 2011/02/14
# Given the database containing the downloaded information from WoS,
#   create a file (in doc\) containing the records of the same journal (or author)
#   so that Jounal Bibliographical Coupling (Author Bibliographic Couping) is possible.
sub ISI2BigDoc {
	my($DSN, $DB_Path, $type, $OutDir) = @_;
	my($DBH, $STH, $sql, $J9, @A, %Actor, @Actor, $ac, $actor);     
	my($txt, $encoding_name);
	my($str, $nr, $id, $title, $content, $ff, @Str, %J92SO, %Ac2UT);
	my($percent, $i, $n, $pro) = (0.0, 0, 0); 
	$actor = 'Journal' if $type =~ /JBC|JCW/; #for Journal Bibliometric Coupling/Co-Word
	$actor = 'Author'  if $type =~ /ABC|ACW/; # for Author Bibliometric Coupling/Co-Word
#print "DSN=$DSN, InDir=$InDir\n"; exit;
	if (-d $OutDir) { &DelAllFile($OutDir); }    
	&CreateDir($OutDir);
	
	$DBH = &InitDBH($DSN, $DB_Path);
	if ($actor eq 'Journal') { 
		$sql = "SELECT J9, SO, UT FROM TPAPER"; # SO is not strictly journal name
	} elsif ($actor eq 'Author') {
		$sql = "SELECT AU, AF, UT FROM TPAPER";
	}
	$STH = $DBH->prepare($sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
	$STH->execute();
	while (@A = $STH->fetchrow_array) {
# The following code should not used, since we later need to read records based on J9
#		foreach $txt (@A) {
#			$encoding_name = Encode::Detect::Detector::detect($txt);
#			if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
##				$txt = encode("big5", $txt);
##			if ($encoding_name !~ /big5/i) { # if utf8-encoded
#				from_to($txt, $encoding_name, 'big5'); 
#			}
#		}
		if ($actor eq 'Journal') { 
			if ($A[0] ne '') {
				$Actor{$A[0]}++; 	$Ac2UT{$A[0]} .= $A[2] . "\t";
				$J92SO{$A[0]} = $A[1];
			} else { # 2011/08/19
				$encoding_name = Encode::Detect::Detector::detect($A[1]);
				if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#					$A[1] = encode("big5", $A[1]);
#				if ($encoding_name !~ /big5/i) { # if utf8-encoded
					from_to($A[1], $encoding_name, 'big5'); 
				}
				$Actor{$A[1]}++; 	$Ac2UT{$A[1]} .= $A[2] . "\t";
				$J92SO{$A[1]} = $A[1];
			}
		} elsif ($actor eq 'Author') { 
#			$A[1] = $A[0] if $A[1] eq ''; # Full name first; use Abbre. name if AF eq ''
#			@AF = split /; /, $A[1];
#			foreach $AU (@AF) {	$Actor{$AU}++;	}
			my @AU = split /; /, $A[0]; 			
			my @AF = split /; /, $A[1];
			for(my $i=0; $i<@AU; $i++) {
#				my $au = &Normalize_Author($AU[$i]);
				my $au = $AU[$i]; # already normalized
				next if $au =~ /\[anon\]/;
				$Actor{$au}++; 	$Ac2UT{$au} .= $A[2] . "\t";
				$J92SO{$au} = $AF[$i] if $AF[$i] ne ''; 
#print STDERR "\$AF[$i]=$AF[$i], \$J92SO{$au}=$J92SO{$au}\n";
			}
		}
	}
# Now we have journal names or author names in %Actor, sort them by frequency
	@Actor = sort {$Actor{$b} <=> $Actor{$a}} keys %Actor;
	for ($id=0; $id<@Actor; $id++) { last if $Actor{$Actor[$id]} < $main::OBigDoc; }
	(print STDERR "No data for dumping!\n" and exit) if $id == 0;
	$n = @Actor = @Actor[0..($id-1)];
	print STDERR "There are $n $actor(s)...\n";
	$pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'});
	foreach $ac (@Actor) {
		$percent = $pro->ShowProgress(++$i/$n, $percent);

=comment until next =cut		
		if ($actor eq 'Journal') {
			$sql = "SELECT UT, TI FROM TPAPER WHERE J9=?";
			$STH = $DBH->prepare($sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
			eval { $STH->execute($ac) or die $DBH->errstr; };
		} elsif ($actor eq 'Author') {
			my $au = $ac; $au =~ s/'/''/g; # use ' to escape single quote
# The following can lead to wrong results: Lee, H (Hyunjeong) vs Lee, HM (Han-Ming)
			$sql = "SELECT UT, TI FROM TPAPER WHERE AU LIKE '%$au%'";
#			$sql = "SELECT UT, TI FROM TPAPER WHERE AU LIKE ? OR AF LIKE ?";
			$STH = $DBH->prepare($sql) or die "Can't prepare SQL statement: $DBI::errstr\n";
			eval { $STH->execute() or die $DBH->errstr; };
#			eval { $STH->execute("'%$ac'", "'%$ac'") or die $DBH->errstr; };
		}
		print STDERR "Failed to execute: $sql\n" if ($@);
		@Str = (); $nr = 0;
	    while (($id, $title, $content) = $STH->fetchrow_array) {
	   		foreach $txt ($title, $content) {
				$encoding_name = Encode::Detect::Detector::detect($txt);
				if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#					$txt = encode("big5", $txt);
#				if ($encoding_name !~ /big5/i) { # if utf8-encoded
					from_to($txt, $encoding_name, 'big5'); 
				}
			} 
#			$str .= "$title : $id : $content. \n"; # title, $id, $content
			push @Str, "$title\t:\t$id\t:\t$content."; # title, $id, $content
			$nr++;
	    }
=cut

# Now we have %Ac2UT: the UTs of each journal (or author), put data in @Str;
		@Str = (); $nr = 0;
		my @UTs = split /\t/, $Ac2UT{$ac};
		$sql = "SELECT TI FROM TPAPER WHERE UT=?";
		$STH = $DBH->prepare($sql) or die "Can't prepare SQL stmt: $DBI::errstr\n";
		foreach my $UT (@UTs) {
			eval { $STH->execute($UT); }; #or die $DBH->errstr; };
			print STDERR "Failed to execute: $sql ($UT)\n" if ($@);
			($title, $content) = $STH->fetchrow_array;
	   		foreach $txt ($title, $content) {
				$encoding_name = Encode::Detect::Detector::detect($txt);
				if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#					$txt = encode("big5", $txt);
#				if ($encoding_name !~ /big5/i) { # if utf8-encoded
					from_to($txt, $encoding_name, 'big5'); 
				}
			} 
#			$str .= "$title : $id : $content. \n"; # title, $id, $content
			push @Str, "$title\t:\t$UT\t:\t$content."; # title, $id, $content
			$nr++;
		}
# Write the result
# example : <html><head><title>7373 : 8筆 : 0.050000(tangier-disease: 13.1, cholesterol:  9.7, apoa-i:  8.6, efflux:  6.8, cassette:  4.5)</title></head>
#		print FF "<html><head><title>$fi : $nr筆 : 0.5($terms)</title></head>\n";
		$str = "<html><head><title>$i : $nr Docs. : 1.0($ac: 1.0"
		.($J92SO{$ac} ne ''?", $J92SO{$ac}: 1.0":'') . ")</title></head>\n"
			. "<body>\n". join("\n", @Str). "\n</body></html>\n";
		$ac =~ tr/, /\_\_/; # translate each blank into an underscore
		$ff = "$OutDir/${ac}_${nr}.htm";
		open FF, ">$ff" or die "Cannot write to file:'$ff'";
		print FF $str;
		close(FF);
	}
    $percent = $pro->ShowProgress($i/$n, $percent);
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


#------------------------------------------------------------------------
# Given two files containing terms and their DFs, 
#   Output the merged term distributions for ease of comparison.
sub MergeTermDistribution {
	my($TW, $WD) = @_;  my($hTW, $hWD, $t1, $t2, $df1, $df2, @Terms, $t);
	$hTW = &ReadTerms($TW);
	$hWD = &ReadTerms($WD);
	@Terms = sort {$hTW->{$b} <=> $hTW->{$a}} keys %$hTW;
	print "TW\tTW_DF\tWD\tWD_DF\n";
	foreach $t (@Terms) {
		print "$t\t$hTW->{$t}\t$t\t$hWD->{$t}\n";
	}
	@Terms = sort {$hWD->{$b} <=> $hWD->{$a}} keys %$hWD;
	foreach $t (@Terms) {
		next if ($hTW->{$t}>0); # if already in $hTW, skip this term
		print "$t\t", ($hTW->{$t}eq''?0:$hTW->{$t}), "\t$t\t$hWD->{$t}\n";
	}
	print STDERR "\n# Number of Terms(TW, WD): ",scalar keys %$hTW,  
		", ", scalar keys %$hWD,"\n";
}

# Given a file resulted from &Get_ISI_Terms() or &Get_ISI_Term_DocList(), 
#   Read it back.
sub ReadTerms {
	my($file) = @_;	my(%h, $t, $df, $id, $rt);
	open F, $file or die "Cannot read file:'$file'";
	while (<F>) {
		chomp; next if /^\s*$/g; # skip if empty line
		if (/ : /) { # keys_rw.txt
			($id, $t, $df, $rt) = split / : /, $_; 
			# "23 : indication : 53 : time	39	system	56"
		} elsif (/\t/) { # DE.txt or idx_nouns.txt
			($t, $df) = split /\t/, $_; # "school reform	4"
		} else { # 2009/11/24
			next if /^\s*$|^#/; # skip if empty line or comment line
			$t = $_; $df = 1; # if no tab for field separator
		}
		next if $t =~ /^\d+$|^\s*$/g; # skip if digits or empty term
		next if $t =~ /^Year\W/; # 2010/12/04, should move to the calling functions
		next if $t =~ /^_Total|^_Slope/; # 2011/04/05, delete($h{$key}} should work
		$h{$t} = $df;
	}
	close(F);
	return \%h;
}


# Given a DSN, a table in a DBMS, the field, and a Term-DF file,
#   Output a term-to-DocList result file so as to be used by term_cluster.pl
#	 for term clustering 
# use option $OminDF to filter terms whose DF is less than $OminDF
sub Get_ISI_Term_DocList {
	my($DSN, $Table, $Fields, $DFfile, $DB_Path) = @_; 
	my($terms, @Terms, $t, %Terms);
	my($nr, $id, $hTDF, $i);
	$hTDF = &ReadTerms($DFfile);
	my $DBH = &InitDBH($DSN, $DB_Path);
#	my $sql = "SELECT UT, $Fields FROM $Table where PY < 2006 and PY > 2002";
	my $sql = "SELECT UT, $Fields FROM $Table";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	$nr = 0;
	while (($id, $terms) = $STH->fetchrow_array) {
		$nr++;
		# change $id to become a legal term in term_cluster.pl
		$id =~ s/:/\_/; # replace ISI:000070970500010 with ISI_000070970500010 
					# such that ISI_000070970500010 is considered as a word
	$id .= "_"; # do not end with a digit, otherwise, will be removed in term clustering
		@Terms = split /;\s*/, $terms;
		foreach $t (@Terms) {
		$t =~ s/^\"|\"$//g;
		next if $hTDF->{$t} < $main::OminDF;
		$Terms{ $t } .= "$id\t1\t"; # to meet the requirement of term_cluster.pl
		} 
	}
	$STH->finish;
	$DBH->disconnect;
#	@Terms = sort {$hTDF->{$b} <=> $hTDF->{$a}} keys %$hTDF;
	@Terms = sort {$hTDF->{$b} <=> $hTDF->{$a}} keys %Terms; # 2009/11/24
	$i = 0;
	foreach $t (@Terms) {
		next if $hTDF->{$t} < $main::OminDF;
		$i++;
#		print "$i : $t : $hTDF->{$t} : $Terms{$t}\n";
	print "$i : $t : ", ($Terms{$t}=~tr/\t/\t/)/2, " : $Terms{$t}\n"; # 2009/11/24
	}
	print STDERR "# Number of records: $nr\n";
} # End of &Get_ISI_Term_DocList()


# Basically, this function is the same as &Get_ISI_Term_DocList().
#   But the sources of terms are from TI and AB.
# use option $OminDF to filter terms whose DF is less than $OminDF
sub Get_Selected_Free_Term_DocList {
	my($DSN, $Table, $Fields, $DFfile, $DB_Path) = @_; 
	my($t, $df, $w, %SievedTerm, $n, $maxNumWords, $N, $percent, $DBID);
	my $hTDF = &ReadTerms($DFfile); # read in term file
	die "OminDF was not set!" if not defined $main::OminDF;
	while (($t, $df) = each %$hTDF) { # lower-case and stem the terms
		$w = join(' ', map{Stem::stem(lc $_)} split ' ', $t); # for phrases and words
		$SievedTerm{$w} = $df;
		$n = 1+($w =~ tr/ / /); # number of words in a term
		$maxNumWords = $n if $n > $maxNumWords; # get max. num. of words in a term
#print STDERR "$t : $w : $df : $n\n";
	}
	my $seg = SegWord->new( { 'WordDir'=>'SAM/word' } );
	my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'});
	my $Stop = Stopword->new( );

	my $DBH = &InitDBH($DSN, $DB_Path);
	if ($main::ODBID) { $DBID = $main::ODBID } else { $DBID = 'UT'; }

	($N) = &TotalRecord($DBH, $Table, $DBID);
print STDERR "Total records: $N\n";
#	my $sql = "SELECT UT, PY, TI, AB, DE, ID, SC FROM $Table";
	my $sql = "SELECT $DBID, $Fields FROM $Table";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	$n = 0;
	my($id, $ti, $ab, $rAB, $i, $j, %Existed, %Terms, @Terms, @F);
#	while (($id, $ti, $ab) = $STH->fetchrow_array) {
	while (($id, @F) = $STH->fetchrow_array) {
		$n++;
		# change $id to become a legal term in term_cluster.pl
		$id =~ s/:/\_/; # replace ISI:000070970500010 with ISI_000070970500010 
					# such that ISI_000070970500010 is considered as a word
	$id .= "_"; # do not end with a digit, otherwise, will be removed
#		$rAB = $seg->Tokenize($ti . ' . ' . $ab); # tokenize each word in the title and abstract
		$rAB = $seg->Tokenize(join(" . ", @F)); # tokenize each word in the title and abstract
		# next line lower-case and stem each word in the title and abstract
	for($i=0; $i<@$rAB; $i++) { $rAB->[$i] = Stem::stem(lc $rAB->[$i]); }
#print STDERR join(' ', @$rAB), "\nmaxNumWords=$maxNumWords, \@\$rAB=", scalar @$rAB,"\n";
	%Existed = ();
	for($i=0; $i<@$rAB; $i++) {
		next if $Stop->IsEmark($rAB->[$i]);
		next if $Stop->IsESW($rAB->[$i]);
		for($j=$i; $j<($maxNumWords+$i) and $j<@$rAB; $j++) {
			$w = join(' ', @$rAB[$i..$j]);
		next if $Stop->IsESW($w);
#print STDERR "i=$i, j=$j, w=$w, Existed='", $Existed{$w}, "', SievedTerm{$w}=$SievedTerm{$w}\n";
			next if $Existed{$w}; # already processed
			$Existed{$w}++; 
			if ($SievedTerm{$w}>=$main::OminDF) {
			$Terms{ $w } .= "$id\t1\t"; 
			# to meet the requirement of term_cluster.pl
			}
		}
	}
	$percent = $pro->ShowProgress($n/$N, $percent);
	}
	$percent = $pro->ShowProgress($n/$N, $percent);
	$STH->finish;
	$DBH->disconnect;

	@Terms = sort {$hTDF->{$b} <=> $hTDF->{$a}} keys %$hTDF;
	$i = 0;
	foreach $t (@Terms) {
		next if $hTDF->{$t} < $main::OminDF;
		$i++;
		$w = join(' ', map{Stem::stem(lc $_)} split ' ', $t); # for phrases and words
		$df = ($Terms{$w} =~ tr/\t/\t/)/2;
#		print "$i : $t : $hTDF->{$t} : $Terms{$t}\n";
		print "$i : $t : $df : $Terms{$w}\n";
	}
	print STDERR "# Number of records: $n\n";
}


# Given DSN, Table, and Field of a DBMS, the term_DF file, and year range
#   output each term, its DF, and its time series (DF distribution over the year range)
# use option $OminDF to filter terms whose DF is less than $OminDF
sub Get_ISI_Term_history {
	my($DSN, $Table, $Fields, $DFfile, $Years, $DB_Path) = @_; 
	my($terms, @Terms, $t, %Terms, $i);
	my($nr, $id, $py, $hTDF, @PY, %PY, @Years);
	@Years = split ' ', $Years;
	$hTDF = &ReadTerms($DFfile);
	my $DBH = &InitDBH($DSN, $DB_Path);
#	my $sql = "SELECT UT, $Fields FROM $Table where PY < 2006 and PY > 2002";
	my $sql = "SELECT UT, PY, $Fields FROM $Table";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	$nr = 0;
	while (($id, $py, $terms) = $STH->fetchrow_array) {
		$nr++;
		@Terms = split /;\s*/, $terms;
		foreach $t (@Terms) {
			$t =~ s/^\"|\"$//g;
			next if $hTDF->{$t} < $main::OminDF;
			$Terms{ $t } .= $py . "\t";
		} 
	}
	$STH->finish;
	$DBH->disconnect;
	@Terms = sort {$hTDF->{$b} <=> $hTDF->{$a}} keys %$hTDF;
	print "term\tdf\t", join("\t", @Years),"\n";
	foreach $t (@Terms) {
		next if $hTDF->{$t} < $main::OminDF;
		$i = @PY = split /\t/, $Terms{$t}; # $i : number of documents
		%PY = ();
		foreach $py (@PY) { $PY{$py} ++; }
		$py = join("\t", map{($PY{$_}?$PY{$_}:0)} @Years); # under the year range
		print "$t\t$i\t$py\n";
	}
	print STDERR "# Number of records: $nr\n";
}

# perl -s ISI.pl -OtermTrend -Onorm=abs ..\Result\pub\pub_kts.txt "6872 6186 5822 6350" > ..\Result\pub\pub_kts_trend.txt
# Given a file containing the terms and their time series (DFs over some year range)
#   and the total DFs over the year range
#   calculate the trend index for each term and output the result.
# Call &TrendType() and use option -Onorm
sub Get_ISI_Term_Trend {
	my($file, $Y2DF) = @_;
	my(%h, $t, $df, @Y2DF, @Year2DF, $line, @Years, $ob0, $ob1, $type, $b0, $b1);

# First line contains the field names
	open F, $file or die "Cannot read file:'$file'";
	$line = <F>; # read off the first line which contains the field names
	chomp $line; ($t, $df, @Years) = split /\t/, $line;
	print "term\tdf\tb0\tb1\ttype\t", join("\t", @Years), "\n";

# Second line is the overall trend and its time series 
	@Y2DF = split ' ', $Y2DF;
	($ob0, $ob1, $type) = &TrendType(\@Y2DF, \@Y2DF, $ob0, $ob1);
print STDERR "The trend type for the '$Y2DF' is:\n $ob0, $ob1, $type\n";
	$df=0; foreach $t (@Y2DF) { $df += $t; } # $df is the total number of documents
	print "_Total_\t$df\t$ob0\t$ob1\t\t", join("\t", @Y2DF), "\n";

# For each input line, cal
	while ($line = <F>) {
		chomp $line; next if $line =~ /^\s*$/g;
		($t, $df, @Year2DF) = split /\t/, $line;
#print STDERR "$t, $df, $line";
		($b0, $b1, $type) = &TrendType(\@Y2DF, \@Year2DF, $ob0, $ob1);
		print "$t\t$df\t$b0\t$b1\t$type\t", join("\t", @Year2DF), "\n";
	}
	close(F);
}


# This function use linear regression ratio to predict the 
#   trend type of each term history.
sub TrendType {
	my($rY2DF, $rYear2DF, $ob0, $ob1) = @_;
	my($i, $avg, @Z, $reg, $b0, $b1, $x1, $type, $stderr, $aipy);

	for($i=0; $i<@$rY2DF; $i++){ $avg += $rYear2DF->[$i]; } # accumulate DF for each year
	$avg /= @$rY2DF;  # find the average DF per year
	return (0.0, 0.0, 'error') if $avg == 0;

  if ($main::Onorm eq 'avg') { # wrong Z-score
	for($i=0; $i<@$rY2DF; $i++){ $Z[$i] = ($rYear2DF->[$i] - $avg)/$avg; } 
	# transform it into Z value
  } elsif ($main::Onorm eq 'abs') { # use absolute document number
	for($i=0; $i<@$rY2DF; $i++){ $Z[$i] = $rYear2DF->[$i]; } 
	# use original (absolute) document numbers
  } elsif ($main::Onorm eq 'ipy') { # increase/decrease per year
	for($i=0; $i<@$rY2DF-1; $i++) 
		{ $Z[$i] = ($rYear2DF->[$i+1]-$rYear2DF->[$i])/($rYear2DF->[$i]+1); } 
  } elsif ($main::Onorm eq 's2') { # 2008/09/25
	my $dp = int ((scalar @$rY2DF) * $main::Os + 0.5); #$dp = int (@$rY2DF * 0.7 + 0.5);
	for($i=0; $i<@$rY2DF; $i++){ 
		if ($i<=$dp) {$Z[0] += $rYear2DF->[$i];} else {$Z[1] += $rYear2DF->[$i];}
	}
#print "n=$i, dp=$dp, Z[0]=$Z[0]\tZ[1]=$Z[1]\n";
  } elsif ($main::Onorm eq 'aipy') { # averaged increase/decrease per year
	for($i=0; $i<@$rY2DF-1; $i++)
		{ $aipy += ($rYear2DF->[$i+1]-$rYear2DF->[$i])/($rYear2DF->[$i]+1); } 
	$b1 = $aipy /(@$rY2DF-1); $b0 = 0;
	goto HERE;
  } else { # use Z-score
	for($i=0; $i<@$rY2DF; $i++){ $stderr += ($rYear2DF->[$i] - $avg)**2; }
	$stderr /= @$rY2DF;  $stderr = sqrt($stderr);
	if ($stderr == 0) { $b0 = $b1 = 0; goto HERE; }
	for($i=0; $i<@$rY2DF; $i++){ $Z[$i] = ($rYear2DF->[$i] - $avg)/$stderr; } 
	# transform it into Z value
  }
#print STDERR 'Z=',join(',', @Z), "\n";
=Comment until next =cut (2011/04/04)
	$reg = Statistics::Regression->new(2, "linear regression", ["const", "x"]);
#	for($i=0; $i<@$rY2DF; $i++){ $reg->include( $Z[$i], [ 1.0, $i ] ); }
	for($i=0; $i<@Z;	  $i++){ $reg->include( $Z[$i], [ 1.0, $i ] ); }
	($b0, $b1) = $reg->theta();  # compute the regression
#	$x1 = ($b0-$ob0)/($ob1-$b1); # the position where two ys are euqal
=cut
	$b1 = &Compute_Slope(\@Z); $b0 = 0;
#print STDERR "n=", scalar @Z, ", ob0=$ob0, ob1=$ob1, b0=", sprintf("%1.4f", $b0), ", b1=", sprintf("%1.4f", $b1), ", x1=$x1\n";
HERE:
# do not alter the sequence of the following if-else
	if ($b1 >= 2 * $ob1) {  # predict the trend type by its slope 
		$type = 'SharpInc';
	} elsif ($b1 >= 1.5 * $ob1) {
		$type = 'Inc';
	} elsif ($b1 <= 0.25*$ob1) {
		$type = 'SharpDec';
	} elsif ($b1 <= 0.5 * $ob1) {
		$type = 'Dec';
	} else {
		$type = 'fluctuation';
	}
	return (sprintf("%1.4f", $b0), sprintf("%1.4f", $b1), $type);
}

sub Compute_Slope {
	my($rA) = @_; my($i, @X, @Y, $avg, $sq, $sx, $slope, @A);
	#@A = @$rA; # replaced with next line on 2019/09/27
	for($i=0; $i<@$rA; $i++) { $A[$i] = ($rA->[$i]eq'')?0:$rA->[$i];}
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

#--------------------------------------------------------------------
=head2 MergeHistory() 
# Given a cluster result (in HTML file) to get clustered terms
#	   DSN and Table to look up the publication year of a document by its ID (the UT field)
#	   a term to doc. list file
#  output each term history (by converting doc_id to year) and each cluster's history
# Output format:
#  cluster_id, number_of_terms, similarity, terms, df, 1996 1997 ... 2005 
=cut
sub MergeHistory {
	my($DSN, $Table, $TermDocListFile, $ClusterFile, $Years, $Y2DF) = @_;
	my @Years = split ' ', $Years;
	my @Y2DF = split ' ', $Y2DF;
	if (@Years != @Y2DF) { print STDERR "Data did not match:\nYears=@Years\nY2DF=@Y2DF\n"; exit; }
	my($ob0, $ob1, $type, $file, $b0, $b1, $df, $rYear2DF);
	my($c, @lines, $i, $cid, $nt, $sim, $terms, @Terms);
	($ob0, $ob1, $type) = &TrendType(\@Y2DF, \@Y2DF, $ob0, $ob1);
#print STDERR "The trend type for the '$Y2DF' is:\n $ob0, $ob1, $type\n";
	my $DocId2Year = &GetDocId2Field($DSN, $Table, 'PY');
	my $Term2DocList = &ReadTermDocList($TermDocListFile);
	print "cid\tnt\tsim\tterms\tdf\tb0\tb1\ttrend_type\t", join("\t", @Years), "\n";
	$df=0; foreach $i (@Y2DF) { $df += $i; } # $df is the total number of documents
	print "\t\t\tTotal\t$df\t$ob0\t$ob1\t\t", join("\t", @Y2DF), "\n";

	open F, $ClusterFile or die "Cannot read file:'$ClusterFile'";
	undef $/; $file = <F>; $/ = "\n"; # get all content in one read
	close(F);

	my @Clusters = split /<p>/, $file;
	shift @Clusters; shift @Clusters; # shift out first two non-cluster
	foreach $c (@Clusters) {
		$c =~ s#<[^>]+>##g; # delete all HTML tags
		@lines = split /\n+/, $c;
		if ($lines[0] =~ /(\d+)\(\d+\):/) { $cid = $1; } # cluster id and number of terms: 23(5):
		for($i=0; $i<@lines; $i++) {
#print  "cid=$cid, lines[$i]=$lines[$i]\n";
#		if ($lines[$i] =~ /(\d+)筆 : ([0-9\.]+)/) { # 5筆 : 0.023154
		if ($lines[$i] =~ /(\d+) Docs. : ([0-9\.]+)/) { # 5筆 : 0.023154
		$nt = $1; $sim = $2;
#		@Terms = &GetTerms($nt, join("\n", @lines[($i+1)..($#lines)])); # will yield incorrect result
		@Terms = &GetTerms($nt, join("\n", @lines[($i+1)..($#lines)])."\n"); # this is correct
#print "nt=$nt, lines=\n", join("\n", @lines[($i+1)..($#lines)]), "\n\@Terms=@Terms\n";
#		} elsif ($lines[$i] =~ /\d+ : ([\w \-\&,]+)/) { # 2356 : ergogenic aids or "n-3 fatty acids"
		} elsif ($lines[$i] =~ /\d+ : ([\w \-\&,\.\'\/\(\)\[\]\+]+)/) { # 2356 : ergogenic aids or "n-3 fatty acids"
		$nt = 1; $sim = 1.0;
			@Terms = ($1); # now we have cid, nt, sim, and terms, have to find others
		} else {  @Terms = (); }
#print "nt=$nt, sim=$sim, \@Terms=@Terms\n";
		next if @Terms == 0 or ($nt==1 and $sim==0);
	# now we have cid, nt, sim, and terms, we have to find df and other information
		($df, $rYear2DF) = &ClusterHistory(\@Terms, \@Years, $DocId2Year, $Term2DocList);
#print "df=$df, Year2DF=", join(" ", @$rYear2DF), "\n";
		($b0, $b1, $type) = &TrendType(\@Y2DF, $rYear2DF, $ob0, $ob1);
		print "$cid\t$nt\t$sim\t", join("; ", @Terms), "\t$df\t$b0\t$b1\t$type\t",join("\t", @$rYear2DF),"\n";
		}
	}
} # End of &MergeHistory()


# Given a DSN, a table, and a field in a DBMS, return the \%DocId2Field hash for laster use.
sub GetDocId2Field {
	my($DSN, $Table, $Field, $DB_Path) = @_;  my(%DocId2Field, $id, $f);
	my $DBH = &InitDBH($DSN, $DB_Path);
	my $sql = "SELECT UT, $Field FROM $Table";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	my $nr = 0;
	while (($id, $f) = $STH->fetchrow_array) {
		$nr++;
		$DocId2Field{$id} = $f;
	}
	$STH->finish;
	$DBH->disconnect;
print STDERR "$nr database records read\n";
	return \%DocId2Field;
}


# Give a term to doclist file, read data from the file, save the results in %Term2DocList
sub ReadTermDocList {
	my($file) = @_;  
	my(%Term2DocList, $id, $term, $df, $doclist, %Doc, $i, @Doc, $did);
	open F, $file or die "Cannot read file:'$file'";
	$i = 0;
	while (<F>) {
		chomp;
		($id, $term, $df, $doclist) = split / : /, $_;
		next if $term eq '';
		$i++;
		%Doc = split /\t/, $doclist;
		@Doc = keys %Doc; # get rid of added term frequency
		foreach $did (@Doc) { 
		chop $did; # chop off last '_', e.g. ISI_000077994300001_
		$did =~ s/_/:/; # change ISI_000077994300001 into ISI:000077994300001
	}
		$Term2DocList{$term} = join ("\t", @Doc);
	}
	close(F);
	return \%Term2DocList;
}


# Given number of terms to be extracted and the text string, return the extracted terms
sub GetTerms {
	my($nt, $str) = @_;  my(@Terms, $terms, $i);
#	while ($str =~ /\d+ : ([\w \-\&,]+)\n/g) { # 2356 : ergogenic aids
	while ($str =~ /\d+ : ([\w \-\&,\.\'\/\(\)\[\]\+]+)\n/g) { # 2356 : ergogenic aids
#	$terms .= $1 . "; ";
	push @Terms, $1;
	$i++; last if $i>=$nt;
	}
	return @Terms; # return $terms;
}


# Given a set of clustered terms, year range, DocId2Year, and Term2DocList
#   return df and Year2DF in this cluster
# Note: a doc. belongs to this cluster, if any terms in this cluster occur in the doc.
sub ClusterHistory {
	my($rTerms, $rYears, $DocId2Year, $Term2DocList) = @_;
	my($i, $t, $df, $did, %Dids, @Dids, %Year2DF, @Year2DF);
	foreach $t (@$rTerms) {
		@Dids = split /\t/, $Term2DocList->{$t};
#print "\$Term2DocList->{$t}=$Term2DocList->{$t}\n";
		foreach $did (@Dids) { $Dids{$did}++; } # accumulate number of duplicate dids
	}
	$df = @Dids = keys %Dids; # remove duplicate dids

# Now @Dids has all the Dids that belong to this cluster
	foreach $did (@Dids) {  $Year2DF{ $DocId2Year->{$did} } ++; }
	@Year2DF = map {$Year2DF{$_}?$Year2DF{$_}:0} @$rYears;
	return ($df, \@Year2DF);
}
# End of &MergeHistory() ----------------------------------------------------


#--------------------------------------------------------------------
=head2 BreakDown() 
# Given DSN, Table, Field, a term to doc. list file, a trend file, year range, Year2DF,
#   break down each cluster to show the distribution of each field value in the cluster.
# Output format:
#  cluster_id, number_of_terms, similarity, terms,  df,	b0, b1, 96df 97df ... 05df,
#  cluster_id, number_of_terms, similarity, Fvalue, fdf, fdfr, b1, df96 97df ... 05df, SingularValue
# For each cluster, the breakdown of each field value is sorted by the singular values.
=cut
# perl -s ISI.pl -Obreakdown -Onorm=abs agr agr JI ..\Result\agr\agr_SC_DocList.txt ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_Sorted_type.txt "1996 1997 1998 1999 2000 2001 2002 2003 2004 2005" "5448 6056 6363 6211 6773 7475 8028 7700 9187 9268" > ..\Result\agr_SC\agr_SC_clu0.0_Trend_abs_Sorted_type_JI.txt
# Use option: -OSkipEmpty
sub BreakDown {
	my($DSN, $Table, $Field, $TermDocListFile, $TrendFile, $Years, $Y2DF) = @_;
	my @Years = split ' ', $Years;
	my @Y2DF = split ' ', $Y2DF;
	my($ob0, $ob1, $type, $file, $b0, $b1, $df, $rYear2DF, $yrs, $line, $trend_type);
	my($c, @line, $i, $j, $cid, $nt, $sim, $terms, @Terms, $U, $S, $V, $sumsv, $sum);
	my($F_df, $rF2YearDF, @F, $f, @Year2DF, $nr, $nc, @AuthScore, @EigenTrend, $mmn);
	my(@EigenValue, $sumas);
	($ob0, $ob1, $type) = &TrendType(\@Y2DF, \@Y2DF, $ob0, $ob1);
print STDERR "The trend type for the '$Y2DF' is:\n $ob0, $ob1, $type\n";
	my $DocId2Year = &GetDocId2Field($DSN, $Table, 'PY');
	my $DocId2Field = &GetDocId2Field($DSN, $Table, $Field);
	my $Term2DocList = &ReadTermDocList($TermDocListFile);

# Print out field names
	print "cid\tnt\tsim\tterms\tdf\tdf_ratio\tb1\ttrend_type\t", join("\t", @Years), "\tAuthority\tAuth_ratio\n";
# print out total trend summed over all number of document occurrence for each year
	$df=0; foreach $i (@Y2DF) { $df += $i; } # $df is the total number of documents
	print "\t\t\tTotal\t$df\t\t$ob1\t\t", join("\t", @Y2DF), "\t\t\n";

	open F, $TrendFile or die "Cannot read file:'$TrendFile'";
	<F>; <F>; # read off first two lines
	while ($line = <F>) {
		next if $line =~ /^\s*$/; # skip empty line
		chomp $line; 
		($cid, $nt, $sim, $terms, $df, $b0, $b1, $trend_type, $yrs) = split /\t/, $line, 9;
		# print original line, next are for breakdown
		print "$cid\t$nt\t$sim\t$terms\t$df\t\t$b1\t$trend_type\t$yrs\t\t\n";
		@Terms = split /; /, $terms;
	# now we have cid, nt, sim, and terms, we have to find df and other information
	($rF2YearDF, $df) = &GetField2YearDF(\@Terms, \@Years, $DocId2Year, $DocId2Field, $Term2DocList);
if ($df == 0) { print STDERR "df=$df, sumas=", &ts($sumas), " for\n$line\n"; next; }
	@F = sort {$rF2YearDF->{$b}[0] <=> $rF2YearDF->{$a}[0]} keys %$rF2YearDF; 
	# hash of a 2-d array, the first element of the array is the DF of $f
	($U, $S, $V, $nr, $nc) = &SVDecomposition($rF2YearDF, \@F, scalar @Y2DF);
# print the Singular Values and EigenTrends
#print "S=\n", $S->as_matlab( ( format => "%.3f") ), "\n";
	$sumsv = $sum = $sumas = 0;  $mmn = (($nr>$nc)?$nc:$nr);
	for($j=0; $j<$mmn; $j++) { $sumsv += $S->[0][0][$j]; }
	for ($i=0; $i<$nr; $i++) { $sumas += $AuthScore[$i] = $U->[0][$i][0]; }
if ($sumas == 0) { print STDERR "sumas=", &ts($sumas), ", AuthScore=", join(", ", map{&ts($_)} @AuthScore), "\n"; }
	for ($i=0; $i<$mmn; $i++) {$EigenValue[$i] = $S->[0][0][$i]; }
	for ($i=0; $i<$nc; $i++) { $EigenTrend[$i] = $S->[0][0][0] * $V->[0][$i][0]; }
	($b0, $b1, $type) = &TrendType(\@Y2DF, \@EigenTrend, -1.5170, $main::Ob1); #農業整體趨勢
	print "$cid\t$nt\t\tSV_Trend\t\t\t$b1\t$type\t",join("\t", map{&ts($_)}@EigenTrend),"\t\t\n";
	print "$cid\t$nt\t\tSV_Value\t\t\t\t\t",join("\t", map{&ts($_)}@EigenValue),"\t", "\t\n";# &ts($sumas), "\n";

# print the count-based breakdown distribution
	my $truncated_df = 0;
	for($i=0; $i<$nr; $i++) {
		$f = $F[$i];
		@Year2DF = @{$rF2YearDF->{$f}}; 
		$F_df = shift @Year2DF; # shift out the total df
		$truncated_df += $F_df;
#		last if ($i>10 and ($F_df/$df)<0.005);
		}
		next if $truncated_df == 0;
	for($i=0; $i<$nr; $i++) {
		$f = $F[$i]; $j = $i+1;
		@Year2DF = @{$rF2YearDF->{$f}}; 
		$F_df = shift @Year2DF; # shift out the total df
		($b0, $b1, $type) = &TrendType(\@Y2DF, \@Year2DF, -1.5170, 0.3371); #農業整體趨勢
		print "$cid\t$nt\t$j\t$f\t$F_df\t", &ts($F_df/$truncated_df), # &ts($F_df/$df), 
			  "\t$b1\t$type\t",join("\t", @Year2DF),"\t", &ts($AuthScore[$i]), "\t", 
			  (($sumas==0)?'':&ts($AuthScore[$i]/$sumas)), "\n";
#		last if ($i>10 and ($F_df/$df)<0.005);
		}
	}
} # End of &BreakDown();


# Given terms, Term2DocList (so as to get all DocId),
#	DocId2Year, DocId2Field (so as to get a doc.'s PY and Field (C1 or JI) from DocId),
#	   YearRange ($rYears, so as to know the range of year to analyze),
#	(assume years in YearRange is consecutive, like "1996, 1997, ..., 2004, 2005"
# Returns: Field_to_Year_DocCount: a hash of reference to an array, 
# 	where the arrays are indexed from 0 to YearRange, index 0 is for tatal DF,
#	index 1 is the first year of YearRange, index 2 is the second year of YearRange, ...
# Use option: -OSkipEmpty
sub GetField2YearDF {
	my($rTerms, $rYears, $DocId2Year, $DocId2Field, $Term2DocList) = @_;
	my($i, $t, $df, $did, $f, $year, %Dids, @Dids, %F2YearDF);
	foreach $t (@$rTerms) {
		@Dids = split /\t/, $Term2DocList->{$t};
#print "\$Term2DocList->{$t}=$Term2DocList->{$t}\n";
		foreach $did (@Dids) { $Dids{$did}++; } # accumulate number of duplicate dids
	}
#	$df = @Dids = keys %Dids; # remove duplicate dids
	@Dids = keys %Dids; # remove duplicate dids
	$df = 0;

# Now @Dids has all the Dids that belong to this cluster
	foreach $did (@Dids) {
		$f = $DocId2Field->{$did}; # to know its field value
		next if $f eq '' and $main::OSkipEmpty; 
		$df ++;
		$year = $DocId2Year->{$did}; # to know its year
		next if $year < $rYears->[0] or $year > $rYears->[-1]; # out of range
		$i = $year - $rYears->[0] + 1; # $i start from 1, zero is for sum of all 
		$F2YearDF{$f}->[$i] ++; # for the F-Year matrix, each element is the doc. count
	}
# Now accumulate the DFs in each year in index 0
	while (($f, $year) = each %F2YearDF) { # $year is a ref to an array
		for($i=1; $i<=($rYears->[-1] - $rYears->[0] + 1); $i++) {
			$year->[$i] = 0 if $year->[$i] eq ''; # if empty, set to 0
		$year->[0] += $year->[$i];
		}
	}
	return (\%F2YearDF, $df);
}


sub SVDecomposition {
	my($rF2YearDF, $rF, $nc) = @_;
# @$rF is sorted Field values
	my($M, $nr, $U, $S, $V, @F, $i, $j, $f, $year);

#	$nr = @F = keys %$rF2YearDF;
	$nr = (@$rF>20)?20:scalar @$rF; # maximum is 20
	return if $nr == 0;
	$M = new Math::MatrixReal($nr, $nc);
# Fill in M such that its elements are those of $rF2YearDF
	for($i=0; $i<$nr; $i++) {
		$f = $rF->[$i];
		$year = $rF2YearDF->{ $f };
	for ($j=1; $j<=$nc; $j++) {
		$M->[0][$i][$j-1] = $year->[$j];
	}
	}
	$U = new Math::MatrixReal($nr, $nr); # double[nr][nr];
	$S = new Math::MatrixReal(1, $nc);   # double[nc];
	$V = new Math::MatrixReal($nc, $nc); # double[nc][nc];
#print "M=(USV*=)\n",  $M->as_matlab( ( format => "%.3f") ), "\n";
	($U, $S, $V) = SVD::SVD($M); # for any rectangular matrix $M, output U, S, V (not V*)
	# Note: $U is truncated if $nr >= $nc, $V is truncated if $nr < $nc
	if ($U->[0][0][0] < 0) { 
	$U = -1 * $U; # Negate each element to get positive values for our examples
	$V = -1 * $V; # Negation should be done for both matrices at the same time
	} # See Reference [1]
#print "U=\n", $U->as_matlab( ( format => "%.3f") ), "\n";
#print "S=\n", $S->as_matlab( ( format => "%.3f") ), "\n";
#print "V=\n", $V->as_matlab( ( format => "%.3f") ), "\n\n"; exit;
	return ($U, $S, $V, $nr, $nc);
}
# End of &BreakDown() ----------------------------------------------------


# 將SC、DE、ID欄位歸類後的全部類別，按照趨勢指標排序，提供專家確認：
# perl -s ISI.pl -OSortByTrend ..\Result\agr_SC\agr_SC_clu0.0_Trend.txt > ..\Result\agr_SC\agr_SC_clu0.0_Trend_Sorted.txt
# Given a file in the format:
#  cid	nt	sim	terms	df	b0	b1	trend_type	1996	1997	1998	1999	2000	2001	2002	2003	2004	2005
#   output the similar file with clusters been sorted by trend.
sub SortByTrend {
	my($cid, $nt, $sim, $terms, $df, $b0, $b1, $type, $r);
	my($sum, $oldcid, @Cluster, %Trend, @Lines);
	$sum = 0;
	$_=<>; print $_; $_=<>; print $_; # the first two lines need not be changed.
	$oldcid = 1; 
	while (<>) {
		($cid, $nt, $sim, $terms, $df, $b0, $b1, $type, $r) = split /\t/, $_;
		if ($cid ne $oldcid) {
		$Cluster[$cid] = join "", @Lines; # record all the items in the cluster
		$Trend{$cid} = $sum/@Lines; # trends of Cluster $cid are averaged
		@Lines = ();
		$sum = 0;
		$oldcid = $cid;
#print "$cid\n";
		}
		$_ =~ s/$type//;
		push @Lines, $_;
		$sum += $b1;
	}
	if (@Lines > 0) { 
		$Cluster[$cid] = join "", @Lines;
		$Trend{$cid} = $sum/@Lines;
	}
# Now we have all clusters in @Cluster and their trend index in %Sim
	my @CidSortByTrend = sort {$Trend{$b} <=> $Trend{$a}} keys %Trend;
# print out the cluster sorted by trend
	foreach $cid (@CidSortByTrend) {
		print $Cluster[$cid];
	}
}

# 將專家已經判斷過的結果放到trend_type欄位：
# perl -s ISI.pl -OInsertTrendType ..\exp\SC_expert.txt ..\Result\agr_SC\agr_SC_clu0.0_Trend_Sorted.txt > ..\Result\agr_SC\agr_SC_clu0.0_Trend_Sorted_type.txt
# Given the sorted (or un-sorted) clusters in a file having the format:
#  cid	nt	sim	terms	df	b0	b1	trend_type	1996	1997	1998	1999	2000	2001	2002	2003	2004	2005
# and the judgement file made by experts,
# output the cluster file with the trend type inserted with experts' judgement
sub InsertTrendType {
	my($JudgedFile, $ClusterFile) = @_;
	my($line, @F, $trend_id, %Trend);
	open F, $JudgedFile or die "Cannot read file:'$JudgedFile'";
	$_ = <F>; # read in the first line of the file
	@F = split /\t/, $line; # The first line is the field names
	$trend_id = $#F; # last field is the trend type judged by experts
	$_ = <F>; # read off the second which is the information for total terms
	while (<F>) {
	chomp;	@F = split /\t/;
	$Trend{$F[0].$F[3]} = $F[$trend_id]; # key is cid and terms
	}
	close(F);
	open F, $ClusterFile or die "Cannot read file:'$ClusterFile'";
	while (<F>) {
	@F = split /\t/, $_;
	if ($Trend{$F[0].$F[3]}) { $F[7] = $Trend{$F[0].$F[3]}; }
	print join("\t", @F);
	}
	close(F);
}


# perl -s ISI.pl -OmergeYear=2 ..\Result\agr_SC\agr_SC_clu0.0_Trend.txt > ..\Result\agr_SC\agr_SC_clu0.0_Trend_y2.txt
# Given a file in the format:
#  cid	nt	sim	terms	df	b0	b1	trend_type	1996	1997	1998	1999	2000	2001	2002	2003	2004	2005
# Output the similar file with years merged and b0 and b1 re-calculated.
sub MergeYear {
	my($line, @Field, @Years, @Y2DF, $Ys, $Ye, $i, $j, $sum);
	$line = <>;  chomp $line;
	@Field = split /\t/, $line; # The first line is the field names
	$Ys = $#Field; $Ye = 0; # the index position of the Year start and end
	for($i=0; $i<@Field; $i++) { 
		if ($Field[$i] =~ /^\d\d\d\d$/) {
		$Ys = $i if $i < $Ys; # The starting position of the year
		$Ye = $i if $i > $Ye; # The ending position of the year
		}
	}
#	@Years = @Field[$Ys..$Ye]; # do not need this line
	print join("\t", @Field[0..$Ys-1]);  # print out new field name
	for($i=$Ys; $i<=$Ye; $i+=$main::OmergeYear) {
		print "\t", $Field[$i], '-', $Field[($i+$main::OmergeYear-1)<$Ye?($i+$main::OmergeYear-1):$Ye];
	} print "\n";
	
	$line = <>;  chomp $line;
	@Field = split /\t/, $line; # The second line is the distribution of Total
	@Y2DF = (); 
	for($i=$Ys; $i<=$Ye; $i+=$main::OmergeYear) {
	$sum = 0;
#	for ($j=$i; $j<@Field and $j<($i+$main::OmergYear); $j++) { 
	for ($j=$i; $j<($i+$main::OmergeYear); $j++) { 
		$sum += $Field[$j]; 
	}
	push @Y2DF, $sum;
	}
	my($ob0, $ob1, $type, $b0, $b1, @Year2DF);
	($ob0, $ob1, $type) = &TrendType(\@Y2DF, \@Y2DF, $ob0, $ob1);
print STDERR "The trend type for the '@Y2DF' is:\n $ob0, $ob1, $type\n";
	print join("\t", @Field[0..4]), "\t$ob0\t$ob1\t$type\t",join("\t", @Y2DF),"\n";
	while (<>) {
		chomp $_; next if /^\s*$/g; # skip if an empty line
		@Field = split /\t/, $_;
# merge years
		@Year2DF = (); 
		for($i=$Ys; $i<=$Ye; $i+=$main::OmergeYear) {
			$sum = 0;
		for ($j=$i; $j<@Field and $j<$i+$main::OmergeYear; $j++) { $sum += $Field[$j]; }
		push @Year2DF, $sum;
		}
		($b0, $b1, $type) = &TrendType(\@Y2DF, \@Year2DF, $ob0, $ob1);
		print join("\t", @Field[0..4]), "\t$b0\t$b1\t$type\t", join("\t", @Year2DF), "\n";
	}	
}



# perl -s ISI.pl -OYearRange=0-6 ..\Result\agr_SC\agr_SC_clu0.0_Trend.txt > ..\Result\agr_SC\agr_SC_clu0.0_Trend_yr0-6.txt
# Given a file in the format:
#  cid	nt	sim	terms	df	b0	b1	trend_type	1996	1997	1998	1999	2000	2001	2002	2003	2004	2005
# Output the similar file with years limited to the OYearRange and b0 and b1 re-calculated.
sub YearRange {
	my($line, @Field, @Years, @Y2DF, $Ys, $Ye, $i, $j, $sum);

	$line = <>;  chomp $line;
	@Field = split /\t/, $line; # The first line is the field names
	$Ys = $#Field; $Ye = 0; # the index position of the Year start and end
	for($i=0; $i<@Field; $i++) { # find the actual positions
		if ($Field[$i] =~ /^\d\d\d\d$/) {
		$Ys = $i if $i < $Ys; # The starting position of the year
		$Ye = $i if $i > $Ye; # The ending position of the year
		}
	}
#print STDERR "Ys=$Ys, Ye=$Ye\n";
	print join("\t", @Field[0..$Ys-1]), "\t";  # print out new field name
	($i, $j) = split /\-/, $main::OYearRange; # split /\-/, "0-6"
	$Ys += $i; $Ye = $Ys+$j; # update starting and ending positions of the year range
#print STDERR "Ys=$Ys, i=$i, Ye=$Ye, j=$j\n";
	print join("\t", @Field[$Ys..$Ye]), "\n";
	
	$line = <>;  chomp $line;
	@Field = split /\t/, $line; # The second line is the distribution of Total
	@Y2DF = @Field[$Ys..$Ye]; 
	my($ob0, $ob1, $type, $b0, $b1, @Year2DF);
	($ob0, $ob1, $type) = &TrendType(\@Y2DF, \@Y2DF, $ob0, $ob1);
print STDERR "The trend type for the '@Y2DF' is:\n $ob0, $ob1, $type\n";
	print join("\t", @Field[0..4]), "\t$ob0\t$ob1\t$type\t",join("\t", @Y2DF),"\n";

	while (<>) {
		chomp $_; next if /^\s*$/g; # skip if an empty line
		@Field = split /\t/, $_;
# merge years
		@Year2DF = @Field[$Ys..$Ye]; 
   	($b0, $b1, $type) = &TrendType(\@Y2DF, \@Year2DF, $ob0, $ob1);
		print join("\t", @Field[0..4]), "\t$b0\t$b1\t$type\t", join("\t", @Year2DF), "\n";
	}	
}

# Given a sampling rate, a clustered HTML file and an extracted file
#  write out their sampling results to a new HTML file and a new txt file
sub Sampling {
	my($rate, $HTMLfile, $InFile) = @_;
	my($HTMLsampleFile, $OutFile); # output files
	$HTMLsampleFile = $HTMLfile;
	$HTMLsampleFile =~ s/\.html/_sample_$rate\.html/;
	$OutFile = $InFile;
	$OutFile =~ s/\.txt/_sample_$rate\.txt/;
	
	open HTMLin, $HTMLfile or die "cannot read file:'$HTMLfile'";
	open In, $InFile or die "Cannot read file:'$InFile'";
	open HTMLout, ">$HTMLsampleFile" or die "cannot write to file:'$HTMLsampleFile'";
	open Out, ">$OutFile" or die "Cannot write to file:'$OutFile'";

	my($file, $cid, $cn, @Clusters, $c, %Cid, $r);
	undef $/; $file = <HTMLin>; $/ = "\n"; # get all content in one read
	close(HTMLin);
	@Clusters = split /<p>/, $file;
	print HTMLout (shift @Clusters), "<p>", (shift @Clusters), "<p>";
	foreach $c (@Clusters) {
		$cid = $cn = 0;
		if ($c =~ /(\d+)\((\d+)\):/) { $cid = $1; $cn = $2; } # cluster id and number of terms: 23(5):
		next if rand(1) >= $rate; 
		print HTMLout $c , "<p>";
		$Cid{$cid} = 1; # record the cluster id for later use
	}
	close(HTMLout);
	while (<In>) {
		($cid, $r) = split /\t/, $_, 2;
		if ($Cid{$cid}==1 or $cid==0) { # the first two lines have zero cid
		print Out $_;
	}
	}
	close(Out);	close(In);
}


# This function is to check how many DE, ID, SC terms are in the title and the abstract
# perl -s ISI.pl -Ochktm EduEval EEPA318 (to check the overlap of terms in [DE|SC\ID] and TI+AB)
sub CheckTerm {
	my($DSN, $Table, $DB_Path) = @_;
	my($N, $t, @Terms, $ut, $py, $ti, $ab, $de, $id, $sc, $rAB, $text, $percent);

	my $seg = SegWord->new( { 'WordDir'=>'SAM/word' } );
	my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'});

	my $DBH = &InitDBH($DSN, $DB_Path);
	($N) = &TotalRecord($DBH, $Table);
print STDERR "Total records: $N\n";

	my $sql = "SELECT UT, PY, TI, AB, DE, ID, SC FROM $Table";
#	my $sql = "SELECT UT, PY, TI, AB, DE, ID, SC FROM $Table where DE like 'biomass recovery%'";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	my($tp, $nt, $tp_de, $nt_de, $p_de, $tp_id, $nt_id, $p_id, 
	   $tp_sc, $nt_sc, $p_sc, $sc0, $de0, $id0, $n) 
	   = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
	while (($ut, $py, $ti, $ab, $de, $id, $sc) = $STH->fetchrow_array) {
		$n++;
		$rAB = $seg->Tokenize($ti . ' . ' . $ab); # tokenize each word in the title and abstract
		# next line lower-case and stem each word in the title and abstract
		$text = join(' ', map{Stem::stem(lc $_)} @$rAB);
#print STDERR "Abstract='$text'\n\n";
		($tp, $nt) = &Check($de, $text);
#my($tp_de, $nt_de, $rDE) = &Check($de, $text);
		if ($nt > 0) { $tp_de += $tp; $nt_de += $nt; $p_de += $tp/$nt; } else { $de0++; }
		($tp, $nt) = &Check($id, $text);
#my($tp_id, $nt_id, $rID) = &Check($id, $text);
		if ($nt > 0) { $tp_id += $tp; $nt_id += $nt; $p_id += $tp/$nt; } else { $id0++; }
		($tp, $nt) = &Check($sc, $text);
#my($tp_sc, $nt_sc, $rSC) = &Check($sc, $text);
		if ($nt > 0) { $tp_sc += $tp; $nt_sc += $nt; $p_sc += $tp/$nt; } else { $sc0++; } #print STDERR "sc=$sc\n";}
#if (length($text)<500 and $nt_de>0 and $tp_de/$nt_de>0.3 and $nt_id>0 and $tp_id/$nt_id>0.2  and $nt_sc>0 and $tp_sc/$nt_sc>0.1) {print "tp_de=$tp_de, nt_de=$nt_de, Terms = ", join(', ', @$rDE), "\n", "tp_id=$tp_id, nt_id=$nt_id, Terms = ", join(', ', @$rID), "\n","tp_sc=$tp_sc, nt_sc=$nt_sc, Terms = ", join(', ', @$rSC), "\n","Text = $text\n"; exit;}
		$percent = $pro->ShowProgress($n/$N, $percent);
	}
	$percent = $pro->ShowProgress($n/$N, $percent);
	$STH->finish;
	$DBH->disconnect;
	print "Total records: $N\n",
		  "DE precision: Macro=", ($n>0?&ts($p_de/$n):"$p_de/$n"), 
			", Micro=($tp_de/$nt_de)=", ($nt_de>0?&ts($tp_de/$nt_de):"$tp_de/$nt_de"), 
			", No. of empty DE=$de0\n",
		  "ID precision: Macro=", ($n>0?&ts($p_id/$n):"$p_id/$n"), 
			", Micro=($tp_id/$nt_id)=", ($nt_id>0?&ts($tp_id/$nt_id):"$tp_id/$nt_id"), 
			", No. of empty ID=$id0\n",
		  "SC precision: Macro=", ($n>0?&ts($p_sc/$n):"$p_sc/$n"), 
			", Micro=($tp_sc/$nt_sc)=", ($nt_sc>0?&ts($tp_sc/$nt_sc):"$tp_sc/$nt_sc"), 
			", No. of empty SC=$sc0\n";
}

#sub ts { my($x, $n) = @_; $n=4 if not $n; return sprintf("%0.".$n."f", $x);  }
sub ts { 
	my($x, $n) = @_;
	if ($x == int($x)) { return $x; }
	else { $n=4 if not $n; return sprintf("%0.".$n."f", $x); }
}


sub TotalRecord {
	my($DBH, $Table, $DBID) = @_;
	$DBID = 'UT' if not $DBID;
	my $sql = "SELECT count($DBID) FROM $Table";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	return $STH->fetchrow_array;
}

# Given a string of text from a field (SC|ID|DE) and a string of text from TI and AB
#  Output the number of terms which occur both in the field and in the text
#	and the total number of terms in the field.
sub Check {
	my($field, $text) = @_;
	my($t, @Terms, $tp, $n);
#	@Terms = split /;\s*|[\/\(\)\&\[\]]/, $field; # split out each term based on the separator
	@Terms = split /[,;]\s*|[\/\(\)\&\[\]]/, $field; # 2007/07/27
	# next line lower-case and stem each word in each term (phrase)
	foreach $t (@Terms) { $t = join(' ', map{Stem::stem(lc $_)} split ' ', $t); }
#print STDERR "field=$field\nTerms = ", join(', ', @Terms), "\n" if $field =~ /Soil/;
	# for each term, see if it is in the $text
	foreach $t (@Terms) {
#print STDERR "t1=$t, " if $field =~ /Soil/;
		next if $t =~ /[^\w\- ]/;
#print STDERR "t2=$t\n" if $field =~ /Soil/;
		$n++;
	$tp ++ if ($text =~ /\b$t\b/); 
	} 
# return number of true positive and number of terms
#	return ($tp, $n, \@Terms);
	return ($tp, $n);
}


# For basic statistics of a document collection downloaded from ISI
# Given a DSN and a table in a DBMS, outputs number of terms, its min, 
#   its max, and empty records in TI, AB, DE, ID, SC, ...
sub AvgWordCount {
	my($DSN, $Table, $DB_Path) = @_;
	my $seg = SegWord->new( { 'WordDir'=>'SAM/word' } );
	my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'});

	my $DBH = &InitDBH($DSN, $DB_Path);
	my($N) = &TotalRecord($DBH, $Table);
print STDERR "Total records: $N\n";
	if ($main::OBioAbs) {&AvgWordCount_BioAbs($seg, $pro, $DBH, $Table, $N); exit; }
	my($n, $t, @Terms, $rAB, $text, $percent);
	my($ut, $py, $af, $au, $ti, $ab, $de, $id, $sc, $nr, $tc, $cr, $c1, $in, $dp, $la);
	my $sql = "SELECT UT, AF, AU, TI, AB, DE, ID, SC, NR, TC, CR, C1, IU, DP, LA FROM $Table";
# Replace next line with the above line on 2019/09/01
#	my $sql = "SELECT UT, AU, TI, AB, DE, ID, SC, NR, TC, CR, C1, IU, DP FROM $Table";
#	my $sql = "SELECT UT, PY, TI, AB, DE, ID, SC FROM $Table where DE like 'biomass recovery%'";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	$n = 0;
	my(@AFF, @AUU, @DEE, @IDD, @SCC, @C11, @IUU, @DPP, @LAA, @NRR);
	my($c, @AF, @AU, @TI, @AB, @DE, @ID, @SC, @NR, @TC, @CR, @C1, @IU, @DP, @LA, @C);
	foreach $c (@AF[0..3], @AU[0..3], @TI[0..3], @AB[0..3], @DE[0..3], @ID[0..3], 
	@SC[0..3], @NR[0..3], @TC[0..3], @C1[0..3], @IU[0..3], @DP[0..3], @LA[0..3]) { $c=0; }
	$AF[1] = $AU[1] = $TI[1] = $AB[1] = $DE[1] = $ID[1] = $SC[1] = $NR[1] 
		= $TC[1] = $C1[1] = $IU[1] = $DP[1] = $LA[1] = 100000;
	while (($ut, $af, $au, $ti, $ab, $de, $id, $sc, $nr, $tc, $cr, $c1, $in, $dp, $la) = $STH->fetchrow_array) {
		$n++;
# index 0: sum of word counts, 1: min of word count, 2: max, 3: empty record count
		$rAB = $seg->Tokenize($ti); # tokenize each word in the title
		$c = @$rAB; # word count
		$TI[0] += $c; $TI[1] = $c if $c < $TI[1] and $c>0;
		$TI[2]  = $c if $TI[2] < $c; $TI[3]++ if $c == 0;
		$rAB = $seg->Tokenize($ab); # tokenize each word in abstract
		$c = @$rAB; # word count
		$AB[0] += $c; $AB[1] = $c if $c < $AB[1] and $c>0;
		$AB[2]  = $c if $AB[2] < $c; $AB[3]++ if $c == 0;
		
		$c = @C = split /;\s*/, $af; push @AFF, @C;
		$AF[0] += $c;   $AF[1] = $c  if $c < $AF[1] and $c>0;
		$AF[2]  = $c if $AF[2] < $c; $AF[3]++ if $c == 0;
		$c = @C = split /;\s*/, $au; push @AUU, @C;
		$AU[0] += $c;   $AU[1] = $c  if $c < $AU[1] and $c>0;
		$AU[2]  = $c if $AU[2] < $c; $AU[3]++ if $c == 0;
		$c = @C = split /;\s*/, $de; push @DEE, @C;
		$DE[0] += $c;   $DE[1] = $c  if $c < $DE[1] and $c>0;
		$DE[2]  = $c if $DE[2] < $c; $DE[3]++ if $c == 0;
		$c = @C = split /;\s*/, $id; push @IDD, @C;
		$ID[0] += $c;   $ID[1] = $c  if $c < $ID[1] and $c>0;
		$ID[2]  = $c if $ID[2] < $c; $ID[3]++ if $c == 0;
		$c = @C = split /;\s*/, $sc; push @SCC, @C;
		$SC[0] += $c;   $SC[1] = $c  if $c < $SC[1] and $c>0;
		$SC[2]  = $c if $SC[2] < $c; $SC[3]++ if $c == 0;
		$c = @C = split /;\s*/, $c1; push @C11, @C;
		$C1[0] += $c;   $C1[1] = $c  if $c < $C1[1] and $c>0;
		$C1[2]  = $c if $C1[2] < $c; $C1[3]++ if $c == 0;
		$c = @C = split /;\s*/, $in; push @IUU, @C;
		$IU[0] += $c;   $IU[1] = $c  if $c < $IU[1] and $c>0;
		$IU[2]  = $c if $IU[2] < $c; $IU[3]++ if $c == 0;
		$c = @C = split /;\s*/, $dp; push @DPP, @C;
		$DP[0] += $c;   $DP[1] = $c  if $c < $DP[1] and $c>0;
		$DP[2]  = $c if $DP[2] < $c; $DP[3]++ if $c == 0;
		$c = @C = split /;\s*/, $la; push @LAA, @C;
		$LA[0] += $c;   $LA[1] = $c  if $c < $LA[1] and $c>0;
		$LA[2]  = $c if $LA[2] < $c; $LA[3]++ if $c == 0;
		
		$c = @C = split /;\s*/, $cr; push @NRR, @C;
		$NR[0] += $nr; $NR[1] = $nr if $nr < $NR[1] and $cr ne '';
		$NR[2]  = $nr if $NR[2] < $nr; $NR[3]++ if $nr == 0;
		$TC[0] += $tc; $TC[1] = $tc if $tc < $TC[1] and $tc ne '';
		$TC[2]  = $tc if $TC[2] < $tc; $TC[3]++ if $tc == 0;

		$percent = $pro->ShowProgress($n/$N, $percent);
	}
	$AF[4] = &Distinct(\@AFF); $AU[4] = &Distinct(\@AUU); $LA[4] = &Distinct(\@LAA); 
	$DE[4] = &Distinct(\@DEE); $ID[4] = &Distinct(\@IDD); $SC[4] = &Distinct(\@SCC);
	$C1[4] = &Distinct(\@C11); $IU[4] = &Distinct(\@IUU); $DP[4] = &Distinct(\@DPP);
	$NR[4] = &Distinct(\@NRR);
	$percent = $pro->ShowProgress($n/$N, $percent);
	$STH->finish;
	$DBH->disconnect;
	print "TI:\tEmptyRec=$TI[3]\tMaxWordCount=$TI[2]\tMinWordCount=$TI[1]\tAvg=", &ts($TI[0]/$N), "\n",
		  "AB:\tEmptyRec=$AB[3]\tMaxWordCount=$AB[2]\tMinWordCount=$AB[1]\tAvg=", &ts($AB[0]/$N), "\n",
		  "DE:\tEmptyRec=$DE[3]\tMaxWordCount=$DE[2]\tMinWordCount=$DE[1]\tAvg=", &ts($DE[0]/$N), "\tTotal=$DE[0]\tDistinctTotal=$DE[4]\n",
		  "ID:\tEmptyRec=$ID[3]\tMaxWordCount=$ID[2]\tMinWordCount=$ID[1]\tAvg=", &ts($ID[0]/$N), "\tTotal=$ID[0]\tDistinctTotal=$ID[4]\n",
		  "SC:\tEmptyRec=$SC[3]\tMaxWordCount=$SC[2]\tMinWordCount=$SC[1]\tAvg=", &ts($SC[0]/$N), "\tTotal=$SC[0]\tDistinctTotal=$SC[4]\n",
		  "NR:\tZeroRec=$NR[3]\tMax=$NR[2], Min=$NR[1]\tAvg=", &ts($NR[0]/$N), "\tTotal=$NR[0]\tDistinctTotal=$NR[4]\n",
		  "TC:\tZeroRec=$TC[3]\tMax=$TC[2], Min=$TC[1]\tAvg=", &ts($TC[0]/$N), "\tTotal=$TC[0]\n",
		  "AF:\tZeroRec=$AF[3]\tMax=$AF[2], Min=$AF[1]\tAvg=", &ts($AF[0]/$N), "\tTotal=$AF[0]\tDistinctTotal=$AF[4]\n",
		  "AU:\tZeroRec=$AU[3]\tMax=$AU[2], Min=$AU[1]\tAvg=", &ts($AU[0]/$N), "\tTotal=$AU[0]\tDistinctTotal=$AU[4]\n",
		  "C1:\tZeroRec=$C1[3]\tMax=$C1[2], Min=$C1[1]\tAvg=", &ts($C1[0]/$N), "\tTotal=$C1[0]\tDistinctTotal=$C1[4]\n",
		  "IU:\tZeroRec=$IU[3]\tMax=$IU[2], Min=$IU[1]\tAvg=", &ts($IU[0]/$N), "\tTotal=$IU[0]\tDistinctTotal=$IU[4]\n",
		  "DP:\tZeroRec=$DP[3]\tMax=$DP[2], Min=$DP[1]\tAvg=", &ts($DP[0]/$N), "\tTotal=$DP[0]\tDistinctTotal=$DP[4]\n",
		  "LA:\tZeroRec=$LA[3]\tMax=$LA[2], Min=$LA[1]\tAvg=", &ts($LA[0]/$N), "\tTotal=$LA[0]\tDistinctTotal=$LA[4]\n",
		  "Total Records=$N\n"; # 2011/04/13
}

sub Distinct { 
	my($rC) = @_; my($c, %C); 
	foreach $c (@$rC) { $C{$c}++; } 
	return scalar keys %C;
}

sub AvgWordCount_BioAbs{
	my($seg, $pro, $DBH, $Table, $N) = @_;
#	my $sql = "SELECT UT, AU, TI, AB, C1, IU, DP, MC, CC, TA, DS, CH, MQ, PR, MI FROM $Table";
	my $sql = "SELECT UT, AU, TI, AB, C1, IU, DP, MC, CC, MI FROM $Table";
#	my $sql = "SELECT UT, PY, TI, AB, DE, ID, SC FROM $Table where DE like 'biomass recovery%'";
	my $STH = $DBH->prepare($sql)
		   or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$STH->execute()
		   or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
	my($n, $t, @Terms, $rAB, $text, $percent);
	my($ut, $py, $au, $ti, $ab, $c1, $in, $dp, 
	   $mc, $cc, $ta, $ds, $ch, $mq, $pr, $mi);

	$n = 0;
	my($c, @AU, @TI, @AB, @C1, @IU, @DP,
		@MC, @CC, @TA, @DS, @CH, @MQ, @PR, @MI, @C);
	foreach $c (@AU[0..3], @TI[0..3], @AB[0..3], @MC[0..3], @CC[0..3], 
	@TA[0..3], @DS[0..3], @CH[0..3], @MQ[0..3], @PR[0..3], @MI[0..3], 
	@C1[0..3], @IU[0..3], @DP[0..3]) { $c=0; }
	$AU[1] = $TI[1] = $AB[1] = $MC[1] = $CC[1] = $TA[1] = $DS[1] = $DP[1]
		= $CH[1] = $MQ[1] = $PR[1] = $MI[1] = $C1[1] = $IU[1] = 100000;
	while (($ut, $au, $ti, $ab, $c1, $in, $dp, $mc, $cc, $mi) = $STH->fetchrow_array) {
		$n++;
# index 0: sum of word counts, 1: min of word count, 2: max, 3: empty record count
		$rAB = $seg->Tokenize($ti); # tokenize each word in the title
		$c = @$rAB; # word count
		$TI[0] += $c; $TI[1] = $c if $c < $TI[1] and $c>0;
		$TI[2]  = $c if $TI[2] < $c; $TI[3]++ if $c == 0;
		$rAB = $seg->Tokenize($ab); # tokenize each word in abstract
		$c = @$rAB; # word count
		$AB[0] += $c; $AB[1] = $c if $c < $AB[1] and $c>0;
		$AB[2]  = $c if $AB[2] < $c; $AB[3]++ if $c == 0;
		
		$c = @C = split /;\s*/, $au;
		$AU[0] += $c;   $AU[1] = $c  if $c < $AU[1] and $c>0;
		$AU[2]  = $c if $AU[2] < $c; $AU[3]++ if $c == 0;
		$c = @C = split /;\s*/, $c1;
		$C1[0] += $c;   $C1[1] = $c  if $c < $C1[1] and $c>0;
		$C1[2]  = $c if $C1[2] < $c; $C1[3]++ if $c == 0;
		$c = @C = split /;\s*/, $in;
		$IU[0] += $c;   $IU[1] = $c  if $c < $IU[1] and $c>0;
		$IU[2]  = $c if $IU[2] < $c; $IU[3]++ if $c == 0;
		$c = @C = split /;\s*/, $dp;
		$DP[0] += $c;   $DP[1] = $c  if $c < $DP[1] and $c>0;
		$DP[2]  = $c if $DP[2] < $c; $DP[3]++ if $c == 0;
			
		$c = @C = split /;\s*/, $mc;
		$MC[0] += $c;   $MC[1] = $c  if $c < $MC[1] and $c>0;
		$MC[2]  = $c if $MC[2] < $c; $MC[3]++ if $c == 0;
		$c = @C = split /;\s*/, $cc;
		$CC[0] += $c;   $CC[1] = $c  if $c < $CC[1] and $c>0;
		$CC[2]  = $c if $CC[2] < $c; $CC[3]++ if $c == 0;
#		$c = @C = split /;\s*/, $ta;
#		$TA[0] += $c;   $TA[1] = $c  if $c < $TA[1] and $c>0;
#		$TA[2]  = $c if $TA[2] < $c; $TA[3]++ if $c == 0;
#		$c = @C = split /;\s*/, $ds;
#		$DS[0] += $c;   $DS[1] = $c  if $c < $DS[1] and $c>0;
#		$DS[2]  = $c if $DS[2] < $c; $DS[3]++ if $c == 0;
#		$c = @C = split /;\s*/, $ch;
#		$CH[0] += $c;   $CH[1] = $c  if $c < $CH[1] and $c>0;
#		$CH[2]  = $c if $CH[2] < $c; $CH[3]++ if $c == 0;
#		$c = @C = split /;\s*/, $mq;
#		$MQ[0] += $c;   $MQ[1] = $c  if $c < $MQ[1] and $c>0;
#		$MQ[2]  = $c if $MQ[2] < $c; $MQ[3]++ if $c == 0;
#		$c = @C = split /;\s*/, $pr;
#		$PR[0] += $c;   $PR[1] = $c  if $c < $PR[1] and $c>0;
#		$PR[2]  = $c if $PR[2] < $c; $PR[3]++ if $c == 0;	
		$c = @C = split /;\s*/, $mi;
		$MI[0] += $c;   $MI[1] = $c  if $c < $MI[1] and $c>0;
		$MI[2]  = $c if $MI[2] < $c; $MI[3]++ if $c == 0;	
	$percent = $pro->ShowProgress($n/$N, $percent);
	}
	$percent = $pro->ShowProgress($n/$N, $percent);
	$STH->finish;
	$DBH->disconnect;
	print "TI: EmptyRec=$TI[3], MaxWordCount=$TI[2], MinWordCount=$TI[1], Avg=", &ts($TI[0]/$N), "\n",
		  "AB: EmptyRec=$AB[3], MaxWordCount=$AB[2], MinWordCount=$AB[1], Avg=", &ts($AB[0]/$N), "\n",
		  "MC: EmptyRec=$MC[3], MaxWordCount=$MC[2], MinWordCount=$MC[1], Avg=", &ts($MC[0]/$N), "\n",
		  "CC: EmptyRec=$CC[3], MaxWordCount=$CC[2], MinWordCount=$CC[1], Avg=", &ts($CC[0]/$N), "\n",
#		  "TA: EmptyRec=$TA[3], MaxWordCount=$TA[2], MinWordCount=$TA[1], Avg=", &ts($TA[0]/$N), "\n",
#		  "DS: EmptyRec=$DS[3], MaxWordCount=$DS[2], MinWordCount=$DS[1], Avg=", &ts($DS[0]/$N), "\n",
#		  "CH: EmptyRec=$CH[3], MaxWordCount=$CH[2], MinWordCount=$CH[1], Avg=", &ts($CH[0]/$N), "\n",
#		  "MQ: EmptyRec=$MQ[3], MaxWordCount=$MQ[2], MinWordCount=$MQ[1], Avg=", &ts($MQ[0]/$N), "\n",
#		  "PR: EmptyRec=$PR[3], MaxWordCount=$PR[2], MinWordCount=$PR[1], Avg=", &ts($PR[0]/$N), "\n",
		  "MI: EmptyRec=$MI[3], MaxWordCount=$MI[2], MinWordCount=$MI[1], Avg=", &ts($MI[0]/$N), "\n",
		  "AU: ZeroRec=$AU[3], Max=$AU[2], Min=$AU[1], Avg=", &ts($AU[0]/$N), "\n",
		  "C1: ZeroRec=$C1[3], Max=$C1[2], Min=$C1[1], Avg=", &ts($C1[0]/$N), "\n",
		  "IU: ZeroRec=$IU[3], Max=$IU[2], Min=$IU[1], Avg=", &ts($IU[0]/$N), "\n",
		  "DP: ZeroRec=$DP[3], Max=$DP[2], Min=$DP[1], Avg=", &ts($DP[0]/$N), "\n";
}


# Use options: $Ob1, $Ob0
sub ExtractEigenTrend {
	my($cid, $nt, $sim, $terms, $df, $df_ratio, $b1, $trend_type, @R, $Auth_ratio, $Authority);
	my(@Y2DF, $b0, $type, $prev_line, @R2, $b12);
	$prev_line = "";
	while (<>) { # read from @ARGV
		chomp;
		($cid, $nt, $sim, $terms, $df, $df_ratio, $b1, $trend_type, @R) = split /\t/, $_;
		$b0 = $df_ratio;  
		if ($_ =~ /\t\t$/) { # the last two columns are empty, do nothing
		} else { $Auth_ratio = pop @R;  $Authority = pop @R; }
	if ($_ =~ /^cid\t/ or $_ =~ /\tTotal\t/) { # the first and second line
		if ($_ =~ /\tTotal\t/) { @Y2DF = @R; } else { $b0 = "b0"; }
		print "$cid\t$nt\t$sim\t$terms\t$df\t$b0\t$b1\t$trend_type\t", join("\t", @R), "\n";
	} elsif ($_ =~ /\tSV_Trend\t/) { # the previous line is the terms
# We want the previous line's data, except $b0, $b1, $type
		($b0, $b1, $type) = &TrendType(\@Y2DF, \@R, 'arbitrary numeric value', $main::Ob1);
		($cid, $nt, $sim, $terms, $df, $df_ratio, $b12, $trend_type, @R2) = split /\t/, $prev_line;
		print "$cid\t$nt\t$sim\t$terms\t$df\t$b0\t$b1\t$type\t", join("\t", @R), "\n";
	}
	$prev_line = $_;
	}
}


# Given the agr_SC_clu0.0_Trend_abs_Sorted_type_C1_SVD.txt
# (or agr_DE_clu0.0_Trend_abs_Sorted_type_C1_SVD.txt),
#   filter out other countries not in : 日本,荷蘭,美國,韓國,大陸,台灣,以色列,和英國(或德國)
# skip those clusters whose trend_type is not the specified type
# or stop when $Ofc clusters have been output
# Use option -Ofc=30 or -Ofc=+ or -Ofc=++
sub FilterCountry {
	my($cid, $nt, $sim, $terms, $df, $df_ratio, $b1, $trend_type, @R);
	my($pat, $cid_p, $i, $flag, $df_ratio_p);
	$pat = $main::Ofc;  $pat =~ s/\+/\\\+/g;
#print STDERR "Ofc=$main::Ofc, pat=$pat\n";
	$cid_p = ''; $i = 0;
	$_ = <>; print $_; # print out first line
	if ($main::Ofc =~ /\+/) { $flag = 0; } else { $flag = 1; } # output the line when $flag is true
	while (<>) {
		($cid, $nt, $sim, $terms, $df, $df_ratio, $b1, $trend_type, @R) = split /\t/, $_;
		if ($cid ne $cid_p) {
			$i++; $cid_p = $cid;
			if ($main::Ofc>0 and $i > $main::Ofc) {
				last;
			} else { # Ofc=+ or Ofc=++
				if ($trend_type =~ /$pat/) { $flag = 1; } else { $flag = 0; }
			}
		}
		if ($main::Ofc =~ /\+/ and $df_ratio eq '' and $df_ratio_p ne '') { 
			# for each new cluster, even in the same cid
			if ($trend_type =~ /$pat/) { $flag = 1; } else { $flag = 0; }
		}
		if (not $flag) { $df_ratio_p = $df_ratio; next; }
		if ($df_ratio eq '') { # output this line unconditionally
		} elsif ($terms !~ /JAPAN|NETHERLANDS|USA|KOREA|CHINA|TAIWAN|ISRAEL|ENGLAND/) {
			$df_ratio_p = $df_ratio; next;
		}
		print $_;
		$df_ratio_p = $df_ratio;
	}
#print STDERR "i=$i\n";
}

# perl -s ISI.pl -Ov -Onorm=abs ..\Result\InfoBank_S3\2_4_4_0.01_PY.txt
sub TimeSeriesMatrix_Conversion {
	my($file) = @_;
	my($flag, $n, @M1, @M2, $line, @Head1, @Head2);
	@ARGV = ($file);	$flag = $n = 0;
	while ($line = <>) { # read in the matrix, set @Head1, @Head2, $M
		chomp; 
		if ($line =~ /Field: PY/) { 
			$flag = 1; # next 2 lines are headlines
			$line = <>; $line =~ s/\s+$//; @Head1 = split /\t/, $line;
			$line = <>; $line =~ s/\s+$//; @Head2 = split /\t/, $line;
			next;
		}
		if ($flag) {
			$line =~ s/\s+$//; # chop off empty white spaces
			@M2 = split /\t/, $line;
			for (my $i=0; $i<@M2; $i++) { $M1[$n][$i] = $M2[$i]; }
			$n++;
		}
	}
# Now we have @Head1, @Head2, and $M1
# Write out first line to show the field names
	my($i, $j, $df, @Year2DF, @Y2DF, $type, $b0, $b1, $ob0, $ob1);
	print "term\tdf\tb0\tb1\ttype";
	for($j=0; $j<$n; $j++) {  print "\t", $M1[$j][0]; } print "\n";

# Second line is the overall trend and its time series 
	for($i=1; $i<@Head1; $i++) {
		for($j=0; $j<$n; $j++) {
			$Y2DF[$j] += $M1[$j][$i]; $df += $M1[$j][$i];
		}
	}
	($ob0, $ob1, $type) = &TrendType(\@Y2DF, \@Y2DF, $ob0, $ob1);
print STDERR "The trend type for the 'Y2DF' is:\n $ob0, $ob1, $type\n";
	print "Total\t$df\t$ob0\t$ob1\t\t", join("\t", @Y2DF), "\n";

# For each line, compute the slope of linear regression
	for($i=1; $i<@Head1; $i++) {
		undef @Year2DF; $df = 0;
		for($j=0; $j<$n; $j++) {
			$df += $Year2DF[$j] = $M1[$j][$i];
		}
		($b0, $b1, $type) = &TrendType(\@Year2DF, \@Year2DF, $ob0, $ob1);
		print "$Head1[$i], $Head2[$i]\t$df\t$b0\t$b1\t$type\t", 
			join("\t", @Year2DF), "\n";
	}
}


# ---------------------------------------------------------------
# Read in C1_PY.txt and output C1_PY_5.txt
# This is only for 台經院
sub Every5Years {
	my(@L5, @L, $i, @LL, $in, $y1, $y2, $sum, $sumAll, $sy, $ey, $fy, $ly, @LT, @SA);
	$fy = 3000; $ly = 0; # fy : first year; ly : last year
	while ($in=<>) {
		push @LL, $in if $in=~/^Year/;
		push @LL, $in and print "\t_Total_" if $in=~/^\t[^\d]/;
#		print "\t$sumAll", $in  and next if $in=~/^\t\d/;
		if ($in =~ /^_Total_\t/) { # 2011/04/05
			@LT = split /\t/, $in; 
			splice @LT, 1, 0, $sumAll; 
			print join("\t", @LT);
			next;
		}
		if ($in =~ /^_Slope_\t/) {		
			@LT = split /\t/, $in; 
			splice @LT, 1, 0, &Compute_Slope(\@SA); 
			print join("\t", @LT);
			next;
		}
		print $in and next if ($in !~ /^\d\d\d\d/);
		chomp $in;
#print STDERR $in,"\n";
		@L = split ' ', $in;
		$sum=0; for($i=1; $i<@L; $i++) { $sum += $L[$i]; }
		$sumAll += $sum;
		splice @L, 1, 0, $sum; # add the total of the year in the first column
		print join("\t", @L), "\n";
		next if $L[0] < 1970 or $L[0] > 2014;
		$fy = $L[0] if $fy > $L[0];
		$ly = $L[0] if $ly < $L[0];
		push @SA, $sum; # for computing slope
#print STDERR join("\t", @L[0..4]), "\n";
		if ($L[0] % 5 == 0) {
			push @LL, join("\t", @L5) if @L5 != 0; # save to the output buffer
#print STDERR "$L[0]\t", join("\t", @L5[0..6]), "\n";
			@L5 = (); # clean the accumulator for every five years
		}
		for($i=1; $i<@L; $i++) { $L5[$i-1] += $L[$i]; }
	}
	push @LL, join("\t", @L5) if @L5 > 0;
	print "\n", shift @LL, "\t_Total_", shift @LL;
	@L = @L5 = ();
	for($i=0; $i<@LL; $i++) { # $LL[$i] contains the year's data
#		$y1 = 85+$i*5; $y1-=100 if $y1>=100; $y2=$y1+4;
#		$y1 = sprintf("%02d", $y1); $y2 = sprintf("%02d", $y2);
		if ($i==0) { $sy=$fy; $ey=4+($sy-$sy%5); }
		elsif ($i==@LL-1) { $sy = $ey+1; $ey = $ly; }
		else {$sy = $ey+1; $ey=4+$sy; }
		$y1 = $sy; $y1 =~ s/^\d\d//; $y2 = $ey; $y2=~s/^\d\d//;
		print "$y1-$y2\t$LL[$i]\n";
#print STDERR "$y1-$y2\t$LL[$i]\n";
		@L = split "\t", $LL[$i];
		for($in=0; $in<@L; $in++) { $L5[$in] += $L[$in]; }
	}
	print "_Total_\t", join("\t", @L5), "\n";
	my($j, @A, @SL, @Loop);
	@Loop = split /\t/, $LL[0]; # @Loop is only to know the number of columns
	for($j=0; $j<@Loop; $j++) {
		@A = ();
		for($i=0; $i<@LL; $i++) { 
			@LT = split /\t/, $LL[$i]; 	$A[$i] = $LT[$j];
		}
		$SL[$j] = &Compute_Slope(\@A);
	} 
	print "_Slope_\t", join("\t", @SL), "\n";
}

# Given C1_PY_5.txt and C1_PY_TC_5, generate C1_PY_CPP_5.txt
# perl -s ISI.pl -OPYCPP ..\Result\Edu0012\C1_PY_5.txt ..\Result\Edu0012\C1_PY_TC_5.txt > ..\Result\Edu0012\C1_PY_CPP_5.txt
# perl -s ISI.pl -OPYCPP ..\Result\Edu0512\C1_PY_5.txt ..\Result\Edu0512\C1_PY_TC_5.txt > ..\Result\Edu0512\C1_PY_CPP_5.txt
sub ComputePYCPP {
	my($f1, $f2) = @_; 
	my($rM1, $rM2, $rH, $m1, $n1, $m2, $n2, $i, $j, @A, @B, @M);
#	($rM1, $rH, $m1, $n1) = &Read_C1_PY($f1, 1, $rH); # set $rM1 and $rH

	($i, $j) = (0, 0); # index of matrix
	open F, $f1 or die "Cannot read file:'$f1'";
	while (<F>) {
		chomp;	@A = split /\t/, $_; next if @A <= 2;	next if $_ =~ /_Slope_/;
		@B = @A; # reset @B to @A initially
		if ($A[0] eq '') { # if country line like "	_Total_	USA	UK	..."
			for($j=2; $j<@A; $j++) { $rH->{$A[$j]} = $j; } # (Ctry => index)
		}
		for($j=0; $j<@B; $j++) { $rM1->[$i][$j] = $B[$j]; }
		$i++; # advance the matrix's row index to next line
	}
	close(F);
	($m1, $n1, $i, $j) = ($i, $j, 0, 0);
#	($rM2, $rH, $m2, $n2) = &Read_C1_PY($f2, 2, $rH); # use $rH and set $rM2
#print STDERR join(", ", map{"$_=>$rH->{$_}"} sort{$rH->{$a}<=>$rH->{$b}} keys %$rH), "\n";
	open F, $f2 or die "Cannot read file:'$f2'";
	while (<F>) {
		chomp;	@A = split /\t/, $_; next if @A <= 2;	next if $_ =~ /_Slope_/;
		undef @B; @B = @A; # reset @B to @A initially
		@B[0..1] = @A[0..1];
#print STDERR join", ", @B[0..5], "\n";
		if ($A[0] eq '') { # if country line like "	_Total_	USA	UK	..."
			for($j=2; $j<@A; $j++) { 
				$M[$j] = (defined $rH->{$A[$j]}?$rH->{$A[$j]}:$#A); # 2013/07/29
				$B[$M[$j]] = $A[$j];
			}
		} else { # not country line, but data line
			for($j=2; $j<@A; $j++) {
				$B[$M[$j]] = $A[$j];
			}
		}
# copy @B to ith row of matrix $rM
		for($j=0; $j<@B; $j++) { 
			$rM2->[$i][$j] = $B[$j]; 
#			print "($i,$j)=$rM2->[$i][$j]", "\t";
		} #print "\n";
		$i++; # advance the matrix's row index to next line
	} #print "\n";
	close(F);
	($m2, $n2) = ($i, $j);

	die "Two matrix mismatch: m1=$m1, m2=$m2, n1=$n1, n2=$n2\n" if ($m1 != $m2 or $n1 != $n2);
	for ($i=0; $i<$m1; $i++) {
		for ($j=0; $j<$n1; $j++) {
				print $rM1->[$i][$j] . "\t";
		}	print "\n";
	} print "\n";
	for ($i=0; $i<$m2; $i++) {
		for ($j=0; $j<$n2; $j++) {
			print $rM2->[$i][$j] . "\t";
		}	print "\n";
	} print "\n";

	for ($i=0; $i<$m1; $i++) {
		print $rM1->[$i][0] . "\t";
		for ($j=1; $j<$n1; $j++) {
			if ($rM1->[$i][$j] !~ /^\d+$/) { # if not digital number
				print $rM1->[$i][$j];
			} else {
				printf("%1.4f", (($rM1->[$i][$j]>0)?($rM2->[$i][$j]/$rM1->[$i][$j]):0));
			}
			print "\t";
		} print "\n";
}

sub Read_C1_PY {
	my($f, $flag, $rH) = @_; my($rM, $i, $j, @A, @B, @M); 
	($i, $j) = (0, 0); # index of matrix
	open F, $f or die "Cannot read file:'$f'";
	while (<F>) {
		chomp;		@A = split /\t/, $_;
		next if @A <= 2;
		next if $_ =~ /_Slope_/;
		@B = @A; # reset @B to @A initially
		if ($A[0] eq '') { # if country line like "	_Total_	USA	UK	..."
			for($j=2; $j<@A; $j++) { 
				if ($flag == 1) { # the first file's country line
					$rH->{$A[$j]} = $j ; # key==Cty -> value==index
					$M[$j] = $j; # isomorphic
				} else { # second file, move position, record mapping
					$M[$j] = $rH->{$A[$j]};
					$B[$M[$j]] = $A[$j];
				}
			}
		} else { # not country line, but data line
			if ($flag == 2) { # second file, move position
				for($j=1; $j<@A; $j++) {
					$B[$M[$j]] = $A[$j];
				}
			}
		}
		for($j=0; $j<@B; $j++) { $rM->[$i][$j] = $B[$j]; 	}
		$i++; # advance the matrix's row index to next line
	}
	close(F);
	return ($rM, $rH, $i, $j);
}}

sub OrganizeMI {
	my($file) = @_;  my($w, $f, %FL, @WL, $str, $i);
	while (<>) { 
		chomp; next if /^\s*$/; 
		($w, $f) = split /\t/, $_; 
		$i++; next if $f <=$main::Omi;
		next if $i>=500;
		$FL{$w}=$f; 
	}
	@WL = sort {$FL{$b}<=>$FL{$a}} keys %FL;
print STDERR "There are $i terms and only ", scalar @WL, " of them are to be organized.\n";
	$str = OrganizeWords(\@WL, \%FL);
	print "<HTML><head><title>MI</title></head>\n<body><center><h2>MI</h2>\n"
		, "$str<p></center></body></html>";
}

# Given $rWL, $rFL
sub OrganizeWords {
	my($rWL, $rFL) = @_;
	my($w, $wl, $maxl, $i, @SWL, @SortWL, @WLP, @a);
# 1. index words with their word length:Same-length words are put together
	foreach $w (@$rWL) {
# English word length is determined by number of spaces
	$wl =  $w =~ tr/ / / + 1; 
	$SWL[$wl] .= "$w \0 ";  # indexed by the same word length
	if ($maxl < $wl) { $maxl = $wl; }
	}
# 2. Sort words by word length DESC, record positions of each different length
	for ($i=$maxl; $i>0; $i--) {
#	@a = sort { $FL{$b} <=> $FL{$a} } split(/ \0 /, $SWL[$i]);
	@a = split(/ \0 /, $SWL[$i]);
	push(@SortWL, @a);
	$WLP[$i] = $WLP[$i+1] + @a; # Word Length Position for later use
	}
# Now we have @SortWL, @WLP 
#   For each keyword w, find those keywords contain w as substring
	my($t, %WStruct, %IsLinked);
	foreach $w (@$rWL) {
	$wl =  $w =~ tr/ / / + 1; 
	for ($i=$WLP[$wl+1]-1; $i>=0; $i--) {
		$t = $SortWL[$i];
# For single English word
#		if &stem($w) is a substring of $x
		if (!defined($IsLinked{$t}) && (index($t, &Stem::stem($w)) > -1)) {
#		if (index($x, $w) > -1) {  # if $w is a substring of $x
		$WStruct{$w} .= "$t \0 "; 
		$IsLinked{$t} = 1;
		}
	}
	}
	undef(@WLP); # no longer used
# Now we have @SortWL, %WStruct, %IsLined
#print "Sort by word length=@SortWL<br>\n";

# Output the result with HTML's <LI> tags
# Use: 
#   $check :  
# Set tmp:
#   $lnlt : current line limit
#   $lns  : current line number, base from 0
#   $clns : cumulative line number
#   $col : current column, base from 0
#   $mcol : max columns
# Set variables: 
#   $SBS : Sort By Structure
	my($SBS, $mcol, $lnlt, $clns, $lns, $col, $tn, $c, $ks, $d, %Stem, @C);
	$SBS = "<table border=1 width=100%><tr><td valign=top><OL start=1>\n";
	$mcol = 3;
	$lnlt = int(@$rWL / $mcol); $clns = $lns = $col = 0; $tn = 1;
	foreach $w (@$rWL) {
	if (not defined($IsLinked{$w})) { # if not linked
		$tn++;
		$c = $w; $c =~ s/ (\W)/$1/g;
		if (defined($Stem{$c})) {
		$SBS .= "<LI>$c ($Stem{$c}):$rFL->{$w}\n";
		} else {
		$SBS .= "<LI>$c : $rFL->{$w}\n";
		}
		@C = split(/ \0 /, $WStruct{$w});
		undef($ks);
		foreach $d (@C) { 
		$c = $d; $c =~ s/ (\W)/$1/g; 
		$ks .= "<LI>$c : $rFL->{$d}\n"; 
		}
		$SBS .= "<OL>$ks</OL>\n" if ($ks ne "");
		$lns += 1 + @C;
		if (($lns >= $lnlt) && ($col<($mcol-1))) {
		$col++; $clns += $lns; 
		$SBS .= "</OL><td valign=top><OL start=$tn>\n" if (@$rWL > $clns);
		$lnlt = int((@$rWL - $lns) / ($mcol-$col));
		$lns = 0; 
		}
	}
	}
	$SBS .= "</OL></table>\n";
	return $SBS;
}


#------------------------------------------------------------
# Given the fields, merge the corresponding files containing terms and their DFs, 
#   Output the merged term distributions for ease of comparison.
sub MergeFieldDistribution {
	my($field, $dir) = @_;
	my(@Files, $i, $f, $ff, @hT, $t, @Terms);
	@Files = split ' ', "_PY.txt _PY_TC.txt _PY_fc.txt _PY_TC_fc.txt";
	$i = 0;
	foreach $f (@Files) {
		$ff = $dir .'/'. $field . $f; #print STDERR "read $ff\n";
		if (-e $ff) { # added on 2019/08/25
			$hT[$i] = &ReadTerms($ff);
		} else {
			print("There is no need to deal with file: '$ff'.\n");
		}
		$i++;
	}
	@Terms = sort {$hT[0]->{$b} <=> $hT[0]->{$a}} keys %{$hT[0]};
	print "$field\tNC\tTC\tCPP\tFC\tFTC\tFCPP\n";
	foreach $t (@Terms) {
		print "$t\t$hT[0]->{$t}\t$hT[1]->{$t}\t", 
		($hT[0]->{$t}==0?0.0:&ts($hT[1]->{$t}/$hT[0]->{$t}, 2)), 
		"\t$hT[2]->{$t}\t$hT[3]->{$t}\t", 
		($hT[2]->{$t}==0?0.0:&ts($hT[3]->{$t}/$hT[2]->{$t}, 2)), 
		"\n";
	}
}

# perl -s ISI.pl -O2xls -OmaxR=200 envi01 ..\Result\envi01 ..\Result\envi01\envi01_by_field.xls
# perl -s ISI.pl -O2xls=2 -Of=..\Result\envi01_dc_S4\2_6_6_0.05_all_2.txt -OmaxR=200 envi01_dc_S4 ..\Result\envi01_dc_S4
sub Insert2Excel {
	my($GrpName, $dir, $XlsF) = @_;  my($Book);
	$XlsF = "$dir/_${GrpName}_by_field\.xls" if $XlsF eq '';
	if (-e $XlsF) { unlink($XlsF); }
	$Book = Spreadsheet::WriteExcel->new($XlsF);
	&MultiText2XLS($dir, $Book) if $main::O2xls==1;
	&SingleText2XLS($dir, $Book) if $main::O2xls==2;
	$Book->close();
}

sub MultiText2XLS {
	my($dir, $Book) = @_;
	my($f, @Files, $sh, $Sheet, $rRows, @col, $i, $j, $v, $encoding_name);
	@Files = glob("$dir/*.txt");
	foreach $f (@Files) {
#		next if $f !~ m{C1_PY_5.txt|SC_PY_5.txt|SC2C_PY_5.txt};
#		next if $f !~ m{SC2C_PY_5.txt};
		next if $f =~ /AF_PY|AU_PY|AU.txt|TC_PY/; # 2020/02/14
		if ($f=~m{([^/\\]+)\.txt$}) { $sh = $1; } else { $sh = $f; }
		$Sheet = $Book->add_worksheet($sh);
		$rRows = &Read2Rows($f, ($f=~/CPP|stat|Cite|UT|CJ_J9|J9_C1|J9_SC/));
		for($i=0; $i<@$rRows; $i++) {
			@col = split /\t/, $rRows->[$i];
			for($j=0; $j<@col; $j++) {
				$encoding_name = Encode::Detect::Detector::detect($col[$j]);
				if ($encoding_name !~ /UTF-8/i) { # if not utf8-encoded
					$v = decode("big5", $col[$j]);
#				if ($encoding_name !~ /big5/i) { # if utf8-encoded
#					$v = $col[$j];
#					from_to($v, 'big5', $encoding_name); 
				} else { $v = $col[$j]; }
#				$Sheet->write(&ToAA($j).($i+1), $v);
				$Sheet->write($i, $j, $v);
#print &ToAA($j).($i+1), "=>", $v, "\t";
			}
		} # for($i=0, ...
#print "\n";
	} # foreach 
}

sub ToAA { 
	my($i) = @_; my($j, $k, $c1, $c2); 
	$j = int($i/26); $k = $i%26;
	$c1 = ($j==0)?'':chr(65+$j-1); $c2 = chr(65+$k);
	return $c1.$c2;
}

sub Read2Rows {
	my($f, $intact) = @_;  my($flag, @R, @R2, @R3, @R4, $maxR);
	$maxR = ($main::OmaxR>0)?$main::OmaxR:200;
#	open F, '<:encoding(big5)', $f or die "Cannot read file:'$f'";
	open F, $f or die "Cannot read file:'$f'";
	while (<F>) { # Data read in is now in utf8 format.
		chomp; @R = split/\t/, $_;
		if ($intact) { push @R2, $_; next; }
		if (@R == 2) {
			push @R2, $_;
		} elsif ($_=~/Year\\/) { 
			$flag++; if ($flag==1) { push @R3, $_; } else { push @R4, $_; }
		} elsif ($flag == 1 and @R>2) { # e.g., Year\SC
			push @R3, $_;
		} elsif ($flag == 2 and @R>2) {
			push @R4, $_;
		}
	}
	close(F);
	@R = ();
	push @R, @R4 if @R4>0;
	push @R, @R3 if @R3>0;
	push @R, @R2[0..(@R2>$maxR?$maxR:@R2-1)];
	return \@R;
}

sub SingleText2XLS {
	my($dir, $Book) = @_;
	my($f, @Files, $sh, $Sheet, @Row, @col, $i, $j, $v, $flag, $TC, $rTC);
	my($encoding_name);
#	open F, '<:encoding(big5)', $main::Of 
	open F, $main::Of or die "Cannot read file:'$main::Of'\n";
	$flag = '';
	while (<F>) { 
		chomp; 	next if /^\s*$/; # skip if empty line
		if (/Field: \[?(\w+)\]?/) { 
			$flag = $1; # indicate current field
			$TC = 1 if $1 eq 'TC'; # indicate there is a TC field
			$i = 0; # reset Row ID
			$Sheet = $Book->add_worksheet($1);
			next;
		}
		next if $flag eq '';
		@col = split /\t/, $_;
		for($j=0; $j<@col; $j++) {
			if ($i == 1) { $col[$j] =~ s/(\d+ : \d+)[^\d]+/$1 Docs./; }
			# Change '筆' into ' Docs.';
			$encoding_name = Encode::Detect::Detector::detect($col[$j]);
			if ($encoding_name !~ /UTF-8/i) { # if not utf8-encoded
				$v = decode("big5", $col[$j]);
#			if ($encoding_name !~ /big5/i) { # if utf8-encoded
#				$v = $col[$j];
#				from_to($v, 'big5', $encoding_name); 
			} else { $v = $col[$j]; }
			#$v = decode("big5", $col[$j]); # This work! on 2010/12/03
			# When the texts are read from an html file, decode them to big5
			$Sheet->write($i, $j, $v);
			$rTC->[$j][$i] = $col[$j] if $flag eq 'TC'; # transpose the matrix
		} # for($j=0, ...
		$i++;
	} # while (<F>) { 
	return 1 unless $TC;
	$Sheet = $Book->add_worksheet('TCv');
	for($i=0; $i<@$rTC; $i++) {
		$TC = 0; @col = @{$rTC->[$i]};
		for($j=0; $j<@col; $j++) {
			$encoding_name = Encode::Detect::Detector::detect($col[$j]);
			if ($encoding_name !~ /UTF-8/i) { # if not utf8-encoded
				$v = decode("big5", $col[$j]);
#			if ($encoding_name !~ /big5/i) { # if utf8-encoded
#				$v = $col[$j];
#				from_to($v, 'big5', $encoding_name); 
			} else { $v = $col[$j]; }
			#$v = decode("big5", $col[$j]); # This work! on 2010/12/03
			# When the texts are read from an html file, decode them to big5
			$Sheet->write($i, $j, $v); 
			$TC += $col[$j] if $j>1;
		}
		$TC = 'Sum' if $i == 0;
		$Sheet->write($i, $j, $TC);
	}
	return 1;
}

# perl -s ISI.pl -Om2f ..\Result\Edu0512_JBC_S2\2_eLearn.txt ..\Result\Edu0512_JBC_S2\5_SciEdu.txt > ..\Result\Edu0512_JBC_S2\2_and_5.txt
sub MergeTwoFields {
	my($f1, $f2) = @_; my($rH1, $rH2, $k, $v, %H);
	$rH1 = &ReadTerms($f1);
	$rH2 = &ReadTerms($f2);
	while (($k, $v) = each %$rH1) { $H{$k} = $v; }
	while (($k, $v) = each %$rH2) { $H{$k} += $v; }
	print join ("\n", map{"$_\t$H{$_}"} sort {$H{$b}<=>$H{$a}} keys %H), "\n";
}
