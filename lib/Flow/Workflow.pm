use MooseX::Declare;
use Getopt::Simple;
use Cwd;

use FindBin qw($Bin);
use lib "$Bin/../..";

class Flow::Workflow with (Util::Logger, 
	Flow::Timer, 
	Flow::Common) {

use File::Path;
use JSON;
use Data::Dumper;
use Flow::App;
use Conf::Yaml;
use Table::Main;

#### Int
has 'workflownumber'	=> ( isa => 'Int|Undef', is => 'rw', default	=>	1	);
has 'log'		=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);  
has 'printlog'	=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);
has 'epochstarted'	=> ( isa => 'Int|Undef', is => 'rw', default => 0 );
has 'epochstopped'  => ( isa => 'Int|Undef', is => 'rw', default => 0 );
has 'epochduration'	=> ( isa => 'Int|Undef', is => 'rw', default => 0 );
has 'indent'    => ( isa => 'Int', is => 'ro', default => 15);
has 'start'	=> ( isa => 'Int', is => 'rw', required => 0 );
has 'stop'	=> ( isa => 'Int', is => 'rw', required => 0 );

#### Maybe
has 'force'     => ( isa => 'Maybe', is => 'rw', required => 0 );
has 'epochqueued'	=> ( isa => 'Maybe', is => 'rw', default => 0 );

#### Str
has 'logfile'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);

#### STORED LOGISTICS VARIABLES
has 'username'  => ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'owner'	    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => undef );
has 'package'	=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'projectname'	=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'workflowname'	=> ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'workflowtype'	=> ( isa => 'Str|Undef', is => 'rw', required => 0, documentation => q{User-defined application type} );
has 'description'	=> ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'notes'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'appnumber'	=> ( isa => 'Str|Undef', is => 'rw', default => undef, required => 0, documentation => q{Set order of appearance: 1, 2, ..., N} );
has 'paramname'	=> ( isa => 'Str|Undef', is => 'rw', default => undef, required => 0, documentation => q{Unique parameter name (used by editParameter subcommand)} );
has 'provenance'=> ( isa => 'Str|Undef', is => 'rw', required	=>	0, default => '');

#### STORED STATUS VARIABLES
has 'status'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'locked'	    => ( isa => 'Int|Undef', is => 'rw', default => undef );
has 'queued'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'started'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'stopped'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );
has 'duration'	    => ( isa => 'Str|Undef', is => 'rw', default => undef );

#### TRANSIENT VARIABLES
has 'format'    => ( isa => 'Str', is => 'rw', default => "yaml");
has 'from'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'to'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'newname'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'appFile'	=> ( isa => 'Str', is => 'rw', required => 0 );
has 'field'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'value'	    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'inputfile' => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'wkfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'cmdfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'appfile'   => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'logfile'   => ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'outputfile'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'outputdir'=> ( isa => 'Str|Undef', is => 'rw', required => 0, default => '' );
has 'dbfile'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'dbtype'    => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'database'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'user'      => ( isa => 'Str|Undef', is => 'rw', required => 0 );
has 'password'  => ( isa => 'Str|Undef', is => 'rw', required => 0 );

#### Obj
has 'profiles'	=> ( isa => 'HashRef|Undef', is => 'rw', required	=>	0	);
has 'apps'	    => ( isa => 'ArrayRef[Flow::App]', is => 'rw', default => sub { [] } );
has 'fields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['username', 'projectname', 'workflowname', 'workflownumber', 'owner', 'description', 'notes', 'outputdir', 'field', 'value', 'wkfile', 'outputfile', 'cmdfile', 'start', 'stop', 'appnumber', 'paramname', 'from', 'to', 'status', 'started', 'stopped', 'duration', 'epochqueued', 'epochstarted', 'epochstopped', 'epochduration', 'format', 'log', 'printlog', 'inputfile', 'outputfile', 'appfile'] } );
has 'savefields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', default => sub { ['username', 'projectname', 'workflowname', 'workflownumber', 'owner', 'description', 'notes', 'status', 'started', 'stopped', 'duration', 'locked'] } );
has 'exportfields'    => ( isa => 'ArrayRef[Str|Undef]', is => 'rw', 
	default => sub { ['username', 'projectname', 'workflowname', 'workflownumber', 'owner', 'description', 'notes', 'status', 'started', 'stopped', 'duration', 'provenance'] } );
