
package AXUM::Handler::BussPreset;

use strict;
use warnings;
use YAWF ':html';

YAWF::register(
  qr{busspreset}                  => \&busspreset_overview,
  qr{busspreset/([1-9][0-9]*)}    => \&busspreset,
  qr{ajax/busspreset}             => \&ajax,
);

my @buss_names = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;
my @ext_names = map sprintf('ext_%d', $_), 1..8;

# display the value of a column
# arguments: column name, database return object
sub _col_overview {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("busspreset", %d, "%s", "%s", this, "buss_preset_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("busspreset", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
}

# display the value of a column
# arguments: column name, database return object
sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};


  # boolean values
  my %booleans = (
    use_preset      => [0, 'yes', 'no'  ],
    on_off          => [1, 'on',  'off' ],
    crm_use_preset  => [0, 'yes', 'no'  ],
    crm_on_off      => [0, 'on', 'off'  ],
  );

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("busspreset", %d, "%s", "%s", this, "buss_preset_list", "Place before ", "Move")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if($booleans{$n}) {
    if ($n =~ /^crm/) {
      $v = $d->{$n}[$d->{buss}] eq 't' ? (1) : (0);
      my $s = $n;

      $s =~ s/crm/crm_$d->{monitor_buss}/;
      if ($d->{buss}<=15) {
        a href => '#', onclick => sprintf('return conf_set("busspreset", %d, "%s", "%s", this)', $d->{number}, $buss_names[$d->{buss}].'_'.$s, $v?0:1),
         ($v?1:0) == $booleans{$n}[0] ? (class => 'off') : (), $booleans{$n}[$v?1:2];
      } else {
        a href => '#', onclick => sprintf('return conf_set("busspreset", %d, "%s", "%s", this)', $d->{number}, $ext_names[($d->{buss}-16)].'_'.$s, $v?0:1),
         ($v?1:0) == $booleans{$n}[0] ? (class => 'off') : (), $booleans{$n}[$v?1:2];
      }
    } else {
      a href => '#', onclick => sprintf('return conf_set("busspreset", %d, "%s", "%s", this)', $d->{number}, $buss_names[$d->{buss}-1].'_'.$n, $v?0:1),
       ($v?1:0) == $booleans{$n}[0] ? (class => 'off') : (), $booleans{$n}[$v?1:2];
    }
    return;
  }
  if($n eq 'level') {
    a href => '#', onclick => sprintf('return conf_level("busspreset", %d, "%s", %f, this)', $d->{number}, $buss_names[$d->{buss}-1].'_'.$n, $v),
      $v == 0 ? (class => 'off') : (), $v < -120 ? (sprintf 'Off') : (sprintf '%.1f dB', $v);
  }
  if($n eq 'label') {
    txt $v;
  }
  if($n eq 'console') {
    txt $v;
  }
}

sub _create_buss_preset {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'label', minlength => 1, maxlength => 32 },
  );
  die "Invalid input" if $f->{_err};

  # get new free preset number
  my $num = $self->dbRow(q|SELECT gen
    FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM buss_preset), 1)) AS g(gen)
    WHERE NOT EXISTS(SELECT 1 FROM buss_preset WHERE number = gen)
    LIMIT 1|
  )->{gen};
  # insert row
  $self->dbExec(q|
    INSERT INTO buss_preset (number, label) VALUES (!l)|,
    [ $num, $f->{label}]);
  $self->dbExec("SELECT buss_preset_renumber()");
  $self->dbExec(q|INSERT INTO buss_preset_rows (number, buss) SELECT ?, generate_series(1,16)|, $num);
  $self->dbExec(q|INSERT INTO monitor_buss_preset_rows (number, monitor_buss) SELECT ?, generate_series(1,16)|, $num);
  $self->resRedirect('/busspreset', 'post');
}

