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
package Kanku::Handler::ChangeDomainState;

use Moose;
use Kanku::Config;
use Kanku::Util::VM;

use Path::Class::File;
use Data::Dumper;
with 'Kanku::Roles::Handler';

has 'domain_name' => (is => 'rw',isa=>'Str');
has 'action'      => (is => 'ro', isa => enum([qw[reboot shutdown create destroy undefine]]);

# TODO: implement wait_for_*
has [qw/wait_for_network wait_for_console/] => (is => 'rw',isa=>'Bool',lazy=>1,default=>1);
has [qw/timeout/] => (is => 'rw',isa=>'Int',lazy=>1,default=>600);

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'wait_for_console',
          type  => 'checkbox',
          label => 'Wait for console'
        },
      ];
  }
);
sub distributable { 1 };

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();
  my $msg  = "Nothing to do!"

  if ( ! $self->domain_name && $ctx->{domain_name}) {
    $self->domain_name($ctx->{domain_name});
    $msg = "Set domain_name from context to '".$self->domain_name."'";
  }

  return {
    code    => 0,
    message => $msg
  };
}

sub execute {
  my $self   = shift;
  my $ctx    = $self->job()->context();
  my $action = $self->action;
  my $cfg    = Kanku::Config->instance()->config();

  my $final_states = {
    reboot   => 1,
    create   => 1,
    shutdown => 5,
    destroy  => 5,
    undefine => 0
  };

  my $vm = Kanku::Util::VM->new(
      domain_name => $self->domain_name,
      job_id      => $self->job->id,
  );

  my $dom = $vm->dom;
  $dom->$action();

  my $to = $self->timeout;
  my $info = $dom->get_info;
  while ($info->{state} != $final_state->{$action}) {
     $to--;
     if( $to <= 0) {
       die "Action '$action' on ". $self->domain_name ." failed with timeout";
     }
     sleep 1;
  }

  return {
    code    => 0,
    message => "Action '$action' on ". $self->domain_name ." finished successfully";
  };
}

1;

__END__

=head1 NAME

Kanku::Handler::ChangeDomainState

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ChangeDomainState
    options:
      action: shutdown
      timeout:          600 

=head1 DESCRIPTION

This handler triggers an action on a VM and waits for the final state.

=head1 OPTIONS

    action  :          <create|reboot|shutdown|destroy|undefine>

    timeout :          wait only <seconds>

=head1 CONTEXT

=head2 getters

 domain_name

=head2 setters

=head1 DEFAULTS

    timeout : 600 seconds

=cut

