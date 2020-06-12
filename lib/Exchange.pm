package Exchange;
use Moose::Role;
use Method::Signatures::Simple;

use JSON;
use Data::Dumper;
use AnyEvent;
use Coro;
use Net::RabbitMQ;
use TryCatch;

#### Strings
has 'apiroot'	=>	( isa => 'Str', is => 'rw', default => " http://localhost:55672/api/vhosts");
has 'sendtype'	=> 	( isa => 'Str|Undef', is => 'rw', default => "response" );
has 'sourceid'	=>	( isa => 'Undef|Str', is => 'rw', default => "" );
has 'callback'	=>	( isa => 'Undef|Str', is => 'rw', default => "" );
has 'queue'		=>	( isa => 'Undef|Str', is => 'rw', default => undef );
has 'token'		=> ( isa => 'Str|Undef', is => 'rw' );
has 'user'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'pass'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'host'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'vhost'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'port'		=> ( isa => 'Str|Undef', is => 'rw', default	=>	5672 );
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 2 );

#### Objects
#has 'connection'=> ( isa => 'Net::RabbitFoot', is => 'rw', lazy	=> 1, builder => "openConnection" );
has 'connection'=> ( isa => 'Net::RabbitMQ', is => 'rw', lazy	=> 1, builder => "getConnection" );
has 'storedconnection'=> ( isa => 'Net::RabbitMQ', is => 'rw' );
has 'receiveconnection'=> ( isa => 'Net::RabbitMQ', is => 'rw' );
#has 'channel'	=> ( isa => 'Net::RabbitFoot::Channel', is => 'rw', lazy	=> 1, builder => "openConnection" );
has 'parser'=> ( isa => 'JSON', is => 'rw', lazy	=>	1, default	=>	sub {
	return JSON->new->allow_nonref; } );

#### NOTIFY
method notifyStatus ($data, $status) {
	$self->logDebug("status", $status);
	#$self->logDebug("data", $data);

	$data->{status}	=	$status;
	$self->notify($data);
}

method notifyError ($data, $error) {
	$self->logDebug("error", $error);
	$data->{error}	=	$error;
	
	$self->notify($data);
}

method notify ($data) {
	my $hash		=	{};
	$hash->{data}	=	$data;
	$hash			=	$self->addIdentifiers($hash);
	#$self->logDebug("hash", $hash);
	
	my $parser		=	$self->parser();
	my $message		=	$parser->encode($hash);

	$self->sendFanout('chat', $message);
}

#### FANOUT
method sendFanout ($exchange, $data) {
	$self->logDebug("exchange", $exchange);
	# $self->logDebug("data", $data);
	
	my $host	=	$self->host() || $self->conf()->getKey( "mq:host", undef) || "localhost";
	my $port	=	$self->port() || $self->conf()->getKey( "mq:port", undef) || 5672;
	my $user	= 	$self->user() || $self->conf()->getKey( "mq:user", undef) || "guest";
	my $pass	=	$self->pass() || $self->conf()->getKey( "mq:pass", undef) || "guest";
	my $vhost	=	$self->vhost() || $self->conf()->getKey( "mq:vhost", undef) || "/";

	my $parser 		= 	$self->parser();
	my $json 		=	$parser->encode($data);
	$self->logDebug("json ", $json );

	try {
		my $channelid = 1;
		# my $queuename = 'direct_logs';
		my $exchangetype = 'direct';
		my $routingkey  = "broadcast";
		
		my $connection = Net::RabbitMQ->new() ;

		my %qparms = (
			user 		=> 	$user,
			password 	=> 	$pass,
			host    	=>  $host,
			vhost   	=>  $vhost,
			port   		=>  $port
		);
		$self->logDebug("qparms", \%qparms);
		$connection->connect($host, \%qparms);

		$connection->channel_open($channelid);

		$connection->exchange_declare(
			$channelid, 
			$exchange, 
			{
				exchange 		=> 	$exchange, 
				exchange_type 	=> 	$exchangetype, 
				auto_delete		=> 	1,	
				durable 		=>	0
			}
		);

		$connection->publish(
			$channelid, 
			$routingkey, 
			$json, 
			{ 
				exchange => $exchange 
			}
		);

		print " [x] Sent fanout with routing key '$routingkey': $json\n";

		$connection->disconnect;
	}
	catch {
		$self->logDebug("Failed to connect");
	}
}

