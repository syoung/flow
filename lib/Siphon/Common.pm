package Siphon::Common;
use Moose::Role;
use Method::Signatures::Simple;

=head2

PURPOSE

	Run tasks on worker nodes using task queue

	Use queues to communicate between master and nodes:
	
		WORKERS: REPORT STATUS TO MASTER
	
		MASTER: DIRECT WORKERS TO:
		
			- DEPLOY APPS
			
			- PROVIDE WORKFLOW STATUS
			
			- STOP/START WORKFLOWS

=cut

use strict;
use warnings;

#### EXTERNAL MODULES
use FindBin qw($Bin);
use Test::More;
use POSIX qw(ceil floor);

#### INTERNAL MODULES
use Time::Local;
# use Virtual;

method pause {
	my $sleep	=	$self->sleep();
	print "Queue::Balancer::pause    Sleeping $sleep seconds\n";
	sleep($sleep);
}

method getProjectsByUsername ($username) {
	return if not defined $username;
	return $self->table()->db()->queryarray("SELECT * FROM project WHERE username='$username'");
}
#### BALANCE INSTANCES
method balanceOpenstackInstances ($workflows) {
	print "\n\n#### DOING balanceInstances\n";
	$self->logDebug("workflows", $workflows);

	my $stopping	=	$self->stoppingInstances();
	$self->logDebug("stopping", $stopping);
	return if $stopping;
	
	my $username	=	$$workflows[0]->{username};
	#$self->logDebug("username", $username);

	# 1. CALCULATE AVERAGE DURATION OF completed SAMPLES IN EACH WORKFLOW/QUEUE
	my $durations	=	$self->getDurations($workflows);
	$self->logDebug("durations", $durations);
	
	#### NARROW DOWN TO ONLY QUEUES WITH CLUSTERS
	$workflows	=	$self->clusterWorkflows($workflows);	
	$self->logDebug("cluster only workflows", $workflows);

	# 2. GET CURRENT COUNTS OF RUNNING INSTANCES PER QUEUE
	my $currentcounts	=	$self->getCurrentCounts($username);
	$self->logDebug("currentcounts", $currentcounts);

	#### GET REQUIRED RESOURCES FOR QUEUE INSTANCES (CPUs, RAM, ETC.)
	my $instancetypes	=	$self->getInstanceTypes($workflows);
	$self->logDebug("instancetypes", $instancetypes);

	# 3. IF LATEST RUNNING WORKFLOW HAS NO COMPLETED JOBS, SET
	#	INSTANCE COUNT FOR NEXT WORKFLOW TO cluster->minnodes
	my $latestcompleted =	$self->getLatestCompleted($workflows);
	$self->logDebug("latestcompleted", $latestcompleted);

	# 4. GET TOTAL QUOTA FOR RESOURCE (DEFAULT: NO. CPUS)
	my $metric	=	$self->metric();	
	my $quota	=	$self->getResourceQuota($username, $metric);
	$self->logDebug("quota", $quota);

#### DEBUG

$quota		=	2;
$self->logDebug("DEBUG quota", $quota);

#### DEBUG


	my $resourcecounts	=	[];
	my $instancecounts	=	[];
	#### SET DEFAULT INSTANCE COUNTS FOR FIRST WORKFLOW IF:
	#### 1. PROJECT WORKFLOWS HAVE JUST STARTED RUNNING, OR
	#### 2. SAMPLES HAVE JUST BEEN LOADED
	#### 
	if ( not defined $latestcompleted or not %$durations ) {
		print "#### DOING getDefaultResource\n";
		my $resourcecount	=	$self->getDefaultResource($$workflows[0], $instancetypes, $quota);
		$self->logDebug("resourcecount", $resourcecount);

		my $metric	=	$self->metric();

		my $queuename	=	$self->getQueueName($$workflows[0]);
		my $resource	=	$instancetypes->{$queuename}->{$metric};
		my $instancecount	=	ceil($resourcecount/$resource);
		$instancecount		=	0 if $instancecount < 1;
		$self->logDebug("instancecount", $instancecount);
		
		$resourcecounts	=	[ $resourcecount ];
		$instancecounts	=	[ $instancecount ];
	}
	else {
		print "#### DOING getResourceCounts\n";
		##### GET CURRENT COUNT OF VMS PER QUEUE (queueample STATUS 'started')
		##### ASSUMES ONE VM PER TASK
		#my $currentcounts=	$self->getCurrentCounts();
		#$self->logDebug("currentcounts", $currentcounts);
		
		# 2. BALANCE COUNTS BASED ON DURATION
		#
		$resourcecounts	=	$self->getResourceCounts($workflows, $durations, $instancetypes, $quota);
		$instancecounts	=	$self->getInstanceCounts($workflows, $instancetypes, $resourcecounts);
		#$self->logDebug("instancecounts", $instancecounts);

		#### IF NOT ALL WORKFLOWS HAVE RUNNING INSTANCES,
		#### SET DEFAULT INSTANCE COUNTS FOR 2ND TO LAST RUNNING WORKFLOW 
		#### IF IT HAS NO COMPLETED JOBS TO PROVIDE DURATION INFO
		my $lateststarted	=	$self->getLatestStarted($workflows);
		$self->logDebug("lateststarted", $lateststarted);
		$lateststarted		=	$latestcompleted if not defined $lateststarted;
	
		if ( $lateststarted != $latestcompleted ) {
			$instancecounts	=	$self->adjustCounts($workflows, $resourcecounts, $lateststarted, $quota);
		}
	}
	$self->logDebug("resourcecounts", $resourcecounts);
	$self->logDebug("instancecounts", $instancecounts);

	$self->addRemoveNodes($workflows, $instancecounts, $currentcounts);

	#   TAILOUT AT END OF SAMPLE RUN:
	#   NB: maxJobs <= NUMBER OF REMAINING SAMPLES FOR THE WORKFLOW
}