has 'hash'		=> ( isa => 'HashRef|Undef', is => 'rw', required => 0 );
has 'args'		=> ( isa => 'HashRef|Undef', is => 'rw', default => sub { return {}; } );
has 'db'		=> ( isa => 'Any', is => 'rw', required => 0 );
has 'logfh'     => ( isa => 'FileHandle', is => 'rw', required => 0 );
has 'conf' 	=> (
    is 		=>	'rw',
    isa 	=> 	'Conf::Yaml',
    lazy	=>	1,
    builder	=>	"setConf"
);
    
has 'table'		=>	(
	is 			=>	'rw',
	isa 		=>	'Table::Main',
	lazy		=>	1,
	builder	=>	"setTable"
);
    
method BUILD ($hash) {
	$self->getopts();
	$self->initialise();
}

method initialise {
	#$self->logCaller("");

	$self->owner($self->username()) if not defined $self->owner();
	$self->inputfile($self->wkfile()) if defined $self->wkfile() and $self->wkfile();

	$self->checkInputs();
}

method checkInputs {
	$self->logDebug("self->wkfile: "), $self->wkfile(), "\n";
	#$self->logDebug("self->inputfile: "), $self->inputfile(), "\n";
	
	# $self->logDebug("inputfile not defined. Exiting") and exit
	# 	if defined $self->inputfile()
	# 	and $self->inputfile()
	# 	and not $self->inputfile() =~ /\.wrk$/;

	# $self->logDebug("outputfile must end in '.wrk'") and exit
	# 	if defined $self->outputfile()
	# 	and $self->outputfile()
	# 	and not $self->outputfile() =~ /\.wrk$/;
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

method run {
	$self->logDebug("");

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
	my $section = "[workflow ". $self->workflowname() . "]\n";
	$self->logDebug($section);
	$self->logDebug();
	$self->logDebug($self->_wiki() . "\n\n");

	#### RUN APPS
	my $apps = $self->apps();
	$self->logDebug("No. apps: ". scalar(@$apps) . "\n" );
	
	my $start = $self->start();
	$start = 1 if not defined $start or $start =~ /^\s*$/;
	my $stop = $self->stop();
	$stop = scalar(@$apps) if not defined $stop or $stop =~ /^\s*$/;
	$stop = scalar(@$apps) if $stop > scalar(@$apps);
	$self->logDebug("start", $start);
	$self->logDebug("stop", $stop);
	
	#### SET STARTED
	$self->setStarted();
	$self->logDebug("starting workflow " . $self->workflowname()  . "': " . $self->started() . "'\n" );
	
	for ( my $i = $start - 1; $i < $stop; $i++ ) {
		my $app = $$apps[$i];
		$self->logDebug("Running app '" . $app->appname() . "'\n" );
		$app->logfh($self->logfh());
		$app->outputdir($self->outputdir());
		my ($status, $label) = $app->run();
		#$self->logDebug("Flow::Workflow::run    completed", $status);
		#$self->logDebug("Flow::Workflow::run    label", $label) if defined $label;

		$self->logDebug("Application may not have completed successfully.\n\nApplication status: $status.\n\nPlease check the logfile", $logfile) if not $status or $status ne "completed";
		
		$self->logDebug("\nApplication status", $status)
			and last if $status ne "completed";
	}

	#### SET STOPPED
	$self->setStopped();
	$self->logDebug("ending workflow '"  . $self->workflowname()  . "': " . $self->started() . "\n" );
	
	#### SET DURATION
	$self->setDuration();
	
	#### END LOG
	$self->logDebug("\nCompleted workflow " . $self->workflowname() . "\n");
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
	#$self->logDebug("App::loadCmd()");
	
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
		require Flow::App;
		my $app = Flow::App->new();
		$app->getopts();
		$app->_loadCmd($command);
		#$self->logDebug("app:");
		#print $app->toString(), "\n";
		$self->_addApp($app);
	}
	
	$self->_write();
	
	return 1;
}

method loadScript {
    
	my $cmdfile = $self->cmdfile();
	open(FILE, $cmdfile) or die "Can't open cmdfile: $cmdfile\n";
	$/ = undef;
	my $content = <FILE>;
	close(FILE) or die "Can't close cmdfile: $cmdfile\n";
	$/ = "\n";
	$content =~ s/,\\\n/,/gms;
	#$self->logDebug("content", $content);

	$self->_loadScript($content);

    my $outputfile = $self->outputfile();
    $outputfile = $self->inputfile() if not defined $outputfile;
    $self->_write($outputfile);
	
	print "Printed workflow file: ", $outputfile, "\n";

}

