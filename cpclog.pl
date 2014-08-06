#!/usr/bin/perl

#package ListParse;

use diagnostics;
#use strict;
use LWP::Simple;
use HTML::TreeBuilder;
use HTML::TreeBuilder::XPath;
use Mojo;
use Term::ANSIColor qw(:constants);
require HTML::Parser;

my $url;
my $content;
my $line;
my $content_filtered;
my $raw;
my $n;
my @cases;
my @listitems;
my @lis;

my $fbpre = "http://fogbugz.cpanel.net/?";

my $parser = HTML::TreeBuilder->new();

$url = "http://documentation.cpanel.net/display/ALD/11.44+Change+Log";

$raw = get $url;
die "Couldn't get $url" unless defined $raw;

my $dom = HTML::TreeBuilder::XPath->new_from_content($raw);
my @h2 = $dom->findnodes('//h2'); 
my @ul = $dom->findnodes('//ul');

foreach($content_filtered) {
	foreach(@ul) { 
		push @lis, $_->findvalues('./li');
	}
}

foreach($raw) { 
	if ( /\<li.*\bcase\b.*\<\/li/ ) {
		my $listitem = $&;
		$listitem =~ s{</li>}{\n}g;
		$listitem =~ s{<.*>}{}g;
		$listitem =~ s{</li}{}g;
		@cases = split /\n/, $listitem;
	}
}

if ( $ARGV[0] eq "-l" ) {
	foreach my $case (@cases) {
		print "$case\n";
	}
} else {

print "Enter a case number: ";
chomp (my $caseid = <STDIN>);
my $fburl = $fbpre . $caseid;

foreach (@cases) {
	if ( /$caseid/ ) {
		print BOLD CYAN ON_BLACK "Found: " . RESET;
		print "$_\n";
		print BOLD CYAN ON_BLACK "URL: " . RESET . "$fburl\n";
		$n = 1;
	} 
}

if ( !$n) { print "Case $caseid not found in change log.\n"; }

}
