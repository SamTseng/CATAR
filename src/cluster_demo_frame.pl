#!/usr/bin/perl -s
use CGI qw/:standard/;
$uid = int rand()*10000;



print "Content-type: text/html\n\n";
print <<HTMLEND;
<html>
<head>
<title>���B���J�۰��k���i��
</title>
</head>
<body bgcolor=white>
<center>
<h2>���B���J�۰��k���i��</h2>
<form method=get action="ClusterDB.pl" target="mainFrame">
<input type=hidden name="Ouid" value=$uid>
<table border=1>
<tr>
<td align=center>
���޸s�աG<input type=text name="Ogrp" value="NanoPat" size=7>
���e�ȡG<input type=text name="threshold" value="0.1" size=3>
<td align=center>��X���O�ơG
<input type=text name="MaxCluster" value="12" size=3>
<td align=center>���D���J�ơG
<input type=text name="NumCatTitleTerms" value="3" size=3>
<td align=center>���D�����e�G
<input type=text name="Oct_low_tf" value="1" size=3>
<td align=center>���D���ƧǡG
<select name="Otfc" width=3>
    <option selected value="Chi">Chi
    <option value="TFC">TFC
    <option value="ChixTFC">ChixTFC
</select>
<input type=submit value="����">

<tr>
<td width=25%>���e�Ȥ��� 0 �� 1 �����A�V���� 1�A�k���b�@�_�����V�ۦ��C<br>
��ĳ�ȡG0.90 - 0.98 �����i���ƥ������ΦP�װl�ܡC<br>
	0.6 - 0.9 �����i���������尻���C
<td width=15%>��ĳ�� 5-20 �����A���ϥΪ̺ݹq���t�סA���ȶV�j�t�׶V�C�C
<td width=15%>��ĳ�� 2 - 4 �����C
<td width=15%>��ĳ�� 0 - 2 �����C
<td width=25%>��ĳ�� Chi �� ChixTFC
</table>
</form>
</center>
</body>
</html>
HTMLEND
