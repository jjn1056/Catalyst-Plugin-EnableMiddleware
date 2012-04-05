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
L<Plack::Middleware::Session), Debugging (as in L<Plack::Middleware::Debug>)
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

Here we are using our C<psgi> file and some tools that come L<Plack> in order
to enable L<Plack::Middleware::Debug> and L<Plack::Middleware::Session>.  This
is a nice, clean approach that cleanly separates your L<Catalyst> application
from enabled middleware.

However there may be cases when you'd rather enable middleware via you L<Catalyst>
application, rather in a stand alone file.  For example
This plugin lets you mount L<Plack> applications via configuration. For example,
the above mapping could be re-written as follows:

    package MyApp::Web;
    our $VERSION = '0.01';

    use Moose;
    use Catalyst qw/URLMap/;

    extends 'Catalyst';

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/static', { 'File',
          {root => __PACKAGE__->path_to(qw/share web static/)} },
      });

    __PACKAGE__->setup;
    __PACKAGE__->meta->make_immutable;

Then your C<myapp_web.psgi> would simply become:

    #!/usr/bin/env plackup

    use strict;
    use warnings;

    use MyApp::Web;  ## Your subclass of 'Catalyst'
    MyApp::Web->psgi_app;

And we'd manage the URL mappings inside the Catalyst configuration and in your
application class.

You can of course use a configuration file and format (like Config::General)
instead of hard coding your configuration into the main application class.
This would allow you the ability to configure things differently in different
environments (one of the key reasons to take this approach).

The approach isn't 'either/or' and merits to each are apparent.  Choosing one
doesn't preclude the other.

We use L<Plack::App::URLMap> under the hood to perform this work.

=head1 CONFIGURATION

Configuration for this plugin should be a hashref under the top level key
C<Plugin::URLMap>, as in the following:

    __PACKAGE__->config(
      'Plugin::URLMap', \%maps);

Where C<\%maps> has keys that refer to URL paths off your application root
(which is usually '/', but might be some other path if your L<Catalyst>
application itself is mounted into another application) and has values that are
either another hashref or a plain scalar.  In other words:

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/path1' => $name_of_plack_app,
        '/path2 => { $name_of_plack_app => \%init_args },
      });

Where C<$name_of_plack_app> is a scalar referring to the package name of your
L<Plack> class (basically any class that is initialized with C<new> and has 
a method called either C<to_app> or C<psgi_app>, which must return a subref
that conforms to the PSGI specification) and where C<%init_args> are key - value
arguments passed to C<new> at initialization time.

C<$name_of_plack_app> is loaded using the same technique as L<Plack::Builder>,
so if your application is under the L<Plack::App> namespace you can drop that
prefix.  The following two configurations are essentially the same:

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/static', { 'Plack::App::File',
          {root => __PACKAGE__->path_to(qw/share web static/)} },
      });

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/static', { 'File',
          {root => __PACKAGE__->path_to(qw/share web static/)} },
      });


This means if you want to map an application under a different namespace, you
will need (as in L<Plack::Builder>) to prefix C<$name_of_plack_app> with a C<+>
as in the above and following example:

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/git' => '+Gitalist',
      });

I believe this is well optimized for the most common cases, and it also is
consistent with how L<Catalyst> plugins are loaded, so hopefully it will be
a reasonable convention.

=head2 Deep URL Path Mapping

There may be times when you wish to map urls more than one path level from the
root.  For example you might wish to map the url C<http://myapp.com/one/two/>
from an application other than your main L<Catalyst> application.  Here's how
you would do that:

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/one' => {
          '/two' => { '+MyApp::PlackApp', \%init_args },
        },
      });

Basically if your C<$name_of_plack_app> starts with a C</> we assume you are
creating some sub-mappings and proceed like that.  You can add as many levels
of submappings as you wish.

=head2 Mapping Pre-Initialized Plack Applications

In some cases you may wish to map an already initialized L<Plack> application
to a given URL mount.  You may do so by simply passing the instance as the
value of the URL mount string key:

    use Plack::App::File;
    my $static = Plack::App::File->new(
      root => __PACKAGE->path_to(qw/share static));

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/static' => $static,
      });

In this case, your object (such as C<$static>) should support a method called
C<to_app> or C<psgi_app>.

=head2 Mapping a subroutine reference

Similarly to mapping a pre-initialized object, you can map a subroutine
reference.  This subroutine reference should conform to the L<PSGI>
specification:

    __PACKAGE__->config(
      'Plugin::URLMap', {
        '/hello_world' => sub {
          my $env = shift;
          return [ 200,
            ['Content-Type' => 'text/plain'],
            [ 'Hello World' ] ];
        },
      });

=head2 URL Mapping '/'

The '/' mount mapping is reserved for your L<Catalyst> Application.  Trying to
map this path will result in an error.

=head1 AUTHOR

John Napiorkowski L<email:jjnapiork@cpan.org>

=head1 SEE ALSO

L<Plack>, L<Plack::App::URLMap>, L<Catalyst>

=head1 COPYRIGHT & LICENSE

Copyright 2012, John Napiorkowski L<email:jjnapiork@cpan.org>

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
