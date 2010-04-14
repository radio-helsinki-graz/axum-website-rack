
package AXUM::Handler::ConsolePreset;

use strict;
use warnings;
use YAWF ':html';

YAWF::register(
  qr{consolepreset}               => \&consolepreset,
  qr{ajax/consolepreset}             => \&ajax,
);

my @buss_names = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;
my @ext_names = map sprintf('ext_%d', $_), 1..8;

# display the value of a column
# arguments: column name, database return object
sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("consolepreset", %d, "%s", "%s", this, "console_preset_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("consolepreset", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if ($n eq 'mod_preset') {
    my $label = 'none';
    if ($v) {
      my $number = int(((ord($v)-ord('A'))/2)+1);
      my $char = ((ord($v)&1) ? ('A'):('B'));
      $label = "$number$char";
    } else {
      $v = 'NULL';
    }
    a href => '#', onclick => sprintf('return conf_select("consolepreset", %d, "%s", "%s", this, "mod_preset_list", "Select module preset", "Save")', $d->{number}, $n, $v), $v eq 'NULL' ? ('None') : ($label);
  }
  if ($n eq 'buss_preset') {
    my $s->{label} = 'None';
    for my $l (@$lst) {
      if ($l->{number} == $v) {
        $s = $l;
      }
    }
    a href => '#', onclick => sprintf('return conf_select("consolepreset", %d, "%s", "%s", this, "buss_preset_list", "Select buss preset", "Save")', $d->{number}, $n, $v),
      ($s->{label} eq 'none') ? (class => 'off') : (), $s->{label};
  }
  if ($n =~ /console[1|2|3|4]/) {
   a href => '#', onclick => sprintf('return conf_set("consolepreset", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
     $v ? 'y' : (class => 'off', 'n');
  }
}

sub _create_console_preset {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'label', minlength => 1, maxlength => 32 },
  );
  die "Invalid input" if $f->{_err};

  # get new free preset number
  my $num = $self->dbRow(q|SELECT gen
    FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM console_preset), 1)) AS g(gen)
    WHERE NOT EXISTS(SELECT 1 FROM console_preset WHERE number = gen)
    LIMIT 1|
  )->{gen};
  # insert row
  $self->dbExec(q|
    INSERT INTO console_preset (number, label) VALUES (!l)|,
    [ $num, $f->{label}]);
  $self->dbExec("SELECT console_preset_renumber()");
  $self->resRedirect('/consolepreset', 'post');
}

sub consolepreset {
  my $self = shift;

  # if POST, insert new preset
  return _create_console_preset($self) if $self->reqMethod eq 'POST';

  # if del, remove source
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    $self->dbExec('DELETE FROM console_preset WHERE number = ?', $f->{del});
    $self->dbExec("SELECT console_preset_renumber()");
    return $self->resRedirect('/consolepreset', 'temp');
  }
  my $presets = $self->dbAll(q|SELECT pos, number, label, console1, console2, console3, console4, mod_preset, buss_preset
    FROM console_preset ORDER BY pos|);

  my $buss_preset = $self->dbAll(q|SELECT pos, number, label FROM buss_preset ORDER BY pos|);

  $self->htmlHeader(title => 'Console presets', page => 'consolepreset');
  div id => 'console_preset_list', class => 'hidden';
   Select;
    my $max_pos;
    $max_pos = 0;
    for (@$presets) {
      option value => "$_->{pos}", $_->{label};
      $max_pos = $_->{pos} if ($_->{pos} > $max_pos);
    }
    option value => $max_pos+1, "last";
   end;
  end;
  div id => 'mod_preset_list', class => 'hidden';
   Select;
    option value => 'NULL', 'None';
    for ('A'..'H') {
      my $number = int(((ord($_)-ord('A'))/2)+1);
      my $char = ((ord($_)&1) ? ('A'):('B'));
      option value => $_, "$number$char";
    }
   end;
  end;
  div id => 'buss_preset_list', class => 'hidden';
   Select;
    option value => 'NULL', 'None';
    option value => $_->{number}, $_->{label} for (@$buss_preset);
   end;
  end;
  table;
   Tr;
    th colspan => 9, 'Console presets';
   end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Nr';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Label';
    th colspan => 4, 'Console';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Module\npreset";
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Mix/monitor\nbuss preset";
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', '';
   end;
   Tr;
    th '1';
    th '2';
    th '3';
    th '4';
   end;

   for my $p (@$presets) {
     Tr;
      th; _col 'pos', $p; end;
      td; _col 'label', $p; end;
      td; _col 'console1', $p; end;
      td; _col 'console2', $p; end;
      td; _col 'console3', $p; end;
      td; _col 'console4', $p; end;
      td; _col 'mod_preset', $p; end;
      td; _col 'buss_preset', $p, $buss_preset; end;
      td;
       a href => '/consolepreset?del='.$p->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
     end;
   }
  end;
  br; br;
  a href => '#', onclick => 'return conf_addpreset(this)', 'Create new console preset';

  $self->htmlFooter;
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' }, # should have an enum property
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, template => 'asciiprint' },
    { name => 'pos', required => 0, template => 'int' },
    { name => 'mod_preset', required => 0, regex => [ qr/[NULL|A|B|C|D|E|F|G|H]/, 0 ] },
    { name => 'buss_preset', required => 0, regex => [ qr/[NULL|\d{1,4}]/, 0] },
    (map +{ name => "console$_", required => 0, enum => [0,1] }, 1..4),
  );
  return 404 if $f->{_err};

  if($f->{field} eq 'pos') {
    $self->dbExec("UPDATE console_preset SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND number <> $f->{item} THEN pos
                    WHEN pos >= $f->{pos} AND number <> $f->{item} THEN pos+1
                    WHEN number = $f->{item} THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT console_preset_renumber();");
    txt 'Wait for reload';
  } else {
    my %set;
    defined $f->{$_} and ($f->{$_} eq 'NULL' ? ($set{"$_ = NULL"} = 0) :($set{"$_ = ?"} = $f->{$_}))
      for(qw|label console1 console2 console3 console4 mod_preset buss_preset|);
    $self->dbExec('UPDATE console_preset !H WHERE number = ?', \%set, $f->{item}) if keys %set;
    _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
      ($f->{field} eq 'buss_preset') ? ($self->dbAll(q|SELECT number, label FROM buss_preset ORDER BY pos|)) : ();
  }
}


1;

