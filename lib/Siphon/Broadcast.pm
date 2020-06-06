use MooseX::Declare;

=head2

PURPOSE

	- Use direct queue to communicate with nodes
	
	- Order workers to:
		
		- DEPLOY APPS
		
		- PROVIDE WORKFLOW STATUS
		
		- STOP/START WORKFLOWS

=cut

use strict;
use warnings;

class Siphon::Broadcast with (Logger, Exchange, Agua::Common::Database) {

use Agua::DBase::MySQL;
use Conf::Yaml;

#####////}}}}}

# Integers
has 'log'	=>  ( isa => 'Int', is => 'rw', default => 4 );
has 'printlog'	=>  ( isa => 'Int', is => 'rw', default => 5 );
has 'sleep'		=>  ( isa => 'Int', is => 'rw', default => 300 );

# Strings
has 'database'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'user'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'pass'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'host'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'vhost'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'arch'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );

# Objects
has 'conf'		=> ( isa => 'Conf::Yaml', is => 'rw', required	=>	0 );
has 'jsonparser'=> ( isa => 'JSON', is => 'rw', lazy	=>	1, builder	=>	"setParser" );
has 'db'		=> ( isa => 'Agua::DBase::MySQL|Undef', is => 'rw', required	=>	0 );
has 'channel'	=> ( isa => 'Any', is => 'rw', required	=>	0 );
has 'virtual'	=> ( isa => 'Any', is => 'rw', lazy	=>	1, builder	=>	"setVirtual" );

use Getopt::Long;
Getopt::Long::Configure(qw(no_ignore_case bundling pass_through));

#####////}}}}}

method BUILD ($args) {
	$self->initialise($args);	
}

method initialise ($args) {
	# $self->logDebug("args", $args);	
}

method run ($args) {
	if ( scalar(@$args) < 2 ) {
		print "Two arguments required: $0 subcommand secondary\n";
		usage();
		exit;
	}

	my $subcommands   =   [ 
	    "project",
	    "system",
	    "service",
	];

	my $subcommand 	= 	shift @$args;
	print "subcommand: $subcommand\n";
	if ( not exists { map { $_ => 1 } @$subcommands	 }->{$subcommand} ) {
		print "Subcommand does not meet required format\n";
		print "Should be one of the following: @$subcommands\n";
		$self->usage();
	}

	$self->$subcommand($args);
}

method usage {
	print `/usr/bin/env perldoc $0`;
	exit;
}

method project ($args) {
	print "Broadcast::project    args: @$args\n";
	my $secondary = shift @$args;
	$self->logDebug("secondary", $secondary);

	#### VARIABLE
	my $log     	=   2;
	my $printlog    =   4;
	my $help        =   undef;

	my $username 	= 	undef;
	my $project 	= 	undef;
	my $workflow 	= 	undef;
	my $confdir		=	undef;
	my $hostips 	= 	[];

	$self->logDebug("FINAL args", $args);

    {
        local @ARGV = @$args;
        Getopt::Long::Configure(qw(no_ignore_case bundling pass_through));
		GetOptions(
            'log=i'  		=> \$self->{log},
            'printlog=i'  	=> \$self->{printlog},
            'logfile=s'  	=> \$self->{logfile},

            'username=s'   	=> \$username,
            'project=s'   	=> \$project,
            'workflow=s'   	=> \$workflow,
            'confdir=s'   	=> \$confdir,
            'hostip=s@'    	=> $hostips,
		     'help'         => \$help
        ) or croak('Failed to parse with GetOptions. Unable to continue');
    }
    $self->logDebug("username", $username);
    $self->logDebug("project", $project);
    $self->logDebug("workflow", $workflow);
    $self->logDebug("confdir", $confdir);
    $self->logDebug("hostips", $hostips);

    #### SET CONFIG
    $self->setConf();

    my $data = {
		mode 		=>	"project",
		subcommand 	=>	$secondary,
		username 	=> 	$username,
		project 	=> 	$project,
		workflow 	=> 	$workflow,
		confdir 	=> 	$confdir,
		hostip 		=>	$self->getHostname(),
		hostips		=>	$hostips
    };
    $self->logDebug("data", $data);

    $self->sendFanout("direct_logs", $data);
    $self->logDebug("END");
}

method system ($args) {
	$self->logDebug("args", $args);
	my $commands = [];
	my $hostips = [];

    {
        local @ARGV = @$args;

        #### NB: Don't add coderefs to GetOptions
        GetOptions(
            'log=i'  		=> \$self->{log},
            'printlog=i'  	=> \$self->{printlog},
            'logfile=s'  	=> \$self->{logfile},
            'command=s@'   	=> $commands,
            'hostip=s@'    	=> $hostips,
        ) or croak('Failed to parse with GetOptions. Unable to continue');
    }

    $self->logDebug("commands", $commands);
    $self->logDebug("hostips", $hostips);

    #### SET CONFIG
    $self->setConf();

    my $data = {
		mode 		=>	"system",
		hostip 		=>	$self->getHostname(),
		commands 	=> 	$commands,
		hostips		=>	$hostips
    };

    $self->sendFanout("direct_logs", $data);
    $self->logDebug("END");
}

method service ($args) {
	print "Broadcast::service    args: ", @$args, "\n";
	my $secondary = shift @$args;
	$self->logDebug("secondary", $secondary);

	#### VARIABLE
	my $log     	=   2;
	my $printlog    =   4;
	my $help        =   undef;
	my $service 	= 	"";
	my $hostips 	= 	[];

	$self->logDebug("FINAL args", $args);

    {
        local @ARGV = @$args;
        Getopt::Long::Configure(qw(no_ignore_case bundling pass_through));
		GetOptions(
            'log=i'  		=> \$self->{log},
            'printlog=i'  	=> \$self->{printlog},
            'logfile=s'  	=> \$self->{logfile},
            'service=s'   	=> \$service,
            'hostip=s@'    	=> $hostips,
		     'help'         => \$help
        ) or croak('Failed to parse with GetOptions. Unable to continue');
    }
    $self->logDebug("service", $service);
    $self->logDebug("hostips", $hostips);

    #### SET CONFIG
    $self->setConf();

    my $data = {
		mode 		=>	"service",
		service 	=> 	$service,
		subcommand 	=>	$secondary,
		hostip 		=>	$self->getHostname(),
		hostips		=>	$hostips
    };
    $self->logDebug("data", $data);

    $self->sendFanout("direct_logs", $data);
    $self->logDebug("END");
}

method setConf {
	my $installdir 	= 	$ENV{'installdir'} || "/a";
	my $logfile     =   "$installdir/log/broadcast.log";
	my $configfile	=	"$installdir/conf/config.yaml";
	my $conf = Conf::Yaml->new(
	    inputfile	=>	$configfile,
	    backup		=>	1,
	    log     	=>  2,
	    printlog    =>  4,
		logfile		=>	$logfile
	);
	$self->conf($conf);
}


} #### END



