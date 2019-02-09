#!/usr/bin/perl -s
package PatentDB;
#    use DBI;
    use Win32::ODBC;
    use Patent;
    @ISA = qw(Patent); # inherit from class Patent
    use strict;    use vars;
    my $debug = $main::Odebug || 0;

# Next is a comment segment in POD format. Comment ends until '=cut'
=head1 NAME

PatentDB -- A class for getting and parsing patents from a patent website.
	This class save the data to a DBMS, while class Patent save them 
	to the file system. This class is derived from the class Patent.

=head1 SYNOPSIS

    use PatentDB;
    $uspto = PatentDB->new( { 'Patent_INI'=>'Patent.ini' }, 'USPTO', 'NSC' );
    
    Others are the same as "use Patent;". 
    See Patent.html for details.
    Also see Patent.ini for details.

=head1 DESCRIPTION

    To generate the comments surrounded by =head and =cut, run
	pod2html --infile=PatentDB.pm > PatentDB.html
    under MS-DOS.
    To know more about the methods provided, see Patent.html for details.
    You should install DBI, DBD:ODBC by running
    ppm install DBI
    ppm install DBD-ODBC
    under MS-DOS (while you are connecting to the Internet) and then set the
    DNS via control pannel.
        
Author:
    Yuen-Hsien Tseng.  All rights reserved.
Date:
    2003/05/17

=cut


=head2 $pat=PatentDB->new( {'Patent_INI'=>'Patent.ini'}, $group1, $group2 );

  The attributes in the object can be set by an INI file (through attribute 
    'Patent_INI') or directly given in the constructor's argumnets in a 
    key=>value format. To know the attribute names, consult Patent.ini.

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown in 
  		$pat->new( { 'Patent_INI'=>'Patent.ini' }  );

=cut
sub new {
    my($class, $rpara, $group1, $group2) = @_;
    $class = ref($class) || $class;
#print "in PatentDB, new(), class=$class, class->SUPER=",$class->SUPER,"\n";
    my $me = $class->SUPER::new($rpara, $group1, $group2);
    return $me;
}


sub DESTROY {
    my($me) = @_;
    $me->{dbh}->Close(); # only for Win32::ODBC
}

=head2 $pat->ShowDBIdrivers();

  Show availabe DBI drivers (for debugging). 

=cut
sub ShowDBIdrivers {
    my @ary = DBI->available_drivers;
    foreach my $driver (@ary) {
    	foreach my $ds (DBI->data_sources($driver)) {
	    print "$driver:'$ds'\n";
	}
    }
}


=head2 $pat->SimpleSQL( $SQLcommand, argument list );

   Given an SQL command and a list of arguments
   return number of rows affected and the execution results.

=cut
#sub SimpleSQL {my($me,$sql,@args)=@_; print "$sql <= @args\n" if length(join'',@args)<1000; 0; }
sub SimpleSQL { # Win32::ODBC version
    my($me, $sql, @args) = @_;  my($dbh, $sth, $r, @R);
    my($ErrNum, $ErrText, $ErrConn, @SQL, $i);
#print "$sql <= @args\n" if $debug >= 1; # if length(join'',@args)<1000;
    $dbh = $me->{'dbh'};

#    $sql = &prepare($sql, @args);
#print "Num of args=", scalar @args, ", args=", join(", ", map({"'$_'"} @args)), "\n";
    @SQL = split /\?/, $sql;
    for ($i = 0; $i<@args; $i++) {
    	$args[$i] =~ s/'/''/g;
#	$SQL[$i] .= "'$args[$i]'";
	if ($args[$i] eq '') 
	{ $SQL[$i] .= 'null'; } else { $SQL[$i] .= "'$args[$i]'"; }
    }
    $sql = join '', @SQL;
print "sql=$sql\n" if $debug >= 1 and length($sql)<255;
    $dbh->Sql( $sql );
    ($ErrNum, $ErrText, $ErrConn) = $dbh->Error();
    if($ErrNum){ die("SQL Error: $ErrText <br>\nSQL=$sql<br>\n$ErrConn\n"); }

    if ($sql =~ /^\s*SELECT/i) {
	$dbh->FetchRow();
#	($ErrNum, $ErrText, $ErrConn) = $dbh->Error();
#	if($ErrNum){ 
#    	    die("Database Error: $ErrText <br>\n$ErrConn\n"); 
#	} else {
	    @R = $dbh->Data();
#	}
    } else {
    	$r = 1; @R = ();
    } 
    # now return (number of rows affected, 1st returned element, the rest)
    return ($r, shift @R, \@R); 
}

