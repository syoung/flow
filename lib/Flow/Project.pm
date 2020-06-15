use MooseX::Declare;
use Getopt::Simple;

use FindBin qw($Bin);
use lib "$Bin/../..";

class Flow::Project with (Util::Logger, Flow::Common) {

#### EXTERNAL
use File::Path;
use JSON;
use Data::Dumper;
use TryCatch;

#### INTERNAL
use Flow::Workflow;
use Flow::App;
use Flow::Parameter;
use Table::Main;

#### Int
has 'printlog'  => ( isa => 'Int', is => 'rw', default  =>  0   );
has 'maxjobs' => ( isa => 'Int', is => 'rw', default  =>  10  );
has 'stagenumber'=> ( isa => 'Int', is => 'rw', default   =>  10  );
has 'ordinal'   => ( isa => 'Int', is => 'rw', default  =>  0   );  
has 'projectnumber'  => ( isa => 'Int|Undef', is => 'rw', default    =>  1 );
has 'epochstarted'  => ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'epochstopped'  => ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'epochduration' => ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'indent'    => ( isa => 'Int', is => 'ro', default => 15);

#### Maybe
has 'epochqueued' => ( isa => 'Maybe', is => 'rw', default => undef );
has 'force'     => ( isa => 'Maybe', is => 'rw', required => 0 );

#### Str
has 'start'   => ( isa => 'Str', is => 'rw', required => 0 );
has 'stop'    => ( isa => 'Str', is => 'rw', required => 0 );
has 'logtype'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"cli"	);
has 'logfile'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'log'		=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);  

# STORED LOGISTICS VARIABLES
has 'owner'	    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'username'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'database'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'projectname'		=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'workflowname'	=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'type'	    => ( isa => 'Str|Undef', is => 'rw', required => 0, documentation => q{User-defined workflow type} );
has 'description'=> ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'notes'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'number'	=> ( isa => 'Str|Undef', is => 'rw', default => undef, required => 0, documentation => q{Set order of appearance: 1, 2, ..., N} );
has 'provenance' => ( isa => 'Str|Undef', is => 'rw', required	=>	0, default => undef);
has 'scheduler'	 => ( isa => 'Str|Undef', is => 'rw', required	=>	0);
has 'samplestring' => ( isa => 'Str|Undef', is => 'rw', required => 0 );

# STORED STATUS VARIABLES
has 'status'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'locked'	    => ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'queued'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'started'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'stopped'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'duration'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );

# TRANSIENT VARIABLES
has 'format'    => ( isa => 'Str', is => 'rw', default => "yaml");
has 'from'		=> ( isa => 'Str', is => 'rw', required => 0 );
has 'to'		=> ( isa => 'Str', is => 'rw', required => 0 );
has 'newname'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'appFile'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'field'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'value'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );

has 'inputfile' => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'projfile'  => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'wkfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'cmdfile' => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'projectfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'logfile'   => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'outputfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'outputdir' => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'dbfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'dbtype'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'database'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'user'      => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'password'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );

#### Obj
has 'workflows'  => ( isa => 'ArrayRef[Flow::Workflow]', is => 'rw', default => sub { [] } );
has 'fields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['username', 'database', 'projectname', 'projectnumber', 'owner', 'description', 'notes', 'outputdir', 'field', 'value', 'projfile', 'wkfile', 'outputfile', 'cmdfile', 'start', 'stop', 'ordinal', 'from', 'to', 'status', 'started', 'stopped', 'duration', 'epochqueued', 'epochstarted', 'epochstopped', 'epochduration', 'log', 'scheduler', 'samplestring', 'maxjobs', 'stagenumber', 'format' ] } );
has 'savefields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['projectname', 'projectnumber', 'owner', 'description', 'notes', 'status', 'started', 'stopped', 'duration', 'locked'] } );
has 'exportfields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['projectname', 'projectnumber', 'owner', 'description', 'notes', 'status', 'started', 'stopped', 'duration', 'provenance'] } );
has 'db'		=> ( isa => 'Any', is => 'rw', required => 0 );
has 'logfh'     => ( isa => 'FileHandle', is => 'rw', required => 0 );
has 'conf' 		=> (
	is =>	'rw',
	isa => 'Conf::Yaml'
);

has 'table'   =>  (
  is      =>  'rw',
  isa     =>  'Table::Main',
  lazy    =>  1,
  builder =>  "setTable"
);

method BUILD ($args) { 
    $self->logDebug("Project::BUILD()");    
    $self->initialise();
}

method initialise {
  $self->logCaller("");

  $self->owner($self->username()) if not defined $self->owner();
  $self->inputfile($self->projfile()) if defined $self->projfile() and $self->projfile() ne "";
  
  $self->logDebug("inputfile must end in '.prj'") and exit
      if $self->inputfile()
      and not $self->inputfile() =~ /\.prj$/;

  $self->logDebug("outputfile must end in '.prj'") and exit
      if $self->outputfile()
      and not $self->outputfile() =~ /\.prj$/;
}

method getopts {
    $self->_getopts();
    $self->initialise();
}

method _getopts {
    #$self->logDebug("Flow::Project::_getopts    \@ARGV: @ARGV");
    my @temp = @ARGV;
    my $args = $self->args();
    
    my $olderr;
    open $olderr, ">&STDERR";	
    open(STDERR, ">/dev/null") or die "Can't redirect STDERR to /dev/null\n";
    my $options = Getopt::Simple->new();
    $options->getOptions($args, "Usage: blah blah");
    open STDERR, ">&", $olderr;

    #$self->logDebug("options->{switch}:");
    #print Dumper $options->{switch};
    my $switch = $options->{switch};
    #print "CLI::Project::switch    ";
    foreach my $key ( keys %$switch ) {
        #print "$key \n" if not defined $switch->{$key};
        #print "CLI::Project::switch    $key : $switch->{$key}\n" if defined $switch->{$key};
        $self->$key($switch->{$key}) if defined $switch->{$key};
    }
    #print "\n";

    @ARGV = @temp;
}

method args {
  my $meta = $self->meta();

  my %option_type_map = (
      'Bool'     => '!',
      'Str'      => '=s',
      'Int'      => '=i',
      'Num'      => '=f',
      'ArrayRef' => '=s@',
      'HashRef'  => '=s%',
      'Maybe'    => ''
  );
  
  my $attributes = $self->fields();
  my $args = {};
  foreach my $attribute_name ( @$attributes ) {
    my $attr = $meta->get_attribute($attribute_name);
    next if not defined $attr or $attr =~ /^\s*$/;
    my $attribute_type  = $attr->type_constraint();        # $self->logDebug("attribute_name $attribute_name attribute_type", $attribute_type);
        
    $attribute_type =~ s/\|.+$//;
    $args -> {$attribute_name} = {  type => $option_type_map{$attribute_type}  };
  }
  #$self->logDebug("args", $args);
  
  return $args;
}

