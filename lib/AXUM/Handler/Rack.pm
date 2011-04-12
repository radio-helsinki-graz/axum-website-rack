
package AXUM::Handler::Rack;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{config/rack} => \&list,
  qr{config/surface} => \&listui,
  qr{config/(surface|rack)/([0-9a-fA-F]{8})} => \&conf,
  qr{ajax/config/(surface|rack)} => \&ajax,
  qr{ajax/config/loadpre} => \&loadpre,
  qr{ajax/config/setpre} => \&setpre,
  qr{ajax/config/func} => \&funclist,
  qr{ajax/config/setfunc} => \&setfunc,
  qr{ajax/config/setdefault} => \&setdefault,
  qr{ajax/config/setlabel/([0-9a-fA-F]{8})} => \&setlabel,
  qr{ajax/config/setuserlevel/([0-9a-fA-F]{8})} => \&setuserlevel,
);


my @mbn_types = ('no data', 'unsigned int', 'signed int', 'state', 'octet string', 'float', 'bit string');
my @user_level_from_names = ('None', map +( sprintf('Console %d', $_), 1..4));

sub listui {
  my $self = shift;

  my $cards = $self->dbAll('SELECT a.addr, a.name, a.active, a.parent, (a.id).man, (a.id).prod, a.firm_major, a.user_level_from_console,
    (SELECT COUNT(*) FROM templates t WHERE t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major) AS objects,
    (SELECT number FROM templates t WHERE t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major AND t.description = \'Slot number\') AS slot_obj,
    (SELECT name FROM addresses b WHERE (b.id).man = (a.parent).man AND (b.id).prod = (a.parent).prod AND (b.id).id = (a.parent).id) AS parent_name,
    (SELECT COUNT(*) FROM node_config n WHERE a.addr = n.addr AND a.firm_major = n.firm_major) AS config_cnt,
    (SELECT COUNT(*) FROM defaults d WHERE a.addr = d.addr AND a.firm_major = d.firm_major) AS default_cnt,
    (SELECT COUNT(*) FROM predefined_node_config p WHERE (a.id).man = p.man_id AND (a.id).prod = p.prod_id AND a.firm_major = p.firm_major) AS predefined_cfg_cnt,
    (SELECT COUNT(*) FROM predefined_node_defaults d WHERE (a.id).man = d.man_id AND (a.id).prod = d.prod_id AND a.firm_major = d.firm_major) AS predefined_dflt_cnt
    FROM slot_config s
    RIGHT JOIN addresses a ON a.addr = s.addr WHERE s.addr IS NULL AND ((a.parent).man != 1 OR (a.parent).prod != 12) AND NOT ((a.id).man=(a.parent).man AND (a.id).prod=(a.parent).prod AND (a.id).id=(a.parent).id)
    ORDER BY NULLIF((a.parent).man, 0), (a.parent).prod, (a.parent).id, NOT a.active, (a.id).man, (a.id).prod, (a.id).id');
  $self->htmlHeader(title => 'Surface configuration', area => 'config', page => 'surface');
  div id => 'console_list', class => 'hidden';
    Select;
      option value => $_, $user_level_from_names[$_] for (0..4);
    end;
  end;
  table;
   Tr; th colspan => 8, 'Surface configuration'; end;
   my $prev_parent='';
   for my $c (@$cards) {
     $c->{parent} =~ s/\((\d+),(\d+),(\d+)\)/sprintf($1?'%04X:%04X:%04X':'-', $1, $2, $3)/e;
     if($c->{parent} ne $prev_parent) {
       if ($prev_parent) {
         Tr class => 'empty'; th colspan => 5; end;
       }
       Tr; th colspan => 8, !$c->{parent_name} ? 'No parent' : "$c->{parent} ($c->{parent_name})"; end;
       Tr;
         th 'MambaNet Address';
         th 'Node name';
         th 'Default';
         th 'Config';
         th colspan => 3, 'Settings';
         th 'User level';
       end;
       $prev_parent = $c->{parent};
     }

     Tr !$c->{active} ? (class => 'inactive') : ();
      td sprintf '%08X', $c->{addr};
      td $c->{name};
      td !$c->{default_cnt} ? (class => 'inactive') : (), $c->{default_cnt};
      td !$c->{config_cnt} ? (class => 'inactive') : (), $c->{config_cnt};
      td;
       if($c->{objects}) {
         a href => sprintf('/config/surface/%08x', $c->{addr}); lit 'configure &raquo;'; end;
       } else {
         a href => '#', class => 'off', 'no objects';
       }
      end;
      td;
       if($c->{objects} and ($c->{predefined_cfg_cnt} or $c->{predefined_dflt_cnt})) {
         a href => '#', onclick => sprintf('return conf_predefined("%08X", this)', $c->{addr}), 'import';
       } else {
         a href => '#', class => 'off', 'no import data';
       }
      end;
      td;
       if($c->{objects} and $c->{config_cnt}) {
         a href => '#', onclick => sprintf('return conf_text("config/surface", "%08X", "export", "Config name", this, "Name ", "Export")', $c->{addr}), 'export';
       } else {
         a href => '#', class => 'off', 'no export data';
       }
      end;
      td;
        a href => '#', onclick => sprintf('return conf_select("config/surface", "%08X", "%s", %d, this, "console_list")', $c->{addr}, 'user_level_from_console', $c->{user_level_from_console}), $user_level_from_names[$c->{user_level_from_console}];
      end;
     end;
   }
  end;
  $self->htmlFooter;
}


sub list {
  my $self = shift;

  my $cards = $self->dbAll('SELECT a.addr, a.name, s.slot_nr, s.input_ch_cnt, s.output_ch_cnt, a.active,
    (SELECT COUNT(*) FROM templates t WHERE t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major) AS objects,
    (SELECT COUNT(*) FROM node_config n WHERE a.addr = n.addr AND a.firm_major = n.firm_major) AS config_cnt,
    (SELECT COUNT(*) FROM defaults d WHERE a.addr = d.addr AND a.firm_major = d.firm_major) AS default_cnt,
    (SELECT COUNT(*) FROM predefined_node_config p WHERE (a.id).man = p.man_id AND (a.id).prod = p.prod_id AND a.firm_major = p.firm_major) AS predefined_cfg_cnt,
    (SELECT COUNT(*) FROM predefined_node_defaults d WHERE (a.id).man = d.man_id AND (a.id).prod = d.prod_id AND a.firm_major = d.firm_major) AS predefined_dflt_cnt,
    (SELECT COUNT(*) FROM templates t WHERE t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major AND t.description = \'Enable word clock\') AS enable_word_clock,
    (SELECT COUNT(*) FROM global_config g WHERE a.addr = g.ext_clock_addr) AS clock_master
    FROM slot_config s JOIN addresses a ON a.addr = s.addr
    UNION
     (SELECT a.addr, name, 9999, 0, 0, active, 0 AS objects, 0 AS config_cnt, 0 AS default_cnt, 0 AS predefined_cfg_cnt, 0 AS predefined_dflt_cnt, 1,
      (SELECT COUNT(*) FROM global_config g WHERE a.addr = g.ext_clock_addr) AS clock_master
      FROM addresses a
      JOIN templates t ON t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major AND t.description = \'Enable word clock\' AND a.active = TRUE
      EXCEPT
        (SELECT a.addr, name, 9999, 0, 0, active, 0 AS objects, 0 AS config_cnt, 0 AS default_cnt, 0 AS predefined_cfg_cnt, 0 AS predefined_dflt_cnt, 1,
         (SELECT COUNT(*) FROM global_config g WHERE a.addr = g.ext_clock_addr) AS clock_master
         FROM addresses a
         JOIN slot_config s ON a.addr = s.addr))
    ORDER by slot_nr;');

  $self->htmlHeader(title => 'Rack configuration', area => 'config', page => 'rack');
  div id => 'console_list', class => 'hidden';
    Select;
      option value => $_, $user_level_from_names[$_] for (0..4);
    end;
  end;
  table;
   Tr; th colspan => 12, 'Rack configuration'; end;
   Tr;
    th 'Slot';
    th 'WC';
    th 'MambaNet Address';
    th 'Node name';
    th 'Inputs';
    th 'Outputs';
    th 'Default';
    th 'Config';
    th colspan => 3, 'Settings';
    th 'User level';
   end;
   for my $c (@$cards) {
     Tr !$c->{active} ? (class => 'inactive') : ();
      th $c->{slot_nr} != 9999 ? ($c->{slot_nr}) : (style => 'background: none; border: 0px');
      td;
       if ($c->{enable_word_clock}) {
         input type => 'radio', name => 'WC', style => 'vertical-align: middle', $c->{clock_master} ? (checked => 'true') : (),
         onclick => sprintf('return conf_set("config/rack", "%08X", "ext_clock", %d, this)', $c->{addr}, $c->{addr});
       }
      end;
      td sprintf '%08X', $c->{addr};
      td $c->{name};
      if ($c->{slot_nr} != 9999) {
        td !$c->{input_ch_cnt} ? (class => 'inactive') : (), $c->{input_ch_cnt};
        td !$c->{output_ch_cnt} ? (class => 'inactive') : (), $c->{output_ch_cnt};
        td !$c->{default_cnt} ? (class => 'inactive') : (), $c->{default_cnt};
        td !$c->{config_cnt} ? (class => 'inactive') : (), $c->{config_cnt};
        td;
         if($c->{objects}) {
           a href => sprintf('/config/rack/%08x', $c->{addr}); lit 'configure &raquo;'; end;
         } else {
           a href => '#', class => 'off', 'no objects';
         }
        end;
        td;
         if($c->{objects} and ($c->{predefined_cfg_cnt} or $c->{predefined_dflt_cnt})) {
           a href => '#', onclick => sprintf('return conf_predefined("%08X", this)', $c->{addr}), 'import';
         } else {
           a href => '#', class => 'off', 'no import data';
         }
        end;
        td;
         if($c->{objects} and $c->{config_cnt}) {
           a href => '#', onclick => sprintf('return conf_text("config/rack", "%08X", "export", "Config name", this)', $c->{addr}), 'export';
         } else {
           a href => '#', class => 'off', 'no export data';
         }
        end;
        td;
          $c->{user_level_from_console} = 0 if not defined $c->{user_level_from_console};
          a href => '#', onclick => sprintf('return conf_select("config/rack", "%08X", "%s", %d, this, "console_list")', $c->{addr}, 'user_level_from_console', $c->{user_level_from_console}), $user_level_from_names[$c->{user_level_from_console}];
        end;
      } else {
      }
     end;
   }
  end;
  $self->htmlFooter;
}

sub _col {
  my($n, $d, $addr) = @_;
  my $v = $d->{$n};

  if ($n eq 'label') {
    $v = 0 if (!defined $v);
    a href => '#', onclick => sprintf('return conf_text("config/setlabel/%08X", "%d", "%s", "%s", this, "Label", "Save")', oct "0x$addr", $d->{number}, $n, $v), $v ? ($v) : (class => 'off' , 'none');
  }
  if ($n =~ /^user_level[0-5]/)
  {
    if ($d->{sensor_type}) {
      if (defined $v) {
        a href => '#', onclick => sprintf('return conf_set("config/setuserlevel/%08X", "%d", "%s", "%s", this)', oct "0x$addr", $d->{number}, $n, $v+1), ($v ? 'y' : 'n');
      } else {
        if (defined $d->{"func_$n"}) {
          a href => '#', onclick => sprintf('return conf_set("config/setuserlevel/%08X", "%d", "%s", "%s", this)', oct "0x$addr", $d->{number}, $n, 0), class => 'off', $d->{"func_$n"} ? 'y' : 'n';
        }
      }
    }
  }
  if ($n =~ /^all_user_level([0-5])/)
  {
    my @user_level_names  = ('Idle', 'Unkown', 'Operator 1', 'Operator 2', 'Supervisor 1', 'Supervisor 2');

    a href => '#', onclick => sprintf('if (confirm("Override all \'%s\' settings?")) {return conf_set("config/setuserlevel/%08X", "all", "user_level%d", "%s", this)}', $user_level_names[$1], oct "0x$addr", $1, 1), 'y';
    txt ' / ';
    a href => '#', onclick => sprintf('if (confirm("Override all \'%s\' settings?")) {return conf_set("config/setuserlevel/%08X", "all", "user_level%d", "%s", this)}', $user_level_names[$1], oct "0x$addr", $1, 0), 'n';
    txt ' / ';
    a href => '#', onclick => sprintf('if (confirm("Override all \'%s\' settings?")) {return conf_set("config/setuserlevel/%08X", "all", "user_level%d", "%s", this)}', $user_level_names[$1], oct "0x$addr", $1, 2), class => 'off', 'd';
  }
}

sub _funcname {
  my($self, $addr, $num, $f1, $f2, $f3, $sens, $act, $buss) = @_;
  a href => '#', onclick => sprintf('return conf_func("%s", %d, %d, %d, %d, %d, %d, this)',
    $addr, $num, $f1, $f2, $f3, $sens, $act), $f1 == -1 ? (class => 'off') : ();
   if($f1 == -1) {
     txt 'not configured';
   } else {
     my $name = $self->dbRow('SELECT name FROM functions WHERE (func).type = ? AND (func).func = ? ORDER BY pos', $f1, $f3)->{name};
     $name =~ s{Buss \d+/(\d+)}{$buss->[$1/2-1]}ieg;
     ($f2<128) ? (txt 'Module '.($f2+1).': ') : (txt 'Module selected '.($f2-127).': ') if $f1 == 0;
     ($f2<16) ? (txt $buss->[$f2].': ') : (txt 'Buss selected '.($f2-15).': ') if $f1 == 1;
     ($f2<16) ? (txt $self->dbRow('SELECT label FROM monitor_buss_config WHERE number = ?', $f2+1)->{label}.': ') : (txt 'Monitor buss selected '.($f2-15).': ') if $f1 == 2;
     txt 'Console '.($f2+1),': ' if $f1 == 3;
     ($f2<1280) ? (txt $self->dbRow('SELECT label FROM src_config WHERE number = ?', $f2+1)->{label}.': ') : (txt 'Source selected '.($f2-1279).': ') if $f1 == 5;
     ($f2<1280) ? (txt $self->dbRow('SELECT label FROM dest_config WHERE number = ?', $f2+1)->{label}.': ') : (txt 'Destination selected '.($f2-1279).': ') if $f1 == 6;
     if ($name =~ /Console preset (\d+)/)
     {
       my $cp_lbl = $self->dbRow('SELECT label FROM console_preset WHERE pos = ?', $1)->{label};
       txt "Console preset: ".(($cp_lbl) ? ($cp_lbl) : ($1));
     } else {
       txt $name;
     }
   }
  end;
}

sub _default {
  my($addr, $row) = @_;

  return if !$row->{actuator_type};
  my $v = 0;                   # This regex doesn't correctly handle comma's or quotes in strings
  $v = $1 if defined $row->{actuator_def} && $row->{actuator_def} =~ /\(,*([^,]+),*\)/;
  $v = $1 if defined $row->{data} && $row->{data} =~ /\(,*([^,]+),*\)/;
  a href => '#', onclick => sprintf('return conf_text("config/setdefault", %d, "%s", %f, this)', $row->{number}, $addr, $1),
    !$row->{data} ? (class => 'off') : (), $1;
}


sub conf {
  my($self, $type, $addr) = @_;
  $addr = uc $addr;

  my $objects = $self->dbAll('
      SELECT t.number, t.description, t.sensor_type, t.actuator_type, t.actuator_def, d.data, c.func, c.label,
             c.user_level0, c.user_level1, c.user_level2, c.user_level3, c.user_level4, c.user_level5,
             f.label AS func_label,
             f.user_level0 AS func_user_level0,
             f.user_level1 AS func_user_level1,
             f.user_level2 AS func_user_level2,
             f.user_level3 AS func_user_level3,
             f.user_level4 AS func_user_level4,
             f.user_level5 AS func_user_level5
      FROM templates t
      JOIN addresses a ON (t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major)
      LEFT JOIN defaults d ON (d.addr = a.addr AND t.number = d.object AND t.firm_major = d.firm_major)
      LEFT JOIN node_config c ON (c.addr = a.addr AND t.number = c.object AND t.firm_major = c.firm_major)
      LEFT JOIN functions f ON (
        (c.func).type = (f.func).type AND (c.func).func = (f.func).func AND (t.sensor_type = f.rcv_type OR t.actuator_type = f.xmt_type)
        AND f.pos = (SELECT f1.pos FROM functions f1 WHERE (c.func).type = (f1.func).type AND (c.func).func = (f1.func).func AND (t.sensor_type = f1.rcv_type OR t.actuator_type = f1.xmt_type) ORDER BY f1.pos LIMIT 1)
      )
      WHERE a.addr = ? ORDER BY t.number',
    oct "0x$addr"
  );
  my $buss = [ map $_->{label}, @{$self->dbAll('SELECT label FROM buss_config ORDER BY number')} ];

  my $name = $self->dbRow($type eq 'rack'
    ? 'SELECT a.name, s.slot_nr FROM addresses a JOIN slot_config s ON s.addr = a.addr WHERE a.addr = ?'
    : 'SELECT a.name FROM addresses a WHERE a.addr = ?', oct "0x$addr");

  $self->htmlHeader(title => "Object configuration for $addr", area => 'config', page => $type, section => $addr);


  table;
   Tr; th colspan => 13, "Object configuration for $name->{name}".($type eq 'rack' ? " (slot $name->{slot_nr})" : ''); end;
   Tr;
    th colspan => 5;
    th colspan => 2, 'Label';
    th colspan => 7, 'User level';
   end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Nr.';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Description';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Type';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Default';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Function';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Local';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Default';
    th 'Idle';
    th 'Unkown';
    th 'Operator 1';
    th 'Operator 2';
    th 'Supervisor 1';
    th 'Supervisor 2';
   end;
   Tr;
    for (0..5) {
      td; _col "all_user_level$_", {}, $addr; end;
    }
   end;
   for my $o (@$objects) {
     Tr;
      th $o->{number};
      td $o->{description};
      td join ' + ', $o->{sensor_type} ? 'S' : (), $o->{actuator_type} ? 'A' : ();
      td; _default $addr, $o; end;
      td;
       _funcname $self, $addr, $o->{number},
         $o->{func} && $o->{func} =~ /(\d+),(\d+),(\d+)/ ? ($1, $2, $3) : (-1,0,0),
         $o->{sensor_type}, $o->{actuator_type}, $buss;
      end;
      td; _col 'label', $o, $addr; end;
      td $o->{func_label};
      for (0..5) {
        td class=>'off'; _col "user_level$_", $o, $addr; end;
      }
     end;
   }
  end;
  $self->htmlFooter;
}


sub funclist {
  my $self = shift;
  my $f = $self->formValidate(
    { name => 'actuator', enum => [0..$#mbn_types] },
    { name => 'sensor', enum => [0..$#mbn_types] },
  );
  return 404 if $f->{_err};

  my @buss = map $_->{label}, @{$self->dbAll('SELECT label FROM buss_config ORDER BY number')};
  my @mbuss = map $_->{label}, @{$self->dbAll('SELECT label FROM monitor_buss_config ORDER BY number')};
  my $src = $self->dbAll('SELECT number, label FROM src_config ORDER BY pos');
  my $dest = $self->dbAll('SELECT number, label FROM dest_config ORDER BY pos');
  my $preset = $self->dbAll('SELECT number, label FROM console_preset ORDER BY pos');
  my $dspcount = $self->dbRow('SELECT dsp_count() AS cnt')->{cnt};

  my $where = join ' OR ',
    $f->{sensor} ? "rcv_type = $f->{sensor}" : (),
    $f->{actuator} ? "xmt_type = $f->{actuator}" : ();
  $where = $where ? "WHERE $where" : '';
  my @func;
  for (@{$self->dbAll(
      'SELECT (func).type, (func).func, name, rcv_type, xmt_type FROM functions !s ORDER BY pos', $where)}) {
    push @{$func[$_->{type}]}, $_;
    delete $_->{type};
    $_->{name} =~ s{Buss \d+/(\d+)}{$buss[$1/2-1]}ieg;
    if ($_->{name} =~ s/Console preset (\d+)/Console preset: /) {
      $_->{name} .= (defined @$preset[$1-1]) ? (@$preset[$1-1]->{label}) : ($1);
    }
  }

  # main select box
  div id => 'func_main'; Select;
   option value => -1, 'None';
   option value => 0, 'Module' if $func[0];
   option value => 1, 'Buss' if $func[1];
   option value => 2, 'Monitor buss' if $func[2];
   option value => 3, 'Console' if $func[3];
   option value => 4, 'Global' if $func[4];
   option value => 5, 'Source' if $func[5];
   option value => 6, 'Destination' if $func[6];
  end;
  # module functions
  if($func[0]) {
    div id => 'func_0'; Select;
     option value => $_-1, $dspcount < $_/32 ? (class => 'off') : (), $_ for (1..128);
     option value => $_, 'Selected '.($_-127) for (128..131);
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[0]};
    end; end;
  }
  # buss functions
  if($func[1]) {
    div id => 'func_1'; Select;
     option value => $_, $buss[$_] for (0..$#buss);
     option value => $_, 'Selected '.($_-15) for (16..19);
    end; Select;
     option value => $_->{func}, $_->{name} for (@{$func[1]});
    end; end;
  }
  # monitor buss functions
  if($func[2]) {
    div id => 'func_2'; Select;
     option value => $_, $dspcount < ($_+1)/4 ? (class => 'off') : (), $mbuss[$_] for (0..$#mbuss);
     option value => $_, 'Selected '.($_-15) for (16..19);
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[2]};
    end; end;
  }
  # console functions
  if ($func[3]) {
    div id => 'func_3'; Select;
     option value => $_, ($_+1) for (0..3);
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[3]};
    end; end;
  }
  # global functions
  if($func[4]) {
    div id => 'func_4'; Select;
     option value => $_->{func}, $_->{name} for @{$func[4]};
    end; end;
  }
  # source
  if($func[5]) {
    div id => 'func_5'; Select;
     option value => $_->{number}-1, $_->{label} for @$src;
     option value => $_, 'Selected '.($_-1279) for (1280..1283);
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[5]};
    end; end;
  }
  # destination
  if($func[6]) {
    div id => 'func_6'; Select;
     option value => $_->{number}-1, $_->{label} for @$dest;
     option value => $_, 'Selected '.($_-1279) for (1280..1283);
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[6]};
    end; end;
  }
}


sub setfunc {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'addr', regex => [qr/^[0-9a-f]{8}$/i] },
    { name => 'nr', template => 'int' },
    { name => 'function', regex => [qr/\d+,\d+,\d+/] },
    { name => 'sensor', template => 'int' },
    { name => 'actuator', template => 'int' },
  );
  return 404 if $f->{_err};
  my($f1, $f2, $f3) = split /,/, $f->{function};

  if($f1 == -1) {
    $self->dbExec('DELETE FROM node_config WHERE addr = ? AND object = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ? )', oct "0x$f->{addr}", $f->{nr}, oct "0x$f->{addr}");
  } else {
      $self->dbExec('UPDATE node_config SET func = (?, ?, ?) WHERE addr = ? AND object = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)', $f1, $f2, $f3, oct "0x$f->{addr}", $f->{nr}, oct "0x$f->{addr}")
    ||
      $self->dbExec('INSERT INTO node_config (addr, object, func, firm_major) VALUES (?, ?, (?,?,?), (SELECT a.firm_major FROM addresses a WHERE a.addr = ?))', oct "0x$f->{addr}", $f->{nr}, $f1, $f2, $f3, oct "0x$f->{addr}");
  }
  _funcname $self, $f->{addr}, $f->{nr}, $f1, $f2, $f3, $f->{sensor}, $f->{actuator},
    [ map $_->{label}, @{$self->dbAll('SELECT label FROM buss_config ORDER BY number')} ];
}

sub setlabel {
  my($self, $addr) = @_;
  $addr = uc $addr;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'asciiprint' },
    { name => 'label', required => 0, 'asciiprint' },
  );
  return 404 if $f->{_err};

  $self->dbExec('UPDATE node_config SET label = ? WHERE addr = ? AND object = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)', $f->{$f->{field}}, oct "0x$addr", $f->{item}, oct "0x$addr");

  $f->{number} = $f->{item};
  txt _col 'label', $f, $addr;
}

sub setuserlevel {
  my($self, $addr) = @_;
  $addr = uc $addr;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'asciiprint' },
    map +(
      { name => "user_level${_}", required => 0, enum => [0,1,2] },
    ), 0..5
  );
  return 404 if $f->{_err};


  if ($f->{item} eq 'all') {
    if ($f->{$f->{field}} < 2) {
      $self->dbExec("UPDATE node_config SET $f->{field} = ? WHERE addr = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)", $f->{$f->{field}}, oct "0x$addr", oct "0x$addr");
    } else {
      $self->dbExec("UPDATE node_config SET $f->{field} = NULL WHERE addr = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)", oct "0x$addr", oct "0x$addr");
    }

    txt 'Wait for reload';
  }
  else {
    if ($f->{$f->{field}} < 2) {
      $self->dbExec("UPDATE node_config SET $f->{field} = ? WHERE addr = ? AND object = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)", $f->{$f->{field}}, oct "0x$addr", $f->{item}, oct "0x$addr");
    } else {
      $self->dbExec("UPDATE node_config SET $f->{field} = NULL WHERE addr = ? AND object = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)", oct "0x$addr", $f->{item}, oct "0x$addr");
    }
    my $o = $self->dbRow('
        SELECT t.number, t.sensor_type,
               c.user_level0, c.user_level1, c.user_level2, c.user_level3, c.user_level4, c.user_level5,
               f.user_level0 AS func_user_level0,
               f.user_level1 AS func_user_level1,
               f.user_level2 AS func_user_level2,
               f.user_level3 AS func_user_level3,
               f.user_level4 AS func_user_level4,
               f.user_level5 AS func_user_level5
        FROM templates t
        JOIN addresses a ON (t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major)
        LEFT JOIN node_config c ON (c.addr = a.addr AND t.number = c.object AND t.firm_major = c.firm_major)
        LEFT JOIN functions f ON ((c.func).type = (f.func).type AND (c.func).func = (f.func).func AND (t.sensor_type = f.rcv_type OR t.actuator_type = f.xmt_type))
        WHERE a.addr = ? AND t.number= ? ORDER BY t.number',
      oct "0x$addr", $f->{item}
    );

    txt _col $f->{field}, $o, $addr;
  }
}

