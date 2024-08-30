#!/usr/bin/perl -s
package MDS;

	use strict;	use vars;
	use GD;
# Note: to use GD in Windows, you'd better install Perl 5.6, rather than 5.8.

# do not allocate whilte, black, red, and blue, they are reserved.
# for color palate, see http://www.frogtown.com/~lori/rgb.html
# Remark next line on 2019/08/30
#	my(@Color, @ColorNames); # Add ColorNames on 2012/01/15

=head1 NAME

MDS -- A class for MultiDimentional Scaling (MDS) mapping. 

=head1 SYNOPSIS

	use MDS;
	$mds = MDS->new( { 'MDS_INI'=>'MDS.ini' }); # or $mds = MDS->new();
	$mds->SetValue('mds_exe', 'D:\demo\File\L04\bin\mds.exe');
	$mds->SetValue('SimFile', "$IndexPath/SimPairs.txt");
	$mds->SetValue('Coordinate', "$IndexPath/Coordinate.txt");
	$mds->SetValue('Width', 600);
	$mds->SetValue('Height', 450);
	$mds->SetValue('scale', 2); # default is 1, control the distance btn circles
	$mds->SetValue('BaseSize', 600); # default is 600, control the circle size
	$mds->SetValue('AbsSize', 1); # useful to show grow map or evolve map
	$mds->SetValue('TotalDoc', 612); # total number of documents
	# if this number is not given, mds will try to figure it out by itself.
	$mds->SetValue('NoOL', 1); # if you do not want to plot outliers
	$mds->SetValue('fill', 1); # to fill the circle area or not, 1=Yes,0=No
	$mds->SetValue('InitialMap', 'Coordinate.txt'); # to draw the map based on a previous one
	if ($Ocolor) { # if want to map different colors for different clusters
		use Cluster;
		$rDC = Cluster->new( { 'debug'=>$Odebug } );
		$rDC->SetValue('IndexPath', $IndexPath);
		$rDC->ReadTree();
		($rDid2Cid, $rCid2Dids) = $rDC->CutCollection($Ocut);
	}
	$mds->PrintAttributes(); # for debugging
	$mds->mdsmap(2, "$IndexPath/SortedPairs.txt", "$IndexPath/Title.txt",
	"$IndexPath/map_$Ocut.png", $rDid2Cid, $rCid2Dids, $rCid2Cno, $rWanted, $rUnWanted);


=head1 DESCRIPTION

	To generate the comments surrounded by =head and =cut, run
		pod2html MDS.pm > MDS.html
	under MS-DOS.

	Note: After =head and before =cut, there should be a complete blank line
	(only newline is allowed, not any white spaces) for correct formatting.

   MDS can be used to map conceptual objects in high-dimentional space 
	   into visible objects of lower (2 or 3) dimentions.
   Or think in another way, you can use MDS to map a set of objects
	   in a 2-D or 3-D map based on their (dis)similarities.
   Specifically, 
	   Given a set of objects and a 2-D matrix describing their similarities,
	   MDS map these objects in a 2-D (or 3-D) graph such that similar objects 
	   are in close vicinity while dissimilar objects are spread far apart.

Author:

	Yuen-Hsien Tseng.  All rights reserved.

Date:

	2005/08/01

=cut


=head2 Methods

=cut

=head2 $mds=MDS->new( { 'MDS_INI'=>'MDS.ini' })

  The attributes in the object can be set by an INI file (through attribute
	'MDS_INI') or directly given in the constructor''s argumnets in a
	key=>value format. To know the attribute names, consult MDS.ini.

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown above.

 This method return a reference to a no-name hash.

