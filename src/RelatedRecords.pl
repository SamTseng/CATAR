# This program is to process the related records
# On 2006/03/29 by Yuen-Hsien Tseng
    use vars; use strict;
    use DBI;

    my $stime = time();
# perl -s RelatedRecords.pl -OISIt File_NanoPaperTW NanoPaperTW [DE|IT|SC]
# perl -s RelatedRecords.pl -OISIt NanoPaperWD RelatedRecordsAll_NoDup SC
    if ($main::OISIt) { &Get_ISI_Terms(@ARGV); &myexit(); }
# perl -s RelatedRecords.pl -Omtd ..\Result\NanoPaperTW_SC.txt ..\Result\NanoPaperWD_SC.txt
    if ($main::Omtd) { &MergeTermDistribution(@ARGV); &myexit(); }

# D:\demo\STPIWG\Source_Data>perl -s ..\src\filelist4.pl \
#    RelatedRecords.lst D:\STPI\Source_Data\RelatedRecords
#
#D:\demo\STPIWG\Source_Data>perl -s ..\src\RelatedRecords.pl \
#   RelatedRecords.lst > RelatedRecordsAll.txt
#D:\demo\STPIWG\Source_Data>perl -s ..\src\RelatedRecords.pl -OdelDup\
#   RelatedRecords.lst > RelatedRecordsAll_NoDup.txt
#  Fields mismatch at 112-th line  at ..\src\RelatedRecords.pl line 22, <F> line 113.
#  Fields mismatch at 94-th line  at ..\src\RelatedRecords.pl line 22, <F> line 95.
#  Fields mismatch at 491-th line  at ..\src\RelatedRecords.pl line 22, <F> line 492.
# It takes about 120 seconds.
#
# It seems that ACCESS cannot import RelatedRecordsAll.txt due to its size.
#  So let's split RelatedRecordsAll.txt into several small files.
# D:\demo\STPIWG\Source_Data>perl -s ..\src\RelatedRecords.pl -Osplit \
#   RelatedRecordsAll.txt RelatedRecords
# It takes about 120 seconds.

    my @AllFields = split /\s+/, 
"PT      AU      CA      TI      SO      SE      LA      DT      DE      ID
 AB      C1      RP      EM      CR      NR      TC      PU      PI      PA
 SN      J9      JI      PD      PY      VL      IS      PN      SU      SI
 BP      EP      AR      DI      PG      SC      GA      UT
";

# Note field name ID is renamed as IT
#    my @UsefulFields = split ' ',     "AU TI DE IT AB C1 TC JI PY SC UT";
#    my @UsefulFieldIndex = split ' ', " 1  3  8  9 10 11 16 22 24 35 37";
#    my $C1_index = 11; # authors' address field, containing country names
    my @UsefulFields = split ' ',     "AU TI SO DE ID AB C1 CR NR TC PY SC UT";
    my @UsefulFieldIndex = split ' ', " 1  3  4  8  9 10 11 14 15 16 24 35 37";
    my $C1_index = 11; # authors' address field, containing country names
    my $AB_index = 10;

# perl -s RelatedRecords.pl -Osplit RelatedRecordsAll.txt RelatedRecords
    if ($main::Osplit) { &SplitFiles(@ARGV); &myexit(); }
    my ($n, $m) = &ParseRelatedRecords(@ARGV);
    print STDERR "There are $n records.\n";
    print STDERR "There are $m records whose fields do not match.\n";
    &myexit();

sub myexit { print STDERR "# It takes ", time()-$stime, " seconds\n"; exit; }

