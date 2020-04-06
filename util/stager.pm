package stager;
use Moose::Role;
use Method::Signatures::Simple;

method preTargetCommit ($mode, $repodir, $message) {
    $self->logDebug("mode", $mode);
    $self->logDebug("repodir", $repodir);
    $self->logDebug("message", $message);

    return if $mode ne "2-3";

    $self->logDebug("Carrying out mode $mode preTargetCommit procedures");

    #### REMOVE TEST DIR
    my $testdir = "$repodir/t";
    $self->logDebug("testdir", $testdir);
    my $command =   "rm -fr $testdir";
    $self->logDebug("command", $command);

    `$command`;    

    #### REMOVE APPS DIR
    my $appsdir = "$repodir/apps/*";
    $self->logDebug("appsdir", $appsdir);
    $command =   "rm -fr $appsdir";
    $self->logDebug("command", $command);

    `$command`;    
}

1;