method stoppingInstances {
	my $query	=	qq{SELECT * FROM instance
WHERE status='stopping'
};
	my $stopping	=	$self->table()->db()->queryhasharray($query);
	$self->logDebug("stopping", $stopping);
	
	if ( defined $stopping ) {
		print "Stopping instances:\n" ;
		foreach my $stopinstance ( @$stopping ) {
			print "$stopinstance->{queue}: $stopinstance->{host}\n";
		}
	}

	return 1 if defined $stopping and @$stopping;
	return 0;
}

#### ADD NODES
method addRemoveNodes ($workflows, $instancecounts, $currentcounts) {
	#$self->logDebug("workflows", $workflows);
	$self->logDebug("currentcounts", $currentcounts);
	$self->logDebug("instancecounts", $instancecounts);

	for ( my $i = 0; $i < @$instancecounts; $i++ ) {
		my $instancecount =	$$instancecounts[$i];
		$self->logDebug("instancecount [$i]", $instancecount);

		my $queuename	=	$self->getQueueName($$workflows[$i]);
		$self->logDebug("queuename [$i]", $queuename);
		
		my $currentcount =	$currentcounts->{$queuename} || 0;
		$self->logDebug("currentcount [$i]", $currentcount);
		
		my $difference	=	$instancecount - $currentcount;
		$self->logDebug("difference	= $instancecount - $currentcount");
		$self->logDebug("difference [$i]", $difference);
		
		if ( $difference > 0 ) {
			$self->addNodes($$workflows[$i], $difference);
		}
		elsif ( $difference < 0 ) {
			$self->deleteNodes($$workflows[$i], abs($difference));
		}
	}	
}
method addNodes ($workflow, $maxnodes) {
	$self->logDebug("workflow", $workflow);
	$self->logDebug("maxnodes", $maxnodes);

	my $username	=	$workflow->{username};
	my $project		=	$workflow->{project};
	my $name		=	$workflow->{workflow};

	#	1. GET amiid, instancetype FOR cluster = username.project.workflow
	my $clusterobject	=	$self->getQueueCluster($workflow);
	my $amiid			=	$clusterobject->{amiid};
	my $instancetype	=	$clusterobject->{instancetype};
	$self->logDebug("amiid", $amiid);
	$self->logDebug("instancetype", $instancetype);

	my $workobject	=	$self->getWorkObject($workflow);
	$self->logDebug("workobject", $workobject);
	
	for ( my $i = 0; $i < $maxnodes; $i++ ) {

		my $hostname	=	$self->randomHostname($name);
		$self->logDebug("hostname", $hostname);
	
		my $id	=	$self->virtual()->launchNode($workobject, $amiid, $maxnodes, $instancetype, $hostname);
		$self->logDebug("id", $id);
		$self->logError("failed to add node") and return 0 if not defined $id;

		my $success	=	0;
		$success	=	1 if $id =~ /^[0-9a-z\-]+$/;
		$self->logDebug("failed to add node") and return 0 if not $success;
		
		$self->addHostInstance($workflow, $hostname, $id);
	}
	
	return 1;
}

method getWorkObject ($workflow) {
	$self->logDebug("workflow", $workflow);

	#### ADD package AND version TO WORKFLOW OBJECT
	my $stages			=	$self->getStagesByWorkflow($workflow);
	my $object			=	$$stages[0];
	my $package			=	$object->{package};
	my $version			=	$object->{version};
	$self->logDebug("package", $package);
	$self->logDebug("version", $version);

	return $object;
}

method addHostInstance ($workflow, $hostname, $id) {
	#$self->logDebug("workflow", $workflow);
	#$self->logDebug("hostname", $hostname);
	#$self->logDebug("id", $id);
	
	my $time			=	$self->getMysqlTime();

	my $data	=	{};
	$data->{username}	=	$workflow->{username};
	$data->{queue}		=	$self->getQueueName($workflow);
	$data->{host}		=	$hostname;
	$data->{id}			=	$id;
	$data->{status}		=	"running";
	$data->{time}		=	$time;
	$self->logDebug("data", $data);
	
	my $keys	=	[ "username", "queue", "host" ];
	my $notdefined	=	$self->notDefined($data, $keys);	
	$self->logDebug("notdefined", $notdefined) and return if @$notdefined;

	#### ADD TO TABLE
	my $table		=	"instance";
	my $fields		=	$self->table()->db()->fields($table);
	$self->_addToTable($table, $data, $keys, $fields);
}

method getInstallDir ($packagename) {
	$self->logDebug("packagename", $packagename);

	my $packages = $self->conf()->getKey("packages:$packagename", undef);
	$self->logDebug("packages", $packages);
	my $version	=	undef;
	foreach my $key ( %$packages ) {
		$version	=	$key;
		last;
	}

	my $installdir	=	$packages->{$version}->{INSTALLDIR};
	$self->logDebug("installdir", $installdir);
	
	return $installdir;
}