method receiveFanout ($exchangename, $handler) {
	$self->logDebug("exchangename", $exchangename);
	$self->logDebug("handler", $handler);
    $|++;

	my $host	=	$self->host() || $self->conf()->getKey( "mq:host", undef) || "localhost";
	my $port	=	$self->port() || $self->conf()->getKey( "mq:port", undef) || 5672;
	my $user	= 	$self->user() || $self->conf()->getKey( "mq:user", undef) || "guest";
	my $pass	=	$self->pass() || $self->conf()->getKey( "mq:pass", undef) || "guest";
	my $vhost	=	$self->vhost() || $self->conf()->getKey( "mq:vhost", undef) || "/";
	my $routingkey = 	$self->conf()->getKey( "mq:broadcast", undef) || "broadcast";
	$self->logDebug("routingkey", $routingkey);

	my $connection      = Net::RabbitMQ->new();
	my $channelid = 1;

	# my %qparms = ();
	my %qparms = (
		user 		=> 	$user,
		password 	=> 	$pass,
		host    	=>  $host,
		vhost   	=>  $vhost,
		port   		=>  $port
	);
	$self->logDebug("qparms", \%qparms);
	$connection->connect($host, \%qparms);
	$connection->channel_open($channelid);

	my $queuename = $connection->queue_declare(
		$channelid, 
		'', 
		{ 
			exclusive => 1 
		}
	);
	$self->logDebug("queuename", $queuename);

	$connection->queue_bind($channelid, $queuename, $exchangename, $routingkey);
	print STDERR qq{Bound to queue $queuename for routingkey $routingkey\n};

	my $hostname = $self->getHostname();
	$connection->consume($channelid, $queuename, {
		consumer_tag => $hostname, 
		no_ack => 0, 
		exclusive => 0,
	});

	#### NB: recv() is BLOCKING
	while ( my $payload = $connection->recv() )
	{
	    last if not defined $payload;
	    my $body  = $payload->{body};
	    my $dtag  = $payload->{delivery_tag};

		print "[x] Received from queue $queuename: ", substr($body, 0, 1000) , "\n";

		$self->$handler($body);

	    $connection->ack($channelid,$dtag,);
	}
}

method exchangeExists ($exchangename) {
	my $apiroot = $self->apiroot();
}

#### SEND SOCKET
method sendSocket ($data) {	
	$self->logDebug("");
	$self->logDebug("data", $data);

	#### BUILD RESPONSE
	$data->{username}	=	$self->username();
	$data->{sourceid}	=	$self->sourceid();
	$data->{callback}	=	$self->callback();
	$data->{token}		=	$self->token();
	$data->{sendtype}	=	"data";

	$self->sendData($data);
}

method sendData ($data) {
	#### CONNECTION
	my $connection		=	$self->newSocketConnection($data);
	my $channel 		=	$connection->open_channel();
	my $exchange		=	$self->conf()->getKey( "mq:exchange", undef);
	my $exchangetype	=	$self->conf()->getKey( "mq:exchangetype", undef);
	#$self->logDebug("$$    exchange", $exchange);
	#$self->logDebug("$$    exchangetype", $exchangetype);

	$channel->declare_exchange(
		exchange 	=> 	$exchange,
		type 		=> 	$exchangetype,
	);

	my $parser 	= 	$self->parser();;
	my $json 		=	$parser->encode($data);
	$self->logDebug("$$    json", substr($json, 0, 1500));
	
	$channel->publish(
		exchange => $exchange,
		routing_key => '',
		body => $json,
	);

	my $host = $data->{host} || $self->conf()->getKey( "mq:host", undef);
	print "[*]   $$   [$host|$exchange|$exchangetype] Sent message: ", substr($json, 0, 1500), "\n";
	
	$connection->close();
}