#=head
sub SimpleSQL_DBI {
    my($me, $sql, @args) = @_;  my($dbh, $sth, $r, @R);
print "$sql <= @args\n" if $debug >= 1; # if length(join'',@args)<1000;
    $dbh = $me->{'dbh'};
    $sth = $dbh->prepare($sql)
	|| die "Couldn't prepare statement: " . $dbh->errstr;
    $sth->execute( @args )
	|| die "Couldn't execute statement: " . $sth->errstr;
    @R = $sth->fetchrow_array() if $sql =~ /^\s*SELECT/i;
    $r = $sth->rows();
    $sth->finish; 
    # now return (number of rows affected, 1st returned element, the rest)
    return ($r, shift @R, \@R);
}
#=cut


=head2 --- Tools for Patent manipulations ---

=head2 $pat->InitializeSavePatent();

  Connect to a DBMS.

=cut
sub InitializeSavePatent {
    my($me) = @_;
#    my $dbh = DBI->connect('DBI:Oracle:payroll')
#    my $dbh = DBI->connect('DBI:CSV:f_dir=d:/demo/lwp/csvdb')
#    my $dbh = DBI->connect('DBI:ODBC:PatentDB')
#    my $dbh = DBI->connect('DBI:'.$me->{'DSN'}, $me->{'user'}, $me->{'password'})
#	|| die "Couldn't connect to database: " . DBI->errstr;

# Next segment is for Win32::ODBC
    my $DSN = "DSN=$me->{'DSN'};UID=$me->{'user'};PWD=$me->{'password'}";
    my $dbh = new Win32::ODBC($DSN)
	|| die("Can't open new ODBC Connect: DSN='$DSN'");
    if($dbh->GetMaxBufSize < $me->{'MEMO_FIELD_SIZE'}) {
	$dbh->SetMaxBufSize($me->{'MEMO_FIELD_SIZE'});
    }
    my($ErrNum, $ErrText, $ErrConn) = $dbh->Error();
    if($ErrNum)	{ die("Database Error: $ErrText <br>\n$ErrConn\n"); }

    $me->{'dbh'} = $dbh;
}


=head2 $pat->Set_Patent_Existed()

  This method is to set %Patent_Existed for fast matching of a
    given patent number with the existing patents. If matched, then the
    patent can be fetched from the stored tables. If not, then the patent
    will be fetched from the website.

  Since we are now using DBMS, to support simultaneous accesses from multiple
  users, %Patent_Existed is not set. Instead, we check the DBMS to see if
  a given patent number has already existed.

  So we do nothing in this overriding method.

=cut
sub Set_Patent_Existed {
}


=head2 $pat->Has_Patent_Existed( $patnum );

  Given a patent number, check if the patent has existed or not.
  
=cut
sub Has_Patent_Existed {
    my($me, $patnum) = @_;  my($sql, $pn, $r);
    if ($me->{SaveFullText}) {
	$sql = q{SELECT PatentNo FROM TFullText WHERE PatentNo = ?};
    } elsif ($me->{Save2File}) { # 2007/11/11
	return (-s $me->SavePatentPath($patnum)>1000)?1:0;
	# if its file size > 1000, we assume that the patent exists
    } else { # neither save in DBMS, nor in File system
#	$sql = q{SELECT PatentNo FROM TPatentInfo WHERE PatentNo = ?}; # 2007/11/10
	return 0;
    }
    ($r, $pn) = $me->SimpleSQL($sql, $patnum);
    return $pn;
}


=head2 $pat->Get_Patent_Existed($PatNum);

  Given a patent number, read the patent into a hash %Patent from a table, 
    and return the ref to the hash

=cut
sub Get_Patent_Existed {
    my($me, $patnum) = @_;     my($sql, $orgPatent, $rPatent, $r);
    if ($me->{SaveFullText}) {
	$sql = q{SELECT FullText FROM TFullText WHERE PatentNo = ?};
	($r, $orgPatent) = $me->SimpleSQL($sql, $patnum);
	if (length($orgPatent) > 1000) { # if really existed
	    return $me->Parse_Patent( $orgPatent );
	} else {
# We need to write a function to set $rPatent or do something different
	    die "Patent:'$patnum' exists in the DBMS with only ", 
		length($orgPatent), " bytes\n";
	}
    } elsif ($me->{Save2File}) {
	$me->SUPER::Get_Patent_Existed($patnum);
    }
}