method randomHostname ($name) {
	
	my $length	=	10;
	my $random	=	$self->randomHexadecimal($length);	
	my $randomname	=	$name . "-" . $random;
	#$self->logDebug("randomname", $randomname);
	while ( $self->hostExists($randomname) ) {
		$random	=	$self->randomHexadecimal($length);	
		$randomname	=	$name . "-" . $random;
	}

	return $randomname;	
}

method hostExists ($host) {
	my $query	=	qq{SELECT 1 FROM heartbeat
WHERE host='$host'};
	#$self->logDebug("query", $query);
	
	my $success	=	$self->table()->db()->query($query);
	#$self->logDebug("success", $success);
	
	return 0 if not defined $success;
	return 1;
}

method randomHexadecimal ($length) {
	#$self->logDebug("length", $length);
	
	my $random	=	"";
	for ( 0 .. $length ) {
		$random .= sprintf "%01X", rand(0xf);
	}
	$random	=	lc($random);
	#$self->logDebug("random", $random);
	
	return $random;
}

method updateInstanceStatus ($id, $status) {
	$self->logNote("id", $id);
	$self->logNote("status", $status);
	
	my $time		=	$self->getMysqlTime();
	my $query		=	qq{UPDATE instance
SET status='$status',
TIME='$time'
WHERE id='$id'
};
	return $self->table()->db()->do($query);
}

#### DELETE NODES
method deleteNodes ($workflow, $number) {
	my $queuename	=	$self->getQueueName($workflow);
	my $username	=	$workflow->{username};
	my $query	=	qq{SELECT * FROM instance
WHERE username='$username'
AND queue='$queuename'
AND status='running'
LIMIT $number};
	#$self->logDebug("query", $query);
	
	my $instances	=	$self->table()->db()->queryhasharray($query);
	foreach my $instance ( @$instances ) {
		$self->updateInstanceStatus($instance->{id}, "stopping");
		$self->shutdownInstance($workflow, $instance->{host});
	}
}
method shutdownInstance ($workflow, $id) {
	#$self->logDebug("id", $id);

	my $stages			=	$self->getStagesByWorkflow($workflow);
	my $object			=	$$stages[0];
	my $package			=	$object->{package};
	my $installdir		=	$self->getInstallDir($package);
	my $version			=	$object->{version};
	my $teardownfile	=	$self->setTearDownFile($installdir, $version);
	#$self->logDebug("teardownfile", $teardownfile);
	my $teardown			=	$self->getFileContents($teardownfile);
	#$self->logDebug("teardown", substr($teardown, 0, 100));
	
	my $data	=	{
		host			=>	$id,
		mode			=>	"doShutdown",
		teardown		=>	$teardown,
		teardownfile	=>	$teardownfile
	};
	
	my $key	=	"update.host.status";
	$self->sendTopic($data, $key);
}

method setTearDownFile($installdir, $version) {
	return "$installdir/data/sh/teardown.sh";
}

#### RESOURCES
method getDefaultResource ($queue, $instancetypes, $quota) {
	$self->logDebug("queue", $queue);

	#### SET FIRST NODES TO MAX NO SAMPLES COMPLETED
	my $queuename		=	$self->getQueueName($queue);
	my $instancetype		=	$instancetypes->{$queuename};
	my $metric			=	$self->metric();
	my $resource	=	$instancetype->{$metric};
	$self->logDebug("queuename", $queuename);
	$self->logDebug("resource", $resource);
	$self->logDebug("instancetype", $instancetype);

	#### SET RESOURCE QUOTA
	my $resourcequota	=	$quota;
	$self->logDebug("resourcequota", $resourcequota);

	my $cluster	=	$self->getQueueCluster($queue);
	$self->logDebug("cluster", $cluster);
	my $maxnodes		=	$cluster->{maxnodes};
	$self->logDebug("maxnodes", $maxnodes);
	
	my $resourcecount 	=	$resource * $maxnodes;
	$self->logDebug("resourcecount", $resourcecount);

	my $username		=	$queue->{username};
	
	if ( $resourcecount > $resourcequota ) {
		$self->logDebug("resourcecount $resourcecount > resourcequota $resourcequota. Setting to resourcequota ($resourcequota)");
		$resourcecount = $resourcequota;
	}
	$self->logDebug("resourcecount", $resourcecount);
	
	return $resourcecount;
}

method clusterWorkflows ($workflows) {
	#$self->logDebug("workflows", $workflows);

	my $clusterworkflows	=	[];
	for ( my $i = 0; $i < @$workflows; $i++ ) {
		#$self->logDebug("workflows[$i]", $$workflows[$i]);

		my $cluster	=	$self->getQueueCluster($$workflows[$i]);
		#$self->logDebug("cluster", $cluster);
		if ( defined $cluster ) {
			push @$clusterworkflows, $$workflows[$i];			
		}
	}
	##$self->logDebug("CLUSTER ONLY clusterworkflows", $clusterworkflows);
	#if ( defined $clusterworkflows ) {
	#	print "cluster workflows:\n";
	#	foreach my $clusterworkflow ( @$clusterworkflows ) {
	#		print "$clusterworkflow->{name}\n";
	#	}
	#}

	return $clusterworkflows;
}