method receiveSocket ($data) {

	$data 	=	{}	if not defined $data;
	$self->logDebug("data", $data);

	my $connection	=	$self->newSocketConnection($data);
	$self->logDebug("connection", $connection);
	
	my $channel = $connection->open_channel();
	
	#### GET EXCHANGE INFO
	my $exchange		=	$self->conf()->getKey( "mq:exchange", undef);
	my $exchangetype	=	$self->conf()->getKey( "mq:exchangetype", undef);
	$self->logDebug("exchange", $exchange);
	$self->logDebug("exchangetype", $exchangetype);

	$channel->declare_exchange(
		exchange 	=> 	$exchange,
		type 		=> 	$exchangetype,
	);
	$self->logDebug("AFTER");
	
	my $result = $channel->declare_queue( exclusive => 1, );	
	my $queuename = $result->{method_frame}->{queue};
	
	$channel->bind_queue(
		exchange 	=> 	$exchange,
		queue 		=> 	$queuename,
	);

	#### REPORT	
	my $host = $data->{host} || $self->conf()->getKey("socket:host", undef);
	$self->logDebug(" [*] [$host|$exchange|$exchangetype|$queuename] Waiting for RabbitJs socket traffic");
	print " [*] [$host|$exchange|$exchangetype|$queuename] Waiting for RabbitJs socket traffic\n";
	
	sub callsub {
		my $var = shift;
		my $body = $var->{body}->{payload};
	
		print " [x] Received message: ", substr($body, 0, 500), "\n";
	}
	
	$channel->consume(
		on_consume 	=> 	\&callsub,
		queue 		=> 	$queuename,
		no_ack 		=> 	1
	);
	
	AnyEvent->condvar->recv;
}

method addIdentifiers ($data) {
	#$self->logDebug("data", $data);
	#$self->logDebug("self: $self");
	
	#### SET TOKEN
	$data->{token}		=	$self->token();
	
	#### SET SENDTYPE
	$data->{sendtype}	=	$self->sendtype();
	
	#### SET DATABASE
	$self->setDbh() if not defined $self->db();
	$data->{database} 	= 	$self->db()->database() || "";

	#### SET USERNAME		
	$data->{username} 	= 	$self->username();

	#### SET SOURCE ID
	$data->{sourceid} 	= 	$self->sourceid();
	
	#### SET CALLBACK
	$data->{callback} 	= 	$self->callback();
	
	# $self->logDebug("Returning data", $data);

	return $data;
}


##### CONNECTION
method getConnection {
	$self->logDebug("self->storedconnection()", $self->storedconnection());

	return $self->storedconnection() if defined $self->storedconnection();

	my $connection = $self->newConnection();	
	my $channelid = 1;
	my $channel = $connection->channel_open($channelid);
	#$self->logDebug("BEFORE channel", $channel);

	#### GET EXCHANGE INFO
	my $exchange		=	$self->conf()->getKey( "mq:exchange", undef);
	my $exchangetype	=	$self->conf()->getKey( "mq:exchangetype", undef);

	$exchangetype = "fanout";
	$self->logDebug("exchange", $exchange);
	$self->logDebug("exchangetype", $exchangetype);

	#### SET DEFAULT CHANNEL
	#$self->setChannel($exchange, $exchangetype);	
	#$self->channel()->declare_exchange(
	#	exchange => $name,
	#	type => $type,
	#);
	#
	#$channel->declare_exchange(
	#	exchange => 'chat',
	#	type => 'fanout',
	#);

	try {
		$connection->exchange_declare(
			$channelid,
			'chat',
			{
				exchange_type 	=> 	'fanout',
				passive			=> 	0,
				#durable 		=>	1,
				durable 		=>	0,
				auto_delete 	=> 	0
			}
		);
	}
	catch {
		$self->logDebug("Failed to declare exchange $exchange. It's probably already declared");
	}
	
	#### DECLARE QUEUE
	my %declare_opts = (
		durable => 1,
		auto_delete => 0
	);
	
	$self->logDebug("DOING connection->queue_declare($channelid, $exchange, declare_opts", \%declare_opts);
	$connection->queue_declare($channelid, $exchange, \%declare_opts,);

	$self->storedconnection($connection);

	return $connection;	
}

