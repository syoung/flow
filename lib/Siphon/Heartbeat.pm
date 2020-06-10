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


# Integers
has 'log'	=> ( isa => 'Int', 		is => 'rw', default	=> 	2	);  
has 'printlog'	=> ( isa => 'Int', 		is => 'rw', default	=> 	2	);
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 60 );

# Strings
has 'exchange'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"inbound.host.status" );
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



method initialise ($hash) {
	#### SET SLOTS
	$self->setSlots($hash);
	$self->logDebug("AFTER self->setSlots()");
}

method monitor {

	$self->logDebug("");
	
	while ( 1 ) {
		#### SEND 'HEARTBEAT' NODE STATUS INFO
		$self->logDebug("DOING self->heartbeat");
		$self->heartbeat();

		$self->logDebug("DOING self->checkWorker");
		$self->checkWorker();

		my $sleep	=	$self->sleep();
		print "Siphon::Heartbeat::monitor    Sleeping $sleep seconds before checkWorker\n";
		sleep($sleep);
	}	
}

#### HEARTBEAT
method heartbeat {
	
	my $time		=	$self->getMysqlTime();
	my $host		=	$self->getHostname();
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
	
	my $nfsio	=	$self->getNfsIo();
	#$self->logDebug("nfsio", $nfsio);

	my $disk	=	$self->getDisk();
	#$self->logDebug("disk", $disk);

	my $memory	=	$self->getMemory();
	#$self->logDebug("memory", $memory);
		
	my $data	=	{
		queue		=>	$self->queue(),
		host		=>	$host,
		ipaddress	=>	$ipaddress,
		cpu			=>	$cpu,
		io			=>	$io,
		nfsio		=>	$nfsio,
		disk		=>	$disk,
		memory		=>	$memory,
		time		=>	$time,
		mode		=>	"updateHeartbeat"
	};
	#$self->logDebug("data", $data);

	try {
		$self->sendTask($self->queue(), $data);
	}
	catch {
		$self->logDebug("FAILED TO SEND HEARTBEAT", $data);
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
	print "Returning. Can't find logfile: $logfile\n" and return if not -f $logfile;

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



}

