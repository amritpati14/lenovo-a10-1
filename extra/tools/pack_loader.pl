#!/usr/bin/env perl

use strict;
use 5.010;

if ($#ARGV == -1) {
    say "$0 dram=DRAM_INIT usbplug=USB_PLUG boot=FLASHBOOT data=FLASHDATA out=NAME";
    exit;
}

my @VALID = qw/dram usbplug boot data out/;
my $parts = { map { /^(.+?)=(.+)$/ } @ARGV };

if (@_ = grep { not exists $parts->{$_} } @VALID) {
    say "Specify parts: ", join(',', @_);
    exit;
}

my $KEY = q/7C4E0304550509072D2C7B38170D1711/;
my $SCRAMBLE = qq/openssl rc4 -K $KEY/;
my $SCRAMBLE_PARTS = qq/split -b 512 --filter='$SCRAMBLE'/;

my $to_write = [];
my $fn = $ARGV[0];

open FILE, '>', $parts->{out};
binmode(FILE);

my $header_len = 102;
my $recsize = 0x39;
print FILE 
    pack(
        '@0A4' .   # magic
        '@4S' .  # length
        '@6L' .   # version
        '@10L' .   # var2
        '@14S' .  # year
        '@16C5' . # date
        '@21L' .   # var1
        'CLC'x3,  # num off size
        'BOOT', $header_len, 0x0118, 0x1030000,
            2012, 10, 19, 12, 2, 25,
            #2012, 1, 1, 0, 0, 0,
            0x60,
            1, $header_len, $recsize,
            1, $header_len+$recsize, $recsize,
            2, $header_len+$recsize*2, $recsize
    );

fill($header_len);

my $file_offset = 0x14a;
addPart(1, 'full', $parts->{dram});
addPart(2, 'full', $parts->{usbplug});
addPart(4, 'part', $parts->{data});
addPart(4, 'part', $parts->{boot});

fill(0x14a);

sub fill {
    my $fill = $_[0] - tell FILE;
    print FILE "\x0" x $fill if $fill > 0;
}

sub get_fn {
    my $fn = shift;
    $fn =~ s/\..+$//;
    (join "\x00", split '', $fn),
}

sub addPart {
    my ($no, $scramble, $fn) = @_;
    my $fsize = -s $fn;

    printf "%3d %5x %5x %s\n", $no, $file_offset, $fsize, $fn;
    print FILE pack(
        '@0C' . # len
        '@1L' . # num
        '@5a40' . # name
        '@45LLL',  # offset size unknown

        $recsize, $no, get_fn($fn), $file_offset, $fsize, 0
    );

    $file_offset += $fsize;

    push @$to_write, [ $fn, $scramble ];
}
close FILE;

for (@$to_write) {
    my $cmd = qq/cat '$_->[0]' | /
        . ($_->[1] eq 'part' ? $SCRAMBLE_PARTS : $SCRAMBLE)
        . qq/ >> $parts->{out}/;

    say $cmd;
    system $cmd;
}

for ( qq[./rkcrc $parts->{out} $parts->{out}.crc],
      qq[mv $parts->{out}.crc $parts->{out}] ) { say $_; system $_; }
