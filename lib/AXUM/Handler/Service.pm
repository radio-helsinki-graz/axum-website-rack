
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{service} => \&service,
  qr{service/functions} => \&functions,
  qr{service/versions} => \&versions,
  qr{service/password} => \&password,
  qr{ajax/service} => \&ajax,
  qr{ajax/service/account} => \&set_account,
);

my @mbn_types = ('no data', 'unsigned int', 'signed int', 'state', 'octet string', 'float', 'bit string');
my @func_types = ('Module', 'Buss', 'Monitor buss', 'None', 'Global', 'Source', 'Destination');

sub service {
  my $self = shift;

  $self->htmlHeader(title => $self->OEMFullProductName().' service pages', page => 'service');
  table;
   Tr; th colspan => 2, $self->OEMFullProductName().' service'; end;
   Tr; th 1; td; a href => '/service/mambanet', 'MambaNet node overview'; end; end;
   Tr; th 2; td; a href => '#', onclick => 'return msg_box("Are you sure to remove all current sources and generate new sources?", "/source/generate")', 'Generate sources'; end; end;
   Tr; th 3; td; a href => '#', onclick => 'return msg_box("Are you sure to remove all current destination and generate new destinations?", "/dest/generate")', 'Generate destinations'; end; end;
   Tr; th 4; td; a href => '/service/templates', 'Templates'; end; end;
   Tr; th 5; td; a href => '/service/predefined', 'Stored configurations'; end; end;
   Tr; th 6; td; a href => '/service/functions', 'Engine functions'; end; end;
   Tr; th 7; td; a href => '/service/versions?pkg='.$self->OEMShortProductName(), 'Package versions'; end; end;
   Tr; th 8; td; a href => '#', onclick => "window.location = 'http://'+window.location.host+':6565'", 'Download backup'; end; end;
   Tr; th 9; td; a href => '/service/password', 'Change password'; end; end;
  end;
  $self->htmlFooter;
}

sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("service", "%d|%d|%d|%d", "%s", "%s", this, "func_list", "Place before ", "Move")', $d->{rcv_type}, $d->{xmt_type}, $d->{type}, $d->{func}, $n, "$d->{pos}"), $v;
  }
  if ($n eq 'label') {
    a href => '#', onclick => sprintf('return conf_text("service", "%d|%d|%d|%d", "%s", "%s", this, "Label", "Save")', $d->{rcv_type}, $d->{xmt_type}, $d->{type}, $d->{func}, $n, $v), $v;
  }
}