sub busspreset_overview {
  my $self = shift;

  # if POST, insert new preset
  return _create_buss_preset($self) if $self->reqMethod eq 'POST';

  # if del, remove source
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    $self->dbExec('DELETE FROM buss_preset WHERE number = ?', $f->{del});
    $self->dbExec("SELECT buss_preset_renumber()");
    return $self->resRedirect('/busspreset', 'temp');
  }
  my $presets = $self->dbAll(q|SELECT pos, number, label
    FROM buss_preset ORDER BY pos|);

  $self->htmlHeader(title => 'Buss presets', page => 'busspreset');
  div id => 'buss_preset_list', class => 'hidden';
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
   Tr; th colspan => 4, 'Mix/monitor buss presets'; end;
   Tr;
    th 'Nr';
    th 'Label';
    th 'Settings';
    th '';
   end;

   for my $p (@$presets) {
     Tr;
      th; _col_overview 'pos', $p; end;
      td; _col_overview 'label', $p; end;
      td;
       a href => '/busspreset/'.$p->{number}, class => 'off', 'Configure';
      end;
      td;
       a href => '/busspreset?del='.$p->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
     end;
   }
  end;
  br; br;
  a href => '#', onclick => 'return conf_addpreset(this)', 'Create new buss preset';

  $self->htmlFooter;
}

