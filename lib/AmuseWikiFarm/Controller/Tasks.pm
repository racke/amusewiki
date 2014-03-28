package AmuseWikiFarm::Controller::Tasks;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

AmuseWikiFarm::Controller::Tasks - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub root :Chained('/') :PathPart('tasks') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
}

sub status :Chained('root') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    my $job = $c->model('Queue')->fetch_job_by_id($id);
    unless ($job) {
        $c->detach('/not_found');
        return;
    }
    $c->stash(job => $job);
}

sub display :Chained('status') :PathPart('') :Args(0) {
    # empty to close the chain
}

sub ajax :Chained('status') :PathPart('ajax') :Args(0) {
    my ($self, $c, $job) = @_;
    my $json =  $c->stash->{job}->as_json;
    $c->res->content_type('application/json');
    $c->response->body($json);
}


=head1 AUTHOR

Marco,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