method _loadScript ($content) {
	$self->logDebug("");

	my $counter = 0;
	my $sections;
	#@$sections = split "\\#\\d+\\s+", $content;
	@$sections = split "#\\s\\d+\\s", $content;
	#shift @$sections;
	$self->logDebug("sections[0]", $$sections[0]);
	$self->logDebug("no. sections", scalar(@$sections));

	for ( my $i = 0; $i < @$sections; $i++ ) {
		my $section =	$$sections[$i];
		next if $section =~ /^\s*$/;
		
		$counter++;
		$self->logDebug("section $counter", $section);

		require Flow::App;
		my $app = Flow::App->new({
      log         =>  $self->log(),
      printlog    =>  $self->printlog(),
      package     =>  $self->package(),
      owner       =>  $self->owner(),
      description =>  ""
    });
		$app->_loadScript($section);
        
    my $outputfile = $self->outputfile();
    $self->logDebug("outputfile", $outputfile);
    my ($outputdir) =   $outputfile =~ /(^.+)\/[^\/]+$/;
    $outputdir = Cwd::getcwd();
    $self->logDebug("outputdir", $outputdir);
    my $appname = $app->appname();
    my $appfile = "$outputdir/$appname.app";
    $self->logDebug("appfile", $appfile);

    $app->_write($appfile);

		$self->_addApp($app);
	}
	
	return 1;
}


method getNameFromFile ( $wkfile ) {
	$self->logDebug("wkfile", $wkfile);

	my ($workflowname) = $wkfile =~ /([^\/]+)\.wrk$/;
	$self->logDebug("workflowname", $workflowname);

	return $workflowname;
}

method app {
	#$self->logDebug("App::app()");
	$self->_loadFile() if $self->wkfile();

	require Flow::App;
	my $app = Flow::App->new();
	$app->getopts();
	#$self->logDebug("app:");
	#print $app->toString(), "\n";
	
	$self->logDebug("Please provide '--appname' and '--appnumber' argument for app\n") and exit if not $app->appname() and not $app->appnumber();

	#### GET THE PARAM FROM apps
	my $index;
	$index = $app->appnumber() - 1 if $app->appnumber();
	$index = $self->_appIndex($app) if not $app->appnumber();
	$self->logDebug("Can't find app among workflow's apps:"), $app->toString(), "\n\n" and exit if not defined $index;
	#$self->logDebug("index", $index);

	my $application = ${$self->apps()}[$index];
	$self->logDebug("Can't find app number ") . $index + 1 . "\n" and exit if not defined $application;
	#$self->logDebug("BEFORE getopts application:");
	#print $application->toString(), "\n";

	$application->getopts();
	#$self->logDebug("AFTER getopts application:");
	#print $application->toString(), "\n";

	my $command = shift @ARGV;
	#$self->logDebug("command", $command);

	my $return = $application->$command();

	$self->_write() if $self->inputfile();
	
	return $return;
}

method replace {
	$self->logDebug("Flow::Workflow::replace()");
	
	$self->_loadFile() if defined $self->appfile() and $self->appfile();

	#### DO PARAMETERS
	my $apps = $self->apps();
	my $params = [];
	foreach my $parameter ( @$apps )
	{
		$parameter->getopts();
		$parameter->replace();
	}
	#$self->logDebug("AFTER self->toString() :");
	#print $self->toString() ;

	$self->outputfile($self->inputfile());
	$self->_write() if $self->outputfile();
}

method loadApp ($app) {
	$self->logDebug("");        
	$self->_addApp($app);
	my $name = $app->name();
	$name = "unknown" if not defined $name;

	$self->_write();

	my $appnumber = $app->appnumber();
	$self->logDebug("Added app $appnumber: '$name'");
	
	return 1;
}

method addApp {
	$self->logDebug("");

    $self->getopts();
	my $inputfile = $self->inputfile();
	$self->logDebug("inputfile", $inputfile);
	$self->_loadFile();
	$self->logDebug("self->toString()");
	print $self->toString(), "\n";

	my $appfile = $self->appfile();
	$self->logDebug("appfile not defined. Exiting") if not defined $appfile and not $appfile;
	#$self->logDebug("appfile", $appfile);
	
	my $args	=	$self->args();
	$self->logDebug("args", $args);
	
	my $app 	= 	Flow::App->new($args);
	$app->getopts();
	$app->_loadFile();

    my $appname =    $app->appname();
    $self->logDebug("appname", $appname);

	$self->_addApp($app);

	my $outputfile	=	$self->outputfile() || $self->inputfile();
	$self->logDebug("outputfile", $outputfile);
	print "Outputfile not defined\n" and exit if not defined $outputfile;
	
	$self->_write($outputfile);

	my $appnumber = $app->appnumber();
	$self->logDebug("Added app $appnumber: '$appname'");
	
	print "\n";
	print `cat $outputfile`;
	
	return 1;
}

