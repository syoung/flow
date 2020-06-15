use MooseX::Declare;

use strict;
use warnings;

class Siphon::Worker with (Util::Logger, 
	Util::Timer,
	Exchange) {

use FindBin qw($Bin);

#### USE LIBS
use lib "$Bin/../../../../lib";

use TryCatch;
use Getopt::Long;
use Util::Profile;

# Integers
has 'log'	=>  ( isa => 'Int', is => 'rw', default => 4 );
has 'printlog'	=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 300 );

# Strings
has 'processname' => ( is => 'Str', is => 'rw', default => "heartbeat" );
has 'queuename'  =>  ( isa => 'Str', is => 'rw', default => "outbound.job.queue" );
# has 'sendtype'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"report" );
has 'database'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'user'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'pass'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'host'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'vhost'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'arch'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'modulestring'	=> ( isa => 'Str|Undef', is => 'rw', default	=> "Agua::Workflow" );

# Objects
has 'conf'		=> ( isa => 'Conf::Yaml', is => 'rw', required	=>	0 );
has 'parser'=> ( isa => 'JSON', is => 'rw', lazy	=>	1, default => sub {
	return JSON->new->allow_nonref();	} );

has 'channel'	=> ( isa => 'Any', is => 'rw', required	=>	0 );
has 'virtual'	=> ( isa => 'Any', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );

has 'table'		=>	(
	is 			    =>	'rw',
	isa 		    =>	'Table::Main',
	lazy		    =>	1,
	builder		  =>	"setTable"
);

method setTable () {
  my $table = Table::Main->new({
    conf      =>  $self->conf(),
    log       =>  $self->log(),
    printlog  =>  $self->printlog(),
    logfile   =>  $self->logfile()
  });

  $self->table($table); 
}

method BUILD ($args) {
  #### SET LOGS
  $self->log( $args->{ log } ) if defined $args->{ log };
  $self->printlog( $args->{ printlog } ) if defined $args->{ printlog };

  #### KILL EXISTING PROCESSES
	$self->killProcesses( $self->processname() );	
}

method killProcesses ( $processname ) {
	my $processid = $$;
	$self->logDebug( "processid", $processid );
	my $ps = "ps aux | grep $processname | grep -v $processid | tr -s ' '| cut -f 2 -d \" \" | xargs -L 1 kill -9";
	print `$ps`;
}

method run ($args) {

	#### SET LOG
	my $installdir	=	$ENV{'FLOW_HOME'};
	print "Environment variable not defined: FLOW_HOME\n" and exit if not defined $installdir;
	my $logfile     =   "$installdir/log/seneschal.log";
	my $json 		=	undef;
	my $help;
  {
    local @ARGV = @$args;
		GetOptions (
        'json=s'  		=> \$json,
        'log=i'  		  => \$self->{log},
        'printlog=i'  => \$self->{printlog},
        'logfile=s'  	=> \$self->{logfile},
		    'help'        => \$help
		) or die "No options specified. Try '--help'\n";
		usage() if defined $help;

		my $configfile    =    "$installdir/conf/config.yml";
		my $conf = Conf::Yaml->new(
		    inputfile   =>  $configfile,
		    backup      =>  1,
		    log         =>  2,
		    printlog    =>  4,
		    logfile     =>    $logfile
		);
		$self->conf($conf);
	}

	if ( scalar(@$args) == 0 or $$args[0] =~ /^-/ ) {
		$self->listen();
	}
	else {
		my $subcommand 	= 	shift @$args;
		$self->logDebug("subcommand", $subcommand);
		return if not $self->supportedCommand($subcommand);

		#### CONVERT JSON TO DAT
		$self->logDebug("json", $json);
		my $data = $self->parser()->decode($json);
		$self->logDebug("data", $data);
		$self->$subcommand($data);		
	}
}


method listen {
	#### LISTEN FOR TASKS SENT FROM MASTER
	my $queuename 	= 	$self->conf()->getKey( "mq:exchange:worker" );
	# $self->logDebug( "queuename", $queuename );
	my $handler		=	"handleTask";
	$self->receiveTask($queuename, $handler);
}

