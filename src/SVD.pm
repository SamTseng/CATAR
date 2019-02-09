#!/usr/bin/perl -s

package SVD;

    use Exporter;
    @ISA = qw(Exporter); # inherit class Exporter for exporting methods
    @EXPORT = qw(SVD); # export the methods in this package

    use Math::MatrixReal;
    use strict; use vars;    

# Next is a comment segment in POD format. Comment ends until '=cut'
=head1 NAME

SVD -- A package for Singular Value Decomposition.

       Given M of a m-by-n matrix, find three matrices: U, S, and V, such that M=USV*,
       where S is m-by-n with nonnegative numbers on the diagonal and zeros off the diagonal,
             U is an m-by-m unitary matrix,
             V* denotes the conjugate transpose of V, an n-by-n unitary matrix.
       From http://en.wikipedia.org/wiki/Singular_value_decomposition, it says:
	 The matrix V thus contains a set of orthonormal "input" 
	   or "analysing" basis vector directions for M.
	 The matrix U contains a set of orthonormal "output" basis vector directions for M.
	 The matrix S contains the singular values, which can be thought of 
	   as scalar "gain controls" by which each corresponding input is multiplied 
	   to give a corresponding output.
	 A common convention is to order the values S(i,i) in non-increasing 
	   fashion. In this case, the diagonal matrix S is uniquely determined by 
	   m (though the matrices U and V are not).
	 Eigen Value Decomposition is for Hamilton matrices (squared, symmetric, semi-positve).

    Note : The output $S is a vector containing all the sigular values in descending order.
            $S is not the diagonal matrix S in its mathmatic form.

=head1 SYNOPSIS

    use Math::MatrixReal; # Matrices are represented in Math::MatrixReal format
    use SVD;

    my($M, $nr, $nc, $U, $S, $V, $M2, $U2, $S2, $V2, $i, $j, $r, $c);
    $M = &test1()  if $Otest1;   # for $nr >= $nc
    $M = &test12() if $Otest12;  # for $nr < $nc
    $M = &test2()  if $Otest2;   # for $nr >= $nc
    $M = &test3()  if $Otest3;   # for $nr >= $nc
    $M = &test32() if $Otest32;  # for $nr < $nc
    ($nr, $nc) = $M->dim();
    $U = new Math::MatrixReal($nr, $nr); # double[nr][nr];
    $S = new Math::MatrixReal(1, $nc); # double[nc];
    $V = new Math::MatrixReal($nc, $nc); # double[nc][nc];
#    print "Before calling SVD, M=\n", $M;
    print "M=(USV*=)\n",  $M->as_matlab( ( format => "%.3f") ), "\n";
    ($U, $S, $V) = SVD::SVD($M); # for any rectangular matrix $M, output U, S, V (not V*)
    # Note: $U is truncated if $nr >= $nc, $V is truncated if $nr < $nc
    if ($U->[0][0][0] < 0) { 
	$U = -1 * $U; # Negate each element to get positive values for our examples
	$V = -1 * $V; # Negation should be done for both matrices at the same time
    } # See Reference [1]
    print "U=\n", $U->as_matlab( ( format => "%.3f") ), "\n";
    print "S=\n", $S->as_matlab( ( format => "%.3f") ), "\n";
    print "V=\n", $V->as_matlab( ( format => "%.3f") ), "\n\n";

# Reconstruct back the original matrix
    $U2 = new Math::MatrixReal($nr, $nr); # the un-truncated U (for $nr >= $nc)
    $S2 = new Math::MatrixReal($nr, $nc); # The real diagonal matrix
    $V2 = new Math::MatrixReal($nc, $nc); # the un-truncated V (for $nr < $nc)
    $M2 = new Math::MatrixReal($nr, $nc);
    for($i=0; $i<$nc; $i++) { $S2->[0][$i][$i] = $S->[0][0][$i]; }
#    if ($nr >= $nc) {
	for($i=0; $i<$nr; $i++) {
	    for($j=0; $j<$nr; $j++) { # $U is truncated if $nr >= $nc
		$U2->[0][$i][$j] = $U->[0][$i][$j]; # undefined value is zero
	    }
	}
