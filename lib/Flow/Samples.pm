use MooseX::Declare;


use FindBin qw($Bin);
use lib "$Bin/../..";

class Flow::Samples with (Util::Logger, Flow::Common) {

use DBase::Factory;
use Table::Main;
use Util::Main;

#### Int
has 'log'		    => ( isa => 'Int', is => 'rw', default 	=> 	0 	);  
has 'printlog'	=> ( isa => 'Int', is => 'rw', default 	=> 	0 	);

has 'conf' 		=> (
    is =>	'rw',
    isa => 'Conf::Yaml'
);

has 'table'		=>	(
	is 			=>	'rw',
	isa 		=>	'Table::Main',
	lazy		=>	1,
	builder		=>	"setTable"
);

has 'util'    =>  (
  is      =>  'rw',
  isa     =>  'Util::Main',
  lazy    =>  1,
  builder =>  "setUtil"
);

method setUtil () {
  my $util = Util::Main->new({
    conf      =>  $self->conf(),
    log       =>  $self->log(),
    printlog  =>  $self->printlog()
  });

  $self->util($util); 
}

method loadSamples ($project, $table, $sqlfile, $tsvfile, $directory, $regex) {
	my $username	=	$ENV{USER};
	
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("table", $table);
	$self->logDebug("sqlfile", $sqlfile);
	$self->logDebug("tsvfile", $tsvfile);
	$self->logDebug("regex", $regex);
	
	$self->logError("Can't find sqlfile: $sqlfile") and return if not -f $sqlfile;

	my $files   =  $self->util()->getFilesByRegex( $directory, $regex );
	$self->logDebug( "files", $files );

	#### LOAD SQL
	my $query = "DROP TABLE IF EXISTS $table";
	my $success = $self->table()->db()->do($query);
	$query	=	$self->fileContents($sqlfile);
	$self->logDebug("query", $query);
	$success = $self->table()->db()->do($query);
	$self->logDebug( "success", $success );


	#### DELETE FROM TABLE
	$query		=	qq{DELETE FROM $table};
	$self->logDebug("query", $query);
	$self->table()->db()->do($query);
	
	#### CREATE TSV
	$self->createTempTsvFile($username, $project, $tsvfile, $files);

	#### LOAD TSV
	my $success	=	$self->table()->db()->load($table, $tsvfile);
	$self->logDebug("loadTsvFile   success", $success);

	
$self->logDebug( "DEBUG EXIT" ) and exit;


	#### ADD ENTRY TO sampletable TABLE
	if ( $self->table()->db()->hasTable($table) ) {
		$query	=	qq{SELECT 1 FROM sampletable
WHERE username='$username'
AND projectname='$project'
AND sampletable='$table'};
		$self->logDebug("query", $query);
		my $exists = $self->table()->db()->query($query);
		$self->logDebug("exists", $exists);
		
		return if $exists;
  }

	$query	=	qq{INSERT INTO sampletable VALUES
	('$username', '$project', '$table')};
	$self->logDebug("query", $query);
	$success	=	$self->table()->db()->do($query);
	$self->logDebug("success", $success);

	return $success;	
}

method createTempTsvFile ($username, $project, $tsvfile, $files) {
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("tsvfile", $tsvfile);
	
	my $outputs = [];
	foreach my $file ( @$files ) {
		push @$outputs,	"$file|$username|$project\n";
	}
	
	open( OUT, ">", $tsvfile ) or die "Can't open tsvfile: $tsvfile\n";
	foreach my $output ( @$outputs ) {
		print OUT $output;
	}
	close(OUT) or die "Can't close tsvfile: $tsvfile\n";

	return $tsvfile;
}

method loadSampleFiles ($username, $project, $workflow, $workflownumber, $file) {
	my $table	=	"samplefile";
	$username	=	$self->username() if not defined $username;
	$project	=	$self->project() if not defined $project;
	$workflow	=	$self->workflow() if not defined $workflow;
	$workflownumber	=	$self->workflownumber() if not defined $workflownumber;
	
	$self->logError("username not defined") and return if not defined $username;
	$self->logError("project not defined") and return if not defined $project;
	$self->logError("workflow not defined") and return if not defined $workflow;
	$self->logError("workflownumber not defined") and return if not defined $workflownumber;
	$self->logDebug("username", $username);
	$self->logDebug("project", $project);
	$self->logDebug("workflow", $workflow);
	$self->logDebug("workflownumber", $workflownumber);
	$self->logDebug("table", $table);
	$self->logDebug("file", $file);
	
	$self->logError("Can't find file: $file") and return if not -f $file;

	my $lines	=	$self->fileLines($file);
	$self->logDebug("no. lines", scalar(@$lines));

	#### SET DATABASE HANDLE	
	$self->setDbh() if not defined $self->db();
	return if not defined $self->db();

	my $tsv = [];
	foreach my $line ( @$lines ) {
		my ($sample, $filename, $filesize)	=	$line	=~ 	/^(\S+)\s+(\S+)\s+(\S+)/;
		#$self->logDebug("sample", $sample);
		
		my $out	=	"$username\t$project\t$workflow\t$workflownumber\t$sample\t$filename\t$filesize";
		push @$tsv, $out;
	}
	
	my $outputfile	=	$file;
	$outputfile		=~	s/\.{2,3}$//;
	$outputfile		.=	"-$table.tsv";
	my $output	=	join "\n", @$tsv;
	$self->logDebug("output", $output);

	$self->printToFile($outputfile, $output);
	
	my $success	=	$self->loadTsvFile($table, $outputfile);
	$self->logDebug("success", $success);
	
	return $success;	
}

method fileLines ($file) {
#### GET THE LINES FROM A FILE
	my $contents = $self->fileContents($file); 
	return if not defined $contents;

	my @lines = split "\n", $contents;

	return \@lines;
}

method fileContents ($file) {
    $self->logDebug("file", $file);
    die("file not defined\n") if not defined $file;
    die("Can't find file: $file\n$!") if not -f $file;

    my $temp = $/;
    $/ = undef;
    open(FILE, $file) or die("Can't open file: $file\n$!");
    my $contents = <FILE>;
    close(FILE);
    $/ = $temp;
    
    return $contents;
}

method loadTsvFile ($table, $file) {
	$self->logCaller("");
	return if not $self->can('db');
	
	$self->logDebug("table", $table);
	$self->logDebug("file", $file);
	
	$self->setDbh() if not defined $self->db();
	return if not defined $self->db();
	my $query = qq{LOAD DATA LOCAL INFILE '$file' INTO TABLE $table};
	my $success = $self->db()->do($query);
	$self->logCritical("load data failed") if not $success;
	
	return $success;	
}



}