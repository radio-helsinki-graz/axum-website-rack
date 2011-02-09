
package AXUM::Handler::System;

use strict;
use warnings;
use YAWF ':html';
use POSIX qw(strftime);


YAWF::register(
  qr{system} => \&system,
  qr{system/functions} => \&functions,
  qr{system/versions} => \&versions,
  qr{system/password} => \&password,
  qr{system/ssh} => \&ssh,
  qr{system/logs} => \&logs,
  qr{ajax/system} => \&ajax,
  qr{ajax/system/account} => \&set_account,
  qr{ajax/system/user_level} => \&set_user_level,
  qr{ajax/system/state} => \&server_state,
);

my @mbn_types = ('no data', 'unsigned int', 'signed int', 'state', 'octet string', 'float', 'bit string');
my @func_types = ('Module', 'Buss', 'Monitor buss', 'Console', 'Global', 'Source', 'Destination');

sub system {
  my $self = shift;
  my $i=1;

  $self->htmlHeader(title => $self->OEMFullProductName().' system pages', area => 'system');
  table;
   Tr; th colspan => 2, $self->OEMFullProductName().' system configuration'; end;
   Tr; th $i++; td; a href => '/system/mambanet', 'MambaNet node overview'; end; end;
   Tr; th $i++; td; a href => '#', onclick => 'return msg_box("Are you sure to remove all current sources and generate new sources?", "/config/source/generate")', 'Generate sources'; end; end;
   Tr; th $i++; td; a href => '#', onclick => 'return msg_box("Are you sure to remove all current destination and generate new destinations?", "/config/dest/generate")', 'Generate destinations'; end; end;
   Tr; th $i++; td; a href => '/system/templates', 'Templates'; end; end;
   Tr; th $i++; td; a href => '/system/predefined', 'Predefined node configurations'; end; end;
   Tr; th $i++; td; a href => '/system/functions', 'Engine functions'; end; end;
   Tr; th $i++; td; a href => '/system/versions?pkg='.$self->OEMShortProductName(), 'Package versions'; end; end;
   Tr; th $i++; td; a href => '#', onclick => "window.location = 'http://'+window.location.host+':6565'", 'Download backup'; end; end;
   Tr; th $i++; td; a href => '/system/password', 'Change web accounts'; end; end;
   Tr; th $i++; td; a href => '/system/ssh', 'SSH'; end; end;
   Tr; th $i++; td; a href => '/system/logs', 'Log files'; end; end;
  end;
  $self->htmlFooter;
}

sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("system", "%d|%d|%d|%d", "%s", "%s", this, "func_list", "Place before ", "Move")', $d->{rcv_type}, $d->{xmt_type}, $d->{type}, $d->{func}, $n, "$d->{pos}"), $v;
  }
  if ($n eq 'label') {
    a href => '#', onclick => sprintf('return conf_text("system", "%d|%d|%d|%d", "%s", "%s", this, "Label", "Save")', $d->{rcv_type}, $d->{xmt_type}, $d->{type}, $d->{func}, $n, $v), $v;
  }
  if ($n =~ /^user_level[0-5]/) {
    if ($d->{rcv_type} != 0) {
      a href => '#', onclick => sprintf('return conf_set("system", "%d|%d|%d|%d", "%s", "%s", this)', $d->{rcv_type}, $d->{xmt_type}, $d->{type}, $d->{func}, $n, $v?0:1), $v ? 'y' : (class => 'off', 'n');
    }
  }
  if ($n =~ /^all_user_level([0-5])/) {
    my @user_level_names  = ('Idle', 'Unkown', 'Operator 1', 'Operator 2', 'Supervisor 1', 'Supervisor 2');

    a href => '#', onclick => sprintf('if (confirm("Override all \'%s\' settings?")) {return conf_set("system", "all", "user_level%d", "%s", this)}', $user_level_names[$1], $1, 1), 'y';
    txt ' / ';
    a href => '#', onclick => sprintf('if (confirm("Override all \'%s\' settings?")) {return conf_set("system", "all", "user_level%d", "%s", this)}', $user_level_names[$1], $1, 0), 'n';
  }
}