=head2 $pat->SavePatent($rPatent, $orgPatent);

  Given the fetched patent document and the parsed patent structure,
  if the patent has not yet saved( and the parsed structure is correct), 
  save the patent document and the patent structure to the DBMS.
  
  This method calls the following methods:
  	$pat->SaveFullText($rPatent, $orgPatent); 
	$pat->SavePatentInfo($rPatent);
	$pat->SaveDescription($rPatent);
	$pat->SavePatentClass($rPatent);
	$pat->SaveOwner($rPatent); # Inventor and Assignee
	$pat->SaveCitePatent($rPatent);
	$pat->SaveCitePaper($rPatent);

  Here are some SQL tutorials that you may need when writing this method:
     http://www.altavista.com/query?q=sql+tutorial
    http://www.sqlcourse.com/

=cut
sub SavePatent {
    my($me, $rPatent, $orgPatent) = @_;
# Call base class's original method if needed
#    $me->SUPER::SavePatent( $orgPatent, $rPatent ) if $debug==1;
# Each of the next functions corresponds to one or two tables in the DBMS
    $me->{dbh}->{AutoCommit} = 0;  # enable transactions, if possible
    $me->{dbh}->{RaiseError} = 1;  # 
    eval { # try
	$me->SaveFullText($rPatent, $orgPatent); # TFullText
	$me->SavePatentInfo($rPatent);		 # TPatentInfo
	$me->SaveDescription($rPatent);		 # TDescription (TDescriptType)
	$me->SavePatentClass($rPatent);		 # TPatentClass, (TCountry)
	$me->SaveOwner($rPatent); # TOwner, Inventor and Assignee
	my($rUSRefs, $rForRefs, $rSciRefs) = $me->GetOtherReference($rPatent);
	$me->SaveCitePatent($rPatent, $rUSRefs, $rForRefs); # TCitePatent
	$me->SaveCitePaper($rPatent, $rSciRefs);	    # TCitePaper
#	$me->{dbh}->commit(); # if we get this far, absent in Win32::ODBC
    }; # unlike eval "...", eval {...} is very fast
    if ($@) { # catch
	print "Transaction aborted for $rPatent->{PatNum} because \n$@<br>\n";
#	print "SQL=$sth->{Statement}<br>\n";
#	$me->{dbh}->rollback(); # undo the incomplete changes, not in Win32::ODBC
    }
}

=head2 $pat->SaveFullText($rPatent, $orgPatent, $update); 

  If update is TRUE but the record is not in the DBMS, warn and return -1.
  If update is FALSE and the record is in the DBMS, return 0.
  If update is TRUE and the record is in the DBMS, then update the record.
  If update is FALSE and the record is not in the DBMS, then insert the record.
  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.
  
  Other Save methods are almost the same.
  
=cut
sub SaveFullText {
    my($me, $rPatent, $orgPatent, $update) = @_;
    my($r, $sql, $URL, $date, $existed);
#    return 2 if not $me->{SaveFullText}; # 2007/11/10, will lead to the error:
# SQL Error: [Microsoft][ODBC Microsoft Access Driver] 由於參考完整性的設定，
# 若TFullText沒有相關資料存在，就不能像這樣新增：INSERT INTO TPatentInfo...
    $existed = $me->Has_Patent_Existed($rPatent->{PatNum});
    if (not $update and $existed) { return 0 ; }
    if ($update and not $existed) { 
    	$me->ReportError("Patent:'$rPatent->{PatNum}' not existed in " .
    	"Table 'TFullText', UPDATE failure!"); 
    	return -1; 
    }
    my($sec, $min, $hour, $day, $mon, $year) = localtime(time); 
    $mon += 1; $year += 1900;
    $date = "$year/$mon/$day";
    $URL = $me->{PatentNo_URL};
    $URL =~ s/\$patnum/$rPatent->{PatNum}/g;
    if ($update) {
    	$sql = 'UPDATE TFullText SET Source=?, URL=?, UpdateDate=?' .
    	       ', FullText=? where PatentNo=?';
    } else {
    	$sql = 'INSERT INTO TFullText (Source, URL, UpdateDate, ' .
    		'FullText, PatentNo) VALUES (?, ?, ?, ?, ?)';
    }
    if ($me->{SaveFullText}) {
    	($r) = $me->SimpleSQL($sql, 
    		$me->{Source}, $URL, $date, $orgPatent, $rPatent->{PatNum});   	
    } else { # 2007/11/10
    	if ($me->{Save2File}) {
	        my $file = $me->SavePatentPath($rPatent->{PatNum});
print STDERR "Save patent to : '$file'\n" if $me->{debug}==1;
    		open P, ">$file" or die "Cannot write to file:'$file'";
    		print P $orgPatent;
    		close(P);
    	}
    	($r) = $me->SimpleSQL($sql, '', '', '', '', $rPatent->{PatNum});
    }
    return $r; # Number of rows affected 
}