method lock {
  $self->_loadFile() if $self->inputfile();
  $self->locked(1);
  
  $self->logDebug("Locked workflow '"), $self->name(), "'\n";
#        $self->logDebug("self->locked: "), $self->locked(), "\n";
}

method unlock {
  $self->_loadFile() if $self->inputfile();
  $self->locked(0);
  $self->logDebug("Unlocked workflow '"), $self->name(), "'\n";
  #$self->logDebug("self->locked: "), $self->locked(), "\n";
}

method save {
  $self->logDebug("");

  $self->_getopts();
  
  #### READ INPUTFILE
  $self->read();

  #### SET USERNAME
  my $username    =   $self->setUsername();
  $self->logDebug("username", $username);
  
  #### LOAD INTO DATABASE
	$self->projectToDatabase($username, $self);
}


method delete {
  #### READ INPUTFILE
  $self->read();

  #### REMOVE PROJECT FROM ALL DATABASE TABLES
  my $username    =   $self->setUsername();
  my $owner       =   $username;
  my $project     =   $self->name();
  
  #### TABLE: project
  my $table       =   "project";
  my $query       =   qq{DELETE FROM project
WHERE username='$username'
AND name='$project'
};
  $self->logDebug("query", $query);
  $self->table()->db()->do($query);

  #### TABLE: workflow
  $table       =   "workflow";
  $query       =   qq{DELETE FROM $table
WHERE username='$username'
AND project='$project'
};
  $self->logDebug("query", $query);
  $self->table()->db()->do($query);

  #### TABLE: stage
  $table          =   "stage";
  $query       =   qq{DELETE FROM $table
WHERE username='$username'
AND project='$project'
};
  $self->logDebug("query", $query);
  $self->table()->db()->do($query);

  #### TABLE: stageparameter
  $table          =   "stageparameter";
  $query       =   qq{DELETE FROM $table
WHERE username='$username'
AND project='$project'
};
  $self->logDebug("query", $query);
  $self->table()->db()->do($query);

  my $database    =   $self->table()->db()->database();
  print "Project '$project' deleted from database '$database'\n";
}

method newProject {
  #### GET OPTS (E.G., WORKFLOW)
  $self->_getopts();

  my $project		=	$self->name();
  my $inputfile	=	$self->inputfile();
  $self->logDebug("inputfile", $inputfile);
  ($project)		=	$inputfile	=~ /^(.+)\.prj$/ if not defined $project;		
  $self->name($project);
  #$self->logDebug("project", $project);
  print "Project name not defined. Did you provide a project file name?\n" and exit if not defined $project;
  my $description	=	$self->description();
  #$self->logDebug("description", $description);

  $self->_write();
  print "Project file printed: $inputfile\n";
}

method loadScript {
  $self->logDebug("");

  my $cmdfile = $self->cmdfile();
  $self->logDebug("cmdfile", $cmdfile);
  open(FILE, $cmdfile) or die "Can't open cmdfile: $cmdfile\n";
  $/ = undef;
  my $content = <FILE>;
  close(FILE) or die "Can't close cmdfile: $cmdfile\n";
  $/ = "\n";
  $content =~ s/,\\\n/,/gms;
	#$self->logDebug("content", $content);

	my $sections;
    @$sections = split "####\\s+", $content;
	shift @$sections;
	$self->logDebug("sections[0]", $$sections[0]);
	$self->logDebug("no. sections", scalar(@$sections));

	#### SET OUTPUT DIR		
	my $inputfile	=	$self->inputfile();
	my ($outputdir)	=	$inputfile	=~	/^(.+?)\/[^\/]+$/;
	$outputdir		=	"." if not defined $outputdir;

	my $workflownumber		=	0;
	for ( my $i = 0; $i < @$sections; $i++ ) {
		my $section =	$$sections[$i];
    next if $section =~ /^\s*$/;
		
		$workflownumber++;
		$self->logDebug("section $workflownumber", $section);

		my ($workflowname)	=	$section	=~	/^(\S+)/;
		$self->logDebug("workflowname", $workflowname);
		
    require Flow::Workflow;
    my $workflow = Flow::Workflow->new({
			workflowname	  =>	$workflowname,
			workflownumber	=>	$workflownumber,
      table   =>  $self->table()
		});

    $workflow->_loadScript($section);
    $workflow->_write("$outputdir/$workflownumber-$workflowname.wrk");

    #$self->logDebug("workflow:");
    #print $workflow->toString(), "\n";
    $self->_addWorkflow($workflow);
  }
    
	#$self->logDebug("outputfile", $self->inputfile());
  $self->_write();

  return 1;
}

method runProject {
#$self->log(4);
  $self->logDebug("");

  #### READ INPUTFILE
  $self->read();

  #### GET OPTS (E.G., WORKFLOW)
  $self->_getopts();

  #### SET USERNAME AND OWNER
  my $username    =   $self->setUsername();
  my $owner       =   $username;
  my $project     =   $self->name();

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "project not defined\n" and exit if not defined $project;

	my $workflowhashes		=	$self->getWorkflows($username, $project);
	$self->logDebug("workflowhashes", $workflowhashes);

	my $samplehash			=	$self->getSampleHash($username, $project);
	$self->logDebug("samplehash", $samplehash);

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData($username, $project);
	print "*** NUMBER SAMPLES ***", scalar(@$sampledata), "\n" if defined $sampledata;
	print "**** ZERO SAMPLES ****\n" if not defined $sampledata;

	if ( defined $samplehash ) {
		$self->logDebug("samplehash defined. Doing _runWorkflow");
		foreach my $workflowhash ( @$workflowhashes ) {
			$self->_runWorkflow($workflowhash, $samplehash);
		}
	}
	elsif ( defined $sampledata ) {
		$self->logDebug("sampledata defined. Doing _runWorkflow");
		my $maxjobs  =	2;
		if ( not defined $maxjobs ) {
			$self->logDebug("maxjobs not defined. Doing _runWorkflow loop");
		
			foreach my $samplehash ( @$sampledata ) {
				$self->logDebug("Running workflow with samplehash", $samplehash);
				print "Doing _runWorkflow using sample: ", $samplehash->{sample}, "\n";
					foreach my $workflowhash ( @$workflowhashes ) {
						print "Doing workflow: ", $workflowhash->{workflow}, "\n";
						$self->_runWorkflow($workflowhash, $samplehash);
						my $success	=	$self->_runWorkflow($workflowhash, $samplehash);
						$self->logDebug("success", $success);
						
						return if $success == 0;
				}
			}
		}
		else {
			$self->logDebug("maxjobs defined. Doing _runSampleWorkflow");

			foreach my $workflowhash ( @$workflowhashes ) {
				$self->logDebug("DOING _runSampleWorkflow");
				my $success	=	$self->_runSampleWorkflow($workflowhash, $sampledata);
				$self->logDebug("success", $success);
			}
		}
	}
	else {
		print "Running workflows for project: $project\n";
		foreach my $workflowhash ( @$workflowhashes ) {
			$self->_runWorkflow($workflowhash, undef);
		}
		#print "Completed workflow $workflow\n";
	}
}

