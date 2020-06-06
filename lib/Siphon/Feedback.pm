use MooseX::Declare;

=head2

PURPOSE

	Store output on Workers of actions sent by Broadcast  

=cut

use strict;
use warnings;

class Siphon::Feedback with (Logger, Exchange, Agua::Common::Database, Agua::Common::Timer) {

use Agua::DBase::MySQL;

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

#####////}}}}}

method BUILD ($args) {
	$self->initialise($args);	
}

method initialise ($args) {
	# $self->logDebug("args", $args);	
}

method runCommand ($args) {
	print "runCommand    args: @$args\n";
	my $commands = [];
	my $hostips = [];

    {
        local @ARGV = @$args;
        Getopt::Long::Configure(qw(no_ignore_case bundling pass_through));

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

    my $data = {
		mode 	=>	"runCommand",
		commands 	=> $commands,
		hostips		=>	$hostips
    };

    $self->sendFanout("direct_logs", $data);
    $self->logDebug("END");
}

#### LISTEN
method listen ($args) {
	$self->logDebug("args", $args);
	
	my $queuename = "feedback";
	my $handler = *Siphon::Feedback::handleTask;
	$self->receiveTask($queuename, $handler);
}

method handleTask ($json) {
	$self->logDebug("json", substr($json, 0, 200));

	my $data = $self->jsonparser()->decode($json);
	$self->logDebug("data", $data);

	my $mode =	$data->{mode} || "";
	$self->logDebug("mode", $mode);
	
	if ( $self->can($mode) ) {
		$self->$mode($data);
	}
	else {
		print "mode not supported: $mode\n";
		$self->logDebug("mode not supported: $mode");
	}
}

method handleFeedback ($data) {
	$self->logDebug("data", $data);

	$self->saveFeedback($data);
}


method saveFeedback ($data) {
	$self->logDebug("data", $data);
	my $table = "feedback";
	my $hash = $data;
	$hash->{mode} = $data->{mode};
	$hash->{hostips} = $self->jsonparser()->encode($data->{hostips});
	$hash->{outputs} = $self->jsonparser()->encode($data->{outputs});
	$self->logDebug("hash", $hash);

	#### DO ADD
	$self->logDebug("BEFORE self->setDbh");
	$self->setDbh();
	$self->logDebug("AFTER self->setDbh");

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $required = ["mode", "outputs"];
	my $not_defined = $self->db()->notDefined($data, $required);
    if ( @$not_defined ) {
    	$self->logDebug("not defined: @$not_defined");
    	return;
    }

    $self->logDebug("BEFORE addToTable");
	$self->_addToTable($table, $hash, $required);
    $self->logDebug("AFTER addToTable");

	$self->logDebug("COMPLETED");
}


#### UTILS

method notDefined ($hash, $fields) {
	return [] if not defined $hash or not defined $fields or not @$fields;
	
	my $notDefined = [];
    for ( my $i = 0; $i < @$fields; $i++ ) {
        push( @$notDefined, $$fields[$i]) if not defined $$hash{$$fields[$i]};
    }

    return $notDefined;
}

method setParser {
	return JSON->new->allow_nonref;
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


} #### END

