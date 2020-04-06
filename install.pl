#!/usr/bin/perl -w

# 
# 
# PURPOSE: THIS INSTALLER ENABLES flow BY DOING THE FOLLOWING:
#
#     - POPULATES THE FOLLOWING git SUBMODULES:
#       - perl SUBMODULE - AN EMBEDDDED PERL EXECUTABLE
#       - lib DIRECTORY SUBMODULES CONTAINING PERL MODULES
#       - package SUBMODULE CONTAINING APP INSTALLERS
#  
#     - COPIES db/db.sqlite FROM A TEMPLATE (SKIPS IF FILE ALREADY EXISTS)
#
#     - COPIES conf/config.yml FROM A TEMPLATE (SKIPS IF FILE ALREADY EXISTS) AND PROVIDES VALUES FOR THE FOLLOWING FIELDS:
#       - core.INSTALLDIR (E.G.: /flow)
#       - core.USERDIR: /home
#
#     - RUNS envars-standalone.sh IN ORDER TO AUTOMATICALLY LOAD THE FOLLOWING MODIFIED ENVIRONMENT VARIABLES ON CONNNECTION TO THE CONTAINER:
#       -  THE 'PATH' ENVIRONMENT VARIABLE, ENABLING ACCESS TO: 
#         - THE EMBEDDED PERL EXECUTABLE
#         - THE bin/repo EXECUTABLE
#       -  THE 'PERL5LIB' ENVIRONMENT VARIABLE, ENABLING ACCESS TO: 
#         -  THE PERL MODULES IN THE perl DIRECTORY
#         -  THE PERL MODULES IN THE lib DIRECTORY
#
# INSTALLER LOGIC: 
#
##    1. INSTALL ALL SUBMODULES
##    2. CHECKOUT OS-SPECIFIC BRANCH OF perl SUBMODULE
##    3. COPY DB TEMPLATE FROM TEMPLATE IF NOT EXISTS
##    4. COPY CONFIG FILE FROM TEMPLATE IF NOT EXISTS
##    5. RUN envars.sh TO SET ~/.envars FILE
##    6. INSTALL repo

# use FindBin qw($Bin);
use File::Copy qw(move);
# use File::Spec::Functions qw( rel2abs );
# use lib rel2abs( dirname(__FILE__) );

use File::Path;
use File::Basename qw( dirname );
use Cwd qw( abs_path );

# print "dirname(__FILE__): ", dirname( __FILE__ ), "\n";
# print "$_\n" for @INC;
# print "abs_path( $0 ): ", abs_path( $0 ), "\n";
my $INSTALLDIR = dirname(abs_path( $0 ));
print "INSTALLDIR: $INSTALLDIR\n";
# print " dirname(abs_path( $0 )): ", dirname(abs_path( $0 )), "\n";
use lib dirname(abs_path($0));

#### GET OPERATING SYSTEM
my $os = $^O;

#### CHANGE TO FOLDER OF THIS FILE
chdir( $INSTALLDIR );

##    1. INSTALL ALL SUBMODULES
updateSubmodules ();

##    2. CHECKOUT OS-SPECIFIC BRANCH OF perl SUBMODULE
checkoutPerlBranch( $os );

##    3. COPY DB TEMPLATE IF NOT EXISTS
copyDbFile();

##    4. COPY CONFIG FILE FROM TEMPLATE IF NOT EXISTS
copyConfigFile( $os );

##    5. RUN envars.sh TO SET ~/.envars FILE
system( "$INSTALLDIR/envars.sh" );

##    6. INSTALL repo
installRepo();

#### SUBROUTINES
sub updateSubmodules {
  print "Updating submodules:\n";
  my $commands = [
    "git submodule update --init --recursive --remote",
  ];
  foreach my $command ( @$commands ) {
    print "$command\n";
    system( $command );
  }
}

sub copyDbFile {
  my $dbtemplate = "$INSTALLDIR/db/db.sqlite.template";
  my $dbfile = "$INSTALLDIR/db/db.sqlite";
  if ( -f $dbfile ) {
    print "\nSkipping copy dbfile as file already exists: $dbfile\n";
  }
  else {
    print "Copying $dbtemplate to $dbfile\n";
    move( $dbtemplate, $dbfile );
  }  
}

sub copyConfigFile {
  my $os     = shift;

  my $configtemplate = "$INSTALLDIR/conf/config.yml.template";
  my $configfile = "$INSTALLDIR/conf/config.yml";
  if ( -f $configfile ) {
    print "\nSkipping copy configfile as file already exists: $configfile\n";
  }
  else {
    print "Copying $configtemplate to $configfile\n";
    my $contents = getFileContents( $configtemplate );
    $contents = replaceFields( $os, $contents );
    printFile( $configfile, $contents );
  }  
}

sub printFile {
  my $file      = shift;
  my $contents  = shift;

  open( OUTFILE, ">$file" ) or die "Can't open file: $file\n";
  print OUTFILE $contents;
  close( OUTFILE ) or die "Can't close file: $file\n";
}

sub getFileContents {


  my $file = shift;

  open( INFILE, "<$file" ) or die "Can't open file: $file\n";
  my $temp = $/;
  $/ = undef;
  my $contents = <INFILE>;
  close( INFILE ) or die "Can't close file: $file\n";
  $/ = $temp;

  return $contents;
}

sub replaceFields {
  my $os       = shift;
  my $contents = shift;

  my $userdir = "/home";
  if ( $os eq "MSWin32" ) {
    $userdir = "C:\Users";
  }
  elsif ( $os eq "darwin" ) {
    $userdir = "/Users"
  }

  #### REPLACE FIELDS
  $contents =~ s/<INSTALLDIR>/$INSTALLDIR/;
  $contents =~ s/<USERDIR>/$userdir/;
  print "FINAL CONTENTS: $contents\n";

  return $contents;
}

sub checkoutPerlBranch {
  my $os = shift;
  my $branch = undef;
  my $archname = undef;
  
  print "\n";
  if ( $os eq "darwin" ) {
    print "Loading embedded perl branch for OSX:\n";
    $branch = "osx10.14.6";
    $archname = "darwin-2level";
  }
  elsif ( $os eq "linux" ) {
    print "Loading embedded perl branch for Linux:\n";

    my $osname=`/usr/bin/perl -V  | grep "archname="`;
    # print "osname: $osname\n";
    ($archname) = $osname =~ /archname=(\S+)/;
    # print "archname: $archname\n";

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
      print "No /etc/lsb-release or /etc/centos-release file found. This Linux flavor is not supported.\n";
    }
  }
  elsif ( $os eq "MSWin32" ) {
    print "Loading embedded perl branch for Windows:\n";
    $branch = "MSWin32";
    $archname = "x64-multi-thread";
  }

  if ( $branch and $archname ) {
    print "perl branch: $branch-$archname\n";

    # use FindBin qw($Bin);
    my $command = "cd $INSTALLDIR/perl; git checkout $branch-$archname";
    print "$command\n";
    `$command`;
  }
}  

sub installRepo {
  my $repodir = "$INSTALLDIR/apps/repo";
  if ( -d $repodir ) {
    print "Skipping install repo because directory exists: $repodir\n";
  }
  else {
    mkpath( $repodir ) if not -d $repodir;
    chdir( $repodir );
    my $repourl = "https://github.com/syoung/repo";
    system( "git clone $repourl latest" );
    chdir( "$repodir/latest" );
    system( "./install.pl dependent" );
  }
}


