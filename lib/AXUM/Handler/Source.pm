#
package AXUM::Handler::Source;

use strict;
use warnings;
use YAWF ':html';

YAWF::register(
  qr{source}            	  => \&source,
  qr{source/generate}   	  => \&generate,
  qr{ajax/source}       	  => \&ajax,
  qr{ajax/source/([1-9][0-9]*)/eq} => \&eqajax,
);

my @phase_types = ('Normal', 'Left', 'Right', 'Both');
my @mono_types = ('Stereo', 'Left', 'Right', 'Mono');

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
  if($n =~ /input([12])/) {
    $v = (grep $_->{addr} == $d->{'input'.$1.'_addr'} && $_->{channel} == $d->{'input'.$1.'_sub_ch'}, @{$_[2]})[0];
    a href => '#', $v->{active} ? () : (class => 'off'), onclick => sprintf(
      'return conf_select("source", %d, "%s", "%s", this, "input_channels")', $d->{number}, $n, "$v->{addr}_$v->{channel}"),
      sprintf('Slot %d ch %d', $v->{slot_nr}, $v->{channel});
  }
  if ($n eq 'preset_type') {
    txt $d->{preset_type};
  }
  if($n eq 'insert_source') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", %d, this, "matrix_sources")', $d->{number}, $n, $v),
      !$v || !$lst->[$v]{active} ? (class => 'off') : (), $v ? $lst->[$v]{label} : 'none';
  }
  if($n eq 'gain') {
    a href => '#', onclick => sprintf('return conf_level("source", %d, "%s", %f, this)', $d->{number}, $n, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n =~ /.+_on_off/) {
    a href => '#', onclick => sprintf('return conf_set("source", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      $v ? 'on' : (class => 'off', 'off');
  }
  if($n eq 'lc_frequency') {
    a href => '#', onclick => sprintf('return conf_freq("source", %d, "lc_frequency", %d, this)', $d->{number}, $v),
      sprintf '%d Hz', $v;
  }
  if($n eq 'dyn_amount') {
    a href => '#', onclick => sprintf('return conf_proc("source", %d, "dyn_amount", %d, this)', $d->{number}, $v),
      sprintf '%d%%', $v;
  }
  if($n eq 'mod_lvl') {
    a href => '#', onclick => sprintf('return conf_level("source", %d, "%s" , %f, this)', $d->{number}, $n, $v),
      $v < -120 ? (class => 'off', sprintf 'Off') : (sprintf '%.1f dB', $v);
  }
  if($n =~ /use_.+/) {
    a href => '#', onclick => sprintf('return conf_set("source", %d, "%s", %d, this)', $d->{number}, $n, $v?0:1),
     $v ? 'yes' : (class => 'off', 'no');
  }
  if ($n eq 'routing_preset') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", %d, this, "routing_preset_list")', $d->{number}, $n, $v), $lst->{"routing_preset_".$v."_label"};
  }
  if($n eq 'phase') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", %d, this, "phase_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $phase_types[$v];
  }
  if($n eq 'mono') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", %d, this, "mono_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $mono_types[$v];
  }
}


