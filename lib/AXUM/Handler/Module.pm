
package AXUM::Handler::Module;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{module} => \&overview,
  qr{module/([1-9][0-9]*)} => \&conf,
  qr{ajax/module} => \&ajax,
  qr{ajax/module/([A|B|C|D|E|F|G|H])} => \&rpajax,
  qr{ajax/module/([1-9][0-9]*)/([A|B|C|D|E|F|G|H])} => \&rptableajax,
  qr{ajax/module/([1-9][0-9]*)/eq} => \&eqajax,
  qr{ajax/module/([1-9][0-9]*)/dyn} => \&dynajax,
  qr{ajax/module2console} => \&m2cajax,
);

my @phase_types = ('Normal', 'Left', 'Right', 'Both');
my @mono_types = ('Stereo', 'Left', 'Right', 'Mono');
my @busses = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;
my @balance = ('left', 'center', 'right');

sub overview {
  my $self = shift;

  my $p = $self->formValidate({name => 'p', required => 0, default => 1, enum => [1..4]});
  return 404 if $p->{_err};
  $p = $p->{p};

  my $bsel;
  $bsel .= "m.${_}_assignment, "
    for (@busses);
  $bsel .= "false";

  my $rp_bsel;
  $rp_bsel .= "r.${_}_use_preset, m.${_}_assignment, "
    for (@busses);
  $rp_bsel .= "false";

  my $mod = $self->dbAll(q|
    SELECT m.number,
      a.label AS label_a, a.active AS active_a, pa.label AS label_a_preset,
      b.label AS label_b, b.active AS active_b, pb.label AS label_b_preset,
      c.label AS label_c, c.active AS active_c, pc.label AS label_c_preset,
      d.label AS label_d, d.active AS active_d, pd.label AS label_d_preset,
      e.label AS label_e, e.active AS active_e, pe.label AS label_e_preset,
      f.label AS label_f, f.active AS active_f, pf.label AS label_f_preset,
      g.label AS label_g, g.active AS active_g, pg.label AS label_g_preset,
      h.label AS label_h, h.active AS active_h, ph.label AS label_h_preset,
      m.insert_on_off, m.lc_on_off, m.eq_on_off, m.dyn_on_off, m.console,
      !s
    FROM module_config m
    LEFT JOIN matrix_sources a ON a.number = m.source_a
    LEFT JOIN matrix_sources b ON b.number = m.source_b
    LEFT JOIN matrix_sources c ON c.number = m.source_c
    LEFT JOIN matrix_sources d ON d.number = m.source_d
    LEFT JOIN matrix_sources e ON e.number = m.source_e
    LEFT JOIN matrix_sources f ON f.number = m.source_f
    LEFT JOIN matrix_sources g ON g.number = m.source_g
    LEFT JOIN matrix_sources h ON h.number = m.source_h
    LEFT JOIN src_preset pa ON pa.number = m.source_a_preset
    LEFT JOIN src_preset pb ON pb.number = m.source_b_preset
    LEFT JOIN src_preset pc ON pc.number = m.source_c_preset
    LEFT JOIN src_preset pd ON pd.number = m.source_d_preset
    LEFT JOIN src_preset pe ON pe.number = m.source_e_preset
    LEFT JOIN src_preset pf ON pf.number = m.source_f_preset
    LEFT JOIN src_preset pg ON pg.number = m.source_g_preset
    LEFT JOIN src_preset ph ON ph.number = m.source_h_preset
    WHERE m.number >= ? AND m.number <= ?
    ORDER BY m.number|,
    $bsel, $p*32-31, $p*32
  );

  my $bus = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');



  my $where = "WHERE ";
  $where .= "(${_}_assignment = true AND ${_}_use_preset = true) OR "
    for (@busses);
  $where .= "false";

  my $buss_cfg = $self->dbAll('SELECT number FROM module_config WHERE number >= ? AND number <= ?
                               INTERSECT SELECT number FROM module_config !s AND number >= ? AND number <= ?
                               ORDER BY number', $p*32-31, $p*32, $where, $p*32-31, $p*32);
  my $dspcount = $self->dbRow('SELECT dsp_count() AS cnt')->{cnt};

  $self->htmlHeader(page => 'module', title => 'Module overview');
  table;
   Tr;
    th colspan => 10;
     p class => 'navigate';
      txt 'Page: ';
      a href => "?p=$_", $p == $_ ? (class => 'sel') : (), $_
        for (1..4);
     end;
     txt 'Module overview';
    end;
   end;

   for my $m (0..$#$mod/8) {
     my @m = ($m*8)..($m*8+7);
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th colspan => 2, '';
      th sprintf 'Module %d', $mod->[$_]{number} for (@m);
     end;
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th colspan => 2, 'Console';
      td sprintf '%d', $mod->[$_]{console} for (@m);
     end;
     for my $src ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h') {
       Tr $p > $dspcount ? (class => 'inactive') : ();
        if ($src =~ /[a|c|e|g]/) {
          my $number = ((ord($src)-ord('a'))/2)+1;
          th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Preset $number";
        }
        th ((ord($src)&1) ? ('A'):('B'));
        for (@m) {
          my %rp;
          $rp{$src} = $self->dbRow("SELECT r.mod_number, r.mod_preset, m.console, m.number, !s FROM routing_preset r
                                    JOIN module_config m ON m.number = mod_number
                                    WHERE mod_number = ? AND mod_preset = '\u$src'", $rp_bsel, $mod->[$_]{number});
           my $u = 0;
           for my $b (@$bus) {
            next if !$mod->[$_]{$busses[$b->{number}-1].'_assignment'};
            $u += $rp{$src}->{$busses[$b->{number}-1].'_use_preset'};
           }
           td;
            a href => "/module/$mod->[$_]{number}",
             !$mod->[$_]{"active_$src"} || !$mod->[$_]{"label_$src"} || ($mod->[$_]{"label_$src"} eq 'none') ? (class => 'off') : (), $mod->[$_]{"label_$src"}.($mod->[$_]{"label_".$src."_preset"}?(' ('.$mod->[$_]{"label_".$src."_preset"}.')') : ()).($u?(' - #'):()) ||'none';
           end;
        }
       end;
     }
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th colspan => 2, 'Processing';
      for (@m) {
        my $active = ($mod->[$_]{lc_on_off} or
                      $mod->[$_]{insert_on_off} or
                      $mod->[$_]{eq_on_off} or
                      $mod->[$_]{dyn_on_off});

         td;
          a href => "/module/$mod->[$_]{number}", $active ? () : (class => 'off');
           txt $mod->[$_]{lc_on_off} ? ('LC ') : ();
           txt $mod->[$_]{insert_on_off} ? ('Ins ') : ();
           txt $mod->[$_]{eq_on_off} ? ('EQ ') : ();
           txt $mod->[$_]{dyn_on_off} ? ('Dyn ') : ();
           txt (($mod->[$_]{lc_on_off} or
                $mod->[$_]{insert_on_off} or
                $mod->[$_]{eq_on_off} or
                $mod->[$_]{dyn_on_off}) ? () : ('none'));

          end;
         end;
      }
     end;
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th colspan => 2, 'Routing';
      for (@m) {
        td;
          my $nr = $_;
          my @array = @$buss_cfg;
          my $enabled = "";
          ($enabled .= ($array[$_]{number} eq $mod->[$nr]{number})) for 0..$#array;
          a href => "/module/$mod->[$_]{number}", ($enabled) ? ('active') : (class => 'off', 'none');
        end;
      }
     end;
     Tr;
      td colspan => 9, style => 'background: none', '';
     end;
   }
  end;
  $self->htmlFooter;
}


sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  #globals if 'routing preset A/B/C/D' are selected instead of module settings
  my $url = $lst ? ("module/$lst") : ("module");
  my $number = $lst ? ($d->{mod_number}) : ($d->{number});

  if(($n =~ /^source_[a|b|c|d|e|f|g|h]$/) or ($n eq 'insert_source')) {
    my $s;
    for my $l (@$lst) {
      if ($l->{number} == $v)
      {
        $s = $l;
      }
    }
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "matrix_sources")', $d->{number}, $n, $v),
      !($v != 0) || !$s->{active} ? (class => 'off') : (), $s->{label};
  }
  if ($n =~ /source_[a|b|c|d|e|f|g|h]_preset/) {
    my $s;
    for my $l (@$lst) {
      if ($l->{number} == $v)
      {
        $s = $l;
      }
    }
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "src_preset_list")', $d->{number}, $n, $v),
      !$v ? (class => 'off') : (), $v ? $s->{label} : 'none';
  }
  if($n eq 'overrule_active') {
    a href => '#', onclick => sprintf('return conf_set("%s", %d, "%s", "%s", this)', $url, $number, $n, $v?0:1),
      $v ? 'yes' : (class => 'off', 'no');
  }
  if($n eq 'gain') {
    a href => '#', onclick => sprintf('return conf_level("module", %d, "%s", %f, this)', $d->{number}, $n, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n =~ /.+_on_off/) {
    a href => '#', onclick => sprintf('return conf_set_remove("%s", %d, "%s", "%s", this, 0)', $url, $number, $n, $v?0:1),
      $v ? 'on' : (class => 'off', 'off');
  }
  if($n eq 'lc_frequency') {
    a href => '#', onclick => sprintf('return conf_freq("module", %d, "lc_frequency", %d, this)', $d->{number}, $v),
      sprintf '%d Hz', $v;
  }
  if($n eq 'phase') {
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "phase_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $phase_types[$v];
  }
  if($n eq 'mono') {
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "mono_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $mono_types[$v];
  }
  if($n =~ /level$/) {
    if($n eq 'mod_level') {
      a href => '#', onclick => sprintf('return conf_level("module", %d, "%s", %f, this)', $d->{number}, $n, $v),
        $v < -120 ? (class => 'off') : (), $v < -120 ? (sprintf 'off') : (sprintf '%.1f dB', $v);
    } else {
      a href => '#', onclick => sprintf('return conf_level("%s", %d, "%s", %f, this)', $url, $number, $n, $v),
        $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
    }
  }
  if($n =~ /pre_post$/) {
    a href => '#', onclick => sprintf('return conf_set_remove("%s", %d, "%s", "%s", this, 0)', $url, $number, $n, $v?0:1),
      !$v ? (class => 'off', 'post') : 'pre';
  }
  if($n =~ /balance$/) {
    $v = sprintf '%.0f', $v/512;
    my $new_v = $v+1;
    $new_v = 0 if ($new_v > 2);
    a href => '#', onclick => sprintf('return conf_set_remove("%s", %d, "%s", %d, this, 0)', $url, $number, $n, $new_v), $v == 1 ? (class => 'off') : (), $balance[$v];
  }
  if(($n =~ /.+_use_preset$/) or ($n =~ /^use_/)) {
    a href => '#', onclick => sprintf('return conf_set_remove("%s", %d, "%s", "%s", this, 0)', $url, $number , $n, $v?0:1),
      $v ? 'yes' : (class => 'off', 'no');
  }
  if ($n =~ /^m2c_(\w+)/) {
    lit '&raquo;';
    a href => '#', onclick => sprintf('return conf_set_remove("module2console", %d, "%s", 1, this, 0)', $number, $1), class => 'off', "To all console $d->{console} modules";
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

sub _dyntable {
  my $d = shift;

  table;
   Tr;
    th colspan => 2, 'Dynamics';
   end;
   Tr;
    th 'Downward expander threshold';
    td;
     input type => 'text', class => 'text', size => 4, name => "d_exp_threshold",
        value => $d->{d_exp_threshold};
     txt ' dB';
    end;
   end;
   Tr;
    th 'AGC ratio';
    td;
     input type => 'text', class => 'text', size => 4, name => "agc_amount",
        value => $d->{agc_amount};
     txt ' %';
    end;
   end;
   Tr;
    th 'AGC threshold';
    td;
     input type => 'text', class => 'text', size => 4, name => "agc_threshold",
        value => $d->{agc_threshold};
     txt ' dB';
    end;
   end;
   Tr;
    td colspan => 2;
     input type => 'submit', style => 'float: right', class => 'button', value => 'Save';
    end;
   end;
  end;
}

sub _routingtable {
  my($mod, $bus, $type) = @_;
  table;
  Tr;
   th colspan => 6;
    txt "Routing $type";
   end;
   if ($type eq '') {
     td; _col 'm2c_routing', $mod; end;
   } else {
     td; _col "m2c_routing_\l$type", $mod; end;
   }
  end;
  Tr;
   th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', '';
   if ($type =~ /[A|B|C|D|E|F|G|H]/) {
     th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Override\nmodule";
   } else {
     th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Use at\nsource select";
   }
   if ($type =~ /[A|B|C|D|E|F|G|H]/) {
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Level';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'State';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Pre/post';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Balance';
   } else {
    th colspan => 4, 'Default';
   }

  end;
  Tr;
   if ($type =~ /[A|B|C|D|E|F|G|H]/) {
   } else {
     th 'Level';
     th 'State';
     th 'Pre/post';
     th 'Balance';
   }
  end;
  for my $b (@$bus) {
    next if !$mod->{$busses[$b->{number}-1].'_assignment'};
    Tr;
     th $b->{label};
     td; _col $busses[$b->{number}-1].'_use_preset', $mod, $type; end;

     if ($type =~ /[A|B|C|D|E|F|G|H]/) {
       td;
        input type => 'text', class => 'text', size => 4, name => $busses[$b->{number}-1].'_level', value => $mod->{$busses[$b->{number}-1].'_level'}, 'dB';
       end;
     } else {
       td; _col $busses[$b->{number}-1].'_level', $mod, $type; end;
     }
     td; _col $busses[$b->{number}-1].'_on_off', $mod, $type; end;
     td; _col $busses[$b->{number}-1].'_pre_post', $mod, $type; end;
     td; _col $busses[$b->{number}-1].'_balance', $mod, $type; end;
    end;
  }
  if ($type =~ /[A|B|C|D|E|F|G|H]/) {
    Tr;
     td colspan => 6;
      input type => 'submit', style => 'float: right', class => 'button', value => 'Save';
     end;
    end;
  }
  end;
}



sub conf {
  my($self, $nr) = @_;

  my $bsel;
  $bsel .= "${_}_use_preset, ${_}_level, ${_}_on_off, ${_}_pre_post, ${_}_balance, ${_}_assignment, "
    for (@busses);
  $bsel .= "false";

  my $rp_bsel;
  $rp_bsel .= "r.${_}_use_preset, r.${_}_level, r.${_}_on_off, r.${_}_pre_post, r.${_}_balance, m.${_}_assignment, "
    for (@busses);
  $rp_bsel .= "false";

  my $mod = $self->dbRow(q|
    SELECT number, console,
      source_a, source_a_preset,
      source_b, source_b_preset,
      source_c, source_c_preset,
      source_d, source_d_preset,
      source_e, source_e_preset,
      source_f, source_f_preset,
      source_g, source_g_preset,
      source_h, source_h_preset,
      overrule_active,
      use_gain_preset, gain,
      use_lc_preset, lc_frequency, lc_on_off,
      use_insert_preset, insert_source, insert_on_off,
      use_phase_preset, phase, phase_on_off,
      use_mono_preset, mono, mono_on_off,
      use_dyn_preset, d_exp_threshold, agc_amount, agc_threshold, dyn_on_off,
      use_mod_preset, mod_level, mod_on_off,
      use_eq_preset, eq_on_off,
      eq_band_1_range, eq_band_1_level,  eq_band_1_freq, eq_band_1_bw, eq_band_1_type,
      eq_band_2_range, eq_band_2_level, eq_band_2_freq, eq_band_2_bw, eq_band_2_type,
      eq_band_3_range, eq_band_3_level, eq_band_3_freq, eq_band_3_bw, eq_band_3_type,
      eq_band_4_range, eq_band_4_level, eq_band_4_freq, eq_band_4_bw, eq_band_4_type,
      eq_band_5_range, eq_band_5_level, eq_band_5_freq, eq_band_5_bw, eq_band_5_type,
      eq_band_6_range, eq_band_6_level, eq_band_6_freq, eq_band_6_bw, eq_band_6_type,
      !s
    FROM module_config
    WHERE number = ?|,
    $bsel, $nr);
  return 404 if !$mod->{number};

  my %rp;
  for my $s ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h') {
    $rp{$s} = $self->dbRow("SELECT r.mod_number, r.mod_preset, m.console, m.number, !s FROM routing_preset r
                            JOIN module_config m ON m.number = mod_number
                            WHERE mod_number = ? AND mod_preset = '\u$s'", $rp_bsel, $nr);
    return 404 if !$rp{$s}->{mod_number};
  }

  my $pos_lst = $self->dbAll(q|SELECT number, label, type, active FROM matrix_sources ORDER BY pos|);
  my $src_lst = $self->dbAll(q|SELECT number, label, type, active FROM matrix_sources ORDER BY number|);
  my $src_preset_lst = $self->dbAll(q|SELECT number, label FROM src_preset ORDER BY pos|);
  my $bus = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');

  $self->htmlHeader(page => 'module', section => $nr, title => "Module $nr configuration");
  $self->htmlSourceList($pos_lst, 'matrix_sources');
  div id => 'src_preset_list', class => 'hidden';
    Select;
      option value => 0, 'none';
      for (@$src_preset_lst) {
        option value => $_->{number}, $_->{label};
      }
    end;
  end;
  div id => 'eq_table_container', class => 'hidden';
   _eqtable($mod);
  end;
  div id => 'dyn_table_container', class => 'hidden';
   _dyntable($mod);
  end;
  div id => 'phase_list', class => 'hidden';
   Select;
    option value => $_, $phase_types[$_]
      for (0..3);
   end;
  end;
  div id => 'mono_list', class => 'hidden';
   Select;
    option value => $_, $mono_types[$_]
      for (0..3);
   end;
  end;

  for my $s ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h') {
    div id => "routing_${s}_table_container", class => 'hidden';
     _routingtable($rp{$s}, $bus, "\u$s");
    end;
  }

  table;
   Tr;
    th colspan => 6, "Configuration for module $nr - Console $mod->{console}";
   end;
   Tr;
    th colspan => 2, rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Preset';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Source';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Processing\npreset";
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Routing\npreset";
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Ignore\nmodule state";
   end;
   Tr;
   end;
   for my $s ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h') {
     my $u = 0;
     for my $b (@$bus) {
      next if !$mod->{$busses[$b->{number}-1].'_assignment'};
      $u += $rp{$s}->{$busses[$b->{number}-1].'_use_preset'};
     }
     Tr;
      if ($s =~ /[a|c|e|g]/) {
        my $number = ((ord($s)-ord('a'))/2)+1;
        th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")',"$number";
     }
     th ((ord($s)&1) ? ('A'):('B'));
     td; _col "source_$s", $mod, $src_lst; end;
     td; _col "source_${s}_preset", $mod, $src_preset_lst; end;
     td; a href => "#", onclick => "return conf_rtng(\"module/$nr\", this, \"$s\")", ($u == 0) ? (class => 'off', 'none') : ('active'); end;
     if ($s eq 'a') {
      td rowspan=>8; _col 'overrule_active', $mod; end;
     }
   }
   Tr; td colspan => 4, style => 'background: none', ''; end;
  end;
  table;
   Tr; th colspan => 4, 'Processing'; end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', '';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Use at\nsource select";
    th colspan => 2, 'Default';
   end;
   Tr;
    th 'State';
    th 'Value';
   end;
   Tr; th 'Digital gain';
    td; _col 'use_gain_preset', $mod; end;
    td '-';
    td; _col 'gain', $mod; end;
    td; _col 'm2c_gain', $mod; end;
   end;
   Tr; th 'Low cut';
    td; _col 'use_lc_preset', $mod; end;
    td; _col 'lc_on_off', $mod; end;
    td; _col 'lc_frequency', $mod; end;
    td; _col 'm2c_lc', $mod; end;
   end;
   Tr; th 'Insert';
    td; _col 'use_insert_preset', $mod; end;
    td; _col 'insert_on_off', $mod; end;
    td; _col 'insert_source', $mod, $src_lst; end;
   end;
   Tr; th 'Phase';
    td; _col 'use_phase_preset', $mod; end;
    td; _col 'phase_on_off', $mod; end;
    td; _col 'phase', $mod; end;
    td; _col 'm2c_phase', $mod; end;
   end;
   Tr; th 'Mono';
    td; _col 'use_mono_preset', $mod; end;
    td; _col 'mono_on_off', $mod; end;
    td; _col 'mono', $mod; end;
   td; _col 'm2c_mono', $mod; end;
   end;
   Tr; th 'EQ';
    td; _col 'use_eq_preset', $mod; end;
    td; _col 'eq_on_off', $mod; end;
    td;
     a href => "#", onclick => "return conf_eq(\"module\", this, $nr)"; lit 'EQ settings &raquo;'; end;
    end;
   td; _col 'm2c_eq', $mod; end;
   end;
   Tr; th 'Dynamics';
    td; _col 'use_dyn_preset', $mod; end;
    td; _col 'dyn_on_off', $mod; end;
    td;
     a href => "#", onclick => "return conf_dyn(\"module\", this, $nr)"; lit 'Dyn settings &raquo;'; end;
    end;
    td; _col 'm2c_dyn', $mod; end;
   end;
   Tr; th 'Module';
    td; _col 'use_mod_preset', $mod; end;
    td; _col 'mod_on_off', $mod; end;
    td; _col 'mod_level', $mod; end;
   end;
   Tr; td colspan => 3, style => 'background: none', ''; end;
  end;
  _routingtable($mod, $bus, '');

  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my @booleans = qw|overrule_active use_gain_preset use_lc_preset use_insert_preset use_phase_preset use_mono_preset use_eq_preset use_dyn_preset use_mod_preset lc_on_off insert_on_off phase_on_off mono_on_off eq_on_off dyn_on_off mod_on_off|;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'source_a', required => 0, template => 'int' },
    { name => 'source_b', required => 0, template => 'int' },
    { name => 'source_c', required => 0, template => 'int' },
    { name => 'source_d', required => 0, template => 'int' },
    { name => 'source_e', required => 0, template => 'int' },
    { name => 'source_f', required => 0, template => 'int' },
    { name => 'source_g', required => 0, template => 'int' },
    { name => 'source_h', required => 0, template => 'int' },
    { name => 'source_a_preset', required => 0, template => 'int' },
    { name => 'source_b_preset', required => 0, template => 'int' },
    { name => 'source_c_preset', required => 0, template => 'int' },
    { name => 'source_d_preset', required => 0, template => 'int' },
    { name => 'source_e_preset', required => 0, template => 'int' },
    { name => 'source_f_preset', required => 0, template => 'int' },
    { name => 'source_g_preset', required => 0, template => 'int' },
    { name => 'source_h_preset', required => 0, template => 'int' },
    { name => 'gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'lc_frequency', required => 0, template => 'int' },
    { name => 'insert_source', required => 0, template => 'int' },
    { name => 'phase', required => 0, template => 'int' },
    { name => 'mono', required => 0, template => 'int' },
    { name => 'mod_level', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    (map +{ name => $_, required => 0, enum => [0,1] }, @booleans),
    map +(
      { name => "${_}_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_level", required => 0 },
      { name => "${_}_on_off", required => 0, enum => [0,1] },
      { name => "${_}_pre_post", required => 0, enum => [0,1] },
      { name => "${_}_balance", required => 0, enum => [0..2] },
    ), @busses
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} && ($f->{$_} *= 511)
    for (map "${_}_balance", @busses);
  defined $f->{$_} and ((($_ =~ /source_[a|b|c|d|e|f|g|h]_preset/) and ($f->{$_} == 0)) ? ($set{"$_ = NULL"} = $f->{$_}) : ($set{"$_ = ?"} = $f->{$_}))
    for(@booleans, qw|source_a source_b source_c source_d source_e source_f source_g source_h
                      source_a_preset source_b_preset source_c_preset source_d_preset source_e_preset source_f_preset source_g_preset source_h_preset
                      insert_source mod_level lc_frequency gain phase mono|, map +("${_}_use_preset", "${_}_level", "${_}_on_off", "${_}_pre_post", "${_}_balance"), @busses);

  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
    $f->{field} =~ /source_[a|b|c|d|e|f|g|h]_preset/ ? $self->dbAll(q|SELECT number, label FROM src_preset ORDER BY pos|) : (
      $f->{field} =~ /source/ ? $self->dbAll(q|SELECT number, label, active FROM matrix_sources ORDER BY number|) : ()
    );
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
  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $nr);
  _eqtable $f;
}


