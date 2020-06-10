use MooseX::Declare;

=head2

PURPOSE

	Run tasks on worker nodes using task queue

	Use queues to communicate between master and workers:
	
		MASTER:
			
			DIRECT WORKERS TO:
		
			- DEPLOY APPS
			
			- PROVIDE WORKFLOW STATUS
			
			- STOP/START WORKFLOWS

		WORKERS:
		
			REPORT HOST STATUS
			
			REPORT JOB COMPLETION STATUS
	
=cut

use strict;
use warnings;

class Siphon::Listener with (Logger, Exchange, Agua::Common::Database, Agua::Common::Timer, Agua::Common::Project, Agua::Common::Stage, Agua::Common::Workflow, Agua::Common::Util) {

#### EXTERNAL
use Getopt::Long;
Getopt::Long::Configure(qw(no_ignore_case bundling pass_through));

{

# Integers
has 'log'	=>  ( isa => 'Int', is => 'rw', default => 2 );
has 'printlog'	=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'maxjobs'	=>  ( isa => 'Int', is => 'rw', default => 1 );
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 1 );

# Strings
has 'metric'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"cpus" );
has 'user'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'pass'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'host'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'vhost'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'modulestring'	=> ( isa => 'Str|Undef', is => 'rw', default	=> "Agua::Workflow" );
has 'rabbitmqctl'	=> ( isa => 'Str|Undef', is => 'rw', default	=> "/usr/sbin/rabbitmqctl" );

# Objects
has 'modules'	=> ( isa => 'ArrayRef|Undef', is => 'rw', lazy	=>	1, builder	=>	"setModules");
has 'conf'		=> ( isa => 'Conf::Yaml', is => 'rw', required	=>	0 );

# has 'synapse'	=> ( isa => 'Synapse', is => 'rw', lazy	=>	1, builder	=>	"setSynapse" );

has 'db'		=> ( isa => 'Agua::DBase::MySQL', is => 'rw', lazy	=>	1,	builder	=>	"setDbh" );

has 'jsonparser'=> ( isa => 'JSON', is => 'rw', lazy	=>	1, builder	=>	"setParser" );

has 'virtual'	=> ( isa => 'Any', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );

has 'duplicate'	=> ( isa => 'HashRef|Undef', is => 'rw');
has 'channel'	=> ( isa => 'Any', is => 'rw', required	=>	0 );


}

#### EXTERNAL MODULES
use FindBin qw($Bin);
use Test::More;

#### INTERNAL MODULES
use Virtual::Openstack;
#use Synapse;
use Virtual;

#####////}}}}}

method BUILD ($args) {
	$self->initialise($args);	
}

method initialise ($args) {
	#$self->logDebug("args", $args);
	#$self->manage();
}

method run ($args) {

	my $installdir	=	$ENV{'installdir'} || "/a";
	my $logfile     =   "$installdir/log/listener.log";
	my $json 		=	undef;
	my $help;
    {
        local @ARGV = @$args;
		GetOptions (
            'json=s'  		=> \$json,

            'log=i'  		=> \$self->{log},
            'printlog=i'  	=> \$self->{printlog},
            'logfile=s'  	=> \$self->{logfile},
		    'help'          => \$help
		) or die "No options specified. Try '--help'\n";
		usage() if defined $help;

		$self->logDebug("json", $json);

		my $configfile    =    "$installdir/conf/config.yaml";
		my $conf = Conf::Yaml->new(
		    inputfile   =>  $configfile,
		    backup      =>  1,
		    log         =>  2,
		    printlog    =>  4,
		    logfile     =>    $logfile
		);
		$self->conf($conf);
	}

	if ( defined $json ) {
		$self->handleTask($json);		
	}
	else {
		$self->listen();
	}
}

#### LISTEN
method listen {
	$self->logDebug("");
	
	my $taskqueues	=	["update.job.status", "update.host.status"];
	my $handler 	=	*Siphon::Listener::handleTask;
	$self->receiveTask($taskqueues, $handler);
}