method _addApp ($app) {
	#$self->logDebug("Workflow::_addApp()");

	return $self->_insertApp($app, $app->appnumber() - 1) if $app->appnumber();
	
	#### INCREMENT app NUMBER
	$app->appnumber(scalar(@{$self->apps()} + 1));
	
	push @{$self->apps()}, $app;

	$self->_numberApps();

	return scalar(@{$self->apps()});
}

method _insertApp ($app, $index) {
	#$self->logDebug("Workflow::_insertApp(app)");
	#$self->logDebug("app->toString(): "), $app->toString(), "\n";
	#$self->logDebug("index", $index);

	splice @{$self->apps}, $index, 0, $app;
	
	$self->_numberApps();
	
	return $index;
}

method save {
	$self->logCaller("");
	$self->logDebug("self->username()", $self->username());

	#### SET USERNAME AND OWNER
	$self->setUsername() if not $self->username();
	
	#### LOAD INTO DATABASE
	$self->saveWorkflowToDatabase($self);
}

method saveWorkflowToDatabase ($workflowobject) {
	$self->logCaller("SAVE TO WORKFLOW");
	my $username		=	$workflowobject->username();
	my $projectname 	= 	$workflowobject->projectname();
	my $workflowname 	= 	$workflowobject->workflowname();
	my $workflownumber 	= 	$workflowobject->workflownumber();
	$self->logDebug("username", $username);	
	
	#### SKIP IF WORKFLOW ALREADY EXISTS
	my $workflowdata = $workflowobject->exportData();
	$workflowdata->{username}	=	$username;
	$workflowdata->{owner}		=	$username;
	$self->logDebug("Number of apps", scalar(@{$workflowdata->{apps}}) );
	delete $workflowdata->{apps};
	$self->logDebug("workflowdata", $workflowdata);
	my $keys = ['owner', 'username', 'projectname', 'workflowname', 'workflownumber'];
	
	#### ADD WORKFLOW
	$self->workflowToDatabase($workflowdata);

	#### STAGES
	my $stageobjects = $workflowobject->apps();
	$self->logDebug("No. stageobjects", scalar(@$stageobjects));
	foreach my $stageobject ( @$stageobjects ) {
		#$self->logDebug("stageobject", $stageobject);
		#$self->logDebug("stageobject->submit()", $stageobject->submit());

		my $stagenumber 	= $stageobject->{appnumber};
		my $package			=	$stageobject->{package};
		my $installdir		=	$stageobject->{installdir};
		
		#### ADD STAGE	
		$self->stageToDatabase($username, $stageobject, $projectname, $workflowname, $workflownumber, $stagenumber);
		
		#### PARAMETERS
		my $parameterobjects = $stageobject->parameters();
		$self->logDebug("no. parameterobjects", scalar(@$parameterobjects));
		my $paramnumber = 0;
		foreach my $parameterobject ( @$parameterobjects ) {
			$paramnumber++;
			
			#### ADD PARAMETER
			$self->stageParameterToDatabase($username, $package, $installdir, $stageobject, $parameterobject, $projectname, $workflowname, $workflownumber, $stagenumber, $paramnumber);
		}
	}	
}


method workflowToDatabase ($workflowdata) {
	$self->logDebug("workflowdata", $workflowdata);
	$self->logCritical("username not defined") and exit if not defined $workflowdata->{username};
	delete $workflowdata->{apps};

	#### REMOVE WORKFLOW
	my $success = $self->table()->_removeWorkflow($workflowdata);
	$self->logDebug("success", $success);

	#### ADD WORKFLOW
	return $self->table()->_addWorkflow($workflowdata);
}


method moveApp {
	$self->logDebug("Workflow::moveApp(app)");

	$self->_loadFile();

	my $from = $self->from();
	$self->logDebug("from not defined") and exit if not $from;
	$self->logDebug("from out of range (1 - "), scalar(@{$self->apps()}), ")\n" and exit if $from > scalar(@{$self->apps()});
	$self->logDebug("from out of range (1 - "), scalar(@{$self->apps()}), ")\n" and exit if $from < 1;
	

	my $to = $self->to();
	$self->logDebug("to not defined") and exit if not $to;
	$self->logDebug("to out of range (1 - "), scalar(@{$self->apps()}), ")\n" and exit if $to > scalar(@{$self->apps()});
	$self->logDebug("to out of range (1 - "), scalar(@{$self->apps()}), ")\n" and exit if $to < 1;

	#### RETURN IF 'FROM' IS 'TO'
	return 1 if $from == $to;

	#### OTHERWISE, MOVE APP
	my $app = splice @{$self->apps()}, $from - 1, 1;
	print $app->wiki();
	splice @{$self->apps}, $to - 1, 0, $app;
	$self->_numberApps();
	
	$self->_write();
	
	return 1;
}

