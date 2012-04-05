package Catalyst::Plugin::EnableMiddleware;

use Moose::Role;
use namespace::autoclean;
use Plack::Util;
use Scalar::Util;

our $VERSION = '0.001';

around 'psgi_app', sub {
  my ($orig, $self, @args) = @_;
  my @mw = @{$self->config->{'Plugin::EnableMiddleware'}||[]};
  my $psgi_app = $self->$orig(@args);
  while(my $next = shift(@mw)) {
    if(Scalar::Util::blessed $next && $next->can('wrap')) {
      $psgi_app = $next->wrap($psgi_app);
    } elsif(my $type = ref $next) {
      if($type eq 'CODE') {
        $psgi_app = $next->($psgi_app);
      }
    } else {
      my $normalized_next = Plack::Util::load_class($next, 'Plack::Middleware');
      if($mw[0] and ref($mw[0]) and(ref $mw[0] eq 'HASH')) {
        my $args = shift @mw;
        $psgi_app = $normalized_next->wrap($psgi_app, %$args);
      } else {
        $psgi_app = $normalized_next->wrap($psgi_app);
      }
    }
  }
  return $psgi_app;
};

1;

=head1 NAME

Catalyst::Plugin::EnableMiddleware - Enable Plack Middleware via Configuration

=head1 SYNOPSIS

    package MyApp::Web;

    our $VERSION = '0.01';

    use Moose;
    use Catalyst qw/EnableMiddleware/;
    use Plack::Middleware::StackTrace;

    extends 'Catalyst';

    my $stacktrace_middleware = Plack::Middleware::StackTrace->new;

    __PACKAGE__->config(
      'Plugin::EnableMiddleware', [
        'Debug',
        '+MyApp::Custom',
        $stacktrace_middleware,
        'Session' => {store => 'File'},
        sub {
          my $app = shift;
          return sub {
            my $env = shift;
            $env->{myapp.customkey} = 'helloworld';
            $app->($env);
          },
        },
      ],
    );

    __PACKAGE__->setup;
    __PACKAGE__->meta->make_immutable;

=head1 DESCRIPTION

Modern versions of L<Catalyst> use L<Plack> as the underlying engine to
connect your application to an http server.  This means that you can take
advantage of the full L<Plack> software ecosystem to grow your application
and to better componentize and re-use your code.

Middleware is a large part of this ecosystem.  L<Plack::Middleware> wraps your
PSGI application with additional functionality, such as adding Sessions ( as in
L<Plack::Middleware::Session>), Debugging (as in L<Plack::Middleware::Debug>)
and logging (as in L<Plack::Middleware::LogDispatch> or
L<Plack::Middleware::Log4Perl>).

Generally you can enable middleware in your C<psgi> file, as in the following
example

    #!/usr/bin/env plackup

    use strict;
    use warnings;

    use MyApp::Web;  ## Your subclass of 'Catalyst'
    use Plack::Builder;

    builder {

      enable 'Debug';
      enable 'Session', store => 'File';

      mount '/' => MyApp::Web->psgi_app;

    };

Here we are using our C<psgi> file and tools that come with L<Plack> in order
to enable L<Plack::Middleware::Debug> and L<Plack::Middleware::Session>.  This
is a nice, clean approach that cleanly separates your L<Catalyst> application
from enabled middleware.

However there may be cases when you'd rather enable middleware via you L<Catalyst>
application, rather in a stand alone file.  For example, you may wish to let your
L<Catalyst> application have control over the middleware configuration.

This plugin lets you enable L<Plack> applications via configuration. For example,
the above mapping could be re-written as follows:

    package MyApp::Web;
    our $VERSION = '0.01';

    use Moose;
    use Catalyst qw/EnableMiddleware/;

    extends 'Catalyst';

    __PACKAGE__->config(
      'Plugin::EnableMiddleware', [
        'Debug',
        'Session' => {'Session', store => 'File'},
      ]);

    __PACKAGE__->setup;
    __PACKAGE__->meta->make_immutable;

Then your C<myapp_web.psgi> would simply become:

    #!/usr/bin/env plackup

    use strict;
    use warnings;

    use MyApp::Web;  ## Your subclass of 'Catalyst'
    MyApp::Web->psgi_app;

You can of course use a configuration file and format (like Config::General)
instead of hard coding your configuration into the main application class.
This would allow you the ability to configure things differently in different
environments (one of the key reasons to take this approach).

The approach isn't 'either/or' and merits to each are apparent.  Choosing one
doesn't preclude the other.

=head1 CONFIGURATION

Configuration for this plugin should be a hashref under the top level key
C<Plugin::URLMap>, as in the following:

    __PACKAGE__->config(
      'Plugin::EnableMiddleware', \@middleware);

Where C<@middleware> is one of the following

=over4

=item Middleware Object

An already initialized object that conforms to the L<Plack::Middleware>
specification

=item coderef

A coderef that is an inlined middleware

=item a scalar

We assume the scalar refers to a namespace after normalizing it in the same way
that L<Plack::Builder> does (it assumes we want something under the
'Plack::Middleware' unless prefixed with a C<+>).  We initialize an object,
first checking to see if the next value is a hashref, which is then used as
initialization arguments.

=cut

=head1 AUTHOR

John Napiorkowski L<email:jjnapiork@cpan.org>

=head1 SEE ALSO

L<Plack>, L<Plack::App::URLMap>, L<Catalyst>

=head1 COPYRIGHT & LICENSE

Copyright 2012, John Napiorkowski L<email:jjnapiork@cpan.org>

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
