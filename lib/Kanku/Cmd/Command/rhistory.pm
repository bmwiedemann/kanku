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
package Kanku::Cmd::Command::rhistory;

use Moose;
use Term::ReadKey;
use Log::Log4perl;
use POSIX;
use Try::Tiny;

extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Remote';
with 'Kanku::Cmd::Roles::RemoteCommand';
with 'Kanku::Cmd::Roles::View';

has full => (
  traits        => [qw(Getopt)],
  isa           => 'Bool',
  is            => 'rw',
  documentation => 'show full output of error messages',
);

has limit => (
  traits        => [qw(Getopt)],
  isa           => 'Int',
  is            => 'rw',
  documentation => 'limit output to X rows',
);

has page => (
  traits        => [qw(Getopt)],
  isa           => 'Int',
  is            => 'rw',
  documentation => 'show page X of job history',
);

sub abstract { "list job history on your remote kanku instance" }

sub description {
  "list job history on your remote kanku instance

" . $_[0]->description_footer;
}

sub execute {
  my $self  = shift;
  Kanku::Config->initialize;
  my $logger  =	Log::Log4perl->get_logger;

  if ( $self->list ) {
    $self->_list();
  } elsif ( $self->details ) {
    $self->_details();
  } else {
	$logger->warn("Please specify a command. Run 'kanku help rhistory' for further information.");
  }
}

sub _list {
  my $self = shift;

  my $kr;
  try {
	$kr = $self->connect_restapi();
  } catch {
	exit 1;
  };

  my %params = (
    limit => $self->limit || 10,
    page  => $self->page || 1,
  );

  my $data = $kr->get_json( path => "jobs/list" , params => \%params );

  foreach my $job ( @{$data->{jobs}} ) {
    if ( $job->{start_time} ) {
      my $et = ($job->{end_time}) ? $job->{end_time} : time();
      $job->{duration} = duration( $et - $job->{start_time});
    } else {
      $job->{duration} = "Not started yet";
    }
  }

  $self->view('jobs.tt', $data);

};

sub _details {
  my $self   = shift;
  my $logger = Log::Log4perl->get_logger;
  if ( ! $self->details ) {
    $logger->error("No job id given");
    return 1;
  }

  my $kr;
  try {
    $kr = $self->connect_restapi();
  } catch {
    exit 1;
  };

  my $data = $kr->get_json( path => "job/".$self->details );

  $self->_truncate_result($data) if ! $self->full;

  $self->view('job.tt', $data);
}

sub _truncate_result {
  my ($self, $data) = @_;
  foreach my $task (@{$data->{subtasks}}) {
    if ( $task->{result}->{error_message} ) {
      my @lines = split(/\n/,$task->{result}->{error_message});
      my $max_lines = 10;
      if ( @lines > $max_lines ) {
	my $ml = $max_lines;
	my @tmp;
	while ($max_lines) {
	  my $line = pop(@lines);
	  push(@tmp,$line);
	  $max_lines--;
	}
	push(@tmp,"","...","TRUNCATING to $ml lines - use --full to see full output");
	$task->{result}->{error_message} = join("\n",reverse @tmp) . "\n";

      }
    }
  }
}

sub duration {
  my $t = shift;
  # Calculate hours
  my $h = floor($t/(60*60));
  # Remove complete hours
  $t = $t - $h*60*60;
  # Calculate minutes
  my $m = floor($t/60);
  # Calculate seconds
  my $s = $t - ( $m * 60 );

  return sprintf("%02d:%02d:%02d",$h,$m,$s);
}

__PACKAGE__->meta->make_immutable;

1;