method adjustCounts ($queues, $resourcecounts, $lateststarted, $quota) {

#### SET DEFAULT INSTANCE COUNTS FOR NEXT WORKFLOW IF IT HAS NO
#### COMPLETED JOBS TO PROVIDE DURATION INFO

	$self->logDebug("resourcecounts", $resourcecounts);
	my $nextqueue	=	$$queues[$lateststarted];
	$self->logDebug("nextqueue", $nextqueue);
	my $nextqueuename	=	$self->getQueueName($nextqueue);
	$self->logDebug("nextqueuename", $nextqueuename);
	
	my $cluster	=	$self->getQueueCluster($nextqueue);
	$self->logDebug("cluster", $cluster);
	my $min			=	$cluster->{minnodes};
	$self->logDebug("min", $min);

	my $instancetypes	=	$self->getInstanceTypes($queues);
	my $instancetype	=	$instancetypes->{$nextqueuename};
	$self->logDebug("instancetype", $instancetype);
	my $metric		=	$self->metric();
	my $resource	=	$instancetype->{$metric};
	
	my $total	=	0;
	foreach my $resourcecount ( @$resourcecounts ) {
		$total	+=	$resourcecount;
	}
	$self->logDebug("total", $total);
	
	#### IF 
	if ( $total == 0 ) {
		$$resourcecounts[$lateststarted] = $quota;
	}
	else {
		my $latestcount	=	($min * $resource);
		my $newtotal	=	$total - $latestcount;
		$self->logDebug("newtotal", $newtotal);
		
		if ( $newtotal == $total ) {
			$$resourcecounts[$lateststarted] = $quota;
		}
		else {
			foreach my $resourcecount ( @$resourcecounts ) {
				last if $resourcecount == 0;
				$resourcecount	=	$resourcecount * ($newtotal/$total);
			}
			$$resourcecounts[$lateststarted] = $latestcount;
		}		
	}
	$self->logDebug("FINAL resourcecounts", $resourcecounts);
	
	$self->logDebug("RETURNING RERUN OF self->getInstanceCounts");
	return $self->getInstanceCounts($queues, $instancetypes, $resourcecounts);
}

method getResourceCounts ($queues, $durations, $instancetypes, $quota) {

=head2	SUBROUTINE	getResourceCounts

=head2	PURPOSE
	
	Allocate resources (e.g., CPUs) to each workflow

=head2	ALGORITHM

	At max throughput:
	[1] T = t1 = t2 = t3
	Where T = total throughput, tx = throughput for workflow x

	Given N is a finite resource (e.g., number of VMs)
	[2] N = n1 + n2 + n3 + ... + nX
	Where X = total no. of workflows, nx = no. of VMs for workflow x

	Define:
	[3] tx = dx/nx
	Where tx = throughput for workflow x, dx = duration of workflow x, nx = number of resources used in workflow x (e.g., VMs)

	STEPS:

		1. Solve for n1 using [1], [2] and [3]
		n1 = N/(1 + d2/d1 + d3/d1 + ... + dx/d1)

		2. Calculate n2, n3, etc. using [1] and [3] (d1/n1 = d2/n2)
		n2 = (n1 . d2) / d1

=cut
	
	#$self->logDebug("username", $username);
	#$self->logDebug("queues", $queues);
	#$self->logDebug("durations", $durations);
	#$self->logDebug("instancetypes", $instancetypes);
	
	#### GET INDEX OF LATEST RUNNING WORKFLOW
	my $lateststarted 	=	$self->getLatestStarted($queues);
	$self->logDebug("lateststarted", $lateststarted);
	$lateststarted		=	$self->getLatestCompleted($queues) if not defined $lateststarted;

	#### GET FIRST DURATION
	my $firstqueue		=	$self->getQueueName($$queues[0]);
	my $metric	=	$self->metric();
	my $instancetype	=	$instancetypes->{$firstqueue};
	my $firstresource	=	$instancetype->{$metric};
	my $firstduration	=	$durations->{$firstqueue} * $firstresource;
	$self->logDebug("firstqueue", $firstqueue);
	$self->logDebug("firstresource", $firstresource);
	$self->logDebug("firstduration", $firstduration);
	
	####	1. Solve for n1 using [1], [2] and [3]
	####	n1 = N/(1 + d2/d1 + d3/d1 + ... + dx/d1)
	my $terms	=	$self->solveForTerms($queues, $durations, $instancetypes, $lateststarted);
	$self->logDebug("terms", $terms);
	
	my $firstcount		=	$quota / $terms;
	$self->logDebug("firstcount", $firstcount);

	my $firstthroughput	=	($firstduration/3600) * $firstcount;
	$self->logDebug("firstthroughput", $firstthroughput);

	my $queuenames		=	$self->getQueueNames($queues);
	#$self->logDebug("queuenames", $queuenames);

	my $completedworkflows	=	$self->getCompletedWorkflows($queues);	
	$self->logDebug("completedworkflows", $completedworkflows);

	my $resourcecounts	=	[];
	for ( my $i = 0; $i < $lateststarted + 1; $i++ ) {
		my $queuename	=	$$queuenames[$i];
		$self->logDebug("queuename [$i]", $queuename);
		$self->logDebug("completedworkflows [$i]", $$completedworkflows[$i]);

		push @$resourcecounts, 0 and next if $$completedworkflows[$i];
		
		my $duration	=	$durations->{$queuename};
		$self->logDebug("duration", $duration);
		push @$resourcecounts, 0 and last if not defined $duration;
		
		my $instancetype	=	$instancetypes->{$queuename};
		$self->logDebug("instancetype", $instancetype);
		my $resource	=	$instancetype->{$metric};
		$self->logDebug("resource ($metric)", $resource);

		my $adjustedduration	=	$duration * $resource;
		$self->logDebug("adjustedduration", $adjustedduration);
		
		my $resourcecount	=	($firstcount * $adjustedduration) / $firstduration;
		$self->logDebug("resourcecount", $resourcecount);

		my $throughput	=	(3600/$adjustedduration) * $resourcecount;
		$self->logDebug("throughput", $throughput);

		push @$resourcecounts, $resourcecount;
	}
	$self->logDebug("resourcecounts", $resourcecounts);

	##### VERIFY TOTAL
	#my $total = 0;
	#for ( my $i = 0; $i < @$resourcecounts; $i++ ) {
	#	my $resourcecount 	=	$$resourcecounts[$i];
	#
	#	my $queuename	=	$$queuenames[$i];
	#	$self->logDebug("queuename", $queuename);
	#
	#	my $duration	=	$durations->{$queuename};
	#	$self->logDebug("duration", $duration);
	#
	#	$self->logDebug("count = $resourcecount / $duration");
	#	my $count	=	$resourcecount / $duration;
	#	$self->logDebug("count", $count);
	#	
	#	$total 	+=	$resourcecount;
	#}
	#$self->logDebug("total", $total);
	
	return $resourcecounts;
}