method getSampleHash ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	
	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	if ( defined $samplestring ) {
		return	$self->sampleStringToHash($samplestring);
	}

	return undef;
}

method sampleStringToHash ($samplehash) {
	my @entries	=	split "\\|", $samplehash;
	#$self->logDebug("entries", \@entries);
	
	my $hash	=	{};
	foreach my $entry ( @entries ) {
		my ($key, $value)	=	$entry	=~ /^([^:]+):(.+)$/;
		$hash->{$key}	=	$value;
	}
	
	return $hash;
}

method getSampleData ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $query		=	qq{SELECT sampletable FROM sampletable
WHERE username='$username'
AND project='$project'};
	$self->logDebug("query", $query);

	my $table	=	$self->table()->db()->query($query);
	$self->logDebug("table", $table);
	return if not defined $table;
	
	$query			=	qq{SELECT * FROM $table
WHERE username='$username'
AND project='$project'};
	$self->logDebug("query", $query);

	my $sampledata	=	$self->table()->db()->queryhasharray($query);
	#$self->logDebug("sampledata", $sampledata);
	
	return $sampledata;
}

method getWorkflows ($username, $projectname) {
		#### GET ALL SOURCES
		my $query = qq{SELECT * FROM workflow
WHERE username='$username'
AND projectname='$projectname'
ORDER BY workflownumber};
	my $workflows = $self->table()->db()->queryhasharray($query);
	$workflows = [] if not defined $workflows;
	
	return $workflows;
}

method runStage {
	#$self->log(4);
    $self->logDebug("");

    #### READ INPUTFILE
    $self->read();

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
    #### SET USERNAME AND OWNER
    my $username    =   $self->setUsername();
    my $owner       =   $username;
    my $project     =   $self->project();
    my $workflow	=	$self->workflow();
    my $stagenumber	=	$self->stagenumber();
	$self->logDebug("username", $username);
    $self->logDebug("project", $project);
    $self->logDebug("workflow", $workflow);
    $self->logDebug("stagenumber", $stagenumber);
	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	my $samplehash		=	undef;
	$samplehash			=	$self->sampleStringToHash($samplestring) if defined $samplestring;
	$self->logDebug("samplehash", $samplehash);

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "project not defined\n" and exit if not defined $project;
	print "workflow not defined\n" and exit if not defined $workflow;
	print "stagenumber not defined\n" and exit if not defined $stagenumber;
	
	#### GET WORKFLOW
	my $workflowhash=	$self->getWorkflow($username, $project, $workflow);		
	$self->logDebug("workflowhash", $workflowhash);
	
	print "Information for workflow not found: $workflow\n" and exit if not defined $workflowhash;
	
	my $success	=	$self->_runStage($workflowhash, $samplehash, $stagenumber);
	$self->logDebug("success", $success);
}

method _runStage ($workflowhash, $samplehash, $stagenumber) {

	$workflowhash->{start}		=	$stagenumber;
	$workflowhash->{stop}		=	$stagenumber;
	$workflowhash->{samplehash}	=	$samplehash;

	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}		=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();

	$workflowhash->{conf}		=	$self->conf();
	$workflowhash->{db}			=	$self->table()->db();
	$workflowhash->{scheduler}	=	$self->scheduler();
	
	require Engine::Workflow;
  my $object	= Engine::Workflow->new($workflowhash);
	return $object->executeWorkflow();
}

method runWorkflow {
	#$self->log(4);
    $self->logDebug("");

    #### READ INPUTFILE
    $self->read();

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
    #### SET USERNAME AND OWNER
    my $username    =   $self->setUsername();
    my $owner       =   $username;
    my $project     =   $self->name();
    my $workflow	=	$self->workflow();
	$self->logDebug("username", $username);
    $self->logDebug("project", $project);
    $self->logDebug("workflow", $workflow);

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "project not defined\n" and exit if not defined $project;
	print "workflow not defined\n" and exit if not defined $workflow;
	
	#### GET WORKFLOW
	my $workflowhash=	$self->getWorkflow($username, $project, $workflow);		
	print "Information for workflow not found: $workflow\n" and exit if not defined $workflowhash;

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData($username, $project);
	#$self->logDebug("Number of samples", scalar(@$sampledata));
	print "Number of samples: ", scalar(@$sampledata), "\n" if defined $sampledata;

	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	if ( defined $samplestring ) {
		my $samplehash		=	$self->sampleStringToHash($samplestring);
		my $success	=	$self->_runWorkflow($workflowhash, $samplehash);
		$self->logDebug("success", $success);
	}
	elsif ( defined $sampledata ) {
		my $maxjobs  =	5;
		if ( not defined $maxjobs ) {
		
			foreach my $samplehash ( @$sampledata ) {
				$self->logDebug("Running workflow with samplehash", $samplehash);
				#print "Running workflow $workflow using sample: ", $samplehash->{sample}, "\n";
				$self->_runWorkflow($workflowhash, $samplehash);
				my $success	=	$self->_runWorkflow($workflowhash, $samplehash);
				$self->logDebug("success", $success);
			}
		}
		else {
			$self->logDebug("DOING _runSampleWorkflow");
			my $success	=	$self->_runSampleWorkflow($workflowhash, $sampledata);
			$self->logDebug("success", $success);
		}
	}
	else {
		#print "Running workflow $workflow\n";
		$self->_runWorkflow($workflowhash, undef);
		#print "Completed workflow $workflow\n";
	}
}

