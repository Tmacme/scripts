#!/usr/bin/env perl
# convert pyrohmm results to vcf

use strict;
use warnings;

use Getopt::Std;
use List::MoreUtils qw(uniq);
my %opt;
getopts('hf:n:', \%opt);

my $usage = <<ENDL;
perl pyroHMMVcf.pl -f [ref fasta] -n [sample name]
ENDL

sub HELP_MESSAGE {
   print STDERR $usage;
   exit(1);
}

HELP_MESSAGE if $opt{h};
HELP_MESSAGE unless $opt{n};
HELP_MESSAGE unless $opt{f};

my $now = localtime;
my $sample = $opt{n};

open REF, $opt{f} . ".fai" or die "Unable to open reference index file\n";
my @contigs = <REF>;

my $vcfHeader = <<ENDL;
##fileformat=VCFv4.1
##fileDate=$now
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=WMQ,Number=1,Type=Integer,Description="Median mapping quality within window">
##FORMAT=<ID=WBQ,Number=1,Type=Integer,Description="Median base quality within window">
ENDL
for my $contig (@contigs) {
    my @F = split /\t/, $contig;
    $vcfHeader .= "##contig=<ID=$F[0],length=$F[1]>\n";
}
$vcfHeader .= "#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	$sample\n";
print $vcfHeader;

my $format = "GT:WMQ:WBQ";

while (<>) {
    chomp;
    my @F = split / /;
    my ($chrom, $pos, $call, $ref, $alt, $prob, $qual, $winMQ, $winBQ) = @F;
    my @alts = split /,/, $alt;
    my @alts = uniq(@alts);
    my @nonRefAlts;
    for my $i (@alts) {
        push @nonRefAlts, $i if ($i ne $ref);
    }

    my $alts = join ',', @nonRefAlts;
    $alts =~ s/-/./;
    my $GT = "";
    $GT = "0/1" if ($call eq "het" && scalar(@nonRefAlts) == 1);
    $GT = "1/2" if ($call eq "het" && scalar(@nonRefAlts) == 2);
    $GT = "0/0" if ($call eq "hom" && $ref eq $alts);
    $GT = "1/1" if ($call eq "hom" && $ref ne $alts);
    $GT = "0/1" if ($call eq "del" && scalar(@alts) == 2);
    $GT = "1/1" if ($call eq "del" && scalar(@alts) == 1);
    my $sampleFormat = "$GT:$winMQ:$winBQ";
    print "$chrom\t$pos\t.\t$ref\t$alts\t$qual\t.\t$format\t$sampleFormat\n";
}
