use MooseX::Declare;

=head2

PURPOSE

	Run tasks on worker nodes using work queue (up to preset job count limit)

	Use queues to communicate between master and nodes:
	
		WORKERS: REPORT STATUS TO MASTER
	
		MASTER: DIRECT WORKERS TO:
		
			- DEPLOY APPS
			
			- PROVIDE WORKFLOW STATUS
			
			- STOP/START WORKFLOWS

=cut

use strict;
use warnings;

class Siphon::Queuer with (Siphon::Common, Logger, Exchange, Agua::Common::Database, Agua::Common::Timer, Agua::Common::Project, Agua::Common::Stage, Agua::Common::Workflow, Agua::Common::Util) {

#####////}}}}}

{

# Integers
has 'log'	=>  ( isa => 'Int', is => 'rw', default => 2 );
has 'printlog'	=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'maxjobs'	=>  ( isa => 'Int', is => 'rw', default => 61 );
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 30 );

# Strings
has 'sendtype'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"task" );
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
has 'synapse'	=> ( isa => 'Synapse', is => 'rw', lazy	=>	1, builder	=>	"setSynapse" );
has 'db'		=> ( isa => 'Agua::DBase::MySQL', is => 'rw', lazy	=>	1,	builder	=>	"setDbh" );
has 'jsonparser'=> ( isa => 'JSON', is => 'rw', lazy	=>	1, builder	=>	"setParser" );
has 'virtual'	=> ( isa => 'Any', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );
has 'duplicate'	=> ( isa => 'HashRef|Undef', is => 'rw');
has 'channel'	=> ( isa => 'Any', is => 'rw', required	=>	0 );

}

#### EXTERNAL MODULES
use FindBin qw($Bin);
use Test::More;
use POSIX qw(ceil floor);

#### INTERNAL MODULES
#use Virtual::Openstack;
use Synapse;
use Time::Local;
use Virtual;

#####////}}}}}

method BUILD ($args) {
	$self->initialise($args);	
}

method initialise ($args) {
	#$self->logDebug("args", $args);
	#$self->manage();
}

method manage {
	my $virtualtype	=	$self->conf()->getKey("agua", "VIRTUALTYPE");
	$self->logDebug("virtualtype", $virtualtype);
	
	if ( $virtualtype eq "openstack" ) {
		$self->manageOpenstack();
	}
	elsif ( $virtualtype eq "aws" ) {
		$self->manageAws();
	}
}

method manageAws {
	while ( 1 ) {
		my $username	=	$self->conf()->getKey("agua", "ADMINUSER");
		$self->logDebug("username", $username);

		#### GET PROJECTS
		my $projects	=	$self->getRunningUserProjects($username);
		$self->logDebug("projects", $projects);

		foreach my $project	( @$projects ) {
			$self->logDebug("project", $project);

			#### GET WORKFLOWS
			my $workflows	=	$self->getWorkflowsByProject({
				name		=>	$project,
				username	=>	$username
			});
			$self->logDebug("workflows", $workflows);
			next if not defined $workflows or not @$workflows;
			print "Queuer::manageAws    project $project workflows:\n";
			foreach my $workflow ( @$workflows ) {
				print "Queuer::manageAws    $project [$workflow->{number}] $workflow->{name}\n";
			}
			
			### MAINTAIN QUEUES
			$self->maintainQueues($workflows);
		}

		#### PAUSE
		$self->pause();
	}
	
	return 1;
}

method manageOpenstack {
	while ( 1 ) {
	
		#my $tenants		=	$self->getTenants();
		#$self->logDebug("tenants", $tenants);
		#foreach my $tenant ( @$tenants ) {
		#	my $username	=	$tenant->{username};
		#
			my $username	=	$self->conf()->getKey("agua", "ADMINUSER");
		$self->logDebug("username", $username);
		
			#### GET PROJECTS
			my $projects	=	$self->getRunningUserProjects($username);
			$self->logDebug("projects", $projects);

			foreach my $project	( @$projects ) {
				$self->logDebug("project", $project);
	
				#### GET WORKFLOWS
				my $workflows	=	$self->getWorkflowsByProject({
					name		=>	$project,
					username	=>	$username
				});
				$self->logDebug("workflows", $workflows);
				next if not defined $workflows or not @$workflows;
				print "Queuer::manage    project $project workflows:\n";
				foreach my $workflow ( @$workflows ) {
					print "Queuer::manage    $project [$workflow->{number}] $workflow->{name}\n";
				}
				#### MAINTAIN QUEUES
				$self->maintainQueues($workflows);
			}
		
		#}
		
		#### PAUSE
		$self->pause();
	}
	
	return 1;
}