method _runSampleWorkflow ($workflowhash, $sampledata) {
	$self->logDebug("workflowhash", $workflowhash);
	$workflowhash->{start}		=	1;
	$workflowhash->{workflow}	=	$workflowhash->{name};
	$workflowhash->{workflownumber}	=	$workflowhash->{number};

	#### MAX JOBS
	$workflowhash->{maxjobs}	=	$self->maxjobs();
	
	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}		=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();
	$self->logDebug("workflowhash", $workflowhash);
			
	$workflowhash->{conf}		=	$self->conf();
	$workflowhash->{db}			=	$self->table()->db();
	$workflowhash->{scheduler}	=	$self->scheduler();

	require Engine::Workflow;
    my $object	= Engine::Workflow->new($workflowhash);
	
	#### RUN JOBS IN PARALLEL
	$object->runInParallel($workflowhash, $sampledata);
}

method getSampleJobs ($workflowhash, $sampledata) {
	$self->logDebug("workflowhash", $workflowhash);
	
}


method _runWorkflow ($workflowhash, $samplehash) {
	$self->logDebug("workflowhash", $workflowhash);
	$self->logDebug("samplehash", $samplehash);
	
	$workflowhash->{start}		=	1;
	$workflowhash->{samplehash}	=	$samplehash;

	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}		=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();

	$workflowhash->{conf}		=	$self->conf();
	$workflowhash->{db}			=	$self->table()->db();
	$workflowhash->{scheduler}	=	$self->scheduler();
	
	require Engine::Workflow;
    my $object	= Engine::Workflow->new($workflowhash);
	#$self->logDebug("object", $object);
	return $object->executeWorkflow();
}

method getWorkflow ($username, $project, $workflow) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);

    return   $self->table()->db()->queryhash("SELECT * FROM workflow WHERE project='$project' and name='$workflow'");
}

method saveWorkflow {
  $self->logDebug("");

  #### READ INPUTFILE
  $self->read();

  #### SET USERNAME AND OWNER
  my $username    =   $self->setUsername();
  my $owner       =   $username;
  my $projectname     =   $self->projectname();
  $self->logDebug("username", $username);
  $self->logDebug("projectname", $projectname);

  $self->loadFromDatabase($username, $projectname) if not defined $self->workflows();

  #### GET INPUTFILE
  my $workflowfile =   $self->wkfile();
  $self->logDebug("workflowfile", $workflowfile);
  
  #### SET PROJECTFILE
  my ($projectfile) =   $workflowfile =~  /^(.+)\/[^\/]+$/;
  $projectfile    =   "." if not defined $projectfile;
  $projectfile    .=  "/$projectname.prj";
  $self->logDebug("projectfile", $projectfile);
  $self->inputfile($projectfile);
  $self->logDebug("projectfile", $projectfile);
  
  my $workflow = Flow::Workflow->new(
      projectname     =>  $projectname,
      username    =>  $self->username(),
      inputfile   =>  $workflowfile,
      log     	  =>  $self->log(),
      printlog    =>  $self->printlog(),
      conf        =>  $self->conf(),
      table       =>  $self->table()
  );
  $workflow->_getopts();
  $workflow->_loadFile();

  #### VALIDATE
  $self->logCritical("workflow->name not defined") and exit if not defined $workflow->workflowname();

  #### ADD WORKFLOW OBJECT TO PROJECT OBJECT
  $self->_saveWorkflow($workflow);
  
  #### SAVE TO DATABASE
  $workflow->save();

	my $database    =   $self->table()->db()->database();
	print "Workflow '", $workflow->workflowname(), "' saved to project '$projectname' in database '$database'\n";
}

method _saveWorkflow ($workflowobject) {
  $self->logCaller("");
  $self->logDebug("self->table()->db()", $self->table()->db());
  $self->logDebug("workflowobject->workflownumber()", $workflowobject->workflownumber());

  return $self->_insertWorkflow($workflowobject, $workflowobject->workflownumber() - 1) if $workflowobject->workflownumber();
  
  #### INSERT INTO WORKFLOWS
  $workflowobject->workflownumber(scalar(@{$self->workflows()} + 1));
  push @{$self->workflows()}, $workflowobject;

  #### REDO WORKFLOW NUMBERS
  $self->_numberWorkflows();
  
  return scalar(@{$self->workflows()});
}

