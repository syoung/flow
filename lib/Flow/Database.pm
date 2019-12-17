package Flow::Database;
use Moose::Role;
use Method::Signatures::Simple;

=head2

	PACKAGE		Flow::Database
	
	PURPOSE
	
		UTILITY METHODS FOR Agua::Common
		
=cut

#### EXTERNAL
use FindBin qw($Bin);
use lib "$Bin/../../";
use Term::ReadKey;
use Data::Dumper;

#### INTERNAL
use DBase::Factory;

has 'database'	=> ( isa => 'Str|Undef', is => 'rw' );
has 'db'        => ( isa => 'Any', is => 'rw', required => 0 );

method setDbh ( $args ) {
	$self->logNote("args", $args);	
	
	my $database 		=	$args->{database} || $self->database();
	my $dbuser 			=	$args->{dbuser};
	my $dbpassword 	=	$args->{dbpassword};
	my $dbhost 			=	$args->{dbhost};
	my $dbtype 			=	$args->{dbtype};
	my $dbfile 			=	$args->{dbfile};

	my $logfile = $self->logfile();
	my $log = $self->log();
	my $printlog = $self->printlog();

	$self->logNote("ARGS database", $database);
	$self->logNote("ARGS dbtype", $dbtype);
	$self->logNote("ARGS dbuser", $dbuser);
	
	$dbtype 	=	$self->conf()->getKey("database:DBTYPE") if not defined $dbtype;

	if ( $dbtype eq "SQLite" ) {
		$dbfile 	=	$self->conf()->getKey("core:INSTALLDIR") . "/" . $self->conf()->getKey("database:DBFILE") if not defined $dbfile;
		$self->logDebug("dbfile", $dbfile);
	}
	else {
		$self->logNote("database", $database);
		$dbuser 		=	$self->conf()->getKey("database:USER") if not defined $dbuser;
		$dbpassword 	=	$self->conf()->getKey("database:PASSWORD") if not defined $dbpassword;
		$dbhost			=	$self->conf()->getKey("database:HOST") if not defined $dbhost;
		$database	=	$self->conf()->getKey("database:DATABASE") if not defined $database or $database eq "";
		$self->logNote("CONF database", $database);
		$self->logNote("CONF dbtype", $dbtype);
		$self->logNote("CONF dbuser", $dbuser);
		
		if ( $self->can('isTestUser') and $self->isTestUser() ) {
			$dbuser 		=	$self->conf()->getKey("database:TESTUSER") if not defined $dbuser;
			$dbpassword 	=	$self->conf()->getKey("database:TESTPASSWORD") if not defined $dbpassword;
			$database	=	$self->conf()->getKey("database:TESTDATABASE") if not defined $database;
		}
		
		$self->logNote("AFTER database", $database);
		$self->logNote("AFTER dbtype", $dbtype);
		$self->logNote("AFTER dbuser", $dbuser);
		$self->logNote("AFTER dbpassword", $dbpassword);
		
		# $self->logError("dbtype not defined") and return if not $dbtype;
		# $self->logError("dbuser not defined") and return if not $dbuser;
		# $self->logError("dbpassword not defined") and return if not $dbpassword;
		# $self->logError("database not defined") and return if not $database;

		#### SET DATABASE IF PROVIDED IN JSON
		if ( $self->can('json') ) {
			my $json = $self->json();
			$database = $json->{database} if defined $json and defined $json->{database} and $json->{database};
		}

		$self->logNote("FINAL database", $database);
		$self->logNote("FINAL dbtype", $dbtype);
		$self->logNote("FINAL dbuser", $dbuser);
		$self->logNote("FINAL dbpassword", $dbpassword);
	}

	##### CREATE DB OBJECT USING DBASE FACTORY
	my $db = 	DBase::Factory->new(
		$dbtype,
		{
			dbfile			=>	$dbfile,
			database		=>	$database,
			dbuser      =>  $dbuser,
			dbpassword  =>  $dbpassword,
			dbhost  		=>  $dbhost,
			logfile			=>	$logfile,
			log					=>	$log,
			printlog		=>	$printlog,
			parent			=>	$self
		}
	) or print qq{ error: 'Agua::Database::setDbh    Cannot create database object $database: $!' } and return;
	$self->logError("db not defined") and return if not defined $db;
	$self->logDebug("AFTER CREATE    db", $db);

	$self->db($db);	

	return $db;
}

method grantPrivileges ( $tempfile, $rootdbpassword, $database, $dbuser, $dbpassword, $privileges, $host) {
	$self->logError("tempfile not defined") and return if not defined $tempfile;
	$self->logError("rootdbpassword not defined") and return if not defined $rootdbpassword;
	$self->logError("database not defined") and return if not defined $database;
	$self->logError("dbuser not defined") and return if not defined $dbuser;
	$self->logError("dbpassword not defined") and return if not defined $dbpassword;
	$self->logError("privileges not defined") and return if not defined $privileges;
	$self->logError("host not defined") and return if not defined $host;

	#### CREATE DATABASE AND Agua USER AND PASSWORD
    $self->logNote("tempfile", $tempfile);
	my $create = qq{
USE mysql;
GRANT ALL PRIVILEGES ON $database.* TO $dbuser\@localhost IDENTIFIED BY '$dbpassword';	
FLUSH PRIVILEGES;};
	`echo "$create" > $tempfile`;
	my $command = "mysql -u root -p$rootdbpassword < $tempfile";
	$self->logNote("$command");
	print `$command`;
	`rm -fr $tempfile`;
}

method inputRootPassword {
  #### MASK TYPING FOR PASSWORD INPUT
  ReadMode 2;
my $rootdbpassword = $self->inputValue("Root dbpassword (will not appear on screen)");

  #### UNMASK TYPING
  ReadMode 0;

	$self->rootdbpassword($rootdbpassword);

	return $rootdbpassword;
}

