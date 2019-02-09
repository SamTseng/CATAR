    use wntool;
# Ex: perl -s wntool.pl -Odebug=1 optic
#=comment
    $str = <<ENDF;
hydrogenated : 94 : photo,sensor,arylalkyl hydroxylamine,activity,C1,rate,halides,alkyl phenyl,integer,trap,alkoxy phenyl nitro amino,C6,silicon bond,alkoxycarbonyl halogen,Si,substituents,DNA,stream,Schottky diode,halo,bond,plasma,halogen,benzyl,derive,membrane,silicon,substrate,Pd,gas,time,biphenyl,alkoxy phenyl,compounding,phenyl,group,methyl,trifluoromethyl,ppm,phenoxy,hydrogen atom,alkyl,isodethiaazacephem derivative,isodethiaazacephems,SiC,WATER,formulas,aryl,Air,sulfide,flowing rate,ethanol,alkoxy,six carbon atoms,semiconductor,capping layer. 
ENDF
#    while ($str =~ /(\w+)/g) { push @ARGV, $1; }
#=cut    
#    @ARGV = split /[ ,]+/, 'laser, wavelength, beam, optic, light';

    ($rCats, $rScore, $rSense) = &wntool::SemanticClass(@ARGV);
    	print join(", ", @ARGV), "\n  =>", 
    	  join("\n  =>", map{"$rScore->{$_} : $_"}@$rCats), "\n\n";

