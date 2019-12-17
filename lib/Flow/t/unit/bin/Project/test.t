#!/usr/bin/perl -w

use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/../../../../..";
use lib "$Bin/../../lib";

#### CREATE OUTPUTS DIR
my $outputsdir = "$Bin/outputs";
`mkdir -p $outputsdir` if not -d $outputsdir;


#### SET CONF FILE
my $configfile  =   "$Bin/../../../../../../conf/config.yml";

use Test::Flow::Project;
use Getopt::Long;
use FindBin qw($Bin);
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
    log     =>  2,
    printlog    =>  2,
    logfile     =>  $logfile
);

my $object = new Test::Flow::Project(
    log			=>	$log,
    printlog    =>  $printlog,
    logfile     =>  $logfile,
    conf        =>  $conf,
    username    =>  $username
);

# $object->startLog($object->logfile());

#### TEST
$object->testSave();
$object->testSortWorkflowFiles();
$object->testGetWorkflowFiles();
$object->testLoadScript();
$object->testSaveWorkflow();
# $object->testDelete(); #### INCOMPLETE

##### CLEAN UP
`rm -fr $Bin/outputs/*`
