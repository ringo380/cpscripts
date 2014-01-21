#!/bin/sh
eval 'if [ -x /usr/local/cpanel/3rdparty/bin/perl ]; then exec /usr/local/cpanel/3rdparty/bin/perl -x -- $0 ${1+"$@"}; else exec /usr/bin/perl -x $0 ${1+"$@"}; fi;'
  if 0;

#!/usr/bin/perl

# Learning/playing with perl, much of this taken or derived from SSP

use strict;
use warnings;
use diagnostics;
use File::Find;
use File::Spec;
use IO::Socket::INET;
use Sys::Hostname;
use Term::ANSIColor qw(:constants);
use POSIX;
use Storable;
use Time::Local;
use Getopt::Long;

use Cpanel::Sys                     ();

$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';

$|                          = 1;
$Term::ANSIColor::AUTORESET = 1;

# GLOBALS

my $os              = Cpanel::Sys::OS::getos();
my $cpanel_version	= get_cpanel_version();
my $hostname		= hostname();
my $tmp_dir         = "/root";
my $exim_restart_count;

my @exim_version_output;# exim -bV
my @exim_queue_count; 	# exim -bpc
my @exim_bp;            # exim -bp




my %opt = 	(
		"nocolor"	=> 0,
		"noinfo"	=> 0,
		"nobad"		=> 0,
		"nogood"	=> 0,
		);

GetOptions(\%opt,
		"nocolor",
		"noinfo",
		"nogood",
		"nobad",
		);

#my @process_list	= get_process_list();
#my %hostinfo		= get_hostinfo();
#my %cpuinfo		= get_cpuinfo();

my @lsof_25 = split /\n/, timed_run( 'lsof', '-n', '-i', 'tcp:25' );

if ( -x '/usr/sbin/exim' ) {
	@exim_version_output 	= split /\n/, timed_run( '/usr/sbin/exim', '-bV');
	@exim_queue_count 		= split /\n/, timed_run( '/usr/sbin/exim', '-bpc');
	$exim_restart_count 	= split /\n/, timed_run( '/bin/grep', '-c', 'daemon\ started', '/var/log/exim_mainlog');
}

# print @exim_version_output;
# print @exim_queue_count;

print_exim_info();
print_restart_count();
print_queue_count();

print join(", ", @lsof_25);

sub run_eximbp () {
    
}


# Color and print type handling
my $good = ($opt{nocolor} == 0)? BOLD GREEN ON_BLACK "[ * ]" : "[ * ] " ;
my $bad = ($opt{nocolor} == 0)? BOLD RED ON_BLACK "[WARN] * " : "[WARN] * " ;
my $info = ($opt{nocolor} == 0)? BOLD YELLOW ON_BLACK "[INFO] * " : "[INFO] * " ;

#print $info;

sub goodprint { print $good." ".$_[0]; }
sub infoprint { print $info . " " . $_[0] unless ($opt{noinfo} == 1); }
sub badprint { print $bad." ".$_[0]; }
sub redwrap { return ($opt{nocolor} == 0)? BOLD RED ON_BLACK $_[0] : $_[0] ; }
sub greenwrap { return ($opt{nocolor} == 0)? BOLD GREEN ON_BLACK $_[0] : $_[0] ; }

sub print_info {
    my $text = shift;
    print BOLD YELLOW ON_BLACK "[INFO] * $text";
}

sub print_warn {
    my $text = shift;
    print BOLD RED ON_BLACK "[WARN] * $text";
}

sub print_3rdp {
    my $text = shift;
    print BOLD GREEN ON_BLACK "[3RDP] * $text";
}


sub get_cpanel_version {
	my $cpanel_version_file = '/usr/local/cpanel/version';

	if ( open my $file_fh, '<', $cpanel_version_file ) {
		while (<$file_fh>) {
			chomp ( $cpanel_version = $_ );
		}
		close $file_fh;
	}

	if ( $cpanel_version =~ /(\d+\.\d+\.\d+\.\d+)/ ) {
		return $cpanel_version;
	}
	else {
		return 'unknown';
	}
}

sub run {
	my $cmdline = \@_;
	my $output;

	local ($/);
	my ( $pid, $prog_fh );

	if ( $pid = open( $prog_fh, '-1' ) ) {

	}
	else {
		open STDERR, '>', '/dev/null';
		exec(@$cmdline);
		exit(127);
	}

	if ( !$prog_fh || !$pid ) {
		$? = -1;
		return \$output;
	}
	$output = readline($prog_fh);
	close($prog_fh);

	return $output;
}

