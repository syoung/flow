use MooseX::Declare;

class Test::Flow::Workflow with Test::Common extends Flow::Workflow {

# Agua::Common::Workflow, 
# Logger, 
# Agua::Common::Database, 
# Agua::Common::Base, 
# Test::Agua::Common

use Data::Dumper;
use Test::More;
use FindBin qw($Bin);
use JSON;

use Conf::Yaml;
use Test::Table::Main;

# INTS
has 'workflowpid'	=> ( isa => 'Int|Undef', is => 'rw', required => 0 );
has 'workflownumber'=>  ( isa => 'Str', is => 'rw' );
has 'start'     	=>  ( isa => 'Int', is => 'rw' );
has 'submit'  		=>  ( isa => 'Int', is => 'rw' );

# STRINGS
has 'dumpfile'		=>  ( isa => 'Str|Undef', is => 'rw' );
has 'database'		=>  ( isa => 'Str|Undef', is => 'rw' );
has 'fileroot'	=> ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'qstat'		=> ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'queue'			=>  ( isa => 'Str|Undef', is => 'rw', default => 'default' );
has 'cluster'		=>  ( isa => 'Str|Undef', is => 'rw' );
has 'username'  	=>  ( isa => 'Str', is => 'rw' );
has 'workflowname'  	=>  ( isa => 'Str', is => 'rw' );
has 'projectname'   	=>  ( isa => 'Str', is => 'rw' );

# OBJECTS
has 'json'		=> ( isa => 'HashRef', is => 'rw', required => 0 );
has 'db'	=> ( isa => 'Agua::DBase::MySQL', is => 'rw', required => 0 );
has 'stages'		=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'stageobjects'	=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'monitor'		=> 	( isa => 'Maybe|Undef', is => 'rw', required => 0 );

# Object
has 'conf'      => ( 
  is => 'rw', 
  isa => 'Conf::Yaml', 
  lazy => 1, 
  builder => "setConf" 
);

method setConf {
  my $conf  = Conf::Yaml->new({
    memory    =>  1,
    backup    =>  1,
    log       =>  $self->log(),
    printlog  =>  $self->printlog()
  });
  
  $self->conf($conf);
}

has 'table' => ( 
  is => 'rw',
  isa => 'Test::Table::Main',
  lazy => 1,
  builder => "setTestTable" 
);

method setTestTable {
  my $table = Test::Table::Main->new({
    conf      =>  $self->conf(),
    log       =>  $self->log(),
    printlog  =>  $self->printlog()
  });

  $self->table($table); 
}

method testAddWorkflow {
	diag("#### addWorkflow");

  #### RESET DATABASE
  $self->table()->setUpTestDatabase();
  $self->table()->setDatabaseHandle();

	my $username = $self->conf()->getKey("database:TESTUSER");
	my $table 	= "workflow";

	my $data = {
		"username"	=>	$username,
		"projectname"	=>	"Project1",
		"workflowname"		=>	"Workflow1",
		"workflownumber"	=>	"1",
		"description"=>	"Workflow description",
		"notes"	    =>	"Notes",
	};
	my $projectname 	= $data->{projectname};
	my $workflowname 		= $data->{workflowname};
	my $workflownumber 		= $data->{workflownumber};

	#### VERIFY ENTRY IS NOT PRESENT
	my $where = "WHERE username='$username' AND projectname='$projectname' AND workflowname='$workflowname' AND workflownumber='$workflownumber'";
	my $method=	"_addWorkflow";
    my $label =     "Entry does not exist in '$table' BEFORE $method";
    $self->table()->verifyNoRows($table, $where, $label);
	
	$where = "WHERE username='$username' AND projectname='$projectname' AND workflowname='$workflowname'";
	my $rowcount_initial = $self->table()->rowCount($table, $where);
        
  $self->table()->_addWorkflow($data);

  my $rowcount_afteradd = $self->table()->rowCount($table, $where);

  ok($rowcount_initial + 1 == $rowcount_afteradd, "One row added. Current rows: $rowcount_afteradd");

	#### TEST INSERTED FIELD VALUES
	my $rows = $self->table()->verifyRows($table, $where, "Workflow exists in 'workflow' table AFTER _addWorkflow");
	
	ok(scalar(@$rows) == 1, "unique row matches added stage");
  my $inserted = $$rows[0];
	$self->logDebug("inserted", $inserted);
	
	ok($inserted->{workflowname}	eq	$data->{workflowname}, "workflowname field value matches");
	ok($inserted->{workflownumber}	eq	$data->{workflownumber}, "workflownumber field value matches");
	ok($inserted->{projectname}	eq	$data->{projectname}, "projectname field value matches");
	ok($inserted->{username}	eq	$data->{username}, "username field value matches");
	ok($inserted->{description}	eq	$data->{description}, "description field value matches");
	ok($inserted->{notes}	eq	$data->{notes}, "notes field value matches");

  $self->table()->_removeWorkflow($data);

  my $rowcount_afterremove = $self->table()->rowCount($table, $where);

  ok($rowcount_afterremove + 1 == $rowcount_afteradd, "One row removed. Current rows: $rowcount_afterremove");

	$self->table()->verifyNoRows($table, $where, "Workflow doesn't exist in 'workflow' table AFTER _removeWorkflow");
}


method testConvert {
  my $testname = "convert";
  diag("#### $testname");

  #### SET OUTDIR
  `rm -fr $Bin/outputs/$testname`;
  `mkdir -p $Bin/outputs/$testname`;

  my $tests = [
    {
      inputfile => "$Bin/inputs/$testname/1-Download-json.wrk",
      expected => "$Bin/inputs/$testname/1-Download-yaml.wrk",
      format    => "json",
      outputfile => "$Bin/outputs/$testname/1-Download.wrk",
    },
    {
      inputfile => "$Bin/inputs/$testname/1-Download-yaml.wrk",
      expected => "$Bin/inputs/$testname/1-Download-json.wrk",
      format    => "yaml",
      outputfile => "$Bin/outputs/$testname/1-Download.wrk",
    }
  ];

  #### SET force TO OVERWRITE
  $self->force(1);

  foreach my $test ( @$tests ) {
    my $inputfile = $test->{inputfile};
    my $expectedfile= $test->{expected};
    my $outputfile = $test->{outputfile};
    my $format  = $test->{format};

    $self->inputfile($inputfile);
    $self->outputfile($outputfile);
    $self->format($format);
    $self->convert();
  
    if ( $format eq "json" ) {
      my $diff = $self->diff($outputfile, $expectedfile);
      ok($diff, "Converted file from format '$format'");
    }
    else {
      my $json      = $self->getFileContents($outputfile);
      my $actual    = $self->jsonparser()->decode($json);
      $json  = $self->getFileContents($expectedfile);
      my $expected  = $self->jsonparser()->decode($json);
      $self->logDebug("expected", $expected);

      is_deeply($actual, $expected, "Converted file from format '$format'");
    }
  }
}


}   #### Test::Agua::Common::Workflow
