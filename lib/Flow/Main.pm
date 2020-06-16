use MooseX::Declare;
use Getopt::Simple;

use FindBin qw($Bin);
use lib "$Bin/../..";

class Flow::Main with (Util::Logger,
  Util::Timer, 
	Flow::Common) {

#### EXTERNAL
use File::Path;
use JSON;
use Getopt::Simple;
use DateTime;
# use DateTime::Format::Duration;
use Data::Dumper;
use YAML;
use Sys::Hostname;
use File::Path qw(make_path remove_tree);
use FindBin qw($Bin);

#### INTERNAL
use Flow::Project;
use Flow::Workflow;
use Flow::App;
use Flow::Parameter;
use Table::Main;
use Virtual::Factory;

#### Int
has 'workflowpid'  =>   ( isa => 'Int|Undef', is => 'rw', required => 0 );
has 'log'		=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);  
has 'printlog'	=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);
has 'maxjobs'	=> ( isa => 'Int', is => 'rw', default 	=> 	10 	);
has 'stagenumber'=> ( isa => 'Int', is => 'rw', default 	=> 	10 	);
has 'number'	=> ( isa => 'Int|Undef', is => 'rw', default    =>  1	);
has 'indent'    => ( isa => 'Int', is => 'ro', default => 4);
has 'epochstarted'	=> ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'epochstopped'  => ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'epochduration'	=> ( isa => 'Int|Undef', is => 'rw', default => undef );

#### Maybe
has 'epochqueued'	=> ( isa => 'Maybe', is => 'rw', default => undef );
has 'force'     => ( isa => 'Maybe', is => 'rw', required => 0 );

#### Bool
has 'dryrun'	  => ( isa => 'Bool', is => 'rw', default 	=> 	0 	);
has 'force'	    => ( isa => 'Bool', is => 'rw', default 	=> 	0 	);
has 'help'		  => ( isa => 'Bool', is => 'rw', required => 0 );

#### Str
has 'logtype'	  => ( isa => 'Str|Undef', is => 'rw', default	=>	"cli"	);
has 'logfile'	  => ( isa => 'Str|Undef', is => 'rw', required	=>	0	);

has 'inputfile' => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'projfile'  => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'wkfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'cmdfile'	  => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'projectfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'logfile'   => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'outputfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'outputdir'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'dbfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'dbtype'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'database'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'user'      => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'password'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'first'		  => ( isa => 'Str', is => 'rw', required => 0 );
has 'last'		  => ( isa => 'Str', is => 'rw', required => 0 );

#### STORED LOGISTICS VARIABLES
has 'owner'	    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'username'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'database'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'project' 	  => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'workflow'	=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'type'	    => ( isa => 'Str|Undef', is => 'rw', required => 0, documentation => q{User-defined workflow type} );
has 'description'=> ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'notes'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'ordinal'	=> ( isa => 'Str|Undef', is => 'rw', default => undef, required => 0, documentation => q{Set order of appearance: 1, 2, ..., N} );
has 'provenance' => ( isa => 'Str|Undef', is => 'rw', required	=>	0, default => undef);
has 'scheduler'	 => ( isa => 'Str|Undef', is => 'rw', required	=>	0);
has 'samplestring' => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'override' => ( isa => 'Str|Undef', is => 'rw', required => 0 );

#### STORED STATUS VARIABLES
has 'status'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'locked'	    => ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'queued'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'started'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'stopped'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'duration'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );

#### TRANSIENT VARIABLES
has 'format'    => ( isa => 'Str', is => 'rw', default => "yaml");
has 'from'		=> ( isa => 'Str', is => 'rw', required => 0 );
has 'to'		=> ( isa => 'Str', is => 'rw', required => 0 );
has 'newname'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'appFile'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'field'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'value'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );

#### Obj
has 'stages'      =>   ( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'workflows'	 => ( isa => 'ArrayRef[Flow::Workflow]', is => 'rw', default => sub { [] } );
has 'fields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { 
	[ 'profiles', 'username', 'database', 'project', 'number', 'workflow', 'owner', 'description', 'notes', 'outputdir', 'field', 'value', 'projfile', 'wkfile', 'outputfile', 'cmdfile', 'first', 'last', 'ordinal', 'from', 'to', 'status', 'started', 'stopped', 'duration', 'epochqueued', 'epochstarted', 'epochstopped', 'epochduration', 'log', 'printlog', 'scheduler', 'samplestring', 'maxjobs', 'stagenumber', 'format', 'dryrun', 'override', 'force' ] } );
has 'logfh'     => ( isa => 'FileHandle', is => 'rw', required => 0 );

has 'conf' 		=> (
    is =>	'rw',
    isa => 'Conf::Yaml'
);

has 'table'		=>	(
	is 			=>	'rw',
	isa 		=>	'Table::Main',
	lazy		=>	1,
	builder		=>	"setTable"
);

has 'util'    =>  (
  is       =>  'rw',
  isa     =>  'Util::Main',
  lazy    =>  1,
  builder  =>  "setUtil"
);

has 'virtual'		=> 	( 
	isa     => 'Any', 
	is      => 'rw', 
	# lazy	  =>	1, 
	# builder	=>	"setVirtual" 
);

#### SET VIRTUALISATION PLATFORM
method setVirtual ( $virtualtype ) {
	$self->logDebug("virtualtype", $virtualtype);

	#### RETURN IF TYPE NOT SUPPORTED	
	$self->logDebug("virtualtype not supported: $virtualtype") and return if $virtualtype !~	/^(aws|openstack|vagrant)$/;

 #### CREATE DB OBJECT USING DBASE FACTORY
  my $virtual = Virtual->new( $virtualtype,
	{
		conf		  =>	$self->conf(),
  	username	=>  $self->username(),
		logfile		=>	$self->logfile(),
		log			  =>	$self->log(),
		printlog	=>	$self->printlog()
  }) or die "Can't create virtualtype: $virtualtype. $!\n";

	$self->logDebug("virtual: $virtual");

	return $self->virtual($virtual);
}

method setUtil () {
  my $util = Util::Main->new({
    conf      =>  $self->conf(),
    log        =>  $self->log(),
    printlog  =>  $self->printlog()
  });

  $self->util($util);  
}
method BUILD ( $inputs ) { 
	my $args = $inputs->{args};
	$self->logDebug("Project::BUILD  args", $args);    
	$self->initialise( $args );
}

method initialise ( $args ) {
	$self->logCaller("");

return; 
	$self->owner($self->username()) if not defined $self->owner();
	$self->inputfile($self->projfile()) if defined $self->projfile() and $self->projfile() ne "";
	
	$self->logDebug("Doing self->setDbh");
	$self->setDbh();

	$self->logDebug("inputfile must end in '.prj'") and exit
		if $self->inputfile()
		and not $self->inputfile() =~ /\.prj$/;

	$self->logDebug("outputfile must end in '.prj'") and exit
		if $self->outputfile()
		and not $self->outputfile() =~ /\.prj$/;
}

method getopts {
	$self->_getopts();
	$self->initialise({});
}

method _getopts {
	my @temp = @ARGV;
	my $args = $self->args();
	
	my $olderr;
	open $olderr, ">&STDERR";	
	open(STDERR, ">/dev/null") or die "Can't redirect STDERR to /dev/null\n";
	my $options = Getopt::Simple->new();
	$options->getOptions($args, "Usage: blah blah");
	open STDERR, ">&", $olderr;

	my $switch = $options->{switch};
	foreach my $key ( keys %$switch ) {
		$self->$key($switch->{$key}) if defined $switch->{$key};
	}

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
		# $self->logDebug("attribute_name", $attribute_name);

		my $attr = $meta->get_attribute($attribute_name);
    next if not defined $attr or $attr =~ /^\s*$/;
		my $attribute_type  = $attr->type_constraint();	

		$attribute_type =~ s/\|.+$//;
		$args -> {$attribute_name} = {  
			type => $option_type_map{$attribute_type}  
		};
	}
	# $self->logDebug("args", $args);
	
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

#### PROJECT

method list {

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	print "username not defined\n" and exit if not defined $username;

	#### GET WORKFLOWS
	my $query	=	qq{SELECT * FROM project
WHERE username='$username'};
	my $projects    =   $self->table()->db()->queryhasharray($query) || [];
  $self->logDebug("projects", $projects);
  
  if ( scalar( @$projects ) == 1 ) {
  	print "One project\n";
  }
  else {
	  print scalar(@$projects) . " projects\n";
  }
  
  for my $project ( @$projects ) {
  	my $output = "Project    : $project->{projectname}\n";
  	$output   .= "Description: $project->{description}\n" if $project->{description};
  	$output   .= "Notes      : $project->{notes}\n" if $project->{notes};

  	my $workflows = $self->table()->getWorkflowsByProject( $project );
  	foreach my $workflow ( @$workflows ) {
  		$output .= "  Workflow $workflow->{workflownumber} :  $workflow->{workflowname}\n";
  	}
  	print "$output\n";
  }
  if ( scalar( @$projects ) == 0 ) {
  	print "No projects loaded. Use 'flow addproject myprojectname' to create a project\n";
  }
}

method listall {

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	print "username not defined\n" and exit if not defined $username;

	#### GET WORKFLOWS
	my $query	=	qq{SELECT * FROM project
WHERE username='$username'};
	my $projects    =   $self->table()->db()->queryhasharray($query) || [];
  $self->logDebug("projects", $projects);
  
  print "Projects:\n";
  for my $project ( @$projects ) {
  	print $self->desc( $project );
  }
}

method describeUsage () {
	return "\nUSAGE: flow (desc|describe) <projectname> [workflowname/workflownumber]\n\n";
}

=head
	Print out detailed contents of all workflows belonging to a project

=cut
method describe ( $projectname = undef, $workflowid = undef ) {
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowid", $workflowid);

	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	print "username not defined\n" and exit if not defined $username;

	#### CHECK INPUTS
	if ( not defined $projectname ) {
		print "*** Project not defined ***\n";
		print $self->describeUsage(); 
		exit ;
	}

	#### GET WORKFLOW NAME IF workflownumber PROVIDED
	my $workflowname   = $self->getWorkflowName( $username, $projectname, $workflowid );
	$self->logDebug("workflowname", $workflowname);

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();

	my $project = $self->getCleanProject( $projectname );
	my $output = $self->orderOutput( $project );

	print $output;
}

method getWorkflowName ( $username, $projectname, $workflowid ) {
	my $workflowname   = $workflowid;
	if ( $workflowname ) {
		if ( $workflowid =~ /^\d+$/ ) {
			my $workflownumber = $workflowid;
			$workflowname = $self->table()->getWorkflowByNumber( $username, $projectname, $workflownumber );
		}		
	}

	return $workflowname;
}