method getCompletedWorkflows ($queues) {
	#$self->logDebug("queues", $queues);
	
	my $completed	=	[];
	my $complete	=	1;
	foreach my $queue ( @$queues ) {
		#$self->logDebug("queue", $queue);
		if ( $self->hasNonCompletedSamples($queue) ) {
			$complete = 0;
		}
		push @$completed, $complete;
	}
	#$self->logDebug("completed", $completed);
	
	return $completed;	
}

method hasNonCompletedSamples ($queue) {
	#$self->logDebug("queue", $queue);
	
	my $query	=	qq{SELECT 1 FROM queuesample
WHERE username='$queue->{username}'
AND project='$queue->{project}'
AND workflow='$queue->{workflow}'
AND workflownumber=$queue->{workflownumber}
AND status!='completed'
ORDER BY sample};
	#$self->logDebug("query", $query);
	my $has	=	$self->table()->db()->query($query);
	#$self->logDebug("has", $has);

	return 1 if defined $has;
	return 0;
}

method solveForTerms ($queues, $durations, $instancetypes, $latestcompleted) {
	#$self->logDebug("queues", $queues);
	#$self->logDebug("durations", $durations);
	#$self->logDebug("instancetypes", $instancetypes);

	#### GET FIRST DURATION
	my $firstqueue		=	$self->getQueueName($$queues[0]);
	my $instancetype	=	$instancetypes->{$firstqueue};
	my $metric			=	$self->metric();
	my $firstresource	=	$instancetype->{$metric};
	my $firstduration	=	$durations->{$firstqueue} * $firstresource;
	$self->logDebug("firstqueue", $firstqueue);
	#$self->logDebug("instancetype", $instancetype);
	$self->logDebug("firstresource", $firstresource);
	$self->logDebug("firstduration", $firstduration);

	my $terms	=	1;
	for ( my $i = 1; $i < $latestcompleted + 1; $i++ ) {
		my $queue	=	$$queues[$i];
		#$self->logDebug("queue $i", $queue);
		my $queuename	=	$self->getQueueName($queue);
		$self->logDebug("queuename", $queuename);

		my $duration	=	$durations->{$queuename};
		$self->logDebug("duration", $duration);
		last if not defined $duration or $duration == 0;
		
		my $instancetype	=	$instancetypes->{$queuename};
		$self->logDebug("instancetype", $instancetype);
		my $resource	=	$instancetype->{$metric};
		$self->logDebug("resource ($metric)", $resource);

		my $adjustedduration	=	$duration * $resource;
		
		my $term	=	$adjustedduration/$firstduration;
		$self->logDebug("term", $term);
		
		$terms		+=	$term;
	}
	$self->logDebug("FINAL terms", $terms);
	
	return $terms;	
}
method getInstanceCounts ($queues, $instancetypes, $resourcecounts) {

=head2	SUBROUTINE	getInstanceCounts

=head2	PURPOSE
	
	Given the CPU allocations (resourceallocations), allocate instances to each workflow

=head2	ALGORITHM


=cut

	my $metric	=	$self->metric();
	$self->logDebug("metric", $metric);

	my $instancecounts	=	[];
	my $resourcetotal	=	0;
	my $integertotal	=	0;
	for ( my $i = 0; $i < @$resourcecounts; $i++ ) {
		my $queuename	=	$self->getQueueName($$queues[$i]);
		my $resource	=	$instancetypes->{$queuename}->{$metric};
		my $resourcecount 	=	$$resourcecounts[$i] / $resource;
		$self->logDebug("$queuename instance $resource CPUs resourcecount", $resourcecount);
		
		push @$instancecounts, 0 and next if not defined $$resourcecounts[$i];
		
		#### STASH RUNNING COUNT
		$resourcetotal		+=	$$resourcecounts[$i];

		$self->logDebug("");
		if ( $i == scalar(@$resourcecounts) - 1) {
			$self->logDebug("pushing to instancecounts int( ($resourcetotal - $integertotal) / $resource )", int( ($resourcetotal - $integertotal) / $resource ));

			my $instancecount	=	int( ($resourcetotal - $integertotal) / $resource );
			$self->logDebug("instancecount", $instancecount);
			if ( $instancecount <= 0 ) {
				$instancecount		=	0;
			}
			elsif ( $instancecount < 1 ) {
				$instancecount		=	1 ;
			}

			push @$instancecounts, $instancecount;
		}
		else {
			my $instancecount	=	floor($$resourcecounts[$i]/$resource);
			$self->logDebug("pushing to instancecounts floor($$resourcecounts[$i]/$resource)", $instancecount);
			$self->logDebug("instancecount", $instancecount);
			if ( $instancecount <= 0 ) {
				$instancecount		=	0;
			}
			elsif ( $instancecount < 1 ) {
				$instancecount		=	1 ;
			}

			#### STASH RUNNING INTEGER COUNT
			$integertotal	+=	$instancecount * $resource;

			push @$instancecounts, $instancecount;
		}
	}
	$self->logDebug("integertotal", $integertotal);
	$self->logDebug("instancecounts", $instancecounts);

	return $instancecounts;
}

