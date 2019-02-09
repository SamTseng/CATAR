#!/usr/bin/perl -s
package ClusterDB;
# This program is copied from Cluster.pm 
    use Cluster;
    @ISA = qw(Cluster); # inherit from class Cluster
    #require "InitDBH.pl"; # added on 2017/08/28, remove comment on 2019/01/23
    use InitDBH qw(InitDBH); # added on 2019/01/24
    use strict;  use vars;


# Next is a comment segment in POD format. Comment ends until '=cut'

=head1 NAME

 ClusterDB - This class inherit from Cluster.pm to allow saving the results
 	     to DBMS for display.

=head1 SYNOPSIS

    See ClusterDB.pl for examples.

=head1 DESCRIPTION


    To generate the comments surrounded by =head and =cut, run
	pod2html ClusterDB.pm > ClusterDB.html
    under MS-DOS.


Author:
    Yuen-Hsien Tseng.  All rights reserved.
    
Date:
    2004/04/25

=cut


# ------------------- Begin of functions for initialization -----------

=head1 Methods

=head2 new() : the construtor

  $rDC = Cluster->new( {'Attribute_Name'=>'Attribute_Value',...} );

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown in 
    DocCluster->new( { 'Attribute_Name'=>'Attribute_Value' }  );

  The attributes in the object can be directly given in the constructor''s 
  argumnets in a key=>value format. 
  The attribute names and values are:
    WordDir(path in a file system),
    UseDic(1 or 0)

  Omitted attribute pairs will be given default values.

=cut
sub new {
    my($class, $rpara) = @_; 
    $class = ref($class) || $class;
    my $me = $class->SUPER::new($rpara);
    $me->{'MaxCluster'} = 1000; # Set maximum number of clusters for output
    if (-e $rpara->{INI}) { # read attributes from file
            $me->ReadINI($rpara->{INI});
    } else {
# All the above settings can be replaced with the following statement:
        my($k, $v);
        while (($k, $v) = each %$rpara) {
            $me->{$k} = $v;
        }
    }
    $me->SetAttributes_by_DefaultGroup();
    return $me;
}

sub DESTROY {
    my($this) = @_;
    $this->{DBH}->Close(); # only for Win32::ODBC
    $this->{DBH}->disconnect;

}

=head2 ReadINI( 'Cluster.ini' )

  Read the INI file ('Cluster.ini') and set the patent object''s attributes.
  If you do not specify the Patent.ini in new() method, you can specify 
  it in this method.

  Return nothing, but has the side effect of setting some values to the
  attributes of the object.

