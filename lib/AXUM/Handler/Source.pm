#
package AXUM::Handler::Source;

use strict;
use warnings;
use YAWF ':html';
use Data::Dumper;


YAWF::register(
  qr{source}            	  => \&source,
  qr{source/generate}   	  => \&generate,
  qr{ajax/source}       	  => \&ajax,
  qr{ajax/source/([1-9][0-9]*)/eq} => \&eqajax,
);

my @start_trigger_types = ('Dedicated', 'Module fader on', 'Module on', 'Module fader & on active');
my @stop_trigger_types = ('Dedicated', 'Module fader off', 'Module off', 'Module fader & on active');

sub _channels {
  return shift->dbAll(q|SELECT s.addr, a.active, s.slot_nr, g.channel, a.name
    FROM slot_config s
    JOIN addresses a ON a.addr = s.addr
    JOIN generate_series(1,32) AS g(channel) ON s.input_ch_cnt >= g.channel
    WHERE input_ch_cnt > 0
    ORDER BY s.slot_nr, g.channel
  |);
}


sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", "%s", this, "source_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("source", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n eq 'input_gain') {
    a href => '#', onclick => sprintf('return conf_level("source", %d, "input_gain", %f, this)', $d->{number}, $v),
      $v == 30 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n eq 'input_phantom' || $n eq 'input_pad') {
    a href => '#', onclick => sprintf('return conf_set("source", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'no') : 'yes';
  }
  if($n =~ /(?:redlight|monitormute)/) {
    a href => '#', onclick => sprintf('return conf_set("source", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'n') : 'y';
  }
  if($n =~ /^input([12])/) {
    $v = (grep $_->{addr} == $d->{'input'.$1.'_addr'} && $_->{channel} == $d->{'input'.$1.'_sub_ch'}, @{$_[2]})[0];
    a href => '#', $v->{active} ? () : (class => 'off'), onclick => sprintf(
      'return conf_select("source", %d, "%s", "%s", this, "input_channels")', $d->{number}, $n, ($d->{'input'.$1.'_addr'}?("$v->{addr}_$v->{channel}"):('0_0'))),
      ($d->{'input'.$1.'_addr'}?(sprintf('Slot %d ch %d', $v->{slot_nr}, $v->{channel})):('none'));
  }
  if ($n eq 'default_src_preset') {
    my $s;
    for my $l (@$lst) {
      if ($l->{number} == $v)
      {
        $s = $l;
      }
    }
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", %d, this, "src_preset_list")', $d->{number}, $n, $v),
      !$v ? (class => 'off') : (), $v ? $s->{label} : 'none';
  }
  if ($n eq 'start_trigger') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", %d, this, "start_triggers")', $d->{number}, $n, $v), ($v == 0) ? (class => 'off') : (), $start_trigger_types[$v];
  }
  if ($n eq 'stop_trigger') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", %d, this, "stop_triggers")', $d->{number}, $n, $v), ($v == 0) ? (class => 'off') : (), $stop_trigger_types[$v];
  }
}

sub _create_source {
  my($self, $chan) = @_;

  my $f = $self->formValidate(
    { name => 'input1', enum => [ map("$_->{addr}_$_->{channel}", @$chan), "0_0" ] },
    { name => 'input2', enum => [ map("$_->{addr}_$_->{channel}", @$chan), "0_0" ] },
    { name => 'label', minlength => 1, maxlength => 32 },
  );
  die "Invalid input" if $f->{_err};
  my @inputs = (split(/_/, $f->{input1}), split(/_/, $f->{input2}));

  $inputs[0] = 'NULL' if ($inputs[0] == 0);
  $inputs[2] = 'NULL' if ($inputs[2] == 0);

  # get new free source number
  my $num = $self->dbRow(q|SELECT gen
    FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM src_config), 1)) AS g(gen)
    WHERE NOT EXISTS(SELECT 1 FROM src_config WHERE number = gen)
    LIMIT 1|
  )->{gen};
  # insert row
  $self->dbExec("INSERT INTO src_config (number, label, input1_addr, input1_sub_ch, input2_addr, input2_sub_ch)
                 VALUES ($num, '$f->{label}', $inputs[0], $inputs[1], $inputs[2], $inputs[3])");
  $self->dbExec("SELECT src_config_renumber()");
  $self->resRedirect('/source', 'post');
}

