
package AXUM::Handler::ExternSrc;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{config/externsrc} => \&extsrc,
  qr{ajax/config/externsrc} => \&ajax,
);


sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if ($n =~ /^ext/) {
    my $s;
    for my $l (@$lst) {
      if ($l->{number} == $v)
      {
        $s = $l;
      }
    }
    a href => '#', onclick => sprintf('return conf_select("config/externsrc", %d, "%s", %d, this, "matrix_sources")', $d->{number}, $n, $v),
      !($v > 0) || !$s->{active} ? (class => 'off') : (), $s->{label};
  }
  if ($n =~ /^safe/) {
    a href => '#', onclick => sprintf('return conf_set("config/externsrc", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
       ($v == 1)  ? (class => 'off', 'yes') : ('no');
  }
}


sub extsrc {
  my $self = shift;

  my $pos_lst = $self->dbAll('SELECT number, label, type, active FROM matrix_sources WHERE number >= 0 ORDER BY pos');
  my $src_lst = $self->dbAll('SELECT number, label, type, active FROM matrix_sources WHERE number >= 0 ORDER BY number');
  my $mb = $self->dbAll('SELECT number, label, number <= dsp_count()*4 AS active
    FROM monitor_buss_config ORDER BY number');
  my $es = $self->dbAll('SELECT number, !s FROM extern_src_config ORDER BY number',
    join ', ', map("ext$_", 1..8), map("safe$_", 1..8));

  $self->htmlHeader(title => 'Extern source configuration', area => 'config', page => 'externsrc');
  $self->htmlSourceList($pos_lst, 'matrix_sources');

  table;
   Tr; th colspan => 18, 'Extern source configuration'; end;
   Tr;
    th colspan => 2, 'Monitor bus';
    th colspan => 16, 'Extern source';
   end;
   Tr;
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Nr';
    th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', 'Label';
    th colspan => 2, "Ext $_" for (1..8);
   end;
   Tr;
    for (1..8) {
      th 'Safe';
      th 'Source';
    }
   end;

   for my $m (@$mb) {
     Tr $m->{active} ? () : (class => 'inactive');
      th $m->{number};
      td $m->{label};
      $m->{number} % 4 == 1 and do {for (1..8) {
        td rowspan => 4; _col "safe$_", $es->[($m->{number}-1)/4]; end;
        td rowspan => 4; _col "ext$_", $es->[($m->{number}-1)/4], $src_lst; end;
      }};
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $src_lst = $self->dbAll('SELECT number, label, type, active FROM matrix_sources ORDER BY number');
  my $enum = [ 0, map $_->{number}, @$src_lst ];
  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    map( +{ name => "ext$_", required => 0, enum => $enum }, 1..8),
    map( +{ name => "safe$_", required => 0, enum => $enum }, 1..8),
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{"ext$_"} and ($set{"ext$_ = ?"} = $f->{"ext$_"})
    for(1..8);
  defined $f->{"safe$_"} and ($set{"safe$_ = ?"} = $f->{"safe$_"})
    for(1..8);

  $self->dbExec('UPDATE extern_src_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} }, $src_lst;
}


1;

