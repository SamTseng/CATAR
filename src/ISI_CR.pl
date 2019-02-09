#!/usr/bin/perl -s

# This program is to process the Cited Reference
# On 2009/02/19 by Yuen-Hsien Tseng
	use vars; use strict;
	use Text::Soundex;
	use SAMtool::Progress;
	# require "InitDBH.pl"; # Added on 2017/08/28
  use InitDBH qw(InitDBH); # Added on 2019/01/23

	my $stime = time();

my %J9syn = ( # no more used, instead, use like -Omatch=..\Result\sam\CJ_J9.txt
	'J COMPUT ASSIST LEAR' => 'J COMPUT ASSIST LEARN',
	'ETR&D-EDUC TECH RES'=>'ETR&D-EDUC TECHNOL RES DEV'
#	'EDUC TECHNOL'=>'EDUC TECHNOL SOC'
);

# C:\CATAR_src\src>perl -s ISI_CR.pl -Omatch sam ..\Source_Data\sam\sam.mdb TPaper ..\Result\sam\CR.txt ..\Result\sam\CR_UT.txt > ..\Result\sam\CR_UT_stderr.txt
# C:\CATAR_src\src>perl -s ISI_CR.pl -Omatch=..\Result\sam\CJ_J9.txt sam ..\Source_Data\sam\sam.mdb TPaper ..\Result\sam\CR.txt ..\Result\sam\CR_UT.txt > ..\Result\sam\CR_UT_stderr.txt
	&Match_Cited_References(@ARGV) if ($main::Omatch);

# Note there are four options for -Ocite: none, -Opair, -Oau, and -Oj9
# perl -s ISI_CR.pl -Ocite -Opair sam ..\Source_data\sam\sam.mdb TPaper CR_UT > ..\Result\sam\Cite.txt
# 結果 Cite.txt 也會插入到資料庫的Cite資料表
# perl -s ISI_CR.pl -Ocite sam ..\Source_data\sam\sam.mdb TPaper CR_UT > ..\Result\sam\CiteAU.txt
# perl -s ISI_CR.pl -Ocite -Oau sam ..\Source_data\sam\sam.mdb TPaper CR_UT > ..\Result\sam\CiteAU.txt
# perl -s ISI_CR.pl -Ocite -Oj9 sam ..\Source_data\sam\sam.mdb TPaper CR_UT > ..\Result\sam\CiteJ9.txt
	&Build_Citing2Cited(@ARGV) if $main::Ocite;

	print STDERR "# It takes ", time()-$stime, " seconds\n"; 
	exit;

sub myexit { print STDERR "# It takes ", time()-$stime, " seconds\n"; exit; }



# Given a DSN, a Table in a DBMS, and the file containing the accumulated CR,
#   Output "UT	CR	TC" to show which CR corresponds to which record
sub Match_Cited_References {
	my($DSN, $DBpath, $Table, $CRfile, $OutFile) = @_;
	my($DBH, $STH, $STH1, $STH2, $sql, $pro, $percent);
	my($r, $cr, $i, $n, $m, $rUT, $ut, $rCJ2J9, $tc, @CR_UT);
	
	$rCJ2J9 = &ReadCJ_J9($main::Omatch) if -r $main::Omatch;
	
	$DBH = &InitDBH($DSN, $DBpath);

	$i = $n = $m = 0;
	open F, $CRfile or die "Cannot read file:'$CRfile'";
	while (<F>) { last if /^Cited /; $n++; } close(F); # to get the value of $n
	$STH = $DBH->prepare("SELECT COUNT(*) FROM $Table");
	$STH->execute();	($m) = $STH->fetchrow_array;	$STH->finish;
print STDERR "Matching $n cited references with $m records in your collection ...\n";
	print STDERR "It may take very long time since there are $n x $m=",$n*$m,
		" pairs to be matched.\n" if $n*$m>1000000;

	$sql = "SELECT UT, PY, AU, J9, VL, BP FROM $Table where "
			. "BP=? and VL=? and PY=? and J9=?";
#			. "BP=? and VL=? and PY=? and J9 like '%$j9%'";
	$STH1 = $DBH->prepare($sql)
			or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
	$sql = "SELECT UT, PY, AU, J9, VL, BP FROM $Table where "
			. "BP=? and PY=? and J9=?";
#			. "BP=? and PY=? and J9 like '%$j9%'";
	$STH2 = $DBH->prepare($sql)
			or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";

	open Out, ">$OutFile" or die "Cannot write to file:'$OutFile'";
	print Out "UT\tCR\tTC\n";
	$pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'});
	
	@ARGV = ($CRfile);
	while (<>) { 
		$i++; chomp; last if /^Cited /; 
		$percent = $pro->ShowProgress($i/$n, $percent);
		($cr, $tc) = split /\t/, $_;
#		($rUT) = &Match_CitedReference($DBH, $Table, $cr, $i, $rCJ2J9);
		($rUT) = &Match_CitedReference($STH1, $STH2, $cr, $i, $rCJ2J9);
print "\ni=$i, '$cr'=>", join(",", @$rUT), "\n" if (scalar @$rUT)>1;
		foreach $ut (@$rUT) {
			print Out "$ut\t$cr\t$tc\n"; 
			push @CR_UT, "$ut\t$cr\t$tc";
		}
	}
	$percent = $pro->ShowProgress($i/$n, $percent);
	$sql = "INSERT INTO CR_UT (UT, CR, TC) VALUES (?, ?, ?)";
	&Insert2DB($DBH, 'CR_UT', $sql, \@CR_UT); # delete existing records before insertion
	$DBH->disconnect;
	close(Out);
}