method loadFromDatabase ($username, $projectname) {
  $self->logDebug("username", $username);
  $self->logDebug("projectname", $projectname);

  #### GET WORKFLOWS		
  my $data    =   $self->table()->db()->queryhash("SELECT * FROM project 
WHERE username='$username'
AND projectname='$projectname'");
  my $workflows = $self->table()->getWorkflowsByProject($data);
  $self->logDebug("no. workflows", scalar(@$workflows));
  #$self->logDebug("workflows", $workflows);
  
  my $workflowobjects 	=	$self->getWorkflowObjectsForProject($workflows, $username);
  $self->logDebug("no. workflowobjects", scalar(@$workflowobjects));
  foreach my $workflowobject ( @$workflowobjects ) {
      #### SAVE WORKFLOW TO DATABASE
      $self->_saveWorkflow($workflowobject);
  }
}
method run {
    $self->logDebug("Project::run(app)");

    $self->_loadFile();
    #$self->logDebug("self->toString(): "), $self->toString(), "\n";
    $self->logDebug("outputdir not defined. Exiting") and exit if not defined $self->outputdir();

    #### WRITE BKP FILE
    my $bkpfile = '';
    $bkpfile .= $self->outputdir() . "/" if $self->outputdir();
    $bkpfile .= $self->name() . ".wk.bkp";
    $self->outputfile($bkpfile);
    $self->_write();

    #### START LOGGER IF NOT STARTED
    my $logfile = $self->setLogFile();
    if ( not $self->logfh() )
    {
        my $logfh;
        open($logfh, ">$logfile") or die "Can't open logfile: $logfile\n";
        $self->logfh($logfh);
    }
    
    #### DO LOGGING
    my $section = "[workflow ". $self->name() . "]\n";
    $self->logDebug($section);
    $self->logDebug();
    $self->logDebug($self->_wiki() . "\n\n");

    #### RUN APPS
    my $workflows = $self->workflows();
    $self->logDebug("No. workflows: " . scalar(@$workflows) . "\n" );
    
    my $start = $self->start();
    $start = 1 if not defined $start or $start =~ /^\s*$/;
    my $stop = $self->stop();
    $stop = scalar(@$workflows) if not defined $stop or $stop =~ /^\s*$/;
    $stop = scalar(@$workflows) if $stop > scalar(@$workflows);
    $self->logDebug("start", $start);
    $self->logDebug("stop", $stop);
    
    #### SET STARTED
    $self->setStarted();
    $self->logDebug("starting workflow " . $self->name()  . "': " . $self->started() . "'\n" );
    
    for ( my $i = $start - 1; $i < $stop; $i++ ) {
        my $workflow = $$workflows[$i];
        $self->logDebug("Running app '"  . $workflow->name() . "'\n" );
        $workflow->logfh($self->logfh());
        $workflow->outputdir($self->outputdir());
        my ($status, $label) = $workflow->run();
        #$self->logDebug("Flow::Project::run    completed", $status);
        #$self->logDebug("Flow::Project::run    label", $label) if defined $label;

        $self->logDebug("Workflow may not have completed successfully.\n\nWorkflow status: $status.\n\nPlease check the logfile", $logfile) if not $status or $status ne "completed";
        
        $self->logDebug("\nWorkflow status", $status) and last if $status ne "completed";
    }

    #### SET STOPPED
    $self->setStopped();
    $self->logDebug("ending workflow '"  . $self->name()  . "': " . $self->started() . "\n" );
    
    #### SET DURATION
    $self->setDuration();
    
    #### END LOG
    $self->logDebug("\nCompleted workflow " . $self->name() . "\n");
    $self->logDebug();
    
    $self->outputfile($self->inputfile());
    $self->_write();
    
    return 1;
}

method setLogFile {
    return $self->logfile() if $self->logfile();
    my $logfile = '';
    $logfile .= $self->outputdir() . "/" if $self->outputdir();
    $logfile .= $self->name() . ".wk.log";
    if ( -f $logfile )
    {
        my $counter = 1;
        my $log = "$logfile.$counter";
        while ( -f $log )
        {
            $counter++;
            $log = "$logfile.$counter";
        }
        `mv $logfile $log`;
    }
    $self->logfile($logfile);
}

method loadCmd {
    #$self->logDebug("Workflow::loadCmd()");
    
    $self->_loadFile();

    my $cmdfile = $self->cmdfile();
    open(FILE, $cmdfile) or die "Can't open cmdfile: $cmdfile\n";
    $/ = undef;
    my $content = <FILE>;
    close(FILE) or die "Can't close cmdfile: $cmdfile\n";
    $/ = "\n";
    $content =~ s/,\\\n/,/gms;

    my @commands = split "\n\n", $content;
    foreach my $command ( @commands )
    {
        next if $command =~ /^\s*$/;
        require Flow::Workflow;
        my $workflow = Flow::Workflow->new(
          table   =>  $self->table()
        );
        $workflow->getopts();
        $workflow->_loadCmd($command);
        #$self->logDebug("app:");
        #print $workflow->toString(), "\n";
        $self->_addWorkflow($workflow);
    }
    
    $self->_write();
    
    return 1;
}

method app {
    $self->logDebug("Workflow::app()");

=HEAD2
    $self->_loadFile() if $self->wkfile();

    require Flow::Workflow;
    my $workflow = Flow::Workflow->new();
    $workflow->getopts();
    #$self->logDebug("app:");
    #print $workflow->toString(), "\n";
    
    $self->logDebug("Please provide '--name' or '--number' argument for app\n") and exit if not $workflow->name() and not $workflow->number();

    #### GET THE PARAM FROM workflows
    my $index;
    $index = $workflow->number() - 1 if $workflow->number();
    $index = $self->_appIndex($workflow) if not $workflow->number();
    $self->logDebug("Can't find app among workflow's workflows:"), $workflow->toString(), "\n\n" and exit if not defined $index;
    #$self->logDebug("index", $index);

    my $workflow = ${$self->workflows()}[$index];
    $self->logDebug("Can't find app number ") . $index + 1 . "\n" and exit if not defined $workflow;
    #$self->logDebug("BEFORE getopts workflow:");
    #print $workflow->toString(), "\n";

    $workflow->getopts();
    #$self->logDebug("AFTER getopts workflow:");
    #print $workflow->toString(), "\n";

    my $command = shift @ARGV;
    #$self->logDebug("command", $command);

    my $return = $workflow->$command();

    $self->_write() if $self->inputfile();
    
    return $return;
    
    
=cut

}

method replace {
    $self->logDebug("Flow::Project::replace()");
    
    $self->_loadFile() if defined $self->workflowfile() and $self->workflowfile();
    
    #$self->logDebug("BEFORE self->toString() :");
    #print $self->toString();

    #### DO PARAMETERS
    my $workflows = $self->workflows();
    my $params = [];
    foreach my $parameter ( @$workflows )
    {
        $parameter->getopts();
        $parameter->replace();
    }
    #$self->logDebug("AFTER self->toString() :");
    #print $self->toString() ;

    $self->outputfile($self->inputfile());
    $self->_write() if $self->outputfile();
}

method loadWorkflow ($workflow) {

	#### READ INPUTFILE
    $self->read();

    $self->logDebug("");        
    $self->_addWorkflow($workflow);
    my $workflowname = $workflow->workflowname();
    $workflowname = "unknown" if not defined $workflowname;

    $self->_write();

    my $workflownumber = $workflow->workflownumber();
    $self->logDebug("Added workflow $workflownumber: '$workflowname'");
    
    return 1;
}

method addWorkflow ($workflowfile) {
  $self->logDebug("workflowfile", $workflowfile);
  
  #### INITIALISE PROJECT FROM FILE
  $self->_loadFile();
  #$self->logDebug("self->toString()");
  #print $self->toString(), "\n";

  $self->logDebug("workflowfile not defined. Exiting") if not defined $workflowfile and not $workflowfile;

  my $workflow = Flow::Workflow->new(
    inputfile =>  $workflowfile,
    table   =>  $self->table()      
  );
  $workflow->getopts();
  $workflow->_loadFile();

  $self->logCritical("workflow->name() not defined") and exit if not defined $workflow->name();

  $self->_addWorkflow($workflow);

  return 1;
}

method _addWorkflow ($workflowobject) {
  $self->logDebug("");

  return $self->_insertWorkflow($workflowobject, $workflowobject->workflownumber() - 1) if $workflowobject->workflownumber();
  
  #### INCREMENT ORDINAL AND SET ON THIS APP
  $workflowobject->workflownumber(scalar(@{$self->workflows()} + 1));
  
  push @{$self->workflows()}, $workflowobject;

  $self->_numberWorkflows();

  #### WRITE TO PROJECT FILE
  $self->_write();
  
  #### CREATE WORKFLOW FILE
  my $workflowname    = $workflowobject->workflowname();
  my $workflownumber  = $workflowobject->workflownumber();
  my $projectfile     = $self->outputfile();
  $self->logDebug("projectfile", $projectfile);
  $projectfile        = $self->inputfile() if not defined $projectfile or $projectfile eq "";
  my ($projectdir)    = $projectfile =~ /^(.+?)\/[^\/]+$/;
  $projectdir =   "." if not defined $projectdir;
  $self->logDebug("projectdir", $projectdir);

  my $workflowfile = "$projectdir/$workflownumber-$workflowname.work";
  $self->logDebug("workflowfile", $workflowfile);
  File::Path::rmtree( $workflowfile ) if -f $workflowfile;
  $workflowobject->export($workflowfile);

  return scalar(@{$self->workflows()});
}

method _insertWorkflow ($workflow, $index) {
  $self->logDebug("index", $index);
  $self->logDebug("scalar self->workflows()", scalar(@{$self->workflows()}));
  splice @{$self->workflows()}, $index, 0, $workflow;
  
  $self->_numberWorkflows($self->workflows());
  
  return $index;
}

method moveWorkflow {
    $self->logDebug("Project::moveWorkflow(workflow, index)");

    $self->_loadFile();

    my $from = $self->from();
    $self->logDebug("from not defined") and exit if not $from;
    $self->logDebug("from out of range (1 - "), scalar(@{$self->workflows()}), ")\n" and exit if $from > scalar(@{$self->workflows()});
    $self->logDebug("from out of range (1 - "), scalar(@{$self->workflows()}), ")\n" and exit if $from < 1;
    

    my $to = $self->to();
    $self->logDebug("to not defined") and exit if not $to;
    $self->logDebug("to out of range (1 - "), scalar(@{$self->workflows()}), ")\n" and exit if $to > scalar(@{$self->workflows()});
    $self->logDebug("to out of range (1 - "), scalar(@{$self->workflows()}), ")\n" and exit if $to < 1;

    #### RETURN IF 'FROM' IS 'TO'
    return 1 if $from == $to;

    #### OTHERWISE, MOVE APP
    my $workflow = splice @{$self->workflows()}, $from - 1, 1;
    print $workflow->wiki();
    splice @{$self->workflows()}, $to - 1, 0, $workflow;
    $self->_numberWorkflows($self->workflows());
    
    $self->_write();
    
    return 1;
}


method deleteWorkflow {
    #$self->logDebug("Project::deleteWorkflow(app)");
    #$self->logDebug("app:");
    #print Dumper $workflow;

    my $inputfile = $self->inputfile;
    #$self->logDebug("self", $self);
    #$self->logDebug("inputfile", $inputfile);

    $self->_loadFile();
    #print $self->toString(), "\n";

    my $workflownumber = $self->workflownumber();

    my $workflow = Flow::Workflow->new(
      workflowname    =>  $self->workflowname(),
      workflownumber  =>  $self->workflownumber(),
      table   =>  $self->table()
    );
    $workflow->getopts();

    my $workflowname;
    ($workflowname, $workflownumber) = $self->_deleteWorkflow($workflow);
    $workflowname = "name unknown" if not defined $workflowname;

    $self->logDebug("Deleted app $workflownumber", $workflowname);

    $self->_write();
    
    return 1;
}

method _numberWorkflows ( $workflows ) {
  for ( my $i = 0; $i < scalar( @$workflows ); $i++ ) {
    my $workflow = $$workflows[$i];
    $workflow->workflownumber($i + 1);
  }
}

method _deleteWorkflow ($workflow) {
    #$self->logDebug("Project::_deleteWorkflow(app)");

    my $index;
    $index = $self->workflownumber() - 1 if $self->workflownumber()
        and $self->workflownumber() !~ /^\s*$/;
    $index = $self->_appIndex($workflow) if not defined $index;
    $self->logDebug("app not found", $workflow)
        and exit if not defined $index;

    $self->logDebug("app not found", $workflow)
        and return 0 if not defined $index;

    $self->logDebug("zero-index '$index' falls after the end of the workflows array (length: "), scalar(@{$self->workflows}), ")\n" and exit if $index > scalar(@{$self->workflows}) - 1;
    my $name = @{$self->workflows}[$index]->name();

    splice @{$self->workflows()}, $index, 1;

    #$self->_orderWorkflows();

    $self->_numberWorkflows($self->workflows());

    return $name, $index + 1;
}

method editWorkflow ($workflow) {
    #$self->logDebug("Project::editWorkflow(app)");
    #$self->logDebug("app:");
    #print Dumper $workflow;
    my $field = $self->field();
    $self->logDebug("field not defined")
        and exit if not defined $field;

    my $inputfile = $self->inputfile;
    #$self->logDebug("self", $self);
    #$self->logDebug("inputfile", $inputfile);

    $self->_loadFile();
    #print $self->toJson(), "\n";
    
    $self->_editWorkflow($workflow);
    #print $self->toJson(), "\n";

    #$self->_orderWorkflows();
    #print $self->toJson(), "\n";
    
    $self->_write();
}

method _editWorkflow ($workflow) {
    #$self->logDebug("Project::editWorkflow(app)");
    #$self->logDebug("app:");
    #print Dumper $workflow;

    $workflow->edit();
    #print $self->toJson(), "\n";

    $self->_write();
}

method desc {
    $self->logDebug("Project::desc()");
    $self->_loadFile();
    
    print $self->toString() and exit if not defined $self->field();
    my $field = $self->field();
    print $self->toJson(), "\n";
    print "$field: " , $self->$field(), "\n";

    return 1;
}

method wiki {
    #$self->logDebug("Project::wiki()");
    $self->_loadFile() if $self->projfile();

    print $self->_wiki();

    return 1;
}


method _wiki {
    #$self->logDebug("Project::_wiki()");
    my $wiki = '';
    $wiki .= "\nProject:\t" . $self->name() . "\n";
    $wiki .= "\t" . $self->status() if $self->status();
    $wiki .= "Started: " . $self->started() . "\n" if $self->started();
    $wiki .= "Stopped: " . $self->stopped() . "\n" if $self->stopped();
    $wiki .= "Duration: " . $self->duration() . "\n" if $self->duration();
    $wiki .= "Status: " . $self->status() . "\n" if $self->status();
    $wiki .= "\n" if $self->started();
    
    #### DO APPS
    my $workflows = $self->workflows();
    foreach my $workflow ( @$workflows )
    {
        $wiki .= $workflow->_wiki();
    }
    
    return $wiki;
}



method edit {
    #### IN CASE workflow IS PART OF project
    $self->getopts();
    
    my $field = $self->field();
    my $value = $self->value();
    if ( not $self->field() ) {
        $self->logDebug("field is not defined. Exiting");
        print "Field is not defined. Exiting\n";
        exit;
    }
    $self->logDebug("field: **$field**");
    $self->logDebug("value: **$value**");
    
    #### ENSURE field IS VALID
    my $valid = 0;
    foreach my $currentfield ( @{$self->fields()} ) {
        #$self->logDebug("currentfield: **$currentfield**");
        $valid = 1 if $field eq $currentfield;
        last if $field eq $currentfield;
    }
    #$self->logDebug("valid", $valid);
    $self->logDebug("Flow::Project::edit    field $field not valid") and exit if not $valid;

    $self->$field($value);
    
    $self->save();
}

method editFile {
    $self->outputfile($self->inputfile()) if not defined $self->outputfile();
    if ( not defined $self->outputfile() ) {
        print "Neither inputfile nor outputfile is defined. Exiting\n";
        $self->logDebug("outputfile not defined. Exiting");
        exit;
    }

    #### IN CASE workflow IS PART OF project
    $self->getopts();
    
    my $field = $self->field();
    my $value = $self->value();
    if ( not $self->field() ) {
        $self->logDebug("field is not defined. Exiting");
        print "Field is not defined. Exiting\n";
        exit;
    }
    $self->logDebug("field: **$field**");
    $self->logDebug("value: **$value**");

    $self->_loadFile() if defined $self->inputfile();
    
    #### ENSURE field IS VALID
    my $valid = 0;
    foreach my $currentfield ( @{$self->fields()} ) {
        #$self->logDebug("currentfield: **$currentfield**");
        $valid = 1 if $field eq $currentfield;
        last if $field eq $currentfield;
    }
    #$self->logDebug("valid", $valid);
    $self->logDebug("Flow::Project::edit    field $field not valid") and exit if not $valid;

    $self->$field($value);
    #$self->logDebug("field $field: "), $self->$field(), "\n";
    
    $self->outputfile($self->inputfile());
    $self->_write();
}

method create {
    #$self->logDebug("Project::create()");
    my $inputfile = $self->inputfile;
    $self->logDebug("inputfile must end in '.prj'") and exit
        if not $inputfile =~ /\.prj$/;
    $self->logDebug("inputfile not defined") and exit
        if not defined $inputfile
        or not $inputfile;
    
    my $name = $self->name;
    $self->logDebug("Please supply 'name' argument") and exit if not $self->name();
    
    $self->_confirm("Outputfile already exists. Overwrite?") if -f $inputfile and not defined $self->force();

    $self->getopts();
    if ( not $self->name() ) {
        my ($name) = $self->inputfile() =~ /([^\/^\\]+)\.prj/;
        $self->name($name);
    }
    
    $self->_write();        

    $self->logDebug("Created project ");
    $self->logDebug("self->name: '" . $self->name() . "'") if $self->name();
    $self->logDebug(": " . $self->inputfile() . "\n\n");
}

method copy {
    #$self->logDebug("Project::copy()");
    $self->_loadFile();
    $self->name($self->newname());

    my $outputfile = $self->outputfile;
    $self->_confirm("Outputfile already exists. Overwrite?") if -f $outputfile and not defined $self->force();

    $self->_write();        
}

method _toExportHash ($fields) {
  #$self->logCaller("");
  #$self->logDebug("fields: @$fields");

  my $hash;
  foreach my $field ( @$fields ) {
      next if ref($self->$field) eq "ARRAY";
      $hash->{$field} = $self->$field();
  }

  #### DO WORKFLOWS
  my $workflows = $self->workflows();
  my $workflowsdata = [];
  foreach my $workflow ( @$workflows )
  {
      push @$workflowsdata, $workflow->exportData();
  }
  #$self->logDebug("workflowsdata:");
  #print Dumper $workflowsdata;

  $hash->{workflows} = $workflowsdata;
  return $hash;
}

method toHash {
    my $hash;
    #$self->logDebug("self->started(): "), $self->started(), "\n";
    foreach my $field ( @{$self->savefields()} ) {
		next if not defined $self->$field();

        next if ref($self->$field) eq "ARRAY";

		$hash->{$field} = $self->$field();
    }

    #### DO WORKFLOWS
    my $workflows = $self->workflows();
	$self->logDebug("no. workflows", scalar(@$workflows));

    my $workflowsdata = [];
    foreach my $workflow ( @$workflows ) {
#			print "workflow->toString():\n";
#            print $workflow->toString(), "\n";
        push @$workflowsdata, $workflow->exportData();
    }

    $hash->{workflows} = $workflowsdata;
    return $hash;
}

method toJson {
    my $hash = $self->toHash();
    my $jsonParser = JSON->new();
	my $json = $jsonParser->pretty->indent->encode($hash);
    return $json;    
}

method exportData {
    return $self->_toExportHash($self->exportfields());
}

method _indentSecond ($first, $second, $indent) {
    $indent = $self->indent() if not defined $indent;
    my $spaces = " " x ($indent - length($first));
    return $first . $spaces . $second;
}
    
method _appIndex ($workflow) {
    #$self->logDebug("Project::_appIndex(app)");
    #$self->logDebug("app:");
    #print $workflow->toString();

    my $counter = 0;
    foreach my $currentname ( @{$self->workflows} )
    {
        if ( $workflow->name() eq $currentname->name() )
        {
            return $counter;
        }
        $counter++;
    }

    return;
}

method _write {
  my $outputfile = $self->outputfile;
  $outputfile = $self->inputfile if not defined $outputfile or not $outputfile;
  $self->logDebug("outputfile", $outputfile);

  my ($basedir) = $outputfile =~ /^(.+)(\/|\\)[^\/^\\]+$/;
  File::Path::mkpath($basedir) if defined $basedir and not -d $basedir;

  my $output  = "";
  my $format  = $self->format();
  #$self->logDebug("format", $format);
  if ( $format eq "yaml" ) {
    require YAML::Tiny;
    my $yaml = YAML::Tiny->new();

    my $data  = $self->toHash();
    #$self->logDebug("data", $data);
    $yaml->[0]  = $data;
    return $yaml->write($outputfile);
  }
  else {
    $output = $self->toJson();        
    open(OUT, ">$outputfile") or die "Can't open outputfile: $outputfile\n";
    print OUT "$output\n";
    close(OUT) or die "Can't close outputfile: $outputfile\n";
  }
}

method read {
  $self->_loadFile();
}

method _loadFile {
  $self->logDebug("");
  my $inputfile = $self->inputfile();
  $self->logDebug("inputfile not specified") and exit if not defined $inputfile;
  return if not -f $inputfile;
    
	my $projectobject;
	my $format	=	$self->format();
	$self->logDebug("format", $format);
	if ( $format eq "yaml" ) {
		require YAML::Tiny;
		my $yaml = YAML::Tiny->read($inputfile) or $self->logCritical("Can't open inputfile: $inputfile") and exit;
		$projectobject 	=	$$yaml[0];
	}
	else {
		#$self->logDebug("inputfile", $inputfile);
		$/ = undef;
		open(FILE, $inputfile) or die "Can't open inputfile: $inputfile\n";
		my $contents = <FILE>;
		close(FILE) or die "Can't close inputfile: $inputfile\n";
		$/ = "\n";
	
		my $jsonParser = JSON->new();
		try {
			$projectobject = $jsonParser->decode($contents);
		}
		catch ($error) {
			print "Improper syntax in JSON file: $inputfile\n";
			print "Error: $error\n";
			print "File contents:\n$contents\n";
			print "Exiting\n";
			exit;
		}
	}
	
  my $workflowsdata = $projectobject->{workflows} || [];
  $self->logDebug("No. workflowsdata", scalar(@$workflowsdata));

  delete $projectobject->{workflows};
  $self->logDebug("projectobject", $projectobject);
  my $fields = $self->fields();
  foreach my $field ( @$fields )
  {
      if ( exists $projectobject->{$field} )
      {
          $self->$field($projectobject->{$field});
      }
  }

  my $workflows = [];
  foreach my $workflowdata ( @$workflowsdata ) {
      my $appdatas = $workflowdata->{apps};
      delete $workflowdata->{apps};
      
      my $workflow = Flow::Workflow->new($workflowdata);
      $workflow->table($self->table());

      my $apps = [];
      foreach my $appdata ( @$appdatas ) {
          my $paramdatas = $appdata->{parameters};
          delete $appdata->{parameters};
          $self->logDebug("appdata", $appdata);
          
          my $app = Flow::App->new($appdata);
          $app->table($self->table());
      
          my $params = [];
          foreach my $paramdata ( @$paramdatas ) {
              my $param = Flow::Parameter->new($paramdata);
              $param->table($self->table());
              push @$params, $param;
          }
          $app->parameters($params);
          
          push @$apps, $app;
      }

      $workflow->apps($apps);

      push @$workflows, $workflow;
  }   

  $self->logDebug("FINAL no. workflows", scalar(@$workflows));
  $self->workflows($workflows);
}

method getWorkflowFiles ($directory) {
    $self->logDebug("directory", $directory);
    sub by_number {
        
        my ($aa) = $a =~ /^(\d+)/; 
        my ($bb) = $b =~ /^(\d+)/; 
        return $aa <=> $bb;
    }

    #### LOAD WORKFLOWS
    my $workflowfiles = $self->getFiles($directory);
    for ( my $i = 0; $i < @$workflowfiles; $i++ ) {
        if ( $$workflowfiles[$i] !~ /\.w.*rk$/ ) {
            splice @$workflowfiles, $i, 1;
            $i--;
        }
    }

    $self->logDebug("BEFORE SORT workflowfiles", $workflowfiles);        
    $workflowfiles = $self->sortWorkflowFiles($workflowfiles);
    $self->logDebug("AFTER SORT workflowfiles", $workflowfiles);        

    return $workflowfiles;
}

method sortWorkflowFiles ($workflowfiles) {
    $self->logDebug("workflowfiles", $workflowfiles);        
    my $by_number  = sub {
        my ($aa) = $a =~ /^(\d+)/; 
        my ($bb) = $b =~ /^(\d+)/; 
        return $aa <=> $bb;
    };

    @$workflowfiles = sort $by_number @$workflowfiles;

    return $workflowfiles;        
}

method _confirm ($message){

    $message = "Please input Y to continue, N to quit" if not defined $message;
    $/ = "\n";
    print "$message\n";
    my $input = <STDIN>;
    while ( $input !~ /^Y$/i and $input !~ /^N$/i )
    {
        print "$message\n";
        $input = <STDIN>;
    }	
    if ( $input =~ /^N$/i )	{	exit;	}
    else {	return;	}
}    

method toString{
    return $self->_toString();
    #$self->logDebug("$output");
}

method export($outputfile) {
    $self->logDebug("");
    #$self->logDebug("outputfile", $outputfile) if defined $outputfile;
    
    $outputfile = $self->outputfile if not defined $outputfile;
    $outputfile = $self->inputfile if not defined $outputfile or not $outputfile;

    my ($basedir) = $outputfile =~ /^(.+)(\/|\\)[^\/^\\]+$/;
    File::Path::mkpath($basedir) if defined $basedir and not -d $basedir;

    my $export = $self->_toExport();        
    open(OUT, ">$outputfile") or die "Can't open outputfile: $outputfile\n";
    print OUT "$export\n";
    close(OUT) or die "Can't close outputfile: $outputfile\n";
}

method _toExport {
    my $hash;
    foreach my $field ( @{$self->exportfields()} )
    {
        #$self->logDebug("field '$field' value: "), $self->$field(), "\n";
        if ( ref($self->$field) ne "ARRAY" )
        {
            $hash->{$field} = $self->$field();
        }
    }

    #### DO WORKFLOWS
    my $workflows = $self->workflows();
    my $workflowsdata = [];
    foreach my $workflow ( @$workflows )
    {
        push @$workflowsdata, $workflow->exportData();
    }
    #$self->logDebug("workflowsdata:");
    #print Dumper $workflowsdata;

    $hash->{workflows} = $workflowsdata;

    my $jsonParser = JSON->new();
	my $json = $jsonParser->pretty->indent->encode($hash);
    return $json;    
}

method _toString {
    my $json = $self->toJson() . "\n";
    my $output = "\n\nProject:\n";
    foreach my $field ( @{$self->savefields()} )
    {
        next if not defined $self->$field() or $self->$field() =~ /^\s*$/;
        $output .= $self->_indentSecond($field, $self->$field(), $self->indent()) . "\n";
    }
    #$output .= "\nWorkflows:\n";
    foreach my $workflow ( @{$self->workflows()} )
    {
        #print Dumper $workflow;
        $output .= "\t" . $workflow->toString() . "\n"; 
    }
    
    #$self->logDebug("output", $output);
    return $output;
}

method _orderWorkflows {
#### REDUNDANT: DEPRECATE LATER
    #$self->logDebug("Project::_orderWorkflows()");

    sub numberOrAbc (){
        #### ORDER BY number IF PRESENT
        #my $aa = $a->number();
        #my $bb = $b->number();
        return $a->number() <=> $b->number()
            if defined $a->number() and defined $b->number()
            and $a->number() and $b->number();
            
        #### OTHERWISE BY ALPHABET
        #my $AA = $a->name();
        #my $BB = $b->name();
        #$self->logDebug("AA", $AA);
        #$self->logDebug("BB", $BB);
        return $a->name() cmp $b->name();
    }

    my $workflows = $self->workflows;
    @$workflows = sort numberOrAbc @$workflows;
    $self->workflows($workflows);
}


   #__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
}


