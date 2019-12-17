use MooseX::Declare;
use Method::Signatures::Simple;

class Test::Flow::Project with Test::Common extends Flow::Project {

# Agua::Common::Util
# Test::Agua::Common::Database,
# 	Test::Agua::Common::Util,
# 	Agua::Common::Database,
# 	Agua::Common::Base,
# 	Agua::Common::Package,

use Data::Dumper;
use Test::More;
use FindBin qw($Bin);

# use DBase::Factory;
# use Ops::Main;
# use Agua::Instance;
use Conf::Yaml;
use Test::Table::Main;
use YAML::Tiny;

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
# has 'dumpfile'		=> ( isa => 'Str|Undef', is => 'rw' );
# has 'database'		=> ( isa => 'Str|Undef', is => 'rw' );
# has 'rootpassword'  => ( isa => 'Str|Undef', is => 'rw' );
# has 'dbuser'        => ( isa => 'Str|Undef', is => 'rw' );
# has 'dbpass'        => ( isa => 'Str|Undef', is => 'rw' );
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

has 'jsonparser'	=> ( 
	is => 'rw', 
	isa => 'JSON', 
	lazy => 1, 
	builder => "setJsonParser"
);

# Object
has 'conf'			=> ( 
	is => 'rw', 
	isa => 'Conf::Yaml', 
	lazy => 1, 
	builder => "setConf" 
);

method setConf {
	my $conf 	= Conf::Yaml->new({
		memory		=>	1,
		backup		=>	1,
		log				=>	$self->log(),
		printlog	=>	$self->printlog()
	});
	
	$self->conf($conf);
}

has 'table' => ( 
  is => 'rw',
  isa => 'Test::Table::Main',
  lazy => 1,
  builder => "setTestTable" 
);

method setTestTable () {
  my $table = Test::Table::Main->new({
    conf      =>  $self->conf(),
    log       =>  $self->log(),
    printlog  =>  $self->printlog()
  });

  $self->table($table); 
}

#### DEFAULT PACKAGES
method setOpsDir ($username, $repository, $type, $package) {
#### example: /agua/0.6/repos/public/biorepository/syoung/bioapps
	$self->logNote("username", $username);
	$self->logNote("repository", $repository);
	$self->logNote("type", $type);
	$self->logNote("package", $package);

	#### ADDED FOR TESTING
	return $self->opsdir() if defined $self->opsdir();
	
	$self->logError("type is not public or private") and exit if $type !~ /^(public|private)$/;
	my $installdir = $self->conf()->getKey("core:INSTALLDIR");
	my $opsdir = "$installdir/repos/$type/$repository/$username/$package";
	File::Path::mkpath($opsdir);
	$self->logError("can't create opsdir: $opsdir") if not -d $opsdir;
	
	return $opsdir;
}

method setInstallDir ($username, $owner, $package, $type) {
#### RETURN LOCATION OF APPLICATION FILES - OVERRIDEN FOR TESTING
	$self->logNote("username", $username);
	$self->logNote("owner", $owner);
	$self->logNote("package", $package);
	$self->logNote("type", $type);

	return $self->installdir() if defined $self->installdir();
	
	my $userdir = $self->conf()->getKey("core:USERDIR");

	return "$userdir/$username/.repos/$type/$package/$owner";
}

#### WORKFLOWS

method testLoadScript {
	diag("#### loadScript");

	#### SET DB
  $self->table()->setUpTestDatabase();
  $self->table()->setDatabaseHandle();
	$self->table()->db()->do("DELETE FROM project");

	my $inputdir	=	"$Bin/inputs/conf";
	my $outputdir	=	"$Bin/outputs/conf";
	`rm -fr $outputdir` if -d $outputdir;
	`mkdir -p $outputdir`;
	
	my $inputdatadir	=	"$Bin/inputs/data";
	my $outputdatadir	=	"$Bin/outputs/data";
	`rm -fr $outputdatadir` if -d $outputdatadir;
	`cp -r $inputdatadir $outputdatadir`;

	my $inputfile	=	"$Bin/outputs/conf/NRC.prj";
	my $cmdfile		=	"$Bin/outputs/data/sh/script.sh";
	my $projectname		=	"NRC";
	my $description	=	"National Research Council (Canada) ovarian cancer analysis pipeline";
	$self->inputfile($inputfile);
	$self->cmdfile($cmdfile);
	$self->projectname($projectname);
	$self->description($description);
	
	$self->loadScript();
	my $diff	=	$self->diff($inputdir, $outputdir);
	$self->logDebug("diff", $diff);
	
	ok($diff, "*.prj and *.wrk files created");
}

method testDelete {
	diag("#### delete");
	
	##### INCOMPLETE ######
	##### INCOMPLETE ######
	##### INCOMPLETE ######
	##### INCOMPLETE ######

	#### SET DB
  $self->table()->setUpTestDatabase();
  $self->table()->setDatabaseHandle();
	$self->table()->db()->do("DELETE FROM project");

	#### LOAD TSVFILES
	my $projectfile	=	"$Bin/inputs/workflows/projects/PanCancer/PanCancer.prj";
	$self->inputfile($projectfile);

	##### INCOMPLETE ######
	##### INCOMPLETE ######
	##### INCOMPLETE ######
	##### INCOMPLETE ######
	
}

method testGetWorkflowFiles {
	diag("#### getWorkflowFiles");
	#### SET DB
  $self->table()->setUpTestDatabase();
  $self->table()->setDatabaseHandle();

	#### SET USERNAME
	my $username = $self->conf()->getKey("database:TESTUSER");
	$self->username($username);
	$self->logDebug("username", $username);

	#### SET WORKFLOW DIR
	my $basedir = "$Bin/inputs/workflows/projects";
	$self->logDebug("basedir", $basedir);
	
	my $tests = [
		{
			project 	=>	"PanCancer",
			expected 	=>	[
				"1-Download.wrk",
				"2-Split.wrk",
				"3-Align.wrk"
			]
		},
	
		{
			project 	=>	"Project1",
			expected 	=>	[
				'1-Workflow1.wrk',
				'2-Workflow2.wrk'
			]
		},
	
		{
			project 	=>	"Project2",
			expected 	=>	[
				'1-Workflow1.wrk'
			]
		}
	];

	foreach my $test ( @$tests ) {
		my $project = $test->{project};
		my $expected = $test->{expected};
		my $projectdir = "$basedir/$project";

		my $actual = $self->getWorkflowFiles($projectdir);
		is_deeply($actual, $expected);
	}
}

method testSortWorkflowFiles {
	diag("#### sortWorkflowFiles");

	my $workflows = [
		'1-Workflow1',
		'11-Workflow11',
		'2-Workflow2',
		'22-Workflow22',
		'3-Workflow3'
	];

	my $expected = [
		'1-Workflow1',
		'2-Workflow2',
		'3-Workflow3',
		'11-Workflow11',
		'22-Workflow22'
	];

	$workflows = $self->sortWorkflowFiles($workflows);
	$self->logDebug("workflows", $workflows);

#	ok ($self->identicalArray($workflows, $expected), "sortWorkflowFiles    correct sorted order");	
	is_deeply($workflows, $expected, "sortWorkflowFiles    correct sorted order");	
}

method testSave {
	diag("#### save");

	#### SET DB
  $self->table()->setUpTestDatabase();
  $self->table()->setDatabaseHandle();
	$self->table()->db()->do("DELETE FROM project");
	
	my $projectfile	=	"$Bin/inputs/workflows/projects/PanCancer/PanCancer.prj";
	$self->inputfile($projectfile);

	#### SET USERNAME AND OWNER
	my $username	=	"testuser";
	$self->username($username);

	#### SAVE
	$self->save();

	#### GET ACTUAL
	my $projectname	=	$self->projectname();
	$self->logDebug("projectname", $projectname);
	my $entry	=	$self->table()->db()->queryhash("SELECT * FROM project WHERE projectname='$projectname'");
	$self->logDebug("self->db->database", $self->table()->db()->database());
	$self->logDebug("entry", $entry);
	
	#### GET EXPECTED
	my $contents	=	$self->getFileContents($projectfile);
	my $yaml 			= YAML::Tiny->read($projectfile);
	my $data			=	$$yaml[0];
	$self->logDebug("data", $data);
	
	#### VERIFY
	foreach my $field ( keys %$data ) {
		next if $field eq "workflows";
		$self->logDebug("field $field: expected $data->{$field}, actual: $entry->{$field}");
		ok($data->{$field} eq $entry->{$field}, "loaded field $field");
	}
}

method testSaveWorkflow {
	diag("#### saveWorkflow");

  #### RESET DATABASE
  $self->table()->setUpTestDatabase();
  # $self->table()->setDatabaseHandle();
	$self->table()->db()->do("DELETE FROM workflow");

	#### INPUTS
	my $directory	=	"$Bin/inputs/workflows/projects/PanCancer";
	#my $wrkflows	=	["1-Download.wrk", "2-Split.wrk", "3-Align.wrk"];
	my $workflows	=	["1-Download.wrk"];
	my $project		=	"PanCancer";
	my $projectfile	=	"$directory/$project.prj";

	#### SET INPUTFILE
	$self->inputfile($projectfile);

	#### SET USERNAME, OWNER AND PROJECT
	my $username	=	"testuser";
	$self->username($username);
	# $self->owner($username);
	$self->projectname($project);

	foreach my $workflow (  @$workflows ) {
		my ($workflownumber, $workflowname)	= $workflow =~/^(\d+)-(.+).(wrk|wk|work)$/;
		$self->logDebug("workflowname", $workflowname);
		$self->logDebug("workflownumber", $workflownumber);

		#### SET WORKFILE
		my $wkfile	=	$self->wkfile("$directory/$workflow");
		$self->logDebug("wkfile", $wkfile);
		$self->logDebug("self->wkfile", $self->wkfile());

		#### SAVE WORKFLOW
		$self->saveWorkflow();
		
		#### VERIFY ENTRIES IN TABLES
		my $query	=	qq{SELECT * FROM workflow
WHERE username='$username'
AND projectname='$project'
AND workflowname='$workflowname'
AND workflownumber='$workflownumber'};
		$self->logDebug("query", $query);
		my $workflowdata	=	$self->table()->db()->queryhash($query);
		$self->logDebug("workflowdata", $workflowdata);
		
		#### GET EXPECTED
		my $json	=	$self->getFileContents($wkfile);
		#$self->logDebug("json", $json);
		my $yaml = YAML::Tiny->read($wkfile);
		my $data = $$yaml[0];
		# my $data	=	$self->jsonparser()->decode($json);
		$self->logDebug("data", $data);
		
		### VERIFY
		foreach my $field ( keys %$workflowdata ) {
			if ( $data->{$field} ) {
				ok($data->{$field} eq $workflowdata->{$field}, "loaded field $field");
			}
		}
	}
}

method setJsonParser {
	my $jsonparser	=	JSON->new->allow_nonref;
	$self->jsonparser($jsonparser);
	
	return $jsonparser;
}


}   #### Test::Flow::Project