#### MAINTAIN QUEUES
method maintainQueues($workflows) {
	#$self->logDebug("workflows", $workflows);
	
	print "\n\n#### DOING maintainQueues\n";
	for ( my $i = 0; $i < @$workflows; $i++ ) {
		my $workflow	=	$$workflows[$i];
		$self->logDebug("workflow $i", $workflow->{name});
		my $label	=	"[" . ($i + 1) . "] ". $$workflows[$i]->{name};
		
		if ( $i != 0 ) {
			$self->logDebug("$label NO COMPLETED JOBS in previous queue") and next if $self->noCompletedJobs($$workflows[$i - 1]);
		}
		
		$self->logDebug("$label DOING self->maintainQueue()");
		$self->maintainQueue($workflows, $workflow);
	}
}

method maintainQueue ($workflows, $workflowdata) {	
	#$self->logDebug("workflowdata", $workflowdata);
	
	my $queuename	=	$self->setQueueName($workflowdata);
	$self->logDebug("queuename", $queuename);
	
	my $workflowcompleted	=	$self->workflowCompleted($workflowdata);
	$self->logDebug("workflowcompleted", $workflowcompleted);
	$self->logDebug("Skipping completed queue", $queuename) and return if $workflowcompleted;
	
	#### GET MAX JOBS
	my $maxjobs		=	$self->maxJobsForQueue($workflowdata);
	$self->logDebug("FINAL maxjobs", $maxjobs);

	#### GET NUMBER OF QUEUED JOBS
	my $queuedjobs	=	$self->getQueuedJobs($workflowdata);
	my $numberqueued=	scalar(@$queuedjobs);
	$self->logDebug("numberqueued", $numberqueued);

	#### ADD MORE JOBS TO QUEUE IF LESS THAN maxjobs
	my $limit	=	$maxjobs - $numberqueued;
	$self->logDebug("limit", $limit);

	return 0 if $limit <= 0;

	#### QUEUE UP ADDITIONAL SAMPLES
	my $tasks	=	$self->getTasks($workflows, $workflowdata, $limit);
	#$self->logDebug("tasks", $tasks);
	$self->logDebug("no. tasks", scalar(@$tasks)) if defined $tasks;
	$self->logDebug("tasks: undefined") if not defined $tasks;
	return 0 if not defined $tasks;

	if ( $numberqueued == 0 and not @$tasks ) {
		$self->logDebug("Setting workflow $workflowdata->{workflow} status to 'completed'");
		$self->setWorkflowStatus($workflowdata->{username}, $workflowdata->{project}, $workflowdata->{workflow}, "completed");
	}
	elsif ( @$tasks ) {
		foreach my $task ( @$tasks ) {
			
			$task->{sendtype}	=	$self->sendtype();
			
			my $queuename = "tasks";
			$self->sendTask($queuename, $task);
		
			$self->updateJobStatus($task);
		}
	}
	
	return 1;
}

method noCompletedJobs ($workflow) {
	my $query	=	qq{SELECT COUNT(*) FROM queuesample
WHERE username='$workflow->{username}'
AND project='$workflow->{project}'
AND workflow='$workflow->{workflow}'
AND workflownumber='$workflow->{workflownumber}'
AND status='completed'};
	$self->logDebug("query", $query);
	
	my $completed	=	$self->db()->query($query);
	#$self->logDebug("completed", $completed);
	
	return 1 if $completed == 0;
	return 0;
}

method setWorkflowCompleted ($workflowdata) {
	my $query	=	qq{UPDATE workflow
SET status='completed'
WHERE username='$workflowdata->{username}'
AND project='$workflowdata->{project}'
AND name='$workflowdata->{name}'
};
	$self->logDebug("query", $query);

	return $self->db()->do($query);
}

method workflowCompleted ($workflowdata) {
	my $query	=	qq{SELECT 1 FROM workflow
WHERE username='$workflowdata->{username}'
AND project='$workflowdata->{project}'
AND name='$workflowdata->{name}'
AND status='completed'};
	#$self->logDebug("query", $query);
	
	return 1 if defined $self->db()->query($query);
	return 0;
}

