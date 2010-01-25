#
package AXUM::Handler::Preset;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{preset}        => \&preset_overview,
  qr{preset/([1-9][0-9]*)} => \&preset,
  qr{ajax/preset}       	  => \&ajax,
  qr{ajax/preset/([1-9][0-9]*)/eq} => \&eqajax,
  qr{ajax/preset/([1-9][0-9]*)/dyn} => \&dynajax,
);

my @phase_types = ('Normal', 'Left', 'Right', 'Both');
my @mono_types = ('Stereo', 'Left', 'Right', 'Mono');

sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("preset", %d, "%s", "%s", this, "preset_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("preset", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n eq 'gain') {
    a href => '#', onclick => sprintf('return conf_level("preset", %d, "%s", %f, this)', $d->{number}, $n, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n =~ /.+_on_off/) {
    a href => '#', onclick => sprintf('return conf_set("preset", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      $v ? 'on' : (class => 'off', 'off');
  }
  if($n eq 'lc_frequency') {
    a href => '#', onclick => sprintf('return conf_freq("preset", %d, "lc_frequency", %d, this)', $d->{number}, $v),
      sprintf '%d Hz', $v;
  }
  if($n eq 'mod_lvl') {
    a href => '#', onclick => sprintf('return conf_level("preset", %d, "%s" , %f, this)', $d->{number}, $n, $v),
      $v < -120 ? (class => 'off', sprintf 'Off') : (sprintf '%.1f dB', $v);
  }
  if($n =~ /use_.+/) {
    a href => '#', onclick => sprintf('return conf_set("preset", %d, "%s", %d, this)', $d->{number}, $n, $v?0:1),
     $v ? 'yes' : (class => 'off', 'no');
  }
  if($n eq 'phase') {
    a href => '#', onclick => sprintf('return conf_select("preset", %d, "%s", %d, this, "phase_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $phase_types[$v];
  }
  if($n eq 'mono') {
    a href => '#', onclick => sprintf('return conf_select("preset", %d, "%s", %d, this, "mono_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $mono_types[$v];
  }
  if ($n =~ /^copy_preset/) {
    lit '&raquo;';
    a href => '#', onclick => sprintf('return conf_addpreset(this, "Copy", %d)', $d->{number}), class => 'off', 'Copy to new preset';
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
    th 'AGC amount';
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



sub _create_preset {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'label', minlength => 1, maxlength => 32 },
    { name => 'preset', required => 0, template => 'int' },
  );
  die "Invalid input" if $f->{_err};

  # get new free preset number
  my $num = $self->dbRow(q|SELECT gen
    FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM src_preset), 1)) AS g(gen)
    WHERE NOT EXISTS(SELECT 1 FROM src_preset WHERE number = gen)
    LIMIT 1|
  )->{gen};
  # insert row
  $self->dbExec(q|
    INSERT INTO src_preset (number, label) VALUES (!l)|,
    [ $num, $f->{label}]);

  if ($f->{preset} > 0)
  {
    my %set = map +("$_ = o.$_" => 0),
      "use_gain_preset",
      "gain",
      "use_lc_preset",
      "lc_on_off",
      "lc_frequency",
      "use_insert_preset",
      "insert_on_off",
      "use_phase_preset",
      "phase_on_off",
      "phase",
      "use_mono_preset",
      "mono_on_off",
      "mono",
      "use_eq_preset",
      "eq_on_off",
      "use_dyn_preset",
      "dyn_on_off",
      "d_exp_threshold",
      "agc_amount",
      "agc_threshold",
      "use_mod_preset",
      "mod_pan",
      "mod_on_off",
      "mod_lvl";

    $set{"$_ = o.$_"} = 0 for(map +("eq_band_${_}_range", "eq_band_${_}_level", "eq_band_${_}_freq", "eq_band_${_}_bw", "eq_band_${_}_slope", "eq_band_${_}_type"), 1..6);

    $self->dbExec("UPDATE src_preset !H
                   FROM src_preset o
                   WHERE src_preset.number = ? AND o.number = ?", \%set, $num, $f->{preset});
  }

  $self->dbExec("SELECT src_preset_renumber()");
  $self->resRedirect('/preset', 'post');
}

sub preset_overview {
  my $self = shift;

  # if POST, insert new preset
  return _create_preset($self) if $self->reqMethod eq 'POST';

  # if del, remove source
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    $self->dbExec('DELETE FROM src_preset WHERE number = ?', $f->{del});
    $self->dbExec("SELECT src_preset_renumber()");
    return $self->resRedirect('/preset', 'temp');
  }
  my $presets = $self->dbAll(q|SELECT pos, number, label
    FROM src_preset ORDER BY pos|);

  $self->htmlHeader(title => 'Processing presets', page => 'preset');
  div id => 'preset_list', class => 'hidden';
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

  table;
   Tr; th colspan => 4, 'Processing preset'; end;
   Tr;
    th 'Nr';
    th 'Label';
    th 'Settings';
    th '';
   end;

   for my $p (@$presets) {
     Tr;
      th; _col 'pos', $p; end;
      td; _col 'label', $p; end;
      td;
       a href => '/preset/'.$p->{number}, class => 'off', 'Configure';
      end;
      td;
       a href => '/preset?del='.$p->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
      td; _col 'copy_preset', $p; end;
     end;
   }
  end;
  br; br;
  a href => '#', onclick => 'return conf_addpreset(this, "Create")', 'Create new preset';

  $self->htmlFooter;
}