method inputValue ( $message, $default ) {
	$self->logError("message is not defined") and return if not defined $message;
	$default = '' if not defined $default;
	$self->logDebug("$message [$default]: ");
	print "$message [$default]: ";

	my $input = '';
    while ( $input =~ /^\s*$/ )
    {
        $input = <STDIN>;
        $input =~ s/\s+//g;
		$default = $input if $input;
		print "\n" and return $default if $default;
        $self->logDebug("$message [$default]: ");
		print "$message [$default]: ";
    }
}

method _updateTable ( $table, $hash, $required_fields, $set_hash, $set_fields ) {
=head2

	SUBROUTINE		_updateTable
	
	PURPOSE

		UPDATE ONE OR MORE ENTRIES IN A TABLE
        
	INPUTS
		
		1. NAME OF TABLE      

		2. HASH CONTAINING OBJECT TO BE UPDATED

		3. HASH CONTAINING TABLE FIELD KEY-VALUE PAIRS
        
=cut
 	$self->logNote("Common::_updateTable(table, hash, required_fields, set_fields)");
    $self->logError("hash not defined") and return if not defined $hash;
    $self->logError("required_fields not defined") and return if not defined $required_fields;
    $self->logError("set_hash not defined") and return if not defined $set_hash;
    $self->logError("set_fields not defined") and return if not defined $set_fields;
    $self->logError("table not defined") and return if not defined $table;

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->table()->db()->notDefined($hash, $required_fields);
    $self->logError("undefined values: @$not_defined") and return if @$not_defined;

	#### GET WHERE
	my $where = $self->table()->db()->where($hash, $required_fields);

	#### GET SET
	my $set = $self->table()->db()->set($set_hash, $set_fields);
	$self->logError("set values not defined") and return if not defined $set;

	##### UPDATE TABLE
	my $query = qq{UPDATE $table $set $where};           
	$self->logNote("$query");
	my $result = $self->table()->db()->do($query);
	$self->logNote("result", $result);
}

method _addToTable ( $table, $hash, $required_fields, $inserted_fields ) {
=head2

	SUBROUTINE		_addToTable
	
	PURPOSE

		ADD AN ENTRY TO A TABLE
        
	INPUTS
		
		1. NAME OF TABLE      

		2. ARRAY OF KEY FIELDS THAT MUST BE DEFINED 

		3. HASH CONTAINING TABLE FIELD KEY-VALUE PAIRS
        
=cut

	#### CHECK FOR ERRORS
    $self->logError("hash not defined for table: $table") and return if not defined $hash;
    $self->logError("required_fields not defined for table: $table") and return if not defined $required_fields;
    $self->logError("table not defined") and return if not defined $table;
	
	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->table()->db()->notDefined($hash, $required_fields);
    $self->logError("table '$table' undefined values: @$not_defined") and return if @$not_defined;

	#### GET ALL FIELDS BY DEFAULT IF INSERTED FIELDS NOT DEFINED
	$inserted_fields = $self->table()->db()->fields($table) if not defined $inserted_fields;

	$self->logError("table '$table' fields not defined") and return if not defined $inserted_fields;
	my $fields_csv = join ",", @$inserted_fields;
	
	##### INSERT INTO TABLE
	my $values_csv = $self->table()->db()->fieldsToCsv($inserted_fields, $hash);
	my $query = qq{INSERT INTO $table ($fields_csv)
VALUES ($values_csv)};           
	$self->logNote("$query");
	my $result = $self->table()->db()->do($query);
	$self->logNote("result", $result);
	
	return $result;
}

method _removeFromTable ( $table, $hash, $required_fields ) {
=head2

	SUBROUTINE		_removeFromTable
	
	PURPOSE

		REMOVE AN ENTRY FROM A TABLE
        
	INPUTS
		
		1. HASH CONTAINING TABLE FIELD KEY-VALUE PAIRS
		
		2. ARRAY OF KEY FIELDS THAT MUST BE DEFINED 

		3. NAME OF TABLE      
=cut
  #### CHECK INPUTS
  $self->logError("hash not defined") and return if not defined $hash;
  $self->logError("required_fields not defined") and return if not defined $required_fields;
  $self->logError("table not defined") and return if not defined $table;

	#### CHECK REQUIRED FIELDS ARE DEFINED
	my $not_defined = $self->table()->db()->notDefined($hash, $required_fields);
    $self->logError("undefined values: @$not_defined") and return if @$not_defined;

	#### DO DELETE 
	my $where = $self->table()->db()->where($hash, $required_fields);
	my $query = qq{DELETE FROM $table
$where};
	#$self->logDebug("\n$query");
	my $result = $self->table()->db()->do($query);
	#$self->logDebug("result", $result);
	
	return 1 if defined $result;
	return 0;
}


method arrayToArrayhash ( $array, $key ) {
=head2

    SUBROUTINE:     arrayToArrayhash
    
    PURPOSE:

        CONVERT AN ARRAY INTO AN ARRAYHASH, E.G.:
		
		{
			key1 : [ entry1, entry2 ],
			key2 : [ ... ]
			...
		}

=cut
	my $arrayhash = {};
	for my $entry ( @$array )
	{
		if ( not defined $entry->{$key} )
		{
			$self->logNote("entry->{$key} not defined in entry. Returning.");
			return;
		}
		$arrayhash->{$entry->{$key}} = [] if not exists $arrayhash->{$entry->{$key}};
		push @{$arrayhash->{$entry->{$key}}}, $entry;		
	}
	
	#$self->logNote("returning arrayhash", $arrayhash);
	return $arrayhash;
}

1;

