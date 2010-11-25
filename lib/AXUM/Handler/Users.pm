#
package AXUM::Handler::User;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{users}        => \&user_overview,
  qr{users/([1-9][0-9]*)} => \&user,
  qr{ajax/users}       	  => \&ajax,
);

my @user_levels = ('Idle', 'Unknown user', 'Operator 1', 'Operator 2', 'Supervisor 1', 'Supervisor 2', 'System adminsitrator');

sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("users", %d, "%s", "%s", this, "user_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
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
    a href => '#', onclick => sprintf('return conf_select("users", %d, "%s", %d, this, "level_list", "Select user level ", "Save")', $d->{number}, $n, $v), ($v>1) ? () : (class => 'off'), @user_levels[$v];
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
  my $users = $self->dbAll(q|SELECT pos, number, username, password, console1_user_level, console2_user_level, console3_user_level, console4_user_level
    FROM users ORDER BY pos|);

  $self->htmlHeader(title => 'Users', page => 'users');
  div id => 'user_list', class => 'hidden';
   Select;
    my $max_pos;
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
    option value => "$_", @user_levels[$_] for (0..6);
   end;
  end;

  table;
   Tr; th colspan => 8, 'Users'; end;
   Tr;
    th colspan => 3, '';
    th colspan => 4, 'User level';
    th '';
   end;
   Tr;
    th 'Nr';
    th 'Username';
    th 'Password';
    th 'console 1';
    th 'console 2';
    th 'console 3';
    th 'console 4';
    th '';
   end;

   for my $u (@$users) {
     Tr;
      th; _col 'pos', $u; end;
      td; _col 'username', $u; end;
      td; _col 'password', $u; end;
      for (1..4) {
        td; _col "console${_}_user_level", $u; end;
      }
      td;
       a href => '/users?del='.$u->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
     end;
   }
  end;
  br; br;
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
    defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
      for(qw|username password|, (map("console${_}_user_level", 1..4)));
      
    $self->dbExec('UPDATE users !H WHERE number = ?', \%set, $f->{item}) if keys %set;
    _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} }
  }
}

