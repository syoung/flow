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

#####################
#### PROFILE METHODS
#####################

#  METHOD: doProfileInheritance 
#
#  PURPOSE: ADD FIELDS FROM ONE OR MORE INHERITED PROFILES.
#
#  THE ORDER OF PRIORITY IS "FIRST TO LAST",  I.E., IF THE 
#
#  inherits FIELD IS AS FOLLOWS:
#
#
#   testprofile:
#
#     inherits : first,second,third
#
#
#  ... THEN:
#     
#    1. THE PROFILES first, second AND third MUST ALSO BE PRESENT
#
#    IN THE profiles.yml FILE (EXITS IF THIS IS NOT THE CASE)
#
#    2. THE FIELDS FROM PROFILE first WILL BE ADDED TO THE FIELDS
#
#    IN PROFILE testprofile WITHOUT OVERWRITING EXISTING FIELDS IN
#
#    testprofile
#
#    3. THE FIELDS IN PROFILE second WILL SIMILARLY BE ADDED TO
#
#    PROFILE testprofile WITHOUT OVERWRITING ANY EXISTING FIELDS
#
#    4. LASTLY, THE FIELDS IN PROFILE third WOULD BE ADDED WITHOUT
#
#    OVERWRITING ANY FIELDS ORIGINALLY IN PROFILE testprofile OR
#
#    ADDED TO IT FROM PROFILES first AND second
#
method doProfileInheritance ( $profiles, $profilename ) {
  $self->logDebug( "profiles", $profiles );
  $self->logDebug( "profilename", $profilename );
  
  my $profile = $profiles->{$profilename};
  my $inherits = $profile->{inherits};
  $self->logDebug( "inherits", $inherits );
  if ( not $inherits ) {
    return $profile;
  }

  my @inheritedprofiles = split ",", $inherits;
  foreach my $inheritedprofile ( @inheritedprofiles ) {
    my $inherited = $profiles->{$inheritedprofile};
    if ( not $inherited ) {
      print "Inherited profile '$inheritedprofile' not found in profiles.yml file\n";
      exit;
    }

    foreach my $key ( keys %$inherited ) {
      $self->logDebug( "key", $key );
      $profile->{ $key } = $self->recurseInheritance ( $profile->{$key}, $inherited->{$key} ); 
    }
  }

  return $profile;
}

method recurseInheritance ( $profilefield, $inheritedfield ) {
  $self->logDebug( "profilefield", $profilefield );
  $self->logDebug( "inheritedfield", $inheritedfield );

  #### INHERITED FIELD DOES NOT EXIST IN profile SO ADD IT 
  if ( not defined $profilefield ) {
    return $inheritedfield;
  }
  #### OTHERWISE, RECURSE IF THE FIELD IS AN OBJECT
  elsif ( ref( $profilefield ) ne "" and ref( $inheritedfield ) ne "" ) {
    foreach my $key ( keys %$inheritedfield ) {
      $self->logDebug( "key", $key );

      if ( not defined $profilefield->{ $key } ) {
        $profilefield->{ $key } =  $inheritedfield->{ $key };
      }
      else {
        $profilefield->{ $key } = $self->recurseInheritance( $profilefield->{ $key }, $inheritedfield->{ $key } );
      }
    }
  }

  #### OTHERWISE, KEEP THE EXISTING VALUE IN profile
  return $profilefield;
}


method yamlToData ( $text ) {
  $self->logDebug( "text", $text );
  return {} if not $text;

  my $yaml = YAML::Tiny->new();
  my $yamlinstance = $yaml->read_string( $text );
  my $data = $yamlinstance->[0];
  # $self->logDebug( "data", $data );

  return $data;
}

method dataToYaml ( $data ) {
  $self->logDebug( "data", $data );
  return "" if not $data;

  my $yaml = YAML::Tiny->new();
  $$yaml[ 0 ] = $data;
  my $text = $yaml->write_string( $data );
  $text =~ s/\'/\"/g;
  $self->logDebug( "text", $text );

  return $text;
}

method getProfileHash ( $profile ) {
  $self->logDebug( "profile", $profile );

  my $yaml = YAML::Tiny->new();
  my $yamlobject = $yaml->read_string( $profile );
  my $data = $$yamlobject[0];
  # $self->logDebug( "data", $data );

  return $data;
}

method getProfiles ( $file ) {
  $self->logDebug( "file", $file );

  return undef if not $file;

  my $yaml = YAML::Tiny->read( $file );
  
  return $$yaml[0];
}