method status ( $projectname = undef, $workflowid = undef ) {

	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	print "username not defined\n" and exit if not defined $username;

	#### CHECK INPUTS
	if ( not defined $projectname ) {
		print "*** Project not defined ***\n";
		print $self->describeUsage(); 
		exit ;
	}

	#### GET WORKFLOW NAME IF workflownumber PROVIDED
	my $workflowname   = $self->getWorkflowName( $username, $projectname, $workflowid );
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowname", $workflowname);
	$self->logDebug("username", $username);

	my $output = "Project: $projectname\n";
	my $workflowobjects = $self->getWorkflows( $username, $projectname ); 
	foreach my $workflowobject ( @$workflowobjects ) {
		if ( defined $workflowname and $workflowobject->{ workflowname } ne $workflowname ) {
			next;
		}
		$output .= "  Workflow " . $workflowobject->{ workflownumber } . " " . $workflowobject->{ workflowname } . "\n"; 

		my $query = "SELECT appnumber, appname, status, queued, started, completed
	FROM stage 
	WHERE projectname='$projectname'
	AND workflowname='$workflowobject->{ workflowname }'
	ORDER BY workflownumber";
		$self->logDebug( "query", $query );

	  my $stagesdata = $self->table()->db()->queryhasharray( $query );
		$self->logDebug( "stagesdata", $stagesdata );
		$stagesdata = $self->getDurations( $stagesdata );

		my $fields = [
			"#", "appname", "status", "duration", "queued", "started", "completed"
		];
		my $lengths = $self->maxLengths( $stagesdata, $fields );
		# $self->logDebug( "lengths", $lengths );
		my $padding = 2;

		$output .=  "    " . $self->formatStatusLine( $lengths, $fields, $fields );

		foreach my $stagedata ( @$stagesdata ) {
			$self->logDebug( "stagedata", $stagedata );
			$stagedata->{ '#' } = $stagedata->{ appnumber };
			my $values = $self->statusValues( $stagedata, $fields );
			$output .= "    " . $self->formatStatusLine( $lengths, $fields, $values );
			# $output .= "\n";
		}
	}

	print $output;
}

method statusValues ( $stagedata, $fields ) {
	my $array = [];
	foreach my $field ( @$fields ) {
		push @$array, $stagedata->{ $field };
	}

	return $array;
}

method formatStatusLine( $lengths, $fields, $values ) {
	# $self->logDebug( "lengths", $lengths );
	# $self->logDebug( "fields", $fields );

	my $line = "";
	my $padding = 2;
	for ( my $i = 0; $i < scalar( @$fields ); $i++ ) {
		my $field = $$fields[ $i ];
		my $value = $$values[ $i ] || "";
		my $maxlength = $lengths->{ $field } + $padding;
		$line .= $value;
		my $gap = $maxlength - length( $value );
		# $self->logDebug( "gap", $gap );
		$line .= " " x $gap;
	}
	$line .= "\n";

	return $line;
}

method getDurations ( $stagesdata ) {
	foreach my $stagedata ( @$stagesdata ) {
		# $self->logDebug( "stagedata", $stagedata, 1 );

		my $completed = $stagedata->{ completed };
		my $started   = $stagedata->{ started };
		# $self->logDebug( "completed", $completed );


		my $duration = $self->getDuration( $completed, $started );
		# $self->logDebug( "duration", $duration );

		$stagedata->{ duration } = $duration;
	}

	return $stagesdata;
}

method maxLengths( $stagesdata, $fields ) {
	$self->logDebug( "stagesdata", $stagesdata );
	# $self->logDebug( "fields", $fields );
	my $limit = scalar( @$fields );
	# $self->logDebug( "limit", $limit );
	my $lengths = {};
	for ( my $i = 0; $i < $limit; $i++ ) {
		my $field = $$fields[ $i ];
		# $self->logDebug( "field", $field );
		my $max = length( $field );
		# $self->logDebug( "max", $max );
		foreach my $stagedata ( @$stagesdata ) {
			# $self->logDebug( "stagedata", $stagedata );
			my $length = length( $stagedata->{ $field } ) || 0;
			# $self->logDebug( "length", $length );
			if ( $length > $max ) {
				$max = $length;
			}
		}
		$lengths->{ $field } = $max;
	}

	return $lengths;
}

method hoursMinsSecs ( $seconds ) {
  $self->logDebug( "seconds", $seconds );
  my $hours = int($seconds / 3600);
  my $minutes = int( ($seconds % 3600) / 60 );
  $seconds = ( ($seconds % 3600) % 60 );

  $hours = $self->padZero($hours, 2);
  $minutes = $self->padZero($minutes, 2);
  $seconds = $self->padZero($seconds, 2);
  
  return "$hours:$minutes:$seconds";
}

method getDuration ( $completed, $started ) {
	$self->logDebug( "completed", $completed );
	$self->logDebug( "started", $started );
	return "" if $self->emptyDate( $completed ) or $self->emptyDate( $started );

	my $completedate = $self->getDatetime( $completed );
	my $startdate = $self->getDatetime( $started );
	# $self->logDebug( "completedate", $completedate );
	# $self->logDebug( "startdate", $startdate );
	# my $difference = $completedate - $startdate;
	# $self->logDebug( "difference", $difference );
	# $self->logDebug( "difference->minutes", $difference->minutes() );

	my $difference = $completedate->delta_ms( $startdate );
	# $self->logDebug( "difference", $difference );
	my $minutes  = $difference->{ minutes };
	$self->logDebug( "minutes", $minutes );
	my $seconds  = $difference->{ seconds };
	$self->logDebug( "seconds", $seconds );
	
	my $totalseconds = $seconds + ( 60 * $minutes );
	my $duration = $self->hoursMinsSecs( $totalseconds );

	return $duration;
}

method emptyDate ( $datetime ) {
	return 1 if not defined $datetime;
	return 1 if $datetime eq "";
	return 1 if $datetime eq "0000-00-00 00:00:00";

	return 0;
}

method getDatetime( $string ) {

	my ( $year, $month, $day, $hour, $minute, $second ) = $string =~ /^(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)$/;
	# $self->logDebug( "year", $year );
	# $self->logDebug( "second", $second );

	return DateTime->new(
    year       => $year,
    month      => $month,
    day        => $day,
    hour       => $hour,
    minute     => $minute,
    second     => $second,
    time_zone  => 'UTC' 
   );
}


=head
	Print out commands for all workflows belonging to a project

=cut
method cli ( $projectname ) {
	$self->logDebug("projectname", $projectname);

	#### SET USERNAME
	my $username    =   $self->setUsername();
	print "username not defined\n" and exit if not defined $username;

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	my $project = $self->getCleanProject( $projectname );
	my $output = "\n# Project: $projectname\n";
	my $workflows = $project->{workflows};
	
	my $workflowindex = 0;
	foreach my $workflow ( @$workflows ) {
		$workflowindex++;
		my $workflowname = $workflow->{workflowname};

		$self->logDebug( "workflow", $workflow );
		$output =~ s/\n\s+$/\n/;
		$output .= "  # Workflow $workflowindex: ";
		$output .= $workflowname;
		$output .= "\n";
		$self->logDebug( "output", $output );
		
		#### HANDLE PROFILE
		my $workflowprofile = $workflow->{profile};
		$self->logDebug( "worfklowprofile", $workflowprofile );
		if ( $workflowprofile and $workflowprofile ne "" ) {
			$output .= "  Profile: $workflowprofile\n";
		}
		
		my $command = "";
		my $apps = $workflow->{apps};
		$self->logDebug( "apps", $apps );
		
		my $profile = Util::Profile->new();

		my $appindex = 0;
		foreach my $app ( @$apps ) {
			$appindex++;
			$command .= "# Stage " . $appindex . "\n";

			my $path = $app->{installdir} . "/" . $app->{location};
			$self->logDebug( "path", $path );
			$command .= $path . " ";
			my $string = $app->{ profile };
			$self->logDebug( "string", $string );
			my $profilehash = $profile->yamlToData( $string );
			$self->logDebug( "profilehash", $profilehash );
			$profile->profilehash( $profilehash );

			my $parameters = $app->{parameters};
			foreach my $parameter ( @$parameters ) {
				$self->logDebug( "parameter", $parameter );
				if ( $parameter->{argument} ) {
					$command .= $parameter->{argument} . " ";
				}

				my $value = $parameter->{ value };
				if ( defined $value ) {
					$value = $profile->replaceString( $value ); 
					$value = $self->replaceWorkflowTags( $username, $projectname, $workflowname, $value );
					$command .= $value . " ";
				}

			}
			$command .= "\n";
		}
		$command =~ s/\n/\n    /g;

		$output .= "    " . $command;
	}

	$output .= "\n";

	print $output;
}

method replaceWorkflowTags ( $username, $projectname, $workflowname, $string  ) {

  # #### GET FILEROOT & USERHOME
  # my $fileroot = $self->util()->getFileroot( $username );  
  # my $userhome = $self->util()->getUserhome( $username );  
  # $self->logDebug( "fileroot", $fileroot );  
  # $self->logDebug( "userhome", $userhome );

  # #### SET OUTPUT DIR
  # my $workflowdir =  "$fileroot/$projectname/$workflowname";

  $string    =~    s/<PROJECT>/$projectname/g;
  $string    =~    s/<WORKFLOW>/$workflowname/g;
  # $string    =~    s/<WORKFLOWDIR>/$workflowdir/g;

  return $string;
}

method getCleanProject ( $projectname ) {

	#### SET USERNAME
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	print "username not defined\n" and exit if not defined $username;

	my $project = $self->table()->getProject( $username, $projectname );
	$self->logDebug("project", $project);
	print "Can't find project: $projectname\n" and exit if not %$project;

	my $workflows = $self->table()->getWorkflowsByProject( $project );
	foreach my $workflow ( @$workflows ) {

		my $apps = $self->table()->getStagesByWorkflow( $workflow );
		foreach my $app ( @$apps ) {
			$self->logDebug("app", $app);

			my $apps = $self->removeEmpty( [ $app ] );
			$app = $$apps[ 0 ];
			my $parameters = $self->table()->getParametersByStage( $app );
			# $self->logDebug("parameters", $parameters);

			$parameters = $self->removeEmpty( $parameters );
			$self->logDebug("BEFORE removeParent    parameters", $parameters);
			$parameters = $self->removeParent( $app, $parameters );
			$self->logDebug("AFTER removeParent    parameters", $parameters, 1);
			# $parameters = $self->orderByNumber( $parameters, "paramnumber" );
			# $self->logDebug("AFTER orderByNumber    parameters", $parameters, 1);

			#### REMOVE OWNER
			my $paramfields = {
				"owner" => 1,
				"paramnumber" => 1,
				# "ordinal" => 1
			};
			$parameters = $self->removeParent( $paramfields, $parameters );
			$self->logDebug("FINAL parameters", $parameters);

			my $appfields = {
				"username" => 1,
				"projectname" => 1,
				"workflowname" => 1,
				"workflownumber" => 1,
			};
			$app = $self->removeParentField( $appfields, $app );

			$app->{parameters} = $parameters;
		}

		$workflow->{apps} = $apps;
	}

	$workflows = $self->removeParent( $project, $workflows );
	$workflows = $self->removeEmpty( $workflows );

	my $projects = $self->removeEmpty( [ $project ] );
	$project = $$projects[ 0 ];
		
	$project->{workflows} = $workflows;

	return $project;	
}