sub _eqtable {
  my $d = shift;

  my @eq_types = ('Off', 'HPF', 'Low shelf', 'Peaking', 'High shelf', 'LPF', 'BPF', 'Notch');

  table;
   Tr; th 'Band'; th 'Range'; th 'Level'; th 'Frequency'; th 'Bandwidth'; th 'Type'; end;
   for my $i (1..6) {
     Tr;
      th $i;
      td;
       input type => 'text', class => 'text', size => 4, name => "eq_band_${i}_range",
         value => $d->{"eq_band_${i}_range"};
       txt ' dB';
      end;
      td;
       input type => 'text', class => 'text', size => 4, name => "eq_band_${i}_level",
         value => $d->{"eq_band_${i}_level"};
       txt ' dB';
      end;
      td;
       input type => 'text', class => 'text', size => 7, name => "eq_band_${i}_freq",
         value => $d->{"eq_band_${i}_freq"};
       txt ' Hz';
      end;
      td;
       txt 'Q = ';
       input type => 'text', class => 'text', size => 4, name => "eq_band_${i}_bw",
         value => sprintf '%.1f', $d->{"eq_band_${i}_bw"};
      end;
      td;
       Select style => 'width: 100px', name => "eq_band_${i}_type";
        option value => $_, $_ == $d->{"eq_band_${i}_type"} ? (selected => 'selected') : (),
          $eq_types[$_] for (0..$#eq_types);
       end;
      end;
     end;
   }
   Tr;
    td '';
    td '0 - 18';
    td '-Range - +Range';
    td '20 - 20000';
    td '0.1 - 10';
    td;
     input type => 'submit', style => 'float: right', class => 'button', value => 'Save';
    end;
   end;
  end;
}


sub _create_source {
  my($self, $chan) = @_;

  my $f = $self->formValidate(
    { name => 'input1', enum => [ map "$_->{addr}_$_->{channel}", @$chan ] },
    { name => 'input2', enum => [ map "$_->{addr}_$_->{channel}", @$chan ] },
    { name => 'label', minlength => 1, maxlength => 32 },
  );
  die "Invalid input" if $f->{_err};
  my @inputs = (split(/_/, $f->{input1}), split(/_/, $f->{input2}));

  # get new free source number
  my $num = $self->dbRow(q|SELECT gen
    FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM src_config), 1)) AS g(gen)
    WHERE NOT EXISTS(SELECT 1 FROM src_config WHERE number = gen)
    LIMIT 1|
  )->{gen};
  # insert row
  $self->dbExec(q|
    INSERT INTO src_config (number, label, input1_addr, input1_sub_ch, input2_addr, input2_sub_ch) VALUES (!l)|,
    [ $num, $f->{label}, @inputs ]);
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
    preset_type,
    !s FROM src_config ORDER BY pos|, join ', ', @cols);

  $self->htmlHeader(title => 'Source configuration', page => 'source');
  # create list of available channels for javascript
  div id => 'input_channels', class => 'hidden';
   Select;
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

  table;
   Tr; th colspan => 34, 'Source configuration'; end;
   Tr;
    th '';
    th colspan => 3, '';
    th colspan => 3, 'Input';
    th 'Preset';
    th colspan => 8, 'Redlight';
    th colspan => 16, 'Monitor destination mute/dim';
    th '';
   end;
   Tr;
    th 'Nr';
    th 'Label';
    th 'Input 1 (left)';
    th 'Input 2 (right)';
    th 'Phantom';
    th 'Pad';
    th 'Gain';
    th 'Type';
    th $_ for (1..8);
    th abbr => $_->{label}, $_->{active} ? ():(class => 'inactive'), id => "exp_monitormute$_->{number}", $_->{number}%10
      for (@$mb);
    th '';
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
        my $t = $self->dbRow("SELECT COUNT(*) FROM node_config WHERE (func).type = 5 AND (func).seq = $s->{number}-1 AND (func).func = 61");
        if ($t->{count}) {
          _col 'input_pad', $s;
        } else {
          txt '-';
        }
      end;
      td;
        my $t = $self->dbRow("SELECT COUNT(*) FROM node_config WHERE (func).type = 5 AND (func).seq = $s->{number}-1 AND (func).func = 62");
        if ($t->{count}) {
          _col 'input_gain', $s;
        } else {
          txt '-';
        }
      end;
      td; _col 'preset_type', $s; end;
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
  a href => '#', onclick => 'return conf_addsrcdest(this, "input_channels", "input")', 'Create new source';

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

  my @booleans = qw|use_gain_preset use_lc_preset use_insert_preset use_phase_preset use_mono_preset use_eq_preset use_dyn_preset use_mod_preset use_routing_preset
                    lc_on_off insert_on_off phase_on_off mono_on_off eq_on_off dyn_on_off mod_on_off|;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, maxlength => 32, minlength => 1 },
    { name => 'input_phantom', required => 0, enum => [0,1] },
    { name => 'input_pad', required => 0, enum => [0,1] },
    { name => 'input_gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'input1', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    { name => 'input2', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    { name => 'insert_source', required => 0, 'int' },
    { name => 'gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'lc_frequency', required => 0, template => 'int' },
    { name => 'phase', required => 0, template => 'int' },
    { name => 'mono', required => 0, template => 'int' },
    { name => 'dyn_amount', required => 0, template => 'int' },
    { name => 'mod_lvl', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'routing_preset', required => 0, template => 'int' },
    (map +{ name => $_, required => 0, enum => [0,1] }, @booleans),
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
    defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
      for(qw|label input_phantom input_pad input_gain gain lc_frequency insert_source phase mono dyn_amount mod_lvl routing_preset|, (map($_, @booleans)), (map "redlight$_", 1..8), (map "monitormute$_", 1..16));
    defined $f->{$_} and $f->{$_} =~ /([0-9]+)_([0-9]+)/ and ($set{$_.'_addr = ?, '.$_.'_sub_ch = ?'} = [ $1, $2 ])
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
        $f->{field} =~ /routing_preset/ ? $self->dbRow(q|SELECT routing_preset_1_label,
                                                                routing_preset_2_label,
                                                                routing_preset_3_label,
                                                                routing_preset_4_label,
                                                                routing_preset_5_label,
                                                                routing_preset_6_label,
                                                                routing_preset_7_label,
                                                                routing_preset_8_label
                                                                FROM global_config|) : ();
    }
  }
}

sub eqajax {
  my($self, $nr) = @_;

  my @num = (regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ]);
  my $f = $self->formValidate(map +(
    { name => "eq_band_${_}_range", @num },
    { name => "eq_band_${_}_level", @num },
    { name => "eq_band_${_}_freq", @num },
    { name => "eq_band_${_}_bw", @num },
    { name => "eq_band_${_}_type", enum => [ 0..7 ] },
  ), 1..6);
  return 404 if $f->{_err};

  my %set = map +("$_ = ?" => $f->{$_}),
    map +("eq_band_${_}_range", "eq_band_${_}_level", "eq_band_${_}_freq", "eq_band_${_}_bw", "eq_band_${_}_type"), 1..6;
  $self->dbExec('UPDATE src_config !H WHERE number = ?', \%set, $nr);
  _eqtable $f;
}
