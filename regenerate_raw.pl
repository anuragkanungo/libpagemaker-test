#!/usr/bin/perl

$html = 1;

sub GenRaw {

    $PMDVL = '6.0';

    @pmdVersionList = split( /\s+/, $PMDVL );

    foreach $pmdVersion (@pmdVersionList) {

        # remove all diff files, since they are possible outdated now
        $diffs = 'testset/' . $pmdVersion . '/*.diff';
        `rm -f $diffs`;

        $regrInput = 'testset/' . $pmdVersion . '/regression.in';
        $FL        = `cat $regrInput`;

        @fileList = split( /\n/, $FL );
        foreach $file (@fileList) {
            $filePath = 'testset/' . $pmdVersion . '/' . $file;
            `pmd2raw $filePath >$filePath.raw 2>/dev/null`;
            `pmd2xhtml $filePath > $filePath.xhtml 2>/dev/null`;
            `xmllint --c14n --nonet --dropdtd $filePath.xhtml > $filePath.xhtml.tmp 2>/dev/null`;
            `xmllint --format $filePath.xhtml.tmp > $filePath.xhtml 2>/dev/null`;
            `rm $filePath.xhtml.tmp`;
            `pmd2odg $filePath > $filePath.odg 2> /dev/null`;
            `xmllint --c14n --nonet --dropdtd $filePath.odg > $filePath.odg.tmp 2>/dev/null`;
            `xmllint --format $filePath.odg.tmp > $filePath.odg 2>/dev/null`;
            `rm $filePath.odg.tmp`;
        }
    }
}

# Main function
&GenRaw;

1;