method getTasks ($queues, $queuedata, $limit) {

	#### GET ADDITIONAL SAMPLES TO ADD TO QUEUE
	$self->logDebug("queuedata", $queuedata);
	$self->logDebug("limit", $limit);

	#### GET SAMPLE TABLE
	my $sampletable	=	$self->getSampleTable($queuedata);
	#$self->logDebug("sampletable", $sampletable);
	print "Queuer::getTasks    sampletable not defined\n" and exit if not defined $sampletable;

	#### POPULATE QUEUE SAMPLE TABLE IF EMPTY	
	my $workflownumber	=	$queuedata->{workflownumber};
	#$self->logDebug("workflownumber", $workflownumber);
	if ( $workflownumber == 1 ) {
		my $hassamples		=	$self->hasQueueSamples($queuedata);
		#$self->logDebug("hassamples", $hassamples);
		$self->populateQueueSamples($queuedata, $sampletable) if not $hassamples;
	}

	#### GET TASKS FROM queuesample TABLE
	my $tasks	=	$self->pullTasks($queues, $queuedata, $limit);
	$self->logDebug("tasks", $tasks);
	#$self->logDebug("no. tasks", scalar(@$tasks));
	return if not @$tasks;

	#### DIRECT THE TASK TO EXECUTE A WORKFLOW
	foreach my $task ( @$tasks ) {
		$task->{module}		=	"Agua::Workflow";
		$task->{mode}		=	"executeWorkflow";
		$task->{database}	=	$queuedata->{database} || $self->database() || $self->conf()->getKey("database:DATABASE", undef);
		
		$task->{workflow}	=	$queuedata->{workflow};
		$task->{workflownumber}=	$queuedata->{workflownumber};
		
		#### UPDATE TASK STATUS AS queued
		$task->{status}		=	"queued";
		
		#### SET TIME QUEUED
		$task->{time}		=	$self->getMysqlTime();

		#### SET SAMPLE HASH
		$task->{samplehash}	=	$self->getTaskSampleHash($task, $sampletable);
		#$self->logDebug("task", $task);
	}
	
	return $tasks;
}

method hasQueueSamples ($queuedata) {
	#$self->logDebug("queuedata", $queuedata);
	my $query	=	qq{SELECT 1 FROM queuesample
WHERE username='$queuedata->{username}'
AND project='$queuedata->{project}'
AND workflow='$queuedata->{workflow}'};
	#$self->logDebug("query", $query);
	
	return 1 if defined $self->db()->query($query);
	return 0;
}

method populateQueueSamples($queuedata, $sampletable) {

	$self->logDebug("queuedata", $queuedata);
	$self->logDebug("sampletable", $sampletable);

	my $query		=	qq{SELECT * FROM $sampletable};
	$self->logDebug("query", $query);
	my $samples		=	$self->db()->queryhasharray($query);
	$self->logDebug("no. samples", scalar(@$samples));
	my $fields		=	$self->db()->fields("queuesample");
	$self->logDebug("fields", $fields);

	my $tsvfile		=	"/tmp/queuesample.$sampletable.$$.tsv";
	$self->logDebug("tsvfile", $tsvfile);
	open(OUT, ">", $tsvfile) or die "Can't open tsv file: $tsvfile\n";
	foreach my $sample ( @$samples ) {
		$sample->{username}	=	$queuedata->{username};
		$sample->{project}	=	$queuedata->{project};
		$sample->{workflow}	=	$queuedata->{workflow};
		$sample->{workflownumber}	=	$queuedata->{workflownumber};
		$sample->{status}	=	"none";
		my $line	=	$self->db()->fieldsToTsv($fields, $sample);
		#$self->logDebug("line", $line);

		print OUT $line;
	}
	close(OUT) or die "Can't close tsv file: $tsvfile\n";

	$self->logDebug("loading 'queuesample' table");
	$self->db()->load("queuesample", $tsvfile, undef);
	
}

method getSampleTable ($queuedata) {
	my $username	=	$queuedata->{username};
	my $project		=	$queuedata->{project};
	my $query		=	qq{SELECT sampletable FROM sampletable
WHERE username='$username'
AND project='$project'};
	#$self->logDebug("query", $query);
	
	return $self->db()->query($query);
}

method getTaskSampleHash ($task, $sampletable) {
	my $username	=	$task->{username};
	my $project		=	$task->{project};
	my $sample		=	$task->{sample};
	my $query		=	qq{SELECT * FROM $sampletable
WHERE username='$username'
AND project='$project'
AND sample='$sample'};
	#$self->logDebug("query", $query);
	
	return $self->db()->queryhash($query);
}

