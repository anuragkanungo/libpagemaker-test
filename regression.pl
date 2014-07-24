#!/usr/bin/perl

my $html = 0;    # set to 1 to output a nicely formatted HTML page

my $do_odg = 0;  # execute the pmd2odg diff test
my $do_vg  = 0;  # execute the valgrind test (takes a while)

my $pass_colour = "11dd11";
my $fail_colour = "dd1111";
my $warn_colour = "e59800";
my $skip_colour = "9999dd";

sub DisplayCell {
    my ( $bgColor, $text ) = @_;

    print "<td style='background-color: #$bgColor;'>$text</td>\n";
}

sub DiffTest {
    my ( $command, $command2, $command3, $file, $extension ) = @_;
    my $result  = "passed";
    my $comment = "";

    my $errPath    = $file . ".$extension.err";
    my $rawPath    = $file . ".$extension";
    my $newRawPath = $file . ".$extension.new";
    my $diffPath   = $file . ".$extension.diff";

    `$command $file 1> $newRawPath 2>/dev/null`;
    if ($command2) {
        `mv $newRawPath $newRawPath.tmp`;
        `$command2 $newRawPath.tmp 1> $newRawPath 2> /dev/null`;
        `rm $newRawPath.tmp`;
    }
    if ($command3) {
        `mv $newRawPath $newRawPath.tmp`;
        `$command3 $newRawPath.tmp 1> $newRawPath 2> /dev/null`;
        `rm $newRawPath.tmp`;
    }

    if ( $err ne "" ) {
        $result = "fail";
    }
    else {
        # remove the generated (empty) error file
        `rm -f $errPath`;

        # diff the stored raw data with the newly generated raw data
        `diff -u --minimal -d $rawPath $newRawPath 1>$diffPath 2>$diffPath`;

        $diff = `cat $diffPath | grep -v "No differences encountered"`;

        if ( $diff ne "" ) {
            $result = "changed";
        }
        else {
            `rm -f $diffPath`;
        }
    }

    # remove the generated raw file
    `rm -f $newRawPath`;

    # DISPLAYING RESULTS
    if ($html) {
        my $bgColor;
        if ( $diff eq "" && $err eq "" ) {
            $bgColor = $pass_colour;
        }
        elsif ( $err ne "" ) {
            $bgColor = $fail_colour;
        }
        else {
            $bgColor = $warn_colour;
        }

        if ( $err ne "" || $diff ne "" ) {
            $comment =
                " <a href='"
              . ( $err ne "" ? $errPath : $diffPath ) . "'>"
              . ( $err ne "" ? "error"  : "diff" ) . "<a>";
        }

        DisplayCell( $bgColor, $result . $comment );
    }
    else {
        if ( $err ne "" || $diff ne "" ) {
            $comment = ( $err ne "" ? "(error: " : "(diff: " )
              . ( $err ne "" ? $errPath : $diffPath ) . ")";
        }
        print "! $file diff (using $command): $result $comment\n";
    }

    return $result;
}

sub CgTest {
    my ( $command, $file ) = @_;

    my $callgraph = `$command $file`;
    chomp($callgraph);

    return $callgraph;
}

