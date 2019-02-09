#!/usr/bin/env perl
# Written by Sam Tseng on 2012/01/15
# The cymk2rgb perl code is from http://www.perlmonks.org/?node_id=222409
#

use strict;
use warnings;
# my @cmyk = qw(0 128 255 127 ); # some test data
# my @rgb = cmyk2rgb(@cmyk); # convert
# foreach (0..2){  print "$_ $rgb[$_]\n"; } # result

# The color names is from the eps file exported from Pajek as suggested by:
#    http://list.fmf.uni-lj.si/pipermail/pajek/2008-December/000256.html
# These color can be seen at:
#    http://vlado.fmf.uni-lj.si/pub/networks/pajek/doc/crayola.pdf
my @Color = qw( 
Red           0    1    1    0    
Green         1    0    1    0    
Blue          1    1    0    0    
Yellow        0    0    1    0    
Magenta       0    1    0    0    
Cyan          1    0    0    0    
Emerald       1    0    0.50 0    
YellowOrange  0    0.42 1    0    
RoyalBlue     1    0.50 0    0    
Plum          0.50 1    0    0    
OrangeRed     0    1    0.50 0    
LimeGreen     0.50 0    1    0    
Peach         0    0.50 0.70 0    
VioletRed     0    0.81 0    0    
Brown         0 0.81    1    0.60 
Tan           0.14 0.42 0.56 0    
LightMagenta  0    0.2  0    0    
JungleGreen   0.99 0    0.52 0    
GreenYellow   0.15 0    0.69 0    
LSkyBlue      0.15 0.05 0    0    
Black         0    0    0    1    
Goldenrod     0    0.10 0.84 0    
DarkOrchid    0.40 0.80 0.20 0    
Melon         0    0.46 0.50 0    
BurntOrange   0    0.51 1    0    
BrickRed      0    0.89 0.94 0.28 
WildStrawberry 0    0.96 0.39 0    
LightGreen    0.2  0    0.3  0    
CarnationPink 0    0.63 0    0    
Purple        0.45 0.86 0    0    
Orange        0    0.61 0.87 0    
Fuchsia       0.47 0.91 0    0.08 
Lavender      0    0.48 0    0    
ForestGreen   0.91 0    0.88 0.12 
Dandelion     0    0.29 0.84 0    
SpringGreen   0.26 0    0.76 0    
Apricot       0    0.32 0.52 0    
SeaGreen      0.69 0    0.50 0    
RawSienna     0 0.72    1    0.45 
Thistle       0.12 0.59 0    0    
Salmon        0    0.53 0.38 0    
Violet        0.79 0.88 0    0    
PineGreen     0.92 0    0.59 0.25 
RoyalPurple   0.75 0.90 0    0    
CornflowerBlue 0.65 0.13 0    0    
MidnightBlue  0.98 0.13 0    0.43 
NavyBlue      0.94 0.54 0    0    
Maroon        0    0.87 0.68 0.32 
Cerulean      0.94 0.11 0    0    
ProcessBlue   0.96 0    0    0    
SkyBlue       0.62 0    0.12 0    
Turquoise     0.85 0    0.20 0    
Bittersweet   0    0.75 1    0.24 
TealBlue      0.86 0    0.34 0.02 
YellowGreen   0.44 0    0.74 0    
Sepia         0 0.83    1    0.70 
LightYellow   0    0    0.4  0    
RedViolet     0.07 0.90 0    0.34 
BlueGreen     0.85 0    0.33 0    
RubineRed     0    1    0.13 0    
CadetBlue     0.62 0.57 0.23 0    
LightOrange   0    0.2  0.3  0    
OliveGreen    0.64 0    0.95 0.40 
Orchid        0.32 0.64 0    0    
LightCyan     0.2  0    0    0    
Mahogany      0    0.85 0.87 0.35 
LightPurple   0.2  0.2  0    0    
Canary        0    0    0.50 0    
BlueViolet    0.86 0.91 0    0.04 
RedOrange     0    0.77 0.87 0    
LFadedGreen   0.10 0    0.20 0    
Rhodamine     0    0.82 0    0    
Mulberry      0.34 0.90 0    0.02 
Aquamarine    0.82 0    0.30 0    
Pink          0    0.15 0.05 0    
Periwinkle    0.57 0.55 0    0    
Gray          0    0    0    0.50 
);


my($i, $name, @CMYK, @RGB);
for ($i=0; $i<@Color; $i+=5) {
	$name = $Color[$i];
	@CMYK = @Color[($i+1)..($i+4)];
#	print join(", ", @CMYK), " => ";
	@RGB = &cmyk2rgb(@CMYK);
###	output format: $img->colorAllocate(  0,   0, 255), # blue
	print '  $img->colorAllocate(', join(", ", @RGB), "),\t# $name\n";
### output format:  'Blue'           ,# (  0,   0, 255),
#	print "  '$name',\t\t#(", join(", ", @RGB), ")\n";
}


# Using the formulae from the page zigdon suggested by
#    http://adaptiveview.com/cw/doc5a.html
# red   = 255 - minimum(255,((cyan/255)    * (255 - black) + black))
# green = 255 - minimum(255,((magenta/255) * (255 - black) + black))
# blue  = 255 - minimum(255,((yellow/255)  * (255 - black) + black))
sub cmyk2rgb {
  my (@cmyk) = @_; my($bk, $wh, $tmp, @rgb);
  $bk = $cmyk[3]*255; # $bk is in [0..1], so we need to scale it up
  $wh=255-$bk;   @rgb=();  $tmp=0;
  for (0..2){
#    $tmp = ( ($cmyk[$_]/255) * $wh ) + $bk;
    $tmp = ( ($cmyk[$_]) * $wh ) + $bk; # $cmyk[$_] is already in [0..1]
    $tmp = ($tmp > 255) ? 255 : $tmp; 
    $rgb[$_] = 255 - int ($tmp + 0.5);
  }
  return @rgb;
}

sub cmyk2rgb2 {
    my ($cyan, $magenta, $yellow, $black) = @_;
    my $white = 255 - $black;
    use integer;
    return map $_ > 255 ? 0 : 255 - $_
        => map $_ * $white / 255 + $black
        => ($cyan, $magenta, $yellow);
}