=cut
sub new {
	my($class, $rpara) = @_;
	$class = ref($class) || $class; # ref() return a package name
	my $me = bless( {}, $class ); # same as  $me={}; bless $me, $class;

	$me->{'Width'} = 600; # default is 600
	$me->{'Height'} = 450; # default is 450
	$me->{'scale'} = 1; # default is 1, control the distance btn circles
	$me->{'BaseSize'} = 600; # default is 600, control the circle size
	if (-e $rpara->{MDS_INI}) { # read attributes from file
			$me->ReadINI($rpara->{MDS_INI});
	} else {
# All the above settings can be replaced with the following statement:
		my($k, $v);
		while (($k, $v) = each %$rpara) {
			$me->{$k} = $v;
		}
	}
#	$me->SetAttributes_by_DefaultGroup($group1);
#	$me->SetAttributes_by_DefaultGroup($group2);
	$me->{'IMG'} = new GD::Image($me->{'Width'}, $me->{'Height'});
	my $img = $me->{'IMG'};
# first call to colorAllocate set the background color
	$img->colorAllocate(255, 255, 255); # white, the background color
	my @Color = ( # The color values are copied from the output cmyk2rgb.pl
	  # $img->colorAllocate() return an integer
	  $img->colorAllocate(255, 0, 0), # Red, 
	  $img->colorAllocate(0, 255, 0), # Green
	  $img->colorAllocate(0, 0, 255), # Blue
	  $img->colorAllocate(255, 255, 0), # Yellow
	  $img->colorAllocate(255, 0, 255), # Magenta
	  $img->colorAllocate(0, 255, 255), # Cyan
	  $img->colorAllocate(0, 255, 127), # Emerald
	  $img->colorAllocate(255, 148, 0), # YellowOrange
	  $img->colorAllocate(0, 127, 255), # RoyalBlue
	  $img->colorAllocate(127, 0, 255), # Plum
	  $img->colorAllocate(255, 0, 127), # OrangeRed
	  $img->colorAllocate(127, 255, 0), # LimeGreen
	  $img->colorAllocate(255, 127, 76), # Peach
	  $img->colorAllocate(255, 48, 255), # VioletRed
	  $img->colorAllocate(102, 19, 0), # Brown
	  $img->colorAllocate(219, 148, 112), # Tan
	  $img->colorAllocate(255, 204, 255), # LightMagenta
	  $img->colorAllocate(3, 255, 122), # JungleGreen
	  $img->colorAllocate(217, 255, 79), # GreenYellow
	  $img->colorAllocate(217, 242, 255), # LSkyBlue
	  $img->colorAllocate(0, 0, 0), # Black
	  $img->colorAllocate(255, 229, 41), # Goldenrod
	  $img->colorAllocate(153, 51, 204), # DarkOrchid
	  $img->colorAllocate(255, 138, 127), # Melon
	  $img->colorAllocate(255, 125, 0), # BurntOrange
	  $img->colorAllocate(184, 20, 11), # BrickRed
	  $img->colorAllocate(255, 10, 156), # WildStrawberry
	  $img->colorAllocate(204, 255, 178), # LightGreen
	  $img->colorAllocate(255, 94, 255), # CarnationPink
	  $img->colorAllocate(140, 36, 255), # Purple
	  $img->colorAllocate(255, 99, 33), # Orange
	  $img->colorAllocate(124, 21, 235), # Fuchsia
	  $img->colorAllocate(255, 133, 255), # Lavender
	  $img->colorAllocate(20, 224, 27), # ForestGreen
	  $img->colorAllocate(255, 181, 41), # Dandelion
	  $img->colorAllocate(189, 255, 61), # SpringGreen
	  $img->colorAllocate(255, 173, 122), # Apricot
	  $img->colorAllocate(79, 255, 127), # SeaGreen
	  $img->colorAllocate(140, 39, 0), # RawSienna
	  $img->colorAllocate(224, 105, 255), # Thistle
	  $img->colorAllocate(255, 120, 158), # Salmon
	  $img->colorAllocate(54, 31, 255), # Violet
	  $img->colorAllocate(15, 191, 78), # PineGreen
	  $img->colorAllocate(64, 25, 255), # RoyalPurple
	  $img->colorAllocate(89, 222, 255), # CornflowerBlue
	  $img->colorAllocate(3, 126, 145), # MidnightBlue
	  $img->colorAllocate(15, 117, 255), # NavyBlue
	  $img->colorAllocate(173, 23, 55), # Maroon
	  $img->colorAllocate(15, 227, 255), # Cerulean
	  $img->colorAllocate(10, 255, 255), # ProcessBlue
	  $img->colorAllocate(97, 255, 224), # SkyBlue
	  $img->colorAllocate(38, 255, 204), # Turquoise
	  $img->colorAllocate(194, 48, 0), # Bittersweet
	  $img->colorAllocate(35, 250, 165), # TealBlue
	  $img->colorAllocate(143, 255, 66), # YellowGreen
	  $img->colorAllocate(76, 13, 0), # Sepia
	  $img->colorAllocate(255, 255, 153), # LightYellow
	  $img->colorAllocate(157, 17, 168), # RedViolet
	  $img->colorAllocate(38, 255, 171), # BlueGreen
	  $img->colorAllocate(255, 0, 222), # RubineRed
	  $img->colorAllocate(97, 110, 196), # CadetBlue
	  $img->colorAllocate(255, 204, 178), # LightOrange
	  $img->colorAllocate(55, 153, 8), # OliveGreen
	  $img->colorAllocate(173, 92, 255), # Orchid
	  $img->colorAllocate(204, 255, 255), # LightCyan
	  $img->colorAllocate(166, 25, 22), # Mahogany
	  $img->colorAllocate(204, 204, 255), # LightPurple
	  $img->colorAllocate(255, 255, 127), # Canary
	  $img->colorAllocate(34, 22, 245), # BlueViolet
	  $img->colorAllocate(255, 59, 33), # RedOrange
	  $img->colorAllocate(229, 255, 204), # LFadedGreen
	  $img->colorAllocate(255, 46, 255), # Rhodamine
	  $img->colorAllocate(165, 25, 250), # Mulberry
	  $img->colorAllocate(46, 255, 178), # Aquamarine
	  $img->colorAllocate(255, 217, 242), # Pink
	  $img->colorAllocate(110, 115, 255), # Periwinkle
	  $img->colorAllocate(127, 127, 127), # Gray # the last must be Gray
	);
	$me->{rColor} = \@Color;  # added on 2019/08/30
	my @ColorNames = (  # The color names are copied from the output cmyk2rgb.pl
	  'Red',		#(255, 0, 0)
	  'Green',		#(0, 255, 0)
	  'Blue',		#(0, 0, 255)
	  'Yellow',		#(255, 255, 0)
	  'Magenta',		#(255, 0, 255)
	  'Cyan',		#(0, 255, 255)
	  'Emerald',		#(0, 255, 127)
	  'YellowOrange',		#(255, 148, 0)
	  'RoyalBlue',		#(0, 127, 255)
	  'Plum',		#(127, 0, 255)
	  'OrangeRed',		#(255, 0, 127)
	  'LimeGreen',		#(127, 255, 0)
	  'Peach',		#(255, 127, 76)
	  'VioletRed',		#(255, 48, 255)
	  'Brown',		#(102, 19, 0)
	  'Tan',		#(219, 148, 112)
	  'LightMagenta',		#(255, 204, 255)
	  'JungleGreen',		#(3, 255, 122)
	  'GreenYellow',		#(217, 255, 79)
	  'LSkyBlue',		#(217, 242, 255)
	  'Black',		#(0, 0, 0)
	  'Goldenrod',		#(255, 229, 41)
	  'DarkOrchid',		#(153, 51, 204)
	  'Melon',		#(255, 138, 127)
	  'BurntOrange',		#(255, 125, 0)
	  'BrickRed',		#(184, 20, 11)
	  'WildStrawberry',		#(255, 10, 156)
	  'LightGreen',		#(204, 255, 178)
	  'CarnationPink',		#(255, 94, 255)
	  'Purple',		#(140, 36, 255)
	  'Orange',		#(255, 99, 33)
	  'Fuchsia',		#(124, 21, 235)
	  'Lavender',		#(255, 133, 255)
	  'ForestGreen',		#(20, 224, 27)
	  'Dandelion',		#(255, 181, 41)
	  'SpringGreen',		#(189, 255, 61)
	  'Apricot',		#(255, 173, 122)
	  'SeaGreen',		#(79, 255, 127)
	  'RawSienna',		#(140, 39, 0)
	  'Thistle',		#(224, 105, 255)
	  'Salmon',		#(255, 120, 158)
	  'Violet',		#(54, 31, 255)
	  'PineGreen',		#(15, 191, 78)
	  'RoyalPurple',		#(64, 25, 255)
	  'CornflowerBlue',		#(89, 222, 255)
	  'MidnightBlue',		#(3, 126, 145)
	  'NavyBlue',		#(15, 117, 255)
	  'Maroon',		#(173, 23, 55)
	  'Cerulean',		#(15, 227, 255)
	  'ProcessBlue',		#(10, 255, 255)
	  'SkyBlue',		#(97, 255, 224)
	  'Turquoise',		#(38, 255, 204)
	  'Bittersweet',		#(194, 48, 0)
	  'TealBlue',		#(35, 250, 165)
	  'YellowGreen',		#(143, 255, 66)
	  'Sepia',		#(76, 13, 0)
	  'LightYellow',		#(255, 255, 153)
	  'RedViolet',		#(157, 17, 168)
	  'BlueGreen',		#(38, 255, 171)
	  'RubineRed',		#(255, 0, 222)
	  'CadetBlue',		#(97, 110, 196)
	  'LightOrange',		#(255, 204, 178)
	  'OliveGreen',		#(55, 153, 8)
	  'Orchid',		#(173, 92, 255)
	  'LightCyan',		#(204, 255, 255)
	  'Mahogany',		#(166, 25, 22)
	  'LightPurple',		#(204, 204, 255)
	  'Canary',		#(255, 255, 127)
	  'BlueViolet',		#(34, 22, 245)
	  'RedOrange',		#(255, 59, 33)
	  'LFadedGreen',		#(229, 255, 204)
	  'Rhodamine',		#(255, 46, 255)
	  'Mulberry',		#(165, 25, 250)
	  'Aquamarine',		#(46, 255, 178)
	  'Pink',		#(255, 217, 242)
	  'Periwinkle',		#(110, 115, 255)
	  'Gray',		#(127, 127, 127)
	);
	$me->{rColorNames} = \@ColorNames; # added on 2019/08/30
	return $me;
}