sub setdefault {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'item', template => 'int' },
    { name => 'field', regex => [qr/^[0-9a-f]{8}$/i] }, # = address
  );
  return if $f->{_err};

  my $v = $self->formValidate({name => $f->{field}});
  $v = $v->{$f->{field}};

  my $obj = $self->dbRow('
      SELECT t.number, t.actuator_type, t.actuator_def, d.data
      FROM templates t
      JOIN addresses a ON (t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major)
      LEFT JOIN defaults d ON (d.addr = a.addr AND t.number = d.object AND a.firm_major = d.firm_major)
      WHERE a.addr = ? AND t.number = ?',
    oct "0x$f->{field}", $f->{item}
  );
  return 404 if !$obj->{actuator_type};

  my $dat = $obj->{actuator_type} <= 3 ? "($v,,,)" :
            $obj->{actuator_type} == 4 ? qq|(,,,$v)| :
            $obj->{actuator_type} == 5 ? "(,$v,,)" : qq|(,,$v,)|;

  # TODO: compare value with actuator_def? check min-max?
  if($v eq '') {
    if(defined $obj->{data})
    {
      $self->dbExec('DELETE FROM defaults WHERE addr = ? AND object = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)', oct "0x$f->{field}", $f->{item}, oct "0x$f->{field}");
      $obj->{data} = '';
    }
  } else {
    $self->dbExec(defined $obj->{data}
      ? 'UPDATE defaults SET data = ? WHERE addr = ? AND object = ? AND firm_major = (SELECT a.firm_major FROM addresses a WHERE a.addr = ?)'
      : 'INSERT INTO defaults (data, addr, object, firm_major) VALUES (?, ?, ?, (SELECT a.firm_major FROM addresses a WHERE a.addr = ?))',
      $dat, oct "0x$f->{field}", $f->{item}, oct "0x$f->{field}"
    );
    $obj->{data} = $dat;
  }

  _default $f->{field}, $obj;
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' }, # should have an enum property
    { name => 'item', required => 1, regex => [qr/^[0-9a-f]{8}$/i] },
    { name => 'export', required => 0, maxlength => 32, minlength => 1 },
    { name => 'user_level_from_console', required =>0, enum => [0,1,2,3,4] },
    { name => 'ext_clock', required => 0, 'int' },
  );
  return 404 if $f->{_err};

  if ($f->{field} eq 'export') {
    my $i = $self->dbRow("SELECT (id).man, (id).prod, firm_major FROM addresses WHERE addr = ?  ", oct "0x$f->{item}");
    $self->dbExec("DELETE FROM predefined_node_config WHERE man_id = ? AND prod_id = ? AND firm_major = ? AND cfg_name = ?", $i->{man}, $i->{prod}, $i->{firm_major}, $f->{export});
    $self->dbExec("DELETE FROM predefined_node_defaults WHERE man_id = ? AND prod_id = ? AND firm_major = ? AND cfg_name = ?", $i->{man}, $i->{prod}, $i->{firm_major}, $f->{export});

    my $obj_cfgs = $self->dbAll("SELECT object, (func).type,
                                 CASE
                                  WHEN (func).type = 5 THEN (SELECT pos FROM src_config WHERE number = ((func).seq+1))
                                  WHEN (func).type = 6 THEN (SELECT pos FROM dest_config WHERE number = ((func).seq+1))
                                 ELSE (func).seq
                                 END AS seq,
                                 (func).func,
                                 label, user_level0, user_level1, user_level2, user_level3, user_level4, user_level5
                                 FROM node_config WHERE addr = ? AND firm_major = ?", oct "0x$f->{item}", $i->{firm_major});
    for my $o (@$obj_cfgs) {
      my $new_func = sprintf("(%d,%d,%d)", $o->{type}, $o->{seq}, $o->{func});
      $self->dbExec("INSERT INTO predefined_node_config (man_id, prod_id, firm_major, cfg_name, object, func,
                                 label, user_level0, user_level1, user_level2, user_level3, user_level4, user_level5)
                                 VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)", $i->{man}, $i->{prod}, $i->{firm_major}, $f->{export}, $o->{object}, $new_func,
                                 $o->{label}, $o->{user_level0}, $o->{user_level1}, $o->{user_level2}, $o->{user_level3}, $o->{user_level4}, $o->{user_level5});
    }

    my $obj_dflts = $self->dbAll("SELECT object, data FROM defaults WHERE addr = ? AND firm_major = ?", oct "0x$f->{item}", $i->{firm_major});
    for my $o (@$obj_dflts) {
      $self->dbExec("INSERT INTO predefined_node_defaults (man_id, prod_id, firm_major, cfg_name, object, data) VALUES(?,?,?,?,?,?)", $i->{man}, $i->{prod}, $i->{firm_major}, $f->{export}, $o->{object}, $o->{data});
    }
    txt $f->{export};
  } elsif ($f->{field} eq 'user_level_from_console') {
    $self->dbExec("UPDATE addresses SET user_level_from_console = ? WHERE addr = ?", $f->{$f->{field}}, oct "0x$f->{item}");
    #used rack in the link, because surface/rack make no differenct for the user_level_from_console ajax communication
    a href => '#', onclick => sprintf('return conf_select("config/surface", "%08X", "%s", "%s", this, "console_list")', oct "0x$f->{item}", 'user_level_from_console', $f->{user_level_from_console}), $user_level_from_names[$f->{user_level_from_console}];
  } elsif ($f->{field} eq 'ext_clock') {
    $self->dbExec("UPDATE global_config SET ext_clock_addr = ?", $f->{$f->{field}});
    txt "Done";
  }
}

