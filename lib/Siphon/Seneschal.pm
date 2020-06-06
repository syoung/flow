use MooseX::Declare;

=head2

PURPOSE

	1. Use queues to communicate with nodes
	
   	- Direct workers to:
		
		- DEPLOY APPS
		
		- PROVIDE WORKFLOW STATUS
		
		- STOP/START WORKFLOWS

=cut

use strict;
use warnings;

class Siphon::Seneschal with (Logger, Exchange, Agua::Common::Database) {

use Timer;
use Agua::DBase::MySQL;
use Conf::Yaml;
use Getopt::Long;
Getopt::Long::Configure(qw(no_ignore_case bundling pass_through));

# Integers
has 'log'		=>  ( isa => 'Int', is => 'rw', default => 2 );
has 'printlog'	=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 120 );

# Strings
has 'database'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'user'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'pass'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'host'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'vhost'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'arch'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'modulestring'	=> ( isa => 'Str|Undef', is => 'rw', default	=> "Agua::Workflow" );

# Arrays
has 'commands'	=> ( isa => 'ArrayRef', is => 'rw', default => sub {
	[ 
	    "project",
	    "system",
	    "service",
	    "method",
	]
});

# Objects
has 'conf'		=> ( isa => 'Conf::Yaml', is => 'rw', required	=>	0 );
has 'jsonparser'=> ( isa => 'JSON', is => 'rw', lazy	=>	1, builder	=>	"setParser" );
has 'db'		=> ( isa => 'Agua::DBase::MySQL|Undef', is => 'rw', required	=>	0 );
has 'channel'	=> ( isa => 'Any', is => 'rw', required	=>	0 );
has 'virtual'	=> ( isa => 'Any', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );
has 'timer'	=> ( isa => 'Any', is => 'rw', lazy	=>	1, default	=>	sub { use Timer; Timer->new({"log" => 5}) }  );

use FindBin qw($Bin);
use TryCatch;

#####////}}}}}

method BUILD ($args) {
	$self->initialise($args);	
}

method initialise ($args) {
	#$self->logDebug("args", $args);	
}

method run ($args) {
	if ( scalar(@$args) == 0 or $$args[0] =~ /^-/ ) {
		$self->listen($args);
	}
	else {
		my $subcommand 	= 	shift @$args;
		$self->logDebug("subcommand", $subcommand);
		return if not $self->supportedCommand($subcommand);

		#### SET LOG
		my $installdir	=	$ENV{'installdir'} || "/a";
		my $logfile     =   "$installdir/log/seneschal.log";
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

			my $configfile    =    "$installdir/conf/config.yaml";
			my $conf = Conf::Yaml->new(
			    inputfile   =>  $configfile,
			    backup      =>  1,
			    log         =>  2,
			    printlog    =>  4,
			    logfile     =>    $logfile
			);
			$self->conf($conf);

			$self->logDebug("json", $json);
			my $data = $self->jsonparser()->decode($json);
			$self->logDebug("data", $data);
			$self->$subcommand($data);		
		}
	}
}

method supportedCommand ($command) {
	my $commands   =   $self->commands();
	$self->logDebug("commands", $commands);
	
	if ( not exists { map { $_ => 1 } @$commands	 }->{$command} ) {
 		print "Command '$command' is not in the list of  commands: @$commands\n";
		$self->usage();
		return 0;
	}

	return 1;
}

method listen ($args) {
	$self->logDebug("args", $args);

    {
        local @ARGV = @$args;
		GetOptions(
            'log=i'  		=> \$self->{log},
            'printlog=i'  	=> \$self->{printlog},
            'logfile=s'  	=> \$self->{logfile},
         ) or croak('Failed to parse with GetOptions. Unable to continue');
	}

    #### SET CONFIG
    $self->setConfig();

	my $exchangename = "direct_logs";
	my $handler = *Siphon::Seneschal::handleFanout;
	$self->receiveFanout($exchangename, $handler);
}