method pullTasks ($queues, $queuedata, $limit) {
	
	#$self->logDebug("queues", $queues);
	$self->logDebug("queuedata", $queuedata);

	my $workflownumber	=	$queuedata->{workflownumber};
	my $previous	=	$self->getPrevious($queues, $queuedata);
	$self->logDebug("previous", $previous);

	#### VERIFY VALUES
	my $notdefined	=	$self->notDefined($queuedata, ["username", "project", "workflow"]);
	$self->logDebug("notdefined", $notdefined);
	$self->logCritical("not defined", @$notdefined) and return if scalar(@$notdefined) != 0;

	my $query		=	qq{SELECT * FROM queuesample
WHERE username='$previous->{username}'
AND project='$previous->{project}'
AND workflow='$previous->{workflow}'
AND workflownumber='$previous->{workflownumber}'
AND status='$previous->{status}'
LIMIT $limit};
	$self->logDebug("query", $query);
	
	return $self->db()->queryhasharray($query) || [];
}

method getPrevious ($queues, $queuedata) {
	#$self->logDebug("queues", $queues);
	#$self->logDebug("queuedata", $queuedata);

	my $workflownumber	=	$queuedata->{workflownumber};
	#$self->logDebug("workflownumber", $workflownumber);
	
	my $previous	=	{};
	if ( $workflownumber == 1 ) {
		$previous->{status}		=	"none";
		$previous->{username}	=	$queuedata->{username};
		$previous->{project}	=	$queuedata->{project};
		$previous->{workflow}	=	$queuedata->{workflow};
		$previous->{workflownumber}	=	$queuedata->{workflownumber};
	}
	else {
		my $previousindex		=	$workflownumber - 2;
		$self->logDebug("previousindex", $previousindex);
		my $previousdata		=	$$queues[$previousindex];
		$previous->{status}		=	"completed";
		$previous->{username}	=	$previousdata->{username};
		$previous->{project}	=	$previousdata->{project};
		$previous->{workflow}	=	$previousdata->{workflow};
		$previous->{workflownumber}	=	$previousdata->{workflownumber};
	}

	return $previous;	
}

#### TOPICS
method sendTopic ($data, $key) {

	$self->logDebug("data", $data);
	#$self->logDebug("key", $key);

	my $exchange	=	$self->conf()->getKey("queue:topicexchange", undef);
	#$self->logDebug("exchange", $exchange);

	my $host		=	$self->host() || $self->conf()->getKey("queue:host", undef);
	my $user		= 	$self->user() || $self->conf()->getKey("queue:user", undef);
	my $pass		=	$self->pass() || $self->conf()->getKey("queue:pass", undef);
	my $vhost		=	$self->vhost() || $self->conf()->getKey("queue:vhost", undef);
	$self->logNote("host", $host);
	$self->logNote("user", $user);
	$self->logNote("pass", $pass);
	$self->logNote("vhost", $vhost);
	
    my $connection = $self->newConnection();

	$self->logNote("connection: $connection");
	$self->logNote("DOING connection->open_channel");
	my $channel 	= 	$connection->channel_open();
	$self->channel($channel);

	$self->logNote("DOING channel->declare_exchange");

	$channel->declare_exchange(
		exchange => $exchange,
		type => 'topic',
	);
	
	my $json	=	$self->jsonparser()->encode($data);
	#$self->logDebug("json", $json);
	$self->channel()->publish(
		exchange => $exchange,
		routing_key => $key,
		body => $json,
	);
	
	print "[x] Sent topic with key '$key' mode '$data->{mode}'\n";

	$self->logDebug("closing connection");
	$connection->close();
}

method setQueueName ($task) {
	#### VERIFY VALUES
	my $notdefined	=	$self->notDefined($task, ["username", "project", "workflow"]);
	$self->logCritical("not defined", $notdefined) and return if @$notdefined;
	
	my $username	=	$task->{username};
	my $project		=	$task->{project};
	my $workflow	=	$task->{workflow};
	my $queue		=	"$username.$project.$workflow";
	#$self->logDebug("queue", $queue);
	
	return $queue;	
}