method deleteApp {
	$self->logDebug("");

	$self->_loadFile();

	my $appnumber = $self->appnumber();
	$self->logDebug("appnumber", $appnumber) if defined $appnumber;
    
    #### SANITY CHECK
    print "appnumber not defined. Use option --appnumber to specifc which app to delete\n" and exit if not defined $appnumber;

	my $appobject = Flow::App->new(
		appnumber    =>  $appnumber
	);
	$appobject->getopts();
#        $app->_loadFile();
	#$self->logDebug("app->toString()");
	#print $app->toString(), "\n";
	#$self->logDebug("app->appnumber(): "), $app->appnumber(), "\n";

	#my $appnumber = $app->appnumber();
	my $name;
	($name, $appnumber) = $self->_deleteApp($appobject);
	$name = "name unknown" if not defined $name;
	$self->logDebug("name", $name);
	$self->logDebug("Deleted app $appnumber", $name);
	
	#if defined $app->appnumber() and $app->appnumber();
	#$self->_deleteApp($app) if not defined $self->appnumber();
	#print $self->toJson(), "\n";

	my $outputfile	=	$self->outputfile() || $self->inputfile();
	$self->logDebug("outputfile", $outputfile);
	
	$self->_write($outputfile);
	
	print "Deleted app $appnumber $name from workflow and printed to file: $outputfile\n";

	return 1;
}

method _numberApps {
	for ( my $counter = 0; $counter < scalar(@{$self->apps()}); $counter++ )
	{
		my $app = ${$self->apps()}[$counter];
		$app->appnumber($counter + 1);
	}
}

method _deleteApp ($app) {
	#$self->logDebug("Workflow::_deleteApp(app)");

	my $index;
	$index = $self->appnumber() - 1 if $self->appnumber()
		and $self->appnumber() !~ /^\s*$/;
	$index = $self->_appIndex($app) if not defined $index;
	$self->logDebug("index", $index);
	$self->logDebug("app not found", $app->toString())
		and exit if not defined $index;

	$self->logDebug("app not found", $app)
		and return 0 if not defined $index;

	$self->logDebug("zero-index '$index' falls after the end of the apps array (length: "), scalar(@{$self->apps()}), ")\n" and exit if $index > scalar(@{$self->apps()}) - 1;
	my $appname = @{$self->apps}[$index]->appname();

	splice @{$self->apps}, $index, 1;

	#$self->_orderApps();

	$self->_numberApps();

	return $appname, $index + 1;
}

method editApp {
    my $appnumber = $self->appnumber();
    $self->logDebug("appnumber", $appnumber);
	my $field = $self->field();
    $self->logDebug("field", $field);
	my $value = $self->value();
    $self->logDebug("value", $value);
	my $inputfile = $self->inputfile;
	$self->logDebug("inputfile", $inputfile);

        #### SANITY CHECK
	print "inputfile not defined. Use --inputfile option\n" and exit if not defined $inputfile;
	print "appnumber not defined. Use --appnumber option\n" and exit if not defined $appnumber;
	print "field not defined. Use --field option\n" and exit if not defined $field;
	print "value not defined. Use --value option\n" and exit if not defined $value;

	$self->_loadFile();
    my $index   =   $appnumber - 1;
    $self->logDebug("index", $index);
    my $apps    =   $self->apps();
    my $app     =   $$apps[$index];
    #$self->logDebug("app", $app);
	
	$app->edit();

	#$self->_orderApps();
	#print $self->toJson(), "\n";
	
	my $outputfile = $self->outputfile() || $inputfile;
	$self->_write($outputfile);

    print "\nChanged app $appnumber field '$field' to value: $value\n\n";
}


method editParameter {
    my $appnumber = $self->appnumber();
    $self->logDebug("appnumber", $appnumber);
	my $paramname = $self->paramname();
    $self->logDebug("paramname", $paramname);
	my $field = $self->field();
    $self->logDebug("field", $field);
	my $value = $self->value();
    $self->logDebug("value", $value);
	my $inputfile = $self->inputfile;
	$self->logDebug("inputfile", $inputfile);

  #### SANITY CHECK
	print "inputfile not defined. Use --inputfile option\n" and exit if not defined $inputfile;
	print "appnumber not defined. Use --appnumber option\n" and exit if not defined $appnumber;
	print "paramname not defined. Use --paramname option\n" and exit if not defined $paramname;
	print "field not defined. Use --field option\n" and exit if not defined $field;
	print "value not defined. Use --value option\n" and exit if not defined $value;

	$self->_loadFile();
  my $index   =   $appnumber - 1;
  $self->logDebug("index", $index);
  my $apps    =   $self->apps();
  my $app     =   $$apps[$index];
  #$self->logDebug("app", $app);

  my $parameter = $app->getParam($paramname);
  #$self->logDebug("parameter", $parameter);
  print "parameter has no field '$field'\n" and exit if not $parameter->can($field);
  print "parameter field '$field' does not support value: $value\n" and exit if not $parameter->$field($value);
    
	my $outputfile = $self->outputfile() || $inputfile;
    
	$self->_write($outputfile);
    
    print "\nChanged app $appnumber parameter '$paramname' field '$field' to value: $value\n\n";    
}