method setConfig {
	my $installdir = $ENV{'installdir'} || "/a";
	my $logfile		=   "$installdir/log/seneschal.log";
	my $configfile	=	"$installdir/conf/config.yaml";
	my $conf = Conf::Yaml->new(
	    inputfile   =>  $configfile,
	    backup      =>  1,
	    log         =>  $self->log(),
	    printlog    =>  $self->printlog(),
	    logfile     =>  $logfile
	);
	$self->conf($conf);	
}

method handleFanout ($json) {
	$self->logDebug("json", substr($json, 0, 200));
	my $data = $self->jsonparser()->decode($json);
	$self->logDebug("data", $data);
	my $hostips = $data->{hostips};
	$self->logDebug("hostips", $hostips);

	my $ipaddress	=	$self->getIpAddress();
	$self->logDebug("ipaddress", $ipaddress);

    my $included = $self->includedIp($hostips, $ipaddress);
    $self->logDebug("included", $included);

	if ( not $included ) {
		$self->logDebug("Returning. Host IP $ipaddress not in hostips", $hostips);
		return; 
	}

	my $queuename = "feedback";
	my $mode =	$data->{mode} || "";
	$self->logDebug("mode", $mode);
	
	if ( $self->can($mode) ) {

		#### RUN
		my $outputs 	= 	$self->$mode($data);
 		$self->logDebug("outputs", $outputs);

		#### REPORT
		my $time		=	$self->timer()->getMysqlTime();
		my $host		=	$self->getHostname();
		my $data		=	{
			queue		=>	$queuename,
			hostname	=>	$host,
			hostip		=>	$ipaddress,
			time		=>	$time,
			outputs		=>	$outputs,
			hostips		=>	$hostips,
			mode		=>	"handleFeedback"
		};

		$self->logDebug("data", $data);

		try {
			$self->logDebug("DOING sendTask(feedback, data)", $data);
			$self->sendTask($queuename, $data);
		}
		catch {
			my $error = $@;
			$self->logDebug("Error, sendTask failed", $@);
		}
	}
	else {
		print "mode not supported: $mode\n";
		$self->logDebug("mode not supported: $mode");
	}
}

method includedIp ($hostips, $ip) {
	$self->logDebug("hostips", $hostips);
	$self->logDebug("ip", $ip);

	return 1 if not defined $hostips;
	return 1 if not @$hostips;
 	foreach my $hostip ( @$hostips ) {
		$self->logDebug("hostip", $hostip); 		

 		return 1 if $hostip eq $ip;
 	}

 	return 0;
}

method method ($data) {
	my $mode =	$data->{mode} || "";
	$self->logDebug("mode", $mode);
	
	if ( $self->can($mode) ) {

		#### RUN
		my $outputs 	= 	$self->$mode($data);
 		$self->logDebug("outputs", $outputs);

		return $outputs;
	}	
}

method system ($data) {
	$self->logDebug("data", $data);

	my $commands	=	$data->{commands};
	$self->logDebug("commands", $commands);

	my $outputs = $self->commandOutputs($commands);
	$self->logDebug("outputs", $outputs);

	return $outputs;
}

method project ($data) {
	print "Siphon::Seneschal::project    data: $data\n";
	my $username 	= 	$data->{username};
	my $project 	= 	$data->{project};
	my $workflow 	= 	$data->{workflow};
	my $confdir		=	$data->{confdir};

	$self->logDebug("Changing directory to confdir:", $confdir);
	chdir($confdir);

	my $commands = [
	    "/a/bin/cli/flow deleteProject --project $project --username $username",
	    "/a/bin/cli/flow addProject --project $project --username $username",
	    "/a/bin/cli/flow addWorkflow --project $project --wkfile $confdir/$workflow.work --username $username",
	];

	my $outputs = $self->commandOutputs($commands);

	return $outputs;
}

method service ($data) {
	$self->logDebug("data", $data);
	my $service		=	$data->{service};
	my $command		=	$data->{subcommand};
	my $commands 	= 	[
	    "service $service $command",
	];

	my $outputs = $self->commandOutputs($commands);
	$self->logDebug("outputs", $outputs);

	return $outputs;
}

