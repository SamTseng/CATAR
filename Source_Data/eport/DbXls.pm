#!/usr/bin/perl -s
package DbXls;
#	use Encode::TW; # this line must exist, despite we have the next line
#	use Encode qw/encode decode/;
# perl -e "use encoding big5;$str='中文成功123'; print join(',',split(//,$str));"
# Output=>中,文,成,功,1,2,3
# See: http://brianchang168.blogspot.com/2009/03/perl-string-split-by-use-encoding-big5.html
# 若從資料庫取得的字串,可試試 $str=decode("big5", $str);再做 @str=split(//,$str);
# For more unicode issues, see the solutions in \demo\NIB\NER\NER.pl
#	That is: After reading $text from a DBMS, use $text = encode("big5", $text); 
#		to change the encoding of $text into Big5.
#		To save $text (in Big5) into a DBMS, use $text = decode('big5', $text);
#		to change the encoding of $text into utf8.
	use strict;  use vars;
	use DBI;
#	use DBI ':sql_types';
	use DBD::ODBC;

# Next is a comment segment in POD format. Comment ends until '=cut'

=head1 NAME

 DbXls - extracts the data in Excel and insert them to Access
 
=head1 SYNOPSIS

	use DbXls;
	exit;


=head1 DESCRIPTION


	To generate the comments surrounded by =head and =cut, run
	pod2html DbXls.pm > DbXls.html
	under MS-DOS.


Author:
	Yuen-Hsien Tseng.  All rights reserved.
	
Date:
	2010/02/26

=cut


# ------------------- Begin of functions for initialization -----------

=head1 Methods

=head2 new() : the construtor

  $oDX = DbXls->new( {'Attribute_Name'=>'Attribute_Value',...} );

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown in 
	DbXls->new( { 'Attribute_Name'=>'Attribute_Value' }  );

  The attributes in the object can be directly given in the constructor's ' 
  argumnets in a key=>value format.

  Omitted attribute pairs will be given default values.

=cut

sub new {
	my($class, $rpara) = @_; 
	$class = ref($class) || $class;
#	my $me = $class->SUPER::new( $rpara );
	my $me = bless( {}, $class );
	if (ref($rpara)) {	while (my($k, $v) = each %$rpara) { $me->{$k} = $v; }  }
	$me->ReadINI($rpara->{INI}) if (-e $rpara->{INI}); # read attributes from file
	$me->SetAttributes_by_DefaultGroup();
    $me->{'error_log'} = 'error_log.txt' if not defined $me->{'error_log'};
#	$me->{'Progress'}=Progress->new({'OUT'=>*STDERR{IO},'Format'=>'percent'});
	$me->InitDB();
	return $me;
}