#  METHOD: replaceTags
#
#  PURPOSE: ADD FIELDS FROM ONE OR MORE INHERITED PROFILES.
#
#  THE ORDER OF PRIORITY IS "FIRST TO LAST",  I.E., IF THE 
#
#  inherits FIELD IS AS FOLLOWS:
#
#   testprofile:
#
#     inherits : first,second,third
#
#  THEN THE VALUES IN first WILL OVERRIDE THE VALUES IN second
#
#  WHICH WILL, IN TURN, OVERRIDE THE VALUES IN third.
#
#  SEE METHOD doProfileInheritance ABOVE FOR DETAILS
#
#
method replaceTags ( $data, $profiledata ) {
  $self->logDebug( "data", $data );
  $self->logDebug( "profiledata", $profiledata );

  foreach my $key ( keys %$data ) {
    # $self->logDebug( "DOING key $key" );
    my $string = $data->{ $key };

    next if not $string;
    $data->{ $key } = $self->replaceString( $profiledata, $string );
    if ( not defined $data->{ $key } ) {
      $self->logError( "**** PROFILE PARSING FAILED. RETURNING undef TO TRIGGER ROLLBACK ****");
      return undef;
    }
  }
  # $self->logDebug( "data", $data );

  return $data;
}

method replaceString( $profiledata, $string ) {
  # $self->logDebug( "profiledata", $profiledata );
  # $self->logDebug( "string", $string );

  while ( $string =~ /<profile:([^>]+)>/ ) {
    my $keystring = $1;
    # $self->logDebug( "string", $string );
    my $value = $self->getProfileValue( $keystring, $profiledata );
    # $self->logDebug( "value", $value );

    if ( not $value ) {
      $self->logError( "*** ERROR *** Can't find profile value for key: $keystring ****" );
      # print "\n\n\n**** Can't find profile value for key: $keystring ****\n\n\n";
      return undef;
    }

    #### ONLY INSERT SCALAR VALUES
    if ( ref( $value ) ne "" ) {
      # print "Profile value is not a string: " . YAML::Tiny::Dump( $value ) . "\n";
      $self->logError( "Profile value is not a string: " . YAML::Tiny::Dump( $value ) . "\n" );
      return undef;
    }

    $string =~ s/<profile:$keystring>/$value/ if defined $value;
  }

  return $string;
}

method getProfileValue ( $keystring, $profile ) {
  $self->logDebug( "keystring", $keystring );
  my @keys = split ":", $keystring;
  my $hash = $profile;
  foreach my $key ( @keys ) {
    $hash  = $hash->{$key};
    return undef if not defined $hash;
    $self->logDebug("hash", $hash);
  }

  return $hash;
}

# method setProfileValue ( $keystring, $profile, $value ) {
#   $self->logDebug( "keystring", $keystring );
#   my @keys = split ":", $keystring;
#   my $hash = $profile;
#   foreach my $key ( @keys ) {
#     $hash  = $hash->{$key};
#     return undef if not defined $hash;
#     $self->logDebug("hash", $hash);
#   }

#   return $hash;
# }

#####################
#### DATABASE METHODS
#####################

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

  $self->logDebug( "BEFORE replaceTags    stagedata", $stagedata );
  $stagedata = $self->replaceTags( $stagedata, $profiledata );
  $self->logDebug( "AFTER replaceTags    stagedata", $stagedata );

  #### PROFILE
  my $profilename   = $stagedata->{profilename};
  my $stageprofile  = $self->doProfileInheritance( $profiledata, $profilename );
  $stagedata->{profile} = $self->dataToYaml( $stageprofile );
 $self->logDebug( "stagedata", $stagedata );

  #### REMOVE STAGE
  my $success = $self->table()->_deleteStage($stagedata);
  print "Can't remove stage: " . Dump $stagedata . "\n" if not $success;

  #### ADD STAGE
  return $self->table()->_addStage($stagedata);
}

method stageParameterToDatabase ( $username, $package, $installdir, $stage, $parameterobject, $projectname, $workflowname, $workflownumber, $stagenumber, $paramnumber, $profiledata ) {
  $self->logNote("parameterobject", $parameterobject);
  $self->logDebug("stagenumber", $stagenumber);
  
  my $paramdata = $parameterobject->exportData();
  $self->logDebug("BEFORE paramdata", $paramdata);
  $paramdata->{projectname}   = $projectname;
  $paramdata->{workflowname}    = $workflowname;
  $paramdata->{workflownumber}= $workflownumber;
  $paramdata->{paramname}      = $paramdata->{paramname};
  $paramdata->{paramnumber}    = $paramnumber;
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

  $self->logDebug( "BEFORE replaceTags    paramdata", $paramdata );
  $paramdata = $self->replaceTags( $paramdata, $profiledata );
  $self->logDebug( "AFTER replaceTags    paramdata", $paramdata );
  if ( not defined $paramdata ) {
    return undef;
  }


  #### REMOVE STAGE PARAMETER
  $self->table()->_deleteStageParameter($paramdata);

  #### ADD STAGE PARAMETER
  return $self->table()->_addStageParameter($paramdata);
}


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
  $self->logCaller( "workflow", $workflow );
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

  $self->logDebug( "workflow", $workflow );
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


method setTable () {
  my $table = Table::Main->new({
    conf      =>  $self->conf(),
    log       =>  $self->log(),
    printlog  =>  $self->printlog(),
    logfile   =>  $self->logfile()
  });

  $self->table($table); 
}



#####################
#### UTILITY METHODS
#####################


method setJsonParser {
  return JSON->new->allow_nonref;
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