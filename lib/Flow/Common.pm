package Flow::Common;
use Moose::Role;
use Method::Signatures::Simple;

# use Package::Sync;
use JSON;

=head2

ROLE        Flow::Common

PURPOSE

  1. PROVIDE COMMON UTILITY METHODS FOR Flow CLASSES

=cut


method yamlToData ( $text ) {
  $self->logDebug( "text", $text );
  return {} if not $text;

  my $yaml = YAML::Tiny->new();
  my $yamlinstance = $yaml->read_string( $text );
  my $data = $yamlinstance->[0];
  $self->logDebug( "data", $data );

  return $data;
}

method insertTags ( $data, $profiledata ) {
  $self->logDebug( "data", $data );
  $self->logDebug( "profiledata", $profiledata );

  for my $key ( keys %$profiledata ) {
    # $self->logDebug( "DOING key $key" );

    #### ONLY INSERT SCALAR VALUES
    if ( ref( $profiledata->{ $key } ) eq "" ) {
      for my $datakey ( keys %$data ) {
        my $upperkey = "<" . uc( $key ) . ">";
        # $self->logDebug( "upperkey", $upperkey );
        # $self->logDebug( "profiledata->{$key}", $profiledata->{$key} );

        next if not $data->{$datakey};
        $data->{$datakey} =~ s/$upperkey/$profiledata->{$key}/g;
      }
    }
  }
  $self->logDebug( "data", $data );

  return $data;
}

method stageToDatabase ( $username, $stageobject, $projectname, $workflowname, $workflownumber, $appnumber, $profiledata ) {
  $self->logDebug("appnumber", $appnumber);
  
  $self->logCritical("username not defined") and exit if not defined $username;

  #### ADD STAGE
  my $stagedata = $stageobject->exportData();
  $stagedata->{username}        = $username;
  $stagedata->{projectname}     = $projectname;
  $stagedata->{workflowname}    = $workflowname;
  $stagedata->{workflownumber}  = $workflownumber;
  $stagedata->{appnumber}       = $appnumber;
  $self->logDebug("stagedata", $stagedata);

  #### GET STAGE PARAMETERS DATA
  my $parametersdata = $stagedata->{parameters};
  
  #### DELETE PARAMETERS FROM STAGE BEFORE ADD STAGE
  delete $stagedata->{parameters};
  #$self->logDebug("AFTER delete, stagedata", $stagedata);

  $self->logDebug( "BEFORE insertTags    stagedata", $stagedata );
  $stagedata = $self->insertTags( $stagedata, $profiledata );
  $self->logDebug( "AFTER insertTags    stagedata", $stagedata );

  #### REMOVE STAGE
  $self->table()->_deleteStage($stagedata);
  
  #### ADD STAGE
  $self->table()->_addStage($stagedata);
}

method stageParameterToDatabase ( $username, $package, $installdir, $stage, $parameterobject, $projectname, $workflowname, $workflownumber, $stagenumber, $paramnumber, $profiledata ) {
  $self->logNote("parameterobject", $parameterobject);
  $self->logDebug("stagenumber", $stagenumber);
  
  my $paramdata = $parameterobject->exportData();
  $self->logDebug("BEFORE paramdata", $paramdata);
  $paramdata->{projectname}   = $projectname;
  $paramdata->{workflowname}    = $workflowname;
  $paramdata->{workflownumber}= $workflownumber;
  $paramdata->{name}      = $paramdata->{paramname};
  $paramdata->{number}    = $paramnumber;
  $paramdata->{appnumber}   = $stagenumber,
  $paramdata->{owner}     = $username;
  $paramdata->{username}    = $username;
  $paramdata->{package}   = $package;
  $paramdata->{installdir}  = $installdir;
  $paramdata->{appname}   = $stage->appname();
  $paramdata->{owner}     = $stage->owner() || $username;
  $paramdata->{version}   = $stage->version();
  $paramdata->{ordinal}   = $paramnumber if not defined $paramdata->{ordinal};
  $self->logDebug("AFTER paramdata", $paramdata); 

  if ( not $paramdata->{paramname} and $paramdata->{argument} ) {
    $paramdata->{paramname} = $paramdata->{argument};
    $paramdata->{paramname} =~ s/^\-+//g;
  }

  $self->logDebug( "BEFORE insertTags    paramdata", $paramdata );
  $paramdata = $self->insertTags( $paramdata, $profiledata );
  $self->logDebug( "AFTER insertTags    paramdata", $paramdata );


  #### REMOVE STAGE PARAMETER
  $self->table()->_deleteStageParameter($paramdata);

  #### ADD STAGE PARAMETER
  return $self->table()->_addStageParameter($paramdata);
}

method setTable () {
  my $table = Table::Main->new({
    conf      =>  $self->conf(),
    log       =>  $self->log(),
    printlog  =>  $self->printlog(),
    logfile   =>  $self->logfile()
  });

  $self->table($table); 
}


method setJsonParser {
  return JSON->new->allow_nonref;
}

#### JSON

method projectToDatabase ($username, $projectobject) {
  $self->logCritical("username not defined") and exit if not defined $username;
  my $projectdata = $projectobject->exportData();
  delete $projectdata->{workflows};
  $projectdata->{username} = $username;
  $self->logDebug("projectdata", $projectdata);
  
  #### REMOVE PROJECT
  my $success = $self->table()->_removeProject($projectdata);
  $self->logDebug("success", $success);

  #### ADD PROJECT
  return $self->table()->_addProject($projectdata);
}

