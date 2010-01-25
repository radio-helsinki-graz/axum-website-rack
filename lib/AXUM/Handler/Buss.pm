
package AXUM::Handler::Buss;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{buss}      => \&buss,
  qr{ajax/buss} => \&ajax,
);

my @buss_names = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;

# display the value of a column
# arguments: column name, database return object
sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  # boolean values
  my %booleans = (
    mono         => [0, 'yes', 'no'  ],
    global_reset => [0, 'yes', 'no'  ],
    interlock    => [0, 'yes', 'no'  ],
    exclusive    => [0, 'yes', 'no'  ],
    on_off       => [1, 'On',  'Off' ],
    pre_on       => [0, 'Pre', 'Post'],
    pre_balance  => [0, 'Pre', 'Post'],
  );

  if($booleans{$n}) {
    a href => '#', onclick => sprintf('return conf_set("buss", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      ($v?1:0) == $booleans{$n}[0] ? (class => 'off') : (), $booleans{$n}[$v?1:2];
    return;
  }
  if($n eq 'pre_level') {
    my $pre = ($v != 0);
    my $post = (($d->{count}-$v) != 0);

    a href => '#', onclick => sprintf('return conf_set("buss", %d, "%s", "%s", this)', $d->{number}, $n, $pre?0:1),
     ($pre ? ($post ? ('Pre/Post') : ('Pre')) : (class => 'off', 'Post'));
    return;
  }
  if($n eq 'level') {
    a href => '#', onclick => sprintf('return conf_level("buss", %d, "level", %f, this)', $d->{number}, $v),
      $v == 0 ? (class => 'off') : (), $v < -120 ? (sprintf 'Off') : (sprintf '%.1f dB', $v);
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("buss", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n eq 'console') {
    a href => '#', onclick => sprintf('return conf_select("buss", %d, "%s", %d, this, "console_list")', $d->{number}, $n, $v),
      $v;
  }
}


sub buss {
  my $self = shift;

  my $busses = $self->dbAll(q|
    (SELECT  b.number, b.label, b.mono, b.pre_on, b.pre_balance, b.level, b.on_off, b.interlock, b.exclusive, b.global_reset, b.console,
        COUNT(*),
        SUM(CASE WHEN m.buss_1_2_pre_post = true AND b.number = 1 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_3_4_pre_post = true AND b.number = 2 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_5_6_pre_post = true AND b.number = 3 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_7_8_pre_post = true AND b.number = 4 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_9_10_pre_post = true AND b.number = 5 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_11_12_pre_post = true AND b.number = 6 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_13_14_pre_post = true AND b.number = 7 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_15_16_pre_post = true AND b.number = 8 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_17_18_pre_post = true AND b.number = 9 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_19_20_pre_post = true AND b.number = 10 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_21_22_pre_post = true AND b.number = 11 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_23_24_pre_post = true AND b.number = 12 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_25_26_pre_post = true AND b.number = 13 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_27_28_pre_post = true AND b.number = 14 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_29_30_pre_post = true AND b.number = 15 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN m.buss_31_32_pre_post = true AND b.number = 16 THEN 1 ELSE 0 END) AS pre_level
      FROM module_config m
      JOIN buss_config b ON b.console = m.console
      WHERE m.number <= dsp_count()*32
      GROUP BY b.number, b.label, b.mono, b.pre_on, pre_balance, b.level, b.on_off, b.interlock, b.exclusive, b.global_reset, b.console
      ORDER BY b.number ASC)
    UNION
      (SELECT  b.number, b.label, b.mono, b.pre_on, b.pre_balance, b.level, b.on_off, b.interlock, b.exclusive, b.global_reset, b.console, 0 AS count, 0 AS pre_level
        FROM buss_config b
        WHERE (SELECT COUNT(*) FROM module_config m WHERE m.console = b.console) = 0
        ORDER BY b.number ASC)|);

  $self->htmlHeader(title => 'Buss configuration', page => 'buss');
  div id => 'console_list', class => 'hidden';
    Select;
      option value => $_, 'Console '.($_) for (1..4);
    end;
  end;
  table;
   Tr; th colspan => 12, 'Buss configuration'; end;
   Tr;
    th colspan => 2, '';
    th '2 Mono';
    th colspan => 3, 'Master Pre/Post';
    th colspan => 2, 'Master';
    th colspan => 2, '';
    th rowspan => 2, "Buss reset\nby module active";
    th '';
   end;
   Tr;
    th 'Buss';
    th 'Label';
    th 'Busses';
    th 'Module on';
    th 'Module level';
    th 'Module balance';
    th 'Level';
    th 'State';
    th 'Interlock';
    th 'Exclusive';
    th 'Console';
   end;
   for my $b (@$busses) {
     Tr;
      th sprintf '%d/%d', $b->{number}*2-1, $b->{number}*2;
      for(qw|label mono pre_on pre_level pre_balance level on_off interlock exclusive global_reset console|) {
        td; _col $_, $b; end;
      }
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' }, # should have an enum property
    { name => 'item', template => 'int' },
    { name => 'console',      required => 0, enum => [1,2,3,4] },
    { name => 'mono',         required => 0, enum => [0,1] },
    { name => 'global_reset', required => 0, enum => [0,1] },
    { name => 'interlock',    required => 0, enum => [0,1] },
    { name => 'exclusive',    required => 0, enum => [0,1] },
    { name => 'on_off',       required => 0, enum => [0,1] },
    { name => 'pre_on',       required => 0, enum => [0,1] },
    { name => 'pre_level',    required => 0, enum => [0,1] },
    { name => 'pre_balance',  required => 0, enum => [0,1] },
    { name => 'level',        required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'label',        required => 0, maxlength => 32, minlength => 1 },
  );
  return 404 if $f->{_err};

  if ($f->{field} eq 'pre_level') {
    my %set;
    $set{"$buss_names[$f->{item}-1]_pre_post = ?"} = $f->{$f->{field}};
    $self->dbExec('UPDATE module_config !H WHERE number <= dsp_count()*32 AND console = (SELECT console FROM buss_config WHERE number = ?)', \%set, $f->{item});

    _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}}, count => 1};
  } else {
    my %set;
    defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
      for(qw|console mono global_reset interlock exclusive on_off pre_on pre_balance level label|);

    $self->dbExec('UPDATE buss_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
    _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
  }
}


1;