sub loadpre {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'addr', required => 1, regex => [qr/^[0-9a-f]{8}$/i] },
  );
  return 404 if $f->{_err};

  my $pre_cfg = $self->dbAll("(SELECT p.cfg_name, p.man_id, p.prod_id, p.firm_major, COUNT(*) AS cnt_func, (SELECT COUNT(*) FROM predefined_node_defaults d
                                                                                                            JOIN addresses a ON (a.id).man = d.man_id AND (a.id).prod = d.prod_id AND a.firm_major = d.firm_major
                                                                                                            WHERE a.addr = ? AND p.cfg_name = d.cfg_name) AS cnt_def
                                FROM predefined_node_config p
                                JOIN addresses a ON (a.id).man = p.man_id AND (a.id).prod = p.prod_id AND a.firm_major = p.firm_major
                                WHERE a.addr = ?
                                GROUP BY p.cfg_name, p.man_id, p.prod_id, p.firm_major
                                ORDER BY p.man_id, p.prod_id, p.firm_major)
                              UNION
                              (SELECT d.cfg_name, d.man_id, d.prod_id, d.firm_major, (SELECT COUNT(*) FROM predefined_node_config p
                                                                                      JOIN addresses a ON (a.id).man = d.man_id AND (a.id).prod = p.prod_id AND a.firm_major = p.firm_major
                                                                                      WHERE a.addr = ? AND p.cfg_name = d.cfg_name) AS cnt_func, COUNT(*) AS cnt_def
                                FROM predefined_node_defaults d
                                JOIN addresses a ON (a.id).man = d.man_id AND (a.id).prod = d.prod_id AND a.firm_major = d.firm_major
                                WHERE a.addr = ?
                                GROUP BY d.cfg_name, d.man_id, d.prod_id, d.firm_major
                                ORDER BY d.man_id, d.prod_id, d.firm_major)", oct "0x$f->{addr}", oct "0x$f->{addr}", oct "0x$f->{addr}", oct "0x$f->{addr}");

  div id => 'pre_main'; Select;
  for my $p (@$pre_cfg)
  {
    option value => "$p->{cfg_name}", $p->{cfg_name}." (".$p->{cnt_def}."/".$p->{cnt_func}.")";
  }
  end;
}

