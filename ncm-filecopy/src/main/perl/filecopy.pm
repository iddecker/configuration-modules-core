# ${license-info}
# ${developer-info}
# ${author-info}


package NCM::Component::filecopy;

use strict;
use NCM::Component;
use vars qw(@ISA $EC);
@ISA = qw(NCM::Component);
$EC  = LC::Exception::Context->new->will_store_all;
use NCM::Check;

use EDG::WP4::CCM::Element qw(unescape);

use File::Basename;
use File::Path;
use Encode qw(encode_utf8);

use CAF::FileEditor;

local (*DTA);

##########################################################################
sub Configure($$@) {
##########################################################################

  my ( $self, $config ) = @_;

  # Define path for convenience.
  my $base = "/software/components/filecopy";

  # Retrieve component configuration
  my $confighash = $config->getElement($base)->getTree();
  my $files = $confighash->{services};

  # Determine first if there is anything to do.
  return 0 unless ( $files );

  # Some initializations
  my $globalForceRestart = $confighash->{forceRestart};
  my $changes = 0;

  # Loop over all of the files and manage the associated services.
  # %commands stores the command to execute for each modified file. This is a hash to avoid
  # reexecuting several times the same command.
  my %commands;
  for my $e_fname ( sort keys %{$files} ) {
    my $file_config = $files->{$e_fname};
    
    # The actual file name.
    my $fname = unescape($e_fname);
    $self->debug(1,"Processing file $fname...");

    # Pull in the file content.
    # The content can be either embedded in the configuration or specified as a file which MUST exist.
    my $contents;
    if ( $file_config->{config} ) {
      $contents = $files->{config};
    } else if ( $file_config->{source} ) {
      my $src_file = $file_config->{source};
      if ( -e $src_file ) {
        $contents = CAF::FileEditor::open($src_file);
      } else {
        $self->error("File $fname: source file not found ($src_file).");
      };
    } else {
      $self->debug("File $fname: internal error (neither 'config' nor 'source' property present)");
    };
    
    # Now just create the new configuration file.
    # Existing file is backed up, if it exists.

    if ( !-e $fname ) {
      # Check to see if the directory needs to be created.
      my $dir = dirname($fname);
      mkpath( $dir, 0, 0755 ) unless ( -e $dir );
      if ( !-d $dir ) {
        $self->error("Can't create directory: $dir");
        next;
      }
    }

    my %file_opts;
    if ( $file_config->{perms} ) {
      $file_opts{'mode'} = $file_config->{perms};
    }
    if ( $file_config->{group} ) {
      $file_opts{'group'} = $file_config->{group};
    }
    if ( $file_config->{owner} ) {
      my $owner_group = $file_config->{owner};
      my ($owner, $group) = split /:/, $owner_group;
      $file_opts{'owner'} = $owner;
      if ( !exists($file_opts{'group'}) && $group ) {
        $file_opts{'group'} = $group;
      }
    }

    # by default a backup is made, but this can be suppressed
    my $backup = '.old';
    if ( defined($file_config->{backup}) && !$file_config->{backup} ) {
      $backup = undef;
    }

    if ( !defined($file_config->{no_utf8}) || $file_config->{no_utf8} ) {
        $contents = encode_utf8($contents);
    } else {
      $self->debug("UTF8 encoding disabled.");
    }
    

    # LC::Check methods log a message if a change happened
    # LC::Check::status must be called independently because doing
    # the same operation in LC::Check::file, changes are not reported in
    # the return value.
    if ( $backup ) {
      $changes = LC::Check::file(
                                  $fname,
                                  backup   => $backup,
                                  contents => $contents,
                                );      
    } else {
      $changes = LC::Check::file(
                                  $fname,
                                  contents => $contents,
                                );            
    }
    $changes += LC::Check::status(
                                $fname,
                                %file_opts
    );

    # Check if the service must be restarted.
    # Default is to restart only if config file was changed.
    # Restart can be forced indepedently of changes, defining 'forceRestart'
    # properties globally or at the service level.
    my $service_restart = $changes;
    if ( ($file_config->{forceRestart} || $globalForceRestart ) ) {
      $service_restart = 1;
    }

    # Queue the restart command if given.
    # Use a hash to avoid reexecuting several times the same command.
    if ( $file_config->{restart} && $service_restart ) {
      $commands{$file_config->{restart}} = '';
    }
  }

  # Loop over all of the commands and execute them.  Do this after
  # everything to take care of any dependencies between writing
  # multiple files.
  foreach my $command (keys(%commands)) {
    $self->debug(1,"Executing command: $command");
    my $rc = system($command);
    $self->error("Failed to execute restart command: $command\n") if ($rc);
  }

  return 1;
}


1;    # Required for PERL modules
