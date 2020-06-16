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

class Siphon::Nurse with (Util::Logger, Util::Timer,Exchange) {

#### EXTERNAL
use Getopt::Long;
Getopt::Long::Configure(qw(no_ignore_case bundling pass_through));

#### EXTERNAL MODULES
use FindBin qw($Bin);
use Test::More;

#### INTERNAL
use Conf::Yaml;
use Table::Main;
use Virtual::Factory;
use sigtrap 'handler' => *Siphon::Nurse::killProcesses, 'stack-trace', 'error-signals';
use TryCatch;

# Integers
has 'log'	=>  ( isa => 'Int', is => 'rw', default => 4 );
has 'printlog'	 =>  ( isa => 'Int', is => 'rw', default => 5 );
has 'maxjobs'	   =>  ( isa => 'Int', is => 'rw', default => 1 );
has 'sleep'		   =>  ( isa => 'Int', is => 'rw', default => 1 );
has 'messages'	 =>  ( isa => 'Int', is => 'rw', default => 0 );

# Strings
has 'processname' => ( is => 'Str', is => 'rw', default => "nurse" );
has 'queuename'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"inbound.host.heartbeat" );
has 'metric'	   => ( isa => 'Str|Undef', is => 'rw', default	=>	"cpus" );
has 'user'		   => ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'pass'		   => ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'host'		   => ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'vhost'		   => ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'modulestring'	=> ( isa => 'Str|Undef', is => 'rw', default	=> "Agua::Workflow" );
has 'rabbitmqctl'	=> ( isa => 'Str|Undef', is => 'rw', default	=> "/usr/sbin/rabbitmqctl" );

# Objects
has 'modules'	   => ( isa => 'ArrayRef|Undef', is => 'rw', lazy	=>	1, builder	=>	"setModules");
has 'conf'		   => ( isa => 'Conf::Yaml', is => 'rw', required	=>	0 );

has 'jsonparser' => ( isa => 'JSON', is => 'rw', lazy	=>	1, builder	=>	"setParser" );

has 'virtual'	   => ( isa => 'Any', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );

has 'duplicate'  => ( isa => 'HashRef|Undef', is => 'rw');
has 'channel'	   => ( isa => 'Any', is => 'rw', required	=>	0 );


has 'table'		=>	(
	is 			=>	'rw',
	isa 		=>	'Table::Main',
	lazy		=>	1,
	builder		=>	"setTable"
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
	$self->logDebug( "processname", $processname );
	my $processid = $$;
	$self->logDebug( "processid", $processid );
	my $ps = "ps aux | grep $processname | grep -v $processid | tr -s ' '| cut -f 2 -d \" \" | xargs -L 1 kill -9";
	print `$ps`;
}

method run ($args) {

	my $installdir	=	$ENV{'FLOW_HOME'};

	my $logfile     =   "$installdir/log/listener.log";
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

		$self->logDebug("json", $json);

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
	
	my $queuename	=	$self->queuename();
	my $handler 	=	*Siphon::Nurse::handleTask;
	$self->receiveTask( $queuename, $handler );
}

method handleTask ($json) {
	$self->logDebug("json", substr($json, 0, 200));

	my $data = $self->jsonparser()->decode($json);
	#$self->logDebug("data", $data);

	my $mode =	$data->{mode} || "";
	$self->logDebug("mode", $mode);

	try {
		print "INSIDE TRY ***************\n";
		$self->$mode($data);		
	}
	catch {
		print "INSIDE CATCH ***************\n";
		$self->logCritical( "Failed to handle task mode: $mode\n" );
		print "Failed to handle task mode: $mode\n";
	}
}

method memberOfArray ( $array, $value ) {
	foreach my $entry ( @$array ) {
		return 1 if $entry eq $value;
	}

	return 0;
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
	$self->logDebug("data->{host}", $data->{host});
	$self->logDebug("data->{time}", $data->{time});

	my $keys	=	[ "host", "time" ];
	my $notdefined	=	$self->notDefined($data, $keys);	
	$self->logDebug("notdefined", $notdefined) and return if @$notdefined;

	#### ADD TO TABLE
	my $table		=	"heartbeat";
	my $fields		=	$self->table()->db()->fields($table);
	$self->logDebug( "keys", $keys );
	$self->logDebug( "fields", $fields );

	try {
		$self->table()->_addToTable($table, $data, $keys, $fields);
	}
	catch {
		print "FAILED TO ADD TO TABLE: $table\n";
		$self->addToFailed( $data );
	}
}

method addToFailed( $data ) {
	$self->logDebug( "data", $data );

	my $time = $data->{ time };
	my $host = $data->{ host };
	my $parser = JSON->new();
	my $message = $parser->pretty->indent->encode( $data );

	my $entry = {
		host    => $host,
		time    => $time,
		message => $message
	};

	#### ADD TO TABLE
	my $table		=	"failed";
	my $keys    = [ "host", "time", "message" ];
	my $fields		=	$self->table()->db()->fields($table);
	$self->logDebug( "keys", $keys );
	$self->logDebug( "fields", $fields );
	$self->table()->_addToTable($table, $entry, $keys, $fields);
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

END {
	print "IN Siphon::Nurse::END ***************************\n";

	my $processname = "nurse";
	print "Processesname: $processname\n";
	# $self->logDebug( "processname", $processname );
	my $processid = $$;
	print "Processid: $processid\n";
	# $self->logDebug( "processid", $processid );
	my $ps = "ps aux | grep $processname | grep -v $processid | tr -s ' '| cut -f 2 -d \" \" | xargs -L 1 kill -9";
	print `$ps`;

}	
	
	
}


