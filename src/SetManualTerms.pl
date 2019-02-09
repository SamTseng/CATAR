sub SetManualTerms {
    my($rDC, $seg, $TermFile) = @_;
    open F, $TermFile or die "Cannot read file:'$TermFile'";
    @Terms = <F>; chomp @Terms;
    close(F);
    $seg->ResetSegmentationDic(\@Terms);
}
1;
