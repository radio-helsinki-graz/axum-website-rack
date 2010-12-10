
package AXUM::Handler::User;

use strict;
use warnings;
use YAWF ':html';
use Data::Dumper;

YAWF::register(
  qr{config/users}        => \&user_overview,
  qr{config/users/([1-9][0-9]*)} => \&user,
  qr{ajax/config/users}       	  => \&ajax,
  qr{ajax/config/users/login}    => \&ajax_login,
  qr{ajax/config/users/write}    => \&ajax_write_chipcard,
);

my @user_levels = ('Idle', 'Unknown user', 'Operator 1', 'Operator 2', 'Supervisor 1', 'Supervisor 2', 'Administrator');
my @pool_levels = ('A', 'B', 'All');

sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("config/users", %d, "%s", "%s", this, "user_pos_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if ($n eq 'active') {
    a href => '#', onclick => sprintf('return conf_set("config/users", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1), $v ? 'y' : (class => 'off', 'n');
  }
  if($n eq 'username') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("config/users", %d, "%s", "%s", this)', $d->{number}, $n, $jsval), $v;
  }
  if($n eq 'password') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_pass("config/users", %d, "%s", "%s", this)', $d->{number}, $n, $jsval), "*****";
  }
  if ($n eq 'logout_to_idle') {
    a href => '#', onclick => sprintf('return conf_set("config/users", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1), $v ? 'y' : (class => 'off', 'n');
  }
  if($n =~ /console([1|2|3|4])_user_level/) {
    a href => '#', onclick => sprintf('return conf_select("config/users", %d, "%s", %d, this, "level_list", "Select user level ", "Save")', $d->{number}, $n, $v), ($v>1) ? () : (class => 'off'), $user_levels[$v];
  }
  if($n =~ /console([1|2|3|4])_login/) {
     input type => 'button', onclick => sprintf('return conf_select("config/users/login", %d, "%s", %d, this, "user_list", "Select user ", "Login")', $1, $n, 0), value => 'Login';
  }
  if($n =~ /console([1|2|3|4])_write/) {
     input type => 'button', onclick => sprintf('return conf_select("config/users/write", %d, "%s", %d, this, "user_list", "Select user ", "Write")', $1, $n, 0), value => 'Write';
  }
  if($n =~ /console([1|2|3|4])_preset$/) {
    my $s;

    $v = 0 if not defined $v;

    for my $l (@$lst) {
      if ($l->{pos} == $v)
      {
        $s = $l;
      }
    }
    a href => '#', onclick => sprintf('return conf_select("config/users", %d, "%s", %d, this, "preset_list", "Select preset ", "Save")', $d->{number}, $n, $v),
    ((not defined $v) or ($v == 0)) ? ((class => 'off'), 'None') : $s->{label};
  }
  if ($n =~ /console([1|2|3|4])_preset_load/) {
    a href => '#', onclick => sprintf('return conf_set("config/users", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1), $v ? 'y' : (class => 'off', 'n');
  }
  if($n =~ /console([1|2|3|4])_sourcepool/) {
    a href => '#', onclick => sprintf('return conf_select("config/users", %d, "%s", %d, this, "pool_list", "Select pool ", "Save")', $d->{number}, $n, $v),
    ($v == 2) ? (class => 'off') : (), $pool_levels[$v];
  }
  if($n =~ /console([1|2|3|4])_presetpool/) {
    a href => '#', onclick => sprintf('return conf_select("config/users", %d, "%s", %d, this, "pool_list", "Select pool ", "Save")', $d->{number}, $n, $v),
    ($v == 2) ? (class => 'off') : (), $pool_levels[$v];
  }
  if ($n =~ /active_username/) {
    if ($v ne '')
    {
      table width => '100%';
       Tr;
        td style => 'border: 0px', width => '100%'; txt $v; end;
        td style => 'border: 0px', aligh => 'right';
         input type => 'button', onclick => sprintf('return conf_set("config/users/login", %d, "logout", "1", this)', $d->{number}), value => 'Logout';
        end;
       end;
      end;
    }
  }
  if ($n =~ /chipcard_username/) {
    if ($d->{chipcard_username} ne '') {
      table width => '100%';
       Tr;
        td style => 'border: 0px', width => '100%'; txt $d->{chipcard_username}; end;
        td style => 'border: 0px', aligh => 'right';
          if (!$d->{"accountfound"}) {
            form method => 'POST';
             input type=>'hidden', name=>'username', value => $d->{chipcard_username};
             input type=>'hidden', name=>'password', value => $d->{chipcard_password};
             input type=>'submit', value => 'Add';
            end;
          }
        end;
       end;
      end;
    }
  }
}

sub _create_user {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'username', required => 1, minlength => 1, maxlength => 32 },
    { name => 'password', required => 0, minlength => 1, maxlength => 32 },
  );
  die "Invalid input" if $f->{_err};

  $f->{password} = "" if not defined $f->{password};

  if ($self->dbRow(q|SELECT COUNT(*) FROM users WHERE username = ?|, $f->{username})->{count} == '0') {
    # get new free preset number
    my $num = $self->dbRow(q|SELECT gen
      FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM users), 1)) AS g(gen)
      WHERE NOT EXISTS(SELECT 1 FROM users WHERE number = gen)
      LIMIT 1|
    )->{gen};

    # insert row
    $self->dbExec(q|
      INSERT INTO users (number, username, password) VALUES (!l)|,
      [ $num, $f->{username}, $f->{password}]);

    $self->dbExec("SELECT users_renumber()");
    $self->resRedirect('/config/users', 'post');
  } else {
    txt "Error: user '$f->{username}' already exists.";
    br;
    br;
    a href => '/config/users', 'return';
  }
}