sub preset {
  my($self, $nr) = @_;

  my $preset = $self->dbRow(q|SELECT number,
         label,
         use_gain_preset,
         gain,
         use_lc_preset,
         lc_frequency,
         lc_on_off,
         use_insert_preset,
         insert_on_off,
         use_phase_preset,
         phase,
         phase_on_off,
         use_mono_preset,
         mono,
         mono_on_off,
         use_eq_preset,
         eq_band_1_range,
         eq_band_1_level,
         eq_band_1_freq,
         eq_band_1_bw,
         eq_band_1_type,
         eq_band_2_range,
         eq_band_2_level,
         eq_band_2_freq,
         eq_band_2_bw,
         eq_band_2_type,
         eq_band_3_range,
         eq_band_3_level,
         eq_band_3_freq,
         eq_band_3_bw,
         eq_band_3_type,
         eq_band_4_range,
         eq_band_4_level,
         eq_band_4_freq,
         eq_band_4_bw,
         eq_band_4_type,
         eq_band_5_range,
         eq_band_5_level,
         eq_band_5_freq,
         eq_band_5_bw,
         eq_band_5_type,
         eq_band_6_range,
         eq_band_6_level,
         eq_band_6_freq,
         eq_band_6_bw,
         eq_band_6_type,
         eq_on_off,
         use_dyn_preset,
         d_exp_threshold,
         agc_amount,
         agc_threshold,
         dyn_on_off,
         use_mod_preset,
         mod_lvl,
         mod_on_off
         FROM src_preset
         WHERE number = ?|, $nr);
  return 404 if !$preset->{number};

  $self->htmlHeader(page => 'preset', section => $nr, title => "Preset $preset->{label}");
  div id => 'eq_table_container', class => 'hidden';
   _eqtable($preset);
  end;
  div id => 'dyn_table_container', class => 'hidden';
   _dyntable($preset);
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

  table;
   Tr; th colspan => 4, "Settings for preset: $preset->{label}"; end;
   Tr;
    th '';
    th 'Override';
    th colspan => 2, 'Preset';
   end;
   Tr;
    th '';
    th 'module';
    th 'state';
    th 'value';
   end;
   Tr;
    th 'Digital gain';
    td; _col 'use_gain_preset', $preset; end;
    td '-';
    td; _col 'gain', $preset; end;
   end;
   Tr;
    th 'Low cut';
    td; _col 'use_lc_preset', $preset; end;
    td; _col 'lc_on_off', $preset; end;
    td; _col 'lc_frequency', $preset; end;
   end;
   Tr; th 'Insert';
    td; _col 'use_insert_preset', $preset; end;
    td; _col 'insert_on_off', $preset; end;
    td '-';
   end;
   Tr; th 'Phase';
    td; _col 'use_phase_preset', $preset; end;
    td; _col 'phase_on_off', $preset; end;
    td; _col 'phase', $preset; end;
   end;
   Tr; th 'Mono';
    td; _col 'use_mono_preset', $preset; end;
    td; _col 'mono_on_off', $preset; end;
    td; _col 'mono', $preset; end;
   end;
   Tr; th 'EQ';
    td; _col 'use_eq_preset', $preset; end;
    td; _col 'eq_on_off', $preset; end;
    td;
     a href => "#", onclick => "return conf_eq(\"preset\", this, $nr)"; lit 'EQ settings &raquo;'; end;
    end;
   end;
   Tr; th 'Dynamics';
    td; _col 'use_dyn_preset', $preset; end;
    td; _col 'dyn_on_off', $preset; end;
    td;
     a href => "#", onclick => "return conf_dyn(\"preset\", this, $nr)"; lit 'Dyn settings &raquo;'; end;
    end;
   end;
   Tr; th 'Module';
    td; _col 'use_mod_preset', $preset; end;
    td; _col 'mod_on_off', $preset; end;
    td; _col 'mod_lvl', $preset; end;
   end;
  end;
  $self->htmlFooter;
}

sub ajax {
  my $self = shift;

  my @booleans = qw|use_gain_preset use_lc_preset use_insert_preset use_phase_preset use_mono_preset use_eq_preset use_dyn_preset use_mod_preset
                    lc_on_off insert_on_off phase_on_off mono_on_off eq_on_off dyn_on_off mod_on_off|;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, maxlength => 32, minlength => 1 },
    { name => 'gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'lc_frequency', required => 0, template => 'int' },
    { name => 'phase', required => 0, template => 'int' },
    { name => 'mono', required => 0, template => 'int' },
    { name => 'mod_lvl', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    (map +{ name => $_, required => 0, enum => [0,1] }, @booleans),
    { name => 'pos', required => 0, template => 'int' },
  );
  return 404 if $f->{_err};

  #if field returned is 'pos', the positions of other rows may change...
  if($f->{field} eq 'pos') {
    $self->dbExec("UPDATE src_preset SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND number <> $f->{item} THEN pos
                    WHEN pos >= $f->{pos} AND number <> $f->{item} THEN pos+1
                    WHEN number = $f->{item} THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT src_preset_renumber();");
    #_col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
    txt 'Wait for reload';
  } else {
    my %set;
    defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
      for(qw|label gain lc_frequency phase mono dyn_amount mod_lvl|, (map($_, @booleans)));

      $self->dbExec('UPDATE src_preset !H WHERE number = ?', \%set, $f->{item}) if keys %set;
      _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
        $f->{field} =~ /source/ ? $self->dbAll(q|SELECT number, label, active FROM matrix_sources ORDER BY number|) : ();
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
  $self->dbExec('UPDATE src_preset !H WHERE number = ?', \%set, $nr);
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

  my %set = map +("$_ = ?" => $f->{$_}),
    map +("d_exp_threshold", "agc_amount", "agc_threshold");
  $self->dbExec('UPDATE src_preset !H WHERE number = ?', \%set, $nr);
  _dyntable $f;
}
