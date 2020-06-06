use MooseX::Declare;

=head2

PURPOSE

  1. Balance number of nodes by adding and removing nodes

  2. Add/remove based on throughput and available resources

  3. Add using AWS 'run-instances' command 
  
  4. Remove using fanout 'doShutdown' message to Seneschal
  
    Seneschal responds 

=cut

use strict;
use warnings;

class Siphon::Balancer with (Siphon::Common, Logger, Exchange, Agua::Common::Database, Agua::Common::Timer, Agua::Common::Project, Agua::Common::Stage, Agua::Common::Workflow, Agua::Common::Util) {

#####////}}}}}

{

# Integers
has 'parity'   =>  ( isa => 'Int', is => 'rw', default => 1 );
has 'log'    =>  ( isa => 'Int', is => 'rw', default => 2 );
has 'printlog'  =>  ( isa => 'Int', is => 'rw', default => 5 );
has 'maxjobs'  =>  ( isa => 'Int', is => 'rw', default => 50 );
has 'sleep'    =>  ( isa => 'Int', is => 'rw', default => 120 );
has 'quota'    =>  ( isa => 'Int', is => 'rw' );

# Strings
has 'sendtype'  => ( isa => 'Str|Undef', is => 'rw', default  =>  "task" );
has 'metric'  => ( isa => 'Str|Undef', is => 'rw', default  =>  "cpus" );
has 'user'    => ( isa => 'Str|Undef', is => 'rw', required  =>  0 );
has 'pass'    => ( isa => 'Str|Undef', is => 'rw', required  =>  0 );
has 'host'    => ( isa => 'Str|Undef', is => 'rw', required  =>  0 );
has 'vhost'    => ( isa => 'Str|Undef', is => 'rw', required  =>  0 );
has 'modulestring'  => ( isa => 'Str|Undef', is => 'rw', default  => "Agua::Workflow" );
has 'rabbitmqctl'  => ( isa => 'Str|Undef', is => 'rw', default  => "/usr/sbin/rabbitmqctl" );

# Objects
has 'modules'  => ( isa => 'ArrayRef|Undef', is => 'rw', lazy  =>  1, builder  =>  "setModules");
has 'conf'    => ( isa => 'Conf::Yaml', is => 'rw', required  =>  0 );
has 'synapse'  => ( isa => 'Synapse', is => 'rw', lazy  =>  1, builder  =>  "setSynapse" );
has 'db'    => ( isa => 'Agua::DBase::MySQL', is => 'rw', lazy  =>  1,  builder  =>  "setDbh" );
has 'jsonparser'=> ( isa => 'JSON', is => 'rw', lazy  =>  1, builder  =>  "setParser" );
has 'virtual'  => ( isa => 'Any', is => 'rw', lazy  =>  1, builder  =>  "setVirtual" );
has 'duplicate'  => ( isa => 'HashRef|Undef', is => 'rw');
has 'channel'  => ( isa => 'Any', is => 'rw', required  =>  0 );

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

method balance {
  my $virtualtype  =  $self->conf()->getKey("agua", "VIRTUALTYPE");
  $self->logDebug("virtualtype", $virtualtype);
  
  if ( $virtualtype eq "openstack" ) {
    $self->balanceOpenstack();
  }
  elsif ( $virtualtype eq "aws" ) {
    $self->balanceAws();
  }
}

method balanceAws {
  while ( 1 ) {
    my $username  =  $self->conf()->getKey("agua", "ADMINUSER");
    $self->logDebug("username", $username);

    #### GET PROJECTS
    my $projects  =  $self->getRunningUserProjects($username);
    $self->logDebug("projects", $projects);

    foreach my $project  ( @$projects ) {
      $self->logDebug("project", $project);

      #### GET WORKFLOWS
      my $workflows  =  $self->getWorkflowsByProject({
        name    =>  $project,
        username  =>  $username
      });
      $self->logDebug("workflows", $workflows);
      next if not defined $workflows or not @$workflows;
      print "Balancer::manage    project $project workflows:\n";
      foreach my $workflow ( @$workflows ) {
        print "Balancer::manage    $project [$workflow->{number}] $workflow->{name}\n";
      }
      
      ### BALANCE INSTANCES
      $self->balanceAwsInstances($workflows);
    }

    #### PAUSE
    $self->pause();
  }
  
  return 1;
}

method balanceAwsInstances ($workflows) {
  print "\n\n#### DOING balanceAwsInstances\n";
  $self->logDebug("workflows", $workflows);

  my $stopping  =  $self->stoppingInstances();
  $self->logDebug("stopping", $stopping);
  return if $stopping;
  
  my $username  =  $$workflows[0]->{username};
  #$self->logDebug("username", $username);

  # 1. CALCULATE AVERAGE DURATION OF completed SAMPLES IN EACH WORKFLOW/QUEUE
  my $durations  =  $self->getDurations($workflows);
  $self->logDebug("durations", $durations);
  
  #### NARROW DOWN TO ONLY QUEUES WITH CLUSTERS
  $workflows  =  $self->clusterWorkflows($workflows);  
  $self->logDebug("cluster only workflows", $workflows);

  # 2. GET CURRENT COUNTS OF RUNNING INSTANCES PER QUEUE
  my $currentcounts  =  $self->getCurrentCounts($username);
  $self->logDebug("currentcounts", $currentcounts);

  #### GET REQUIRED RESOURCES FOR QUEUE INSTANCES (CPUs, RAM, ETC.)
  my $instancetypes  =  $self->getInstanceTypes($workflows);
  $self->logDebug("instancetypes", $instancetypes);

  # 3. IF LATEST RUNNING WORKFLOW HAS NO COMPLETED JOBS, SET
  #  INSTANCE COUNT FOR NEXT WORKFLOW TO cluster->minnodes
  my $latestcompleted =  $self->getLatestCompleted($workflows);
  $self->logDebug("latestcompleted", $latestcompleted);

### DEBUG

# # 4. GET TOTAL QUOTA FOR RESOURCE (DEFAULT: NO. CPUS)
# my $metric  =  $self->metric();  
#
## REM: ADD getQuota TO Aws
#
# my $quota  =  $self->getResourceQuota($username, $metric);
# $self->logDebug("quota", $quota);

# #### OVERRIDE WITH COMMAND LINE ARGUMENT --quota
# $quota = $self->quota() if defined $self->quota();


my $quota    =  24;
$self->logDebug("DEBUG quota", $quota);
my $metric     =  "cpus";

### DEBUG


  my $resourcecounts  =  [];
  my $instancecounts  =  [];
  #### SET DEFAULT INSTANCE COUNTS FOR FIRST WORKFLOW IF:
  #### 1. PROJECT WORKFLOWS HAVE JUST STARTED RUNNING, OR
  #### 2. SAMPLES HAVE JUST BEEN LOADED
  #### 
  if ( not defined $latestcompleted or not %$durations ) {
    print "#### DOING getDefaultResource\n";
    my $resourcecount  =  $self->getDefaultResource($$workflows[0], $instancetypes, $quota);
    $self->logDebug("resourcecount", $resourcecount);

    my $queuename  =  $self->getQueueName($$workflows[0]);
    my $resource  =  $instancetypes->{$queuename}->{$metric};
    $self->logDebug("resource", $resource);
    my $instancecount  =  ceil($resourcecount/$resource);
    $instancecount    =  0 if $instancecount < 1;
    $self->logDebug("instancecount", $instancecount);
    
    $resourcecounts  =  [ $resourcecount ];
    $instancecounts  =  [ $instancecount ];
  }
  else {
    print "#### DOING getResourceCounts\n";
    ##### GET CURRENT COUNT OF VMS PER QUEUE (queueample STATUS 'started')
    ##### ASSUMES ONE VM PER TASK
    #my $currentcounts=  $self->getCurrentCounts();
    #$self->logDebug("currentcounts", $currentcounts);
    
    # 2. BALANCE COUNTS BASED ON DURATION
    #
    $resourcecounts  =  $self->getResourceCounts($workflows, $durations, $instancetypes, $quota);
    $instancecounts  =  $self->getInstanceCounts($workflows, $instancetypes, $resourcecounts);
    #$self->logDebug("instancecounts", $instancecounts);

    #### IF NOT ALL WORKFLOWS HAVE RUNNING INSTANCES,
    #### SET DEFAULT INSTANCE COUNTS FOR 2ND TO LAST RUNNING WORKFLOW 
    #### IF IT HAS NO COMPLETED JOBS TO PROVIDE DURATION INFO
    my $lateststarted  =  $self->getLatestStarted($workflows);
    $self->logDebug("lateststarted", $lateststarted);
    $lateststarted    =  $latestcompleted if not defined $lateststarted;
  
    if ( $lateststarted != $latestcompleted ) {
      $instancecounts  =  $self->adjustCounts($workflows, $resourcecounts, $lateststarted, $quota);
    }
  }
  $self->logDebug("resourcecounts", $resourcecounts);
  $self->logDebug("instancecounts", $instancecounts);

  $self->addRemoveNodes($workflows, $instancecounts, $currentcounts, $instancetypes);

  #   TAILOUT AT END OF SAMPLE RUN:
  #   NB: maxJobs <= NUMBER OF REMAINING SAMPLES FOR THE WORKFLOW
}


method balanceOpenstack {
  while ( 1 ) {
  
    #my $tenants    =  $self->getTenants();
    #$self->logDebug("tenants", $tenants);
    #foreach my $tenant ( @$tenants ) {
    #  my $username  =  $tenant->{username};
    #
      my $username  =  $self->conf()->getKey("agua", "ADMINUSER");
    $self->logDebug("username", $username);
    
      #### GET PROJECTS
      my $projects  =  $self->getRunningUserProjects($username);
      $self->logDebug("projects", $projects);

      foreach my $project  ( @$projects ) {
        $self->logDebug("project", $project);
  
        #### GET WORKFLOWS
        my $workflows  =  $self->getWorkflowsByProject({
          name    =>  $project,
          username  =>  $username
        });
        $self->logDebug("workflows", $workflows);
        next if not defined $workflows or not @$workflows;
        print "Balancer::manage    project $project workflows:\n";
        foreach my $workflow ( @$workflows ) {
          print "Balancer::manage    $project [$workflow->{number}] $workflow->{name}\n";
        }
        
        #### BALANCE INSTANCES
        $self->balanceInstances($workflows);
      }
    
    #}
    
    #### PAUSE
    $self->pause();
  }
  
  return 1;
}

method pause {
  my $sleep  =  $self->sleep();
  print "PAUSE    Sleeping $sleep seconds\n";
  sleep($sleep);
}

method getProjects ($username) {
  return if not defined $username;
  return $self->db()->queryarray("SELECT * FROM project WHERE username='$username'");
}
#### BALANCE INSTANCES
method balanceOpenstackInstances ($workflows) {
  print "\n\n#### DOING balanceInstances\n";
  $self->logDebug("workflows", $workflows);

  my $stopping  =  $self->stoppingInstances();
  $self->logDebug("stopping", $stopping);
  return if $stopping;
  
  my $username  =  $$workflows[0]->{username};
  #$self->logDebug("username", $username);

  # 1. CALCULATE AVERAGE DURATION OF completed SAMPLES IN EACH WORKFLOW/QUEUE
  my $durations  =  $self->getDurations($workflows);
  $self->logDebug("durations", $durations);
  
  #### NARROW DOWN TO ONLY QUEUES WITH CLUSTERS
  $workflows  =  $self->clusterWorkflows($workflows);  
  $self->logDebug("cluster only workflows", $workflows);

  # 2. GET CURRENT COUNTS OF RUNNING INSTANCES PER QUEUE
  my $currentcounts  =  $self->getCurrentCounts($username);
  $self->logDebug("currentcounts", $currentcounts);

  #### GET REQUIRED RESOURCES FOR QUEUE INSTANCES (CPUs, RAM, ETC.)
  my $instancetypes  =  $self->getInstanceTypes($workflows);
  $self->logDebug("instancetypes", $instancetypes);

  # 3. IF LATEST RUNNING WORKFLOW HAS NO COMPLETED JOBS, SET
  #  INSTANCE COUNT FOR NEXT WORKFLOW TO cluster->minnodes
  my $latestcompleted =  $self->getLatestCompleted($workflows);
  $self->logDebug("latestcompleted", $latestcompleted);

  # 4. GET TOTAL QUOTA FOR RESOURCE (DEFAULT: NO. CPUS)
  my $metric  =  $self->metric();  
  my $quota  =  $self->getResourceQuota($username, $metric);
  $self->logDebug("quota", $quota);

#### DEBUG

$quota    =  2;
$self->logDebug("DEBUG quota", $quota);

#### DEBUG


  my $resourcecounts  =  [];
  my $instancecounts  =  [];
  #### SET DEFAULT INSTANCE COUNTS FOR FIRST WORKFLOW IF:
  #### 1. PROJECT WORKFLOWS HAVE JUST STARTED RUNNING, OR
  #### 2. SAMPLES HAVE JUST BEEN LOADED
  #### 
  if ( not defined $latestcompleted or not %$durations ) {
    print "#### DOING getDefaultResource\n";
    my $resourcecount  =  $self->getDefaultResource($$workflows[0], $instancetypes, $quota);
    $self->logDebug("resourcecount", $resourcecount);

    my $metric  =  $self->metric();

    my $queuename  =  $self->getQueueName($$workflows[0]);
    my $resource  =  $instancetypes->{$queuename}->{$metric};
    my $instancecount  =  ceil($resourcecount/$resource);
    $instancecount    =  0 if $instancecount < 1;
    $self->logDebug("instancecount", $instancecount);
    
    $resourcecounts  =  [ $resourcecount ];
    $instancecounts  =  [ $instancecount ];
  }
  else {
    print "#### DOING getResourceCounts\n";
    ##### GET CURRENT COUNT OF VMS PER QUEUE (queueample STATUS 'started')
    ##### ASSUMES ONE VM PER TASK
    #my $currentcounts=  $self->getCurrentCounts();
    #$self->logDebug("currentcounts", $currentcounts);
    
    # 2. BALANCE COUNTS BASED ON DURATION
    #
    $resourcecounts  =  $self->getResourceCounts($workflows, $durations, $instancetypes, $quota);
    $instancecounts  =  $self->getInstanceCounts($workflows, $instancetypes, $resourcecounts);
    #$self->logDebug("instancecounts", $instancecounts);

    #### IF NOT ALL WORKFLOWS HAVE RUNNING INSTANCES,
    #### SET DEFAULT INSTANCE COUNTS FOR 2ND TO LAST RUNNING WORKFLOW 
    #### IF IT HAS NO COMPLETED JOBS TO PROVIDE DURATION INFO
    my $lateststarted  =  $self->getLatestStarted($workflows);
    $self->logDebug("lateststarted", $lateststarted);
    $lateststarted    =  $latestcompleted if not defined $lateststarted;
  
    if ( $lateststarted != $latestcompleted ) {
      $instancecounts  =  $self->adjustCounts($workflows, $resourcecounts, $lateststarted, $quota);
    }
  }
  $self->logDebug("resourcecounts", $resourcecounts);
  $self->logDebug("instancecounts", $instancecounts);

  $self->addRemoveNodes($workflows, $instancecounts, $currentcounts, $instancetypes);

  #   TAILOUT AT END OF SAMPLE RUN:
  #   NB: maxJobs <= NUMBER OF REMAINING SAMPLES FOR THE WORKFLOW
}

method stoppingInstances {
  my $query  =  qq{SELECT * FROM instance
WHERE status='stopping'
};
  my $stopping  =  $self->db()->queryhasharray($query);
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
method addRemoveNodes ($workflows, $instancecounts, $currentcounts, $instancetypes) {
  #$self->logDebug("workflows", $workflows);
  $self->logDebug("currentcounts", $currentcounts);
  $self->logDebug("instancecounts", $instancecounts);

  for ( my $i = 0; $i < @$instancecounts; $i++ ) {
    my $instancecount =  $$instancecounts[$i];
    $self->logDebug("instancecount [$i]", $instancecount);

    my $queuename  =  $self->getQueueName($$workflows[$i]);
    $self->logDebug("queuename [$i]", $queuename);
    
    my $currentcount =  $currentcounts->{$queuename} || 0;
    $self->logDebug("currentcount [$i]", $currentcount);
    
    my $remainingsamples = $self->remainingSamples($workflows); 
    $self->logDebug("remainingsamples", $remainingsamples);

    $instancecount = $remainingsamples if $remainingsamples < $instancecount;

    my $difference  =  $instancecount - $currentcount;
    $self->logDebug("difference  = $instancecount - $currentcount");
    $self->logDebug("difference [$i]", $difference);

    my $instance    =  $instancetypes->{$queuename};

    if ( $difference > 0 ) {
      $self->addNodes($$workflows[$i], $difference, $instance);
    }
    elsif ( $difference < 0 ) {
      $self->deleteNodes($$workflows[$i], abs($difference));
    }
  }  
}

method remainingSamples ($workflows) {
  $self->logDebug("workflows", $workflows);
  
  my $remainingsamples = 0;    #### NO. INSTANCES FOR ALL WORKFLOWS
  my $parity = $self->parity();   #### NO. SAMPLES PER INSTANCE
  foreach my $workflow ( @$workflows ) {
    my $tasks = $self->getWorkflowSamples($workflow);
    $remainingsamples += scalar(@$tasks); 
  }

  return $remainingsamples;
}

method getWorkflowSamples ($workflow) {
  $self->logDebug("workflow", $workflow);
  my $workflownumber  =  $workflow->{workflownumber};

  my $query    =  qq{SELECT * FROM queuesample
WHERE username='$workflow->{username}'
AND project='$workflow->{project}'
AND workflow='$workflow->{workflow}'
AND workflownumber='$workflow->{workflownumber}'
AND (status='queued' OR status='none')
};
  $self->logDebug("query", $query);
  
  return $self->db()->queryhasharray($query) || [];
}

method addNodes ($workflow, $maxnodes, $instance) {
  $self->logDebug("workflow", $workflow);
  $self->logDebug("maxnodes", $maxnodes);

  my $username  =  $workflow->{username};
  my $project    =  $workflow->{project};
  my $name    =  $workflow->{project} . "-" . $workflow->{workflow};

  #### VOLUME SIZE
  my $disksize   =  $instance->{disk};

  #### GET amiid, instancetype FOR cluster
  #### (cluster = username.project.workflow)
  my $clusterobject  =  $self->getQueueCluster($workflow);
  my $amiid      =  $clusterobject->{amiid};
  my $instancetype  =  $clusterobject->{instancetype};
  $self->logDebug("amiid", $amiid);
  $self->logDebug("instancetype", $instancetype);

  my $workobject  =  $self->getWorkObject($workflow);
  $self->logDebug("workobject", $workobject);
  
  my $instanceobject  =  $self->getQueueInstance($workobject);

  for ( my $i = 0; $i < $maxnodes; $i++ ) {

    my $hostname  =  $self->randomHostname($name);
    $self->logDebug("hostname", $hostname);
  
    my ($instanceid, $ipaddress)  =  $self->virtual()->launchNode($workobject, $instanceobject, $amiid, $maxnodes, $instancetype, $hostname, $disksize);
    $self->logDebug("instanceid", $instanceid);
    $self->logError("failed to add node") and return 0 if not defined $instanceid;

    my $success  =  0;
    $success  =  1 if $instanceid =~ /^[0-9a-z\-]+$/;
    $self->logDebug("failed to add node") and return 0 if not $success;
    
    $self->addHostInstance($workflow, $hostname, $instanceid, $ipaddress);    
  }
  
  return 1;
}

method getWorkObject ($workflow) {
  $self->logDebug("workflow", $workflow);

  #### ADD package AND version TO WORKFLOW OBJECT
  my $stages      =  $self->getStagesByWorkflow($workflow);
  my $object      =  $$stages[0];
  my $package      =  $object->{package};
  my $version      =  $object->{version};
  $self->logDebug("package", $package);
  $self->logDebug("version", $version);

  return $object;
}

method addHostInstance ($workflow, $hostname, $instanceid, $ipaddress) {
  #$self->logDebug("workflow", $workflow);
  #$self->logDebug("hostname", $hostname);
  $self->logDebug("instanceid", $instanceid);
  my $time      =  $self->getMysqlTime();
  my $data  =  {};
  $data->{username}  =  $workflow->{username};
  $data->{queue}    =  $self->getQueueName($workflow);
  $data->{host}    =  $hostname;
  $data->{instanceid}  =  $instanceid;
  $data->{ipaddress}  =  $ipaddress;
  $data->{status}    =  "running";
  $data->{time}    =  $time;
  $self->logDebug("data", $data);
  
  my $keys  =  [ "username", "queue", "host" ];
  my $notdefined  =  $self->notDefined($data, $keys);  
  $self->logDebug("notdefined", $notdefined) and return if @$notdefined;

  #### ADD TO TABLE
  my $table    =  "instance";
  my $fields    =  $self->db()->fields($table);
  $self->_addToTable($table, $data, $keys, $fields);
}

method getInstallDir ($packagename) {
  $self->logDebug("packagename", $packagename);

  my $packages = $self->conf()->getKey("packages:$packagename", undef);
  $self->logDebug("packages", $packages);
  my $version  =  undef;
  foreach my $key ( %$packages ) {
    $version  =  $key;
    last;
  }

  my $installdir  =  $packages->{$version}->{INSTALLDIR};
  $self->logDebug("installdir", $installdir);
  
  return $installdir;
}

method randomHostname ($name) {
  
  my $length  =  10;
  my $random  =  $self->randomHexadecimal($length);  
  my $randomname  =  $name . "-" . $random;
  #$self->logDebug("randomname", $randomname);
  while ( $self->hostExists($randomname) ) {
    $random  =  $self->randomHexadecimal($length);  
    $randomname  =  $name . "-" . $random;
  }

  return $randomname;  
}

method hostExists ($host) {
  my $query  =  qq{SELECT 1 FROM heartbeat
WHERE host='$host'};
  #$self->logDebug("query", $query);
  
  my $success  =  $self->db()->query($query);
  #$self->logDebug("success", $success);
  
  return 0 if not defined $success;
  return 1;
}

method randomHexadecimal ($length) {
  #$self->logDebug("length", $length);
  
  my $random  =  "";
  for ( 0 .. $length ) {
    $random .= sprintf "%01X", rand(0xf);
  }
  $random  =  lc($random);
  #$self->logDebug("random", $random);
  
  return $random;
}

method updateInstanceStatus ($id, $status) {
  $self->logNote("id", $id);
  $self->logNote("status", $status);
  
  my $time    =  $self->getMysqlTime();
  my $query    =  qq{UPDATE instance
SET status='$status',
TIME='$time'
WHERE id='$id'
};
  return $self->db()->do($query);
}

#### DELETE NODES
method deleteNodes ($workflow, $number) {
  my $queuename  =  $self->getQueueName($workflow);
  my $username  =  $workflow->{username};
  my $query  =  qq{SELECT * FROM instance
WHERE username='$username'
AND queue='$queuename'
AND status='running'
LIMIT $number};
  #$self->logDebug("query", $query);
  
  my $instances  =  $self->db()->queryhasharray($query);
  foreach my $instance ( @$instances ) {
    $self->updateInstanceStatus($instance->{id}, "stopping");
    $self->shutdownInstance($workflow, $instance->{id});
  }
}

method shutdownInstance ($workflow, $instanceid) {
  $self->logDebug("instanceid", $instanceid);

  my $stages      =  $self->getStagesByWorkflow($workflow);
  my $object      =  $$stages[0];
  my $package      =  $object->{package};
  my $installdir    =  $self->getInstallDir($package);
  my $version      =  $object->{version};
  my $teardownfile  =  $self->setTearDownFile($installdir, $version);
  #$self->logDebug("teardownfile", $teardownfile);
  my $teardown    =  "";
  $teardown = $self->getFileContents($teardownfile) if -f $teardownfile;
  #$self->logDebug("teardown", substr($teardown, 0, 100));
  
  my $data  =  {
    source      =>  "balancer",
    instanceid    =>  $instanceid,
    mode      =>  "doShutdown",
    teardown    =>  $teardown,
    teardownfile  =>  $teardownfile
  };
  $self->logDebug("data", $data);
  
    $self->sendFanout("direct_logs", $data);

  # my $key  =  "update.host.status";
  # $self->sendTopic($data, $key);

}

method setTearDownFile($installdir, $version) {
  return "$installdir/data/sh/teardown.sh";
}

#### RESOURCES
method getDefaultResource ($queue, $instancetypes, $quota) {
  $self->logDebug("queue", $queue);
  $self->logDebug("instancetypes", $instancetypes);

  #### SET FIRST NODES TO MAX NO SAMPLES COMPLETED
  my $queuename    =  $self->getQueueName($queue);
  my $instancetype  =  $instancetypes->{$queuename};
  $self->logDebug("instancetype", $instancetype);
  my $metric      =  $self->metric();
  my $resource    =  $instancetype->{$metric};
  $self->logDebug("queuename", $queuename);
  $self->logDebug("resource", $resource);
  $self->logDebug("instancetype", $instancetype);

  #### SET RESOURCE QUOTA
  my $resourcequota  =  $quota;
  $self->logDebug("resourcequota", $resourcequota);

  my $cluster  =  $self->getQueueCluster($queue);
  $self->logDebug("cluster", $cluster);
  my $maxnodes    =  $cluster->{maxnodes};
  $self->logDebug("maxnodes", $maxnodes);
  
  my $resourcecount   =  $resource * $maxnodes;
  $self->logDebug("resourcecount", $resourcecount);

  my $username    =  $queue->{username};
  
  if ( $resourcecount > $resourcequota ) {
    $self->logDebug("resourcecount $resourcecount > resourcequota $resourcequota. Setting to resourcequota ($resourcequota)");
    $resourcecount = $resourcequota;
  }
  $self->logDebug("FINAL resourcecount", $resourcecount);
  
  return $resourcecount;
}

method clusterWorkflows ($workflows) {
  #$self->logDebug("workflows", $workflows);

  my $clusterworkflows  =  [];
  for ( my $i = 0; $i < @$workflows; $i++ ) {
    #$self->logDebug("workflows[$i]", $$workflows[$i]);

    my $cluster  =  $self->getQueueCluster($$workflows[$i]);
    #$self->logDebug("cluster", $cluster);
    if ( defined $cluster ) {
      push @$clusterworkflows, $$workflows[$i];      
    }
  }
  ##$self->logDebug("CLUSTER ONLY clusterworkflows", $clusterworkflows);
  #if ( defined $clusterworkflows ) {
  #  print "cluster workflows:\n";
  #  foreach my $clusterworkflow ( @$clusterworkflows ) {
  #    print "$clusterworkflow->{name}\n";
  #  }
  #}

  return $clusterworkflows;
}

method adjustCounts ($queues, $resourcecounts, $lateststarted, $quota) {

#### SET DEFAULT INSTANCE COUNTS FOR NEXT WORKFLOW IF IT HAS NO
#### COMPLETED JOBS TO PROVIDE DURATION INFO

  $self->logDebug("resourcecounts", $resourcecounts);
  my $nextqueue  =  $$queues[$lateststarted];
  $self->logDebug("nextqueue", $nextqueue);
  my $nextqueuename  =  $self->getQueueName($nextqueue);
  $self->logDebug("nextqueuename", $nextqueuename);
  
  my $cluster  =  $self->getQueueCluster($nextqueue);
  $self->logDebug("cluster", $cluster);
  my $min      =  $cluster->{minnodes};
  $self->logDebug("min", $min);

  my $instancetypes  =  $self->getInstanceTypes($queues);
  my $instancetype  =  $instancetypes->{$nextqueuename};
  $self->logDebug("instancetype", $instancetype);
  my $metric    =  $self->metric();
  my $resource  =  $instancetype->{$metric};
  
  my $total  =  0;
  foreach my $resourcecount ( @$resourcecounts ) {
    $total  +=  $resourcecount;
  }
  $self->logDebug("total", $total);
  
  #### IF 
  if ( $total == 0 ) {
    $$resourcecounts[$lateststarted] = $quota;
  }
  else {
    my $latestcount  =  ($min * $resource);
    my $newtotal  =  $total - $latestcount;
    $self->logDebug("newtotal", $newtotal);
    
    if ( $newtotal == $total ) {
      $$resourcecounts[$lateststarted] = $quota;
    }
    else {
      foreach my $resourcecount ( @$resourcecounts ) {
        last if $resourcecount == 0;
        $resourcecount  =  $resourcecount * ($newtotal/$total);
      }
      $$resourcecounts[$lateststarted] = $latestcount;
    }    
  }
  $self->logDebug("FINAL resourcecounts", $resourcecounts);
  
  $self->logDebug("RETURNING RERUN OF self->getInstanceCounts");
  return $self->getInstanceCounts($queues, $instancetypes, $resourcecounts);
}

method getResourceCounts ($queues, $durations, $instancetypes, $quota) {

=head2  SUBROUTINE  getResourceCounts

=head2  PURPOSE
  
  Allocate resources (e.g., CPUs) to each workflow

=head2  ALGORITHM

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
  my $lateststarted   =  $self->getLatestStarted($queues);
  $self->logDebug("lateststarted", $lateststarted);
  $lateststarted    =  $self->getLatestCompleted($queues) if not defined $lateststarted;

  #### GET FIRST DURATION
  my $firstqueue    =  $self->getQueueName($$queues[0]);
  my $metric  =  $self->metric();
  my $instancetype  =  $instancetypes->{$firstqueue};
  my $firstresource  =  $instancetype->{$metric};
  my $firstduration  =  $durations->{$firstqueue} * $firstresource;
  $self->logDebug("firstqueue", $firstqueue);
  $self->logDebug("firstresource", $firstresource);
  $self->logDebug("firstduration", $firstduration);
  
  ####  1. Solve for n1 using [1], [2] and [3]
  ####  n1 = N/(1 + d2/d1 + d3/d1 + ... + dx/d1)
  my $terms  =  $self->solveForTerms($queues, $durations, $instancetypes, $lateststarted);
  $self->logDebug("terms", $terms);
  
  my $firstcount    =  $quota / $terms;
  $self->logDebug("firstcount", $firstcount);

  my $firstthroughput  =  ($firstduration/3600) * $firstcount;
  $self->logDebug("firstthroughput", $firstthroughput);

  my $queuenames    =  $self->getQueueNames($queues);
  #$self->logDebug("queuenames", $queuenames);

  my $completedworkflows  =  $self->getCompletedWorkflows($queues);  
  $self->logDebug("completedworkflows", $completedworkflows);

  my $resourcecounts  =  [];
  for ( my $i = 0; $i < $lateststarted + 1; $i++ ) {
    my $queuename  =  $$queuenames[$i];
    $self->logDebug("queuename [$i]", $queuename);
    $self->logDebug("completedworkflows [$i]", $$completedworkflows[$i]);

    push @$resourcecounts, 0 and next if $$completedworkflows[$i];
    
    my $duration  =  $durations->{$queuename};
    $self->logDebug("duration", $duration);
    push @$resourcecounts, 0 and last if not defined $duration;
    
    my $instancetype  =  $instancetypes->{$queuename};
    $self->logDebug("instancetype", $instancetype);
    my $resource  =  $instancetype->{$metric};
    $self->logDebug("resource ($metric)", $resource);

    my $adjustedduration  =  $duration * $resource;
    $self->logDebug("adjustedduration", $adjustedduration);
    
    my $resourcecount  =  ($firstcount * $adjustedduration) / $firstduration;
    $self->logDebug("resourcecount", $resourcecount);

    my $throughput  =  (3600/$adjustedduration) * $resourcecount;
    $self->logDebug("throughput", $throughput);

    push @$resourcecounts, $resourcecount;
  }
  $self->logDebug("resourcecounts", $resourcecounts);

  ##### VERIFY TOTAL
  #my $total = 0;
  #for ( my $i = 0; $i < @$resourcecounts; $i++ ) {
  #  my $resourcecount   =  $$resourcecounts[$i];
  #
  #  my $queuename  =  $$queuenames[$i];
  #  $self->logDebug("queuename", $queuename);
  #
  #  my $duration  =  $durations->{$queuename};
  #  $self->logDebug("duration", $duration);
  #
  #  $self->logDebug("count = $resourcecount / $duration");
  #  my $count  =  $resourcecount / $duration;
  #  $self->logDebug("count", $count);
  #  
  #  $total   +=  $resourcecount;
  #}
  #$self->logDebug("total", $total);
  
  return $resourcecounts;
}

method getCompletedWorkflows ($queues) {
  #$self->logDebug("queues", $queues);
  
  my $completed  =  [];
  my $complete  =  1;
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
  
  my $query  =  qq{SELECT 1 FROM queuesample
WHERE username='$queue->{username}'
AND project='$queue->{project}'
AND workflow='$queue->{workflow}'
AND workflownumber=$queue->{workflownumber}
AND status!='completed'
ORDER BY sample};
  #$self->logDebug("query", $query);
  my $has  =  $self->db()->query($query);
  #$self->logDebug("has", $has);

  return 1 if defined $has;
  return 0;
}

method solveForTerms ($queues, $durations, $instancetypes, $latestcompleted) {
  #$self->logDebug("queues", $queues);
  #$self->logDebug("durations", $durations);
  #$self->logDebug("instancetypes", $instancetypes);

  #### GET FIRST DURATION
  my $firstqueue    =  $self->getQueueName($$queues[0]);
  my $instancetype  =  $instancetypes->{$firstqueue};
  my $metric      =  $self->metric();
  my $firstresource  =  $instancetype->{$metric};
  my $firstduration  =  $durations->{$firstqueue} * $firstresource;
  $self->logDebug("firstqueue", $firstqueue);
  #$self->logDebug("instancetype", $instancetype);
  $self->logDebug("firstresource", $firstresource);
  $self->logDebug("firstduration", $firstduration);

  my $terms  =  1;
  for ( my $i = 1; $i < $latestcompleted + 1; $i++ ) {
    my $queue  =  $$queues[$i];
    #$self->logDebug("queue $i", $queue);
    my $queuename  =  $self->getQueueName($queue);
    $self->logDebug("queuename", $queuename);

    my $duration  =  $durations->{$queuename};
    $self->logDebug("duration", $duration);
    last if not defined $duration or $duration == 0;
    
    my $instancetype  =  $instancetypes->{$queuename};
    $self->logDebug("instancetype", $instancetype);
    my $resource  =  $instancetype->{$metric};
    $self->logDebug("resource ($metric)", $resource);

    my $adjustedduration  =  $duration * $resource;
    
    my $term  =  $adjustedduration/$firstduration;
    $self->logDebug("term", $term);
    
    $terms    +=  $term;
  }
  $self->logDebug("FINAL terms", $terms);
  
  return $terms;  
}
method getInstanceCounts ($queues, $instancetypes, $resourcecounts) {

=head2  SUBROUTINE  getInstanceCounts

=head2  PURPOSE
  
  Given the CPU allocations (resourceallocations), allocate instances to each workflow

=head2  ALGORITHM


=cut

  my $metric  =  $self->metric();
  $self->logDebug("metric", $metric);

  my $instancecounts  =  [];
  my $resourcetotal  =  0;
  my $integertotal  =  0;
  for ( my $i = 0; $i < @$resourcecounts; $i++ ) {
    my $queuename  =  $self->getQueueName($$queues[$i]);
    my $resource  =  $instancetypes->{$queuename}->{$metric};
    my $resourcecount   =  $$resourcecounts[$i] / $resource;
    $self->logDebug("$queuename instance $resource CPUs resourcecount", $resourcecount);
    
    push @$instancecounts, 0 and next if not defined $$resourcecounts[$i];
    
    #### STASH RUNNING COUNT
    $resourcetotal    +=  $$resourcecounts[$i];

    $self->logDebug("");
    if ( $i == scalar(@$resourcecounts) - 1) {
      $self->logDebug("pushing to instancecounts int( ($resourcetotal - $integertotal) / $resource )", int( ($resourcetotal - $integertotal) / $resource ));

      my $instancecount  =  int( ($resourcetotal - $integertotal) / $resource );
      $self->logDebug("instancecount", $instancecount);
      if ( $instancecount <= 0 ) {
        $instancecount    =  0;
      }
      elsif ( $instancecount < 1 ) {
        $instancecount    =  1 ;
      }

      push @$instancecounts, $instancecount;
    }
    else {
      my $instancecount  =  floor($$resourcecounts[$i]/$resource);
      $self->logDebug("pushing to instancecounts floor($$resourcecounts[$i]/$resource)", $instancecount);
      $self->logDebug("instancecount", $instancecount);
      if ( $instancecount <= 0 ) {
        $instancecount    =  0;
      }
      elsif ( $instancecount < 1 ) {
        $instancecount    =  1 ;
      }

      #### STASH RUNNING INTEGER COUNT
      $integertotal  +=  $instancecount * $resource;

      push @$instancecounts, $instancecount;
    }
  }
  $self->logDebug("integertotal", $integertotal);
  $self->logDebug("instancecounts", $instancecounts);

  return $instancecounts;
}

method getQueueNames ($queues) {
  #$self->logDebug("queues", $queues);
  
  my $queuenames  =  [];
  for ( my $i = 0; $i < @$queues; $i++ ) {
    my $queue  =  $$queues[$i];
    #$self->logDebug("queue $i", $queue);
    my $queuename  =  $self->getQueueName($queue);
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

  my $quotas  =  $self->getQuotas($username);
  #$self->logNote("quotas", $quotas);

  my $quota  =  undef;
  if ( $metric eq "cpus" ) {
    ($quota)  =  $quotas  =~  /cores\s+\|\s+(\d+)/ms;
    $self->logNote("quota", $quota);
  }
  else {
    print "Balancer::getResourceQuota    Metric not supported: $metric\n" and exit;
  }

  return $quota;  
}

method getQuotas ($username) {
  $self->logNote("username", $username);
  
  my $quotas  =  $self->virtual()->getQuotas();
  #$self->logNote("quotas", $quotas);
  
  return $quotas;
}


#### INSTANCE TYPE
method getInstanceTypes ($queues) {
  
  $self->logDebug("queues", $queues);
  
  my $instancetypes  =  {};
  foreach my $queue ( @$queues ) {
    #$self->logDebug("queue", $queue);
    my $queuename  =  $self->getQueueName($queue);
    $self->logDebug("queuename", $queuename);
    
    my $instancetype  =  $self->getQueueInstance($queue);
    $instancetypes->{$queuename}  = $instancetype;
  }
  #$self->logDebug("instancetypes", $instancetypes);
  
  return $instancetypes;
}

method getQueueInstance ($queue) {
  $self->logDebug("queue", $queue);
  my $queuename  =  $self->getQueueName($queue);
  #$self->logDebug("queuename", $queuename);
  my $query  =  qq{SELECT * FROM instancetype
WHERE username='$queue->{username}'
AND cluster='$queuename'};
  $self->logDebug("query", $query);
  my $instancetype  =  $self->db()->queryhash($query);
  #$self->logDebug("instancetype", $instancetype);  
  
  return $instancetype;
}

method getThroughputs ($queues, $durations, $instancecounts) {
  $self->logDebug("queues", $queues);
  $self->logDebug("durations", $durations);
  $self->logDebug("instancecounts", $instancecounts);
  my $SECONDS  =  3600;
  my $throughputs  =  {};
  foreach my $queue ( @$queues ) {
    my $queuename  =  $self->getQueueName($queue);
    #$self->logDebug("queuename", $queuename);
    
    my $throughput  =  ($SECONDS/$durations->{$queuename}) * $instancecounts->{$queuename};
    $self->logDebug("throughput = ($SECONDS/$durations->{$queuename}) * $instancecounts->{$queuename}");
    $self->logDebug("throughput", $throughput);
    
    $throughputs->{$queuename}  =  $throughput;
  }
  
  return $throughputs;
}

method getQueueName ($queue) {
  $self->logCaller("queue", $queue);
  $self->logDebug("queue", $queue);
  
  my $fields  =  [ "username", "project", "workflow" ];
  foreach my $field ( @$fields ) {
    return if not defined $queue->{$field};
  }

  return $queue->{username} . "." . $queue->{project} . "." . $queue->{workflow};
}

}