method notDefined ($hash, $fields) {
	return [] if not defined $hash or not defined $fields or not @$fields;
	
	my $notDefined = [];
    for ( my $i = 0; $i < @$fields; $i++ ) {
        push( @$notDefined, $$fields[$i]) if not defined $$hash{$$fields[$i]};
    }

    return $notDefined;
}

#### JOB STATUS
method updateJobStatus ($data) {
	#$self->logDebug("data", $data);
	$self->logDebug("$data->{sample} $data->{status}");

	my $keys	=	[ "username", "project", "workflow", "workflownumber", "sample" ];
	my $notdefined	=	$self->notDefined($data, $keys);	
	$self->logDebug("notdefined", $notdefined) and return if @$notdefined;

	#### ADD TO provenance TABLE
	my $table		=	"provenance";
	my $fields		=	$self->db()->fields($table);
	my $success		=	$self->_addToTable($table, $data, $keys, $fields);
	#$self->logDebug("addToTable 'provenance'    success", $success);
	$self->logDebug("failed to add to provenance table") if not $success;

	#### UPDATE queuesamples TABLE
	$success		=	$self->updateQueueSample($data);	
	$self->logDebug("failed to add to queuesample table") if not $success;
}

method updateQueueSample ($data) {
	#$self->logDebug("data", $data);	
	
	#### UPDATE queuesample TABLE
	my $table	=	"queuesample";
	my $keys	=	[ "sample" ];
	$self->_removeFromTable($table, $data, $keys);
	
	$keys	=	["username", "project", "workflow", "workflownumber", "sample", "status" ];

	return $self->_addToTable($table, $data, $keys);
}

#### HEARTBEAT
method updateHeartbeat ($data) {
	$self->logDebug("host $data->{host} [$data->{time}]");
	#$self->logDebug("data", $data);
	my $keys	=	[ "host", "time" ];
	my $notdefined	=	$self->notDefined($data, $keys);	
	$self->logDebug("notdefined", $notdefined) and return if @$notdefined;

	#### ADD TO TABLE
	my $table		=	"heartbeat";
	my $fields		=	$self->db()->fields($table);
	$self->_addToTable($table, $data, $keys, $fields);
}

method setConfigMaxJobs ($queuename, $value) {
	return $self->conf()->setKey("queue:maxjobs", $queuename, $value);
}

method getConfigMaxJobs ($queuename) {
	return $self->conf()->getKey("queue:maxjobs", $queuename);
}

method pushTask ($task) {
	#### STORE UNQUEUED TASK IN queue TABLE
	$self->logDebug("task", $task);
	
	#### VERIFY VALUES
	my $keys	=	["username", "project", "workflow", "workflownumber", "sample"];
	my $notdefined	=	$self->notDefined($task, $keys);
	$self->logCritical("not defined", @$notdefined) and return if @$notdefined;

	my $status	=	"unassigned";
	my $table	=	"queuesample";
	$self->_removeFromTable($table, $task, $keys);
	
	return $self->_addToTable($table, $task, $keys);
}

method allocateSamples ($queuedata, $limit) {
	$self->logDebug("queuedata", $queuedata);
	
	my $samples	=	$self->getSampleFromSynapse($limit);
	foreach my $sample ( @$samples ) {
		my $hash		=	$self->copyHash($queuedata);
		$hash->{sample}	=	$sample;
		return 0 if $self->pushTask($hash) == 0;
	}
	
	return 1;
}

method copyHash ($hash1) {
	my $hash2 = {};
	foreach my $key ( keys %$hash1 ) {
		$hash2->{$key}	=	$hash1->{$key};
	}
	
	return $hash2;
}

method maxJobsForQueue ($queuedata) {
	my $queuename	=	$self->setQueueName($queuedata);
	#$self->logDebug("queuename", $queuename);
	my $maxjobs		=	$self->getConfigMaxJobs($queuename);
	$self->logDebug("FROM CONFIG maxjobs", $maxjobs);
	
	if ( not defined $maxjobs ) {
		$maxjobs	=	$self->maxjobs(); #### EITHER DEFAULT OR USER-DEFINED
		
		$self->setConfigMaxJobs($queuename, $maxjobs);
	}
	$self->logDebug("maxjobs", $maxjobs);
	
	return $maxjobs;
}

