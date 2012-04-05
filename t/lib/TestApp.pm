package TestApp;

use Moose;
use Plack::Middleware::Static;
use Catalyst qw/EnableMiddleware/;

extends 'Catalyst';

my $static = Plack::Middleware::Static->new(
  path => qr{^/static/}, root => TestApp->path_to('share'));

__PACKAGE__->config(
  'Controller::Root', { namespace => '' },
  'Plugin::EnableMiddleware', [
    $static,
    'Static', { path => qr{^/static2/}, root => TestApp->path_to('share') },
    '+TestApp::Custom', { path => qr{^/static3/}, root => TestApp->path_to('share') },
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

