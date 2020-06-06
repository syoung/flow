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

class Siphon::Daemon with (Logger, Exchange, Agua::Common::Util, Agua::Common::Database, Agua::Common::Privileges) {

#####////}}}}}

# Integers
has 'log'			=>  ( isa => 'Int', is => 'rw', default => 2 );
has 'printlog'		=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'time'			=>  ( isa => 'Int', is => 'rw' );
has 'timeout'		=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'validated'		=> 	( isa => 'Int|Undef', is => 'rw', default => 0 );

# Strings
has 'logfile'		=> ( isa => 'Str|Undef', is => 'rw'	);
has 'sessionid'     => ( isa => 'Str|Undef', is => 'rw' );
has 'mode'     		=> ( isa => 'Str|Undef', is => 'rw' );

# Objects
has 'modules'		=> ( isa => 'HashRef|Undef', is => 'rw', lazy	=>	1, builder	=>	"setModules" );
has 'lastsent'		=> ( isa => 'HashRef|Undef', is => 'rw', required	=>	0 );
has 'conf'			=> ( isa => 'Conf::Yaml', is => 'rw', required	=>	0 );
has 'lastreceived'	=>  ( isa => 'HashRef|Undef', is => 'rw' );
has 'virtual'		=> ( isa => 'Virtual', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );
has 'db'		=> ( isa => 'Agua::DBase::MySQL', is => 'rw', lazy	=>	1,	builder	=>	"setDbh" );
has 'jsonparser'	=> ( isa => 'JSON', is => 'rw', lazy => 1, builder => "setParser" );
has 'receiveconnection'=> ( isa => 'Net::RabbitMQ', is => 'rw' );


use FindBin qw($Bin);
use Test::More;

use TryCatch;
use Data::Dumper;
use Acme::Damn;

#####////}}}}}

method BUILD ($args) {
	
	#### SET SLOTS
	$self->setSlots($args);

	#### INITIALISE
	$self->initialise($args);
}

method initialise ($args) {

	#### SET SLOTS
	$self->setSlots($args);

	#### SET LISTENER
	my $queuename = "chat";
	my $handler		=	"handleTask";
	$self->receiveTask($queuename, $handler);
}

method setModules {
	$self->logDebug("");
    my $modulestring = $self->conf()->getKey("agua", "MODULES");
    my @modulenames = split ",", $modulestring;
	$self->logDebug("modulestring", $modulestring);
	$self->logDebug("self->log()", $self->log());

    my $installdir = $self->conf()->getKey("agua", "INSTALLDIR");

	my $modules	=	{};
    foreach my $modulename ( @modulenames ) {
        my $modulepath = $modulename;
        $modulepath =~ s/::/\//g;
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
	$self->modules($modules);

    return $modules; 
}

method timedOut {
	$self->time(time) if not defined $self->time();
	my $time	=	$self->time();
	$self->logDebug("time", $time);
	my $currenttime	=	time;
	my $timeout	=	$self->timeout();
	$self->logDebug("timeout", $timeout);
	$self->logDebug("time", $time);
	$self->logDebug("currenttime", $currenttime);
	$self->logDebug("currenttime - time", $currenttime - $time);
	
	return 0 if $currenttime - $time < $timeout;
	
	#### TIMEOUT lastsent AND lastreceived
	$self->logDebug("Cancelling lastsent AND lastreceived");
	$self->lastsent({});
	$self->lastreceived({});
	
	return 1;
}

method handleTask ($json) {	
	$self->logDebug("json", substr($json, 0, 400));

    #### GET DATA
	my $data = undef;
	try {
		$data = $self->parseJson($json);
	}
	catch {
		$self->logDebug("FAILED parseJson. input is not JSON", $json);
	}
	return if not defined $data;

	#### VERIFY TYPE IS request
	my $sendtype	=	$data->{sendtype};
	#$self->logDebug("sendtype", $sendtype);
	return if not defined $sendtype;
	return if $sendtype ne "request";

	#### GET MODE
	my $mode	=	$data->{mode};
	$self->logDebug("mode", $mode);
    if ( not defined $mode ) {
		$data->{sendtype}	=	"response";
		$self->notifyError($data, "mode not defined");
		return;
	}
	elsif ( $mode eq "" ) {
		$data->{sendtype}	=	"response";
		$self->notifyError($data, "mode is empty");
		return;
	}

	if ( defined $self->lastsent() ) {
		#$self->logDebug("Checking for match with self->lastsent()");
		#$self->logDebug("data", $data);
		#$self->logDebug("self->lastsent()", $self->lastsent());

		return if Test::More::eq_hash($data, $self->lastsent());
    }
	$self->lastsent($data);

	if ( defined $data->{processid} and $data->{processid} eq $$ ) {
		$self->logDebug("processid matches self. Ignoring");
		return;
	}
	
    #### SET WHOAMI
    my $whoami = `whoami`;
    chomp($whoami);
    $data->{whoami} = $whoami;
    
	#### VALIDATE
	my $username 	=	$data->{username};
	my $sessionid 	=	$data->{sessionid};
	my $requestor 	=	$data->{requestor};
	$self->logDebug("username", $username);
	$self->logDebug("sessionid", $sessionid);
	$self->logDebug("requestor", $requestor);

	$self->mode($mode);
	$self->username($username);
	$self->sessionid($sessionid);
	$self->requestor($requestor);

	#### SKIP IF submitLogin
	$self->notifyError($data, "User session not validated for username: $username") and return unless $mode eq "submitLogin" or $self->validate();
	
    #### SET REQUIRED INPUTS
	no warnings;
    my $required = qw(whoami username mode module);
    use warnings;
	
    ##### CLEAN INPUTS
    #$self->cleanInputs($data, $required);
    #
    ##### CHECK INPUTS
    #$self->checkInputs($data, $required);

	#### SET object FROM MODULES
	my $modules	=	$self->modules();
	my $object	=   $self->getObject($modules, $data);
	#$self->logDebug("object", $object);
	$self->notifyError($data, "failed to create object") and return if not defined $object;

    #### VERIFY MODULE SUPPORTS MODE
    $self->notifyError($data, "mode not supported: $mode") and return if not $object->can($mode);
	#print "{ error: 'mode not supported: $mode' }" and return if not $object->can($mode);
    
	#### CHECK HOSTNAME
	if ( defined $data->{hostname} and $data->{hostname} ne "" ) {
		$self->logDebug("Checking hostname matches '$data->{hostname}'");
		my $hostname	=	$self->getHostname();
		if ( $hostname ne $data->{hostname} ) {
		    $self->notifyError($data, "data->{hostname} '$data->{hostname}' failed to match hostname '$hostname'");
			return;
		}
		
		$self->logDebug("hostname matches data->{hostname}: $hostname");
	}

	$self->logDebug("self->receiveconnection()", $self->receiveconnection());
	
    #### RUN REQUEST IN CHILD PROCESS
	my $pid	=	fork();
	if ( $pid ) {
		$self->logDebug("PARENT. child pid: $pid");
	}
	else {
		$self->logDebug("CHILD $$ BEFORE try");
		$self->logDebug("CHILD BEFORE damn", $self->receiveconnection());
		damn $self->receiveconnection();
		$self->logDebug("CHILD AFTER damn", $self->receiveconnection());
		
		try {
			no strict;
			$object->db($self->db());
			$object->$mode($data->{data});
			$self->logDebug("CHILD AFTER object->$mode");
			use strict;
		}
		catch ($error) {
			$self->notifyError($data, "CHILD failed to run mode '$mode': $error");
		}
		$self->logDebug("CHILD $$ AFTER try");
	}
	
	$self->logDebug("END");
}

method parseJson ($json) {
	#$self->logDebug("json", $json);
    
    use JSON;
    my $jsonParser = JSON->new();
    my $data;
    try {
        $data = $jsonParser->allow_nonref->decode($json);    
		#print "Daemon::parseJson    data:\n";
		#print Dumper $data;
		
        return $data;
    }
    catch {
		$self->logDebug("Message is not JSON: $json. Ignoring");
        print "Message is not JSON: $json. Ignoring\n";
		return undef;
    } 
}

method cleanInputs ($data, $keys) {
	$self->logDebug("data", $data);
	$self->logDebug("keys", $keys);
    $self->logDebug('{"error":"JSON not defined"}') and return if not defined $data;

    foreach my $key ( @$keys ) {
        $data->{$key} =~ s/;`//g;
        $data->{$key} =~ s/eval//g;
        $data->{$key} =~ s/system//g;
        $data->{$key} =~ s/exec//g;
    }
}

method checkInputs ($json, $keys) {
    print "{ 'error' : 'agua.pl	JSON not defined' }" and return if not defined $json;

    foreach my $key ( @$keys ) {
        print "{ 'error' : 'agua.pl	JSON not defined' }" and return if not defined $json->{$key};
    }
}

method getHostname {

	#### GET OPENSTACK HOST NAME
	#### E.G., split.v2-5.hd800-real-de2e4a8b-7034-4525-ab3e-33fc993797f8.novalocal
	my $hostname	=	$self->virtual()->getMetaData("hostname");
	$hostname		=~	s/\.novalocal\s*$//;
	$self->logDebug("hostname", $hostname);
	
	#### OTHERWISE, GET LOCAL HOSTNAME
	if ( $hostname eq "" ) {
		$hostname	=	`hostname`;
		$hostname	=~	s/\s+$//g;
	}

	return $hostname;	
}

method getInternalIp {
	return	$self->virtual()->getMetaData("local-ipv4");
}

method getExternalIp {
	return	$self->virtual()->getMetaData("public-ipv4");
}

method updateIps {
	my $internalip	=	$self->getInternalIp();
	my $externalip	=	$self->getExternalIp();

	$self->conf()->setKey("queue:selfinternalip", $internalip);
	$self->conf()->setKey("queue:selfexternalip", $externalip);
}

method getObject ($modules, $data) {

	#$self->logDebug("modules", $modules);
	#$self->logDebug("data", $data);

	#try {

		#### GET MODE
		my $mode = $data->{mode};
		print "mode: $mode\n";
		return if not defined $mode;
		
		#### GET USERNAME
		my $username = $data->{username};
		print "{ error: 'username not defined' }" and return if not defined $username;
	
		#### GET MODULE
		my $module = $data->{module};
		print "module: $module\n";
		
		##### SET LOGFILE
		#my $logfile;
		#$logfile	=	$self->logfile() if $self->can('logfile');
		#if ( not defined $logfile or $logfile eq "" ) {
		#	$self->logDebug("DOING self->setLogfile()");
		#	$logfile     =   $self->setLogFile($username, $module);
		#	$self->conf()->logfile($logfile) if defined $self->conf() and $self->conf()->can('logfile');
		#}

		#### GET OBJECT
		my $object = $modules->{$module};
		if ( not defined $object ) {
			$data->{error}	=	"module $module not supported or failed to run mode: $mode";
			$self->sendSocket($data);
			return;
		}
		
		#### SET OBJECT LOGFILE AND INITIALISE
		#$self->logDebug("object", $object);
		#$object->logfile($logfile) if $self->can('logfile');
		$self->logDebug("Doing object->initialise");
		$object->initialise($data);
	
		return $object;
	#}
	#catch {
	#	return;
	#}
}

method setLogFile ($username, $module) {
	#### SET LOGFILE
	my $logfile =   "$Bin/../../log/$username.$module.log";
	$logfile	=~ 	s/::/-/g;
	
	return $logfile;
}



method setVirtual {
	my $type	=	$self->virtualtype();
	$self->logDebug("type", $type);

	#### RETURN IF TYPE NOT SUPPORTED	
	$self->logDebug("virtual type not supported: $type") and return if $type !~	/^(openstack|vagrant)$/;

   #### CREATE DB OBJECT USING DBASE FACTORY
    my $virtual = Virtual->new( $type,
        {
			conf		=>	$self->conf(),
            username	=>  $self->username(),
			
			logfile		=>	$self->logfile(),
			log			=>	2,
			printlog	=>	2
        }
    ) or die "Can't create virtual of type: $type. $!\n";
	$self->logDebug("virtual", $virtual);
	$self->virtual($virtual);
}



method setParser {
	return JSON->new->allow_nonref;
}

}


#method receiveFanout {
#	$self->logDebug("");
#    $|++;
#    
#    my $exchange	=	"chat";
#	my $channelid	=	1;
#	my $host		=	$self->host() || $self->conf()->getKey("queue:host", undef);
#	$self->logDebug("host", $host);
#
#	#### 1. CONNECTION
#	my $connection      = $self->newConnection();
#	$self->receiveconnection($connection);
#	#my $connection      = Net::RabbitMQ->new() ;
#	#my $channelid  = 1;
#	#my %qparms = (
#	#	user 		=> "guest",
#	#	password 	=> "guest",
#	#	host    	=>  $host,
#	#	vhost   	=>  "/",
#	#	port   		=>  5672
#	#);
#	#$self->logDebug("DOING connection->connect()");
#	#$connection->connect($host, \%qparms);
#	#
#	#### 2. CHANNEL
#	$self->logDebug("DOING connection->channel_open()");
#	$connection->channel_open($channelid);
#	
#	$self->logDebug("DOING connection->basic_qos()");
#	$connection->basic_qos($channelid,{ prefetch_count => 1 });
#	
#	#### 3. EXCHANGE
#	# NB: DEFAULTS
#	# exchange_type 	=> $type,  		# default 'direct'
#	# passive 			=> $boolean,    # default 0
#	# durable 			=> $boolean,    # default 0
#	# auto_delete 		=> $boolean,  	# default 1
#	my $options = {
#		exchange_type=>	"fanout",
#		autodelete	=> 	0,
#		auto_delete	=> 	0,
#		durable 	=> 	0
#	};
#	$self->logDebug("DOING exchange_declare($channelid, $exchange, options)");
#	$connection->exchange_declare($channelid, $exchange, $options);
#	
#	#### 4. QUEUE
#	my %queue_opts = (
#		durable => 1,
#		auto_delete => 0
#	);
#	$self->logDebug("DOING connection->queue_declare()");
#	$connection->queue_declare($channelid, $exchange, \%queue_opts) ;
#	$self->logDebug("DOING connection->queue_bind()");
#	$connection->queue_bind($channelid, $exchange, "chat", "",);
#
#	#### 5. CONSUME
#	my %consume_opts = (
#		exchange => "chat",
#		routing_key =>  ""
#	);
#	$connection->consume($channelid, $exchange, \%consume_opts);
#	$self->logDebug("connection", $connection);
#	
#	# NOTE: recv() is BLOCKING
#	while ( my $payload = $connection->recv() ) {
#		$self->logDebug("payload", $payload);
#		#$self->logDebug("payload", substr($payload, 0, 400));
#		next if not defined $payload;
#		my $body  = $payload->{body};
#		#$self->logDebug("received body", substr($body, 0, 100));
#		my $dtag  = $payload->{delivery_tag} ;
#
#		print "{[x] Received from queue $exchange: ", substr($body, 0, 400), "\n";
#		$self->handleFanout($body);
#		
#		#$connection->ack($channelid,$dtag,);
#	}
#}
#