method getQueueNames ($queues) {
	#$self->logDebug("queues", $queues);
	
	my $queuenames	=	[];
	for ( my $i = 0; $i < @$queues; $i++ ) {
		my $queue	=	$$queues[$i];
		#$self->logDebug("queue $i", $queue);
		my $queuename	=	$self->getQueueName($queue);
		#$self->logDebug("queuename", $queuename);

		push @$queuenames, $queuename;
	}

	return $queuenames;
}

#### QUOTAS
method getResourceQuota ($username, $metric) {
=pod

nova quota-show
+-----------------------------+---------+
| Quota                       | Limit   |
+-----------------------------+---------+
| instances                   | 100     |
| cores                       | 576     |
| ram                         | 4718592 |
| floating_ips                | 10      |
| fixed_ips                   | -1      |
| metadata_items              | 128     |
| injected_files              | 5       |
| injected_file_content_bytes | 10240   |
| injected_file_path_bytes    | 255     |
| key_pairs                   | 100     |
| security_groups             | 10      |
| security_group_rules        | 20      |
+-----------------------------+---------+

=cut

	$self->logNote("username", $username);
	$self->logNote("metric", $metric);

	my $quotas	=	$self->getQuotas($username);
	#$self->logNote("quotas", $quotas);

	my $quota	=	undef;
	if ( $metric eq "cpus" ) {
		($quota)	=	$quotas	=~	/cores\s+\|\s+(\d+)/ms;
		$self->logNote("quota", $quota);
	}
	else {
		print "Balancer::getResourceQuota    Metric not supported: $metric\n" and exit;
	}

	return $quota;	
}

method getQuotas ($username) {
	$self->logNote("username", $username);
	
	my $quotas	=	$self->virtual()->getQuotas();
	#$self->logNote("quotas", $quotas);
	
	return $quotas;
}


#### INSTANCE TYPE
method getInstanceTypes ($queues) {
	
	$self->logDebug("queues", $queues);
	
	my $instancetypes	=	{};
	foreach my $queue ( @$queues ) {
		#$self->logDebug("queue", $queue);
		my $queuename	=	$self->getQueueName($queue);
		$self->logDebug("queuename", $queuename);
		
		my $instancetype	=	$self->getQueueInstance($queue);
		$instancetypes->{$queuename}	= $instancetype;
	}
	#$self->logDebug("instancetypes", $instancetypes);
	
	return $instancetypes;
}

method getQueueInstance ($queue) {
	$self->logDebug("queue", $queue);
	my $queuename	=	$self->getQueueName($queue);
	#$self->logDebug("queuename", $queuename);
	my $query	=	qq{SELECT * FROM instancetype
WHERE username='$queue->{username}'
AND cluster='$queuename'};
	$self->logDebug("query", $query);
	my $instancetype	=	$self->table()->db()->queryhash($query);
	#$self->logDebug("instancetype", $instancetype);	
	
	return $instancetype;
}

method getThroughputs ($queues, $durations, $instancecounts) {
	$self->logDebug("queues", $queues);
	$self->logDebug("durations", $durations);
	$self->logDebug("instancecounts", $instancecounts);
	my $SECONDS	=	3600;
	my $throughputs	=	{};
	foreach my $queue ( @$queues ) {
		my $queuename	=	$self->getQueueName($queue);
		#$self->logDebug("queuename", $queuename);
		
		my $throughput	=	($SECONDS/$durations->{$queuename}) * $instancecounts->{$queuename};
		$self->logDebug("throughput = ($SECONDS/$durations->{$queuename}) * $instancecounts->{$queuename}");
		$self->logDebug("throughput", $throughput);
		
		$throughputs->{$queuename}	=	$throughput;
	}
	
	return $throughputs;
}

method getQueueName ($queue) {
	$self->logCaller("queue", $queue);
	$self->logDebug("queue", $queue);
	
	my $fields	=	[ "username", "project", "workflow" ];
	foreach my $field ( @$fields ) {
		return if not defined $queue->{$field};
	}

	return $queue->{username} . "." . $queue->{project} . "." . $queue->{workflow};
}

#### COUNTS
method getCurrentCounts ($username) {
	my $query	=	qq{SELECT queue, COUNT(*) AS count
FROM instance
WHERE username='$username'
AND status='running'
GROUP BY queue};
	#$self->logDebug("query", $query);
	my $entries	=	$self->table()->db()->queryhasharray($query);
	#$self->logDebug("entries", $entries);
	my $counts	=	{};
	foreach my $entry ( @$entries ) {
		$counts->{$entry->{queue}}	=	$entry->{count}
	}
	#$self->logDebug("counts", $counts);

	return $counts;
}

method setMaxQuota ($queues, $instancecounts, $latestindex) {

	#### GET MAX JOBS
	my $maxjobs		=	$self->maxJobsForQueue($$queues[$latestindex]);
	$self->logDebug("maxjobs", $maxjobs);

	
}