=head2 ReadINI( 'MDS.ini' )

  Read the INI file ('MDS.ini') and set the object''s attributes.
  If you do not specify the MDS.ini in new() method, you can specify 
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


=head2 $pat->SetAttributes_by_DefaultGroup( [group_name] )

  By changing the 'DefaultGroup' attribute (say from 'USPTO' to 'JPO'),
  you may change the corresponding attributes (settings) by this method.

  Return nothing, but has the side effect of setting some values to the
  attributes of the object.

=cut
sub SetAttributes_by_DefaultGroup {
	my($me, $group) = @_; my($k, $v);
	if ($group eq '') { $group = $me->{DefaultGroup}; }
	while (($k, $v) = each %{$me->{Groups}->{ $group }}) {
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
#	while (($k, $v) = each %{$me->{Groups}->{$me->{DefaultGroup}}}) {
# The above line is the same as next line, "->" can be omitted in 2-D case
	while (($k, $v) = each %{$me->{Groups}{$me->{DefaultGroup}}}) {
			print "$k = $v\n\n";
	}
}


=head2 Value() : A generic Set and Get method for all scalar attributes.

  Examples:
	  $me->Value('MaxDocNum', 200); # Set MaxDocNum to 200
	  $n = $me->Value('MaxDocNum'); # get MaxDocNum

  Any scalar attributes should work. That is, 'MaxDocNum' in the above
	can be replaced by, say, 'DefaultGroup', 'MaxAbsSen', etc.
  Other non-scalar attributes should use special Set and Get methods.

=cut
sub Value {
	my($me, $attribute, $value) = @_;
	if ($value ne '') {
		my $old = $me->{$attribute};
		$me->{$attribute} = $value;
		return $old;
	} else {
		return $me->{$attribute};
	}
}

=head2 SetValue() : A generic Set method for all scalar attributes.

  Examples:
	  $me->SetValue('MaxDocNum', 200); # Set MaxDocNum to 200
	  $n = $me->GetValue('MaxDocNum'); # get MaxDocNum

  Any scalar attributes should work. That is, 'MaxDocNum' in the above
	can be replaced by, say, 'DefaultGroup', 'MaxAbsSen', etc.
  Returns old value of the given attribute.
  Other non-scalar attributes should use special Set and Get methods.

=cut
sub SetValue {
	my($me, $attribute, $value) = @_;
	my $old = $me->{$attribute};
	$me->{$attribute} = $value;
	return $old;
}

=head2 GetValue() : A generic Get method for all scalar attributes.

  See SetValue() for examples and explanations.
  To get the value in a hash-typed attribute, a second attribute should 
  be given.
  Example: to get the computed abstracts of a patent, use
	 $obj->SetValue('Title', $title_string); # title string is a must
	 $obj->SetValue('MaxAbsSen', 3); # default is 3

=cut
sub GetValue {
	my($me, $attribute, $attr2) = @_;
	if ($attr2 eq '') {
		return $me->{$attribute}
	}
	return $me->{$attribute}{$attr2};
}

=head2 Main methods

=head2 $mds->mdsmap($dim, $SortedFile, $TitleFile, $OutPNGFile, $rDid2Cid, $rCid2Dids, $rCid2Cno, $rWanted, $rUnWanted)

  Input/output:
	$dim : number of dimensions, usually 2
	$SortedFile : SortedPairs.txt resulted from cluster.pm
	$TitleFile : Title.txt resulted from cluster.pm
	$OutPNGFile : file to hold the mapping result
	For $rDid2Cid, $rCid2Dids, $rCid2Cno, $rWanted, $rUnWanted, 
	  please check &ConstructMaps() in Term_Trend.pl
  Note: Before calling this method, you should set the attributes:
	mds_exe = D:\demo\File\L04\bin\mds.exe
	SimFile : the input file required by mds.exe
	Coordinate : the output file required by mds.exe
	Width : a 2-D map's Width
	Height : a 2-D map's Height
	scale : scale (down or up) of the distance among the cluster
  by using SetValue() method such as:
	$mds->SetValue('mds_exe', 'D:\demo\File\L04\bin\mds.exe');
	$mds->SetValue('SimFile', 'Result\NSC_DocCluster\SimPairs.txt');
	$mds->SetValue('Coordinate', 'Result\NSC_DocCluster\Coordinate.txt');
	$mds->SetValue('Width', 600); # default is 600
	$mds->SetValue('Height', 450); # default is 450
	$mds->SetValue('scale', 1); # default is 1

Step 1.
  Given a file of sorted pairs resulted from cluster.pm, 
	Convert the sorted pairs into the format required by mds.exe.
Step 2.
  Given a matrix containing the similarities between objects,
	and the desired reduced dimensions (such as 2 or 3),
	output the coordinates of these objects in the 2-D or 3-D map.
Step3. 
  From the output of mds, create a 2-d map.

=cut
# Currently this function uses the mds program from http://www.let.rug.nl/~kleiweg/indexs.html
sub mdsmap {
	my($me, $dim, $SortedFile, $TitleFile, $OutPNGFile, 
		$rDid2Cid, $rCid2Dids, $rCid2Cno, $rWanted, $rUnWanted) = @_;
	my($cmd, $rTitle, $rOld2NewID);
# 1. Read $SortedFile, $TitleFile, write $SimFile
# 2024/07/28 不要再使用 -Owant 與 -Ounwant 這兩個選項了，程式可能會有錯誤
	($rTitle, $rOld2NewID) = $me->ConvertSimFile($SortedFile, $TitleFile, 
		$me->{'SimFile'}, $rDid2Cid, $rCid2Dids, $rCid2Cno, $rWanted, $rUnWanted);

# 2. call mds
	if (-f $me->{'InitialMap'}) {
# mds [-K | -S] [-i filename] [-o filename] dimensions  difference-table-file 
#=comment
		$cmd = $me->{'mds_exe'} . " -i " . $me->{'InitialMap'}
			. " -K $dim " . $me->{'SimFile'} 
			. " > " . $me->{'Coordinate'};
#=cut
=comment
		$cmd = $me->{'mds_exe'} . " $dim " . $me->{'SimFile'} 
			. " > " . $me->{'Coordinate'} . '_tmp.txt';
		print STDERR "$cmd\n";
		system($cmd);
		$cmd = $me->{'mds_exe'} . " -i " . $me->{'Coordinate'} 
			. '_tmp.txt' . " -K $dim " . $me->{'SimFile'} 
			. " > " . $me->{'Coordinate'};
=cut
	} else {
		$cmd = $me->{'mds_exe'} . " $dim " . $me->{'SimFile'} 
			. " > " . $me->{'Coordinate'};
	}
	print STDERR "$cmd\n";
	system($cmd) == 0  or die "'$cmd' failed: $?\n";
# 3. read back the output for create the map
	my($did, $cid, %Did2Cid);
	while (($did, $cid) = each %$rDid2Cid) # 2009/03/07
		{ $Did2Cid{ $rOld2NewID->{$did} } = $cid; }
	# %Did2Cid is a new version of $rDid2Cid
	# @$rTitle is a new version of Title.txt
	$me->CreateMap($me->{'Coordinate'}, $rTitle, $OutPNGFile, 
		\%Did2Cid, $rOld2NewID, $rCid2Cno);
}

=head2 $mds->ConvertSimFile()

Read $SortedFile, $TitleFile, write $SimFile.
# 2024/07/28 不要再使用 -Owant 與 -Ounwant 這兩個選項了，程式可能會有錯誤
Return @Title from Title.txt. @Title is a reduced version of Title.txt
	if $main:Owant (%$rWanted) or $main::Ounwant (%$rWanted) are used.
Return %Old2NewID: Old line number id (from 0) in Title.txt 
	to new line number id (from 0) in @Title
	if $main:Owant (%$rWanted) or $main::Ounwant (%$rWanted) are used.

=cut
sub ConvertSimFile {
	my($me, $SortedFile, $TitleFile, $SimFile,  
		$rDid2Cid, $rCid2Dids, $rCid2Cno, $rWanted, $rUnWanted) = @_;
# 2024/07/28 不要再使用 -Owant 與 -Ounwant 這兩個選項了，程式可能會有錯誤
	my($n, $i, $j, $x, $y, $sim, @Title, @M, $t, $TotalDoc);
	my($unwanted, $wanted, $ti, $cid, %Old2NewID, %NewID2Cid);

	$i = $j = -1; $unwanted = keys %$rUnWanted;  $wanted = keys %$rWanted;
#print "UnWant=", join(", ", sort keys %$rUnWanted), "\n";
	open F, $TitleFile or die "Cannot read file:'$TitleFile', $!";
#	@Title = <F>; #chomp @Title;
#	pop @Title if $Title[$#Title] =~ /^\s*$/; # pop out empty line
	while ($ti=<F>) { # 2009/3/07 use this while to replace the above 2 lines
		# 2009/03/07 # remove those unwanted clusters
		# 2009/03/07 # or reserve those wanted clusters
		next if $ti =~ /^\s*$/; # skip if empty line
		$j++; $cid = (split/ : /, $ti)[0];
		next if $unwanted and $rUnWanted->{$cid};
		next if $wanted and not $rWanted->{$cid};
		push @Title, $ti; 
		$i++;                  # $i is new line number (from 0) in @Title
		$Old2NewID{$j} = $i;   # $j is original line number (from 0) in Title.txt
		$NewID2Cid{$i} = $cid; # $i to original $cid in Title.txt
	}
	close(F);

	foreach $t (@Title) {
#		if ($t =~ /^(\d+) : (\d+)筆/) { # the node title : "53 : 4筆,0.13(sens:0.43, sensor:0.32, structure:0.15)"
		if ($t =~ /^(\d+) : (\d+) Docs./) { # the node title : "53 : 4筆,0.13(sens:0.43, sensor:0.32, structure:0.15)"
			$TotalDoc += $2; 
		} else {  $TotalDoc ++;  }
	}
	if ($TotalDoc > 0) { # set attribute TotalDoc, BaseSize for later use
		$me->{'TotalDoc'} = $TotalDoc;
#		$me->{'BaseSize'} = $TotalDoc if $me->{BaseSize} > $TotalDoc;
	}

	open F, $SortedFile or die "Cannot read file:'$SortedFile', $!";
	while (<F>) {
		chomp; next if /^\s*$/; # skip empty line
		($i, $j, $sim) = split ' ', $_; # index is already from 0
#print "\$Old2NewID{$i}=$Old2NewID{$i}=>$NewID2Cid{ $Old2NewID{$i} }, \$Old2NewID{$j}=$Old2NewID{$j}=>$NewID2Cid{ $Old2NewID{$j} }\n"; 
	# 2009/03/07 only output those wanted pairs
		$cid = $NewID2Cid{ $Old2NewID{$i} };
		next if $unwanted and ($cid eq '' or $rUnWanted->{$cid});
		next if $wanted and ($cid eq '' or not $rWanted->{$cid});
		$cid = $NewID2Cid{ $Old2NewID{$j} };
		next if $unwanted and ($cid eq '' or $rUnWanted->{$cid});
		next if $wanted and ($cid eq '' or not $rWanted->{$cid});
#print " \$Old2NewID{$i}=$Old2NewID{$i}=>$NewID2Cid{ $Old2NewID{$i} }, \$Old2NewID{$j}=$Old2NewID{$j}=>$NewID2Cid{ $Old2NewID{$j} }\n"; 
#		($x, $y) = sort {$b <=> $a} ($i, $j); # 2009/03/07
		($x, $y) = sort {$b <=> $a} ($Old2NewID{$i}, $Old2NewID{$j} );
		$M[$x][$y] = $sim; # only lower triangle is needed.
	}
	close(F);

	open FF, ">$SimFile" or die "Cannot write to file:'$SimFile', $!";	
	$n = (scalar @Title);
	print FF "$n\n", @Title;
	for ($i=1; $i<$n; $i++) {
		for ($j=0; $j<$i; $j++) {
			if ($M[$i][$j] eq '') {
				print FF "1.0\n"; # mds require difference, instead of similarity
			} else {
				print FF (1-$M[$i][$j]), "\n";
#				print FF (1-sqrt($M[$i][$j])), "\n"; # no better, 2011/04/19
			}
#print "M[$i][$j]='$M[$i][$j]'=>", (1-$M[$i][$j]),"\n"
		}
	}
	close(FF);

# on 2024/08/30 needed by Lai Kui-Kui 
	my $IndexPath = '';
	if ($SortedFile =~ /^(.+)\/[^\/\\]+/) { $IndexPath = $1 }
    my $SquareMatrix = $IndexPath . '/Square_Maxtrix.txt';
print(STDERR "  SquareMatrix=$SquareMatrix\n");
	open SF, ">$SquareMatrix" or die "Cannot write to file:'$SquareMatrix', $!";	
	$n = (scalar @Title);
	print FF "$n\n", @Title;
	for ($i=0; $i<$n; $i++) {
		for ($j=0; $j<$n; $j++) {
			if ($i == $j) { print("1.0\t"); next; }
			if ($M[$i][$j] eq '') {
				print SF "0.0\t"; # mds require difference, instead of similarity
			} else {
				print SF "$M[$i][$j]\t";
			}
		}
		print SF "\n";
	}
	close(SF);

# This function may have bugs if $main::Owant or $main::Ounwant are used,
	$me->CreateDendrogram(\@Title, \@M, $rDid2Cid, $rCid2Dids);
	return (\@Title, \%Old2NewID);
}

# On 2019/08/31:
# This function may have bugs if $main::Owant or $main::Ounwant are used,
#   because $rDid2Cid, $rCid2Dids are not adjusted.
sub CreateDendrogram {
	my($me, $rTitle, $rM, $rDid2Cid, $rCid2Dids) = @_;
	my($did, $cid, %Cid2Ndoc, @Cids);
	while (($did, $cid) = each %$rDid2Cid) { 
		$Cid2Ndoc{$cid}++; # replace above line on 2019/08/31
#print "$cid : $did=>",(split / : /, $rTitle->[$did])[0],"\n";
	}
	# %Cid2Ndoc: number of of sub-clusters in cluster Cid
	@Cids = sort {$Cid2Ndoc{$b} <=> $Cid2Ndoc{$a}} keys %Cid2Ndoc;
	my($i, $DFi, $BDFi, $DocNameCi, @DocNameCi, $DisPairCi, @DisPairCi);
	my($CallCi, $DivCi, $CanvasCi);
	my($name, $pair, $numLeaves, $HTML);
	for($i=0; $i<@Cids; $i++) {
    	($name, $pair, $numLeaves) = $me->GetOneTree($rTitle, $rM, $rCid2Dids, $Cids[$i]);
    	push @DocNameCi, $name;
		push @DisPairCi, $pair;
    	$CallCi .= <<End_Here;
    treeObj=buildTree($numLeaves, $i); 
    tree=treeObj.tree;
    root=treeObj.root;
    names=treeObj.names; 
    drawDendrogram(tree, root, names, 'df$i', 300); // Editable tree width
//  drawDendrogram(tree, root, names, 'df$i', 400); // this would yield wider tree
    drawBezierDendrogram(tree,root,names,'bdf$i',true,true);

End_Here
    	$DFi .= "#df".$i."{\n    position:relative;\n    margin:0 0 0 36px;\n"
    		. "    font-size:75%;\n    border:0px solid white;\n    }\n";
    	$BDFi .= "#bdf".$i."{\n    margin:10px 0 10px 36px;\n}\n";
    	$DivCi .= '<div style="position: relative; width: 800px; height: 600px;" id="df'.$i.'"></div>'."\n";
    	$CanvasCi .= '<canvas height="600" width="800" id="bdf'.$i.'"></canvas>'."\n";
	}
	$DocNameCi = join(",\n\n", map{"[\n$_\n]"} @DocNameCi) . "\n";
	$DisPairCi = join(",\n\n", map{"[\n$_\n]"} @DisPairCi) . "\n";
# Now replace the varialbes in HTML
	open F, $me->{dendrogramTemplate} or die "Cannot read file:'$me->{dendrogramTemplate}'";
	local $/; undef $/; $HTML = <F>;
	close(F);
	$HTML =~ s|/\* __DFi \*/|$DFi/* __DFi */|;
	$HTML =~ s|/\* __BDFi \*/|$BDFi/* __BDFi */|;
	$HTML =~ s|   // __DocName_List_in_Cluster_i|$DocNameCi   // __DocName_List_in_Cluster_i|;
	$HTML =~ s|   // __DistancePair_List_in_Cluster_i|$DisPairCi   // __DistancePair_List_in_Cluster_i|;
	$HTML =~ s|/\* __Call_to_Draw_Tree \*/|$CallCi/* __Call_to_Draw_Tree */|;
	$HTML =~ s|<!-- __DIV_df -->|$DivCi<!-- __DIV_df -->|;
	$HTML =~ s|<!-- __CANVAS_bdf -->|$CanvasCi<!-- __CANVAS_bdf -->|;
	open F, ">".$me->{dendrogramOut} or die "Cannot write to file:'$me->{dendrogramOut}'";
	print F $HTML; close(F);
}

sub GetOneTree {
	my($me, $rTitle, $rM, $rCid2Dids, $cid) = @_;
	my(@Dids, %Dids, $did, $ti, $idx, @Idx);
	@Dids = split /\t/, $rCid2Dids->{$cid};
# $rTitle->[$did] in the next line should be the whole titles in Title.txt
#   to remove the bugs if $main::Owant or $main::Ounwant are used.
	foreach $did (@Dids) { $Dids{(split / : /, $rTitle->[$did])[0]} = 1; }
	$idx = -1; # remove those not in @$rTitle (reduced Title.txt) 
	foreach $ti (@$rTitle) { 
		$idx++;
		$did = (split/ : /, $ti)[0];
		push @Idx, $idx if $Dids{$did};
	}
# Now we have @Idx to point to @$rTitle to know which nodes are in the cluster i
	my($i, $j, $x, $y, @NodeNames, @Distances, $nid, $nsize, $nsim);
	for ($i=0; $i<@Idx; $i++) {
		$ti = $rTitle->[$Idx[$i]];
		chomp($ti); # chop off the last newline character(s)
		($nid, $nsize, $nsim, $ti) = $me->GetNodeLabel($ti);
		push @NodeNames, $ti;
	}
	for ($i=1; $i<@Idx; $i++) {
		$x = $Idx[$i];
		for ($j=0; $j<$i; $j++) {
			$y = $Idx[$j];
			if ($rM->[$x][$y] eq '') {
				push @Distances, "1.0"; # dendrogram requires difference, instead of similarity
			} else {
				push @Distances, (1-$rM->[$x][$y]);
			}
		}
	}
	return (join(",\n", map {"'$_'"} @NodeNames),
		join(",\n", @Distances), scalar @NodeNames);
}

sub GetNodeLabel {
	my($me, $ti) = @_; 
	my($id, $size, $sim, $label, @Label, $des, $J9);
# Get a label from $ti, where $ti may have the following format:
# 24 : 172 Docs. : 1.0(ASLIB PROC: 1.0, ASLIB PROCEEDINGS: 1.0)
# 1647 : 4376 Docs. : 0.001046(library:414.3054, information:104.5307, academic:86.8283, retrieval:85.9621, literacy:72.7760)
    if ($ti=~/(\d+) : (\d+)[^:]+ : ([\d\.]+)\(([^\)]+)\)/) {
    	$id = $1; $size = $2; $sim = $3; $des = $4;
    	if ($des =~ / 1.0\b/) { $J9 = 1; } else { $J9 = 0; } # to be checked
    	while ($des =~ /([^:]+):\s*[\d\.]+,?\s*/g) { # may cause bug for Chinese
    		$label = $1; # match the one before ":414.3054" or ": 1.0"
    		push @Label, $label;
    	}
    	if ($J9) {
    		$label = $Label[0];
    		$me->{L1toLabel}->{$label} = join("; ", @Label[1..$#Label]);
    	} else { 
    		$label = join("; ", @Label); 
    		$me->{L1toLabel}->{$label} = $ti;
    	}
# ISI:000272846500049 : 2010:Generic title labeling for clustered documents
    } elsif ($ti=~/ : (\d+:.+)$/) {
    	$id = ++$me->{LabelID}; $size = 1; $sim = 1.0; $label = $1;
    }
#print STDERR "ti=$ti\n$id, $size, $sim, $label\n";
	return ($id, $size, $sim, $label);
}



=head2 $mds->CreateMap()

	Given an MDS result (file), a label file with the size of each label,
	the group name of each lable, plot the MDS result in a map.
	
	Note: Before calling this method, you should set the attributes:
	  Width : Width of a 2-d map
	  Height : Height of a 2-d map
	  scale : scale (down or up) of the distance among the cluster

=cut
sub CreateMap {
	my($me, $CoordinateFile, $rTitle, $OutPNGFile, $rDid2Cid, $rOld2NewID, $rCid2Cno) = @_;
# @$rTitle is an array to hold the title of each document
	my($dim, $dn, $rx, $ry, $cx, $cy, $label, $title, $tn, $xn, $yn, $tm);
	my($img, $white, $black, $red, $blue, $gray55, $rDid2Color, $did, $color);
	$img = $me->{'IMG'};
	# allocate some colors
	$white = $img->colorAllocate(255,255,255);
	$black = $img->colorAllocate(0,0,0);	   
	$red = $img->colorAllocate(255,0,0);	  
	$gray55 = $img->colorAllocate(140, 140, 140); # $gray55==81

	$me->{'OutlierColor'} = $gray55; # 2007/05/09
#	$blue = $img->colorAllocate(0,0,255); # already has been used
	$rDid2Color = $me->AllocateColor($img, $rDid2Cid, $rCid2Cno);
	# make the background transparent and interlaced
	$img->transparent($white);
	$img->interlaced('true');
#	$img->interlaced('false');

# $dn : indicator of reading x axis or y axis
# $xn : number of x coordinates read
# $yn : number of y coordinates read
# $tn : number of title (circles) read
# $tm : number of possibly extra title (circles) read
	$tn = 0; $tm = 0; $dn = 0;
	$did = 0; # cluster sequence number in Coordinate.txt
# Assume the node (title) sequence in Coordinate.txt is the same as that in Title.txt
	open F, $CoordinateFile or die "Cannot read file:'$CoordinateFile', $!";
	my($rPajekNodes); 
	$me->{LabelID} = 0; # Set to zero for later use
	while (<F>) { # read the file containing x and y coordinates
		chomp;
		next if /^#|^\s*$/g; # skip if comment or empty line
		if (/^(\d+)$/) { # number of coordinates
			$dim = $1;
# 34 : 6 Docs. : 0.020000(cluster:5.1121, min:3.0151, map:3.0151, text:2.0833)
# -0.31321413
# -0.05544575
		} elsif (/^(\d+) : (\d+) Docs./) { # the node title : "53 : 4 Docs. : 0.13(sens:0.43, sensor:0.32, structure:0.15)"
			$title = $_; $label = "$1:$2";
			$tn++; # must be here before the next line
			$label = "$tn:$2" if $me->{'Cid2Cno'};
# on 2024/07/28, overwrite the above line:
            $label = $rCid2Cno->{$1} . ":$2" if $me->{'Cid2Cno'};
			$dn = 0; # reset dn to x axis
		} elsif (/([^ ]+)\s+:\s+(.+)/) { # /6969912 : Embedded.../ or /ISI:000167255500002 : 2001:Automatic cataloguing/
			$title = $_; $label = $2;
			$tn++; # must be here before the next line
			$label = "$tn:$2" if $me->{'Cid2Cno'};
# on 2024/07/28, 上面一行可能會有錯誤
#		} elsif (/^(\d+) : \d+/) {
#			$label = "$1:10"; 
#		} elsif (/^([\- ][01]\.\d+)$/) { # read in X or Y, depending on $dn
		} elsif (/^([\- ]\d+\.\d+e?-?\d*)$/) { # read in X or Y, depending on $dn
			if ($dn == 0) { 
				$rx = $1; $dn = 1; $xn++;
			} else { 
				$ry = $1; $dn = 0; $yn++;
	# Assume we have only 2-dimensions: X- and Y-axis, now call:
				$color = $rDid2Color->{$did};
#warn("Did2Cid->{$did}=$rDid2Cid->{$did}, Did2Color{$did}=$rDid2Color->{$did}, label=$label, gray55=$gray55\n"
#	. "  title=$title\n");
				if ($color eq '') { $color = $gray55; }
				$rPajekNodes = $me->PlotOne($img, $rx, $ry, 10, $color, $label, $title, $red, 
					$rCid2Cno, $rDid2Cid, $rPajekNodes); 
				# @$rPajekNodes contain each row for a Pajek file
				$did++; # Remark on 2019/08/30
			}
		} else {
#		warn "no match : $_\n"; 
			$tn++; $tm++;
#		$title = ":1";
		}
	}
	close(F);	
	# convert into png data
	open FF, ">$OutPNGFile" or die "Cannot write to file:'$OutPNGFile', $!";
	binmode(FF);
	print FF $img->png;
	print STDERR "Number of title: $tn, extra title: $tm, coordinates: ($xn, $yn)\n";

# Write to files in Pajek format and in VOSviewer format # 2012/01/15
	my ($nid, $nlabel, $x, $y, $size, $ic, $MaxSize, $r);
	my (@Rows, %Rows, $vos); 
	$MaxSize = 0;	@Rows = split /\n/, $rPajekNodes;
	foreach $r (@Rows) {
		($nid, $nlabel, $x, $y, $size, $ic, $color) = split /\t/, $r;
		$MaxSize = $size if $MaxSize < $size; 
		$Rows{$nid} = $r;
	} 
	$rPajekNodes =''; # reset $rPajekNodes
	foreach $r (sort {$a <=> $b} keys %Rows) { # Vertex ID should start from 1 for Pajek
		($nid, $nlabel, $x, $y, $size, $ic, $color) = split /\t/, $Rows{$r};
		$size = sprintf("%1.4f", 5*$size/$MaxSize); # size should between 0-5 
#		$rPajekNodes .= "$nid\t$nlabel\t$cx\t$cy\tx_fact\t$size\ty_fact\t$size\t$ic\t$color\n";
# Tab-delimited definition is not accepted by Pajek
		$cx = ($x+1)/2; # convert to position x in [0..1]  (between 0 and 1) 
		$cy = ($y+1)/2; # convert to position y in [0..1]  (between 0 and 1) 
# For Pajek format, see: http://www.educa.fmf.uni-lj.si/datana/pub/networks/pajek/draweps.htm
#		$rPajekNodes .= "$nid \"$nlabel\" $cx $cy x_fact $size y_fact $size $ic $ColorNames[$color]\n";
		$rPajekNodes .= "$nid \"$nlabel\" $cx $cy x_fact $size y_fact $size $ic $me->{rColorNames}[$color]\n";
		$vos .= "$nid, \"$nlabel\", \"$me->{L1toLabel}{$nlabel}\", $x, $y, $size, $color\n";
	}
	open P, ">".$me->{PajekFile} or die "Cannot write to file:'$me->{PajekFile}'";
	print P "*Vertices ", (scalar (split/\n/, $rPajekNodes)), "\n$rPajekNodes";
	close(P);

	open P, ">".$me->{VOSFile} or die "Cannot write to file:'$me->{VOSFile}'";
	print P "id, label, description, x, y, weight, cluster\n$vos";
	close(P);
}

sub AllocateColor {
	my($me, $img, $rDid2Cid, $rCid2Cno) = @_; 
	my(%Cid2Color, %Did2Color, $did, $cid, $cno);
	while (($did, $cid) = each %$rDid2Cid) {
		# on 2024/07/28 將下一行註解起來，因為$rCid2Cno內容有變 
#		$cid = $cno = $rCid2Cno->{$cid} if $me->{'Cid2Cno'};
		$Cid2Color{$cid} = $me->{rColor}[($cid % scalar @{$me->{rColor}})];
		$Did2Color{$did} = $Cid2Color{$cid};
#warn("did=$did, cid=$cid, cno=$cno, color=$Cid2Color{$cid}\n");
	}
	return \%Did2Color;
}


sub PlotOne {
	my($me, $img, $rx, $ry, $size, $color, $label, $title, $LabelColor, 
		$rCid2Cno, $rDid2Cid, $rPajekNodes) = @_;
	my($Height, $Width) = ($me->{'Height'}, $me->{'Width'});
	my($cx, $cy, $scale, $BaseSize, $TotalDoc);
	$scale = $me->{'scale'};
	$TotalDoc = $me->{'TotalDoc'};
	$BaseSize = $me->{'BaseSize'}; 
	if ($scale>0) {
		$rx = $rx * $scale; # position x in [-1..1]
		$ry = $ry * $scale; # position y in [-1..1]
	}
	$cx = int(($rx+1)/2 * $Width); # convert to position x in Width(=640) pixels
	$cy = int(($ry+1)/2 * $Height); # convert to position y in Height(=450) pixels
	# Draw a blue oval
	if ($label =~ /:(\d+)/) { # format 
		$label = $`; # cluster id number, match the precedent of pattern
		$size = $1;
		if ($size > 0) {
			if ($TotalDoc > 0 and not $me->{'AbsSize'}) { # relative size
			# total number of documents is given or calculable
				$size = int(10 * sqrt($1/$TotalDoc * $BaseSize));
			} else { # absolutte size
				$size = int(10 * sqrt($1)); 
			}
		}
	}
	$size = 3 if $size == 0;
	return if ($color eq $me->{'OutlierColor'} and $me->{'NoOL'}); # 2007/05/09
	if ($color eq $me->{'OutlierColor'}) {
		return if $me->{'NoOL'}; # 2008/04/30
# Set a style consisting of 2 pixels of $color and a 16 pixel gap
		$img->setStyle($color,$color,gdTransparent,gdTransparent,
		gdTransparent,gdTransparent,gdTransparent,gdTransparent,
		gdTransparent,gdTransparent,gdTransparent,gdTransparent,
		gdTransparent,gdTransparent,gdTransparent,gdTransparent,
		gdTransparent,gdTransparent);
		$img->arc($cx,$cy,$size,$size,0,360,gdStyled);
	} else {
		$img->setStyle($color);
		$img->arc($cx,$cy,$size,$size,0,360,gdStyled);
		$img->arc($cx,$cy,$size-1,$size-1,0,360,gdStyled);
		$img->arc($cx,$cy,$size+1,$size+1,0,360,gdStyled);
	}
#	$img->arc($cx,$cy,$size,$size,0,360,$color);
#	$img->arc($cx,$cy,$size-1,$size-1,0,360,$color);
#	$img->arc($cx,$cy,$size+1,$size+1,0,360,$color);
	if ($me->{'fill'}) { $img->fill($cx,$cy,$color); }
	if ($label ne '') {
		$img->string(gdSmallFont,$cx-5,$cy-5,$label,$LabelColor);
	}
#warn("label=$label, color=$color\n");
	# And fill it with red
#	$img->fill(50,50,$red);
#	$img->line(50, 50, 25, 35, $red);

# Now we have rx, ry, size, color, and title, we can output a Pajek format file
	my($nid, $nsize, $nsim, $ti);
	($nid, $nsize, $nsim, $ti) = $me->GetNodeLabel($title);
	$rPajekNodes .= "$nid\t$ti\t$rx\t$ry\t$size\tic\t$color\n";
	return $rPajekNodes;
=comment
	# draw a circle
#	$img->moveTo(110,100);
	$img->bgcolor(undef);
	$img->fgcolor($color);
	$img->ellipse($cx, $cy, $size, $size); # x, y, width, and height

$img->ellipse($cx,$cy,$width,$height)
	This method draws the ellipse defined by center ($cx,$cy), width $width and 
	height $height. The ellipse''s border is drawn in the foreground color and 
	its contents are filled with the background color. To draw a solid ellipse 
	set bgcolor equal to fgcolor. To draw an unfilled ellipse (transparent 
	inside), set bgcolor to undef. 

$img->string($string)
	This method draws the indicated string starting at the current position of 
	the pen. The pen is not moved. Depending on the font selected with the 
	font() method, this will use either a bitmapped GD font or a TrueType font. 
	The angle of the pen will be consulted when drawing the text. For TrueType 
	fonts, any angle is accepted. For GD bitmapped fonts, the angle can be 
	either 0 (draw horizontal) or -90 (draw upwards). 

	For consistency between the TrueType and GD font behavior, the string is 
	always drawn so that the current position of the pen corresponds to the 
	bottom left of the first character of the text. This is different from the 
	GD behavior, in which the first character of bitmapped fonts hangs down from 
	the pen point.

	When rendering TrueType, this method returns an array indicating the 
	bounding box of the rendered text. If an error occurred (such as invalid 
	font specification) it returns an empty list and an error message in $@.

($x,$y) = $img->curPos
	Return the current position of the pen. Set the current position using 
	moveTo(). 

	if ($label ne '') {
	$img->moveTo($cx, $cy);
	$img->font('Times:italic');
	$img->fontsize(20);
	$img->angle(-90); # times italic, angled upward 90 degrees
	$img->string($label);
	}	
=cut

}


=head2 Auxiliary methods

=head2 $DateString = FormatDate($year, $month, $date)

  Given $year, $month, and $date, return a formatted date string for saving.
  EX: return "2003/11/02" if (2003, 11, 2) is given.
	return "9999/01/01" if $year eq '';
	return "$year/01/01" if $month eq '';
	return "$year/$month/01" if $date eq '';
	return "$year/$month/$date"; # year/month/date

=cut
sub FormatDate {
	my($me, $year, $month, $date) = @_;
	return "9999/01/01" if $year eq '';
	return "$year/01/01" if $month eq '';
	return "$year/$month/01" if $date eq '';
	return "$year/$month/$date"; # year/month/date
}


=head $month_num = Month( 'January' )

  Given an English month name, return the digital month name.
  Ex: 'Jan'=>'01', 'Dec'=>'12'.

=cut
sub Month {
	my($me, $mon) = @_;
	my %Month = ('Jan'=>'01', 'Feb'=>'02', 'Mar'=>'03', 'Apr'=>'04',
				  'May'=>'05', 'Jun'=>'06', 'Jul'=>'07', 'Aug'=>'08',
				  'Sep'=>'09', 'Oct'=>'10', 'Nov'=>'11', 'Dec'=>'12');
	return $Month{substr($mon, 0, 3)};
}

=head2 ReportError($msg)

  Report error message. You may inherit the method
  and overload it if your different output devise is used (default STDERR).

=cut
sub ReportError {
	my($me, $msg) = @_;
	print STDERR "$msg\n";
}


1;