#    } else { # $nr < $nc
	for($i=0; $i<$nc; $i++) {
	    for($j=0; $j<$nc; $j++) { # $V is truncated if $nr < $nc
		$V2->[0][$i][$j] = $V->[0][$i][$j]; # undefined value is zero
	    }
	}
#    }
    $M2 = $S2 * ~ $V2;
    print "S x Vt =\n", $M2->as_matlab( ( format => "%.3f") ), "\n";
    $M2 = $U2 * $M2;
    print "U x S x Vt =\n", $M2->as_matlab( ( format => "%.3f") ), "\n\n";

# Get the EigenTrend and Authority Score, and reconstruct back the original matrix gradually
    my($EigenTrend, $AuthScore); # See Reference [1]
    $AuthScore  = new Math::MatrixReal($nr, 1);
    $EigenTrend = new Math::MatrixReal(1, $nc);
    for($j=0; $j<&Min($nr, $nc); $j++) {
	for ($i=0; $i<$nr; $i++) {  $AuthScore->[0][$i][0] = $U->[0][$i][$j]; }
	for ($i=0; $i<$nc; $i++) { $EigenTrend->[0][0][$i] = $S->[0][0][$j] * $V->[0][$i][$j]; }
	if ($j == 0) {
	    print "AuthScore=\n",   $AuthScore->as_matlab( ( format => "%.3f") ), "\n";
	    print "EigenTrend=\n", $EigenTrend->as_matlab( ( format => "%.3f") ), "\n\n";
	    $M2  = $AuthScore->column(1) * $EigenTrend->row(1);
	} else {
	    $M2 += $AuthScore->column(1) * $EigenTrend->row(1);
	}
	print "Apprx. ", ($j+1)," =\n", $M2->as_matlab( ( format => "%.3f") ), "\n";
    }
    exit;   
     
# Reference: 
# [1] Yun Chi, Belle L. Tseng, Junichi Tatemura, "Eigen-Trend: Trend Analysis 
#     in the Blogosphere based on Singular Value Decompositions," 
#     ACM CIKM'06, pp.68-77.

sub Min { my($a, $b) = @_; return ($a>$b?$b:$a); }

sub test1 {
    my $Ma = Math::MatrixReal->new_from_string(<<'MATRIX');
     [ 2 4 ]
     [ 1 3 ]
     [ 0 0 ]
     [ 0 0 ]
MATRIX
    return $Ma;
} # End of &test1()

sub test12 {
    my $Ma = Math::MatrixReal->new_from_string(<<'MATRIX');
     [ 2 1 0 0 ]
     [ 4 3 0 0 ]
MATRIX
    return $Ma;
} # End of &test1()

Results of &test1() from http://web.mit.edu/be.400/www/SVD/Singular_Value_Decomposition.htm
[U,D,V] = svd(M);
U =
	0.82	-0.58	0	0
	0.58	0.82	0	0
	0	0	1	0
	0	0	0	1
D =
	5.47	0
	0	0.37
	0	0
	0	0
V =  (Note: not V*)
	0.40	-0.91
	0.91	 0.40

Results of &test1() from Perl version:
U=
[ -0.817 -0.576;
  -0.576  0.817;
   0.000  0.000;
   0.000  0.000 ]
S=
[  5.465  0.366 ]
V= (Note: not V*)
[ -0.405 -0.915;
  -0.915  0.405 ]


sub test2 {
    my $Ma = Math::MatrixReal->new_from_string(<<'MATRIX');
     [ 1.0  1.0                 1.0                 1.0                 1.0 ]
     [ 0.0  0.7578582801241234  0.8705505614977934  0.9440875104854797  1.0 ]
     [ 0.0  0.5743491727526943  0.7578582801241234  0.8913012274546708  1.0 ]
     [ 0.0  0.4352752672614163  0.6597539444834084  0.8414663533131370  1.0 ]
     [ 0.0  0.3298769722417042  0.5743491727526943  0.7944178780622027  1.0 ]
     [ 0.0  0.25                0.5                 0.75                1.0 ]
MATRIX
    return $Ma;
} # End of &test2()

