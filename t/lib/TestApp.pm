package TestApp;

use Moose;
use Plack::Middleware::Static;
use Plack::App::File;
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
        if($env->{PATH_INFO} =~m/forced/) {
          Plack::App::File->new(file=>TestApp->path_to(qw/share static forced.txt/))
            ->call($env);
        } else {
          return $app->($env);
        }
      },
    },

  ],
);

__PACKAGE__->setup;
__PACKAGE__->meta->make_immutable;