method restartUpstart ($name, $logfile) {
	$self->logDebug("name", $name);
	$self->logDebug("logfile", $logfile);

	my $command		=	qq{ps aux | grep "perl /usr/bin/$name"};
	$self->logDebug("ps command", $command);
	my $output	=	`$command`;
	#$self->logDebug("output", $output);
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

method commandOutputs ($commands) {
	$self->logDebug("commands", $commands);

	my $outputs = [];
	foreach my $command ( @$commands ) {
		$self->logDebug("command", $command);

		my $output = `$command`;
		$self->logDebug("output", $output);
		push @$outputs, {
			command => $command,
			output 	=>	$output
		};
	}

	return $outputs;
}

method doShutdown ($data) {
	$self->logDebug("data", $data);
	my $targethost		=	lc($data->{instanceid});
	$self->logDebug("targethost", $targethost);
	
	my $instanceid 		=	$self->getInstanceId();
	$self->logDebug("instanceid",
	 $instanceid);
	
	if ( $targethost !~ /^$instanceid$/i ) {
		$self->logDebug("No instanceid match ($targethost vs $instanceid). Skipping shutdown");
		return;
	}
		
	# #### SET INSTANCEID IN CONFIG
	# $self->conf()->setKey("agua:INSTANCEID", undef, $data->{host});

	my $status			=	$self->conf()->getKey("agua:STATUS", undef);
	$self->logDebug("status", $status);

	my $teardown		=	$data->{teardown};
	my $teardownfile	=	$data->{teardownfile};
	$self->logDebug("teardown", $teardown);
	$self->logDebug("teardownfile", $teardownfile);
	if ( defined $teardown ) {
		$self->printFile($teardownfile, $teardown);
		`chmod 755 $teardownfile`;
		$self->conf()->setKey("agua:TEARDOWNFILE", undef, $teardownfile);
	}	
	$self->logDebug("status", $status);
	
	#### IF NO WORKFLOW IS RUNNING THEN NOTIFY MASTER TO DELETE HOST
	if ( $status ne "running" ) {
		$self->logDebug("Executing teardownfile: $teardownfile");
	
		#### DO TEARDOWN
		my $teardownfile	=	$self->conf()->getKey("agua:TEARDOWNFILE", undef);
		$self->logDebug("teardownfile", $teardownfile);

		if ( defined $teardownfile and -f $teardownfile ) {
			$self->logDebug("Running teardownfile", $teardownfile);
			print `cat $teardownfile`;
			`$teardownfile`;
		}
		
		#### SEND DELETE INSTANCE
		$self->logDebug("DOING self->sendDeleteInstance()");
		$self->sendDeleteInstance($data->{instanceid});
	}

	else {
		#### SET SHUTDOWN TO true
		$self->conf()->setKey("agua:SHUTDOWN", undef, "true");
	}
	$self->logDebug("completed");
}

method getInstanceId {
	my $instanceid = `curl -s http://169.254.169.254/latest/meta-data/instance-id`;

	$instanceid =~ s/\s+$//g;

	return $instanceid;
}

method verifyShutdown {
	my $shutdown	=	$self->conf()->getKey("agua:SHUTDOWN", undef);
	$self->logDebug("shutdown", $shutdown);
	
	#### GET HOSTNAME FROM CONFIG
	my $host		=	$self->conf()->getKey("agua:HOSTNAME", undef);
	$self->logDebug("host", $host);

	if ( $shutdown eq "true" ) {
		$self->logDebug("DOING self->sendDeleteInstance($host)");
		$self->sendDeleteInstance($host);
	}
}

method sendDeleteInstance ($instanceid) {
	$self->logDebug("instanceid", $instanceid);
	
	my $data		=	{
		source		=>	"seneschal",
		instanceid	=>	$instanceid,
		mode		=>	"deleteInstance",
		queue		=>	"update.host.status"
	};

	#### REPORT HOST STATUS TO 
	$self->sendTask("update.host.status", $data);
}

method usage {
	print `/usr/bin/env perldoc $0`;
	exit;
}



} #### END