##### TASKS
method receiveTask ($queuename, $handler) {
	
	$self->logDebug("queuename", $queuename);
	$self->logDebug("handler", $handler);

	#### NB: (RECEIVER) QUEUENAME = ROUTING_KEY (SENDER)

	#### CONNECTION
	my $connection = $self->newConnection();	
	my $channelid = 1;
	my $channel = $connection->channel_open($channelid);

	$connection->basic_qos($channelid,{ prefetch_count => 1 }) ;

	#### QUEUE DECLARE
	$connection->queue_declare(
		$channelid,
		$queuename,
		{
			durable => 1,
			auto_delete => 0
		}
	);

	#### CONSUME
	my $hostname = $self->getHostname();
	$connection->consume(
		$channelid,
		$queuename,
		{
			consumer_tag => $hostname,
			no_ack       => 0,
			exclusive    => 0

			#durable => 1,
			#exchange => "chat",
			#routing_key =>  ""
		}
	) ;

	#### NOTE THAT recv() is BLOCKING!!!
	while ( my $payload = $connection->recv() )
	{
		last if not defined $payload ;
		my $body  = $payload->{body} ;
		my $dtag  = $payload->{delivery_tag} ;
		my ($sec) = ( $body =~ m{(\d+)} ) ;

		print "[x] Received from queue $queuename: ", substr($body, 0, 400), "\n";

		$self->$handler($body);

		$connection->ack($channelid,$dtag,) ;
	}
}

method handleTask ($json) {
	$self->logDebug("$$ json", $json);
	my $data = $self->parser()->decode($json);

	# #### CHECK sendtype
	# my $sendtype = $data->{ sendtype };
	# $self->logDebug("sendtype", $sendtype);
	# # return 0 if $sendtype ne "task";

	$data->{ start }		=  	1;
	$data->{ conf }		  =   $self->conf();
	$data->{ log }		  =   $self->log();
	$data->{ logfile }	=   $self->logfile();
	$data->{ printlog }	=   $self->printlog();	
	$data->{ worker }		=	  $self;

	my $stageobject = $self->stageFactory( $data );
	$self->logDebug( "stageobject", $stageobject );

	# #### SET STATUS TO running
	# $self->conf()->setKey("workflow:status", "running");

	# try {
	# 	$workflow->executeWorkflow($data);	
	# }
	# catch {
	# 	$self->logDebug("FAILED to handle task with json", $json);
	# }

	# #### SET STATUS TO completed
	# $self->conf()->setKey( "workflow:status", "completed");

	# #### SHUT DOWN TASK LISTENER IF SPECIFIED IN config.yml
	# $self->verifyShutdown();
	
	# $self->logDebug("END handletask");
}

method stageFactory ( $stage ) {
	$self->logDebug( "stage", $stage );
	my $profilehash = $stage->{profile};
	$self->logDebug( "profilehash", $profilehash );

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

# method sendTask ($queuename, $data) {
# 	$self->logDebug("queuename", $queuename);
# 	$self->logDebug("data", $data);

# 	my $processid	=	$$;
# 	#$self->logDebug("processid", $processid);
# 	$data->{ processid }	=	$processid;

# 	#### ADD UNIQUE IDENTIFIERS
# 	$data	=	$self->addTaskIdentifiers($data);

# 	my $parser = JSON->new();
# 	my $message = $parser->encode($data);
# 	$self->logDebug("message", substr($message, 0, 1000));

# 	#### GET HOST
# 	my $host		=	$self->conf()->getKey( "mq:host", undef);
# 	$self->logDebug("host", $host);

# 	#### GET CONNECTION
# 	my $connection	=	$self->newConnection();

# 	my $channelid = 1;
# 	my $channel = $connection->channel_open($channelid);

# 	$connection->queue_declare(
# 		$channelid,
# 		$queuename,
# 		{
# 			queue 	=> $queuename,
# 			durable => 1,
# 			auto_delete => 0
# 		}
# 	);
	
# 	$connection->publish(
# 		$channelid,
# 		$queuename,
# 		$message,
# 		{
# 			routing_key => $queuename,
# 			exchange => ""
# 		}
# 	);

# 	print " [x] Sent TASK on host $host queuename '$queuename': $data->{ mode }: $message\n";

# 	#$self->logDebug("disconnecting connection");
# 	#$connection->disconnect();
# }

method addTaskIdentifiers ($task) {
	#### SET TIME
	$task->{time}		=	$self->getMysqlTime();
	
	##### SET IP ADDRESS
	my $ipaddress			=	 $self->getIpAdress();
	$ipaddress				=~	s/\s+$//;
	$task->{ipaddress}		=	$ipaddress;

	#### SET TOKEN
	$task->{token}		=	$self->token();
	
	#### SET SENDTYPE
	$task->{sendtype}	=	$self->sendtype();
	
	#### SET DATABASE
	$self->setDbh() if not defined $self->db();
	$task->{database} 	= 	$self->db()->database() || "";

	#### SET USERNAME		
	$task->{username} 	= 	$task->{username};

	#### SET SOURCE ID
	$task->{sourceid} 	= 	$self->sourceid();
	
	#### SET CALLBACK
	$task->{callback} 	= 	$self->callback();
	
	#$self->logDebug("Returning task", $task);
	
	return $task;
}


} #### END