method orderOutput ( $project ) {
	$self->logDebug( "project", $project );
	my $output = "";

	my $workflows = $project->{workflows};
	delete $project->{workflows};
	$self->logDebug( "workflows", $workflows );
	$output .= YAML::Tiny::Dump $project;
	$output =~ s/^\-+\n//;

	#### WORKFLOWS
	$output .= "workflows:\n";			

	#### HANDLE NO WORKFLOWS
	if ( scalar( @$workflows ) == 0 ) {
		$output =~ s/\n$/ []\n/;
	}	

	#### OTHERWISE, PRINT WORKFLOWS
	foreach my $workflow ( @$workflows ) {
		my $apps = $workflow->{ apps };
		$self->logDebug( "apps", $apps );
		delete $workflow->{ apps };
		my $profiles = $workflow->{ profiles };
		$self->logDebug( "profiles", $profiles );
		delete $workflow->{ profiles };
		$self->logDebug( "workflow", $workflow );

		#### WORKFLOW
		my $padding = 2;
		my $workflowtext = YAML::Tiny::Dump $workflow;
		$workflowtext =~ s/^\-+\n//;
		$self->logDebug( "BEFORE padRows    workflowtext", $workflowtext );
		$workflowtext = $self->padRows( $workflowtext, $padding );
		$self->logDebug( "AFTER padRows    workflowtext", $workflowtext );

		$output .= $workflowtext . "\n";

		#### APPS
		$output .= "  apps:\n";

		#### HANDLE NO APPS
		if ( scalar( @$apps ) == 0 ) {
			$output =~ s/\n$/ []\n/;
		}	

		#### OTHERWISE, PRINT APPS
		foreach my $app ( @$apps ) {
			my $parameters = $app->{ parameters };
			$self->logDebug( "parameters", $parameters );
			delete $app->{ parameters };
			my $profile = $app->{ profile };
			$self->logDebug( "profile", $profile );
			delete $app->{ profile };
			my $profilename = $app->{ profilename };
			$self->logDebug( "profilename", $profilename );
			delete $app->{ profilename };

			$padding = 6;
			my $apptext = YAML::Tiny::Dump $app;
			$self->logDebug( "apptext", $apptext );
			$apptext =~ s/^\-+\n//;
			# $self->logDebug( "BEFORE padRows    apptext", $apptext );
			$apptext = $self->padRows( $apptext, $padding );
			$self->logDebug( "AFTER padRows    apptext", $apptext );
			$output .= "    -\n" . $apptext . "\n";

			#### PARAMETERS
			$output .= "      parameters:\n";			
			$padding = 8;
			my $parametertext = YAML::Tiny::Dump $parameters;
			$parametertext =~ s/^\-+\n//;
			# $self->logDebug( "BEFORE padRows    parametertext", $parametertext );
			$parametertext = $self->padRows( $parametertext, $padding );
			$self->logDebug( "AFTER padRows    parametertext", $parametertext );
			$output .= $parametertext . "\n";

			#### PROFILE
			if ( $profilename ) {
				$output .= "      profilename: $profilename\n";			
			}
			$output .= "      profile:\n";			
			$padding = 8;
			my $profiletext = $profile;
			if ( not $profile or $profile =~ /^--- \{\}\s*$/ ) {
				$output =~ s/\n$/ {}\n/; 
			}
			else {
				$profiletext =~ s/^\-+\n//;
				# $self->logDebug( "BEFORE padRows    profiletext", $profiletext );
				$profiletext = $self->padRows( $profiletext, $padding );
				$self->logDebug( "AFTER padRows    profiletext", $profiletext );
				$output .= $profiletext . "\n";				
			}
		}
	}

	return $output;
}

method padRows( $text, $padding ) {
	my @lines = split "\n", $text;
	foreach my $line ( @lines ) {
		$line = " " x $padding . $line;
	}

	return join "\n", @lines;
}

method removeParent ( $higher, $array ) {
	$self->logNote( "higher", $higher );
	$self->logNote( "array", $array );
	for ( my $i = 0; $i < scalar( @$array ); $i++ ) {
		my $entry = $$array[ $i ];
		$self->logNote( "entry", $entry );
		$$array[ $i ] = $self->removeParentField( $higher, $entry );
	}

	$self->logDebug( "RETURNING array", $array );

	return $array;
}

method removeParentField ( $higher, $hash ) {
		
	foreach my $key ( keys %$higher ) {
		$self->logNote( "key '$key'", $hash->{$key} );
		if ( $hash->{$key} ) {
			delete $hash->{$key};
		}
	}

	return $hash;	
}

method removeEmpty ( $array ) {
	$self->logNote( "array", $array );
	foreach my $entry ( @$array ) {
		foreach my $key ( keys %$entry ) {
			$self->logNote( "key '$key'", $entry->{$key} );
			if ( not $entry->{$key} or $entry->{$key} eq "" or $entry->{$key} eq "00-00-00 00:00:00" ) {
				delete $entry->{$key};
			}
		}
	}

	return $array;
}

method orderByNumber( $hasharray, $key ) {
#### TO DO: REMOVE

	# print "******************* hasharray: " . $hasharray . "\n";
	# print "******************* key: " . $key . "\n";
	# # $self->logDebug( "hasharray", $hasharray );
	# # $self->logDebug( "key", $key );

	sub keySort () {
		return ! $a->{ "paramnumber" } cmp $b->{ "paramnumber" };
	}

	@$hasharray = sort keySort @$hasharray;

	return $hasharray;
}

method show ( $projectname ) {
	$self->logDebug("projectname", $projectname);

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();

	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	print "username not defined\n" and exit if not defined $username;

	my $data = {
		username 		=> $username,
		projectname => $projectname
	};

	my $project = $self->table()->getProject( $username, $projectname );
	$self->logDebug("project", $project);

	my $output = "Project: $projectname\n";
	my $workflows = $self->table()->getWorkflowsByProject( $project );
	foreach my $workflow ( @$workflows ) {
		my $workflowobject = Flow::Workflow->new( $workflow );
		$output .= $workflowobject->toString();

		my $apps = $self->table()->getStagesByWorkflow( $workflow );
		foreach my $app ( @$apps ) {
			$self->logDebug("app", $app);
			my $appobject = Flow::App->new( $app );
			my $parameterobjects = [];
			my $parameters = $self->table()->getParametersByStage( $app );
			foreach my $parameter ( @$parameters ) {
				my $parameterobject = Flow::Parameter->new( $parameter );
				$self->logDebug("parameterobject", $parameterobject);
				push @$parameterobjects, $parameterobject;
			}
			$appobject->parameters( $parameterobjects );
			$output .= $appobject->toString();
		}
	}

	print $output;
}

method addProject ( $projectname ) {
	$self->logDebug("projectname", $projectname);
	print "Usage: flow <projectname> [options]" and exit if not defined $	projectname or $self->help();

	#### GET USERNAME
	my $username    		=   $self->setUsername();

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();

  #### GET EXISTING PROJECT
	my $project = $self->table()->getProject( $username, $projectname );
	$self->logDebug("project", $project);
	if ( $project and $project->{projectname} ) {
		print "Project '$projectname' already exists. Use a different name to add a project.\n";
		exit;
	}  
    
	#### GET FIELDS
  my $projectnumber 	=   $self->_setProjectNumber();
	my $description			=		$self->description();
	my $notes						=		$self->notes();
	$self->logDebug("username", $username);
  $self->logDebug("projectnumber", $projectnumber);
	$self->logDebug("description", $description);
  $self->logDebug("notes", $notes);

	#### LOAD INTO DATABASE
	my $projectobject		=	Flow::Project->new({
		conf		    		=>	$self->conf(),
		username	  		=>	$username,
		projectname			=>	$projectname,
    projectnumber 	=>  $projectnumber,
		description			=>	$description,
		notes						=>	$notes
	});

	$self->_addProject( $projectobject );

	#### REPORT
	print "Project '$projectname' added for user '$username'\n";
}

method editProject ( $project ) {
	$self->logDebug("project", $project);
	print "Usage: flow <project> [options]" and exit if not defined $project or $self->help();

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();

	#### GET FIELDS
	my $username    =   $self->setUsername();
	my $description	=		$self->description();
	my $notes				=		$self->notes();
	$self->logDebug("username", $username);
	$self->logDebug("description", $description);
  $self->logDebug("notes", $notes);
    
  my $hash = $self->table()->db()->queryhash("SELECT * FROM project
WHERE username='$username'
AND projectname='$project'");
  $self->logDebug("hash", $hash);

  my $field = $self->field();
  my $value = $self->value();

  $hash->{conf} = $self->conf();
  $hash->{field} = $field;
  $hash->{ value } = $value;

	#### LOAD INTO DATABASE
	my $projectobject		=	Flow::Project->new( $hash );
	$projectobject->edit();

	#### REPORT
	print "Added field '$field' value '$value' to project '$project' for user '$username'\n";
}

method _setProjectNumber {
  my $query = "SELECT max(projectnumber) FROM project";
  my $number = $self->table()->db()->query($query);
  
  if ( not defined $number) {
      $number = 1;
  }
  else {
      $number = $number + 1;
  }
  
  return $number;
}

method _addProject ($projectobject) {
	#### LOAD INTO DATABASE
	my $username	=	$projectobject->username();
	$self->projectToDatabase($username, $projectobject);
}

method loadProject {
	$self->logDebug("");

	$self->_getopts();

	#### GET INPUTFILE        
	my $inputfile	=	$self->inputfile();
	$self->logDebug("inputfile", $inputfile);
	print "Can't find inputfile: $inputfile\n" if not -f $inputfile;

	#### SET USERNAME
	my $username    =   $self->setUsername();
	$self->logDebug("username", $username);
	
	#### LOAD INTO DATABASE
	my $projectobject		=	Flow::Project->new({
		conf		  =>	$self->conf(),
		username	=>	$username,
		inputfile	=>	$inputfile,
		log			  =>	$self->log(),
		printlog	=>	$self->printlog()
	});
	$projectobject->read();
	
	$self->_addProject($projectobject);
}

method deleteProjectUsage () {
	return "\nUSAGE: flow (delp|deleteproject) <projectname>\n\n"; 
}

method deleteProject ( $projectname ) {
	$self->logDebug("projectname", $projectname);

	#### CHECK INPUTS
	if ( not defined $projectname ) {
		print "*** Project not defined ***\n";
		print $self->deleteProjectUsage(); 
		exit ;
	}

	#### REMOVE PROJECT FROM ALL DATABASE TABLES
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	print "Project not defined.\nUSAGE: flow deleteproject <project>\n" and exit if not defined $projectname;
	
	my $query       =   "SELECT projectname FROM project
WHERE username='$username'
AND projectname='$projectname'";
	$self->logDebug("query", $query);
	my $project = $self->table()->db()->query( $query );
	$self->logDebug("project", $project);
	if ( not defined $project ) {
		print "Project '$projectname' not found in database\n";
		exit;
	}

	#### TABLE: project
	$query       =   qq{DELETE FROM project
WHERE username='$username'
AND projectname='$project'
};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);

	#### TABLE: workflow
	$query       =   qq{DELETE FROM workflow
WHERE username='$username'
AND projectname='$project'
};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);

	#### TABLE: stage
	$query       =   qq{DELETE FROM stage
WHERE username='$username'
AND projectname='$project'
};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);

	#### TABLE: stageparameter
	$query       =   qq{DELETE FROM stageparameter
WHERE username='$username'
AND projectname='$project'
};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);

	my $database    =   $self->table()->db()->database();
	print "Deleted project '$project' for user '$username'\n";
}

