#!/usr/bin/perl -s

# Object interface
use Text::CSV;
$file = 'tmp/scopus_eng_20211102.csv'; # $ARGV[1];
#print("file to read: $file\n");

@Scopus_Fields = split(",", "Authors,Author(s) ID,Title,Year,Source title,Volume,Issue,Art. No.,Page start,Page end,Page count,Cited by,DOI,Link,Affiliations,Authors with affiliations,Abstract,Author Keywords,Index Keywords,Molecular Sequence Numbers,Chemicals/CAS,Tradenames,Manufacturers,Funding Details,Funding Text 1,Funding Text 2,Funding Text 3,Funding Text 4,Funding Text 5,Funding Text 6,References,Correspondence Address,Editors,Sponsors,Publisher,Conference name,Conference date,Conference location,Conference code,ISSN,ISBN,CODEN,PubMed ID,Language of Original Document,Abbreviated Source Title,Document Type,Publication Stage,Open Access,Source,EID");

$num_lines = -1;
# Read/parse CSV
$csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
open $fh, "<:encoding(utf8)", $file or die "$file: $!";
while ($row = $csv->getline ($fh)) {
    if ($num_lines == -1) { $num_lines += 1; next; }
    $AF = join("\n   ", split(", ", $row->[0]));
    $C1 = &convertC1($row->[15]);
    $CR = join("\n   ", split("; ", $row->[30]));
    $num_lines += 1;
    print("
AF $AF
TI $row->[2]
PY $row->[3]
SO $row->[4]
C1 $C1
LA $row->[43]
J9 $row->[44]
DT $row->[45]
AB $row->[16]
DE $row->[17]
ID $row->[18]
CR $CR
UT ISI:$num_lines
ER
");
}
close $fh;
print(STDERR "\n\nnumber of lines: $num_lines\n");
exit();

sub convertC1 {
    my($SC1) = @_; my(@C1);
# "Hasnine, M.N., Research Center for Computing and Multimedia Studies, Hosei University, Tokyo, 184-8584, Japan; Ak?ap?nar, G., Department of Computer Education & Instructional Technology, Hacettepe University, Ankara, 06800, Turkey; Mouri, K., Academic Center for Computing and Media Studies, Kyoto University, Kyoto, 606-8501, Japan; Ueda, H., Research Center for Computing and Multimedia Studies, Hosei University, Tokyo, 184-8584, Japan"
# C1 [Chang, Yueh-Hsia; Chang, Chun-Yen] Natl Taiwan Normal Univ, Grad Inst Sci Educ, Taipei 11677, Taiwan.
    my @SC1 = split("; ", $SC1);
    for $sc1 (@SC1) {
        my @s = split(", ", $sc1);
        push @C1, "[$s[0], $s[1]] $s[3], $s[2], $s[4], $s[$#s].";
    }
    print(STDERR $SC1, "\n");
    print(STDERR join("\n   ", @C1), "\n");
    return join("\n   ", @C1);
}