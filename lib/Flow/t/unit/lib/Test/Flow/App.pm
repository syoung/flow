use MooseX::Declare;
use Method::Signatures::Simple;

class Test::Flow::App with Test::Common extends Flow::App {

 # with (
	# Test::Agua::Common::Database,
	# Test::Agua::Common::Util,
	# Agua::Common::Base,
	# Agua::Common::Database,
	# Agua::Common::Package,
	# Agua::Common::Util)

use Data::Dumper;
use Test::More;
# use DBase::Factory;
# use Ops::Main;
# use Agua::Instance;
use Conf::Yaml;
use FindBin qw($Bin);

# Ints
has 'log'		=>  ( isa => 'Int', is => 'rw', default => 2 );  
has 'printlog'		=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'validated'		=> ( isa => 'Int', is => 'rw', default => 0 );

# Strings
has 'requestor'     => ( isa => 'Str|Undef', is => 'rw' );
has 'logfile'       => ( isa => 'Str|Undef', is => 'rw' );
has 'owner'	        => ( isa => 'Str|Undef', is => 'rw' );
has 'package'		=> ( isa => 'Str|Undef', is => 'rw' );
has 'remoterepo'	=> ( isa => 'Str|Undef', is => 'rw' );
has 'sourcedir'		=> ( isa => 'Str|Undef', is => 'rw' );
has 'installdir'	=> ( isa => 'Str|Undef', is => 'rw' );
has 'database'		=> ( isa => 'Str|Undef', is => 'rw' );
has 'rootpassword'  => ( isa => 'Str|Undef', is => 'rw' );
has 'dbuser'        => ( isa => 'Str|Undef', is => 'rw' );
has 'dbpass'        => ( isa => 'Str|Undef', is => 'rw' );
#has 'sessionid'     => ( isa => 'Str|Undef', is => 'rw' );

# Objects
has 'json'			=> ( isa => 'HashRef', is => 'rw', required => 0 );

# has 'head' 	=> (
# 	is =>	'rw',
# 	'isa' => 'Agua::Instance',
# 	default	=>	sub { Agua::Instance->new();	}
# );
# has 'master' 	=> (
# 	is =>	'rw',
# 	'isa' => 'Agua::Instance',
# 	default	=>	sub { Agua::Instance->new();	}
# );

# has 'ops' 	=> (
# 	is 		=>	'rw',
# 	isa 	=>	'Ops::Main',
# 	default	=>	sub { Ops::Main->new();	}
# );

has 'conf' 	=> (
	is =>	'rw',
	isa => 'Conf::Yaml',
	default	=>	sub { Conf::Yaml->new(	memory	=>	1	);	}
);

method BUILD ($hash) {
	$self->logDebug("");
	
	# if ( defined $self->logfile() ) {
	# 	$self->head()->ops()->logfile($self->logfile());
	# 	$self->head()->ops()->log($self->log());
	# 	$self->head()->ops()->printlog($self->printlog());
	# }
}

method testLoadUsage {
	diag("#### loadUsage");
	
	#### SET UP DIRS
	my $inputs = "$Bin/inputs/loadusage";
	my $outputs = "$Bin/outputs/loadusage";
	$self->setUpDirs($inputs, $outputs);

	#### SET FILES
	my $usagefile = "$Bin/outputs/loadusage/jbrowseFeatures.txt";
	my $expectedusagefile = "$Bin/outputs/loadusage/jbrowseFeatures-expected.txt";
	my $appfile = "$Bin/outputs/loadusage/jbrowseFeatures.app";
	my $expectedappfile = "$Bin/outputs/loadusage/jbrowseFeatures-expected.app";

	#### LOAD USAGE	
	my $app = $self->_loadUsage($usagefile);
	$self->logDebug("app", $app->toString());
	
	#### CONFIRM PARAMETER NAMES
	my $expected = $self->getFileContents($expectedusagefile);
	$self->logDebug("expected", $expected);
	ok($app->toString() eq $expected, "parameter names");
	
	#### CHECK DESCRIPTIONS
	my $tests = [
		{
			paramname		=>	"tempdir",
			type		=>	"String",
			description =>	"Use this temporary directory to write data on execution host"
		},
		{
			paramname		=>	"maxjobs",
			type		=>	"Int",
			description =>	"Maximum number of jobs to be run concurrently"
		},
		{
			paramname		=>	"queue",
			type		=>	"String",
			description =>	undef
		}
	];
	
	foreach my $test ( @$tests ) {
		my $paramname = $test->{paramname};
		ok($app->hasParam($paramname), "hasParam $paramname");

		my $param = $app->getParam($paramname);
		$self->logDebug("param", $param);

		my $type = $param->paramtype();
		$self->logDebug("type", $type);
		is_deeply($type, $test->{type}, "type for param $paramname");

		my $description = $param->description();
		$self->logDebug("description", $description);
		is_deeply($description, $test->{description}, "description for param $paramname");
	}	
}

method testExportApp {
	diag("#### exportApp");
	
	#### SET UP DIRS
	my $inputs = "$Bin/inputs/loadusage";
	my $outputs = "$Bin/outputs/loadusage";
	`rm -fr $outputs`;
	`mkdir -p $outputs`;
	# $self->setUpDirs($inputs, $outputs);

	#### SET FILES
	my $outputfile = "$outputs/jbrowseFeatures.app";
	my $expectedfile = "$inputs/jbrowseFeatures-expected.app";

	#### LOAD APP
	$self->inputfile($expectedfile);
	$self->_loadFile();

	#### WRITE APP FILE
	$self->exportApp($outputfile);

	#### TEST FILE
	ok(-f $outputfile, "outputfile printed: $outputfile");

	require YAML::Tiny;
	my $yaml = YAML::Tiny->read($outputfile);
	my $actual = $$yaml[0];
	$yaml = YAML::Tiny->read($expectedfile);
	my $expected = $$yaml[0];
	# $self->logDebug("actual", $actual);
	# $self->logDebug("expected", $expected);

	is_deeply($actual, $expected, "outputfile matches inputfile");	
}



}   #### Test::Flow::App