method getWorkflowObjectsForProject ($workflowsdata, $username) {
  
  my $workflowobjects = [];
  foreach my $workflowdata ( @$workflowsdata ) {
    #$self->logDebug("workflowdata", $workflowdata);
    $workflowdata->{workflow} = $workflowdata->{name};

    my $workflowobject  = $self->getWorkflowObject($workflowdata);
    push @$workflowobjects, $workflowobject;

  } #### workflowsdata
  
  return $workflowobjects;
}

method getWorkflowObject ($workflow) {
  my $username  = $workflow->{username};
  $self->logDebug("username", $username);
  
  #### GET STAGES
  my $stages = $self->table()->getStagesByWorkflow($workflow);
  $self->logDebug("No. stages", scalar(@$stages));
  
  #### CREATE WORKFLOW AND LOAD STAGES
  $workflow->{owner}      =   $username;
  $workflow->{username}   =   $username;
  $workflow->{logfile}    =   $self->logfile();
  $workflow->{log}        =   $self->log();
  $workflow->{db}         =   $self->table()->db();
  $workflow->{printlog}   =   $self->printlog();

  my $workflowobject = Flow::Workflow->new($workflow);
  
  foreach my $stage ( @$stages ) {
    $stage->{appname} = $stage->{name};
    $stage->{appnumber} = $stage->{number};
    my $parameters = $self->table()->getParametersByStage($stage);
    
    #### CREATE APPLICATION AND LOAD PARAMETERS
    $stage->{username}  = $username;
    $stage->{logfile}   = $self->logfile();
    $stage->{log}       = $self->log();
    $stage->{printlog}  = $self->printlog();
  
    $self->logDebug("stage", $stage);
    my $appobject = Flow::App->new($stage);
    #$self->logDebug("appobject", $appobject);
    foreach my $parameter ( @$parameters ) {
      $self->logDebug("parameter", $parameter);
      $appobject->loadParam($parameter);
    }
    
    $workflowobject->_addApp($appobject);
  }
    
  return $workflowobject; 
}

method _indentText ($text, $indent) {
  my $lines = [ split "\n", $text ];
  for (my $i = 0; $i < @$lines; $i++) {
    $$lines[$i] =  $indent . $$lines[$i];
  }

  return join "\n", @$lines;
}

method _indentSecond ($first, $second, $indent) {
  $indent = $self->indent() if not defined $indent;
  my $spaces = " " x ($indent - length($first));
  return $first . $spaces . $second;
}

method setUsername {
  my $whoami    =   `whoami`;
  $whoami       =~  s/\s+$//;
  $self->logDebug("whoami", $whoami);

  #### RETURN ACCOUNT NAME IF NOT ROOT
  if ( $whoami ne "root" ) {
    $self->username($whoami);
    return $whoami;
  }
  
  #### OTHERWISE, SET USERNAME IF PROVIDED
  my $username    =   $self->username();
  $self->logDebug("username", $username);
  if ( defined $username and $username ne "" ) {
    $self->username($username);
    return $username;
  }
  else {
    $self->username($whoami);
    return $whoami;
  }
}

method setConf {
  my $installdir  =   $ENV{'FLOW_HOME'};
  my $configfile  =   "$installdir/conf/config.yml";
  my $logfile     =   "$installdir/log/app.$$.log";
  
  my $conf    =   Conf::Yaml->new({
    inputfile   =>  $configfile,
    logfile     =>  $logfile,
    log         =>  $self->log(),
    printlog    =>  $self->printlog()
  });
  
  return $self->conf($conf);
}

method getFileContents ($file) {
  $self->logNote("file", $file);
  open(FILE, $file) or $self->logCritical("Can't open file: $file") and exit;
  my $temp = $/;
  $/ = undef;
  my $contents =  <FILE>;
  close(FILE);
  $/ = $temp;

  return $contents;
}

method getDirs ($directory) {
  $self->logDebug("directory", $directory);
  opendir(DIR, $directory) or die "Can't open directory: $directory\n";
  my $dirs;
  @$dirs = readdir(DIR);
  closedir(DIR) or die "Can't close directory: $directory";
  $self->logDebug("dirs", $dirs);

  # my $dirs = $self->listFiles($directory);
  # $self->logDebug("dirs", $dirs);
  
  for ( my $i = 0; $i < @$dirs; $i++ ) {
    if ( $$dirs[$i] =~ /^\.+$/ ) {
      splice @$dirs, $i, 1;
      $i--;
    }
    my $filepath = "$directory/$$dirs[$i]";
    if ( not -d $filepath ) {
      splice @$dirs, $i, 1;
      $i--;
    }
  }
    
  return $dirs; 
}

method getFiles ($directory) {
  $self->logDebug("directory", $directory);

  my $files;
  opendir(DIR, $directory) or die "Can't open directory: $directory\n";
  @$files = readdir(DIR);
  closedir(DIR) or die "Can't close directory: $directory";
  $self->logDebug("files", $files);
  
  for ( my $i = 0; $i < @$files; $i++ ) {
    if ( $$files[$i] =~ /^\.+$/ ) {
      splice @$files, $i, 1;
      $i--;
    }
    my $filepath = "$directory/$$files[$i]";
    if ( not -f $filepath ) {
      splice @$files, $i, 1;
      $i--;
    }
  }
  
  return $files;  
}



no Moose::Role;

1;