=head2 $pat->SavePatentInfo($rPatent, $update); 

  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.

=cut
sub SavePatentInfo {
    my($me, $rPatent, $update) = @_;
    my($r, $sql, $pn, $existed);
# See if the record has existed or not
    $sql = q{SELECT PatentNo FROM TPatentInfo WHERE PatentNo = ?};
    ($r, $pn) = $me->SimpleSQL( $sql, $rPatent->{PatNum} );
    $existed = $pn eq $rPatent->{PatNum};
    if (not $update and $existed) { return 0; }
    if ($update and not $existed) { # existed means patent has be parsed in $rPatent
    	$me->ReportError("Patent:'$rPatent->{PatNum}' not existed in " .
    	"Table 'TPatentInfo', UPDATE failure!"); 
    	return -1; 
    }
    
    my($GovernCountryNo, $IssuedDate, $Title, $ApplyNo, $ApplyDate, 
       $SearchField, $cn, $FamilyID); # 2018/04/03
#print "this->{GovernCountry}=$me->{GovernCountry}\n";
    $GovernCountryNo = $me->CountryName2No( $rPatent->{GovernCountry} );
    $IssuedDate = $rPatent->{'IssuedDate'};
    $Title = $rPatent->{'Title'};
    $ApplyNo = $rPatent->{'Appl. No.'}; # need quotes if there are spaces
    if ($rPatent->{Filed} =~ m#(\w+) (\d+), (\d+)#) { 
   	    $ApplyDate = $me->FormatDate($3, $me->Month($1), $2);
    }
    $SearchField = $rPatent->{'Field of Search'};
    $FamilyID = $rPatent->{'Family ID'}; # 2018/04/03
    if ($update) { # update the record
    	$sql = 'UPDATE TPatentInfo SET GovernCountryNo=?, IssuedDate=?, ' .
    	'Title=?, FamilyID=?, ApplyNo=?, ApplyDate=?, SearchField=? where PatentNo=?';
    } else { # insert the record
    	$sql ='INSERT INTO TPatentInfo ' .
    	'(GovernCountryNo, IssuedDate, Title, FamilyID, ApplyNo, ApplyDate, ' .
    	'SearchField, PatentNo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
    }
#print "IssuedDate='$IssuedDate', ApplyNo='$ApplyNo', $rPatent->{Filed}\n";
    ($r) = $me->SimpleSQL($sql, $GovernCountryNo, $IssuedDate, $Title, 
    		$FamilyID, $ApplyNo, $ApplyDate, $SearchField, $rPatent->{PatNum});
    return $r; # Number of rows affected 
}

# Convert Country name to country number
sub CountryName2No {
    my($me, $name) = @_;  my($sql, $r, $cn);
    $sql = 'SELECT CountryNo from TCountry where CountryName=?';
    ($r, $cn) = $me->SimpleSQL($sql, $name);
    if ($cn eq '') {
# CountryNo is auto-incrment, so no need to insert it into the table
    	$sql = 'INSERT INTO TCountry (CountryName) VALUES (?)';
    	($r) = $me->SimpleSQL($sql, $name);
    	$sql = 'SELECT CountryNo from TCountry where CountryName=?';
    	($r, $cn) = $me->SimpleSQL($sql, $name);
    }
    return $cn;
}


=head2 $pat->SaveDescription($rPatent, $update); 

  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.