sub source {
  my $self = shift;

  my $chan = _channels $self;

  # if POST, insert new source
  return _create_source($self, $chan) if $self->reqMethod eq 'POST';

  # if del, remove source
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    $self->dbExec('DELETE FROM src_config WHERE number = ?', $f->{del});
    $self->dbExec("SELECT src_config_renumber()");
    return $self->resRedirect('/source', 'temp');
  }

  my $mb = $self->dbAll('SELECT number, label, number <= dsp_count()*4 AS active
    FROM monitor_buss_config ORDER BY number');

  my @cols = ((map "redlight$_", 1..8), (map "monitormute$_", 1..16));
  my $src = $self->dbAll(q|SELECT pos, number, label, input1_addr, input1_sub_ch, input2_addr,
    input2_sub_ch, input_phantom, input_pad, input_gain,
    default_src_preset, start_trigger, stop_trigger,
    !s FROM src_config ORDER BY pos|, join ', ', @cols);

  my $src_preset_lst = $self->dbAll(q|SELECT number, label FROM src_preset ORDER BY pos|);

  $self->htmlHeader(title => 'Source configuration', page => 'source');
  # create list of available channels for javascript
  div id => 'src_preset_list', class => 'hidden';
    Select;
      option value => 0, 'none';
      for (@$src_preset_lst) {
        option value => $_->{number}, $_->{label};
      }
    end;
  end;
  # create list of available channels for javascript
  div id => 'input_channels', class => 'hidden';
   Select;
    option value => "0_0", 'None';
    option value => "$_->{addr}_$_->{channel}", $_->{active} ? () : (class => 'off'),
        sprintf "Slot %d channel %d (%s)", $_->{slot_nr}, $_->{channel}, $_->{name}
      for @$chan;
   end;
  end;
  # create list of sources for javascript
  div id => 'source_list', class => 'hidden';
   Select;
   my $max_pos;
    $max_pos = 0;
    for (@$src) {
      option value => "$_->{pos}", $_->{label};
      $max_pos = $_->{pos} if ($_->{pos} > $max_pos);
    }
    option value => $max_pos+1, "last";
   end;
  end;
  # create list of start triggers for javascript
  div id => 'start_triggers', class => 'hidden';
   Select;
    option value => $_, $start_trigger_types[$_] for (0..3);
   end;
  end;
  # create list of stop triggers for javascript
  div id => 'stop_triggers', class => 'hidden';
   Select;
    option value => $_, $stop_trigger_types[$_] for (0..3);
   end;
  end;

  table;
   Tr; th colspan => 34, 'Source configuration'; end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Nr';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Label';
    th colspan => 5, 'Input';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Processing\npreset";
    th colspan => 2, 'Trigger';
    th colspan => 8, 'Redlight';
    th colspan => 16, 'Monitor destination mute/dim';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', '';
   end;
   Tr;
    th '1 (left)';
    th '2 (right)';
    th 'Phantom';
    th 'Pad';
    th 'Gain';
    th 'Start';
    th 'Stop';
    th $_ for (1..8);
    th abbr => $_->{label}, $_->{active} ? ():(class => 'inactive'), id => "exp_monitormute$_->{number}", $_->{number}%10
      for (@$mb);
   end;

   for my $s (@$src) {
     Tr;
      th; _col 'pos', $s; end;
      td; _col 'label', $s; end;
      td; _col 'input1', $s, $chan; end;
      td; _col 'input2', $s, $chan; end;
      td;
        my $t = $self->dbRow("SELECT COUNT(*) FROM node_config WHERE (func).type = 5 AND (func).seq = $s->{number}-1 AND (func).func = 60");
        if ($t->{count}) {
          _col 'input_phantom', $s;
        } else {
          txt '-';
        }
      end;
      td;
        $t = $self->dbRow("SELECT COUNT(*) FROM node_config WHERE (func).type = 5 AND (func).seq = $s->{number}-1 AND (func).func = 61");
        if ($t->{count}) {
          _col 'input_pad', $s;
        } else {
          txt '-';
        }
      end;
      td;
        $t = $self->dbRow("SELECT COUNT(*) FROM node_config WHERE (func).type = 5 AND (func).seq = $s->{number}-1 AND (func).func = 62");
        if ($t->{count}) {
          _col 'input_gain', $s;
        } else {
          txt '-';
        }
      end;
      td; _col 'default_src_preset', $s, $src_preset_lst; end;
      td; _col 'start_trigger', $s; end;
      td; _col 'stop_trigger', $s; end;
      for (map "redlight$_", 1..8) {
        td; _col $_, $s; end;
      }
      for (@$mb) {
        td $_->{active} ? (class => "exp_monitormute$_->{number}") : (class => "exp_monitormute$_->{number} inactive"); _col "monitormute$_->{number}", $s; end;
      }
      td;
       a href => '/source?del='.$s->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
     end;
   }
  end;
  br; br;
  a href => '#', onclick => 'return conf_addsrc(this, "input_channels", "input")', 'Create new source';

  $self->htmlFooter;
}

