#!/usr/bin/perl -s

    use strict; use vars;
    use lib "/demo/DbXls";
    use DbXls;
    use Win32::OLE qw(in with);
    use Win32::OLE::Const 'Microsoft Excel';
    $Win32::OLE::Warn = 3; # die on errors...

# 下面的命令從Excel中插入資料到資料庫
# C:\CATAR_src\Source_Data\eport>copy \CATAR_src\src\Paper_org.mdb eport.mdb
# C:\CATAR_src\Source_Data\eport>perl -s eportfolio.pl -Oxls -Odebug C:\CATAR_src\Source_Data\eport\bib.xls C:\CATAR_src\Source_Data\eport\ref.xls eport.mdb
    &AddDB_from_File(@ARGV) if $main::Oxls;
    exit;

sub myexec {
    my($cmd) = @_;    print STDERR "$cmd\n";
    system($cmd)==0 or die "'$cmd' failed: $?\n";
}

sub AddDB_from_File {
    my($bibFile, $refFile, $dbFile) = @_;    my($oDX, $field, $Excel);
    $oDX = DbXls->new( { 'DB_Type'=>'MDB', 'DB_Dir'=>$dbFile } );
    $oDX->SetValue('debug', $main::Odebug) if defined $main::Odebug;
print STDERR "$bibFile, $refFile, $dbFile\n";
# get already active Excel application or open new
	$Excel = Win32::OLE->GetActiveObject('Excel.Application')
		|| Win32::OLE->new('Excel.Application', 'Quit');
    my($id, $au, $py, $ti, $Book, $Sheet, $sh, $r, @CR); 

# Read the Cited References first and save them in @CR
    $Book = $Excel->Workbooks->Open($refFile);
	$Sheet = $Book->Worksheets(1); # open the default sheet, normally names 'Sheet1'
	foreach my $row (2..100000) {
	    last unless defined $Sheet->Cells($row,1)->{'Value'};
	    # print out the contents of a cell
#	    foreach my $col (1..3) {
#		printf "At ($row, $col) the value is %s and the formula is %s\n",
#		$Sheet->Cells($row,$col)->{'Value'},
#		$Sheet->Cells($row,$col)->{'Formula'};
	    $id = $Sheet->Cells($row,1)->{'Value'};
	    $au = $Sheet->Cells($row,3)->{'Value'};
	    ($au, $r) = split/、/, $au;
	    $py = $Sheet->Cells($row,4)->{'Value'};
	    $ti = $Sheet->Cells($row,5)->{'Value'};
	    push @{$CR[$id]}, "$au, $py, $ti, , "; 
#print "$id, $au, $py, $ti\n"; next;	    
	}
    $Book->Close;  # clean up after ourselves

# Now, read the partial bibliographic records, and insert them into a DB together with CR
	$oDX->InitDB();
	$oDX->SimpleSQL("Delete FROM TPaper");
    $Book = $Excel->Workbooks->Open($bibFile);
	$Sheet = $Book->Worksheets(1);  # open the default sheet, normally names 'Sheet1'
	my($AU, $AF, $TI, $SO, $DE, $AB, $C1, $CR, $TC, $PY, $VL, $BP);
	my($sql, $sth, $dbh, $r, @R);
	$id = 0;
	foreach my $row (3..100000) {
	    last unless defined $Sheet->Cells($row,1)->{'Value'};
	    $id ++;
	    $AU = $Sheet->Cells($row,1)->{'Value'};
	    $AF = $Sheet->Cells($row,2)->{'Value'};
	    $TI = $Sheet->Cells($row,3)->{'Value'};
	    $SO = $Sheet->Cells($row,4)->{'Value'};
	    $DE = $Sheet->Cells($row,5)->{'Value'};
	    $AB = $Sheet->Cells($row,7)->{'Value'};
	    $C1 = 'Taiwan';
	    $CR = $Sheet->Cells($row,9)->{'Value'};
	    $CR = join("; ", @{$CR[$CR]});
	    $TC = $Sheet->Cells($row,11)->{'Value'};
	    $PY = $Sheet->Cells($row,13)->{'Value'};
	    $BP = $Sheet->Cells($row,15)->{'Value'};
#print "$AU, $PY, $TI\n"; next;    
		$sql = "INSERT INTO TPaper (UT, TC, PY, BP, C1, AU, AF, SO, [IN], TI, DE, AB, CR) "
			 . "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
		$dbh = $oDX->{'DBH'};
		$sth = $dbh->prepare($sql)
			or die "Couldn't prepare statement: $sql" . $dbh->errstr;
	    $sth->bind_param(6, $sth, DBI::SQL_LONGVARCHAR); # so that the Chinese characters
	    $sth->bind_param(8, $sth, DBI::SQL_LONGVARCHAR); # can be correctly shown in 
	    $sth->bind_param(9, $sth, DBI::SQL_LONGVARCHAR); # MS Access 2010
	    $sth->bind_param(10, $sth, DBI::SQL_LONGVARCHAR);
	    $sth->bind_param(11, $sth, DBI::SQL_LONGVARCHAR);
	    $sth->bind_param(12, $sth, DBI::SQL_LONGVARCHAR);
	    $sth->bind_param(13, $sth, DBI::SQL_LONGVARCHAR);
		eval { $sth->execute($id, $TC, $PY, $BP, $C1, $AU, $AF, $SO, $SO, $TI, $DE, $AB, $CR)
			or die "Couldn't execute statement: $sql" . $sth->errstr; };
	}
    $Book->Close;  # clean up after ourselves
}



1;
