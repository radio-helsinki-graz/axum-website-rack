
package AXUM::Handler::Pools;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{config/sourcepools}        => \&sourcepools,
  qr{ajax/config/sourcepools}   => \&ajax_sourcepools,
  qr{config/presetpools}        => \&presetpools,
  qr{ajax/config/presetpools}   => \&ajax_presetpools,
);

sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if(($n eq 'pos') or
     ($n eq 'type') or
     ($n eq 'label')) {
    txt $v;
  }
  if ($n =~ /(.*)pool([1-8])/) {
    $n = "pool$2";
    $v = $d->{$n};
    if ($1 eq 'source')
    {
      a href => '#', onclick => sprintf('return conf_set("config/sourcepools", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
       $v ? 'y' : (class => 'off', 'n');
    }
    if ($1 eq 'preset')
    {
      a href => '#', onclick => sprintf('return conf_set("config/presetpools", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
       $v ? 'y' : (class => 'off', 'n');
    }
  }
}

sub sourcepools {
  my $self = shift;

  my $pool = $self->dbAll(q|SELECT pos, number, type, label, pool1, pool2, pool3, pool4, pool5, pool6, pool7, pool8, active
                            FROM matrix_sources ORDER BY pos|);

  $self->htmlHeader(title => 'Source pools', area => 'config', page => 'sourcepools');

  table;
   Tr; th colspan => 11, 'Source pool'; end;
   Tr;
    th colspan => 3, '';
    th colspan => 2, "Console $_" for (1..4);
   end;
   Tr;
    th 'Nr';
    th 'Type';
    th 'Label';
    for (1..4) {
      th 'A';
      th 'B';
    }
   end;

   for my $p (@$pool) {
     Tr $p->{active} ? () : (class => 'inactive');
      th; _col 'pos', $p; end;
      td; _col 'type', $p; end;
      td; _col 'label', $p; end;
      for (1..8) {
        td; _col "sourcepool$_", $p; end;
      }
     end;
   }
  end;
  $self->htmlFooter;
}

sub ajax_sourcepools {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    map +(
      { name => "pool$_", required => 0, enum => [ 0, 1] },
    ), 1..8
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($f->{$_} eq 'NULL' ? ($set{"$_ = NULL"} = 0) :($set{"$_ = ?"} = $f->{$_})) for (map("pool$_", 1..8));

  if ($f->{item} < 289) {
    $self->dbExec('UPDATE src_pool !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  } else {
    $self->dbExec('UPDATE src_config !H WHERE number = ?', \%set, ($f->{item}-288)) if keys %set;
  }
  _col "source$f->{field}", { number => $f->{item}, $f->{field} => $f->{$f->{field}}};
}

sub presetpools {
  my $self = shift;

  my $pool = $self->dbAll(q|SELECT pos, number, label, pool1, pool2, pool3, pool4, pool5, pool6, pool7, pool8
                            FROM processing_presets ORDER BY pos|);

  $self->htmlHeader(title => 'Preset pools', area => 'config', page => 'presetpools');

  table;
   Tr; th colspan => 11, 'Preset pool'; end;
   Tr;
    th colspan => 2, '';
    th colspan => 2, "Console $_" for (1..4);
   end;
   Tr;
    th 'Nr';
    th 'Label';
    for (1..4) {
      th 'A';
      th 'B';
    }
   end;

   for my $p (@$pool) {
     Tr;
      th; _col 'pos', $p; end;
      td; _col 'label', $p; end;
      for (1..8) {
        td; _col "presetpool$_", $p; end;
      }
     end;
   }
  end;
  $self->htmlFooter;
}

sub ajax_presetpools {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    map +(
      { name => "pool$_", required => 0, enum => [ 0, 1] },
    ), 1..8
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($f->{$_} eq 'NULL' ? ($set{"$_ = NULL"} = 0) :($set{"$_ = ?"} = $f->{$_})) for (map("pool$_", 1..8));

  if ($f->{item} < 1) {
    $self->dbExec('UPDATE preset_pool !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  } else {
    $self->dbExec('UPDATE src_preset !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  }

  _col "preset$f->{field}", { number => $f->{item}, $f->{field} => $f->{$f->{field}}};
}