=cut
sub SaveDescription {
    my($me, $rPatent, $update) = @_;
    my($r, $sql, $pn, $existed, $i, $rPatentAbs, $field, $TypeNo);
# See if the record has existed or not
    $sql = q{SELECT PatentNo FROM TDescription WHERE PatentNo = ?};
    ($r, $pn) = $me->SimpleSQL( $sql, $rPatent->{PatNum} );
    $existed = $pn eq $rPatent->{PatNum};
    if (not $update and $existed) { return 0; }
    if ($update and not $existed) { 
    	$me->ReportError("Patent:'$rPatent->{PatNum}' not existed in " .
    	"Table 'TDescription', UPDATE failure!"); 
    	return -1; 
    }
# When we want to update these records, we may be in a situation that we have
# different sections from the previous same patent (maybe due to parsing error)
    if ($update) { # So we should delete all the existing records for updating
    	$sql = 'DELETE FROM TDescription WHERE PatentNo=?';
    	($r) = $me->SimpleSQL($sql, $rPatent->{PatNum});
    }
    $rPatentAbs = $me->GetPatentAbstract( $rPatent );
    $i = -1;
    foreach $field (@{$me->{Patent_Des_Fields}}) {
    	$i++;
    	$TypeNo = $me->DesTypeName2No( $field, $i );
    	$r += $me->SaveDescriptionField($field, $TypeNo, $rPatentAbs, $rPatent);
    }
    return $r; # Number of rows affected 
}


=head2 $pat->SaveDescriptionField($field, $TypeNo, $rPatentAbs, $rPatent, $update); 

  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.

=cut
sub SaveDescriptionField {
    my($me, $field, $TypeNo, $rPatentAbs, $rPatent, $update) = @_;
    my($r, $sql, $SectionTitle, $Descript, $Abstract);
    return if not $me->{SaveDescription} and $field ne 'Abstract'; # 2007/11/10
    $SectionTitle = $rPatent->{$field . '_SecTitle'}; # Set in Parse_Patent
    $SectionTitle = $field if $SectionTitle eq '';
    $Descript = $rPatent->{$field};
    $Abstract = $rPatentAbs->{$field};
#    $Abstract = '' if not $me->{SaveDescription} and $field eq 'Abstract'; # 2007/11/10
    if ($update) {
    	$sql = 'UPDATE TDescription SET SectionTitle=?, Descript=?, ' .
    	'Abstract=? WHERE PatentNo=? and TypeNo=?';
    } else { # insert the record
    	$sql ='INSERT INTO TDescription (SectionTitle, Descript, Abstract, ' .
    	'PatentNo, TypeNo) VALUES (?, ?, ?, ?, ?)';
    }
    ($r) = $me->SimpleSQL($sql, $SectionTitle, $Descript, $Abstract,
	   $rPatent->{PatNum}, $TypeNo);
    return $r; # Number of rows affected 
}


sub DesTypeName2No {
    my($me, $name, $sequence) = @_;  my($sql, $r, $cn);
    $sql = 'SELECT TypeNo from TDescriptType where TypeName=?';
    ($r, $cn) = $me->SimpleSQL($sql, $name);
    if ($cn eq '') {
# TypeNo is auto-incrment, so no need to insert it into the table
	$sql = 'INSERT INTO TDescriptType (TypeName, Sequence) VALUES (?, ?)';
	($r) = $me->SimpleSQL($sql, $name, $sequence);
	$sql = 'SELECT TypeNo from TDescriptType where TypeName=?';
	($r, $cn) = $me->SimpleSQL($sql, $name);
    }
    return $cn;
}


=head2 $pat->SavePatentClass($rPatent, $update); 

  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.