#### TASKS
method receiveTask ($taskqueues, $handler) {
	# my $exchange = "gravity.checks";
	#$self->logDebug("taskqueues", $taskqueues);

	my $host		=	$self->host() || $self->conf()->getKey("queue:host", undef);
	$host = "localhost";
	$self->logDebug("host", $host);

	#### OPEN CONNECTION
	my $connection	=	$self->newConnection();	
	my $channelid  = 1;
	my $channel = $connection->channel_open($channelid);
	
	$connection->basic_qos($channelid,{ prefetch_count => 1 });
	
	my %declare_opts = (
		durable => 1,
		auto_delete => 0
	);

	foreach my $taskqueue ( @$taskqueues ) {
		$self->logDebug("taskqueue", $taskqueue);
		$self->logDebug("DOING connection->queue_declare($channelid, $taskqueue, declare_opts", \%declare_opts);

		$connection->queue_declare($channelid, $taskqueue, \%declare_opts);

		my %consume_opts = (
			exchange => $taskqueue,
			routing_key =>  ""
		);
		$connection->consume($channelid, $taskqueue, \%consume_opts);
	}
							
	#### NB: recv IS BLOCKING
	my $this	=	$self;
	while ( my $payload = $connection->recv() ) {
		last if not defined $payload;
		my $body  = $payload->{body};
		print " [x] Received task on host $host: ", substr($body, 0, 500) , "\n";
	
		my $dtag  = $payload->{delivery_tag};
	
		#### RUN TASK
		&$handler($this, $body);
		
		my $sleep	=	$self->sleep();
		print "Sleeping $sleep seconds\n";
		sleep($sleep);
			
		#### SEND ACK AFTER TASK COMPLETED
		$connection->ack($channelid,$dtag,);
	}		
	
	#### SET self->connection
	$self->connection($connection);
	
	# Wait forever
	AnyEvent->condvar->recv;	
}

method handleTask ($json) {
	#$self->logDebug("json", substr($json, 0, 200));

	my $data = $self->jsonparser()->decode($json);
	#$self->logDebug("data", $data);

	my $mode =	$data->{mode} || "";
	#$self->logDebug("mode", $mode);
	
	if ( $self->can($mode) ) {
		$self->$mode($data);
	}
	else {
		print "mode not supported: $mode\n";
		$self->logDebug("mode not supported: $mode");
	}
}

method notDefined ($hash, $fields) {
	return [] if not defined $hash or not defined $fields or not @$fields;
	
	my $notDefined = [];
    for ( my $i = 0; $i < @$fields; $i++ ) {
        push( @$notDefined, $$fields[$i]) if not defined $$hash{$$fields[$i]};
    }

    return $notDefined;
}

#### UPDATE
method updateJobStatus ($data) {
	$self->logNote("data", $data);
	$self->logDebug("data not defined") and return if not defined $data;
	$self->logDebug("sample not defined") and return if not defined $data->{sample};
	$self->logDebug("$data->{host} $data->{sample} $data->{status}");
	
	#### UPDATE queuesamples TABLE
	$self->updateQueueSample($data);	

	#### UPDATE provenance TABLE
	$self->updateProvenance($data);	
}

method updateHeartbeat ($data) {
	$self->logDebug("host $data->{host} $data->{ipaddress} [$data->{time}]");
	#$self->logDebug("data", $data);
	my $keys	=	[ "host", "time" ];
	my $notdefined	=	$self->notDefined($data, $keys);	
	$self->logDebug("notdefined", $notdefined) and return if @$notdefined;

	#### ADD TO TABLE
	my $table		=	"heartbeat";
	my $fields		=	$self->db()->fields($table);
	$self->_addToTable($table, $data, $keys, $fields);
}

