#
#      $Id$
#
#########################################################################
#									#
#			   Copyright (C)  2002				#
#	     			Internet2				#
#			   All Rights Reserved				#
#									#
#########################################################################
#
#	File:		OWP::Digest.pm
#
#	Author:		Anatoly Karp
#			Internet2
#
#	Date:		Thu Oct 17 10:40:10  2002
#
#	Description: Merging multiple bucket files.

package OWP::Digest;

require 5.005;
use strict;
use POSIX;

$Digest::REVISION = '$Id$';
$Digest::VERSION='1.0';

# the first 3 fields (all unsigned bytes) are fixed in all versions of header 
use constant MAGIC_SIZE => 9;
use constant VERSION_SIZE => 1;
use constant HDRSIZE_SIZE => 1;

use constant NUM_LOW => 50000;
use constant NUM_MID  => 10000;
use constant NUM_HIGH => 49900;
use constant MAX_BUCKET => (NUM_LOW + NUM_MID + NUM_HIGH - 1);
use constant MAGIC => 'OwDigest';
use constant THOUSAND => 1000;

use constant DEBUG => 1;

# This sub merges @files into a new digest file $newname.
sub merge {
    my ($newname, @files) = @_;

    unless (@files) {
	warn "no files to be merged into $newname - continuing...";
	return;
    }

    open OUT, ">$newname" or die "Could not open $newname: $!";

    my @buckets;

    for (0..MAX_BUCKET) {
	$buckets[$_] = 0;
    }

    my ($worst_prec, $final_min) = (0.0, 99999.0);
    my ($total_sent, $total_lost, $total_dup) = (0, 0, 0);

    my ($magic, $version, $hdr_len);
    my $seen = 0;
    foreach my $file (@files) {
    	next if(!-r $file);
	open(FH, "<$file") or die "Could not open $file: $!";

	my ($header, $prec, $sent, $lost, $dup, $buf, $min, $pre);

	$pre = MAGIC_SIZE + VERSION_SIZE + HDRSIZE_SIZE;
	die "Cannot read header: $!" if (read(FH, $buf, $pre) != $pre);
	($magic, $version, $hdr_len) = unpack "a8xCC", $buf;
	my $remain_bytes = $hdr_len - $pre;

	die "Currently only work with version 1 and 2: $file: $version"
		unless (($version == 1) || ($version == 2));

	die "Cannot read header"
		if (read(FH, $buf, $remain_bytes) != $remain_bytes);

	if($version == 1){
		($prec, $sent, $lost, $dup, $min) = unpack "CLLLd", $buf;
		$prec = (2**(32 - $prec)) * 2;
	}
	else{
		# currently only version 2 is encoded this way, but
		# leave as "default".
		($prec, $sent, $lost, $dup, $min) = unpack "dLLLd", $buf;
	}

	if ($prec > $worst_prec) {
	    $worst_prec = $prec;
	}

	if ($min < $final_min) {
	    $final_min = $min;
	}

	$total_sent += $sent;
	$total_lost += $lost;
	$total_dup += $dup;

	# Compute the number of non-empty buckets (== records in the file).
	my @stat = stat FH;
	die "stat failed: $!" unless @stat;
	my $size = $stat[7];
	my ($num_records);
	{
	    use integer;
	    $num_records = ($size - $hdr_len) / 8;
	}

	for (my $i = 0; $i < $num_records; $i++) {
	    my $buf;
	    read FH, $buf, 8 or die "Could not read: $!";
	    my ($index, $count) = unpack "LL", $buf;

	    $buckets[$index] += $count;

	}
	close FH;
	$seen = 1;
    }

    unless ($seen) {
	warn "DEBUG: no files to be merged into $newname - continuing...";
	return;
    }

    unless ($total_sent) {
	warn "DEBUG: sent == 0 upon merge into $newname";
    }

    # migrate all files to version 2 over time.

    $version = 2;
    # Trick to compute header length and place it within the header itself.
    my $header = pack "a8xCCdLLLd", MAGIC, $version, $hdr_len, $worst_prec,
	    $total_sent, $total_lost, $total_dup, $final_min;
    $hdr_len = length($header);
    $header = pack "a8xCCdLLLd", MAGIC, $version, $hdr_len, $worst_prec,
	    $total_sent, $total_lost, $total_dup, $final_min;

    print OUT $header;
    for (my $ind = 0; $ind <= MAX_BUCKET; $ind++) {
	next unless $buckets[$ind];

	my $rec = pack "LL", $ind, $buckets[$ind];
	print OUT $rec;

    }
    close OUT;
}

1;