=cut
sub SavePatentClass {
    my($me, $rPatent, $update) = @_;
    my($r, $sql, $pn, $existed, $ClassType, %Type, $class, @Class, @C, $c, 
       $CountryNo, @ClassCountry, $NumRows);
# See if the record has existed or not
    $sql = q{SELECT PatentNo FROM TPatentClass WHERE PatentNo = ?};
    ($r, $pn) = $me->SimpleSQL( $sql, $rPatent->{PatNum} );
    $existed = $pn eq $rPatent->{PatNum};
    if (not $update and $existed) { return 0; }
    if ($update and not $existed) { 
    	$me->ReportError("Patent:'$rPatent->{PatNum}' not existed in " .
    	"Table 'TPatentClass', UPDATE failure!"); 
    	return -1; 
    }
# When we want to update these records, we may be in a situation that we have
# different classes from the previous same patent (maybe due to parsing error)
    if ($update) { # So we should delete all the existing records for updating
    	$sql = 'DELETE FROM TPatentClass WHERE PatentNo=?';
    	($r) = $me->SimpleSQL($sql, $rPatent->{PatNum});
    }
    $NumRows = 0; # next are modified on 2018/04/03
    foreach $ClassType (@{$me->{Patent_Class_Fields}}) {
    	$Type{$ClassType} = 0; # initialize number of classes of the same type
    	@C = split /\s*;\s*/, $rPatent->{$ClassType}; # "H01L 21/762&nbsp(20060101); H01L 021/306&nbsp()"
# Create a @ClassCountry to know which class belongs to which country 
   		foreach $c (@C) {
	  	  $c =~ s/&nbsp.*$//; # 2007/11/10 delete the training "&nbsp(\w*)"
    		next if $c eq '';
    		$Type{$ClassType}++;
    		$r += $me->SavePatentClassItem($ClassType, $c, 
    											($Type{$ClassType}==1), $rPatent, $update);
    		$NumRows += $r;
    	}
    }
    return $NumRows; # Number of rows affected 
}


=head2 $pat->SavePatentClassItem($ClassType, $class, $IsMain, $rPatent, $update); 

  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.

=cut
sub SavePatentClassItem { # modified on 2018/04/03
    my($me, $ClassType, $class, $IsMain, $rPatent, $update) = @_;
    my($r, $sql);
    $IsMain = ($IsMain)?1:0;
    if ($update) {
    	$sql = 'UPDATE TPatentClass SET IsMain=? ' .
    	'WHERE PatentNo=? and ClassType=? and PatentClass=?';
    } else { # insert the record
    	$sql ='INSERT INTO TPatentClass (IsMain, PatentNo, ClassType, ' .
        	'PatentClass) VALUES (?, ?, ?, ?)';
    }
    ($r) = $me->SimpleSQL($sql, $IsMain, $rPatent->{PatNum}, $ClassType, $class);
    return $r; # Number of rows affected 
}


=head2 $pat->SaveOwner($rPatent, $update); 

  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.
  OwnerType => 1 : Inventors, 2 : Assignee
  Type => 1 : personal, 2 : corporation

=cut
sub SaveOwner {
    my($me, $rPatent, $update) = @_;
    my($r, $sql, $pn, $existed, @OwnerType, $Owner);
# See if the record has existed or not
    $sql = q{SELECT PatentNo FROM TOwner WHERE PatentNo = ?};
    ($r, $pn) = $me->SimpleSQL( $sql, $rPatent->{PatNum} );
    $existed = $pn eq $rPatent->{PatNum};
    if (not $update and $existed) { return 0; }
    if ($update and not $existed) { 
    	$me->ReportError("Patent:'$rPatent->{PatNum}' not existed in " .
    	"Table 'TOwner', UPDATE failure!"); 
    	return -1; 
    }

# When we want to update these records, we may be in a situation that we have
# different sections from the previous same patent (maybe due to parsing error)
    if ($update) { # So we should delete all the existing records for updating
    	$sql = 'DELETE FROM TOwner WHERE PatentNo=?';
    	($r) = $me->SimpleSQL($sql, $rPatent->{PatNum});
    }
#    @OwnerType = ('1', '2'); # 1 : Inventors, 2 : Assignee
    @OwnerType = ('Inventors', 'Assignee'); # 2018/04/03
    foreach $Owner ($rPatent->{Inventors}, $rPatent->{Assignee}) {
    	$r += $me->SaveOwner_Inv_Ass($Owner, shift @OwnerType, $rPatent);
    }
    return $r;
}

sub SaveOwner_Inv_Ass {
    my($me, $Owner, $OwnerType, $rPatent) = @_; 
    my($p, $City, $country, $r, @Owner, $CountryNo, $Type, $State, @OwnerName);
    @OwnerName = ('', 'Inventors', 'Assignee'); # 2007/11/10
#    my $OwnerName = $OwnerName[$OwnerType]; 	# 2007/11/10
    my $OwnerName = $OwnerType; 	# 2018/04/03
# The format for $Owner are:
# Inventors: Smeltzer; Ronald K. (Dallas, TX), Bean; Kenneth E. (Richardson, TX)
# Assignee: Texas Instruments Incorporated (Dallas, TX)
#   @Owner = split /\)/, $Owner; # split by right parenthesis
    @Owner = split /\)[,\s]*/, $Owner; # 2007/11/10