Results of &test2() from Matlab
[U,D,V] = svd(M);
D =
    4.0143         0         0         0         0
         0    0.9803         0         0         0
         0         0    0.3522         0         0
         0         0         0    0.0209         0
         0         0         0         0    0.0004
         0         0         0         0         0
V =
    0.1290   -0.8538    0.5019   -0.0503    0.0022
    0.3605   -0.3537   -0.6377    0.5576   -0.1651
    0.4543   -0.0929   -0.3332   -0.5544    0.6055
    0.5325    0.1348    0.0544   -0.4113   -0.7254
    0.6029    0.3452    0.4769    0.4583    0.2827

Results of &test2() from Java version:
D=
[ 4.014  0.980  0.352  0.021  0.000  ]
V=
[ -0.129   0.854  -0.502   0.050   0.002  ]
[ -0.360   0.354   0.638  -0.558  -0.165  ]
[ -0.454   0.093   0.333   0.554   0.606  ]
[ -0.533  -0.135  -0.054   0.411  -0.725  ]
[ -0.603  -0.345  -0.477  -0.458   0.283  ]

Results of &test2() from Perl version:
U=
[-0.518  0.837 -0.177  0.001  0.000;
 -0.442 -0.126  0.696 -0.479 -0.258;
 -0.406 -0.196  0.265  0.389  0.631;
 -0.376 -0.248 -0.072  0.517 -0.132;
 -0.350 -0.288 -0.336  0.138 -0.615;
 -0.329 -0.318 -0.544 -0.577  0.374 ]
S=
[ 4.014 0.980 0.352 0.021 0.000 ]
V= (Note: not V*)
[-0.129  0.854 -0.502  0.050  0.002;
 -0.360  0.354  0.638 -0.558 -0.165;
 -0.454  0.093  0.333  0.554  0.606;
 -0.533 -0.135 -0.054  0.411 -0.725;
 -0.603 -0.345 -0.477 -0.458  0.283 ]

   
# Results of &test3() is the same as those of &test2()
sub test3 {
    my($nr, $nc) = (6, 5);  
    my $Ma = new Math::MatrixReal($nr, $nc);
    my($r, $c, $p, $frac);
    for( $r = 0; $r < $nr; $r++ ) {
	$p = $r / ($nr-1);
	for( $c = 0; $c < $nc; $c++ ) {
	    $frac = $c / ($nc-1);
	    $Ma->assign($r+1, $c+1, $frac ** $p);  # M[r][c] = Math.pow(frac,p);
	}
    }
    return $Ma;
}

sub test32 {  # transpose of &test3()
    my($nr, $nc) = (6, 5);  
    my $Ma = &test3();
    my($nr2, $nc2) = (5, 6);  
    my $Ma2 = new Math::MatrixReal($nr2, $nc2);
    my($r, $c);
    for( $r = 0; $r < $nr; $r++ ) {
	for( $c = 0; $c < $nc; $c++ ) {
	    $Ma2->[0][$c][$r] = $Ma->[0][$r][$c];
	}
    }
    return $Ma2;
}


=head1 DESCRIPTION

  This program is converted from a Java code by Sam Tseng on 2007/01/15.
  The Java SVD code is from http://www.idiom.com/~zilla/Computer/Javanumeric/SVD_NR.java
      where this link is at http://www.idiom.com/~zilla/Computer/Javanumeric/index.html
      which in turn was reached from http://en.wikipedia.org/wiki/Singular_value_decomposition.

  /** Remarks from the Java version:
   *    Returns U in a (the input matrix). 
   *    Normaly U is nr*nr,
   *      but if nr>nc only the first nc columns are returned
   *      (nice, saves memory).
   *    The columns of U have arbitrary sign,
   *      also the columns corresponding to near-zero singular values
   *      can vary wildly from other implementations.
   */

Author:
    Yuen-Hsien Tseng. 
Date:
    2007/01/15.

=cut

=head1 Methods

