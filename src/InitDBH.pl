# Create this file on 2017/08/29 by Sam Tseng
use DBI;
use DBI ':sql_types';
#	$DBH = &InitDBH($DSN, $DBpath, $user, $pass);

sub InitDBH { # for SQLite
	my($DSN, $Path, $user, $pass) = @_; my($DBH);
	$DBH = DBI->connect("DBI:SQLite:dbname=$Path",$user,$pass
		, {RaiseError => 1, AutoCommit => 1 } 
# AutoCommit must be 1, otherwise nothing happens in the $Path file.
	 ) or die "Can't make database connect: $DBI::errstr\n";
	$DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
	$DBH->{LongTruncOk} = 1;
	return $DBH;
}

sub InitDBH_for_MS_Access {
	my($DSN, $Path, $user, $pass) = @_; my($DBH);
	$DSN = "driver=Microsoft Access Driver (*.mdb, *.accdb);dbq=$Path" if $Path ne '';
	$DBH = DBI->connect( "DBI:ODBC:$DSN", $user, $pass, {
	  RaiseError => 1, AutoCommit => 0
	 }) or die "Can't make database connect: $DBI::errstr\n";
	$DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
	$DBH->{LongTruncOk} = 1;
	return $DBH
}
1;
