#!/usr/bin/perl -w

use Test::More tests => 2;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib "$Bin/../../../../..";
use Getopt::Long;

use Conf::Yaml;
use Test::Flow::App;

#### CREATE OUTPUTS DIR
my $outputsdir = "$Bin/outputs";
`mkdir -p $outputsdir` if not -d $outputsdir;

#### SET LOG
my $log         =   2;
my $printlog    =   5;
my $logfile     =   "$Bin/outputs/test.log";

#### GET OPTIONS
my $login;
my $owner       =   "anonymous";
my $username    =   "syoung";
my $token;
my $keyfile;
my $help;
GetOptions (
    'log=i'         => \$log,
    'printlog=i'    => \$printlog,
    'login=s'       => \$login,
    'owner=s'       => \$owner,
    'username=s'    => \$username,
    'token=s'       => \$token,
    'keyfile=s'     => \$keyfile,
    'help'          => \$help
) or die "No options specified. Try '--help'\n";
usage() if defined $help;

#### LOAD LOGIN, ETC. FROM ENVIRONMENT VARIABLES
$login = $ENV{'login'} if not defined $login or not $login;
$token = $ENV{'token'} if not defined $token;
$keyfile = $ENV{'keyfile'} if not defined $keyfile;

#### SET CONF
my $configfile  =   "$Bin/../../../../../conf/config.yml";
my $conf = Conf::Yaml->new(
    memory      =>  1,
    inputfile	=>	$configfile,
    log         =>  $log,
    printlog    =>  $printlog,
    logfile     =>  $logfile
);

my $object = new Test::Flow::App(
    log			=>	$log,
    printlog    =>  $printlog,
    logfile     =>  $logfile,
    conf        =>  $conf,
    username    =>  $username,
    owner       =>  $owner
);

#### START LOG AFRESH
$object->startLog($object->logfile());

#### TESTS
# $object->testLoadUsage();
$object->testExportApp();


#### CLEAN UP
`rm -fr $Bin/outputs/*`