=cut
sub ReadINI {
    my($me, $iniFile) = @_;
    my($GroupName, $DefaultGroup, %Groups);
    open (F, $iniFile) or die "Cannot open '$iniFile': $!";
    while (<F>) {
            next if /^#|^\s*$/; # if a comment line or an empty line
            chomp;
            if (/\[([^\[]+)\]/) { $GroupName = $1; next; }
            if (/^(\w+)=(.+)\s*$/) {
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
    	die "Ini_file=$iniFile\n$!";
    }
}


=head2 SetAttributes_by_DefaultGroup()

  By changing the 'DefaultGroup' attribute (say from 'USPTO' to 'JPO'),
  you may change the corresponding attributes (settings) by this method.

  Return nothing, but has the side effect of setting some values to the
  attributes of the object.

=cut
sub SetAttributes_by_DefaultGroup {
    my($me) = @_; my($k, $v);
    while (($k, $v) = each %{$me->{Groups}->{$me->{DefaultGroup}}}) {
            $me->{$k} = $v; # use the default group's attribute
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
            print "$k = $v\n\n";
    }
    print "\n#=========== Default group's attributes ...\n";
#    while (($k, $v) = each %{$me->{Groups}->{$me->{DefaultGroup}}}) {
# The above line is the same as next line, "->" can be omitted in 2-D case
    while (($k, $v) = each %{$me->{Groups}{$me->{DefaultGroup}}}) {
            print "$k = $v\n\n";
    }
}


=head2 $rDC->ShowDBIdrivers();

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

use DBI;
use DBI ':sql_types';
# $DBH = &InitDBH($DSN, $DBpath, $user, $pass);

=head2 InitDBMS() : Initialize database connection

  $DBH = $rDC->InitDBMS( );

=cut
#  Set attributes: DBH
sub InitDBMS {
    my($me, $DSN, $DB_Path) = @_;   my($DBH);
    $DSN = $me->{DSN} if $DSN eq '';
    $DB_Path = $me->{DB_Path} if $DB_Path eq '';
#    $DSN = "driver=Microsoft Access Driver (*.mdb, *.accdb);dbq=$DB_Path" if $DB_Path ne '';
print STDERR "DSN=$DSN\n" if $me->{'debug'}>=1;
#    $DBH = DBI->connect("DBI:ODBC:$DSN",,, {
#       RaiseError => 1, AutoCommit => 0
#     } ) or die "Can't make database connect: $DBI::errstr\n";
#    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
#    $DBH->{LongTruncOk} = 1;

    # $DBH = $me->InitDBH($DSN, $DB_Path);
    # The above line is replaced with the next line:
    $DBH = &InitDBH($DSN, $DB_Path, $me->{'user'}, $me->{'password'});

    $me->{DBH}->disconnect() if ref($me->{DBH}); # release previous DBH
    return $me->{'DBH'} = $DBH;
}


sub SaveCTree {
    my($me, $Threshold) = @_; my($DBH, $STH, $CTUID, $sql);
    $CTUID = $me->{'UID'};
    $DBH = $me->{'DBH'};
    $sql = "INSERT INTO CTree (CTID, CTName, CTDesc, CTUID, CTCTime) VALUES "
         . "(?, ?, ?, ?, ?)";
    $STH = $DBH->prepare($sql)
             or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($CTUID, $Threshold, "", $CTUID, "")
             or die "Can't execute SQL statement: $STH::errstr\n";
    $STH->finish;
}

sub SaveCatalog {
    my($me, $CID, $CName, $CPID) = @_; my($DBH, $STH, $CUID, $sql);
    $CUID = $me->{'UID'};
    $DBH = $me->{'DBH'};
    $sql = "INSERT INTO Catalog (CID, CName, CDesc, CUID, CPID, CCTime) VALUES "
         . "(?, ?, ?, ?, ?, ?)";
    $STH = $DBH->prepare($sql)
             or die "Can't prepare SQL statement: $DBI::errstr\n";
#    $STH->bind_param(2, $STH, DBI::SQL_LONGVARCHAR); #2014/10/27
    $STH->execute($CID, $CName, "", $CUID, $CPID, "")
             or die "Can't execute SQL statement: CID=$CID, "
             . "CName=$CName, CUID=$CUID, CPID=$CPID. $STH::errstr\n";
    $STH->finish;
}

sub DeleteDBMSRecords {
    my($me) = @_; my($DBH, $STH, $UID, $sql);
    $UID = $me->{'UID'};
    $DBH = $me->{'DBH'};
    $sql = "delete from CTree where CTUID=?";
    $STH = $DBH->prepare($sql)
             or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($UID)
             or die "Can't execute SQL statement: $sql=>$UID. $STH::errstr\n";
    $STH->finish;
    $sql = "delete from Catalog where CUID=?";
    $STH = $DBH->prepare($sql)
             or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($UID)
             or die "Can't execute SQL statement: $sql=>$UID. $STH::errstr\n";
    $STH->finish;
    $sql = "delete from Classify where CTID=?";
    $STH = $DBH->prepare($sql)
             or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($UID)
             or die "Can't execute SQL statement: $sql=>$UID. $STH::errstr\n";
    $STH->finish;
}

sub SaveClassify {
    my($me, $CID, $NID) = @_; my($DBH, $STH, $CTID, $sql);
    $CTID = $me->{'UID'};
    $DBH = $me->{'DBH'};
    $sql = "INSERT INTO Classify (CTID, CID, NID, CType, WgScore) VALUES "
         . "(?, ?, ?, ?, ?)";
    $STH = $DBH->prepare($sql)
             or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($CTID, $CID, $NID, 3, 0)
             or die "Can't execute SQL statement: $sql, $CTID, $CID, NID='$NID'\n";
    $STH->finish;
}

=head2 CutTree() : cluster the inserted documents with a threshold

  $rDC->CutTree( $threshold );

=cut
# Set 'CutTree', 'CutPapa'
sub CutTree {
    my($me, $Threshold) = @_; 
    my($root, @NewRoot, %NewRoot, $rTree, $rRoot);
print STDERR "\nCut the clustered tree with threshold: '$Threshold'<br>\n" if $me->{debug}>=1;
    $rRoot = $me->{'Root'};
    $rTree = $me->{'Tree'};
    foreach $root (keys %$rRoot) {
    	push @NewRoot, $me->ParseTree($root, $rTree, $Threshold);
    }
    foreach $root (@NewRoot) { # get each new root's number of leaves
    	$NewRoot{$root} = $me->GetLeaveNumber($root, $rTree);
#print "$root ($NewRoot{$root})<br>\n";
    }
    $me->{'Cid2Terms'} = $me->GenCid2Terms(\@NewRoot);
    return $me->CreateTreeHTML(\%NewRoot, $Threshold); 
}

=head2 CreateTreeHTML() : 

=cut
# Given the roots, Cid2Terms, return the tree in HTML string ready for 
# output to a browser
# Use attributes: 'Title', 'Cid2Terms', 'FileList'
# Use methods : Traverse()
sub CreateTreeHTML {
    my($me, $rRoot, $Threshold) = @_;  
    my($root, $i, $si, $msg, $c, @Root, $htmlstr, %Freq, $n, $nc);

#    $htmlstr = "<html><head></head><body bgcolor=white>";
# output tree statistics
    %Freq = (); # (key, value) = (number_of_leaves, number_of_clusters)
    @Root = sort { $rRoot->{$b} <=> $rRoot->{$a} } keys %$rRoot;
#print "<p>", join("<br>\n", map{"$_:$rRoot->{$_}"}@Root), "<p>\n";
    $n = @Root;
    # %$rRoot : (key, value) = (cluster_id:similarity, number_of_leaves)

# You may remark this segment
#=comment until next =cut
    foreach $i (@Root) { $Freq{$rRoot->{$i}}++; } 
    $msg = ''; $si = 0;
    foreach $i (sort {$Freq{$b} <=> $Freq{$a}} keys %Freq) {
#	$msg .= "$Freq{$i} clusters contain $i items<br>\n"; 
	$si += $i * $Freq{$i};
    }
#    $htmlstr .= "There are $n clusters, $si items<p>\n". $msg;

#    $me->SaveCTree('門檻='.$Threshold.',有'.$n.'類,共'.$si.'筆');
    $me->SaveCTree('Threshold='.$Threshold.', having '.$n.' categories and '.$si.' Docs.');
# output tree structures
    my $rPapa = \();  $nc = 0;
    foreach $root (@Root) {
    	$i = 0;  $me->Traverse(-1, $root, "", ++$i, $rPapa, $rRoot); 
    	# -1 for root node
    	$nc ++; last if $nc > $me->{'MaxCluster'};
#    	last if $rRoot{$root} <= 2; # if <= node;
    }
    return $htmlstr;
}

=head2 Traverse() : 

=cut
# Use attributes: 'Title', 'Cid2Terms', 'DocPath'
sub Traverse {
    my($me, $papa, $node, $level, $i, $rPapa, $rRoot) = @_;  
    #(papa, node, level_string, itemNo, papa_ref, RooSize_ref)
    my($n, $j, $t, $title, $cid, @T, @Sons, $patnum, $ctt, $htmlstr);
    my($rDocPath, $rCid2Terms, @TV, %TermV, $rTree, $CID, $CPID, $CName);
    $rTree = $me->{'Tree'};
    $rCid2Terms = $me->{'Cid2Terms'};
    $rDocPath = $me->{'DocPath'};
    $ctt = $me->{'NumCatTitleTerms'}-1;

    $CID = $CName = $node; 
    $CID =~ s/:.+//; # get node number
    $CName =~ s/^[^:]+://; # get similarity
    if ($CName=~/^[\d\.]+$/) { $CName = sprintf("%3.2f", $CName); }
#    $CName = $rRoot->{$node} . '筆,' . $CName if $rRoot->{$node}>0;
    $CName = $rRoot->{$node} . ' Docs.,' . $CName if $rRoot->{$node}>0;
    $CPID = $papa; $CPID =~ s/:.+//; # get papa's node number
        
    @Sons = split /\t/, $rTree->{$node};
    if (@Sons == 0) { # if leaf node, format is "document number"
	$me->SaveClassify($CPID, $rDocPath->[$node]); # pass in ($CID, $NID)
    } else { # if internal node, format is "Node_Number:Similarity"
	if ($node =~ /(\d+):/) { 
	    $cid = $1;
	    @T = split("\t", $rCid2Terms->{$cid});
#=head sort the term by the value
	    %TermV = (); # clear the hash
	    for ($n=0; $n<@T; $n++) {
	    	($t, $j) = split /:/, $T[$n];
#	    	last if $j<1 and $n>=3; 
		next if $t eq '';
		$TermV{$t} = $j;
	    } # get at most $ctt+1 terms or more terms if their values are 1s
	    @TV = sort {$TermV{$b} <=> $TermV{$a}} keys %TermV;
	    $n = (@TV-1<$ctt)?@TV-1:$ctt;
	    $CName .= "(".join(", ",map{"$_:$TermV{$_}"}@TV[0..$n]).")";
	}
	$me->SaveCatalog($CID, $CName, $CPID); # pass in ($CID, $CName, $CPID)
	for ($j=0; $j<@Sons; $j++) {
	    $me->Traverse($node, $Sons[$j], "  $level$i.", $j+1, $rPapa);
        }
    }
} # End of &Traverse()


# Given %Chi, %DF, $DocNum, set %Cid2Terms
sub ComputeMaxCHI {
    my($me) = @_; my($rTP, $rDF, $rDFcat, $NumDocClass, $rChi);
    my($k, $t, $w, $cat, @Chi, @tn, $v, $vdf, %Cid2Terms);
    $rChi = $me->{'Chi'};
    $rTP = $me->{'TP'};
    $rDF = $me->{'DF'};
    $rDFcat = $me->{'DFcat'};
    $NumDocClass = $me->{'NumDocClass'};
    @Chi = sort {$rChi->{$b} <=> $rChi->{$a} } keys %$rChi;
    foreach $k (@Chi) {
    	($t, $cat) = split /\t/, $k;
#    	next if $rDF->{$t} <= $Odf;
#	$tn[$cat]++;	next if $tn[$cat] > 9;
#	$v = sprintf("%5.4f", $rChi->{$k}); 
	$v = sprintf("%3.2f", $rChi->{$k}); 
#	$v = 1 if $v >= 1;
# above 2 lines is replaced by the next 2 lines on 2003/12/22, but no better
#	$vdf = $rChi->{$k} * log($rDF->{$t})/log($NumDocClass);
#	$v = sprintf("%6.2f", $vdf); 
	$w = $me->DelSpace($t);
	$Cid2Terms{$cat} .= "$w:$v\t" 
#	$Cid2Terms{$cat} .= "<b>$t</b>:$v\t" 
#	$Cid2Terms{$cat} .= "<b>$t</b>\t" 
	  if $v > 0 
	  and $rTP->{$k} >= $rDFcat->{$cat} * 0.5
#	  and index($Cid2Terms{$cat}, "$t")<0 # should not include substring
	  and index($Cid2Terms{$cat}, $w)<0; # should not include substring
#	  if $v > 0 and index($Cid2Terms{$cat}, ">$t<")<0;
#print "\$Cid2Terms{$cat}=$Cid2Terms{$cat}, '$t':$v, TP=$rTP->{$k}, DFcat=$rDFcat->{$cat}<br>\n";
}
#print join("<p>\n", map{"$_:$Cid2Terms{$_}"}keys%Cid2Terms), "<p>\n";
    $me->{'Cid2Terms'} = \%Cid2Terms;
}


=head2 DelSpace() : delete spaces between each Chinese character

  $text = $seg->DelSpace( $text );

  Given a string of text with each Chinese character or English word separated
  by a space (a result after calling &SegWord->ExtractKeyPhrase();), delete
  the space between Chinese characters but not between the English words.

=cut
sub DelSpace { # public
    my($me, $t) = @_; my(@Token, @Term, $i);
    @Token = split ' ', $t; 
    @Term = ($Token[0]);
    for($i=1; $i<@Token; $i++) {
        push @Term, ' ' 
        	if $Token[$i-1] =~/^[\w\d]/ and $Token[$i] =~ /^[\w\d]/;
        push @Term, $Token[$i];
    }
    return join ('', @Term); 
}

1;
