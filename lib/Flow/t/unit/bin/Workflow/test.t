#!/usr/bin/perl -w

#### EXTERNAL MODULES
use Test::More qw(no_plan);
use FindBin qw($Bin);
use Getopt::Long;

#### USE LIBS
use lib "$Bin/../../../../..";
use lib "$Bin/../../lib";

#### SET CONF FILE
my $configfile  =   "$Bin/../../../../../../conf/config.yml";

use Test::Flow::Workflow;
use Conf::Yaml;

#### SET LOG
my $log         =   2;
my $printlog    =   5;
my $logfile     =   "$Bin/outputs/test.log";

#### GET OPTIONS
my $login;
my $owner;
my $username = "syoung";
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

my $conf = Conf::Yaml->new(
    memory      =>  1,
    inputfile	=>	$configfile,
    log         =>  $log,
    printlog    =>  $printlog,
    logfile     =>  $logfile
);

my $object = new Test::Flow::Workflow(
    log			=>	$log,
    printlog    =>  $printlog,
    logfile     =>  $logfile,
    conf        =>  $conf,
    username    =>  $username
);

#### LOG
# $object->startLog($object->logfile());

#### TESTS
$object->testConvert();
$object->testAddWorkflow();

##### CLEAN UP
`rm -fr $Bin/outputs/*`