method getRunningUserProjects ($username) {
	#$self->logDebug("username", $username);
	my $query	=	qq{SELECT projectname FROM project
WHERE username='$username'
AND status='running'};
	$self->logDebug("query", $query);
	my $projects	=	$self->table()->db()->queryarray($query);
	$self->logDebug("projects", $projects);
	
	return $projects;
}

method getLatestCompleted ($queues) {
	#$self->logDebug("queues", $queues);

	my $latestindex;
	for ( my $i = 0; $i < @$queues; $i++ ) {
		my $incomplete 	=	$self->hasNonCompletedSamples($$queues[$i]);
		#$self->logDebug("incomplete", $incomplete);
		$latestindex = $i if not $incomplete;
	}
	
	return $latestindex;
}

method getCompletedSamples ($queue) {
	my $query	=	qq{SELECT * FROM queuesample
WHERE username='$queue->{username}'
AND project='$queue->{project}'
AND workflow='$queue->{workflow}'
AND workflownumber=$queue->{workflownumber}
AND status='completed'
ORDER BY sample};
	#$self->logDebug("query", $query);
	my $samples	=	$self->table()->db()->queryhasharray($query);
	#$self->logDebug("samples", $samples);

	return $samples;	
}

method getLatestStarted ($queues) {
	#$self->logDebug("queues", $queues);

	my $latestindex;
	for ( my $i = 0; $i < @$queues; $i++ ) {
		my $started 	=	$self->hasStartedSamples($$queues[$i]);
		#$self->logDebug("queue [$i] $$queues[$i]->{workflow} started", $started);
		$latestindex = $i if $started;
	}
	
	return $latestindex;
}

method hasStartedSamples ($queue) {
	my $query	=	qq{SELECT 1 FROM queuesample
WHERE username='$queue->{username}'
AND project='$queue->{project}'
AND workflow='$queue->{workflow}'
AND workflownumber=$queue->{workflownumber}
AND status!='completed'
AND status!='none'
ORDER BY sample};
	#$self->logDebug("query", $query);
	my $started	=	$self->table()->db()->query($query);
	#$self->logDebug("started", $started);

	return 1 if defined $started;
	return 0;
}

method getStartedSamples ($queue) {
	my $query	=	qq{SELECT * FROM queuesample
WHERE username='$queue->{username}'
AND project='$queue->{project}'
AND workflow='$queue->{workflow}'
AND workflownumber=$queue->{workflownumber}
AND status!='completed'
ORDER BY sample};
	#$self->logDebug("query", $query);
	my $samples	=	$self->table()->db()->queryhasharray($query);
	#$self->logDebug("samples", $samples);

	return $samples;	
}
method getQueueCluster ($queue) {
	#$self->logDebug("queue", $queue);
	my $queuename	=	$self->getQueueName($queue);
	my $query	=	qq{SELECT * FROM cluster
WHERE username='$queue->{username}'
AND cluster='$queuename'};
	$self->logDebug("query", $query);
	my $instancetype	=	$self->table()->db()->queryhash($query);
	#$self->logDebug("instance", $instance);
	
	return $instancetype;
}


method getDurations ($queues) {
	my $durations	=	{};
	foreach my $queue ( @$queues ) {
		#$self->logDebug("queue", $queue);
		my $queuename	=	$queue->{username} . "." . $queue->{project} . "." . $queue->{workflow};
		my $duration	=	$self->getQueueDuration($queue);
		#$self->logDebug("duration", $duration);

		$durations->{$queuename}	= $duration if defined $duration;
		last if not defined $duration;
	}		

	return $durations;
}

method getQueueDuration ($queue) {
	
	#$self->logDebug("queue", $queue);

	my $provenance	=	$self->getQueueProvenance($queue);
	return if not defined $provenance or not @$provenance;
	#$self->logDebug("provenance", $provenance);
	
	#### COUNT ALL NON-ERROR start-completed DURATIONS
	my $samples	=	{};
	foreach my $row ( @$provenance ) {
		my $sample	=	$row->{sample};
		#$self->logDebug("sample", $sample);

		if ( defined $samples->{$sample} ) {
			push @{$samples->{$sample}}, $row;
		}
		else {
			$samples->{$sample}	=	[ $row ];
		}
	}
	#$self->logDebug("samples", $samples);
	
	my $totaldurations	=	[];
	foreach my $sample ( keys %$samples ) {
		#$self->logDebug("sample", $sample);
		my $rows	=	$samples->{$sample};
		#$self->logDebug("rows", $rows);

		my $sampledurations	=	$self->getSampleDurations($rows);
		#$self->logDebug("sampledurations", $sampledurations);
		@$totaldurations = (@$totaldurations, @$sampledurations) if defined $sampledurations and @$sampledurations;
	}
	#$self->logDebug("totaldurations", $totaldurations);
	
	my $duration = 0;
	foreach my $queueduration ( @$totaldurations ) {
		#$self->logDebug("queueduration", $queueduration);
		$duration += $queueduration;
	}
	$duration = $duration / scalar(@$totaldurations) if @$totaldurations;
	#$self->logDebug("FINAL AVERAGE duration", $duration);

	return undef if $duration == 0;
	return $duration;
}

