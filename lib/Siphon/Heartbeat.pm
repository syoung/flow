use MooseX::Declare;

=head2

NOTES

	Use SSH to parse logs and execute commands on remote nodes
	
TO DO

	Use queues to communicate between master and nodes:
	
		WORKERS REPORT STATUS TO MANAGER
	
		MANAGER DIRECTS WORKERS TO:
		
			- DEPLOY APPS
			
			- PROVIDE WORKFLOW STATUS
			
			- STOP/START WORKFLOWS

=cut

use strict;
use warnings;

class Siphon::Heartbeat with (Util::Logger, Exchange, Util::Timer) {

use FindBin qw($Bin);
use TryCatch;
use Table::Main;

# Integers
has 'log'	=> ( isa => 'Int', 		is => 'rw', default	=> 	2	);  
has 'printlog'	=> ( isa => 'Int', 		is => 'rw', default	=> 	2	);
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 6 );

# Strings
has 'processname' => ( is => 'Str', is => 'rw', default => "heartbeat" );
has 'queue'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"inbound.host.heartbeat" );
has 'database'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'command'	=> ( isa => 'Str|Undef', is => 'rw'	);
has 'logfile'	=> ( isa => 'Str|Undef', is => 'rw'	);
has 'arch'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );


# Objects
has 'conf'		=> ( isa => 'Conf::Yaml', is => 'rw', required	=>	0 );
has 'jsonparser'=> ( isa => 'JSON', is => 'rw', lazy	=>	1, builder	=>	"setParser" );

# has 'db'		=> ( isa => 'Agua::DBase::MySQL', is => 'rw', required	=>	0 );

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
	$self->killProcesses( $self->processname() );	
}

method killProcesses ( $processname ) {
	my $processid = $$;
	$self->logDebug( "processid", $processid );
	my $ps = "ps aux | grep $processname | grep -v $processid | tr -s ' '| cut -f 2 -d \" \" | xargs -L 1 kill -9";
	print `$ps`;
}

method monitor {

	$self->logDebug("");
	
	while ( 1 ) {
		#### SEND host STATUS
		$self->heartbeat();

		#### CHECK worker IS RUNNING, RESTART IF NOT
		$self->checkWorker();

		#### PAUSE
		my $sleep	=	$self->sleep();
		print "Siphon::Heartbeat::monitor    Sleeping $sleep seconds\n";
		sleep($sleep);
	}	
}

#### HEARTBEAT
method heartbeat {
	my $time		=	$self->getMysqlTime();
	$self->logDebug( "time", $time );
	my $host		=	$self->getHostname();
	$self->logDebug( "host", $host );
	my $ipaddress	=	$self->getIpAddress();
	$self->logDebug("ipaddress", $ipaddress);

	my $arch	=	$self->getArch();
	if ( $arch eq "ubuntu" ) {
		`if [ ! -f /usr/bin/mpstat ]; then  apt-get install -y sysstat; fi`;
	}
	elsif ( $arch eq "centos" ) {
		`if [ ! -f /usr/bin/mpstat ]; then  yum install -y sysstat; fi`;
	}
	
	my $cpu		=	$self->getCpu();
	#$self->logDebug("cpu", $cpu);
	
	my $io		=	$self->getIo();
	#$self->logDebug("io", $io);
	
	# my $nfsio	=	$self->getNfsIo();
	#$self->logDebug("nfsio", $nfsio);
	my $nfsio = "";

	my $disk	=	$self->getDisk();
	#$self->logDebug("disk", $disk);

	my $memory	=	$self->getMemory();
	#$self->logDebug("memory", $memory);
		
	my $data	=	{
		queue		  =>	$self->queue(),
		host		  =>	$host,
		ipaddress	=>	$ipaddress,
		cpu			  =>	$cpu,
		io			  =>	$io,
		nfsio		  =>	$nfsio,
		disk		  =>	$disk,
		memory		=>	$memory,
		time		  =>	$time,
		mode		  =>	"updateHeartbeat"
	};
	#$self->logDebug("data", $data);

	try {
		$self->sendTask($self->queue(), $data);

	}
	catch {
		$self->logDebug( "FAILED TO SEND HEARTBEAT" );
	}

	try {
		print "BEFORE updateHeartbeat\n";
		$self->updateHeartbeat( $data );		
	}
	catch {
		$self->logDebug( "FAILED TO UPDATE DATABASE. ADDING TO failed TABLE" );
		$self->addToFailed( $data );
	}
}

method getIo {
	return `iostat`;
}

method getNfsIo {
	return `nfsiostat -m 10 1`;
}

method getCpu {
	return `mpstat`;
}

method getDisk {
	return `df -ah`;
}

method getMemory {
	return `sar -r 1 1`;
}

#### CHECK WORKER
method checkWorker {
	my $name		=	"worker";
	my $logfile		=	"/var/log/upstart/$name.log";
	
	$self->logDebug("logfile", $logfile);
	print "Skipping checkWorker as file missing: $logfile\n" and return if not -f $logfile;

	my $command		=	"tail $logfile";
	$self->logDebug("command", $command);
	my $log	=	`$command`;
	$self->logDebug("log", $log);
	if ( $log =~	/Heartbeat lost/msi ) {
		print "HEARTBEAT LOST. Doing restartUpstart($name, $logfile)\n";
		$self->logDebug("HEARTBEAT LOST    Doing restartUpstart($name, $logfile)");	
		$self->restartUpstart($name, $logfile);
	}
}

method restartUpstart ($name, $logfile) {
	$self->logDebug("name", $name);
	$self->logDebug("logfile", $logfile);

	my $command		=	qq{ps aux | grep "perl /usr/bin/$name"};
	$self->logDebug("command", $command);
	my $output	=	`$command`;
	$self->logDebug("output", $output);
	my $processes;
	@$processes	=	split "\n", $output;
	#$self->logDebug("processes", $processes);
	foreach my $process ( @$processes ) {
		#$self->logDebug("process", $process);
		my ($pid)	=	$process	=~	/^\S+\s+(\S+)/;
		my $command	=	"kill -9 $pid";
		$self->logDebug("KILL command", $command);
		`$command`;
	}
	
	#### REMOVE LOG FILE
	$command	=	"rm -fr $logfile";
	$self->logDebug("DELETE command", $command);
	`$command`;
	
	#### RESTART UPSTART PROCESS
	$command	=	"service $name restart";
	$self->logDebug("RESTART command", $command);
	`$command`;
	
	$self->logDebug("END");
}

method updateHeartbeat ($data) {
	$self->logDebug("data->{host}", $data->{host});
	$self->logDebug("data->{time}", $data->{time});

	my $time = $data->{ time };
	my $keys	=	[ "host", "time" ];
	my $notdefined	=	$self->table()->db()->notDefined($data, $keys);	
	$self->logDebug("notdefined", $notdefined) and return if @$notdefined;

	#### ADD TO TABLE
	my $table		=	"heartbeat";
	my $fields		=	$self->table()->db()->fields($table);
	$self->table()->_addToTable($table, $data, $keys, $fields);
}

method  ($data) {
	my $time = $data->{ time };
	my $host = $data->{ host };

	my $table		=	"failed";
	my $source  = "heartbeat";
	my $entry = {
		source => $source,
		time   => $time,
		time   => $host,
		data   => $data
	};

	my $keys    = [ "time", "host" ];
	my $fields	=	$self->table()->db()->fields($table);
	$self->table()->_addToTable($table, $entry, $keys, $fields);
}


}

