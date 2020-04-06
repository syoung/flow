package Mock::Base;
use Moose::Role;
use Method::Signatures::Simple;

=head2

	PACKAGE		Mock::Base
	
	PURPOSE
	
		BASE MOCK CLASS WITH input AND output GET/SETTERS

=cut
	
#### Arrays
has 'outputs'		=>  ( isa => 'ArrayRef|Undef', is => 'rw', default	=>	sub { return [] } );
has 'inputs'		=>  ( isa => 'ArrayRef|Undef', is => 'rw', default	=>	sub { return [] } );

method clearInput {
	$self->inputs([]);
}

method clearOutput {
	$self->outputs([]);
}

method returnInput {
	return splice($self->inputs(), 0, 1);
}

method returnOutput {
	return splice($self->outputs(), 0, 1);
}



1;