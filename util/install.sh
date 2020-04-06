#!/usr/bin/perl -w

my $arch = $^O;
# print "arch: $arch\n";

my $branch = undef;
if ( $arch eq "darwin" ) {
  print "Loading extlib for OSX\n";

}
elsif ( $arch eq "linux" ) {
  print "Loading extlib for Linux\n";
  if ( -f "/etc/lsb-release" ) {
    print "Getting Ubuntu version...\n";
    my $version = `cat /etc/lsb-release | grep DISTRIB_RELEASE`;
    $version =~ s/DISTRIB_RELEASE=//;
    $version =~ s/\s+//;
    # print "version: $version\n";
    $branch = "ubuntu$version";
    $branch =~ s/\.//g;
    # print "Branch: $branch\n";
  }
  elsif ( -f "/etc/centos-release" ) {
    print "Getting Centos version...\n";
    my $version = `cat /etc/centos-release | grep "CentOS Linux release"`;
    $version =~ s/CentOS Linux release//;
    $version =~ s/\s+\(Core\)\s*$//;
    $version =~ s/\s+\(Core\)\s*$//;
    $version =~ s/\.\d+$//;
    $version =~ s/\s+//;
    # print "version: $version\n";
    $branch = "centos$version";
    $branch =~ s/\.//g;
    # print "Branch: $branch\n";
  }
  else {
    print "No LSB or CentOS release file found in /etc. This Linux flavor is not supported. Use 'perlmods' executable to install perl modules to extlib directory\n";
  }
}
elsif ( $arch eq "MSWin32" ) {
  print "Loading extlib for Windows\n";

}

if ( $branch ) {
  print "extlib branch: $branch\n";

  use FindBin qw($Bin);
  print "Bin: $Bin\n";
  my $command = "cd $Bin/extlib; git checkout $branch";
  print "$command\n";
  `$command`;
}
