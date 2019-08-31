REM The following DOS commands will install modules for CATAR
cd \CATAR\src
cpan install Encode::Detect::Detector
cpan install Statistics::Regression
cpan install Math::MatrixReal
cpan install Win32::ODBC

mkdir C:\Strawberry\perl\site\lib\SAMtool
copy Perl_Module\SAMtool\* C:\Strawberry\perl\site\lib\SAMtool