sub dynajax {
  my($self, $nr) = @_;

  my @num = (regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ]);
  my $f = $self->formValidate(
    { name => "d_exp_threshold", @num },
    { name => "agc_amount", template => 'int' },
    { name => "agc_threshold", @num },
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?" => $f->{$_}), "d_exp_threshold", "agc_amount", "agc_threshold";

  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $nr);
  _dyntable $f;
}

sub rpajax {
  my($self, $type) = @_;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    map +(
      { name => "${_}_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_level", required => 0 },
      { name => "${_}_on_off", required => 0, enum => [0,1] },
      { name => "${_}_pre_post", required => 0, enum => [0,1] },
      { name => "${_}_balance", required => 0, enum => [0..2] },
    ), @busses
  );
  return 404 if $f->{_err};


  my %set;
  defined $f->{$_} && ($f->{$_} *= 511)
    for (map "${_}_balance", @busses);
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(map +("${_}_use_preset", "${_}_level", "${_}_on_off", "${_}_pre_post", "${_}_balance"), @busses);

  $self->dbExec('UPDATE routing_preset !H WHERE mod_number = ? AND mod_preset = ?', \%set, $f->{item}, $type) if keys %set;
  _col $f->{field}, { mod_number => $f->{item}, $f->{field} => $f->{$f->{field}} }, $type;
}

