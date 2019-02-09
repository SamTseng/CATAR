
perl -s tool.pl -OSC=IssuedDate IEK_A Patent ..\Result\IEK_A_S2\2_2_2_0.1.html > ..\Result\IEK_A_S2\2_2_2_0.1_IssuedDate.html

perl -s tool.pl -OSC=Inventor -Omin=2 IEK_A Patent ..\Result\IEK_A_S2\2_2_2_0.1.html > ..\Result\IEK_A_S2\2_2_2_0.1_Inventor.html

perl -s tool.pl -OSC=Assignee -Omin=2 IEK_A Patent ..\Result\IEK_A_S2\2_2_2_0.1.html > ..\Result\IEK_A_S2\2_2_2_0.1_Assignee.html

perl -s tool.pl -OSC=Country -Omin=1 IEK_A Patent ..\Result\IEK_A_S2\2_2_2_0.1.html > ..\Result\IEK_A_S2\2_2_2_0.1_Country.html

perl -s tool.pl -OSC=Citation -Omin=2 IEK_A Patent ..\Result\IEK_A_S2\2_2_2_0.1.html > ..\Result\IEK_A_S2\2_2_2_0.1_Citation.html

perl -s tool.pl -OSC=PC -Omin=2 IEK_A Patent ..\Result\IEK_A_S2\2_2_2_0.1.html > ..\Result\IEK_A_S2\2_2_2_0.1_PC.html