method desc {
	$self->logDebug("");
	
	my $output = $self->_toString();
	$output = $self->_indentText($output, " " x 4 );

	return $output;
}

method wiki {
	#$self->logDebug("Workflow::wiki()");
	$self->_loadFile() if $self->wkfile();

	print $self->_wiki();

	return 1;
}


method _wiki {
	#$self->logDebug("Workflow::_wiki()");
	my $wiki = '';
	$wiki .= "\nWorkflow:\t" . $self->name() . "\n";
	$wiki .= "\t" . $self->status() if $self->status();
	$wiki .= "Started: " . $self->started() . "\n" if $self->started();
	$wiki .= "Stopped: " . $self->stopped() . "\n" if $self->stopped();
	$wiki .= "Duration: " . $self->duration() . "\n" if $self->duration();
	$wiki .= "Status: " . $self->status() . "\n" if $self->status();
	$wiki .= "\n" if $self->started();
	
	#### DO APPS
	my $apps = $self->apps();
	foreach my $app ( @$apps )
	{
		$wiki .= $app->_wiki();
	}
	
	return $wiki;
}



method getopts {
	$self->_getopts();    
	#$self->initialise();
}

method _getopts {
	# $self->logCaller();
	# $self->logDebug("***************** Flow::Workflow::getopts()");
	my @temp = @ARGV;

	my $arguments	=	$self->arguments();
  # $self->logDebug("arguments", $arguments);
	my $olderr;
	open $olderr, ">&STDERR";	
	open(STDERR, ">/dev/null") or die "Can't redirect STDERR to /dev/null\n";
	my $options = Getopt::Simple->new();
	$options->getOptions($arguments, "Usage: blah blah"); 
	open STDERR, ">&", $olderr;

	my $switch = $options->{switch};
	my $args	=	{};
	foreach my $key ( keys %$switch ) {
		# print "Flow::Workflow::_getopts    key: $key\n";
		my $value	=	$switch->{$key};
		if ( defined $value ) {
			#print "ADDING TO ARGS value: $value\n";
			$args->{$key}	=	$value;
			$self->$key($value) if $self->can($key);
		}
	}
	
	#### LOG STARTS	
	$self->logDebug("args", $args);

	#### SET args
	$self->args($args);

	#### RESTORE @ARGV
	@ARGV = @temp;
}

method arguments {
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
		my $attribute_type  = $attr->type_constraint();#$self->logDebug("attribute_type", $attribute_type);
		
		$attribute_type =~ s/\|.+$//;
		$args -> {$attribute_name} = {  type => $option_type_map{$attribute_type}  };
	}
	#$self->logDebug("args", $args);
	
	return $args;
}

method edit {
	#### IN CASE workflow IS PART OF project
	$self->getopts();
	
	my $field = $self->field();
	my $value = $self->value();

	$self->_loadFile() if defined $self->inputfile();
	
	my $present = 0;
	#$self->logDebug("field: **$field**");
	#$self->logDebug("value: **$value**");
	foreach my $currentfield ( @{$self->fields()} ) {
		$present = 1 if $field eq $currentfield;
		last if $field eq $currentfield;
	}
	$self->logDebug("Flow::Workflow::edit    field $field not valid") and exit if not $present;

	$self->$field($value);
	$self->logDebug("field $field: ", $self->$field());

    my $outputfile = $self->outputfile();
    $outputfile = $self->inputfile() if not defined $outputfile;

	$self->_write($outputfile);
}

method create {
	$self->_getopts();
	$self->logDebug("Workflow::create()");

	my $outputfile 		= 	$self->outputfile;
	$outputfile     	=   $self->workfile() if not defined $outputfile;
	$self->logDebug("outputfile", $outputfile);

	my $workflowname 	= 	$self->workflowname() || $self->name();
	($workflowname)		=	$outputfile	=~ /^(.+)\.(wk|work)$/ if not defined $workflowname;
	print "Workflow name not defined\n" and exit if not defined $workflowname;
	$self->workflowname($workflowname) if not defined $self->workflowname();
	
	my $outputdir		=	$self->outputdir() || ".";
	$outputfile			=	"$outputdir/$workflowname.work" if not defined $outputfile or $outputfile eq "";
	$self->logDebug("outputfile", $outputfile);
	
	$self->_write($outputfile);

	print "outputfile: $outputfile\n";
	print "\n";
	print `cat $outputfile`;
	
	return 1;
}

