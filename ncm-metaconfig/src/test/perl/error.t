use strict;
use warnings;
use Test::More;
use Test::Quattor;
use NCM::Component::metaconfig;
use CAF::Object;

=pod

=head1 DESCRIPTION

Test that a JSON config file can be generated by this component.

=cut

my $cmp = NCM::Component::metaconfig->new('metaconfig');

my $cfg = {
	   owner => 'root',
	   group => 'root',
	   mode => 0644,
	   contents => {
			foo => 1,
			bar => 2,
			baz => {
				a => [0..3]
				}
			},
	   daemons => {'httpd' => 'restart'},
	   module => "ljhljhljhlujuih908yp08y",
	  };

ok(!$cmp->handle_service("/foo/bar", $cfg), "Error while rendering detected");
ok($cmp->{ERROR}, "Errors in file rendering reported");

my $fh = get_file("/foo/bar");

ok(!defined($fh), "File is not opened in case of errors"),

done_testing();
