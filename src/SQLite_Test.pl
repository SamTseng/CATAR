#/usr/bin/perl -s
# This program is to test SQLite manipulation in Perl, written by Sam Tseng.
# Or more accurately, to test  require "InitDBH.pl"; whatever database it uses.

# perl -s SQLite_Test.pl Sam ..\Source_Data\Sam\Sam.db TPaper 'ISI:1' VL 2
# The above line using single quote would not work. But next line do!
# perl -s SQLite_Test.pl Sam ..\Source_Data\Sam\Sam.db TPaper "ISI:A1" VL 2

# Delete from TPaper
# Insert into TPaper (UT) values ('ISI:A1992HU15600007')
# UPDATE TPaper Set BP = 30 WHERE UT = 'ISI:A1'
# perl -s SQLite_Test.pl movie ..\Source_Data\movie\movie.db TPaper '98458' VL 2

use Encode;
use Encode::TW; # this line must exist, despite we have the next line
use Encode qw/encode decode from_to/;

use Encode::TW; # this line must exist, despite we have the next line
use Encode qw/encode decode/;
use Encode::Detect::Detector;

  use vars; use strict;
  require "InitDBH.pl";
  my($DSN, $DB_Path, $Table, $ut, $fk, $fv) = @ARGV;
  my($sql, $sth);
	my $DBH = &InitDBH($DSN, $DB_Path);
  &FetchRows($DBH, $Table, $ut); # success
  exit;
  &DeleteTable($DBH, $Table); # seems to work, but not in file
  &FetchRows($DBH, $Table, $ut); # success
  &InsertRow1($DBH, $Table, $ut, $fk, $fv);
  &FetchRows($DBH, $Table, $ut); # success
  $DBH->disconnect; 
  exit();
  
# Before insertion, delete the records in $Table
sub DeleteTable {
	my($DBH, $Table) = @_;
	$sql = "Delete from $Table";
print "sql=$sql\n";

	my $rv = $DBH->do($sql) or die $DBH->errstr;
	if( $rv < 0 ) {
   print "1:", $DBI::errstr;
	} else {
   print "1: Total number of rows deleted : $rv\n";
	}
	
# Another attempt to delete all rows in the table
	$sth = $DBH->prepare($sql);
	eval { $rv = $sth->execute() or die $DBH->errstr; };
	print STDERR "Failed to delete: $sql" if ($@);
	if( $rv < 0 ) {
   print "2:", $DBI::errstr;
	} else {
   print "2: Total number of rows deleted : $rv\n";
	}
}

sub InsertRow1 {
	my($DBH, $Table, $ut, $fk, $fv) = @_;
	&InsertKey($DBH, $Table, $ut);
	&UpdateField1($DBH, $Table, $ut, $fk, $fv);
}

sub InsertKey {
	my($DBH, $Table, $ut) = @_;
	$sql = "INSERT INTO $Table (UT) VALUES (?)";
print STDERR "sql=$sql\n";
	$sth = $DBH->prepare($sql);
	$sth->execute($ut) 
}

sub UpdateField1 {
	my($DBH, $Table, $ut, $fk, $fv) = @_;
	$sql = "UPDATE $Table Set $fk = ? WHERE UT = ?";
print STDERR "sql=$sql\n";
	$sth = $DBH->prepare($sql);
	$sth->execute($fv, $ut) or die $DBH->errstr;
}
 
sub FetchRows {
	my($DBH, $Table, $ut) = @_;
#  $sql = "select AU, BP, UT from $Table";
  $sql = "select * from $Table where UT = ?";
	$sth = $DBH->prepare($sql);
	$sth->execute($ut) or die $DBH->errstr; # This works!
#	$sth->execute() or die $DBH->errstr; 
	print "Fetch next row with ut=$ut\n";
  while (my @V = $sth->fetchrow_array()) {
    map{from_to($_, 'utf8', 'big5')} @V; # For UTF-8 Chinese
  	print "ut=$ut, @V\n";
  }
  $sth->execute($ut) or die $DBH->errstr;
  while (my $rV = $sth->fetchrow_hashref) {
#    from_to($rV->{AU}, 'utf8', 'big5'); # For UTF-8 Chinese
    my $encoding_name = Encode::Detect::Detector::detect($rV->{AU});
    print "\$encoding_name=$encoding_name\n";
		if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#	  if ($encoding_name !~ /big5/i) { # if utf8-encoded
		  from_to($rV->{AU}, $encoding_name, 'big5'); 
    }	
  	print "AU=$rV->{AU}, BP=$rV->{BP}, VL=$rV->{VL}, UT=$rV->{UT}\n"; 
  }

}