# Given a cited reference like:"GAMSON WA, 1989, AM J SOCIOL, V95, P1"
#   look for the database to see if it corresponds to any existing record.
# Return the hash with key=cr and value=UT
sub Match_CitedReference {
#	my($DBH, $Table, $cr, $i, $rCJ2J9) = @_;
	my($STH1, $STH2, $cr, $i, $rCJ2J9) = @_;
	my(@UT, $sql, $STH, $j, $k);
	my($au, $py, $j9, $vl, $bp);
	my($UT, $PY, $AU, $J9, $VL, $BP);

	($au, $py, $j9, $vl, $bp) = split /, /, $cr;
	# GAMSON WA, 1989, AM J SOCIOL, V95, P1
	if ($py !~ /^\d+$/) { ($py, $j9, $vl, $bp) = split /, /, $cr; $au = ''; }
	# 1990, EDUC RES, V19, P2
	# HOUSE ER, 1998, AM J EVAL, V19, P233P	1
#	$j9 = $J9syn{$j9} if $J9syn{$j9};
	$j9 = $rCJ2J9->{$j9} if $rCJ2J9->{$j9};
	if ($bp =~ /^P/ and $vl =~ /^V/ and $j9 ne '' and $py =~ /^\d+$/) {
#		$sql = "SELECT UT, PY, AU, J9, VL, BP FROM $Table where "
#			. "BP=? and VL=? and PY=? and J9=?";
##			. "BP=? and VL=? and PY=? and J9 like '%$j9%'";
#		$STH1 = $DBH->prepare($sql)
#			or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
		$vl =~ s/^V//; $bp =~ s/^P//;
		$STH1->execute($bp, $vl, $py, $j9)
#		$STH1->execute($bp, $vl, $py)
			or die "i=$i, Can't run SQL statement: $STH1::errstr\n";
		$STH = $STH1;
	} elsif ($vl =~ /^P/ and $j9 ne '' and $py =~ /^\d+$/) { 
			# COLLINS A, 1989, KNOWING LEARNING INS, P453
		$bp = $vl; $vl = '';
#		$sql = "SELECT UT, PY, AU, J9, VL, BP FROM $Table where "
#			. "BP=? and PY=? and J9=?";
##			. "BP=? and PY=? and J9 like '%$j9%'";
#		$STH = $DBH->prepare($sql)
#			or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
		$bp =~ s/^P//;
		$STH2->execute($bp, $py, $j9)
#		$STH2->execute($bp, $py)
			or die "i=$i, Can't run SQL statement: $STH2::errstr\n";
		$STH = $STH2;
	} else { return (\@UT); }
	$k = $j = 0;
#print "\nsql=$sql\n$cr=>$bp, $vl, $py, $j9, $au\n";
	while (($UT, $PY, $AU, $J9, $VL, $BP) = $STH->fetchrow_array) {
		$k++;
#print "SELECTED: $UT, $PY, $VL, $BP, $AU, $J9\n";
		if (not &Match_Author($au, $AU)) {
	print "CR.txt(line i=$i)=>CR.au=\"$au\" did not match AU=\"$AU\", UT=$UT, J9=$J9\n";
			next;
		}
		$j++;
		push @UT, $UT;
	}
print "i=$i, Match $k records and resolve into $j record(s)\n" if $k!=$j;
	return (\@UT);
}