method runProject ( $projectname ) {
	$self->logDebug("projectname", $projectname);
	
	#### READ INPUTFILE
	#$self->read();

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	my $first				=		$self->first();
	my $dryrun			=		$self->dryrun();
	$self->logDebug("first", $first);
	$self->logDebug("dryrun", $dryrun);

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "projectname not defined\n" and exit if not defined $projectname;

	my $workflowhashes		=	$self->getWorkflows($username, $projectname);
	$self->logDebug("workflowhashes", $workflowhashes);

	my $samplehash			=	$self->getSampleHash($username, $projectname);
	$self->logDebug("samplehash", $samplehash);

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData($username, $projectname);
	print "*** NUMBER SAMPLES ***", scalar(@$sampledata), "\n" if defined $sampledata;
	print "**** NO SAMPLES ****\n" if not defined $sampledata;

	if ( defined $samplehash ) {
		$self->logDebug("samplehash defined. Doing _runWorkflow");
		my $counter = 0;
		foreach my $workflowhash ( @$workflowhashes ) {
			$self->logDebug("samplehash defined. Doing _runWorkflow $counter");

			#### SET DRY RUN
			$workflowhash->{dryrun}		=	$dryrun;
			
			$counter++;
			if ( $first and $counter < $first ) {
				next;
			}
			
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
					my $counter = 0;
					foreach my $workflowhash ( @$workflowhashes ) {
						print "Doing workflow $counter: ", $workflowhash->{workflow}, "\n";
						$counter++;
						if ( $first and $counter < $first ) {
							next;
						}

						$self->_runWorkflow($workflowhash, $samplehash);
						my $success	=	$self->_runWorkflow($workflowhash, $samplehash);
						$self->logDebug("success", $success);
						
						return if $success == 0;
				}
			}
		}
		else {
			$self->logDebug("maxjobs defined. Doing _runSampleWorkflow");

			my $counter = 0;
			foreach my $workflowhash ( @$workflowhashes ) {
				$self->logDebug("DOING _runSampleWorkflow $counter");
				
				$counter++;
				if ( $first and $counter < $first ) {
					next;
				}

				my $success	=	$self->_runSampleWorkflow($workflowhash, $sampledata);
				$self->logDebug("success", $success);
			}
		}
	}
	else {
		print "Running workflows for project: $projectname\n";
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

method sampleStringToHash ($samplestring) {
	my @entries	=	split "\\|", $samplestring;
	$self->logDebug("entries", \@entries);
	
	my $hash	=	{};
	foreach my $entry ( @entries ) {
		my ($key, $value)	=	$entry	=~ /^([^:]+):(.+)$/;
        $self->logDebug("$key: $value");
		$hash->{$key}	=	$value;
	}
	
	return $hash;
}

method overrideHash($override, $target) {
    foreach my $key ( keys %$override ) {
        $target->{$key} = $override->{$key};
    }

    return $target;    
}

method getSampleData ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $query		=	qq{SELECT sampletable FROM sampletable
WHERE username='$username'
AND projectname='$project'};
	$self->logDebug("query", $query);

	my $table	=	$self->table()->db()->query($query);
	$self->logDebug("table", $table);
	return if not defined $table;
	
	$query			=	qq{SELECT * FROM $table
WHERE username='$username'
AND projectname='$project'};
	$self->logDebug("query", $query);

	my $sampledata	=	$self->table()->db()->queryhasharray($query);
	#$self->logDebug("sampledata", $sampledata);
	
	return $sampledata;
}

method getWorkflows ($username, $project) {
		#### GET ALL SOURCES
		my $query = qq{SELECT * FROM workflow
WHERE username='$username'
AND projectname='$project'
ORDER BY workflownumber};
	my $workflows = $self->table()->db()->queryhasharray($query);
	$self->logDebug("workflows", $workflows);
	$workflows = [] if not defined $workflows;
	
	return $workflows;
}

#### WORKFLOW

method getOptions ( $argv, $arguments ) {
	# $self->logDebug("argv", $argv);
	# $self->logDebug("arguments", $arguments);

	my $options = {};

  for (my $i = 0; $i < @$argv; $i++) {
    my $arg = $$argv[$i];

    for (my $k = 0; $k < @$arguments; $k++) {
      my $argument = $$arguments[$k][0];
      my $regex = $$arguments[$k][1];
    
      if ( $arg eq $argument ) {
        if ( $i == @$argv - 1 ) {
        	print "Value missing for argument: $argument\n";
        	exit;
        }
        elsif ( $$argv[$i + 1] !~ /$regex/ ) { 
          print "Wrong format for argument '$argument'. Should be regex: $regex\n";
          exit;
        }
        else {
        	$argument =~ s/^\-+//;
          $options->{$argument} = $$argv[$i + 1];
          $i++;
        }

        last;
      }
    }
  }

  return $options;
}

method getProfileYaml ( $profiles, $profilename ) {
	$self->logDebug( "profilename", $profilename );

	return "" if not $profilename;

	my $profilehash = $self->setProfileHash( $profiles, $profilename );
	$self->logDebug( "profilehash", $profilehash );

	my $yaml = YAML::Tiny->new();
	$$yaml[ 0 ] = $profilehash;
	my $profileyaml = $yaml->write_string( $profilehash );

	return $profileyaml;
}