sub user_overview {
  my $self = shift;

  # if POST, insert new preset
  return _create_user($self) if $self->reqMethod eq 'POST';

  # if del, remove source
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    txt "Do delete";
    $self->dbExec('DELETE FROM users WHERE number = ?', $f->{del});
    $self->dbExec("SELECT users_renumber()");
    return $self->resRedirect('/config/users', 'temp');
  }
  my $users = $self->dbAll(q|SELECT pos, number, active, username, password, logout_to_idle,
                                    console1_user_level, console2_user_level, console3_user_level, console4_user_level,
                                    console1_preset, console2_preset, console3_preset, console4_preset,
                                    console1_preset_load, console2_preset_load, console3_preset_load, console4_preset_load,
                                    console1_sourcepool, console2_sourcepool, console3_sourcepool, console4_sourcepool,
                                    console1_presetpool, console2_presetpool, console3_presetpool, console4_presetpool
                             FROM users ORDER BY pos|);

  my $c = $self->dbAll(q|SELECT c.number, c.username AS active_username, c.chipcard_username, c.chipcard_password, (SELECT COUNT(*) FROM users u WHERE u.username = c.chipcard_username AND u.password = c.chipcard_password) AS accountfound
                         FROM console_config c
                         ORDER BY c.number|);

  my $console_presets = $self->dbAll(q|SELECT pos, number, label FROM console_preset ORDER BY pos|);
  my $max_pos;

  $self->htmlHeader(title => 'Users', area => 'config', page => 'users');
  div id => 'user_list', class => 'hidden';
   Select;
    $max_pos = 0;
    for (@$users) {
      option value => "$_->{number}", $_->{username};
      $max_pos = $_->{pos} if ($_->{pos} > $max_pos);
    }
   end;
  end;
  div id => 'user_pos_list', class => 'hidden';
   Select;
    $max_pos = 0;
    for (@$users) {
      option value => "$_->{pos}", $_->{username};
      $max_pos = $_->{pos} if ($_->{pos} > $max_pos);
    }
    option value => $max_pos+1, "last";
   end;
  end;
  div id => 'level_list', class => 'hidden';
   Select;
    option value => "$_", $user_levels[$_] for (2..6);
   end;
  end;
  div id => 'preset_list', class => 'hidden';
   Select;
    option value => 'NULL', 'None';
    for (@$console_presets) {
      option value => "$_->{pos}", $_->{label};
    }
   end;
  end;
  div id => 'pool_list', class => 'hidden';
   Select;
    option value => '0', 'A';
    option value => '1', 'B';
    option value => '2', 'All';
   end;
  end;
  table;
   Tr; th colspan => 26, 'Users'; end;
   Tr;
    th colspan => 5, '';
    th colspan => 5, "Console $_" for (1..4);
    th '';
   end;
   Tr;
    td colspan => 5, '';
    for (1..4) {
      td colspan => 5;
        _col "console${_}_login";
        _col "console${_}_write";
      end;
    }
    td '';
   end;
   Tr;
    td colspan => 5, 'Active account';
    for (1..4) {
      td colspan => 5;
        _col 'active_username', @$c[$_-1];
      end;
    }
    td '';
   end;
   Tr;
    td colspan => 5, 'Chipcard account';
    for (1..4) {
      td colspan => 5;
        _col 'chipcard_username', @$c[$_-1];
      end;
    }
    td '';
   end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Nr';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Active';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Username';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Password';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Logout to idle';
    for (1..4) {
      th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")';
       txt 'User'; br;
       txt 'level';
      end;
      th colspan => 2;
       txt 'Preset';
      end;
      th colspan => 2, 'Pool';
    }
    th '';
   end;
   Tr;
    for (1..4) {
      th 'Nr';
      th 'Load';
      th 'Source';
      th 'Preset';
    }
    th '';
   end;

   for my $u (@$users) {
     Tr $u->{active} ? () : (class => 'inactive');
      th; _col 'pos', $u; end;
      td; _col 'active', $u; end;
      td; _col 'username', $u; end;
      td; _col 'password', $u; end;
      td; _col 'logout_to_idle', $u; end;
      for (1..4) {
        td; _col "console${_}_user_level", $u; end;
        td; _col "console${_}_preset", $u, $console_presets; end;
        td; _col "console${_}_preset_load", $u; end;
        td; _col "console${_}_sourcepool", $u; end;
        td; _col "console${_}_presetpool", $u; end;
      }
      td;
       a href => '/config/users?del='.$u->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
     end;
   }
  end;
  br;
  br;
  a href => '#', onclick => 'return conf_adduser(this, "Create")', 'Create new user';

  $self->htmlFooter;
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'username', required => 0, maxlength => 32, minlength => 1 },
    { name => 'password', required => 0, maxlength => 32, minlength => 1 },
    { name => 'pos', required => 0, template => 'int' },
    { name => 'active', required => 0, enum => [ 0, 1 ] },
    { name => 'logout_to_idle', required => 0, enum => [ 0, 1 ] },
    map +(
      { name => "console${_}_user_level", required => 0, enum => [ 0..6 ] },
      { name => "console${_}_preset", required => 0, regex => [ qr/[NULL|\d]/, 0 ] },
      { name => "console${_}_preset_load", required => 0, enum => [ 0, 1 ] },
      { name => "console${_}_sourcepool", required => 0, enum => [ 0..2 ] },
      { name => "console${_}_presetpool", required => 0, enum => [ 0..2 ] },
    ), 1..4
  );
  return 404 if $f->{_err};

  #if field returned is 'pos', the positions of other rows may change...
  if($f->{field} eq 'pos') {
    $self->dbExec("UPDATE users SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND number <> $f->{item} THEN pos
                    WHEN pos >= $f->{pos} AND number <> $f->{item} THEN pos+1
                    WHEN number = $f->{item} THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT users_renumber();");
    #_col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
    txt 'Wait for reload';
  } else {
    my %set;
    defined $f->{$_} and ($f->{$_} eq 'NULL' ? ($set{"$_ = NULL"} = 0) :($set{"$_ = ?"} = $f->{$_}))
      for(qw|username password logout_to_idle active|,
             (map("console${_}_user_level", 1..4)),
             (map("console${_}_preset", 1..4)),
             (map("console${_}_preset_load", 1..4)),
             (map("console${_}_sourcepool", 1..4)),
             (map("console${_}_presetpool", 1..4)));

    $self->dbExec('UPDATE users !H WHERE number = ?', \%set, $f->{item}) if keys %set;
    _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
      $f->{field} =~ /console[1|2|3|4]_preset/ ? $self->dbAll(q|SELECT pos, number, label FROM console_preset ORDER BY number|) : ()
  }
}

sub ajax_login {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'logout', enum => [ 1 ] },
    map +(
      { name => "console${_}_login", required => 0, template => 'int' },
    ), 1..4
  );
  return 404 if $f->{_err};

  if ($f->{field} =~ /console([1|2|3|4])_login/) {
    $self->dbExec('INSERT INTO recent_changes (change, arguments) VALUES(\'login\', ?||\' \'||?)', $1, $f->{$f->{field}});
    _col $f->{field};
    _col "console$1_write";
  }
  if ($f->{field} eq 'logout')
  {
    $self->dbExec('INSERT INTO recent_changes (change, arguments) VALUES(\'login\', ?||\' \'||0)', $f->{item});
    txt 'Done';
  }
}

sub ajax_write_chipcard {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    map +(
      { name => "console${_}_write", required => 0, template => 'int' },
    ), 1..4
  );
  return 404 if $f->{_err};

  if ($f->{field} =~ /console([1|2|3|4])_write/) {
    $self->dbExec('INSERT INTO recent_changes (change, arguments) VALUES(\'write\', ?||\' \'||?)', $1, $f->{$f->{field}});
    _col "console$1_login";
    _col $f->{field};
  }
}