=head2 ReadINI( 'class.ini' ) : read attributes and values from a INI file

  Read the INI file ('class.ini') and set the class object`s  attributes.

=cut
sub ReadINI {
	my($me, $iniFile) = @_;
	my($GroupName, $DefaultGroup, %Groups);
	open (F, $iniFile) or die "Cannot open '$iniFile': $!";
	while (<F>) {
		next if /^#|^\s*$/; # if a comment line or an empty line
		chomp;
		if (/^\[([^\[]+)\]/) { $GroupName = $1; next; }
#		if (/^(\w+)=(.+)\s*$/) {
		if (/^([^=]+)=(.+)\s*$/) { # 2010/03/31
			if ($1 eq 'DefaultGroup') {
				   $DefaultGroup = $2;
			} elsif ($GroupName eq '') { # global attributes
				$me->{$1} .= $2;
			} else { # local attributes (local to a group)
# Next line is the same as $Groups{$GroupName}->{$1} .= $2;
				$Groups{$GroupName}{$1} .= $2; # "->" can be omitted in 2-D hash
			}
		}
	}
	close(F);
	$me->{DefaultGroup} = $DefaultGroup;
	$me->{Groups} = \%Groups; # a ref to a hash of hash
	if (keys %Groups == 0 or $me->{DefaultGroup} eq '') {
		die "Cannot read Ini_file='$iniFile'\n$!";
	}
}


=head2 SetAttributes_by_DefaultGroup()

  By changing the 'DefaultGroup' attribute (say from 'Group1' to 'Group2'),
  you may change the corresponding attributes (settings) by this method.

  Return nothing, but has the side effect of setting some values to the
  attributes of the object.

=cut
sub SetAttributes_by_DefaultGroup {
	my($me) = @_; my($k, $v);
#print STDERR "Run &SetAttributes_by_DefaultGroup()\n";
	while (($k, $v) = each %{$me->{Groups}{$me->{DefaultGroup}}}) {
		$me->{$k} = $v; # use the default group's attribute
#print STDERR "k=$k, v=$v\n";
	}
}


=head2 PrintAttributes();

  This is for debugging. Print all the attributes of the object $pat.

  Return nothing, but has the side effect of showing all attributes and 
  their values in the STDOUT.

=cut
sub PrintAttributes {
	my($me) = @_;  my($k, $v);
	print "\n#=========== All attributes ...\n";
	while (($k, $v) = each %$me) {
		print "$k = $v\n";
	}
	print "\n#=========== Default group's attributes ...\n";
#	while (($k, $v) = each %{$me->{Groups}->{$me->{DefaultGroup}}}) {
# The above line is the same as next line, "->" can be omitted in 2-D case
	while (($k, $v) = each %{$me->{Groups}{$me->{DefaultGroup}}}) {
		print "$k = $v\n";
	}
}

=head2 SetValue() : A generic Set method for all scalar attributes.

  Examples:
	  $oDX->SetValue("DB", "DbXls");
  Returns old value of the given attribute.

=cut
sub SetValue {
	my($this, $attribute, $value) = @_;
	my $old = $this->{$attribute};
  if ($PerlCtrl::VERSION) { # if run in DLL
	$value = encode('big5', $value); # from utf-8 to big5
  }
	$this->{$attribute} = $value;
	return $old;
}

=head2 GetValue() : A generic Get method for all scalar attributes.

  Examples:
	  $DB = $oDX->GetValue("DB");

=cut
# To get the value in a hash-typed attribute, a 2nd attribute should be given.
sub GetValue {
	my($this, $attribute, $attr2) = @_;
  if ($PerlCtrl::VERSION) { # if run in DLL
	$attribute = encode('big5', $attribute); # from utf-8 to big5
	$attr2 = encode('big5', $attr2); # from utf-8 to big5
  }
	if ($attr2 eq '') {
		return $this->{$attribute}
	}
	return $this->{$attribute}{$attr2};
}


sub CurrentDateTime {
	my($me) = @_;
	my($sec, $min, $hour, $day, $mon, $year) = localtime(time); 
	my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my $month = $abbr[$mon];
	$mon += 1; # since it starts from 0 to 11
	$mon = sprintf("%02d", $mon); # convert '1' into '01'
	$day = sprintf("%02d", $day); # convert '8' into '08'
	$year += 1900; # since $year is the number of years since 1900
#   To get the last two digits of the year (e.g., '01' in 2001) do:
#	$year = sprintf("%02d", $year % 100);
#   In scalar context, localtime() returns the ctime(3) value:
#	$now_string = localtime;  # e.g., "Thu Oct 13 04:54:34 1994"
#	return reverse ($sec, $min, $hour, $day, $mon, $year);
	return ($year, $mon, $day, $hour, $min, $sec);
	# return in reverse order, that is, $year is the first returned element
}


=head2 InitDB() : Initialize Database Access.

  $flag = $oDX->InitDB( $DB, $user, $pass, $host, $port );
  You need to call this method before connect to a database.

  return a flag inidicating OK or not

=cut
sub InitDB {
	my($me) = @_;
	if ($me->{'DB_Type'} eq 'MySQL') {
		$me->InitDB_MySQL($me->{'DB'}, $me->{'user'}, $me->{'pass'});
	} elsif ($me->{'DB_Type'} eq 'MDB') {
		$me->InitDB_MDB($me->{'DB_Dir'}, $me->{'user'}, $me->{'pass'});
	} elsif ($me->{'DB-Type'} eq 'SQLite') {
		$me->InitDB_SQLite($me->{'DB_Dir'}, $me->{'user'}, $me->{'pass'});
	}	
}

sub DESTROY {
	my($this) = @_;	$this->{DBH}->disconnect();
}

sub InitDB_MySQL {
	my($me, $DB, $user, $pass, $host, $port) = @_;
	my($dsn, $dbh, $drh);
	$dsn = "DBI:mysql:database=$DB;host=$host;port=$port";
	$dsn = "DBI:mysql:database=$DB;host=$host;" if $port eq '';
	$dsn = "DBI:mysql:database=$DB;" if $host eq '';
	$user = $me->{'user'} if $user eq '';
	$pass = $me->{'pass'} if $pass eq '';
#print STDERR "DB=$DB, user=$user, pass=$pass\n";
	$dbh = DBI->connect($dsn, $user, $pass, {
	   RaiseError => 1, AutoCommit => 0
	   } ) or die "Can't make database connection: $DBI::errstr\n";
	$drh = DBI->install_driver("mysql");
	$dbh->{LongReadLen} = 1280000; # only work for SELECT, not for INSERT
	$dbh->{LongTruncOk} = 1;
# The following 3 lines is important to make data in/out of MySQL correct
# Please refer to http://ymlib.blogspot.com/2006_11_01_archive.html
	if ($me->{DefaultGroup} eq 'MSWin32') { 
# in archive.dmc.ntnu.edu.tw, the MySQL can not understand the next 3 lines
		$dbh->do( "SET character_set_client ='big5'");
		$dbh->do( "SET character_set_connection='big5'");
		$dbh->do( "SET character_set_results='big5'");
	}
	$me->{DBH}->disconnect() if ref($me->{DBH}); # release previous DBH
	$me->{'DBH'} = $dbh;
	return 1;
}

# To use SQLite, "install DBI" and then "install DBD::SQLite"
# SQLite browser : http://sourceforge.net/projects/sqlitebrowser/ or http://sqlitebrowser.sourceforge.net/
# SQLite tutorial: http://souptonuts.sourceforge.net/readme_sqlite_tutorial.html
sub InitDB_SQLite {
	my($me, $DBfile, $user, $pass) = @_;
	my($dsn, $dbh, $drh);
	$dsn = "DBI:SQLite:dbname=$DBfile;"; # eg. $DBfile='Paper_org.mdb' or 'Paper_org.db'
	$user = $me->{'user'} if $user eq '';
	$pass = $me->{'pass'} if $pass eq '';
#print STDERR "DBfile=$DBfile, user=$user, pass=$pass\n";
	$dbh = DBI->connect($dsn, $user, $pass, {
	   RaiseError => 1, AutoCommit => 0,
	   sqlite_unicode => 1 # 設定資料庫讀取的資料為 UTF-8 (utf8)
	   # see http://freehaha.blogspot.com/2010/04/perl-utf-8-sqlite-issue.html
	   } ) or die "Can't make database connection: $DBI::errstr\n";
	$drh = DBI->install_driver("mysql");

	$dbh->{LongReadLen} = 1280000; # only work for SELECT, not for INSERT
	$dbh->{LongTruncOk} = 1;
	$me->{DBH}->disconnect() if ref($me->{DBH}); # release previous DBH
	$me->{'DBH'} = $dbh;
	return 1;
}

=comment until next =cut
use DBI;
$dbh = DBI->connect( "dbi:SQLite:dbname=aaa.dbl" ) || die "Cannot connect: $DBI::errstr";
$sql = "select id,name,pass from table01";
$sth = $dbh->prepare($sql) or die '123';
$sth->execute() or die '456';
while( $href = $sth->fetchrow_hashref ){ #print $href->{'id'},"\n";
  while( ($debug_key,$debug_value)=each %{$href} ) {
    print pack('A2 A13 A3','',$debug_key,'=>') . $debug_value,"\n";
  }
} $dbh->disconnect;
D:\test>sqlite3.exe aaa.dbl ".dump"
BEGIN TRANSACTION;
CREATE TABLE table01 (id , name , pass );
INSERT INTO "table01" VALUES('1','ddd','ddd');
INSERT INTO "table01" VALUES('2','perl','cpan');
INSERT INTO "table01" VALUES('3','aaa','bbb');
INSERT INTO "table01" VALUES('5','sss','ggg');
INSERT INTO "table01" VALUES('6','sss',NULL);
COMMIT;
=cut



sub InitDB_MDB {
	my($me, $Path) = @_;
	$Path = 'D:/NTCIR/DB/NTCIR6.mdb' if $Path eq '';
	my $mdb = $Path; #"C:\\perl\\rssnewsdb\\rss.mdb";
	my $DSN = "driver=Microsoft Access Driver (*.mdb);dbq=$mdb";
	
=Comment until next =cut
	my $server='patrickdt';  # This segment is for MS SQL
	my $database = 'News';
	my $user = 'sa';
	my $pass = 'wgadmin';
	$DSN = "DBI:ODBC:DRIVER={SQL Server};SERVER={$server};database=$database;uid=$user;pwd=$pass";
=cut

	my $dbh = DBI->connect("dbi:ODBC:$DSN", {
	   RaiseError => 1, AutoCommit => 0
	   } ) or die "$DBI::errstr\n"; 
	$dbh->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
	$dbh->{LongTruncOk} = 1;
#	$dbh->do("set character set big5"); # this line does not work on 2010/07/12
	$me->{DBH}->disconnect() if ref($me->{DBH}); # release previous DBH
	$me->{'DBH'} = $dbh;
	return 1;
}

sub error_log {
    my($me, $errID, $errStr) = @_;
    open F, ">>".$me->{'error_log'} 
	or die "Cannot written to error log file:'$me->{error_log}'\n";
    my($year, $mon, $day, $hour, $min, $sec) = $me->CurrentDateTime();
    my $logtime = "$year/$mon/$day $hour:$min:$sec";
    print F "$errID\t$logtime\t$errStr\n";
    close(F);
    return $errID;
}

=head2 $oDX->SimpleSQL( $SQLcommand, argument list );

   Given an SQL command and a list of arguments
   return number of rows affected and the execution results.

=cut
sub SimpleSQL {
	my($me, $sql, @args) = @_;  my($dbh, $sth, $r, @R);
print STDERR "$sql <= @args\n" if $me->{debug} >= 1; 
	$dbh = $me->{'DBH'};
	$sth = $dbh->prepare($sql)
		or die "Couldn't prepare statement: $sql" . $dbh->errstr;
	eval { $sth->execute( @args )
		or die "Couldn't execute statement: $sql" . $sth->errstr; };
	if ($@) { $me->error_log(6, "Simple SQL Fail:".$dbh->errstr); return 0; }

	@R = $sth->fetchrow_array() if $sql =~ /^\s*SELECT/i;
	$r = $sth->rows();
	$sth->finish; 
	# now return (number of rows affected, returned elements)
	return ($r, @R); 
}

=head2 $oDX->FetchRows( $SQLcommand, argument list );

   Given an SQL command and a list of arguments
   return number of rows affected and the execution results.

=cut
sub FetchRows {
	my($me, $sql, @args) = @_;  my($dbh, $sth, $r, @a, @R);
print STDERR "$sql <=> '@args'\n" if $me->{debug} >= 1; 
	$dbh = $me->{'DBH'};
	$sth = $dbh->prepare($sql)
		or die "Cannot prepare statement: " . $dbh->errstr;
	eval { $sth->execute( @args )
		or die "Cannot execute statement: " . $sth->errstr; };
	if ($@) { $me->error_log(6, "FetchRows:".$dbh->errstr); return 0; }
	while (@a = $sth->fetchrow_array()) {
		push @R, join("\t", @a);
	}
	return (\@R);
}


# Next line is used in UnivRank.pl (or UnivRank.pm). 
# This function should be removed from here in the future.
sub AddDB_Table_Field {
	my($oDX, $Table, $Field, $u, $d) = @_;  my($sql, $r, @R, $ue);
	if ($u =~ /([^=]+)=(.+)/) { $u = $1; $ue = $2; }
# see if it has already existed
	$sql = "SELECT University FROM $Table where University=?";
	($r, @R) = $oDX->SimpleSQL($sql, $u);
	if (@R == 0) { # if not, use insert
		if ($ue eq '') {
			$sql = "INSERT INTO $Table (University, $Field) VALUES (?, ?)";
			($r, @R) = $oDX->SimpleSQL($sql, $u, $d);
		} else {
			$sql = "INSERT INTO $Table (University, UniversityEnglish, $Field) VALUES (?, ?, ?)";
			($r, @R) = $oDX->SimpleSQL($sql, $u, $ue, $d);
		}
	} else { # if yes, use update
		$sql = "Update $Table SET $Field = ? WHERE University = ?";
		($r, @R) = $oDX->SimpleSQL($sql, $d, $u);
	}
}

1;