sub timed_run {
    eval { local $SIG{__DIE__}; local $SIG{__WARN__}; require Cpanel::SafeRun::Timed; };

    if ( !$@ && $INC{'Cpanel/SafeRun/Timed.pm'} ) {
        open( my $save_stderr_fh, '>&STDERR' );
        open( STDERR, '>', '/dev/null' );
        my $result = Cpanel::SafeRun::Timed::timedsaferun( 10, @_ );
        open( STDERR, '>&=' . fileno($save_stderr_fh) );
        return $result;
    }
    goto \&run;
}


sub get_os {
    chomp( my $_os = lc run('uname') );
    return $_os;
}

sub print_exim_info {
	my %output;
	my $exim_status;
	my $key;
	my $value;
	
	if (@exim_version_output) {
		
		my ( 
			$exim_version, 
			$exim_built, 
			$exim_conf, 
			$exim_routers
		);
		
		for my $line (@exim_version_output) {
			if ( $line =~ m{ Exim \s version \s (\d+.\d+.\d+) }xms ) {
				$exim_version = $1;
			}
			if ( $line =~ m{ \s built \s (.*) \z }xms ) {
				$exim_built = $1;
			}
			if ( $line =~ m{ \A Configuration \s file \s is \s (.*) \z }xms ) {
				$exim_conf = $1;
			}
			if ( $line =~ m{ \A Routers: \s (.*) \z }xms ) {
				$exim_routers = $1;
			}
			
		}
	
		if ( !$exim_version or !$exim_built or !$exim_conf ) {
			$output{"could not determine Exim info!"} = "Error: ";
		} else {
			$output{"[ $exim_version ]"} = "Exim Version: ";
			$output{"[ $exim_built ]"} = "Exim Built on: ";
			$output{"[ $exim_conf ]"} = "Exim Config Path: ";
		}

	
	}

	while ( ($key, $value) = each(%output) ) {
		print_info($value);
		print_normal($key);
	}
	
#	print_info('Exim Version: ');
#	print_normal($output[0]);

#	print_info('Exim Built on: ');
#	print_normal($output[1]);

#	print_info('Exim Config Path: ');
#	print_normal($output[2]);

	
}



## precedes informational items (e.g., "Hostname:")
sub print_start {
    my $text = shift;
    print BOLD YELLOW ON_BLACK $text;
}
## for informational items (e.g., the server's hostname)
sub print_normal {
    my $text = shift;
    print BOLD CYAN ON_BLACK "$text\n";
}
## for important things (e.g., "Hostname is not a FQDN")
sub print_warning {
    my $text = shift;
    print BOLD RED ON_BLACK "$text\n";
}

sub print_info2 {
    my $text = shift;
    print BOLD GREEN ON_BLACK "$text\n";
}

sub print_magenta {
    my $text = shift;
    print BOLD MAGENTA ON_BLACK "$text\n";
}


##############################
#  BEGIN [INFO] CHECKS
##############################

sub print_hostname {

    print_info('Hostname: ');

    if ( $hostname !~ /([\w-]+)\.([\w-]+)\.(\w+)/ ) {
        print_warning("$hostname may not be a FQDN ( en.wikipedia.org/wiki/Fully_qualified_domain_name )");
    }
    else {
        print_normal($hostname);
    }
}

sub print_queue_count {
		if ( @exim_queue_count < 50 ) {
			print BOLD WHITE ON_BLACK "Exim Queue Count: " . RESET;
			print BOLD GREEN ON_BLACK $exim_queue_count[0] . RESET . "\n";
		} else {
			print BOLD WHITE ON_BLACK "Exim Queue Count: " . RESET;
			print BOLD RED ON_BLACK $exim_queue_count[0] . RESET . "\n";
		}
}

sub print_restart_count {
	print_info('Recent Restarts: ');
	
	if ( $exim_restart_count ) {
		print_normal($exim_restart_count);
	}
}



#				print BOLD YELLOW ON_BLACK "Exim Version: " . RESET;
#				print BOLD WHITE ON_BLACK $exim_version . RESET . "\n";
#				print BOLD YELLOW ON_BLACK "Exim Built on: " . RESET;
#				print BOLD WHITE ON_BLACK $exim_built . RESET . "\n";
#				print BOLD YELLOW ON_BLACK "Exim Loaded Conf Path: " . RESET;
#				print BOLD WHITE ON_BLACK $exim_conf . RESET . "\n\n";				
#				print BOLD BLUE ON_BLACK "Routers: " . RESET;
#				print WHITE ON_BLACK $exim_routers . RESET . "\n";
