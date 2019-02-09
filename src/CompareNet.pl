#!/usr/bin/perl -s
use vars; use strict;

# perl -s CompareNet.pl ..\Result\SCIENTO_dc\Key_RT_5.net ..\Result\SCIENTO_dc\Inv.txt ..\Result\ScientoDE\SimPairs_0.15_1.5.net ..\Result\ScientoDE\DE_DocList.txt
    my($Pajek1, $Inv1, $Pajek2, $Inv2) = @ARGV;
    my($rId2T1, $rEdge1) = &Read_Pajek_File($Pajek1);
    my($rDF1, $rT2Dlist1) = &GetDF_from_InvFile($Inv1);
    my($rId2T2, $rEdge2) = &Read_Pajek_File($Pajek2);
    my($rDF2, $rT2Dlist2) = &GetDF_from_DocList($Inv2);

    my($t, %T2Id1, %T2Id2, @Both, @T1nT2, @T2nT1);
    %T2Id1 = reverse %$rId2T1;  %T2Id2 = reverse %$rId2T2;
    my($both, $t1nt2, $t2nt1) = (0, 0, 0);
    foreach $t (keys %T2Id1) {
    	if ($T2Id2{$t}) { 
	    $both++; push @Both, $t; 
	    print STDERR "\$rDF1->{$t}=$rDF1->{$t} != \$rDF2->{$t}=$rDF2->{$t}\n" if $rDF1->{$t} != $rDF2->{$t};
	}
    	if (not $T2Id2{$t}) { $t1nt2++; push @T1nT2, $t; }
    }
    foreach $t (keys %T2Id2) {
    	if (not $T2Id1{$t}) { $t2nt1++; push @T2nT1, $t; }
    }
    print "In 1 but not in 2: $t1nt2\n", join("\n", map{"$_\t$rDF1->{$_}"}@T1nT2), "\n\n";
    print "In 2 but not in 1: $t2nt1\n", join("\n", map{"$_\t$rDF2->{$_}"}@T2nT1), "\n\n";
    print "Both have Nodes : $both\n",
    	  "In 1 but not in 2: $t1nt2\n",
    	  "In 2 but not in 1: $t2nt1\n\n";

    my($bothe, $e1ne2, $e2ne1) = (0, 0, 0);
    my($e, @Bothe, @E1nE2, @E2nE1);
    foreach $e (keys %$rEdge1) {
    	if ($rEdge2->{$e}) { 
	    $bothe++; push @Bothe, $e; 
	}
    	if (not $rEdge2->{$e}) { $e1ne2++; push @E1nE2, $e; }
    }
    foreach $e (keys %$rEdge2) {
    	if (not $rEdge1->{$e}) { $e2ne1++; push @E2nE1, $e; }
    }

    print "In both: $bothe\n", join("\n", 
	map{"$_\t". &Common($_, $rT2Dlist1, $rT2Dlist2)}@Bothe), "\n\n";
    print "In 1 but not in 2: $e1ne2\n", join("\n", 
	map{"$_\t". &Common($_, $rT2Dlist1, $rT2Dlist2)}@E1nE2), "\n\n";
    print "In 2 but not in 1: $e2ne1\n", join("\n", 
	map{"$_\t". &Common($_, $rT2Dlist1, $rT2Dlist2)}@E2nE1), "\n\n";
    print "Both have Edges : $bothe\n",
    	  "In 1 but not in 2: $e1ne2\n",
    	  "In 2 but not in 1: $e2ne1\n";

sub Read_Pajek_File {
    my($File) = @_;
    my(%Id2T, $e, %Edge);
    open F, $File or die "Cannot read file:'$File'";
    while (<F>) {
	chomp;	next if /^\s*$/;
	if (/^(\d+)\s+"([^"]+)"\s*/) { # e.g., "1 "russia" 0.1 ..."
	    $Id2T{$1} = $2;
	}
	if (/^(\d+)\s+(\d+)/) { # e.g., "1 2"
	    $e = join ("\t", sort ($Id2T{$1}, $Id2T{$2}));
	    $Edge{$e} = 1;
	}
    }
    close(F);
    return (\%Id2T, \%Edge);
}

sub GetDF_from_DocList {  
    my($File) = @_;  
    my($id, $t, $df, $r, %DF, %T2Dlist);
    open F, $File or die "Cannot read file:'$File'";
    while (<F>) { # 1 : russia : 9 : ISI_000072877000011_	1 ...
    	($id, $t, $df, $r) = split / : /, $_;
    	next if $df <= 0;
    	$DF{$t} = $df;  
    	$r=~s/\t$//; # remove last tab
    	$T2Dlist{$t} = $r;
    }    
    close(F);
    return (\%DF, \%T2Dlist);
}

sub GetDF_from_InvFile {  
    my($InvFile) = @_;  
    my($t, $df, $r, @R, %DF, %T2Dlist);
    open F, $InvFile or die "Cannot read file:'$InvFile'";
    while (<F>) { # slovenia	122,1,513,7,1241,1,1253,1,
    	($t, $r) = split /\t/, $_;
    	$DF{$t} = int(($r=~tr/,/,/)/2); 
    	$r=~s/,$//; # remove last comma
    	$T2Dlist{$t} = $r;
    }    
    close(F);
    return (\%DF, \%T2Dlist);
}

sub ts { my($x, $n) = @_; $n=4 if not $n; return sprintf("%0.".$n."f", $x);  }

sub Common {
    my($e, $rT2Dlist1, $rT2Dlist2) = @_;
    my($t1, $t2) = split /\t/, $e;
    my($df_1, $df1_1, $df2_1) = &CommonDetail($t1, $t2, $rT2Dlist1);
    my($df_2, $df1_2, $df2_2) = &CommonDetail($t1, $t2, $rT2Dlist2);
    print STDERR 
    "\$df=($df_1,$df_2), \$df1=($df1_1,$df1_2), \$df2=($df2_1,$df2_2)\n"
    	if ($df_1 != $df_2) or ($df1_1 != $df1_2) or ($df2_1 != $df2_2); 
    return "$df1_1\t$df2_1\t$df_1\t".&ts(2*$df_1/($df1_1+$df2_1));
}

sub CommonDetail{
    my($t1, $t2, $rT2Dlist) = @_;  my(%D1, %D2, $df1, $df2, $df, $d);
    %D1 = split /,|\t/, $rT2Dlist->{$t1};
    %D2 = split /,|\t/, $rT2Dlist->{$t2};
    $df1 = keys %D1; $df2 = keys %D2;
    foreach $d (keys %D1) { $df++ if $D2{$d}; }
    return ($df, $df1, $df2);
}