sub functions {
  my $self = shift;

  my $src = $self->dbAll(q|SELECT pos, (func).type AS type, (func).func AS func, name, rcv_type, xmt_type, label, user_level0, user_level1, user_level2, user_level3, user_level4, user_level5 FROM functions ORDER BY pos|);

  $self->htmlHeader(title => $self->OEMFullProductName().' system pages', area => 'system', page => 'functions');

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
   Tr; th colspan => 12, $self->OEMFullProductName().' functions'; end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'pos';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'type';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'function';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'rcv';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'xmt';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'label';
    th 'idle';
    th 'unkn';
    th 'oper1';
    th 'oper2';
    th 'super1';
    th 'super2';
   end;
   Tr;
    for (0..5) {
      td; _col "all_user_level$_"; end;
    }
   end;
   for my $s (@$src) {
     Tr;
      th; _col 'pos', $s; end;
      td $func_types[$s->{type}];
      td $s->{name};
      td $mbn_types[$s->{rcv_type}];
      td $mbn_types[$s->{xmt_type}];
      td; _col 'label', $s; end;
      for (0..5) {
        td; _col "user_level$_", $s; end;
      }
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
    map +(
      { name => "user_level${_}", required => 0, enum => [0,1] },
    ), 0..5
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
  if ($f->{field} =~ /user_level([0-5])/)
  {
    my $db_data = $f->{$f->{field}} ? ('true') : ('false');
    if ($f->{item} =~ /(\d+)\|(\d+)\|(\d+)\|(\d+)/) {
      my $rcv_type = $1;
      my $xmt_type = $2;
      my $type = $3;
      my $func = $4;

      $self->dbExec("UPDATE functions SET $f->{field} = $db_data
                     WHERE rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func;");
      txt _col $f->{field}, {$f->{field} => $f->{$f->{field}}, rcv_type => $rcv_type, xmt_type => $xmt_type, type => $type, func => $func};
    } else {
      $self->dbExec("UPDATE functions SET $f->{field} = $db_data;");
      txt 'Wait for reload';
    }
  }
}

sub versions {
  my $self = shift;
  my $f = $self->formValidate(
    { name => 'pkg', template => 'asciiprint' },
  );

  $self->htmlHeader(title => $self->OEMFullProductName().' system pages', area => 'system', page => 'versions');

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

  if ($n =~ /(config|system)_(user|password)/) {
    if ($2 eq 'user') {
      a href => '#', onclick => sprintf('return conf_text("system/account", %d, "%s", "%s", this, "User", "Save")', $d->{line}, $n, $d->{$n}), $d->{$n} ? ($d->{$n}) : (class => 'off', 'None');
    } else {
      a href => '#', onclick => sprintf('return conf_pass("system/account", %d, "%s", "%s", this, "User", "Save")', $d->{line}, $n, $d->{$n}), '****';
    }
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
  open(FILE, '/etc/lighttpd/.lighttpdpassword_config');
  my @array = <FILE>;
  $array[$line] =~ m/(.*):(.*)/;
  my $config_account = { line => $line, config_user => $1, config_password => $2 };
  close FILE;

  open(FILE, '/etc/lighttpd/.lighttpdpassword_system');
  my @array = <FILE>;
  $array[$line] =~ m/(.*):(.*)/;
  my $system_account = { line => $line, system_user => $1, system_password => $2 };
  close FILE;

  $self->htmlHeader(title => $self->OEMFullProductName().' system pages', area => 'system', page => 'password');
  table;
   Tr; th colspan => 2, 'Console 1-4 configuration account'; end;
   Tr; th 'User'; th 'Password'; end;
   Tr;
    td; _password_col 'config_user', $config_account; end;
    td; _password_col 'config_password', $config_account; end;
   end;
   Tr class => 'empty'; th colspan => 2; end; end;
   Tr; th colspan => 2, 'System configuration account'; end;
   Tr; th 'User'; th 'Password'; end;
   Tr;
    td; _password_col 'system_user', $system_account; end;
    td; _password_col 'system_password', $system_account; end;
   end;
  end;
  $self->htmlFooter;
}

sub set_account {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'item', required => 1, template => 'int' },
    { name => 'field', required => 1, template => 'asciiprint' },
    { name => 'config_user', required => 0, template => 'asciiprint' },
    { name => 'config_password', required => 0, template => 'asciiprint' },
    { name => 'system_user', required => 0, template => 'asciiprint' },
    { name => 'system_password', required => 0, template => 'asciiprint' },
  );
  return 404 if $f->{_err};

  if ($f->{field} =~ /(config|system)_(user|password)/) {
    my $filename = "/etc/lighttpd/.lighttpdpassword_$1";
    my $type = $2;
    my @array;

    open(FILE, $filename);
    @array = <FILE>;

    if ($type eq 'user') {
      $array[$f->{item}] =~ s/^(.*):(.*)/$f->{$f->{field}}:$2/;
    }
    if ($type eq 'password') {
      $array[$f->{item}] =~ s/^(.*):(.*)/$1:$f->{$f->{field}}/;
    }

    my @result = grep(/[^\s]/,@array);
    close FILE;

    open(FILE, ">$filename");
    print FILE @result;
    close FILE;

    $array[$f->{item}] =~ m/(.*):(.*)/;
    _password_col $f->{field}, { line => $f->{item}, $f->{field} => $f->{$f->{field}}};
  }
}

sub ssh {
  my $self = shift;

  $self->htmlHeader(title => $self->OEMFullProductName().' system pages', area => 'system', page => 'ssh');

  table;
   Tr; th colspan => 4, $self->OEMFullProductName().' server'; end;
   Tr;
    th 'name';
    th 'protocol';
    th 'port';
    th 'state';
   end;
   Tr;
    th 'ssh';
    td 'TCP';
    td '22';
    td;
      my @array;
      open(FILE, '/etc/hosts.allow');
      @array = <FILE>;
      for my $i (0..$#array) {
        if ($array[$i] =~ /^ALL: (.*)/) {
          if ($1 =~ /EXCEPT sshd/) {
            a href => '#', onclick => sprintf('return conf_set("system/state", "ssh", "state", 1, this)'), 'disabled';
          } else {
            a href => '#', onclick => sprintf('if (confirm("Are you sure to disabled SSH?\n(WARNING: remote support will be not possible!)")) { return conf_set("system/state", "ssh", "state", 0, this) }'), 'enabled';
          }
        }
      }
    end;
   end;
  end;
  $self->htmlFooter;
}

sub server_state {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'asciiprint' },
    { name => 'state', required => 0, template => 'int' },
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/hosts.allow');
  @array = <FILE>;
  for my $i (0..$#array) {
    if ($array[$i] =~ /^ALL: (.*)/) {
      if ($f->{$f->{field}}) {
        $array[$i] =~ s/^ALL: (.*)/ALL: ALL/;
        a href => '#', onclick => sprintf('if (confirm("Are you sure to disabled SSH?\n(WARNING: remote support will be not possible!)")) { return conf_set("system/state", "ssh", "state", 0, this) }'), 'enabled';
      } else {
        $array[$i] =~ s/^ALL: (.*)/ALL: EXCEPT sshd/;
        a href => '#', onclick => sprintf('return conf_set("system/state", "ssh", "state", 1, this)'), 'disabled';
      }
    }
  }
  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/hosts.allow');
  print FILE @result;
  close FILE;
}

sub logs {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'filename', template => 'asciiprint' },
  );

  if ($f->{_err}) {
    $self->htmlHeader(title => $self->OEMFullProductName().' system pages', area => 'system', page => 'logs');

    table;
     Tr; th colspan => 5, $self->OEMFullProductName().' log files'; end;
     Tr; td; a href => '/system/logs?filename=axum-address.log', 'Address server'; end; end;
     Tr; td; a href => '/system/logs?filename=axum-engine.log', 'Engine'; end; end;
     Tr; td; a href => '/system/logs?filename=axum-gateway.log', 'Gateway'; end; end;
     Tr; td; a href => '/system/logs?filename=axum-learner.log', 'Learner'; end; end;
     Tr; td; a href => '/system/logs?filename=postgresql.log', 'PostGreSQL'; end; end;
    end;
  } else {
    txt "Log file '$f->{filename}.' download at ".strftime("%a %b %e %H:%M:%S %Y", gmtime);
    br; br;
    txt `cat /var/log/$f->{filename}`;
  }

  $self->htmlFooter;
}


1;