=head2

method insertTestData ($table, $data) {
	#### SET OWNER
	$self->owner($self->username());
	my $owner = $self->owner();
	$self->logDebug("owner", $owner);

    my $hash = {
        username    =>  $self->username(),
        owner       =>  $self->owner(),
        package 	=>  $self->package(),
        opsdir      =>  $self->opsdir(),
        installdir  =>  $self->installdir(),
        version     =>  "0.3"
    };

	my $table = "package";
    my $fields = $self->table()->db()->fields($table);
    $self->logDebug("fields: @$fields");
    my $insert = '';
    for ( my $i = 0; $i < @$fields; $i++ )
    {
        next if $$fields[$i] eq "datetime";
        my $value = $hash->{$$fields[$i]} ? $hash->{$$fields[$i]} : '';
        $insert .= "'$value',";
    }
    $insert =~ s/,$//;
    $insert .= ", NOW()";
    my $query = qq{INSERT INTO $table VALUES ($insert)};
    $self->logDebug("query", $query);
	
	#### TEST QUERY
    ok($self->table()->db()->do($query), "inserted testversion row into $table");

	#### TEST INSERTED FIELD VALUES
	#### TEST INSERTED FIELD VALUES
	my $where = "";
	foreach my $key ( keys %$hash) {
		$where .=	" AND $key='$hash->{$key}'";
	}
	$where =~ s/^\s+AND/ WHERE/;
	$self->verifyRows($table, $where, "test version row values");
}