sub rptableajax {
  my($self, $nr, $type) = @_;

  my $f = $self->formValidate(
    map +(
      { name => "${_}_level", required => 0 },
    ), @busses
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(map +("${_}_level"), @busses);

  $self->dbExec('UPDATE routing_preset !H WHERE mod_number = ? AND mod_preset = ?', \%set, $nr, $type) if keys %set;

  my $rp_bsel;
  $rp_bsel .= "r.${_}_use_preset, r.${_}_level, r.${_}_on_off, r.${_}_pre_post, r.${_}_balance, m.${_}_assignment, "
    for (@busses);
  $rp_bsel .= "false";
  my $bus = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');
  my $rp = $self->dbRow("SELECT r.mod_number, r.mod_preset, m.console, m.number, !s FROM routing_preset r
                          JOIN module_config m ON m.number = mod_number
                          WHERE mod_number = ? AND mod_preset = '\u$type'", $rp_bsel, $nr);
  _routingtable($rp, $bus, $type);
}

sub m2cajax {
  my($self, $type) = @_;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => "gain", required => 0, enum => [1] },
  );
  return 404 if $f->{_err};

  my %set;
  if ($f->{field} =~ /gain/) {
    $set{"use_gain_preset = o.use_gain_preset"} = 0;
    $set{"gain = o.gain"} = 0;
  }
  if ($f->{field} =~ /lc/) {
    $set{"use_lc_preset = o.use_lc_preset"} = 0;
    $set{"lc_on_off = o.lc_on_off"} = 0;
    $set{"lc_frequency = o.lc_frequency"} = 0;
  }
  if ($f->{field} =~ /phase/) {
    $set{"use_phase_preset = o.use_phase_preset"} = 0;
    $set{"phase_on_off = o.phase_on_off"} = 0;
    $set{"phase = o.phase"} = 0;
  }
  if ($f->{field} =~ /mono/) {
    $set{"use_mono_preset = o.use_mono_preset"} = 0;
    $set{"mono_on_off = o.mono_on_off"} = 0;
    $set{"mono = o.mono"} = 0;
  }
  if ($f->{field} =~ /eq/) {
    $set{"use_eq_preset = o.use_eq_preset"} = 0;
    $set{"eq_on_off = o.eq_on_off"} = 0;
    $set{"$_ = o.$_"} = 0 for(map +("eq_band_${_}_range", "eq_band_${_}_level", "eq_band_${_}_freq", "eq_band_${_}_bw", "eq_band_${_}_type"), 1..6);
  }
  if ($f->{field} =~ /dyn/) {
   $set{"use_dyn_preset = o.use_dyn_preset"} = 0;
   $set{"dyn_on_off = o.dyn_on_off"} = 0;
   $set{"d_exp_threshold = o.d_exp_threshold"} = 0;
   $set{"agc_amount = o.agc_amount"} = 0;
   $set{"agc_threshold = o.agc_threshold"} = 0;
  }
  if ($f->{field} eq 'routing') {
    $set{"$_ = o.$_"} = 0 for(map +("${_}_use_preset", "${_}_level", "${_}_on_off", "${_}_pre_post", "${_}_balance"), @busses);
  }
  if ($f->{field} =~ /routing_([a|b|c|d|e|f|g|h])/) {
    $set{"$_ = o.$_"} = 0 for(map +("${_}_use_preset", "${_}_level", "${_}_on_off", "${_}_pre_post", "${_}_balance"), @busses);
    $self->dbExec('UPDATE routing_preset !H
                   FROM routing_preset o, module_config m
                   WHERE m.console = (SELECT console FROM module_config WHERE number = ?) AND
                   m.number = routing_preset.mod_number AND
                   o.mod_number = ? AND
                   routing_preset.mod_preset = ? AND
                   routing_preset.mod_preset = o.mod_preset', \%set, $f->{item}, $f->{item}, "\u$1") if keys %set;
  } else {
    $self->dbExec('UPDATE module_config !H
                   FROM module_config o
                   WHERE module_config.console = o.console AND o.number = ? AND module_config.number != o.number', \%set, $f->{item});
  }

  a href => '#', class => 'off', "Done";
}


1;