method newConnection {
	my $host		=	$self->host() ? $self->host() : $self->conf()->getKey( "mq:host" );
	my $user		= 	$self->user() ? $self->user() : $self->conf()->getKey( "mq:user" );
	my $password	=	$self->pass() ? $self->pass() : $self->conf()->getKey( "mq:pass" );
	my $vhost		=	$self->vhost() ? $self->vhost() : $self->conf()->getKey( "mq:vhost" );
	
	$self->logDebug("host", $host);
	$self->logDebug("user", $user);
	$self->logDebug("password", $password);
	$self->logDebug("vhost", $vhost);
	
	$self->logDebug("DOING Net::RabbitMQ->new()");
	my $connection  = Net::RabbitMQ->new();
	$self->logDebug("connection", $connection);

	$connection->connect(
		$host,
		{
			port 				=>	5672,
			host				=>	$host,
			user 				=>	$user,
			password 		=>	$password,
			vhost				=>	$vhost,
			channel_max => 2047
		}
	);
	$self->logDebug("connection", $connection);

	return $connection;	
}

#### TASK
method sendTask ($queuename, $data) {
	$self->logDebug("queuename", $queuename);
	$self->logDebug("data", $data);

    $|++;

	my $host		=	$self->host() ? $self->host() : $self->conf()->getKey( "mq:host" );
	my $user		= 	$self->user() ? $self->user() : $self->conf()->getKey( "mq:user" );
	my $password	=	$self->pass() ? $self->pass() : $self->conf()->getKey( "mq:pass" );
	my $vhost		=	$self->vhost() ? $self->vhost() : $self->conf()->getKey( "mq:vhost" );

	$self->logDebug("host", $host);
	$self->logDebug("user", $user);
	$self->logDebug("password", $password);
	$self->logDebug("vhost", $vhost);
	
	$self->logDebug("BEFORE Net::RabbitMQ->new()");
	my $connection  = Net::RabbitMQ->new();
	$self->logDebug("AFTER Net::RabbitMQ->new()");
	$self->logDebug("connection", $connection);

	$connection->connect(
		$host,
		{
			port 		=>	5672,
			host		=>	$host,
			user 		=>	$user,
			password 	=>	$password,
			vhost		=>	$vhost
		}
	);
	$self->logDebug("connection", $connection);

	my $channelid = 1;
	$self->logDebug("BEFORE channel");
	my $channel = $connection->channel_open($channelid);
	$self->logDebug("AFTER channel", $channel);

	$connection->queue_declare(
		$channelid,
		$queuename,
		{
			durable => 1,
			auto_delete => 0
		}
	);
	
	my $parser 	= 	JSON->new->allow_nonref;
	my $json 	=	$parser->encode($data);
	$self->logDebug("json", $json);
	# my $message		=	encode_json($data);
	# $self->logDebug("message", $message);

	$connection->publish(
		$channelid,
		$queuename,
		$json,
		{
			exchange => ""
		}
	);

    print "Message sent to queue $queuename: $json\n";

	$connection->disconnect();
}

