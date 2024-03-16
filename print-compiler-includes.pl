#!/usr/bin/env perl

use strict;
use warnings;

my $verbose = 0;
my $flag = '';

# Check for command-line flags before positional arguments
foreach my $arg (@ARGV) {
    if ($arg eq '-v') {  # Check for verbose flag
	$verbose = 1;
	next;  # Skip to the next argument
    }
    if ($arg =~ /^--/) {  # This is a flag
	$flag = $arg;
	next;
    }
}

# Use the $CC environment variable as a default compiler
my $compiler = $ENV{CC} // 'gcc';

# Override with command-line argument if provided
foreach my $arg (@ARGV) {
    if ($arg !~ /^--/ && $arg ne '-v') {  # This is not a flag
	$compiler = $arg;
	last;  # Breaks out of the loop once a compiler is found
    }
}

my $command = $compiler . ' -E -Wp,-v -xc /dev/null 2>&1';

if ($verbose) {
    print "$command\n";
    exit 0;
}

my $start_marker = '#include "..." search starts here:';
my $end_marker = "End of search list.";

open(my $pipe, '-|', $command)
    or die "Failed to execute '$command': $!";

my $found_start = 0;
my @include_directories;

while (my $line = <$pipe>) {
    chomp($line);
    if ($line =~ /$start_marker/) {
	$found_start = 1;
	next;
    }
    last if ($line =~ /$end_marker/ && $found_start);
    if ($found_start and $line !~ /search starts here/) {
	$line =~ s/^\s+//;  # Remove leading whitespace
	$line =~ s/\s+$//;  # Remove trailing whitespace
	push @include_directories, $line;
    }
}

close($pipe);

if ($flag eq '--clangd') {
    if (@include_directories) {
	print "CompileFlags:\n";
	print "  Add:\n";
	foreach my $dir (@include_directories) {
	    $dir =~ s/\s*\(framework directory\)$//;
	    print "    - -I${dir}\n";
	}
    }
} else {
    foreach my $dir (@include_directories) {
	$dir =~ s/\s*\(framework directory\)$//;
	print "-I${dir} ";
    }
    print "\n";
}