method getQueueTasks {	
	my $list		=	$self->getQueueTaskList();
	$list		=~	s/Listing queues ...(), "\s*\n//;
	$list		=~	s/(), "\n...done.\s*//;
	my $tasks	=	{};
	foreach my $entry ( split "\n", $list ) {
		#$self->logDebug("entry", $entry);
		my ($queue, $taskcount)	=	$entry	=~	/^(\S+)\s+(\d+)/;
		$tasks->{$queue}	=	$taskcount if defined $queue and defined $taskcount;
	}	
	#$self->logDebug("tasks", $tasks);

	return $tasks;
}

method getQueueTaskList {
	
	my $vhost		=	$self->conf()->getKey("queue:vhost", undef);
	#$self->logDebug("vhost", $vho st);
	
	my $rabbitmqctl	=	$self->rabbitmqctl();
	#$self->logDebug("rabbitmqctl", $rabbitmqctl);
	
	my $command		=	qq{$rabbitmqctl list_queues -p $vhost name messages};
	#$self->logDebug("command", $command);

	my $queuelist	=	`$command`;
	#$self->logDebug("queuelist", $queuelist);

	return $queuelist;
}


method getQueuedJobs ($workflowdata) {
	my $query	=	qq{SELECT * FROM queuesample
WHERE username='$workflowdata->{username}'
AND project='$workflowdata->{project}'
AND workflow='$workflowdata->{workflow}'
AND status='queued'};
	#$self->logDebug("query", $query);
	
	return $self->db()->queryhasharray($query) || [];
}