method receiveTask ($queuename, $handler) {
	
	$self->logDebug("queuename", $queuename);
	$self->logDebug("handler", $handler);

	#### NB: (RECEIVER) QUEUENAME = ROUTING_KEY (SENDER)

	my $host		=	$self->host() ? $self->host() : $self->conf()->getKey( "mq:host", undef);
	my $user		= 	$self->user() ? $self->user() : $self->conf()->getKey( "mq:user", undef);
	my $password	=	$self->pass() ? $self->pass() : $self->conf()->getKey( "mq:pass", undef);
	my $vhost		=	$self->vhost() ? $self->vhost() : $self->conf()->getKey( "mq:vhost", undef);
	
	# $host = "localhost";

	$self->logDebug("host", $host);
	$self->logDebug("user", $user);
	$self->logDebug("password", $password);
	$self->logDebug("vhost", $vhost);
	
	
	#### CONNECTION
	$self->logDebug("BEFORE Net::RabbitMQ->new()");
	my $connection  = Net::RabbitMQ->new();
	$self->logDebug("AFTER Net::RabbitMQ->new()");
	$self->logDebug("connection", $connection);

	$connection->connect(
		$host,
	 	# {}
		{
			port 		=>	5672,
			host		=>	$host,
			user 		=>	$user,
			password 	=>	$password,
			vhost		=>	$vhost
		}
	);

	my $channelid = 1;
	my $channel = $connection->channel_open($channelid);
	$self->logDebug("channel", $channel);

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
	$connection->consume(
		$channelid,
		$queuename,
		{
			# exchange 	=> 	"chat",
			no_ack 		=> 	0
			#exchange => "chat",
			#routing_key =>  ""
		}
	) ;

	#### NB: recv() is BLOCKING
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

	$connection->disconnect();
}

method startRabbitJs {
	my $command		=	"service rabbitjs restart";
	$self->logDebug("command", $command);
	
	return `$command`;
}

method stopRabbitJs {
	my $command		=	"service rabbitjs stop";
	$self->logDebug("command", $command);
	
	return `$command`;
}


method setChannel($name, $type) {
	$self->channel()->declare_exchange(
		exchange => $name,
		type => $type,
	);
}

method closeConnection {
	$self->logDebug("self->connection()", $self->connection());
	$self->connection()->close();
}

method getArch {
	my $arch = $self->arch();
	return $arch if defined $arch;
	
	$arch 	= 	"linux";
	my $command = "uname -a";
    my $output = `$command`;
	#$self->logDebug("output", $output);
	
    #### Linux ip-10-126-30-178 2.6.32-305-ec2 #9-Ubuntu SMP Thu Apr 15 08:05:38 UTC 2010 x86_64 GNU/Linux
    $arch	=	 "ubuntu" if $output =~ /ubuntu/i;
    #### Linux ip-10-127-158-202 2.6.21.7-2.fc8xen #1 SMP Fri Feb 15 12:34:28 EST 2008 x86_64 x86_64 x86_64 GNU/Linux
    $arch	=	 "centos" if $output =~ /fc\d+/;
    $arch	=	 "centos" if $output =~ /\.el\d+\./;
	$arch	=	 "debian" if $output =~ /debian/i;
	$arch	=	 "freebsd" if $output =~ /freebsd/i;
	$arch	=	 "osx" if $output =~ /darwin/i;

	$self->arch($arch);
    $self->logDebug("FINAL arch", $arch);
	
	return $arch;
}

method getIpAddress {
	my $ipaddress	=	`facter ipaddress`;
	$ipaddress		=~ 	s/\s+$//;
	$self->logDebug("ipaddress", $ipaddress);
	
	return $ipaddress;
}

method getHostname {
	my $facter		=	`which facter`;
	$facter			=~	s/\s+$//;
	my $hostname	=	`$facter hostname`;
	$hostname		=~	s/\s+$//g;
	$hostname 		=~ 	s/\+//g;
	$hostname		=	uc(substr($hostname, 0, 1)) . substr($hostname, 1);
	$self->logDebug("hostname", $hostname);
	
	return $hostname;
}

method printFile ($file, $text) {
	$self->logNote("file", $file);
	$self->logNote("substr text", substr($text, 0, 100));

    open(FILE, ">$file") or die "Can't open file: $file\n";
    print FILE $text;    
    close(FILE) or die "Can't close file: $file\n";
}

method runCommand ($data) {
	my $commands	=	$data->{commands};
	foreach my $command ( @$commands ) {
		print `$command`;
	}
}



1;
