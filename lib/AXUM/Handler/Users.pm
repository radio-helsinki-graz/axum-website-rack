
package AXUM::Handler::User;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{users}        => \&user_overview,
  qr{users/([1-9][0-9]*)} => \&user,
  qr{ajax/users}       	  => \&ajax,
  qr{ajax/users/login}    => \&ajax_login,
  qr{ajax/users/write}    => \&ajax_write_chipcard,
);

my @user_levels = ('Idle', 'Unknown user', 'Operator 1', 'Operator 2', 'Supervisor 1', 'Supervisor 2', 'Administrator');
my @pool_levels = ('A', 'B', 'All');

sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("users", %d, "%s", "%s", this, "user_pos_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if($n eq 'username') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("users", %d, "%s", "%s", this)', $d->{number}, $n, $jsval), $v;
  }
  if($n eq 'password') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_pass("users", %d, "%s", "%s", this)', $d->{number}, $n, $jsval), "*****";
  }
  if($n =~ /console([1|2|3|4])_user_level/) {
    a href => '#', onclick => sprintf('return conf_select("users", %d, "%s", %d, this, "level_list", "Select user level ", "Save")', $d->{number}, $n, $v), ($v>1) ? () : (class => 'off'), $user_levels[$v];
  }
  if($n =~ /console([1|2|3|4])_login/) {
     input type => 'button', onclick => sprintf('return conf_select("users/login", %d, "%s", %d, this, "user_list", "Select user ", "Login")', $d->{number}, $n, $v), value => 'Login';
  }
  if($n =~ /console([1|2|3|4])_write/) {
     input type => 'button', onclick => sprintf('return conf_select("users/write", %d, "%s", %d, this, "user_list", "Select user ", "Write")', $d->{number}, $n, $v), value => 'Write';
  }
  if($n =~ /console([1|2|3|4])_preset$/) {
    my $s;
    for my $l (@$lst) {
      if ($l->{number} == $v)
      {
        $s = $l;
      }
    }
    a href => '#', onclick => sprintf('return conf_select("users", %d, "%s", %d, this, "preset_list", "Select preset ", "Save")', $d->{number}, $n, $v),
    ((not defined $v) or ($v == 'NULL')) ? ((class => 'off'), 'None') : $s->{label};
  }
  if($n =~ /console([1|2|3|4])_sourcepool/) {
    a href => '#', onclick => sprintf('return conf_select("users", %d, "%s", %d, this, "pool_list", "Select pool ", "Save")', $d->{number}, $n, $v),
    ($v == 2) ? (class => 'off') : (), $pool_levels[$v];
  }
  if($n =~ /console([1|2|3|4])_presetpool/) {
    a href => '#', onclick => sprintf('return conf_select("users", %d, "%s", %d, this, "pool_list", "Select pool ", "Save")', $d->{number}, $n, $v),
    ($v == 2) ? (class => 'off') : (), $pool_levels[$v];
  }
  if ($n =~ /username([1|2|3|4])/) {
    if ($v ne '') {
      table width => '100%';
       Tr;
        td style => 'border: 0px', width => '100%'; txt $v; end;
        td style => 'border: 0px', aligh => 'right';
          if (!$d->{"${n}found"}) {
            form method => 'POST';
             input type=>'hidden', name=>'username', value => $v;
             input type=>'hidden', name=>'password', value => $d->{"password$1"};
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
    $self->resRedirect('/users', 'post');
  } else {
    txt "Error: user '$f->{username}' already exists.";
    br;
    br;
    a href => '/users', 'return';
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
    return $self->resRedirect('/users', 'temp');
  }
  my $users = $self->dbAll(q|SELECT pos, number, username, password,
                                    console1_user_level, console2_user_level, console3_user_level, console4_user_level,
                                    console1_preset, console2_preset, console3_preset, console4_preset,
                                    console1_sourcepool, console2_sourcepool, console3_sourcepool, console4_sourcepool,
                                    console1_presetpool, console2_presetpool, console3_presetpool, console4_presetpool
                             FROM users ORDER BY pos|);

  my $g = $self->dbRow(q|SELECT username1, username2, username3, username4, password1, password2, password3, password4,
                                (SELECT COUNT(*) FROM users WHERE username = username1 AND password = password1) AS username1found,
                                (SELECT COUNT(*) FROM users WHERE username = username2 AND password = password2) AS username2found,
                                (SELECT COUNT(*) FROM users WHERE username = username3 AND password = password3) AS username3found,
                                (SELECT COUNT(*) FROM users WHERE username = username4 AND password = password4) AS username4found
                         FROM global_config|);

  my $console_presets = $self->dbAll(q|SELECT pos, number, label FROM console_preset ORDER BY pos|);
  my $max_pos;

  $self->htmlHeader(title => 'Users', page => 'users');
  div id => 'user_list', class => 'hidden';
   Select;
    $max_pos = 0;
    for (@$users) {
      option value => "$_->{pos}", $_->{username};
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
    option value => "$_", $user_levels[$_] for (0..6);
   end;
  end;
  div id => 'preset_list', class => 'hidden';
   Select;
    option value => 'NULL', 'None';
    for (@$console_presets) {
      option value => "$_->{number}", $_->{label};
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
   Tr; th colspan => 20, 'Users'; end;
   Tr;
    th colspan => 3, '';
    th colspan => 4, "Console $_" for (1..4);
    th '';
   end;
   Tr;
    td colspan => 3, '';
    for (1..4) {
      td colspan => 4;
        _col "console${_}_login";
        _col "console${_}_write";
      end;
    }
    td '';
   end;
   Tr;
    td colspan => 3, 'Chipcard account';
    for (1..4) {
      td colspan => 4;
        _col "username$_", $g;
      end;
    }
    td '';
   end;
   Tr;
    th colspan => 3, '';
    for (1..4) {
      th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")';
       txt 'User'; br;
       txt 'level';
      end;
      th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")';
       txt 'Console'; br;
       txt 'preset';
      end;
      th colspan => 2, 'Pool';
    }
    th '';
   end;
   Tr;
    th 'Nr';
    th 'Username';
    th 'Password';
    for (1..4) {
      th 'Source';
      th 'Preset';
    }
    th '';
   end;

   for my $u (@$users) {
     Tr;
      th; _col 'pos', $u; end;
      td; _col 'username', $u; end;
      td; _col 'password', $u; end;
      for (1..4) {
        td; _col "console${_}_user_level", $u; end;
        td; _col "console${_}_preset", $u, $console_presets; end;
        td; _col "console${_}_sourcepool", $u; end;
        td; _col "console${_}_presetpool", $u; end;
      }
      td;
       a href => '/users?del='.$u->{number}, title => 'Delete';
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
    map +(
      { name => "console${_}_user_level", required => 0, enum => [ 0..6 ] },
      { name => "console${_}_preset", required => 0, regex => [ qr/[NULL|\d]/, 0 ] },
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
      for(qw|username password|,
             (map("console${_}_user_level", 1..4)),
             (map("console${_}_preset", 1..4)),
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