sub busspreset {
  my ($self, $nr) = @_;

  my $label = $self->dbRow(q|SELECT label FROM buss_preset WHERE number = ?|, $nr);

  my $busses = $self->dbAll(q|
    SELECT bp.number, bp.buss, bp.use_preset, bp.pre_on, bp.pre_level, bp.pre_balance, bp.level, bp.on_off, bp.interlock, bp.exclusive, bp.global_reset,
           bc.label, bc.console
      FROM buss_preset_rows bp 
      JOIN buss_config bc ON bc.number = bp.buss
      WHERE bp.number = ? ORDER BY number, buss ASC|, $nr);

  my $monbusses = $self->dbAll(q|SELECT mbp.number, mbp.monitor_buss, mbp.use_preset AS crm_use_preset, mbp.on_off AS crm_on_off, mbc.label, mbc.console, mbp.monitor_buss <= dsp_count()*4 AS active
                                 FROM monitor_buss_preset_rows mbp
                                 JOIN monitor_buss_config mbc ON mbc.number = mbp.monitor_buss
                                 WHERE mbp.number = ? ORDER BY mbp.monitor_buss|, $nr);

  $self->htmlHeader(title => 'Mix buss preset', page => 'busspreset', section => $nr);
  table;
   Tr;
    td style => 'background: none', valign => 'top';
     table;
      Tr; th colspan => 5, "Mix buss preset - $label->{label}"; end;
      Tr; th colspan => 5, ''; end;
      Tr;
       th colspan => 3, '';
       th colspan => 2, 'Master';
      end;
      Tr;
       th 'Buss';
       th 'Console';
       th 'Use';
       th 'Level';
       th 'State';
      end;
      for my $b (@$busses) {
        Tr;
         th; _col 'label', $b; end;
         for(qw|console use_preset level on_off|) {
           td; _col $_, $b; end;
         }
        end;
      }
     end;
    end;
    td style => 'background: none';
    end;
    td style => 'background: none', valign => 'top';
     table;
      Tr; th colspan => 49, "Monitor buss preset - $label->{label}"; end;
      Tr;
       th '';
       for my $m (@$monbusses) {
         th $m->{active} ? () : (class => 'inactive'), colspan => 2, "$m->{label}"
       }
      end;
      Tr;
       th 'Console';
       for my $m (@$monbusses) {
         td $m->{active} ? () : (class => 'inactive'), colspan => 2, "$m->{console}"
       }
      end;
      Tr;
       th 'Buss';
       for my $m (@$monbusses) {
         th $m->{active} ? () : (class => 'inactive'), 'Use';
         th $m->{active} ? () : (class => 'inactive'), 'State';
       }
      end;
      for my $i (1..24) {
        Tr;
        if ($i<=16) {
          th @$busses[$i-1]->{label};
        } else {
          th 'Ext '.($i-16);
        }
        for my $m (@$monbusses) {
          $m->{buss} = ($i-1);
          td $m->{active} ? () : (class => 'inactive'); _col 'crm_use_preset', $m; end;
          td $m->{active} ? () : (class => 'inactive'); _col 'crm_on_off', $m; end;
        }
      }
      end;
     end;
    end;
   end;
  $self->htmlFooter;
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' }, # should have an enum property
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, template => 'asciiprint' },
    { name => 'pos', required => 0, template => 'int' },
    map( +(
      { name => "${_}_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_on_off", required => 0, enum => [0,1] },
      { name => "${_}_level", required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
      { name => "${_}_crm_1_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_2_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_3_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_4_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_5_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_6_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_7_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_8_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_9_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_10_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_11_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_12_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_13_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_14_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_15_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_16_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_1_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_2_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_3_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_4_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_5_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_6_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_7_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_8_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_9_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_10_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_11_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_12_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_13_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_14_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_15_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_16_on_off", required => 0, enum => [0,1] },
    ), @buss_names), 
    map( +(
      { name => "${_}_crm_1_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_2_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_3_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_4_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_5_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_6_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_7_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_8_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_9_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_10_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_11_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_12_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_13_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_14_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_15_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_16_use_preset", required => 0, enum => [0,1] },
      { name => "${_}_crm_1_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_2_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_3_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_4_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_5_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_6_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_7_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_8_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_9_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_10_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_11_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_12_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_13_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_14_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_15_on_off", required => 0, enum => [0,1] },
      { name => "${_}_crm_16_on_off", required => 0, enum => [0,1] },
    ), @ext_names), 
  );
  return 404 if $f->{_err};

  if($f->{field} eq 'pos') {
    $self->dbExec("UPDATE buss_preset SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND number <> $f->{item} THEN pos
                    WHEN pos >= $f->{pos} AND number <> $f->{item} THEN pos+1
                    WHEN number = $f->{item} THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT buss_preset_renumber();");
    txt 'Wait for reload';
  }

  my %set;
  my $buss = 0;
  my $crm = 0;
  my $fieldname;
  for(qw|use_preset on_off level|, map("crm_${_}_use_preset", (1..16)), map("crm_${_}_on_off", (1..16))) {
    for my $b (@buss_names) {  
      my $field = $b.'_'.$_;
      if (defined $f->{$field}) {
        if ($b =~ /buss_(\d+)_(\d+)_*/) {
          $buss = ($2/2);
          $fieldname = $_;
          if ($fieldname =~ /^crm_(\d+)_(\S+)/) {
            $crm = $1;
            $fieldname = $2;
          } else {
            $set{"$_ = ?"} = $f->{$field};
          }
        }
      }
    }
    for my $e (@ext_names) {  
      my $field = $e.'_'.$_;
      if (defined $f->{$field}) {
        if ($e =~ /ext_(\d+)_*/) {
          $buss = $1+16;
          $fieldname = $_;
          if ($fieldname =~ /^crm_(\d+)_(\S+)/) {
            $crm = $1;
            $fieldname = $2;
          } else {
            $set{"$_ = ?"} = $f->{$field};
          }
        }
      }
    }
  }

  if ($crm>0) {

    $set{"$fieldname\[$buss\] = ?"} = $f->{$f->{field}} ? ('t') : ('f'); 
    $self->dbExec('UPDATE monitor_buss_preset_rows !H WHERE number = ? AND monitor_buss = ?', \%set, $f->{item}, $crm) if keys %set;
    $fieldname = 'crm_'.$fieldname;

    my $mon_array = ['f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f','f'];
    $mon_array->[$buss-1] = $f->{$f->{field}} ? ('t') : ('f');

    _col $fieldname, { number => $f->{item}, $fieldname => $mon_array, buss => ($buss-1), monitor_buss => $crm};
  } elsif ($f->{field} eq 'label') {
    $set{"label = ?"} = $f->{'label'};
    $self->dbExec('UPDATE buss_preset !H WHERE number = ?', \%set, $f->{item}) if keys %set;
    _col $fieldname, { number => $f->{item}, $fieldname => $f->{$f->{field}}, buss => $buss };
  } else {
    $self->dbExec('UPDATE buss_preset_rows !H WHERE number = ? AND buss = ?', \%set, $f->{item}, $buss) if keys %set;
    _col $fieldname, { number => $f->{item}, $fieldname => $f->{$f->{field}}, buss => $buss };
  }
}


1;