sub functions {
  my $self = shift;

  my $src = $self->dbAll(q|SELECT pos, (func).type AS type, (func).func AS func, name, rcv_type, xmt_type, label FROM functions ORDER BY pos|);

  $self->htmlHeader(title => $self->OEMFullProductName().' service pages', page => 'service', section => 'functions');

  # create list of functions for javascript
  div id => 'func_list', class => 'hidden';
   Select;
   my $max_pos;
    $max_pos = 0;
    for (@$src) {
      option value => "$_->{pos}", $func_types[$_->{type}]." - ".$_->{name};
      $max_pos = $_->{pos} if ($_->{pos} > $max_pos);
    }
    option value => $max_pos+1, "last";
   end;
  end;

  table;
   Tr; th colspan => 6, $self->OEMFullProductName().' functions'; end;
   Tr; th 'pos'; th 'type'; th 'function'; th 'rcv'; th 'xmt'; th 'label'; end;
   for my $s (@$src) {
     Tr;
      th; _col 'pos', $s; end;
      td $func_types[$s->{type}];
      td $s->{name};
      td $mbn_types[$s->{rcv_type}];
      td $mbn_types[$s->{xmt_type}];
      td; _col 'label', $s; end;
     end;
   }
  end;
  $self->htmlFooter;
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'asciiprint' },
    { name => 'pos', required => 0, template => 'int' },
    { name => 'label', required => 0, 'asciiprint' },
  );
  return 404 if $f->{_err};

  #if field returned is 'pos', the positions of other rows may change...
  if($f->{field} eq 'pos') {
    $f->{item} =~ /(\d+)\|(\d+)\|(\d+)\|(\d+)/;
    my $rcv_type = $1;
    my $xmt_type = $2;
    my $type = $3;
    my $func = $4;

    $self->dbExec("UPDATE functions SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND NOT (rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func) THEN pos
                    WHEN pos >= $f->{pos} AND NOT (rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func) THEN pos+1
                    WHEN rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT functions_renumber();");
    txt 'Wait for reload';
  }
  if ($f->{field} eq 'label') {
    $f->{item} =~ /(\d+)\|(\d+)\|(\d+)\|(\d+)/;
    my $rcv_type = $1;
    my $xmt_type = $2;
    my $type = $3;
    my $func = $4;

    $self->dbExec("UPDATE functions SET label = '$f->{label}'
                   WHERE rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func;");
    txt _col $f->{field}, {label => $f->{label}, rcv_type => $rcv_type, xmt_type => $xmt_type, type => $type, func => $func};
  }
}

sub versions {
  my $self = shift;
  my $f = $self->formValidate(
    { name => 'pkg', template => 'asciiprint' },
  );

  $self->htmlHeader(title => $self->OEMFullProductName().' service pages', page => 'service', section => 'versions');

  my $n = 0;
  my @pkgs;
  my $pkgs = `pacman -Qs $f->{pkg}`;
  my @lines = split "\n", $pkgs;
  my $pkginfo;

  table;
   Tr; th colspan => 5, $self->OEMFullProductName().' Package versions'; end;
   Tr; th 'Package name'; th 'Version'; th 'Build date'; th 'Install date'; end;
   for (@lines) {
     $_ =~ s/^\S+\///g;
     if ($_ =~ /^\s+/) {
     } else {
       Tr;
        $_ =~ /(.*)\s(.*)/;
        $pkginfo = `pacman -Qi $1`;
        $pkginfo =~ /Name\s+:(.*)/;
        td $1;
        $pkginfo =~ /Version\s+:(.*)/;
        td $1;
        $pkginfo =~ /Build Date\s+:(.*)/;
        td $1;
        $pkginfo =~ /Install Date\s+:(.*)/;
        td $1;
       end;
     }
   }
  end;

   $self->htmlFooter;
}

sub _password_col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if (($n eq 'user') or ($n eq 'password')) {
    a href => '#', onclick => sprintf('return conf_text("service/account", %d, "%s", "%s", this, "User", "Save")', $d->{line}, $n, $d->{$n}), $d->{$n};
  }
}

sub password {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'line', template => 'int' },
  );
  my $line = $f->{line};
  $line = 1 if ($line eq '');

  my $user = "";
  my $pass = "";
  open(FILE, '/etc/lighttpd/.lighttpdpassword');
  my @array = <FILE>;

  $array[$line] =~ m/(.*):(.*)/;

  my $account = { line => $line, user => $1, password => $2 };

  close FILE;

  $self->htmlHeader(title => $self->OEMFullProductName().' service pages', page => 'service', section => 'password');
  table;
   Tr; th 'User'; th 'Password'; end;
   Tr;
    td; _password_col 'user', $account; end;
    td; _password_col 'password', $account; end;
   end;
  end;
  $self->htmlFooter;
}

sub set_account {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'item', required => 1, template => 'int' },
    { name => 'field', required => 1, template => 'asciiprint' },
    { name => 'user', required => 0, template => 'asciiprint' },
    { name => 'password', required => 0, template => 'asciiprint' },
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/lighttpd/.lighttpdpassword');
  @array = <FILE>;

  if (defined $f->{user}) {
    $array[$f->{item}] =~ s/^(.*):(.*)/$f->{user}:$2/;
  }
  if (defined $f->{password}) {
    $array[$f->{item}] =~ s/^(.*):(.*)/$1:$f->{password}/;
  }

  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/lighttpd/.lighttpdpassword');
  print FILE @result;
  close FILE;

  $array[$f->{item}] =~ m/(.*):(.*)/;
  _password_col $f->{field}, { line => $f->{item}, user => $1, password => $2};
}

1;