=head2 SVD() : Singular Value Decomposition for rectangular matrices

   ($U_Matrix, $SingularValues_in_a_Vector, $V_Matrix) = SVD($InputMatrix);
   Note: The $U_Matrix is truncated if $nr >= $nc, or the $V_Matrix is truncated.
         All the returned values are in Math::MatrixReal format.
         The $InputMatrix won't be changed.

=cut

sub SVD {
    my($a) = @_;
    my($m, $n) = $a->dim(); # ($rows,$columns) = $matrix->dim();
    if ($m < $n) { # rows less than columns
	my $b = new Math::MatrixReal($n, $m);
	my $U = new Math::MatrixReal($m, $m);
	my $S = new Math::MatrixReal(1, $m);
	my $V = new Math::MatrixReal($n, $n);
        $b->transpose($a);
        ($V, $S, $U) = &_SVD($b);
        return ($U, $S, $V);
    } else {
	my $b = new Math::MatrixReal($m, $n);
	$b->copy($a);
	return &_SVD($b);
    }
}

sub _SVD {
    my($a) = @_;
    my($i, $its, $j, $jj, $k, $l, $nm, $flag, $m, $n);
    $l = $nm = 0;
    ($m, $n) = $a->dim(); # ($rows,$columns) = $matrix->dim();
    my ($c, $f, $h, $s, $x, $y, $z);
    my $anorm = 0; my $g = 0; my $scale = 0;
# Assume $m >= $n # zliberror._assert(m>=n) ;
    my $rv1 = new Math::MatrixReal(1, $n); # double[n]; # seems a column vector due to $n
    my $w = new Math::MatrixReal(1, $n);
    my $v = new Math::MatrixReal($n, $n);

    for ($i=0; $i < $n; $i++) {
	$l = $i+1;
	$rv1->[0][0][$i] = $scale * $g;
	$g = $s = $scale = 0.0 ;
	if ($i < $m) {
	    for ($k=$i; $k<$m; $k++) { 
	    	$scale += abs($a->[0][$k][$i]);
	    }
	    if ($scale!=0.0) {
		for ($k=$i; $k<$m; $k++) {
		    $a->[0][$k][$i] /= $scale;
		    $s += $a->[0][$k][$i]*$a->[0][$k][$i];
		}
		$f = $a->[0][$i][$i];
		$g = -&SIGN(sqrt($s), $f);
	  	$h = $f * $g - $s;
		$a->[0][$i][$i] = $f - $g;
	  # //if (i!=(n-1)) {		// CHECK
		for ($j = $l; $j<$n; $j++) {
		    for ($s=0, $k=$i; $k<$m; $k++) {
			$s += $a->[0][$k][$i] * $a->[0][$k][$j];
		    }
		    $f = $s/$h;
		    for ($k = $i; $k<$m; $k++) {
			$a->[0][$k][$j] += $f * $a->[0][$k][$i];
		    }
		}
	  # //}
		for ($k=$i; $k<$m; $k++) { 
		    $a->[0][$k][$i] *= $scale;
		}
	    } # End of if ($scale!=0.0) {
	} # End of if ($i < $m) {
	$w->[0][0][$i] = $scale * $g;
	$g = $s = $scale = 0.0 ;
	if ($i<$m && $i!=$n-1) {
	    for ($k=$l; $k<$n; $k++) {
		$scale += abs($a->[0][$i][$k]);
	    }
	    if ($scale != 0.0) {
		for ($k=$l; $k<$n; $k++) {
		    $a->[0][$i][$k] /= $scale;
		    $s += $a->[0][$i][$k] * $a->[0][$i][$k];
		}
		$f = $a->[0][$i][$l];
		$g = - &SIGN(sqrt($s), $f);
		$h = $f * $g - $s; 
		$a->[0][$i][$l] = $f - $g;
		for ($k=$l; $k<$n; $k++) {
		    $rv1->[0][0][$k] = $a->[0][$i][$k]/$h;
		}
		if ($i!=$m-1) {
		    for ($j=$l; $j<$m; $j++) {
			for ($s=0, $k=$l; $k<$n; $k++) {
			    $s += $a->[0][$j][$k] * $a->[0][$i][$k];
			}
			for ($k=$l; $k<$n; $k++) {
			    $a->[0][$j][$k] += $s * $rv1->[0][0][$k];
			}
		    }
		}
		for ($k = $l; $k<$n; $k++) {
		    $a->[0][$i][$k] *= $scale;
		}
	    } # End of if ($scale != 0.0) {
	} # End of if ($i<$m && $i!=$n-1) { //i<m && i!=n-1
	$anorm = &Max( $anorm, ( abs($w->[0][0][$i])+abs($rv1->[0][0][$i]) ) );
    } # End of for ($i = 0; $i < $n; $i++) { //i
    for ($i=$n-1; $i>=0; --$i) {
	if ($i<$n-1) {
	    if ($g != 0.0) {
		for ($j=$l; $j<$n; $j++) {
		    $v->[0][$j][$i] = ($a->[0][$i][$j]/$a->[0][$i][$l])/$g;
		}
		for ($j=$l; $j<$n; $j++) {
		    for ($s=0, $k=$l; $k<$n; $k++) {
			$s += $a->[0][$i][$k] * $v->[0][$k][$j];
		    }
		    for ($k=$l; $k<$n; $k++) {
			$v->[0][$k][$j] += $s * $v->[0][$k][$i];
		    }
		}
	    }
	    for ($j=$l; $j<$n; $j++) {
		$v->[0][$i][$j] = $v->[0][$j][$i] = 0.0;
	    }
	} # End of if (i<n-1) {
	$v->[0][$i][$i] = 1.0;
	$g = $rv1->[0][0][$i];
	$l = $i;
    } # End of for (i=n-1; i>=0; --i) {
    # //for (i=IMIN(m,n);i>=1;i--) {	// !
    # //for (i = n-1; i>=0; --i)  {
    for ($i=&Min($m-1, $n-1); $i>=0; --$i) {
	$l = $i+1;
	$g = $w->[0][0][$i];
	if ($i<$n-1) {
	    for ($j=$l; $j<$n; $j++) {
		$a->[0][$i][$j] = 0.0;
	    }
	}
	if ($g != 0.0) {
	    $g = 1.0/$g;
	    if ($i!= $n-1) {
		for($j=$l; $j<$n; $j++) {
		    for ($s=0, $k=$l; $k<$m; $k++) {
			$s += $a->[0][$k][$i] * $a->[0][$k][$j];
		    }
		    $f = ($s / $a->[0][$i][$i]) * $g;
		    for ($k=$i; $k<$m; $k++) {
			$a->[0][$k][$j] += $f * $a->[0][$k][$i];
		    }
		}
	    }
	    for ($j=$i; $j < $m; $j++) {
		$a->[0][$j][$i] *= $g;
	    }
	} else {
	    for ($j=$i; $j<$m; $j++) {
		$a->[0][$j][$i] = 0.0;
	    }
	}
	$a->[0][$i][$i] += 1.0;
    }
    for ($k=$n-1; $k>=0; --$k)  {
	for ($its=1; $its<=30; ++$its) {
	    $flag = 1; # true;
	    for ($l=$k; $l>=0; --$l) {
		$nm = $l-1;
		if ((abs($rv1->[0][0][$l])+$anorm) == $anorm) {
		    $flag = 0; # false;
		    last; # break ;
		}
		last if ((abs($w->[0][0][$nm])+$anorm) == $anorm);
	    }
	    if ($flag) {
		$c = 0.0;
		$s = 1.0;
		for ($i=$l; $i<=$k; $i++)  {
		    $f = $s * $rv1->[0][0][$i];
		    $rv1->[0][0][$i] = $c * $rv1->[0][0][$i];
		    last if ((abs($f)+$anorm)==$anorm);
		    $g = $w->[0][0][$i];
		    $h = &Pythag($f, $g); 
		    $w->[0][0][$i] = $h;
		    $h = 1.0/$h;
		    $c = $g * $h;
		    $s = -$f * $h;
		    for ($j=0; $j<$m; $j++) {
			$y = $a->[0][$j][$nm];
			$z = $a->[0][$j][$i];
			$a->[0][$j][$nm] = $y*$c+$z*$s;
			$a->[0][$j][$i] = $z*$c-$y*$s;
		    }
		}
	    } # //flag
	    $z = $w->[0][0][$k];
	    if ($l==$k) {
		if ($z<0.0) {
		    $w->[0][0][$k] = -$z;
		    for ($j=0; $j<$n; $j++) {
			$v->[0][$j][$k] = - $v->[0][$j][$k];
		    }
		}
		last;
	    } # //l==k
	    # zliberror._assert(its<50, "no svd convergence in 50 iterations");
	    $x = $w->[0][0][$l];
	    $nm = $k-1;
	    $y = $w->[0][0][$nm];
	    $g = $rv1->[0][0][$nm];
	    $h = $rv1->[0][0][$k];
	    $f = (($y-$z)*($y+$z)+($g-$h)*($g+$h))/(2*$h*$y);
	    $g = &Pythag($f, 1.0);
	    $f = (($x-$z)*($x+$z)+$h*(($y/($f+&SIGN($g,$f)))-$h))/$x;
	    $c = $s = 1.0;
	    for ($j=$l; $j<=$nm; $j++) {
		$i = $j+1;
		$g = $rv1->[0][0][$i];
		$y = $w->[0][0][$i];
		$h = $s * $g;
		$g = $c * $g;
		$z = &Pythag($f,$h) ;
		$rv1->[0][0][$j] = $z;
		$c = $f/$z;
		$s = $h/$z;
		$f = $x*$c+$g*$s;
		$g = $g*$c-$x*$s;
		$h = $y*$s;
		$y *= $c;
		for ($jj=0; $jj<$n; $jj++) {
		    $x = $v->[0][$jj][$j];
		    $z = $v->[0][$jj][$i];
		    $v->[0][$jj][$j] = $x*$c+$z*$s;
		    $v->[0][$jj][$i] = $z*$c-$x*$s;
		}
		$z = &Pythag($f, $h);
		$w->[0][0][$j] = $z;
		if ($z != 0.0) {
		    $z = 1.0/$z;
		    $c = $f * $z;
		    $s = $h * $z;
		}
		$f = $c*$g+$s*$y;
		$x = $c * $y - $s * $g;
		for ($jj=0; $jj<$m; ++$jj) {
		    $y = $a->[0][$jj][$j];
		    $z = $a->[0][$jj][$i];
		    $a->[0][$jj][$j] = $y*$c+$z*$s;
		    $a->[0][$jj][$i] = $z*$c-$y*$s;
		}
	    } # //j<nm
	    $rv1->[0][0][$l] = 0.0;
	    $rv1->[0][0][$k] = $f;
	    $w->[0][0][$k] = $x;
	} # //its
    } # //k
    # // free rv1
# Now sort $w (and $v) descendently
    my($maxj);
    for($i=0; $i<$n-1; $i++) { # selection sort
    	$maxj = $i;
    	for($j=$i+1; $j<$n; $j++) {
	    $maxj = $j if ($w->[0][0][$j] > $w->[0][0][$maxj]);
    	}
    	if ($maxj != $i) { # swap positions, use $z as a temp variable
	    $z = $w->[0][0][$maxj];
	    $w->[0][0][$maxj] = $w->[0][0][$i];
	    $w->[0][0][$i] = $z;
	    for($j=0; $j<$n; $j++) { # for each row, swap the columns
		$z = $v->[0][$j][$maxj];
		$v->[0][$j][$maxj] = $v->[0][$j][$i];
		$v->[0][$j][$i] = $z;
		$z = $a->[0][$j][$maxj];
		$a->[0][$j][$maxj] = $a->[0][$j][$i];
		$a->[0][$j][$i] = $z;
	    }
    	}
    }
    return ($a, $w, $v); # return U, S, V
    # return ($w, $v);
} # End of &_SVD()

sub Pythag { my($a, $b) = @_; return sqrt($a*$a + $b*$b); }

sub SIGN { my($a, $b) = @_;  return (($b) >= 0.0 ? abs($a) : -abs($a)); }

sub Max { my($a, $b) = @_; return (($a>$b) ? $a : $b); }

sub Min { my($a, $b) = @_; return (($a<$b) ? $a : $b); }

1;