sub Match_Author {
	my($au, $AU) = @_; my($r);
	# $au='CHRISTMANN E'|'Tergan, SO'; is from CR
	# $AU='Christmann, E; Badgett, J;'|'Tergan, SO' is from AU
	($AU, $r) = split /; /, $AU;
	$AU =~ s/, / /;
	# $au = 'KEKKONENMONETA S'
	# $AU = 'Kekkonen-Moneta, S; Moneta, GB'
	# $au = 'ODONOGHUE J'
	# $AU = 'O'Donoghue, J; Singh, G; Dorward, L'
	$AU =~ s/[\'\-]//g;
	# $au = 'VANSCHAIK P'
	# $AU = 'van Schaik, P; Pearson, R; Barker, P'
	$AU =~ s/(\w) (\w)/$1$2/;
	# $au => 'ISI:A1996VH96200002	SCOTT G, 1996, INNOV EDUC TRAIN INT, V33, P154	4'
	# $AU = 'Rushby, N', i.e., authors are different!!
#	$au = lc $au;  $AU = lc $AU;
#	return index($AU, $au)==0?1:0; # if match, should be at position 0
	$AU = uc $AU; # 2011/02/19
	return soundex($AU) eq soundex($au);
}

sub ReadCJ_J9 {
	my($file) = @_; my($CJ, $J9, $r, $n, %CJ2J9);
	open F, $file; $_ = <F>; # read off field line
	$n = 0;
	while (<F>) {
		chomp; next if /^\s*$/; # skip empty line
		($J9, $CJ, $r) = split /\t/, $_;
		($n++ and $CJ2J9{$CJ} = $J9) if $CJ ne '';
	}
	close(F);
	print STDERR "$n pairs of CJ vs J9 read...\n";
	return \%CJ2J9;
}


sub Build_Citing2Cited {
	my($DSN, $DB_Path, $TPaper, $CR_UT) = @_;
	my($DBH, $STH, $sql, $STH2, $sql2, $pro, $percent, $nr, $n);
	my(@CR, @CR2, $cr, $UT, $CR, $ut, $actor, $ac, %Seen, %SeenRT);
	my($rCR2UT, $rUT2PY, $rUT2AU, $rUT2J9, $rAc2TC, $id, @Pair);
	
	$DBH = &InitDBH($DSN, $DB_Path);
	$rCR2UT = &GetCR2UT($DBH, $CR_UT);
	($rUT2PY, $rUT2AU, $rUT2J9, $rAc2TC) = &GetUT2Fields($DBH, $TPaper);

	$sql = "SELECT UT, CR FROM $TPaper";
	$STH = $DBH->prepare($sql) or die "prepare fail: SQL=$sql, $DBI::errstr\n";
	$STH->execute() or die "execute fail: SQL=$sql, $STH::errstr\n";
	$nr = 0; $id = 0;
	while (($UT, $CR) = $STH->fetchrow_array) {
		$nr++; @CR2 = ();
		$n = @CR = split /;\s*/, $CR;
		foreach $cr (@CR) { # foreach $cr in the CR field of paper UT
			next if $rCR2UT->{$cr} eq ''; # skip if current UT did not cite any other UT
# insert $UT and $rCR2UT->{$cr} into Table 'Cite'
#		$STH2->execute($UT, $rCR2UT->{$cr}) or die "$STH::errstr";
			if ($main::Opair) {
				print "$UT\t$rCR2UT->{$cr}\n";
				push @Pair, "$UT\t$rCR2UT->{$cr}";
			}
			push @CR2, $rCR2UT->{$cr}; # save the cited UT in @CR2
		}
		next if @CR2 == 0 or $main::Opair; 
# The following codes output the citation relationship among the downloaded data
# in the format similar to related terms, which will be used by other program
# to produce Pajek graph.
# The format would look like: 1	PY:AU	TC+1	PY1:AU1	TC1+1	PY2:AU2	TC2+1
		$actor = $rUT2PY->{$UT}.':'.$rUT2AU->{$UT}.':'.&Coding($UT); # 2011/04/03
		$actor = $rUT2PY->{$UT}.':'.$rUT2AU->{$UT} if $main::Oau;
		$actor = $rUT2PY->{$UT}.':'.$rUT2J9->{$UT} if $main::Oj9;
		next if $Seen{$actor};
		$id++;
		print "$id\t".$actor."\t".($rAc2TC->{$actor}+1)."\t";
		# the format is: ID, keyword, DF (add 1 to ensure non-zero value)
		%SeenRT = (); # initialize to empty
		foreach $ut (@CR2) {
#			$ac = '';
			$ac = $rUT2PY->{$ut}.':'.$rUT2AU->{$ut}.':'.&Coding($ut); # 2011/04/03
			$ac = $rUT2PY->{$ut}.':'.$rUT2AU->{$ut} if $main::Oau;
			$ac = $rUT2PY->{$ut}.':'.$rUT2J9->{$ut} if $main::Oj9;
			next if $SeenRT{$ac};
			print $ac."\t".($rAc2TC->{$ac}+1)."\t";
			# the format is: RT1, DF1, RT2, DF2, ... (add 1 to ensure non-zero DF)
			$SeenRT{$ac}++;
		}
		print "\n"; $Seen{$actor}++;
	}
	$STH->finish;
	$sql = "INSERT INTO Cite (Citing, Cited) VALUES (?, ?)";
	&Insert2DB($DBH, 'Cite', $sql, \@Pair) if $main::Opair;
	$DBH->disconnect;
}

sub Coding { my($UT) = @_; my(@C, $c, $sum);
	@C = split '', $UT;
	foreach $c (@C) { $sum += ord($c); } 
	return sprintf("%2d", $sum%100);
}

sub GetUT2Fields {
	my($DBH, $TPaper) = @_;  
	my($sql, $STH, $UT, $PY, $TC, $AU, @AU, $J9, $Ac);
	my(%UT2PY, %UT2AU, %UT2J9, %Ac2TC);
	$sql = "SELECT UT, PY, TC, AU, J9 FROM $TPaper";
	$STH = $DBH->prepare($sql) or die "prepare fail: SQL=$sql, $DBI::errstr\n";
	$STH->execute() or die "execute fail: SQL=$sql, $STH::errstr\n";
	while (($UT, $PY, $TC, $AU, $J9) = $STH->fetchrow_array) {
		$UT2PY{$UT} = $PY; $UT2J9{$UT} = $J9;
		@AU = split /;\s*/, $AU; $UT2AU{$UT} = $AU[0]; # the first author
		$Ac = ''; $Ac = $AU[0] if $main::Oau; $Ac = $J9 if $main::Oj9;
		$Ac2TC{"$PY:$Ac"} += $TC; 
	}
	$STH->finish;
	return (\%UT2PY, \%UT2AU, \%UT2J9, \%Ac2TC);
}

sub GetCR2UT {
	my($DBH, $CR_UT) = @_;  my($sql, $STH, $UT, $CR, %CR2UT);
	$sql = "SELECT UT, CR FROM $CR_UT";
	$STH = $DBH->prepare($sql) or die "prepare fail: SQL=$sql, $DBI::errstr\n";
	$STH->execute() or die "execute fail: SQL=$sql, $STH::errstr\n";
	while (($UT, $CR) = $STH->fetchrow_array) {	$CR2UT{$CR} = $UT; }
	$STH->finish;
	return \%CR2UT;
}

sub Insert2DB {
	my($DBH, $Table, $sql, $rData) = @_; my($STH, @Data, $d);
# First delete existing records in the Table
	$STH = $DBH->prepare("DELETE FROM $Table") or die "prepare fail: $DBI::errstr\n";
	$STH->execute() or die "execute fail: $STH::errstr\n";
# Next insert new records into the table
#	$sql = "INSERT INTO Cite (Citing, Cited) VALUES (?, ?)"; 
	$STH = $DBH->prepare($sql) or die "prepare fail: SQL=$sql, $DBI::errstr\n";
	foreach $d (@$rData) {
		@Data = split /\t/, $d;
		$STH->execute(@Data) or die "execute fail: SQL=$sql, $STH::errstr\n";
	}
	$STH->finish;
}