method copy {
	#$self->logDebug("Workflow::copy()");
	$self->_loadFile();
	$self->name($self->newname());

	my $outputfile = $self->outputfile;
	$self->_confirm("Outputfile already exists. Overwrite?") if -f $outputfile and not defined $self->force();

	$self->_write($outputfile);
}

method convert {
	my $format		=	$self->format();
  $self->logDebug("format", $format);

  $self->_loadFile();

	#### SWITCH FORMAT
	if ( $format eq "json" ) {
		$format		=	"yaml" ;
	}
	else {
		$format		=	"json";
	}
	$self->logDebug("final format", $format);
	$self->format($format);

  my $outputfile = $self->outputfile();
  $self->_confirm("Outputfile already exists. Overwrite?") if -f $outputfile and not defined $self->force();

  $self->_write($outputfile);
}

method _toExportHash ($fields) {
	#$self->log(4);
	#$self->logCaller("");
	#$self->logDebug("fields: @$fields");

	my $hash;
	foreach my $field ( @$fields ) {
		#$self->logDebug("field", $field);
		next if ref($self->$field) eq "ARRAY";

		next if not defined $self->$field();

		$hash->{$field} = $self->$field();
	}
	#$self->logDebug("hash", $hash);
	
	#### DO PARAMETERS
	my $apps = $self->apps();
	my $applications = [];
	foreach my $app ( @$apps )
	{
		push @$applications, $app->exportData();
	}
	#$self->logDebug("apps");
	#print Dumper $apps;

	$hash->{apps} = $applications;
	return $hash;
}