method updateProvenance ($data) {
	$self->logDebug("$data->{sample} $data->{status} $data->{time}");
	my $keys	=	[ "username", "project", "workflow", "workflownumber", "sample" ];
	my $notdefined	=	$self->notDefined($data, $keys);	
	$self->logDebug("notdefined", $notdefined) and return if @$notdefined;

	#### ADD TO provenance TABLE
	my $table		=	"provenance";
	my $fields		=	$self->db()->fields($table);
	my $success		=	$self->_addToTable($table, $data, $keys, $fields);
	$self->logDebug("addToTable 'provenance'    success", $success);
}
method updateQueueSample ($data) {
	$self->logDebug("data", $data);	
	$self->logDebug("$data->{sample} $data->{status} $data->{time}");
	
	#### UPDATE queuesample TABLE
	my $table	=	"queuesample";
	my $keys	=	[ "sample" ];
	$self->_removeFromTable($table, $data, $keys);
	
	$keys	=	["username", "project", "workflow", "workflownumber", "sample", "status" ];
	$self->_addToTable($table, $data, $keys);
}
#### DELETE
method deleteInstance ($data) {
	$self->logDebug("data", $data);
	my $instanceid	=	$data->{instanceid};
	$self->logDebug("instanceid", $instanceid);

	my $success		=	$self->virtual()->deleteNode($instanceid);
	$self->logDebug("success", $success);

	$self->updateInstanceStatus($instanceid, "deleted");

	return $success;
}

method getUsernameFromInstance ($ipaddress) {
	$self->logDebug("ipaddress", $ipaddress);
	my $query		=	qq{SELECT queue FROM instance
WHERE LOWER(ipaddress) LIKE LOWER('$ipaddress')
};
	$self->logDebug("query", $query);
	my $queue		=	$self->db()->query($query);
	$self->logDebug("queue", $queue);
	
	my ($username)	=	$queue	=~	/^([^\.]+)\./;
	$self->logDebug("username", $username);
	
	return $username;
}

method updateInstanceStatus ($instanceid, $status) {
	$self->logNote("instanceid", $instanceid);
	$self->logNote("status", $status);
	
	my $time		=	$self->getMysqlTime();
	my $query		=	qq{UPDATE instance
SET status='$status',
TIME='$time'
WHERE id='$instanceid'
};
	$self->logDebug("query", $query);
	
	return $self->db()->do($query);
}

#### UTILS
method exited ($nodename) {	
	my $entries	=	$self->virtual()->getEntries($nodename);
	foreach my $entry ( @$entries ) {
		my $internalip	=	$entry->{internalip};
		$self->logDebug("internalip", $internalip);
		my $status	=	$self->workflowStatus($internalip);	

		if ( $status =~ /Done, exiting/ ) {
			my $id	=	$entry->{id};
			$self->logDebug("DOING novaDelete($id)");
			$self->virtual()->novaDelete($id);
		}
	}
}

method runCommand ($command) {
	$self->logDebug("command", $command);
	
	return `$command`;
}

method setParser {
	return JSON->new->allow_nonref;
}

method setVirtual {
	my $virtualtype		=	$self->conf()->getKey("agua", "VIRTUALTYPE");
	$self->logDebug("virtualtype", $virtualtype);

	#### RETURN IF TYPE NOT SUPPORTED	
	$self->logDebug("virtual virtualtype not supported: $virtualtype") and return if $virtualtype !~	/^(aws|openstack|vagrant)$/;

   #### CREATE DB OBJECT USING DBASE FACTORY
    my $virtual = Virtual->new( $virtualtype,
        {
			conf		=>	$self->conf(),
            username	=>  $self->username(),
			
			logfile		=>	$self->logfile(),
			log			=>	$self->log(),
			printlog	=>	$self->printlog()
        }
    ) or die "Can't create virtual of type: $virtualtype. $!\n";
	$self->logDebug("virtual: $virtual");

	$self->virtual($virtual);
}

	
	
	
}


