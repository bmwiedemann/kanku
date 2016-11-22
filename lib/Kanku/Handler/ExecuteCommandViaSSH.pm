# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Handler::ExecuteCommandViaSSH;

use Moose;

use Data::Dumper;

use namespace::autoclean;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';
with 'Kanku::Roles::SSH';

has [qw/ipaddress publickey_path privatekey_path passphrase username/] => (is=>'rw',isa=>'Str');
has commands => (is=>'rw',isa=>'ArrayRef',default=>sub { [] });

has "+distributable" => ( default => 1 );

sub prepare {
  my $self = shift;

  $self->get_defaults();

  return {
    code => 0,
    message => "Preparation successful"
  };
}

sub execute {
  my $self    = shift;
  my $results = [];
  my $ssh2    = $self->connect();
  my $ip      = $self->ipaddress;

  foreach my $cmd ( @{$self->commands} ) {
    
      my $out = $self->exec_command($cmd);

      push @$results, {
        command     => $cmd,
        exit_status => 0,
        message     => $out
      };

  }

  return {
    code        => 0,
    message     => "All commands on $ip executed successfully",
    subresults  => $results
  };
}

sub finalize {
  return {
    code    => 0,
    message => "Nothing to do!"
  }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::ExecuteCommandViaSSH

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ExecuteCommandViaSSH
    options:
      publickey_path: /home/m0ses/.ssh/id_rsa.pub
      privatekey_path: /home/m0ses/.ssh/id_rsa
      passphrase: MySecret1234
      username: kanku
      commands:
        - rm /etc/shadow

=head1 DESCRIPTION

This handler will connect to the ipaddress stored in job context and excute the configured commands


=head1 OPTIONS

      publickey_path    : path to public key file (optional)

      privatekey_path   : path to private key file

      passphrase        : password to use for private key

      username          : username used to login via ssh

      commands          : array of commands to execute


=head1 CONTEXT

=head2 getters

 ipaddress

=head2 setters

 vm_image_file


=head1 DEFAULTS

  privatekey_path       : $HOME/.ssh/id_rsa

  username              : root


=cut