method toHash {
	my $hash;
	#$self->logDebug("self->started(): "), $self->started(), "\n";
	foreach my $field ( @{$self->savefields()} ) {
		#$self->logDebug("field '$field' value: "), $self->$field(), "\n";

		next if not defined $self->$field();
		next if $self->$field() eq "";
		next if $self->$field() eq "0";
		next if $self->$field() eq "0000-00-00 00:00:00";

		if ( ref($self->$field) ne "ARRAY" ) {
			$hash->{$field} = $self->$field();
		}
	}
	$self->logDebug("hash", $hash);
	
	#### DO APPS
	my $apps = $self->apps();
	my $applications = [];
	foreach my $app ( @$apps )
	{
		push @$applications, $app->exportData();
	}
	#$self->logDebug("apps:");
	#print Dumper $apps;

	$hash->{apps} = $applications;
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

method _appIndex ($app) {
	#$self->logDebug("Workflow::_appIndex(app)");
	$self->logDebug("app:");
	print $app->toString();

	my $counter = 0;
	my $name	=	$app->name();
	$self->logDebug("name", $name);
	foreach my $currentapp ( @{$self->apps} ) {
		my $currentname	=	$currentapp->name();
		$self->logDebug("currentname", $currentname);
		if ( $name eq $currentname ) {
			return $counter;
		}
		$counter++;
	}

	return;
}
method _write($outputfile) {
	$self->logDebug("outputfile", $outputfile);
	#$self->logDebug("outputfile", $outputfile) if defined $outputfile;
	
	$outputfile = $self->outputfile if not defined $outputfile;
	$outputfile = $self->inputfile if not defined $outputfile or not $outputfile;
	$self->logDebug("FINAL outputfile", $outputfile);

	my ($basedir) = $outputfile =~ /^(.+)(\/|\\)[^\/^\\]+$/;
	File::Path::mkpath($basedir) if defined $basedir and not -d $basedir;

	my $output	=	"";
	my $format	=	$self->format();
	#$self->logDebug("format", $format);
	if ( $format eq "yaml" ) {
		require YAML::Tiny;
		my $yaml = YAML::Tiny->new();

		my $data	=	$self->toHash();
		#$self->logDebug("data", $data);
		$yaml->[0]	=	$data;
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
	#$self->logDebug("Workflow::_loadFile()");

	my $inputfile = $self->inputfile();
  $self->logDebug("inputfile", $inputfile);
	$self->logDebug("inputfile not specified") and exit if not defined $inputfile;
  print "Can't find inputfile: $inputfile\n" if not -f $inputfile;
	$self->logDebug("Can't find inputfile", $inputfile) and exit if not -f $inputfile;

	my $object	=	undef;
	my $format	=	$self->format();
	$self->logDebug("format", $format);
	if ( $format eq "yaml" ) {
		require YAML::Tiny;
		my $yaml = YAML::Tiny->read($inputfile) or $self->logCritical("Can't open inputfile: $inputfile") and exit;
		$object 	=	$$yaml[0];
	}
	else {
		#$self->logDebug("inputfile", $inputfile);
		$/ = undef;
		open(FILE, $inputfile) or die "Can't open inputfile: $inputfile\n";
		my $contents = <FILE>;
		close(FILE) or die "Can't close inputfile: $inputfile\n";
		$/ = "\n";
	
		my $jsonParser = JSON->new();
		$object = $jsonParser->decode($contents);
	}

	my $fields = $self->fields();
	foreach my $field ( @$fields ) {
		if ( exists $object->{$field} ) {
			$self->$field($object->{$field});
		}
	}

	#### CREATE APPS
	my $apps = [];
  my $appnumber = 1;
	foreach my $apphash ( @{$object->{apps}} ) {
		$self->logDebug("apphash", $apphash);
	  $apphash->{appnumber} = $appnumber;
	  $appnumber++;        
		my $application = Flow::App->new({
	      inputfile   =>  undef,
	      log         =>  $self->log(),
	      printlog    =>  $self->printlog()
	  });

		$application->fromHash($apphash);
		push @$apps, $application;
	}   
	#$self->logDebug("apps:");
	#print Dumper $apps;

	$self->apps($apps);
	
	#$self->initialise();
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

method toString {
	return $self->_toString();
}

method export($outputfile) {
	$self->logDebug("");
	#$self->logDebug("outputfile", $outputfile) if defined $outputfile;
	
	$outputfile = $self->outputfile if not defined $outputfile;
	$outputfile = $self->inputfile if not defined $outputfile or not $outputfile;

	my ($basedir) = $outputfile =~ /^(.+)(\/|\\)[^\/^\\]+$/;
	File::Path::mkpath($basedir) if defined $basedir and not -d $basedir;

	my $export = $self->_toExport();
	
	$self->logDebug("Printing to outputfile: $outputfile");
	open(OUT, ">$outputfile") or die "Can't open outputfile: $outputfile\n";
	print OUT "$export\n";
	close(OUT) or die "Can't close outputfile: $outputfile\n";
}

method _toExport {
	my $hash = $self->exportData();

	#### DO PARAMETERS
	my $apps = $self->apps();
	my $applications = [];
	foreach my $app ( @$apps )
	{
		push @$applications, $app->exportData();
	}
	#$self->logDebug("apps:");
	#print Dumper $apps;

	$hash->{apps} = $applications;

	my $jsonParser = JSON->new();
	my $json = $jsonParser->pretty->indent->encode($hash);
	return $json;    
}

method _toString {
	my $json = $self->toJson() . "\n";
	my $output = "  Workflow: " . $self->workflowname() . "\n";
	foreach my $field ( @{$self->savefields()} ) {
		next if not defined $self->$field() or $self->$field() =~ /^\s*$/;
		$output .= "    " . $self->_indentSecond($field, $self->$field(), $self->indent()) . "\n";
	}

	my $data = {
		username => $self->username(),
		projectname  => $self->projectname(),
		workflowname => $self->workflowname()
	};
	$self->logDebug("data", $data);
	my $apps = $self->table()->getStagesByWorkflow( $data );
	$output .= "    apps (" . scalar(@$apps) . "):\n";

	foreach my $app ( @{$self->apps()} ) {
		my $text = $app->toString();
		$self->logDebug("text", $text);

		$text = $self->_indentText( $text, " " x 2 );
		$output .= $text . "\n"; 
	}
	
	return $output;
}

method _orderApps {
#### REDUNDANT: DEPRECATE LATER
	#$self->logDebug("Workflow::_orderApps()");

	sub appnumberOrAbc (){
		#### ORDER BY appnumber IF PRESENT
		#my $aa = $a->appnumber();
		#my $bb = $b->appnumber();
		return $a->appnumber() <=> $b->appnumber()
			if defined $a->appnumber() and defined $b->appnumber()
			and $a->appnumber() and $b->appnumber();
			
		#### OTHERWISE BY ALPHABET
		#my $AA = $a->name();
		#my $BB = $b->name();
		#$self->logDebug("AA", $AA);
		#$self->logDebug("BB", $BB);
		return $a->name() cmp $b->name();
	}

	my $apps = $self->apps;
	@$apps = sort appnumberOrAbc @$apps;
	$self->apps($apps);
}
}


