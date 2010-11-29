
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{} => \&home,
);


sub home {
  my $self = shift;
  my $i = 1;

  $self->htmlHeader(title => $self->OEMFullProductName().' configuration pages', page => 'home');
  table;
   Tr class => 'empty'; th colspan => 2; b, i $self->OEMFullProductName().' configuration'; end; end;
   Tr; th colspan => 2, 'Global configuration'; end;
   Tr; th $i++; td; a href => '/ipclock', 'IP/Clock configuration'; end; end;
   Tr; th $i++; td; a href => '/globalconf', 'Global configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Buss configuration'; end;
   Tr; th $i++; td; a href => '/buss', 'Mix buss configuration'; end; end;
   Tr; th $i++; td; a href => '/monitorbuss', 'Monitor buss configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Matrix settings'; end;
   Tr; th $i++; td; a href => '/source', 'Source configuration'; end; end;
   Tr; th $i++; td; a href => '/externsrc', 'Extern source configuration'; end; end;
   Tr; th $i++; td; a href => '/dest', 'Destination configuration'; end; end;
   Tr; th $i++; td; a href => '/talkback', 'Talkback configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Module settings'; end;
   Tr; th $i++; td; a href => '/preset', 'Processing presets'; end; end;
   Tr; th $i++; td; a href => '/module/assign', 'Module assignment'; end; end;
   Tr; th $i++; td; a href => '/module', 'Module configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Console settings'; end;
   Tr; th $i++; td; a href => '/busspreset', 'Mix/monitor buss presets'; end; end;
   Tr; th $i++; td; a href => '/consolepreset', 'Console presets'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Hardware settings'; end;
   Tr; th $i++; td; a href => '/surface', 'Surface configuration'; end; end;
   Tr; th $i++; td; a href => '/rack', 'Rack configuration'; end; end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'Security settings'; end;
   Tr; th $i++; td; a href => '/sourcepools', 'Source pools'; end; end;
   Tr; th $i++; td; a href => '/presetpools', 'Preset pools'; end; end;
   Tr; th $i++; td; a href => '/users', 'Users'; end; end;
  end;
  $self->htmlFooter;
}


1;