method getSampleDurations ($rows) {
	#### WORK BACKWARDS AND COUNT EACH GOOD RUN
	#$self->logDebug("rows", $rows);

	my $durations	=	[];
	my $completed;
	my $start;
	for ( my $i = scalar(@$rows) - 1; $i > -1; $i-- ) {
		my $entry	=	$$rows[$i];
		#$self->logDebug("entry $i status", $entry->{status});
		if ( $entry->{status} eq "completed" ) {
			#$self->logDebug("completed, adding completed to entry", $entry);
			$completed = $entry;
		}
		elsif ( defined $completed and $entry->{status} eq "started" ) {
			my $duration	=	$self->calculateDuration($entry->{time}, $completed->{time});
			#$self->logDebug("duration", $duration);
			push @$durations, $duration if defined $duration;
			$completed = undef;
		}
		else {
			$completed = undef;
		}
	}
	
	return $durations;
}

method calculateDuration ($start, $stop) {
	#$self->logDebug("start", $start);
	#$self->logDebug("stop", $stop);
	return if not defined $start or not defined $stop;

	my $startseconds	=	$self->parseDate($start);
	#$self->logDebug("startseconds", $startseconds);
	return if not defined $startseconds;
	my $stopseconds	=	$self->parseDate($stop);
	#$self->logDebug("stopseconds", $stopseconds);
	return if not defined $stopseconds;

	return $stopseconds - $startseconds;
}

method parseDate ($date) { 
	#$self->logDebug("date", $date);

	# 2014-06-12 10:41:15
	my ($year, $month, $day, $hour, $minute, $second);
	if ( $date =~ m{^(\d{1,4})\W*0*(\d{1,2})\W*0*(\d{1,2})\W*0?\s+(\d{0,2})\W*0?(\d{0,2})\W*0?(\d{0,2})}x) {
		$year = $1;  $month = $2;   $day = $3;
		$hour = $4;  $minute = $5;  $second = $6;
		$hour |= 0;  $minute |= 0;  $second |= 0;  # defaults.
		$year = ($year<100 ? ($year<70 ? 2000+$year : 1900+$year) : $year);
		return timelocal($second, $minute, $hour, $day, $month - 1, $year);  
	}

	return undef;
}

method getQueueProvenance ($queue) {
	#$self->logDebug("queue", $queue);
	
	my $query	=	qq{SELECT * FROM provenance
WHERE username='$queue->{username}'
AND project='$queue->{project}'
AND workflow='$queue->{workflow}'
AND workflownumber=$queue->{workflownumber}
ORDER BY sample, time};
	#$self->logDebug("query", $query);
	my $provenance	=	$self->table()->db()->queryhasharray($query);
	#$self->logDebug("provenance", $provenance);

	return $provenance;
}

method getQueues {
	my $query       =	qq{SELECT queuesample.* FROM queuesample,project
WHERE project.status='running'
AND project.username=queuesample.username
AND project.name=queuesample.project
ORDER BY queuesample.username, queuesample.project, queuesample.workflownumber, queuesample.sample};
	$self->logDebug("query", $query);

	return	$self->table()->db()->queryhasharray($query);
}

method getDistinctQueues ($project) {
	my $query       =	qq{SELECT DISTINCT queuesample.username, queuesample.project, queuesample.workflow, queuesample.workflownumber
FROM queuesample,project,cluster
WHERE project.name='$project'
AND project.status='running'
AND project.username=queuesample.username
AND project.name=queuesample.project
ORDER BY queuesample.username, queuesample.project, queuesample.workflownumber, queuesample.sample};
	#$self->logDebug("query", $query);

	return	$self->table()->db()->queryhasharray($query);
}

#### TOPICS
method sendTopic ($data, $key) {
	$self->logDebug("data", $data);
	$self->logDebug("key", $key);

	my $exchange	=	$self->conf()->getKey( "mq:topicexchange", undef);
	$self->logDebug("exchange", $exchange);

	my $host		=	$self->host() || $self->conf()->getKey( "mq:host", undef);
	my $user		= 	$self->user() || $self->conf()->getKey( "mq:user", undef);
	my $pass		=	$self->pass() || $self->conf()->getKey( "mq:pass", undef);
	my $vhost		=	$self->vhost() || $self->conf()->getKey( "mq:vhost", undef);
	$self->logDebug("host", $host);
	$self->logDebug("user", $user);
	$self->logDebug("pass", $pass);
	$self->logDebug("vhost", $vhost);
	
	my $connection = Net::RabbitMQ->new() ;
	$connection->connect(
		$host,
		{
			port 		=>	5672,
			host		=>	$host,
			user 		=>	$user,
			password 	=>	$pass,
			vhost		=>	$vhost
		}
	);

	my $channel_id      = 1;
	$connection->channel_open($channel_id);

	#### disable auto_delete.
	my $exchange_type 	= 'topic';
	$connection->exchange_declare(
		$channel_id, 
		$exchange, 
		{
			exchange 		=> 	$exchange, 
			exchange_type 	=> 	$exchange_type, 
			auto_delete 	=> 	0
		}
	);

	my $parser = $self->setParser();
	my $json = $parser->encode($data);
	$self->logDebug("json", $json);

	$connection->publish(
		$channel_id, 
		$key, 
		$json, 
		{ 
			exchange => $exchange 
		}
	);

	print " [x] Sent topic on exchange '$exchange' with routing key '$key': $json\n";

	$connection->disconnect;
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

#method getWorkflows ($node) {
##### GET CURRENT WORKFLOW STATES (COMPLETED, EXITED)
#	
#}
#
# method runCommand ($command) {
# 	$self->logDebug("command", $command);
	
# 	return `$command`;
# }

method startWorkflow {
	#### OVERRIDE	
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

# method setParser {
# 	return JSON->new->allow_nonref;
# }

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
	
	
	



1;

