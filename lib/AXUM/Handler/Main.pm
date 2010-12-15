
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{} => \&home,
  qr{ajax/home} => \&ajax,
);

sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if($n eq 'program_end_time') {
    a href => '#', onclick => sprintf('return conf_text("home", %d, "%s", "%s", this)', $d->{number}, $n, $v), $v;
  }
  if($n eq 'program_end_time_enable') {
    a href => '#', onclick => sprintf('return conf_set_remove("home", %d, "%s", "%s", this, 0)', $d->{number}, $n, $v?0:1),
      $v ? 'y' : (class => 'off', 'n');
  }
}

sub home {
  my $self = shift;
  my $i = 1;

  my $consoles = $self->dbAll(q|SELECT number, name, location, contact, username, program_end_time, program_end_time_enable FROM console_config ORDER BY number|);

  $self->htmlHeader(title => $self->OEMFullProductName().' webpages', area => 'main');
  table;
   Tr class => 'empty'; th colspan => 7; b, i $self->OEMFullProductName().' settings'; end; end;
   Tr; th colspan => 7, 'Information'; end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Console';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Name';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Location';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Contact';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Active user';
    th colspan => 2, 'Program end time';
   end;
   Tr;
    th 'Value';
    th 'Enable';
   end;
   for my $c (@$consoles) {
     Tr;
      th $c->{number};
      td ($c->{name} ne '' ? ("$c->{name}") : (class => 'off', 'None'));
      td ($c->{location} ne '' ? ("$c->{location}") : (class => 'off', 'None'));
      td ($c->{contact} ne '' ? ("$c->{contact}") : (class => 'off', 'None'));
      td ($c->{username} ne '' ? ("$c->{username}") : (class => 'off', 'None'));
      td; _col 'program_end_time', $c; end;
      td; _col 'program_end_time_enable', $c; end;
     end;
   }
   Tr class => 'empty';
    th colspan => 5, '';
    th; i '99:MM:SS is every hour'; end;
    th '';
   end;
  end;

  table;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 1, 'Password protected areas'; end;
   Tr; td; a href => '/config', 'Console 1-4 configuration'; end; end;
   Tr; td; a href => '/system', 'System configuration'; end; end;
  end;
  $self->htmlFooter;
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'program_end_time', required => 0, regex =>  [ qr/^([0-1]?[0-9]|[2][0-3]|[9][9]):([0-5]?[0-9]):([0-5]?[0-9])?$/, 0 ] },
    { name => 'program_end_time_enable', required => 0, enum => [0,1] },
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?", $f->{$_}), grep defined $f->{$_}, qw|program_end_time program_end_time_enable|;
  $self->dbExec('UPDATE console_config !H WHERE number = ?', \%set, $f->{item});

  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}}};
}


1;