method addWorkflow ( $projectname, $wkfile ) {
	$self->logDebug("projectname", $projectname);
	$self->logDebug("wkfile", $wkfile);

	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	$self->logDebug("username", $username);

	#### QUIT IF PROJECT NOT FOUND
	if ( not $self->table()->isProject( $username, $projectname ) ) {
		print "Can't find project: $projectname\n";
		exit;
	}

	my $formats = [
		[ "--name", "\\w.*" ],
		[ "--profiles", ".+" ], 
		[ "--profilename", ".+" ], 
	];
	my $options = $self->getOptions( \@ARGV, $formats );
	$self->logDebug("options", $options);
	my $profilefile = $options->{ profiles };
	$self->logDebug( "profilefile", $profilefile );
	my $profilename = $options->{ profilename };
	$self->logDebug( "profilename", $profilename );

	#### DEFAULT profilefile LOCATION
	if ( not defined $profilefile ) {
		my ( $directory ) = $wkfile =~ /^(.*?)\/*[^\/]+$/;
		if ( $directory eq "" ) {
			$directory = ".";
		}
		$profilefile = "$directory/profiles.yml";
	}
	$self->logDebug( "profilefile", $profilefile );

	my $projecthash	=	$self->_getProjectHash($username, $projectname);
	$self->logDebug("projecthash", $projecthash);
	print "Can't find project: $projectname (username: $username)\n" and exit if not defined $projecthash;
	
	my $workflows   =   $self->getProjectWorkflows($username, $projectname);
	my $workflownumber  =   scalar(@$workflows) + 1;
	$self->logDebug("workflownumber", $workflownumber);

	#### GET PROJECT
	$projecthash->{conf}		=	$self->conf();
	$projecthash->{log}			=	$self->log();
	$projecthash->{printlog}	=	$self->printlog();
	my $projectobject			=	Flow::Project->new($projecthash);
	$projectobject->loadFromDatabase($username, $projectname);
	$self->logDebug("COMPLETED CREATE projectobject");
    
	my $workflow = Flow::Workflow->new(
		projectname =>  $projectname,
		username    =>  $self->username(),
  	number      =>  $workflownumber,
		inputfile   =>  $wkfile,
		log     	  =>  $self->log(),
		printlog    =>  $self->printlog(),
		conf        =>  $self->conf(),
		db          =>  $self->table()->db()
	);
	$workflow->_loadFile();
	$workflow->workflownumber($workflownumber);
	$self->logDebug("workflow->workflownumber()", $workflow->workflownumber());

	my $profiles = "";
	$profiles = $self->getFileContents( $profilefile ) if $profilefile; 
	$self->logDebug( "profiles", $profiles );

	$workflow->profiles( $profiles );
	$workflow->profilename( $profilename );

	#### GET WORKFLOW NAME FROM ARGUMENT
	my $workflowname =  $workflow->workflowname();
	if ( defined $options->{name} ) {
		$workflowname = $options->{name};
		$workflow->workflowname( $options->{name} );
	}
	$self->logDebug("workflowname", $workflowname);

	if ( not defined $workflowname or $workflowname eq "" ) {
		( $workflowname ) = $wkfile =~ /([^\/]+)\.wrk$/;
		$self->logDebug("workflowname FROM FILE", $workflowname);
		if ( not defined $workflowname ) {
			print "Workflow name is empty or not defined in file: '$wkfile'\n";
			exit;			
		}
	}
	$workflow->workflowname( $workflowname );

	#### SKIP IF WORKFLOW ALREADY EXISTS
	my $isworkflow = $self->table()->isWorkflow( $username, $projectname, $workflowname ) ;
	$self->logDebug("isworkflow", $isworkflow);
	if ( $isworkflow ) {
		print "Workflow '$workflowname' already exists in project '$projectname'. Use '--name newName' to add workflow\n";
		exit; 
	}
	
	my $trash = "";
	if ( not defined $workflowname ) {
		$self->logDebug("wkfile", $wkfile);
		($trash, $workflowname) = $wkfile =~ /^(\d+-)?([^\/]+)\..{2,4}/;
		$self->logDebug("trash", $trash);
		$self->logDebug("workflowname", $workflowname);
		$workflow->workflowname($workflowname);
	}
	
	$self->logCritical("workflow->workflowname not defined") and exit if not defined $workflow->workflowname();

	#### ADD WORKFLOW OBJECT TO project
	$self->logDebug("SAVING workflow->number()", $workflow->workflownumber());
	$projectobject->_saveWorkflow($workflow);

	#### SAVE project TO DATABASE
	$self->projectToDatabase($username, $projectobject);
	
	#### SAVE workflow TO DATABASE
	my $success = $workflow->save();

	if ( $success ) {
		print "\nAdded workflow '$workflowname' at number $workflownumber in project '$projectname' for user '$username'\n\n";
	}
	else {
		print "\n*** ERROR *** Failed to add workflow '$workflowname' to project '$projectname'\n\n";
	}
}

method deleteWorkflowUsage () {
	return "\nUSAGE: flow (delw|deleteworkflow) <projectname> <workflowname/workflownumber>\n\n"; 
}

method deleteWorkflow ( $projectname = undef, $workflowid = undef) {
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowid", $workflowid);

	#### CHECK INPUTS
	if ( not defined $projectname ) {
		print "*** Project not defined ***\n";
		print $self->deleteWorkflowUsage(); 
		exit ;
	}
	if ( not defined $workflowid ) {
		print "*** Workflow not defined ***\n";
		print $self->deleteWorkflowUsage(); 
		exit ;
	}

	#### REMOVE PROJECT FROM ALL DATABASE TABLES
	my $username    =   $self->setUsername();
	my $owner       =   $username;

	#### GET WORKFLOW NAME IF workflownumber PROVIDED
	my $workflowname   = $workflowid;
	if ( $workflowid =~ /^\d+$/ ) {
		my $workflownumber = $workflowid;
		$workflowname = $self->table()->getWorkflowByNumber( $username, $projectname, $workflownumber );
	}
	$self->logDebug("workflowname", $workflowname);
	print "Can't find workflow '$workflowid' in project '$projectname'\n" and exit if not $workflowname;

	#### VERIFY WORKFLOW EXISTS
	my $query       =   "SELECT * FROM workflow
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'";
	$self->logDebug("query", $query);
	my $workflow = $self->table()->db()->queryhash( $query );
	$self->logDebug("workflow", $workflow);
	if ( not defined $workflow ) {
		print "No workflow in project '$projectname' with number '$workflowname'\n";
		exit;
	}
	my $workflownumber = $workflow->{workflownumber};

	$query       		=   qq{DELETE FROM workflow
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);

	#### TABLE: stage
	$query       =   qq{DELETE FROM stage
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);

	#### TABLE: stageparameter
	$query       =   qq{DELETE FROM stageparameter
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);

	#### DECREMENT workflownumber FOR ALL WORKFLOWS 
	#### WITH number > DELETED WORKFLOW number
	my $workflows = $self->table()->db()->queryhasharray("SELECT * FROM workflow
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
ORDER BY workflownumber");
	$self->logDebug("workflows", $workflows);

	for my $workflow ( @$workflows ) {
		if ( $workflow->{workflownumber} > $workflownumber ) {
			my $updatednumber = $workflow->{workflownumber} - 1;

			#### TABLE: workflow
			$query = "UPDATE workflow
SET workflownumber=$updatednumber
WHERE username='$username'
AND projectname='$projectname'
AND workflowname='$workflowname'
AND workflownumber=$workflownumber";
			$self->logDebug("query", $query);
			$self->table()->db()->do( $query );

			#### TABLE: stage
			$query = "UPDATE stage
SET workflownumber=$updatednumber
WHERE username='$username'
AND projectname='$projectname'
AND workflownumber=$workflownumber";
			$self->logDebug("query", $query);
			$self->table()->db()->do( $query );

			$query = "UPDATE stageparameter
SET workflownumber=$updatednumber
WHERE username='$username'
AND projectname='$projectname'
AND workflownumber=$workflownumber";
			$self->logDebug("query", $query);
			$self->table()->db()->do( $query );
		}
	}

	print "Deleted workflow '$workflowname' in project '$projectname' for user '$username'\n";
}

method insertWorkflow ( $project, $wkfile, $workflownumber ) {
	$self->logDebug("project", $project);
	$self->logDebug("wkfile", $wkfile);
	$self->logDebug("workflownumber", $workflownumber);
  $self->logDebug("self->table()->db()", $self->table()->db());        

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();

	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	$self->logDebug("username", $username);

	my $projecthash	=	$self->_getProjectHash($username, $project);
	$self->logDebug("projecthash", $projecthash);
	print "Can't find project: $project (username: $username)\n" and exit if not defined $projecthash;
	
  my $workflows   =   $self->getProjectWorkflows($username, $project);

	#### CREATE PROJECT OBJECT
	$projecthash->{conf}			=	$self->conf();
	$projecthash->{log}				=	$self->log();
	$projecthash->{printlog}	=	$self->printlog();
	$projecthash->{db}				=	$self->table()->db();
	my $projectobject					=	Flow::Project->new($projecthash);
  $projectobject->loadFromDatabase($username, $project);
  $self->logDebug("COMPLETED CREATE projectobject");
	$self->logDebug("BEFORE Flow::Workflow->new    self->table()->db()", $self->table()->db());        

	#### LOAD WORKFLOW TO BE INSERTED
	my $workflow = Flow::Workflow->new(
		project     =>  $project,
		username    =>  $self->username(),
    number      =>  $workflownumber,
  	inputfile   =>  $wkfile,
		log     		=>  $self->log(),
		printlog    =>  $self->printlog(),
		conf        =>  $self->conf(),
		db          =>  $self->table()->db()
	);
	$workflow->_getopts();
	$workflow->_loadFile();
  $workflow->number($workflownumber);
  $self->logDebug("workflow->number()", $workflow->number());
    
	#### GET WORKFLOW NAME
	my $workflowname = $workflow->getNameFromFile( $wkfile );
	$workflow->name($workflowname);
	$self->logDebug("workflowname", $workflowname);
	
	# #### ADD WORKFLOW OBJECT TO PROJECT OBJECT
 #  $self->logDebug("SENDING workflow->number()", $workflow->number());
	# $projectobject->_saveWorkflow($workflow);

	#### SAVE TO project TABLE
	$self->projectToDatabase($username, $projectobject);
	
	#### SAVE TO workflow, stage AND stagenumber TABLES
	my $workflowobjects = $projectobject->workflows();
	print "# workflowobjects " . scalar( @$workflowobjects ) . "\n";

	$self->logDebug("# workflowobjects", scalar( @$workflowobjects ) );
	for my $workflowobject ( @$workflowobjects ) {
		$workflowobject->save();
	}

	print "Inserted workflow '$workflowname' at number $workflownumber in project '$project' for user '$username'\n";
}

method runWorkflow ( $projectname, $workflowid ) {
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;

	#### GET WORKFLOW NAME IF workflownumber PROVIDED
	my $workflowname   = $workflowid;
	if ( $workflowid =~ /^\d+$/ ) {
		my $workflownumber = $workflowid;
		$workflowname = $self->table()->getWorkflowByNumber( $username, $projectname, $workflownumber );
	}
	$self->logDebug("workflowname", $workflowname);

	my $formats = [
		[ "--dryrun" ],
	];
	my $options = $self->getOptions( \@ARGV, $formats );
	$self->logDebug("options", $options);

	# #### GET OPTS (E.G., WORKFLOW)
	# $self->_getopts();
	
	my $dryrun			=		$self->dryrun();
	my $first				=		$self->first() || 1;
	$self->logDebug("dryrun", $dryrun);
	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowname", $workflowname);
	$self->logDebug("first", $first);
	
	#### SET WORKFLOW HASH
	my $workflowhash=	$self->getWorkflow( $username, $projectname, $workflowname );	
	print "Project '$projectname' workflow not found: $workflowname\n" and exit if not defined $workflowhash or not %$workflowhash;
	$workflowhash->{dryrun}		=	$dryrun;
	$workflowhash->{first}		=	$first;
	$self->logDebug( "workflowhash", $workflowhash, 1 );

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData( $username, $projectname );
	print "Number of samples: ", scalar( @$sampledata ), "\n" if defined $sampledata;

	#### SET STAGES
	my $stages = [];
	if ( not $sampledata ) {
		my $samplehash = $self->getSampleHash();	
		$stages = $self->setStages( $workflowhash, $samplehash )
	}
	else {
		foreach my $samplehash ( @$sampledata ) {
			$self->logDebug("Running workflow with samplehash", $samplehash);

			my $samplestages = $self->setStages( $workflowhash, $samplehash );		
			push ( @$stages, @$samplestages ) if @$samplestages;
		}
	}

	# $self->logDebug( "stages", $stages );
	$self->logDebug( "# stages", scalar( @$stages ) );

	my $success = $self->runStages( $stages, $dryrun );
	$self->logDebug( "success", $success );

	# my $samplestring	=	$self->samplestring();
	# $self->logDebug("samplestring", $samplestring);
	# if ( defined $samplestring ) {
	# 	my $samplehash		=	$self->sampleStringToHash($samplestring);
	# 	my $success	=	$self->_runWorkflow( $hosttype, $runtype, $workflowhash, $samplehash );
	# 	$self->logDebug("success", $success);
	# }
	# elsif ( defined $sampledata ) {
	# 	my $maxjobs  =	5;
	# 	if ( not defined $maxjobs or $runtype eq "shell" ) {
		
	# 		foreach my $samplehash ( @$sampledata ) {
	# 			$self->logDebug("Running workflow with samplehash", $samplehash);
	# 			#print "Running workflow $workflowname using sample: ", $samplehash->{sample}, "\n";

	# 			#### ????
	# 			# $self->_runWorkflow($hosttype, $runtype, $workflowhash, $samplehash);

	# 			my $success	=	$self->_runWorkflow( $hosttype, $runtype, $workflowhash, $samplehash );
	# 			$self->logDebug("success", $success);
	# 		}
	# 	}
	# 	else {
	# 		$self->logDebug("DOING _runSampleWorkflow");
	# 		my $success	=	$self->_runSampleWorkflow( $hosttype, $runtype, $workflowhash, $sampledata );
	# 		$self->logDebug("success", $success);
	# 	}
	# }
	# else {
	# 	#print "Running workflow $workflowname\n";
	# 	$self->_runWorkflow( $hosttype, $runtype, $workflowhash, undef );
	# 	#print "Completed workflow $workflowname\n";
	# }
}

method getSampleHash () {
	my $samplehash = undef;
	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	if ( $samplestring ) {
		$samplehash		=	$self->sampleStringToHash( $samplestring );
	}

	return $samplehash;
}

method stageFactory ( $stage ) {
	my $profilehash = $stage->{profilehash};
	# $self->logDebug( "profilehash", $profilehash );

	my $profile = Util::Profile->new();
	$profile->profilehash( $profilehash );

	my $runtype = $profile->getProfileValue( "run:type" );
	$runtype = "Shell" if not $runtype;
	my $hostname = $profile->getProfileValue( "host:name" );
	$hostname = "Local" if not $hostname;
	my $virtual = $profile->getProfileValue( "virtual" );
	$virtual = "Local" if not $virtual;
	$self->logDebug( "runtype", $runtype );
	$self->logDebug( "hostname", $hostname );
	$self->logDebug( "virtual", $virtual );

	my $hosttype = $self->getHostType( $hostname, $virtual );
	$self->logDebug( "hosttype", $hosttype );

#### MONITOR IS CREATED BY Monitor::Factory BASED ON
#### VALUE OF run:type:scheduler

  # #### GET MONITOR
  # $self->logDebug( "BEFORE monitor = self->updateMonitor()" );
  # my $monitor  =   undef;
  # $monitor = $self->updateMonitor();
  # $self->logDebug( "AFTER XXX monitor = self->updateMonitor()" );

  $hosttype = $self->cowCase( $hosttype );
  $runtype = $self->cowCase( $runtype );
  print "Engine::Workflow    runtype: $runtype\n";
  print "Engine::Workflow    hosttype: $hosttype\n";

  my $location    = "$Bin/../../Engine/$hosttype/$runtype/Stage.pm";
  $self->logDebug( "location", $location );
  my $class          = "Engine::" . $hosttype . "::" . $runtype . "::Stage";
  require $location;

  return $class->new( $stage );
}

method getHostType ( $hostname, $virtual ) {
	
	return "Remote" if defined $virtual;

	# use Sys::Hostname;
  my $thishost = hostname || "";

	$self->logDebug( "thishost", $thishost );
	my $isremote = 0;
	if ( $hostname ne "localhost" ) {
	    if ( $thishost and $hostname ) {
		if ( $hostname ne $thishost ) {
		    $isremote = 1;
		}
	    }
	    else {
		$isremote = 1;
	    }
	}
	$self->logDebug( "isremote", $isremote );
  my $hosttype = "Local";
  $hosttype = "Remote" if $isremote;

  return $hosttype;
}

method cowCase ( $string ) {
	return undef if not $string;

  return uc( substr( $string, 0, 1) ) . substr( $string, 1);
}

method setStages ( $workflowhash, $samplehash ) {
  
  # $self->logGroup( "Flow::Main::setStages" );
  $self->logDebug( "workflowhash", $workflowhash );
  $self->logDebug( "samplehash", $samplehash );

  my $username             =    $workflowhash->{username};
  my $projectname          =    $workflowhash->{projectname};
  my $workflowname         =    $workflowhash->{workflowname};
  my $workflownumber       =    $workflowhash->{workflownumber};
  $self->logDebug("username", $username);
  $self->logDebug("projectname", $projectname);
  $self->logDebug("workflowname", $workflowname);
  
  #### SET STAGES
  my $stages = $self->table()->getStagesByWorkflow( $workflowhash );
  $self->logDebug("Total stages", scalar(@$stages) );

  #### GET STAGE PARAMETERS FOR THESE STAGES
  $stages = $self->setStageParameters( $stages, $workflowhash );
  
  #### SET START AND STOP
  my $first = $workflowhash->{ first };
  my $last  = $workflowhash->{ last };
  $self->logDebug( "first", $first );
  $self->logDebug( "last", $last );

  if ( not defined $first or not defined $last ) {
		( $first, $last ) = $self->setFirstLast( $stages );
  }
  $self->logDebug( "first", $first );
  $self->logDebug( "last", $last );

  if ( not defined $first or not defined $last ) {
    print "First or last stage missing. Skipping stages for workflow: $workflowname\n";
    return [];
  }
  
  #### GET FILEROOT & USERHOME
  my $fileroot = $self->util()->getFileroot( $username );  
  my $userhome = $self->util()->getUserhome( $username );  
  $self->logDebug( "fileroot", $fileroot );  
  $self->logDebug( "userhome", $userhome );

  #### SET OUTPUT DIR
  my $outputdir =  "$fileroot/$projectname/$workflowname";

  #### SET WORKFLOW PROCESS ID
  $self->workflowpid($$);  
  my $workflowpid = $self->workflowpid();
  
  # #### GET ENVIRONMENT VARIABLES
  # my $envar = $self->envar();

  #### LOAD STAGE OBJECT FOR EACH STAGE TO BE RUN
  my $stageobjects = [];
  for (  my $counter = $first - 1; $counter < $last; $counter++ ) {
    my $stage = $$stages[$counter];
    $self->logNote( "stage", $stage );
    
    my $stagenumber  =  $stage->{appnumber};
    my $stagename    =  $stage->{appname};    
    my $successor    =  $stage->{successor};
    $self->logDebug( "successor", $successor ) if defined $successor and $successor ne "";
    
    $stage->{stageparameters} = [] if not defined $stage->{stageparameters};

    #### GET PROFILEHASH
    my $profileyaml = $stage->{profile};
    $self->logDebug( "profileyaml", $profileyaml );
    my $profile = Util::Profile->new();
		$stage->{profilehash}  =    $profile->yamlToData( $profileyaml );

    $stage->{username}     =    $username;
    $stage->{workflowpid}  =    $workflowpid;
    $stage->{table}        =    $self->table();
    $stage->{conf}         =    $self->conf();
    $stage->{fileroot}     =    $fileroot;
    $stage->{userhome}     =    $userhome;

    #### MAX JOBS
    $stage->{maxjobs}         =    $self->maxjobs();

    #### SAMPLE HASH
    $stage->{samplehash}      =    $samplehash;
    $stage->{outputdir}       =    $outputdir;

    #### LOG
    $stage->{log}             =    $self->log();
    $stage->{printlog}        =    $self->printlog();
    $stage->{logfile}         =    $self->logfile();

    my $stageobject = $self->stageFactory( $stage );

    #### NEAT PRINT STAGE
    #$stageobject->toString();

    push @$stageobjects, $stageobject;
  }

  $self->logDebug( "final no. stageobjects", scalar( @$stageobjects ) );
  
  # $self->logGroupEnd( "Flow::Main::setStages" );

  return $stageobjects;
}

method setStageParameters ($stages, $workflowhash) {
  #### GET THE PARAMETERS FOR THE STAGES WE WANT TO RUN
  #$self->logDebug("stages", $stages);
  #$self->logDebug("data", $workflowhash);
  
  my $first = $workflowhash->{first} || 1;
  $first--;
  for ( my $i = $first; $i < @$stages; $i++ ) {
    my $keys = ["username", "projectname", "workflowname", "appname", "appnumber"];
    my $where = $self->table()->db()->where($$stages[$i], $keys);
    my $query = qq{SELECT * FROM stageparameter
$where AND paramtype='input'
ORDER BY ordinal};
    # $self->logDebug("query", $query);

    my $stageparameters = $self->table()->db()->queryhasharray($query);
    # $self->logNote("stageparameters", $stageparameters);
    $$stages[$i]->{stageparameters} = $stageparameters;
  }
  
  return $stages;
}

method setFirstLast ( $stages ) {
  $self->logDebug("# stages", scalar(@$stages));
  $self->logDebug("stages is empty") and return if not scalar(@$stages);

  my $first = $self->first();
  my $last = $self->last();
  $self->logDebug("self->first", $self->first());
  $self->logDebug("self->last", $self->last());

  #### SET DEFAULTS  
  $first  =  1 if not defined $first;
  $last   =  scalar(@$stages) if not defined $last;
  $self->logDebug("first", $first);
  $self->logDebug("last", $last);

  $self->logDebug("first not defined") and return if not defined $first;
  $self->logDebug("first is non-numeric: $first") and return if $first !~ /^\d+$/;

  if ( $first > @$stages ) {
    print "Stage first ($first) is greater than the number of stages: " . scalar(@$stages) . "\n";
    $self->logDebug("Stage first ($first) is greater than the number of stages");
    return;

  }

  if ( defined $last and $last ne '' ) {
    if ( $last !~ /^\d+$/ ) {
      $self->logDebug("Stage last is non-numeric: $last");
      return;
    }
    elsif ( $last > scalar(@$stages) ) {
      print "Stage last ($last) is greater than total stages: " . scalar( @$stages ) . "\n";
      $self->logDebug("Stage last ($last) is greater than total stages: " . scalar(@$stages) );
      return;
    }
  }
  else {
    $last = scalar( @$stages );
  }
  
  if ( $first > $last ) {
    print "Stage first ($first) is greater than stage last ($last)\n";
    $self->logDebug("first ($first) is greater than last ($last)");
    return;
  }

  $self->logNote("$$ Setting first: $first");  
  $self->logNote("$$ Setting last: $last");
  
  $self->first( $first );
  $self->last( $last );
  
  return ( $first, $last );
}

#### MOVE TO runStages

  # #### VERIFY THAT PREVIOUS STAGE HAS STATUS completed
  # my $force = $self->force();
  # $self->logDebug( "force", $force );
  # my $previouscompleted = $self->checkPrevious($stages, $workflowhash);
  # $self->logDebug("previouscompleted", $previouscompleted);
  # return [] if not $previouscompleted and not $force;


#### MOVE TO runStages  GET SCHEDULE INFO FROM PROFILE

    # #### SET CLUSTER
    # $stage->{cluster}      =    $cluster;

    # #### SET SCHEDULER
    # $stage->{scheduler}    =  $scheduler;
    
    # #### SET MONITOR
    # $stage->{monitor} = $monitor;

    # # #### SLOTS
    # # $stage->{slots}      =  $slots;

    # #### QUEUE
    # $stage->{qsuboptions}      =    $qsuboptions;

    # $stage->{qsub}      =    $self->conf()->getKey( "scheduler:QSUB" );
    # $stage->{qstat}      =    $self->conf()->getKey( "scheduler:QSTAT" );

    # #### SET SGE ENVIRONMENT VARIABLES
    # $stage->{envar} = $envar;
    
method runStages ( $stages, $dryrun ) {
    $self->logDebug("no. stages", scalar(@$stages));
    $self->logDebug( "dryrun", $dryrun );

    # #### SET EXCHANGE   
    # my $exchange = $self->conf()->getKey("core:EXCHANGE");
    # $self->logDebug("exchange", $exchange);
    
    # #### SELF IS SIPHON WORKER
    # my $worker     =    0;
    # $worker        =    1 if defined $self->worker();
    # $self->logDebug("worker", $worker);

    for ( my $stagecounter = 0; $stagecounter < @$stages; $stagecounter++ ) {
  
      $self->logDebug("stagecounter", $stagecounter);
      my $stageobject = $$stages[$stagecounter];
    	$self->logDebug( "stageobject->{ stagename }", $stageobject->{ stagename } );
      # $self->logDebug( "stageobject", $stageobject, 1 );

      if ( $stagecounter != 0 ) {
          my $ancestor = $stageobject->getAncestor();
          $self->logDebug("ancestor", $ancestor);
          my $status = $stageobject->getStatus();
          $self->logDebug("status", $status);
          next if $status eq "skip"
      }

      my $username         =    $stageobject->username();
      my $projectname      =    $stageobject->projectname();
      my $workflowname     =    $stageobject->workflowname();
      my $stagenumber      =    $stageobject->appnumber();
      my $stagename        =    $stageobject->appname();

      #### LAUNCH VM IF NOT STARTED, OTHERWISE GET IP ADDRESS, ETC.
 			$stageobject = $self->launchVM( $stageobject );
 			if ( not defined $stageobject ) {
 				$self->logError( "stageobject", $stageobject, 1 );
 				print "Failed to launchVM\n";
 				exit;
 			}

      #### SET STAGE START TIME
      my $mysqltime        =    $self->getMysqlTime();
      $self->logDebug("mysqltime", $mysqltime);
      $stageobject->started($mysqltime);
      
      #### CLEAR STDOUT/STDERR FILES
      my $stdoutfile    =    $stageobject->stdoutfile();
      File::Path::rmtree( $stdoutfile ) if -f $stdoutfile;
      my $stderrfile    =    $stageobject->stderrfile();
      File::Path::rmtree(  $stderrfile ) if -f $stderrfile;
      
      #### REPORT STARTING STAGE
      $self->bigDisplayBegin("'$projectname.$workflowname' stage $stagenumber $stagename status: RUNNING");
      
      $stageobject->initialiseRunTimes($mysqltime);

      #### SET STATUS TO running
      $stageobject->setStatus('running');

      # #### NOTIFY STATUS
      # if ( $worker ) {
      #     $self->updateJobStatus($stage, "started");
      # }
      # else {
      #     my $data = $self->_getStatus($username, $projectname, $workflowname);
      #     $self->logDebug("DOING notifyStatus(data)");
      #     # $self->notifyStatus($data) if defined $exchange and $exchange eq "true";
      # }
      
      ####  RUN STAGE
      $self->logDebug("Running stage $stagenumber", $stagename);    
      my ($exitcode) = $stageobject->run( $dryrun );
      $self->logDebug("Stage $stagenumber-$stagename exitcode", $exitcode);

      #### STOP IF THIS STAGE DIDN'T COMPLETE SUCCESSFULLY
      #### ALL APPLICATIONS MUST RETURN '0' FOR SUCCESS)
      if ( $exitcode == 0 ) {
          $self->logDebug("Stage $stagenumber: '$stagename' completed successfully");
          $stageobject->setStatus('completed');
          $self->bigDisplayEnd("'$projectname.$workflowname' stage $stagenumber $stagename status: COMPLETED");
          
          # #### NOTIFY STATUS
          # my $status    =    "completed";
          # if ( $worker ) {
          #     $self->logDebug("DOING self->updateJobStatus: $status");
          #     $self->updateJobStatus($stage, $status);
          # }
          # else {
          #     my $data = $self->_getStatus($username, $projectname, $workflowname);
          #     # $self->notifyStatus($data) if defined $exchange and $exchange eq "true";
          # }
      }
      else {
          $stageobject->setStatus('error');
          $self->bigDisplayEnd("'$projectname.$workflowname' stage $stagenumber $stagename status: ERROR");

          # #### NOTIFY ERROR
          # if ( $worker ) {
          #     $self->updateJobStatus($stage, "exitcode: $exitcode");
          # }
          # else {
          #     my $data = $self->_getStatus($username, $projectname, $workflowname);
          #     # $self->notifyError($data, "Workflow '$projectname.$workflowname' stage #$stagenumber '$stagename' failed with exitcode: $exitcode") if defined $exchange and $exchange eq "true";
          # }
          
          $self->logDebug("Exiting runStages");
          return 0;
      }

      #### SET SUCCESSOR IF PRESENT
      my $successor    =    $stageobject->getSuccessor();
      $self->logDebug("successor", $successor);
      $stagecounter = $successor - 2 if defined $successor and $successor ne "";
      $self->logDebug("stagecounter", $stagecounter);
    }   
   
		# $self->logDebug( "DEBUG EXIT" ) and exit;

    return 1;
}

method launchVM ( $stageobject ) {
  my $profilehash      =    $stageobject->{ profilehash };
  $self->logDebug( "profilehash", $profilehash );
  return $stageobject if not defined $profilehash;

	my $profile = Util::Profile->new();
	$profile->profilehash( $profilehash );

  return $stageobject if not defined $profile->getProfileValue( "virtual" );

  my $virtualtype = $profile->getProfileValue( "virtual:type" );
  $self->logDebug( "virtualtype", $virtualtype );
  my $virtual = $self->setVirtual( $virtualtype );
  # $self->logDebug( "self->virtual()", $self->virtual() );

  $stageobject = $virtual->getNodeInfo( $stageobject );

  #### GET VALUES UPDATED BY getProfileValue
  $profilehash      =    $stageobject->{ profilehash };
  my $ipaddress = $profile->getProfileValue( "instance:ipaddress" );
  $self->logDebug( "ipaddress", $ipaddress );

  #### LAUNCH NODE IF NO IPADDRESS FOUND
  # if ( not defined $ipaddress ) {
  	$self->logDebug( "DOING virtual->launchNode( stageobject )" );
		$stageobject = $virtual->launchNode( $stageobject );
  	$ipaddress = $profile->getProfileValue( "instance:ipaddress", $stageobject->{ profilehash } );
  	$self->logDebug( "ipaddress", $ipaddress );
  # }

  #### GET VALUES UPDATED BY launchNode
  $profilehash      =    $stageobject->{ profilehash };
  # $self->logDebug( "profilehash", $profilehash );

  my $instanceid = $profile->getProfileValue( "instance:id" );
  my $instancename = $profile->getProfileValue( "instance:name" );

	$self->logDebug("instanceid", $instanceid);
	$self->logDebug("instancename", $instancename);
	$self->logDebug( "ipaddress", $ipaddress );

	if ( not defined $instanceid 
		or not defined $instancename
		or not defined $ipaddress ) {
		$self->logDebug( "Failed to get info or launch VM" );
		print "Failed to launch or detect VM\n";
		return undef;
	}


#### INSERT INSTANCE DETAILS INTO DATABASE
#   sqlite> .schema instancestatus
# CREATE TABLE instancestatus
# (
#   username        VARCHAR(30) NOT NULL,
#   projectname     VARCHAR(20) NOT NULL,
#   workflowname    VARCHAR(20) NOT NULL,
#   stagename       VARCHAR(20) NOT NULL,
#   status          VARCHAR(30),
#   started         DATETIME NOT NULL,
#   stopped         DATETIME NOT NULL,
#   terminated      DATETIME NOT NULL,
#   polled          DATETIME NOT NULL,
#   hours           INT(12),
  
#   PRIMARY KEY ( username, projectname, workflowname, stagename )
# );
	# $self->logDebug( "RETURNING stageobject", $stageobject, 1 );

	return $stageobject;	
} 

method getSecurityGroup ( $profilehash ) {

}

method createSecurityGroup ( $profilehash ) {

}

method stopWorkflow ( $username, $projectname, $workflowname, $options ) {
  $self->logDebug("projectname", $projectname);
  $self->logDebug("workflowname", $workflowname);
  
  #### GET ALL STAGES FOR THIS WORKFLOW
  my $query = qq{SELECT * FROM stage
WHERE username ='$username'
AND projectname = '$projectname'
AND workflowname = '$workflowname'
AND status='running'
ORDER BY appnumber};
  $self->logDebug("$query");
  my $stages = $self->table()->db()->queryhasharray($query);
  $self->logDebug("stages", $stages);

  my $messages = $self->killStages( $stages );
  
  #### UPDATE STAGE STATUS TO 'stopped'
  my $update_query = qq{UPDATE stage
SET status = 'stopped'
WHERE username = '$username'
AND projectname = '$projectname'
AND workflowname = '$workflowname'
AND status = 'running'
};
  $self->logDebug("$update_query\n");
  my $success = $self->table()->db()->do($update_query);

  return $success;    
}

method killStages ( $stages ) {
#### 1. 'kill -9' THE PROCESS IDS OF ANY RUNNING STAGE OF THE WORKFLOW
#### 2. INCLUDES STAGE PID, App PARENT PID AND App CHILD PID)

    $self->logDebug("stages", $stages);
    my $messages = [];
    foreach my $stage ( @$stages )
    {
        #### OTHERWISE, KILL ALL PIDS
        push @$messages, $self->util()->killPid($stage->{childpid}) if defined $stage->{childpid};
        push @$messages, $self->util()->killPid($stage->{parentpid}) if defined $stage->{parentpid};
        push @$messages, $self->util()->killPid($stage->{stagepid}) if defined $stage->{stagepid};
        push @$messages, $self->util()->killPid($stage->{workflowpid}) if defined $stage->{workflowpid};
    }

    return $messages;
}


method _runWorkflow ( $hosttype, $runtype, $workflowhash, $samplehash ) {
	$self->logDebug("workflowhash", $workflowhash);
	$self->logDebug("samplehash", $samplehash);
	$self->logDebug( "hosttype", $hosttype );
	$self->logDebug( "runtype", $runtype );

	$workflowhash->{first}		=	$workflowhash->{first} || 1;
	$workflowhash->{samplehash}	=	$samplehash;

	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}			=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();

	$workflowhash->{conf}			=	$self->conf();
	$workflowhash->{db}				=	$self->table()->db();
	$workflowhash->{scheduler}=	$self->scheduler();

	my $stages = $self->setStages( $hosttype, $runtype, $workflowhash );	



	# require Engine::Workflow;
	# my $object	= Engine::Workflow->new( $hosttype, $runtype, $workflowhash );
	# #$self->logDebug("object", $object);
	# return $object->executeWorkflow($workflowhash);
}

method _runSampleWorkflow ( $hosttype, $runtype, $workflowhash, $sampledata ) {
	$self->logDebug("workflowhash", $workflowhash);
	$workflowhash->{first}		=	1;
	$workflowhash->{workflow}	=	$workflowhash->{name};
	$workflowhash->{workflownumber}	=	$workflowhash->{number};

	#### MAX JOBS
	$workflowhash->{maxjobs}	=	$self->maxjobs();
	
	#### LOG INFO		
	$workflowhash->{logtype}	=	$self->logtype();
	$workflowhash->{logfile}	=	$self->logfile();
	$workflowhash->{log}			=	$self->log();
	$workflowhash->{printlog}	=	$self->printlog();
	$self->logDebug("workflowhash", $workflowhash);
			
	$workflowhash->{conf}			=	$self->conf();
	$workflowhash->{db}				=	$self->table()->db();
	$workflowhash->{scheduler}=	$self->scheduler();

	require Engine::Workflow;
	my $object	= Engine::Workflow->new($workflowhash);
	
	#### RUN JOBS IN PARALLEL
	return $object->runInParallel($workflowhash, $sampledata);
}

method getSampleJobs ($workflowhash, $sampledata) {
	$self->logDebug("workflowhash", $workflowhash);
	
}


method getWorkflow ($username, $projectname, $workflowname) {
	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowname", $workflowname);

	my $query = qq{SELECT * FROM workflow 
WHERE projectname='$projectname' 
AND workflowname='$workflowname'
};
	$self->logDebug( "query", $query );

	return   $self->table()->db()->queryhash( $query );
}

method _getProjectHash ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $query	=	qq{SELECT * FROM project
WHERE username='$username'
AND projectname='$project'};
	$self->logDebug("query", $query);

	my $result	=	$self->table()->db()->queryhash($query);
	$self->logDebug("result", $result);
	
	return undef if not defined $result or $result eq "";
	return $result;
}


method _projectExists ($username, $project) {
	#$self->logDebug("username", $username);
	#$self->logDebug("project", $project);

	my $query	=	qq{SELECT 1 FROM project
WHERE username='$username'
AND projectname='$project'};
	#$self->logDebug("query", $query);

	my $result	=	$self->table()->db()->query($query);

	return 0 if not defined $result or $result eq "";
	return 1;
}

method loadFromDatabase ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $workflows = $self->table()->getWorkflowsByProject({
		username => $username,
		project  => $project
	});
	$self->logDebug("no. workflows", scalar(@$workflows));
	#$self->logDebug("workflows", $workflows);
	
	my $workflowobjects 	=	$self->getWorkflowObjectsForProject($workflows, $username);
	$self->logDebug("no. workflowobjects", scalar(@$workflowobjects));

	foreach my $workflowobject ( @$workflowobjects ) {
		#### SAVE WORKFLOW TO DATABASE
		$self->_saveWorkflow($workflowobject);
	}
}

method getProjectWorkflows ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	#### GET WORKFLOWS
	my $query	=	qq{SELECT * FROM workflow
WHERE username='$username'
AND projectname='$project'};
	my $data    =   $self->table()->db()->queryhasharray($query) || [];
  $self->logDebug("data", $data);
    
	return $data;	
}

method getProjectWorkflowObjects ($username, $project) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);

	my $workflows = $self->getWorkflows( $username, $project );
	my $workflowobjects 	=	$self->getWorkflowObjectsForProject($workflows, $username);
	$self->logDebug("no. workflowobjects", scalar(@$workflowobjects));

	return $workflowobjects;	
}

method getProjectWorkflowObject ($username, $project, $workflow) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);

	my $workflowobject = $self->getWorkflowObject({
		username	=>	$username,
		project		=>	$project,
		name		=>	$workflow
	});
	$self->logDebug("workflowobject", $workflowobject);

	return $workflowobject;	
}

method printWorkflow {
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $project     =   $self->project();
	my $workflow	=   $self->workflow();
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	
	my $query	=	qq{SELECT * FROM workflow
WHERE username='$username'
AND projectname='$project'
AND name='$workflow'};
	$self->logDebug("query", $query);
	my $workflowhash	=	$self->table()->db()->queryhash($query);
	$workflowhash->{workflow}	=	$workflowhash->{name};
	
	my $workflowobject 	=	$self->getWorkflowObject($workflowhash);

	my $outputdir	=	$self->outputdir() || ".";
	my $workflownumber	=	$workflowobject->number();
	$self->logDebug("workflownumber", $workflownumber);
	my $workflowfile	=	"$outputdir/$workflownumber-$workflow.work";
	$self->logDebug("workflowfile", $workflowfile);
	
	$workflowobject->_write($workflowfile);
}

#### STAGE
method showStage {
	#$self->log(4);
	$self->logDebug("");

	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;
	my $project     =   $self->project();
	my $workflow	=	$self->workflow();
	my $stagenumber	=	$self->stagenumber();
	my $dryrun		=	$self->dryrun();
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	$self->logDebug("stagenumber", $stagenumber);
	$self->logDebug("stagenumber", $stagenumber);
	$self->logDebug("dryrun", $dryrun);

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
	
	#### SET DRY RUN
	$workflowhash->{dryrun}		=	$dryrun;

	print "Information for workflow not found: $workflow\n" and exit if not defined $workflowhash;

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData($username, $project);
	$self->logDebug("samplesdata", $sampledata);
	#print "Number of samples: ", scalar(@$sampledata), "\n" if defined $sampledata;

	if ( defined $samplestring ) {
		my $samplehash		=	$self->sampleStringToHash($samplestring);
        my $success	=	$self->_showStage($workflowhash, $samplehash, $stagenumber);
		$self->logDebug("success", $success);
	}
	elsif ( defined $sampledata ) {

        my $override	=	$self->override();
        $self->logDebug("override", $override);
        my $overridehash		=	undef;
        $overridehash			=	$self->sampleStringToHash($override) if defined $override;
        $self->logDebug("overridehash", $overridehash);
        
        foreach my $samplehash ( @$sampledata ) {
            $samplehash = $self->overrideHash($overridehash, $samplehash);
            $self->logDebug("Running stage with samplehash", $samplehash);
            print "Running stage $stagenumber using sample: ", $samplehash->{sample}, "\n";
            my $success	=	$self->_showStage($workflowhash, $samplehash, $stagenumber);
            $self->logDebug("success", $success);
        }
	}
	else {
        my $success	=	$self->_showStage($workflowhash, $samplehash, $stagenumber);
        $self->logDebug("success", $success);
	}
	
}

method _showStage ($workflowhash, $samplehash, $stagenumber) {
	$self->logDebug("stagenumber", $stagenumber);
    my $username = $workflowhash->{username};
    my $project = $workflowhash->{project};
    my $workflow = $workflowhash->{name};
    $self->logDebug("workflow", $workflow);
    
	$workflowhash->{first}		=	$stagenumber;
	$workflowhash->{last}		=	$stagenumber + 1;
	$workflowhash->{workflow}	=	$workflowhash->{name};
	$workflowhash->{workflownumber}	=	$workflowhash->{number};
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
	my $workflowobject	= Engine::Workflow->new($workflowhash);
  my $stages = $workflowobject->getStagesByWorkflow($workflowhash);
	$stages = $workflowobject->setStageParameters($stages, $workflowhash);
  my $stage = $$stages[$stagenumber - 1];
  print "Project '$project' workflow '$workflow' for user '$username' does not have a stage $stagenumber\n" and exit if not defined $stage;
  #$workflowobject->printStage($stage);
    
  #### GET FILEROOT
	my $fileroot = $workflowobject->util()->getFileroot($username);	
	$self->logDebug("fileroot", $fileroot);
    
  #### SET FILE DIRS
	my ($scriptdir, $stdoutdir, $stderrdir) = $workflowobject->setFileDirs($fileroot, $project, $workflow);
	$self->logDebug("scriptdir", $scriptdir);

  my $stagename	=	$stage->{name};
  my $id			=	$samplehash->{sample};
  my $successor	=	$stage->{successor};
  $self->logDebug("successor", $successor);
  
  $stage->{stageparameters} = [] if not defined $stage->{stageparameters};

  $stage->{username}		=  	$workflowhash->{username};
  $stage->{db}			=	$self->table()->db();
  $stage->{conf}			=  	$self->conf();
  $stage->{fileroot}		=  	$fileroot;

	#### SET OUTPUT DIR
	my $outputdir =  "$fileroot/$project/$workflow";

	#### SET ENVIRONMENT VARIABLES
    $stage->{envar} = $workflowobject->envar();
    
    #### MAX JOBS
    $stage->{maxjobs}		=	$workflowobject->maxjobs();
    #### QUEUE
    $stage->{queue} = $workflowobject->queueName($username, $project, $workflow);

   	#### SET SGE OPTIONS
	my $scheduler	=	$workflowobject->scheduler() || $workflowobject->conf()->getKey("agua:SCHEDULER", undef);
	if ( defined $scheduler and $scheduler eq "sge" ) {
        #### SLOTS (NUMBER OF CPUS ALLOCATED TO CLUSTER JOB)
        my $cluster 	=	$workflowobject->cluster() || $workflowhash->{cluster};
        $stage->{slots}	=	$workflowobject->getSlots($username, $cluster);
	}

    #### SAMPLE HASH
    $stage->{samplehash}	=  	$samplehash;
    $stage->{outputdir}		=  	$outputdir;
    $stage->{qsub}			=  	$self->conf()->getKey("cluster:QSUB");
    $stage->{qstat}			=  	$self->conf()->getKey("cluster:QSTAT");

    #### LOG
    $stage->{log} 			=	$self->log();
    $stage->{printlog} 		=	$self->printlog();
    $stage->{logfile} 		=	$self->logfile();

    #### SET SCRIPT, STDOUT AND STDERR FILES
    $stage->{scriptfile} 	=	"$scriptdir/$stagenumber-$stagename.sh";
    $stage->{stdoutfile} 	=	"$stdoutdir/$stagenumber-$stagename.stdout";
    $stage->{stderrfile} 	= 	"$stderrdir/$stagenumber-$stagename.stderr";

    if ( defined $id ) {
        $stage->{scriptfile} 	=	"$scriptdir/$stagenumber-$stagename-$id.sh";
        $stage->{stdoutfile} 	=	"$stdoutdir/$stagenumber-$stagename-$id.stdout";
        $stage->{stderrfile} 	= 	"$stderrdir/$stagenumber-$stagename-$id.stderr";
    }

	require Engine::Stage;
  my $stageobject = Engine::Stage->new($stage);
  my $systemcall = $stageobject->setSystemCall();
  $self->logDebug("systemcall", $systemcall);
  my $command = join " \\\n", @$systemcall;
  print "\n$command\n\n";
}

method runStage ( $projectname, $workflowid, $stagenumber ) {
	$self->logDebug("");

	#### SET USERNAME AND OWNER
	my $username    =   $self->setUsername();
	my $owner       =   $username;

	#### GET WORKFLOW NAME IF workflownumber PROVIDED
	my $workflowname   = $workflowid;
	if ( $workflowid =~ /^\d+$/ ) {
		my $workflownumber = $workflowid;
		$workflowname = $self->table()->getWorkflowByNumber( $username, $projectname, $workflownumber );
	}
	$self->logDebug("workflowname", $workflowname);

	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowname", $workflowname);
	$self->logDebug("stagenumber", $stagenumber);

	#### VERIFY INPUTS
	print "username not defined\n" and exit if not defined $username;
	print "projectname not defined\n" and exit if not defined $projectname;
	print "workflowname not defined\n" and exit if not defined $workflowname;
	print "stagenumber not defined\n" and exit if not defined $stagenumber;
	
	#### GET OPTS (E.G., WORKFLOW)
	$self->_getopts();
	
	my $dryrun			=		$self->dryrun();
	my $force				=		$self->force();
	$self->logDebug("stagenumber", $stagenumber);
	$self->logDebug("dryrun", $dryrun);
	$self->logDebug("force", $force);
    
	my $samplestring	=	$self->samplestring();
	$self->logDebug("samplestring", $samplestring);
	my $samplehash		=	undef;
	$samplehash			=	$self->sampleStringToHash($samplestring) if defined $samplestring;
	$self->logDebug("samplehash", $samplehash);

	#### GET WORKFLOW
	my $workflowhash=	$self->getWorkflow($username, $projectname, $workflowname);
	print "Workflow not found: $workflowname\n" and exit if not defined $workflowhash;

	#### SET FIRST/last
	$workflowhash->{ first } = $stagenumber;
	$workflowhash->{ last } = $stagenumber;

	$self->logDebug("workflowhash", $workflowhash);
	
	#### SET DRY RUN
	$workflowhash->{dryrun}		=	$dryrun;

	#### GET SAMPLES
	my $sampledata	=	$self->getSampleData( $username, $projectname );
	print "Number of samples: ", scalar( @$sampledata ), "\n" if defined $sampledata;

	#### SET STAGES
	my $stages = [];
	if ( not $sampledata ) {
		#### GET SAMPLE STRING IF PROVIDED, OK IF EMPTY
		my $samplehash = $self->getSampleHash();	
		$stages = $self->setStages( $workflowhash, $samplehash )
	}
	else {
		foreach my $samplehash ( @$sampledata ) {
			$self->logDebug("Running workflow with samplehash", $samplehash);

			my $samplestages = $self->setStages( $workflowhash, $samplehash );		
			push ( @$stages, @$samplestages ) if @$samplestages;
		}
	}

	# $self->logDebug( "stages", $stages );
	$self->logDebug( "# stages", scalar( @$stages ) );

	my $success = $self->runStages( $stages, $dryrun );
	$self->logDebug( "success", $success );


	#### TO DO: ADD --samplestring


	# #### SET STAGE
	# my $sampledata	=	$self->getSampleData($username, $projectname);
	# $self->logDebug("Count samplesdata", scalar(@$sampledata)) if defined $sampledata;
	# $self->logDebug("samplesdata[0]", $$sampledata[0]) if defined $sampledata and scalar(@$sampledata) > 0;

	# if ( defined $samplestring ) {
	# 	my $samplehash		=	$self->sampleStringToHash($samplestring);
 #        my $success	=	$self->_runStage($workflowhash, $samplehash, $stagenumber);
	# 	$self->logDebug("success", $success);
	# }
	# elsif ( defined $sampledata ) {

 #        my $override	=	$self->override();
 #        $self->logDebug("override", $override);
 #        my $overridehash		=	undef;
 #        $overridehash			=	$self->sampleStringToHash($override) if defined $override;
 #        $self->logDebug("overridehash", $overridehash);
        
 #        foreach my $samplehash ( @$sampledata ) {
 #            $samplehash = $self->overrideHash($overridehash, $samplehash);
 #            $self->logDebug("Running stage with samplehash", $samplehash);
 #            print "Running stage $stagenumber using sample: ", $samplehash->{sample}, "\n";
 #            my $success	=	$self->_runStage($workflowhash, $samplehash, $stagenumber);
 #            $self->logDebug("success", $success);
 #        }
	# }
	# else {
 #        my $success	=	$self->_runStage($workflowhash, $samplehash, $stagenumber);
 #        $self->logDebug("success", $success);
	# }
}


#### LOAD
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

	my $number		=	0;
	for ( my $i = 0; $i < @$sections; $i++ ) {

		my $section =	$$sections[$i];
		
		next if $section =~ /^\s*$/;
		
		$number++;
		$self->logDebug("section $number", $section);

		my ($name)	=	$section	=~	/^(\S+)/;
		$self->logDebug("name", $name);
		
		require Flow::Workflow;
		my $workflow = Flow::Workflow->new({
			name	=>	$name,
			number	=>	$number
		});

		$workflow->_loadScript($section);
		$workflow->_write("$outputdir/$number-$name.work");
	
		#$self->logDebug("workflow:");
		#print $workflow->toString(), "\n";
		$self->_addWorkflow($workflow);
	}
	
	#$self->logDebug("outputfile", $self->inputfile());
	$self->_write();
	
	print "Printed project file: ", $self->inputfile(), "\n";

	return 1;
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
		my $workflow = Flow::Workflow->new();
		$workflow->getopts();
		$workflow->_loadCmd($command);
		#$self->logDebug("app:");
		#print $workflow->toString(), "\n";
		$self->_addWorkflow($workflow);
	}
	
	$self->_write();
	
	return 1;
}

method bigDisplayBegin ($message) {
  print qq{
##########################################################################
#### $message
####
};
  
}

method bigDisplayEnd ($message) {
  print qq{
####
#### $message
##########################################################################
};
  
}

#__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

}