method setUpTestDatabase {
    #### LOAD DATABASE FROM SCRATCH
	$self->logDebug("Doing prepareTestDatabase()");
    $self->prepareTestDatabase();

	$self->logDebug("Doing loadDatabase()");
    $self->loadDatabase();
}

method prepareTestDatabase {
    my $database = $self->database();
    my $user = $self->user();
    my $password = $self->password();
	$self->logDebug("database", $database);
	$self->logDebug("user", $user);
	$self->logNote("password not defined or empty") if not defined $password or not $password;

    $self->setDbh({
		database	=>	$database,
		user  		=>  $user,
		password    =>  $password
	});

    #### SET VARIABLES
    my $dbuser = $self->dbuser();
    my $dbpass = $self->dbpass();
    my $privileges = "ALL";
    my $host = "localhost";

    #### DROP DATABASE
	$self->logDebug("Doing dropDatabase()");
    $self->table()->db()->dropDatabase($database) if defined $self->table()->db()->dbh();

    #### CREATE DATABASE
	$self->logDebug("Doing createDatabase()");
    $self->table()->db()->createDatabase($database);
}


method loadDatabase {
#### LOAD DATA INTO DATABASE
    my $dumpfile    = $self->dumpfile();
    $self->logDebug("dumpfile", $dumpfile);
    $self->reloadTestDatabase($dumpfile);
    $self->logDebug("Finished loadDatabase");
}

method setDatabaseHandle {
    #### SET DBH FOR TEST USER
    my $database = $self->database();
    my $user = $self->conf()->getKey("database:TESTUSER");
    my $pass = $self->conf()->getKey("database:TESTPASSWORD");
    $self->setDbh({
        database    =>  $database,
        user        =>  $user,
        password    =>  $pass
    });
}

method setTestDatabaseRow {
	$self->logDebug("");
    $Test::DatabaseRow::dbh = $self->table()->db()->dbh();
}



=cut