# ex: $Owner='Huang; Smile (Tainan, TW); Chen; Chia-Hsing (Hsinchu, TW)'
    foreach $p (@Owner) {
    	$City = $State = $country = ''; # 2007/11/10
#print STDERR "$rPatent->{PatentNum}, p=$p\n";
    	if ($p =~ /;?\s?(.+) \((.+), (.+)$/) { 
	    	$Owner = $1; $City = $2; $country = $3;
    	} elsif ($p =~ /;?\s?(.+) \((.+)$/) { # 不是美國
	    	$Owner = $1; $country = $2; $City = 'Null';
    	} else { next; } # do nothing if no match
    	$Owner =~ s/;/,/; # convert ';' into ',' between surname and name
    	if ($rPatent->{$OwnerName.'_org'} =~ /<B>$country/i) { # 不是美國的州名
    	    # do nothing
    	} else { # 可能是美國的州名, 
    	    if ($me->{'US_StateName'}{$country}){$State=$country;$country='US';}
    	}

#print STDERR "Owner=$Owner, City=$City, State=$State, Country=$country\n";
    	$CountryNo = $me->CountryName2No( $country );
# Type => 1 : personal, 2 : corporation
    	$Type = ($Owner=~/Ltd|Inc\.|Corporation|Corp\W*$/)?2:1;
    	$Owner =~ s/^\s+|\s+$//g; # delete leading and trailing white spaces
    	$r += $me->SaveOwnerItem($Owner, $OwnerType, 
    	$City, $State, $CountryNo, $Type, $rPatent);
    }
    return $r; # Number of rows affected 
}

sub SaveOwnerItem {
    my($me, $Owner, $OwnerType, $City, $State, $CountryNo, $Type, 
    	$rPatent, $update) = @_;
    my($r, $sql);
    if ($update) {
    	$sql = 'UPDATE TOwner SET City=?, State=?, CountryNo=?, Type=? ' .
    	'WHERE PatentNo=? and Owner=? and OwnerType=?';
    } else { # insert the record
    	$sql ='INSERT INTO TOwner (City, State, CountryNo, Type, ' .
    	'PatentNo, Owner, OwnerType) VALUES (?, ?, ?, ?, ?, ?, ?)';
    }
    ($r) = $me->SimpleSQL($sql, $City, $State, $CountryNo, $Type, 
	   $rPatent->{PatNum}, $Owner, $OwnerType);
    return $r; # Number of rows affected 
}


=head2 $pat->SaveCitePatent($rPatent, $rUSRefs, $rForRefs, $update); 

  After parsing the "References Cited" in a US patent document by calling 
  ($rUSRefs, $rForRefs, $rSciRefs) = $pat->GetOtherReference( $rPatent );
  pass the part:"U.S. Patent Documents" and "Foreign Patent Documents"
  into this method, save the further parsed items into table TCitePatent.
  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.

=cut
sub SaveCitePatent {
    my($me, $rPatent, $rUSRefs, $rForRefs, $update) = @_;
    my($r, $sql, $pn, $existed);
# See if the record has existed or not
    $sql = q{SELECT PatentNo FROM TCitePatent WHERE PatentNo = ?};
    ($r, $pn) = $me->SimpleSQL( $sql, $rPatent->{PatNum} );
    $existed = $pn eq $rPatent->{PatNum};
    if (not $update and $existed) { return 0; }
    if ($update and not $existed) { 
    	$me->ReportError("Patent:'$rPatent->{PatNum}' not existed in " .
    	"Table 'TCitePatent', UPDATE failure!"); 
    	return -1; 
    }

# When we want to update these records, we may be in a situation that we have
# different sections from the previous same patent (maybe due to parsing error)
    if ($update) { # So we should delete all the existing records for updating
    	$sql = 'DELETE FROM TCitePatent WHERE PatentNo=?';
	($r) = $me->SimpleSQL($sql, $rPatent->{PatNum});
    }

    my($cite, $country, $CountryNo, $CitePN, $Year, $Owner, $Class);
# "U.S. Patent Documents"
    foreach $cite (@$rUSRefs) {
    	next if $cite eq '';
#    	my($CitePatentNo, $CitePatentYear, $CitePatentInventor, $CiteUSclass)
	($CitePN, $Year, $Owner, $Class)
    	  = $me->ParsePatRef( $cite );
#print "'$CitePN', Year='$Year', Owner='$Owner', class='$Class'\n";
	$CountryNo = $me->CountryName2No( 'US' );
    	$r += $me->SaveCitesItem($CitePN, $Year, $Owner, $Class, $CountryNo, $rPatent);
    }
# "Foreign Patent Documents"
    foreach $cite (@$rForRefs) {
    	next if $cite eq '';
	($CitePN, $Year, $country, $Class) = $me->ParsePatRef( $cite );
#print "'$CitePN', Year='$Year', country='$country', class='$Class'\n";
	$CountryNo = $me->CountryName2No( $country );
    	$r += $me->SaveCitesItem($CitePN, $Year, "", $Class, $CountryNo, $rPatent);
    }
    return $r; # Number of rows affected 
}


sub SaveCitesItem {
    my($me, $CitePN, $Year, $Owner, $Class, $CountryNo, $rPatent, $update) 
    = @_;
    my($r, $sql);
    if ($update) {
    	$sql = 'UPDATE TCitePatent SET Year=?, '.
    	'Inventor=?, USclass=?, CountryNo=? ' .
    	'WHERE PatentNo=? and CitePatentNo=?';
    } else { # insert the record
	$sql ='INSERT INTO TCitePatent (Year, Inventor, USclass, CountryNo, '.
	'PatentNo, CitePatentNo) VALUES (?, ?, ?, ?, ?, ?)';
    }
    ($r) = $me->SimpleSQL($sql, $Year, $Owner, $Class, $CountryNo, 
	   $rPatent->{PatNum}, $CitePN);
    return $r; # Number of rows affected 
}


=head2 $pat->SaveCitePaper($rPatent, $rSciRefs, $update); 

  After parsing the "References Cited" in a US patent document by calling 
  ($rUSRefs, $rForRefs, $rSciRefs) = $pat->GetOtherReference( $rPatent );
  pass the part:"Other References" 
  into this method, save the further parsed items into table TCitePaper.
  return 0 : already existed; 
  	 1 : insert OK; update OK; # return number of rows affected 
  	-1 : not OK.

=cut
sub SaveCitePaper {
    my($me, $rPatent, $rSciRefs, $update) = @_;
    my($r, $sql, $pn, $existed, $rr);
# See if the record has existed or not
    $sql = q{SELECT PatentNo FROM TCitePaper WHERE PatentNo = ?};
    ($r, $pn) = $me->SimpleSQL( $sql, $rPatent->{PatNum} );
    $existed = $pn eq $rPatent->{PatNum};
    if (not $update and $existed) { return 0; }
    if ($update and not $existed) { 
    	$me->ReportError("Patent:'$rPatent->{PatNum}' not existed in " .
    	"Table 'TCitePaper', UPDATE failure!"); 
    	return -1; 
    }

# When we want to update these records, we may be in a situation that we have
# different sections from the previous same patent (maybe due to parsing error)
    if ($update) { # So we should delete all the existing records for updating
    	$sql = 'DELETE FROM TCitePaper WHERE PatentNo=?';
	($r) = $me->SimpleSQL($sql, $rPatent->{PatNum});
    }

# "Other References"
    my($Type, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle, $cite);
    foreach $cite (@$rSciRefs) {
    	next if $cite eq '';
	($Type, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle)
    	  = @{ $me->ParseSciRef( $cite ) }; # de-reference into an array
  $sql ='INSERT INTO TCitePaper (PatentNo, Type, Year, Vol, StartPage, '.
	'Author, PubTitle, JouTitle, OrgCitation) VALUES (?,?,?,?,?,?,?,?,?)';
	($rr) = $me->SimpleSQL($sql, $rPatent->{PatNum}, $Type, $Year, 
	$Vol, $StartPage, $Author, $PubTitle, $JouTitle, $cite);
#  $sql ='INSERT INTO TCitePaper (PatentNo, Type, Year, YearT, Vol, VolT, '.
#    'StartPage, StartPageT, Author, AuthorT, PubTitle, JouTitle, OrgCitation)'.
#    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
#	($rr) = $me->SimpleSQL($sql, $rPatent->{PatNum}, $Type, $Year, "", 
#	$Vol, "", $StartPage, "", $Author, "", $PubTitle, $JouTitle, $cite);
    	$r += $rr;
    }
    return $r; # Number of rows affected 
}


1;