sub RegTest {
    my $rawDiffFailures   = 0;
    my $xhtmlDiffFailures = 0;
    my $odgDiffFailures   = 0;
    my $vgFailures        = 0;
    my $callGraphFailures = 0;
    my $vgCommand         = "valgrind --tool=memcheck -v --track-origins=yes";
    my $vgVersionOutput   = `valgrind --version`;
    if (   $vgVersionOutput =~ /\-2.1/
        || $vgVersionOutput =~ /\-2.2/ )
    {
        $vgCommand = "valgrind --tool=memcheck -v --track-origins=yes";
    }

    my @pmdVersionList = (
        "6"
    );

    my $pmdVersion;
    foreach $pmdVersion (@pmdVersionList) {
        if ($html) {
            print "<b>Regression testing the PMD"
              . $pmdVersion
              . " parser</b><br>\n";
            print "<table>\n";
            print "<tr>\n";
            print "<td style='background-color: rgb(204, 204, 255);'><b>File</b></td>\n";
            print "<td style='background-color: rgb(204, 204, 255);'><b>Raw Diff Test<br/>(pmd2raw)</b></td>\n";
            print "<td style='background-color: rgb(204, 204, 255);'><b>XHTML Diff Test<br/>(pmd2xhtml)</b></td>\n";
            print "<td style='background-color: rgb(204, 204, 255);'><b>Call Graph Test<br/>(pmd2raw)</b></td>\n";
            print "<td style='background-color: rgb(204, 204, 255);'><b>ODG Test<br/>(pmd2odg)</b></td>\n";
            print "<td style='background-color: rgb(204, 204, 255);'><b>Valgrind Test<br/>(pmd2raw)</b></td>\n";
            print "<td style='background-color: rgb(204, 204, 255);'><b>ODG Valgrind Test<br/>(pmd2odg)</b></td>\n";
            print "</tr>\n";
        }
        else {
            print "Regression testing the PMD" . $pmdVersion . " parser\n";
        }

        my $regrInput = 'testset/' . $pmdVersion . '/regression.in';

        my @fileList = split( /\n/, `cat $regrInput` );
        foreach $file (@fileList) {

            my $filePath = 'testset/' . $pmdVersion . '/' . $file;

            if ($html) {
                print "<tr>\n";
                print "<td><a href='"
                  . $filePath . "'>"
                  . $file
                  . "</a></td>\n";
            }

            # /////////////////////
            # DIFF REGRESSION TESTS
            # /////////////////////

            if ( DiffTest( "pmd2raw", 0, 0, $filePath, "raw" ) eq "fail" ) {
                $rawDiffFailures++;
            }

            if (
                DiffTest(
                    "pmd2xhtml",        "xmllint --c14n --nonet --dropdtd",
                    "xmllint --format", $filePath,
                    "xhtml"
                ) eq "fail"
              )
            {
                $xhtmlDiffFailures++;
            }

            if ($do_odg) {
                if (
                    DiffTest(
                        "pmd2odg --stdout",
                        "xmllint --c14n",
                        "xmllint --format",
                        $filePath,
                        "odg"
                    ) eq "fail"
                  )
                {
                    $odgDiffFailures++;
                }
            }
            else {
                if ($html) {
                    DisplayCell( $skip_colour, "skipped" );
                }
                else {
                    print "! $file ODG: skipped\n";
                }
            }

            # //////////////////////////
            # CALL GRAPH REGRESSION TEST
            # //////////////////////////

            my $cgResult = CgTest( "pmd2raw --callgraph", $filePath );

            if ( $cgResult ne "0" ) {
                $callGraphFailures++;
            }
            if ($html) {
                (
                    $cgResult eq "0"
                    ? DisplayCell( $pass_colour, "passed" )
                    : DisplayCell( $fail_colour, "failed" )
                );
            }
            else {
                print "! $file call graph: "
                  . ( $cgResult eq "0" ? "passed" : "failed" ) . "\n";
            }

            # ////////////////////////
            # VALGRIND REGRESSION TEST
            # ////////////////////////
            if ($do_vg) {
                $vgPath   = 'testset/' . $pmdVersion . '/' . $file . '.vg';
                $valgrind = 0;
                `$vgCommand --leak-check=yes pmd2raw $filePath 1> $vgPath 2> $vgPath`;
                open VG, "$vgPath";
                my $vgOutput;
                while (<VG>) {
                    if (/^\=\=/) {
                        $vgOutput .= $_;
                        if (   /definitely lost: [1-9]/
                            || /ERROR SUMMARY: [1-9]/
                            || /Invalid read of/ )
                        {
                            $valgrind = 1;
                        }
                    }
                }
                close VG;

                `rm -f $vgPath`;
                if ($valgrind) {
                    open VG, ">$vgPath";
                    print VG $vgOutput;
                    close VG;
                    $vgFailures++;
                }
                $vgOutput = "";

                if ($html) {
                    (
                        $valgrind eq 0
                        ? DisplayCell( $pass_colour, "passed" )
                        : DisplayCell(
                            $fail_colour, "failed <a href='$vgPath'>log<a>"
                        )
                    );
                }
                else {
                    print "! $file valgrind (using pmd2raw): "
                      . ( $valgrind eq "0" ? "passed" : "failed" ) . "\n";
                }
            }
            else {
                if ($html) {
                    DisplayCell( $skip_colour, "skipped" );
                }
                else {
                    print "! $file valgrind (using pmd2raw): skipped\n";
                }
            }

            if ( $do_vg && $do_odg ) {
                $vgPath = 'testset/' . $pmdVersion . '/' . $file . '.odgvg';
                $odgvalgrind = 0;
                `$vgCommand --leak-check=yes pmd2odg --stdout $filePath 1> $vgPath 2> $vgPath`;
                open VG, "$vgPath";
                my $vgOutput;
                while (<VG>) {
                    if (/^\=\=/) {
                        $vgOutput .= $_;
                        if (   /definitely lost: [1-9]/
                            || /ERROR SUMMARY: [1-9]/
                            || /Invalid read of/ )
                        {
                            $odgvalgrind = 1;
                        }
                    }
                }
                close VG;

                `rm -f $vgPath`;
                if ($odgvalgrind) {
                    open VG, ">$vgPath";
                    print VG $vgOutput;
                    close VG;
                    $odgvgFailures++;
                }
                $vgOutput = "";

                if ($html) {
                    (
                        $odgvalgrind eq 0
                        ? DisplayCell( $pass_colour, "passed" )
                        : DisplayCell(
                            $fail_colour, "failed <a href='$vgPath'>log<a>"
                        )
                    );
                    print "</tr>\n";
                }
                else {
                    print "! $file odg valgrind: "
                      . ( $odgvalgrind eq "0" ? "passed" : "failed" ) . "\n";
                }
            }
            else {
                if ($html) {
                    DisplayCell( $skip_colour, "skipped" );
                }
                else {
                    print "! $file odg valgrind: skipped\n";
                }
            }
        }

        if ($html) {
            print "</table><br>\n";
        }

        if ($html) {
            print "<b>Summary</b><br>\n";
            print "Regression test found "
              . $rawDiffFailures
              . " raw diff failure(s)<br>\n";
            print "Regression test found "
              . $xhtmlDiffFailures
              . " xhtml diff failure(s)<br>\n";
            print "Regression test found "
              . $callGraphFailures
              . " call graph failure(s)<br>\n";
            if ($do_odg) {
                print "Regression test found "
                  . $odgDiffFailures
                  . " odg diff failure(s)<br>\n";
            }
            else {
                print "ODG diff test skipped<br>\n";
            }
            if ($do_vg) {
                print "Regression test found "
                  . $vgFailures
                  . " valgrind failure(s)<br>\n";
            }
            else {
                print "Valgrind test skipped<br>\n";
            }
        }
        else {
            print "\nSummary\n";
            print "Regression test found "
              . $rawDiffFailures
              . " raw diff failure(s)\n";
            print "Regression test found "
              . $xhtmlDiffFailures
              . " xhtml diff failure(s)\n";
            print "Regression test found "
              . $callGraphFailures
              . " call graph failure(s)\n";
            if ($do_vg) {
                print "Regression test found "
                  . $vgFailures
                  . " valgrind failure(s)\n";
            }
            else {
                print "Valgrind test skipped\n";
            }
            if ($do_vg && $do_odg) {
                print "Regression test found "
                  . $odgvgFailures
                  . "ODG valgrind failure(s)\n";
            }
            else {
                print "ODG valgrind test skipped\n";
            }
        }
    }
}

sub HtmlHeader {
    print "<html>\n<head>\n</head>\n<body>\n";
    print "<h2>libpagemaker Regression Test Suite</h2>\n";
}

sub HtmlFooter {
    print "</body>\n</html>\n";
}

my $confused = 0;
while ( scalar(@ARGV) > 0 ) {
    my $argument = shift @ARGV;
    if ( $argument =~ /--output-html/ ) {
        $html = 1;
    }
    elsif ( $argument =~ /--vg/ ) {
        $do_vg = 1;
    }
    elsif ( $argument =~ /--odg/ ) {
        $do_odg = 1;
    }
    else {
        $confused = 1;
    }
}
if ($confused) {
    print "Usage: regression.pl [ --output-html ] [ --vg ] [ --odg ]\n";
    exit;
}

# Main function
if ($html) {
    &HtmlHeader;
}

&RegTest;

if ($html) {
    &HtmlFooter;
}

