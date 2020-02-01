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
#       - core.HOMEDIR: /home
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

use FindBin qw($Bin);
use File::Copy qw(move);
use File::Path;

my $UBUNTU_VERSION  = "18.04";
my $CENTOS_VERSION  = "7.7";

#### GET OPERATING SYSTEM
my $os = $^O;

# #### CHANGE TO FOLDER OF THIS FILE
# chdir( $Bin );

# ##    1. INSTALL ALL SUBMODULES
# updateSubmodules ();

##    2. CHECKOUT OS-SPECIFIC BRANCH OF perl SUBMODULE
checkoutPerlBranch( $os );

# ##    3. COPY DB TEMPLATE IF NOT EXISTS
# copyDbFile();

# ##    4. COPY CONFIG FILE FROM TEMPLATE IF NOT EXISTS
# copyConfigFile( $os );

# ##    5. RUN envars.sh TO SET ~/.envars FILE
# system( "$Bin/envars.sh" );

# ##    6. INSTALL repo
# installRepo();

# ##    7. SOURCE .envar FILES
# sourceEnvars();


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
  my $dbtemplate = "$Bin/db/db.sqlite.template";
  my $dbfile = "$Bin/db/db.sqlite";
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

  my $configtemplate = "$Bin/conf/config.yml.template";
  my $configfile = "$Bin/conf/config.yml";
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

  my $homedir = getHomeDir( $os );

  #### REPLACE FIELDS
  $contents =~ s/<INSTALLDIR>/$Bin/;
  $contents =~ s/<HOMEDIR>/$homedir/;
  print "FINAL CONTENTS: $contents\n";

  return $contents;
}

sub getHomeDir {
  my $os = shift;

  my $homedir = "/home";
  if ( $os eq "MSWin32" ) {
    $homedir = "C:\Users";
  }
  elsif ( $os eq "darwin" ) {
    $homedir = "/Users"
  }

  return $homedir;
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
    print "osname: $osname\n";
    ($archname) = $osname =~ /archname=([^\-]+)/;
    print "archname: $archname\n";

    if ( -f "/etc/lsb-release" ) {
      print "Getting Ubuntu version...\n";
      my $version = `cat /etc/lsb-release | grep DISTRIB_RELEASE`;
      $version =~ s/DISTRIB_RELEASE=//;
      $version =~ s/\s+//;
      # print "version: $version\n";
      if ( $version > $UBUNTU_VERSION ) {
        print "VERSION $version IS GREATER THAN MAX SUPPORTED UBUNTU VERSION $UBUNTU_VERSION. USING VERSION: $UBUNTU_VERSION\n";
        $version = $UBUNTU_VERSION;
      } 
      # print "FINAL version: $version\n";
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
      if ( $version > $UBUNTU_VERSION ) {
        print "VERSION $version IS GREATER THAN MAX SUPPORTED CENTOS VERSION $CENTOS_VERSION\n";
        $version = $CENTOS_VERSION;
      } 
      print "FINAL version: $version\n";

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

    use FindBin qw($Bin);
    my $command = "cd $Bin/perl; git checkout $branch-$archname";
    print "$command\n";
    `$command`;
  }
}  

sub installRepo {
  my $repodir = "$Bin/apps/repo";
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

sub sourceEnvars {
  print "To add the environment variables, source your ~/.bashrc file:\n";
  print " . ~/.bashrc\n";
  print "Or source the .envars files directly:\n";

  my $files = [
    "$Bin/.envars",
    "$Bin/apps/repo/latest/.envars"
  ];

  foreach my $file ( @$files ) {
    if ( -f $file ) {
      print ". $file\n";
    }
  }
}

sub sourceFile {
  my $file = shift;

  my $contents = getFileContents( $file );
  # print "sourceFile    contents: $contents\n";
  my @lines = split "\n", $contents;
  foreach my $line ( @lines ) {
    # print "line: $line\n";
    if ( $line =~ /^\s*export\s+([^=]+)=(.+)$/ ) {
      my $envar = $1;
      my $value = $2;
      # print "SETTING \$Env{$envar}=$value\n";
      $Env{$envar}=$value;
      print "SET ENVAR $envar: $Env{$envar}\n"
    }
  }
}