sub setpre {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'addr', required => 1, regex => [qr/^[0-9a-f]{8}$/i] },
    { name => 'predefined', required => 1, maxlength => 32, minlength => 1 },
    { name => 'offset', required => 1, template => 'int' },
  );
  return 404 if $f->{_err};

  $self->dbExec("DELETE FROM node_config WHERE addr = ?", oct "0x$f->{addr}");
  $self->dbExec("DELETE FROM defaults WHERE addr = ?", oct "0x$f->{addr}");

  #Insert all functions
  $self->dbExec("INSERT INTO node_config (addr, object, func.type, func.seq, func.func, firm_major, label, user_level0, user_level1, user_level2, user_level3, user_level4, user_level5)
                 SELECT a.addr, p.object, (p.func).type, CASE
                   WHEN (p.func).type = 0 THEN (SELECT CASE
                                                       WHEN ((p.func).seq+$f->{offset})<0 THEN 0
                                                       WHEN ((p.func).seq+$f->{offset})>131 THEN 131
                                                       ELSE ((p.func).seq+$f->{offset})
                                                       END)
                   WHEN (p.func).type = 1 THEN (SELECT CASE
                                                       WHEN ((p.func).seq+$f->{offset})<0 THEN 0
                                                       WHEN ((p.func).seq+$f->{offset})>19 THEN 19
                                                       ELSE ((p.func).seq+$f->{offset})
                                                       END)
                   WHEN (p.func).type = 2 THEN (SELECT CASE
                                                       WHEN ((p.func).seq+$f->{offset})<0 THEN 0
                                                       WHEN ((p.func).seq+$f->{offset})>19 THEN 19
                                                       ELSE ((p.func).seq+$f->{offset})
                                                       END)
                   WHEN (p.func).type = 3 THEN (SELECT CASE
                                                       WHEN ((p.func).seq+$f->{offset})<0 THEN 0
                                                       WHEN ((p.func).seq+$f->{offset})>3 THEN 3
                                                       ELSE ((p.func).seq+$f->{offset})
                                                       END)
                   WHEN (p.func).type = 5 THEN (SELECT CASE
                                                       WHEN EXISTS (SELECT number FROM src_config WHERE pos = ((func).seq)+$f->{offset}) THEN
                                                         (SELECT number FROM src_config WHERE pos = ((func).seq)+$f->{offset})-1
                                                       WHEN EXISTS (SELECT number FROM src_config ORDER BY number LIMIT 1) THEN
                                                         (SELECT number FROM src_config ORDER BY number LIMIT 1)-1
                                                       WHEN ((((p.func).seq+$f->{offset})>1279) AND (((p.func).seq+$f->{offset})<=1284)) THEN
                                                         ((p.func).seq+$f->{offset})
                                                       ELSE
                                                         0
                                                       END)
                   WHEN (p.func).type = 6 THEN (SELECT CASE
                                                       WHEN EXISTS (SELECT number FROM dest_config WHERE pos = ((func).seq)+$f->{offset}) THEN
                                                         (SELECT number FROM dest_config WHERE pos = ((func).seq)+$f->{offset})-1
                                                       WHEN EXISTS (SELECT number FROM dest_config ORDER BY number LIMIT 1) THEN
                                                         (SELECT number FROM dest_config ORDER BY number LIMIT 1)-1
                                                       WHEN ((((p.func).seq+$f->{offset})>1279) AND (((p.func).seq+$f->{offset})<=1284)) THEN
                                                         ((p.func).seq+$f->{offset})
                                                       ELSE
                                                         0
                                                       END)
                   ELSE 0
                   END AS seq,
                   (func).func, p.firm_major, p.label, p.user_level0, p.user_level1, p.user_level2, p.user_level3, p.user_level4, p.user_level5
                 FROM predefined_node_config p
                 JOIN addresses a ON (a.id).man = p.man_id AND (a.id).prod = p.prod_id AND a.firm_major = p.firm_major
                 WHERE a.addr = ? AND p.cfg_name = ?", oct "0x$f->{addr}", $f->{predefined});

  $self->dbExec("INSERT INTO defaults (addr, object, data, firm_major)
                 SELECT a.addr, d.object, d.data, d.firm_major
                 FROM predefined_node_defaults d
                 JOIN addresses a ON (a.id).man = d.man_id AND (a.id).prod = d.prod_id AND a.firm_major = d.firm_major
                 WHERE a.addr = ? AND d.cfg_name = ?", oct "0x$f->{addr}", $f->{predefined});

  txt $f->{predefined};
}

1;