# Use option : $Ocountry : to print the countries of all papers
# Use option : $OCPI : CPI (Cited Paper Id) is the file's basename which
#     indicates the cited paper id (the papers who cites that paper id are
#     all listed in the file.)
sub ParseRelatedRecords {
    my($FileList) = @_;
    my(@FL, $f, $line, @Fields, @Data, $i, $iFile, %UT, $CPI, $fn, $iw, $n);
    my(@Addresses, $addr, @A, %Country, %Distinct, $m);
#print "country=$main::Ocountry, OdelDup=$main::OdelDup\n"; exit;
    open FL, $FileList or die "Cannot read file:'$FileList'";
    @FL = <FL>; chomp @FL;
    close(FL); 
    $n = 0;  # to count the number of all records
    $m = 0; # number of records whose fields do not match
    foreach $f (@FL) {
    	next if $f =~ /^#|^\s*$/g;
    	if ($f =~ m#(\d+)(-\d+)?(.txt)$#i) { $CPI = $1; } else { $CPI = ''; }
   	open F, $f or die "Cannot read file:'$f'";
	$line = <F>; chomp $line; $iFile++;
	@Fields = split /\t/, $line;
#	@Fields = map {uc($_)} split /\t/, $line;
# next 5 lines are to check if the format is correct
if (join(",",@Fields) ne join(",",@AllFields)) { 
	warn "$f : ", scalar @Fields, " : ", join(",", @Fields), "\n";
	warn "$f : ", scalar @AllFields, " : ", join(",", @AllFields), "\n";
	next;
}  next if $main::Ochkfmt;
	if ($iFile == 1) { # print field names at the first line
#	    print "$line\n";
	    if (not $main::Ocountry) {
	    	print "CPI\t" if $main::OCPI;
		print join("\t", @Fields[@UsefulFieldIndex]), "\n"; 
	    }
	}
#exit;
	$i=0;
	while (<F>) {
	    $i++; chomp; @Data = split /\t/, $_;
	    if (@Data != @Fields) { 
	    	warn "Fields mismatch at $i-th line of file:$f, fields=", scalar @Data,"\n"; 
	    	$m++;
	    	next; 
	    }
# Now check if it exists before? If yes, skip, if no, write it out
	    if ($main::OdelDup and $UT{$Data[$#Data]}) { next; } 
	    $UT{$Data[$#Data]} = 1;  # last field (UT) is the key
# Now delete copyright information
	    $Data[$AB_index] =~ s/\(c\) *\d+ *Elsevier Ltd. All rights reserved.//ig;
# Now get the countries of authors from field C1
#print STDERR "$Data[$C1_index]\n";
	    @Addresses = split /;\s*/, $Data[$C1_index]; # addresses of authors
	    undef %Distinct; $iw = 0; # for preserve the original order 
	    foreach $addr (@Addresses) {
	    	$iw++;
	    	@A = split /\s+|,/, $addr; 
	    	$addr = $A[$#A]; # last field is country
#print STDERR "$Data[$#Data]\t$Data[$C1_index]\n" if $addr =~ /\d/;
		$addr =~ s/\"//; # delete abnormal character
		$addr = uc $addr; # convert to upper cases for consistency
		if ($addr =~ /\d/) { $addr = 'USA'; } # rule for USA
	    	$Country{$addr}++;  $Distinct{$addr}+= 1/($iw * $iw);
	    }
	    $Data[$C1_index] = 
	    	join("; ", sort {$Distinct{$b}<=>$Distinct{$a}} keys %Distinct);
#print STDERR "$Data[$C1_index]\n";

#	    print "$_\n";
	    if (not $main::Ocountry) {
	    	print "$CPI\t" if $main::OCPI;
	    	print join("\t", @Data[@UsefulFieldIndex]), "\n"; $n++;
	    }
	}
	close(F);
#	last;
    }
    return ($n, $m) if (not $main::Ocountry) ;
# print out authors' countries
    foreach $addr (sort {$Country{$b} <=> $Country{$a}} keys %Country) {
    	print "$addr\t$Country{$addr}\n";
    }
}

sub SplitFiles {
    my($file, $OutFile) = @_;  #    my $OutFile = 'RelatedRecords";
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


sub Get_ISI_Terms {
    my($DSN, $Table, $Fields) = @_; my($terms, @Terms, $t, %Terms);
    my($nr, $id);
    use DBI;
#    $DBH = DBI->connect( "DBI:ODBC:File",,, {
    my $DBH = DBI->connect( "DBI:ODBC:$DSN",,, { # use -Odsn=File_NSC
      RaiseError => 1, AutoCommit => 0
     }) or die "Can't make database connect: $DBI::errstr\n";
#    my $sql = "SELECT UT, $Fields FROM $Table where PY < 2006 and PY > 2002";
    my $sql = "SELECT UT, $Fields FROM $Table";
    my $STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
    $STH->execute()
           or die "Can't run SQL statement: SQL=$sql, $STH::errstr\n";
    $nr = 0;
    while (($id, $terms) = $STH->fetchrow_array) {
    	$nr++;
    	@Terms = split /;\s*/, $terms;
    	foreach $t (@Terms) {
	    $t =~ s/^\"|\"$//g;
	    $Terms{ $t }++;
    	} 
    }
    $STH->finish;
    $DBH->disconnect;
    @Terms = sort {$Terms{$b} <=> $Terms{$a}} keys %Terms;
    foreach $t (@Terms) {
    	print "$t\t$Terms{$t}\n";
    }
    print STDERR "\n# Number of records: $nr\n";
}

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

sub ReadTerms {
    my($file) = @_;
    my(%h, $t, $df);
    open F, $file or die "Cannot read file:'$file'";
    while (<F>) {
    	chomp; next if /^\s*$/g;
    	($t, $df) = split /\t/, $_;
    	$h{$t} = $df;
    }
    close(F);
    return \%h;
}

