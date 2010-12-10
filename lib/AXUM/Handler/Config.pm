
package AXUM::Handler::Config;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{config} => \&config,
);

sub config {
  my $self = shift;
  my $i = 1;

  $self->htmlHeader(title => $self->OEMFullProductName().' configuration pages', area => 'config');
  table;
   Tr class => 'empty'; th colspan => 2; b, i $self->OEMFullProductName().' configuration'; end; end;
   Tr; th colspan => 2, 'Global configuration'; end;
   Tr; th $i++; td; a href => '/config/ipclock', 'IP/Clock configuration'; end; end;
   Tr; th $i++; td; a href => '/config/globalconf', 'Global configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Buss configuration'; end;
   Tr; th $i++; td; a href => '/config/buss', 'Mix buss configuration'; end; end;
   Tr; th $i++; td; a href => '/config/monitorbuss', 'Monitor buss configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Matrix settings'; end;
   Tr; th $i++; td; a href => '/config/source', 'Source configuration'; end; end;
   Tr; th $i++; td; a href => '/config/externsrc', 'Extern source configuration'; end; end;
   Tr; th $i++; td; a href => '/config/dest', 'Destination configuration'; end; end;
   Tr; th $i++; td; a href => '/config/talkback', 'Talkback configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Module settings'; end;
   Tr; th $i++; td; a href => '/config/preset', 'Processing presets'; end; end;
   Tr; th $i++; td; a href => '/config/module/assign', 'Module assignment'; end; end;
   Tr; th $i++; td; a href => '/config/module', 'Module configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Console settings'; end;
   Tr; th $i++; td; a href => '/config/busspreset', 'Mix/monitor buss presets'; end; end;
   Tr; th $i++; td; a href => '/config/consolepreset', 'Console presets'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Hardware settings'; end;
   Tr; th $i++; td; a href => '/config/surface', 'Surface configuration'; end; end;
   Tr; th $i++; td; a href => '/config/rack', 'Rack configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Security settings'; end;
   Tr; th $i++; td; a href => '/config/sourcepools', 'Source pools'; end; end;
   Tr; th $i++; td; a href => '/config/presetpools', 'Processing preset pools'; end; end;
   Tr; th $i++; td; a href => '/config/users', 'Users'; end; end;
  end;
  $self->htmlFooter;
}


1;