sub generate {
  my $self = shift;
  my $i;
  my $cards = $self->dbAll('SELECT a.addr, a.name, s.slot_nr, s.input_ch_cnt
    FROM slot_config s JOIN addresses a ON a.addr = s.addr WHERE s.input_ch_cnt <> 0 AND a.active ORDER BY s.slot_nr, a.name');
  my $cnt_src;
  $cnt_src = 1;

  $self->dbExec("DELETE FROM src_config;");
  for my $c (@$cards) {
    for ($i=0; $i<$c->{input_ch_cnt}; $i+=2)
    {
      my $num = $self->dbRow(q|SELECT gen
       FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM src_config), 1)) AS g(gen)
       WHERE NOT EXISTS(SELECT 1 FROM src_config WHERE number = gen)
       LIMIT 1|)->{gen};

      $c->{name} =~ s/Axum-Rack-//g;
      $c->{name} =~ s/Rack-//g;
      $self->dbExec("INSERT INTO src_config (number, label, input1_addr, input1_sub_ch, input2_addr, input2_sub_ch) VALUES ($num, '$c->{name} $cnt_src', $c->{addr}, ".($i+1).", $c->{addr}, ".($i+2).");");
      $cnt_src++;

      $self->dbExec("SELECT src_config_renumber()");
    }
  }
  $self->resRedirect('/source', 'post');
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, maxlength => 32, minlength => 1 },
    { name => 'input_phantom', required => 0, enum => [0,1] },
    { name => 'input_pad', required => 0, enum => [0,1] },
    { name => 'input_gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'input1', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    { name => 'input2', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    { name => 'default_src_preset', required => 0, 'int' },
    { name => 'start_trigger', required => 0, enum => [0,1,2,3] },
    { name => 'stop_trigger', required => 0, enum => [0,1,2,3] },
    (map +{ name => "redlight$_", required => 0, enum => [0,1] }, 1..8),
    (map +{ name => "monitormute$_", required => 0, enum => [0,1] }, 1..16),
    { name => 'pos', required => 0, template => 'int' },
  );
  return 404 if $f->{_err};

  #if field returned is 'pos', the positions of other rows may change...
  if($f->{field} eq 'pos') {
    $self->dbExec("UPDATE src_config SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND number <> $f->{item} THEN pos
                    WHEN pos >= $f->{pos} AND number <> $f->{item} THEN pos+1
                    WHEN number = $f->{item} THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT src_config_renumber();");
    #_col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
    txt 'Wait for reload';
  } else {
    my %set;
    defined $f->{$_} and ((($_ =~ /default_src_preset/) and ($f->{$_} == 0)) ? ($set{"$_ = NULL"} = $f->{$_}) : ($set{"$_ = ?"} = $f->{$_}))
      for(qw|label input_phantom input_pad input_gain default_src_preset start_trigger stop_trigger|, (map "redlight$_", 1..8), (map "monitormute$_", 1..16));
    defined $f->{$_} and $f->{$_} =~ /([0-9]+)_([0-9]+)/ and ($set{$_.'_addr = '.(($1 == 0)?('NULL'):('?')).', '.$_.'_sub_ch = ?'} = [ ($1 == 0)?():($1), $2 ])
      for('input1', 'input2');

    $self->dbExec('UPDATE src_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
    if($f->{field} =~ /(input[12])/) {
      my @l = split /_/, $f->{$f->{field}};
      _col $f->{field}, { number => $f->{item}, $1.'_addr' => $l[0], $1.'_sub_ch' => $l[1] }, _channels $self;
    } elsif ($f->{field} =~ /source/) {
      _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
        $f->{field} =~ /source/ ? $self->dbAll(q|SELECT number, label, active FROM matrix_sources ORDER BY number|) : ();
    } else {
      _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
        $f->{field} =~ /default_src_preset/ ? $self->dbAll(q|SELECT number, label FROM src_preset ORDER BY pos|) : ();
    }
  }
}