#### SEND TASK
method setModules {
    my $installdir = $self->conf()->getKey("agua", "INSTALLDIR");
    my $modulestring = $self->modulestring();
	$self->logDebug("modulestring", $modulestring);

	my $modules = {};
    my @modulenames = split ",", $modulestring;
    foreach my $modulename ( @modulenames) {
        my $modulepath = $modulename;
        $modulepath =~ s/::/(), "\//g;
        my $location    = "$installdir/lib/$modulepath.pm";
        #print "location: $location\n";
        my $class       = "$modulename";
        eval("use $class");
    
        my $object = $class->new({
            conf        =>  $self->conf(),
            log     =>  $self->log(),
            printlog    =>  $self->printlog()
        });
        print "object: $object\n";
        
        $modules->{$modulename} = $object;
    }

    return $modules; 
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

method sleeping ($nodename) {	
	my $entries	=	$self->virtual()->getEntries($nodename);
	foreach my $entry ( @$entries ) {
		my $internalip	=	$entry->{internalip};
		$self->logDebug("internalip", $internalip);
		my $status	=	$self->workflowStatus($internalip);	

		if ( $status =~ /Done, sleep/ ) {
			my $id	=	$entry->{id};
			$self->logDebug("DOING novaDelete($id)");
			$self->virtual()->novaDelete($id);
		}
	}
}

method status ($nodename) {	
	my $entries	=	$self->virtual()->getEntries($nodename);
	foreach my $entry ( @$entries ) {
		my $internalip	=	$entry->{internalip};
		$self->logDebug("internalip", $internalip);
		my $status	=	$self->workflowStatus($internalip);	
		my $percent	=	$self->downloadPercent($status);
		$self->logDebug("percent", $percent);
		next if not defined $percent;
		
		if ( $percent < 90 ) {
			my $uuid	=	$self->getDownloadUuid($internalip);
			$self->logDebug("uuid", $uuid);
			
			$self->resetStatus($uuid, "todownload");

			my $id	=	$entry->{id};
			$self->logDebug("id", $id);
			
			$self->logDebug("DOING novaDelete($id)");
			$self->virtual()->novaDelete($id);
		}
	}
}

method getDownloadUuid ($ip) {
	$self->logDebug("ip", $ip);
	my $command =	qq{ssh -o "StrictHostKeyChecking no" -t ubuntu(), "\@", $self->ip "ps aux | grep /usr/bin/gtdownload"};
	$self->logDebug("command", $command);
	
	my $output	=	`$command`;
	#$self->logDebug("output", $output);

	my @lines	=	split $output;
	#$self->logDebug("lines", (), "\@lines);
	
	my $uuid	=	$self->parseUuid(\@lines);
	
	return $uuid;
}
method workflowStatus ($ip) {
	$self->logDebug("ip", $ip);
	my $command =	qq{ssh -o "StrictHostKeyChecking no" -t ubuntu(), "\@", $self->ip "tail -n1 ~/worker.log"};
	$self->logDebug("command", $command);
	
	my $status	=	`$command`;
	#$self->logDebug("status", $status);
	
	return $status;
}

method downloadPercent ($status) {
	#$self->logDebug("status", $status);
	my ($percent)	=	$status	=~ /(), "\(([\d\.]+)\% complete\)/;
	$self->logDebug("percent", $percent);
	
	return $percent;
}

method parseUuid ($lines) {
	$self->logDebug("lines length", scalar(@$lines));
	for ( my $i = 0; $i < @$lines; $i++ ) {
		#$self->logDebug("lines[$i]", $$lines[$i]);
		
		if ( $$lines[$i] =~ /(), "\-d ([a-z0-9\-]+)/ ) {
			return $1;
		}
	}

	return;
}

method stopWorkflow ($ips, $workflow) {
	$self->logDebug("ips", $ips);
	$self->logDebug("workflow", $workflow);
	
	foreach my $ip ( @$ips ) {
		my $data	=	{};
		$data->{module}	=	"Agua::Workflow";
		$data->{mode}	=	"stopWorkflow";
		
	}
}

method getWorkflows ($node) {
#### GET CURRENT WORKFLOW STATES (COMPLETED, EXITED)
	
}

method runCommand ($command) {
	$self->logDebug("command", $command);
	
	return `$command`;
}

method startWorkflow {
	#### OVERRIDE	
}

method setSynapse {
	$self->logDebug("");

	my $synapse	= Synapse->new({
		conf		=>	$self->conf(),
		log     =>  $self->log(),
		printlog    =>  $self->printlog(),
		logfile     =>  $self->logfile()
	});

	$self->synapse($synapse);
}

method pushWorkflow {
	#### ADD A WORKFLOW RECORD TO A REMOTE HOST	
	
}

method pullWorkflow {
	#### GET A WORKFLOW RECORD FROM A REMOTE HOST
	#### INCLUDES ALL FIELDS 
	
	
}

method pullProvenance {
	#### INCLUDES
	#	-	PACKAGES (SOFTWARE AND DATA - URLs, DOIs, ETC.)
	#	-	APPLICATION
	#	-	PARAMETERS
	#	-	RUNTIME
	#	-	STDOUT AND STDERR (FIRST 1000 LINES EACH, STORED IN A GLOB)
	
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
	#$self->logDebug("virtual: $virtual");

	$self->virtual($virtual);
}


method deeplyIdentical ($a, $b) {
    if (not defined $a)        { return not defined $b }
    elsif (not defined $b)     { return 0 }
    elsif (not ref $a)         { $a eq $b }
    elsif ($a eq $b)           { return 1 }
    elsif (ref $a ne ref $b)   { return 0 }
    elsif (ref $a eq 'SCALAR') { $$a eq $$b }
    elsif (ref $a eq 'ARRAY')  {
        if (@$a == @$b) {
            for (0..$#$a) {
                my $rval;
                return $rval unless ($rval = $self->deeplyIdentical($a->[$_], $b->[$_]));
            }
            return 1;
        }
        else { return 0 }
    }
    elsif (ref $a eq 'HASH')   {
        if (keys %$a == keys %$b) {
            for (keys %$a) {
                my $rval;
                return $rval unless ($rval = $self->deeplyIdentical($a->{$_}, $b->{$_}));
            }
            return 1;
        }
        else { return 0 }
    }
    elsif (ref $a eq ref $b)   { warn 'Cannot test '.(ref $a)."\n"; undef }
    else                       { return 0 }
}
	
	
	

}

#method getTenants {
#	my $query	=	qq{SELECT *
#FROM tenant};
#	#$self->logDebug("query", $query);
#
#	return $self->db()->queryhasharray($query);
#}
#

#method getSynapseStatus ($data) {
#	#### UPDATE SYNAPSE
#	my $sample	=	$data->{sample};
#	my $stage	=	lc($data->{workflow});
#	my $status	=	$data->{status};
#	$status		=~	s/^error.+$/error/;
#
#	$self->logDebug("sample", $sample);
#	$self->logDebug("stage", $stage);
#	$self->logDebug("status", $status);
#
#	my $statemap		=	$self->synapse()->statemap();
#	my $synapsestatus	=	$statemap->{"$stage:$status"};
#	$self->logDebug("synapsestatus", $synapsestatus);
#
#	return $synapsestatus;	
#}
#
#method getSampleFromSynapse ($maxjobs) {
#	my $samples	=	$self->synapse()->getBamForWork($maxjobs);
#	$self->logDebug("samples", $samples);
#	
#	return $samples;
#}
#
