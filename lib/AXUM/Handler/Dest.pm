
package AXUM::Handler::Dest;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{dest} => \&dest,
  qr{ajax/dest} => \&ajax,
);


sub _channels {
  return shift->dbAll(q|SELECT s.addr, a.active, s.slot_nr, g.channel, a.name
    FROM slot_config s
    JOIN addresses a ON a.addr = s.addr
    JOIN generate_series(1,32) AS g(channel) ON s.output_ch_cnt >= g.channel
    WHERE output_ch_cnt > 0
    ORDER BY a.name, g.channel
  |);
}


sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'level') {
    a href => '#', onclick => sprintf('return conf_level("dest", %d, "level", %f, this)', $d->{number}, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("dest", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n =~ /output([12])/) {
    $v = (grep $_->{addr} == $d->{'output'.$1.'_addr'} && $_->{channel} == $d->{'output'.$1.'_sub_ch'}, @$lst)[0];
    a href => '#', $v->{active} ? () : (class => 'off'), onclick => sprintf(
      'return conf_select("dest", %d, "%s", "%s", this, "output_channels")', $d->{number}, $n, "$v->{addr}_$v->{channel}"),
      sprintf('Slot %d ch %d', $v->{slot_nr}, $v->{channel});
  }
  if($n eq 'source' || $n eq 'mix_minus_source') {
    a href => '#', onclick => sprintf('return conf_select("dest", %d, "%s", %d, this, "%s")',
        $d->{number}, $n, $v, $n eq 'source' ? 'source_items' : 'mix_minus_items'),
      !$v || !$lst->[$v-1]{active} ? (class => 'off') : (), $v ? $lst->[$v-1]{label} : 'none';
  }
}


sub _create_dest {
  my($self, $chan) = @_;

  my $f = $self->formValidate(
    { name => 'output1', enum => [ map "$_->{addr}_$_->{channel}", @$chan ] },
    { name => 'output2', enum => [ map "$_->{addr}_$_->{channel}", @$chan ] },
    { name => 'label', minlength => 1, maxlength => 32 },
  );
  die "Invalid input" if $f->{_err};
  my @outputs = (split(/_/, $f->{output1}), split(/_/, $f->{output2}));

  # get new free destination number
  my $num = $self->dbRow(q|SELECT gen
    FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM src_config), 1)) AS g(gen)
    WHERE NOT EXISTS(SELECT 1 FROM dest_config WHERE number = gen)
    LIMIT 1|
  )->{gen};
  # insert row
  $self->dbExec(q|
    INSERT INTO dest_config (number, label, output1_addr, output1_sub_ch, output2_addr, output2_sub_ch) VALUES (!l)|,
    [ $num, $f->{label}, @outputs ]);
}


sub dest {
  my $self = shift;

  # if del, remove destination
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    $self->dbExec('DELETE FROM dest_config WHERE number = ?', $f->{del});
    return $self->resRedirect('/dest');
  }

  my $ch = _channels $self;

  # if POST, create destination
  _create_dest($self, $ch) if $self->reqMethod eq 'POST';

  my $lst = $self->dbAll('SELECT number, label, type, active FROM matrix_sources ORDER BY number');
  my $dest = $self->dbAll(q|SELECT number, label, output1_addr,
    output1_sub_ch, output2_addr, output2_sub_ch, level, source, mix_minus_source
    FROM dest_config ORDER BY number|);

  $self->htmlHeader(page => 'dest', title => 'Destination configuration');
  div id => 'output_channels', class => 'hidden';
   Select;
    option value => "$_->{addr}_$_->{channel}",
        sprintf "Slot %d channel %d (%s)", $_->{slot_nr}, $_->{channel}, $_->{name}
      for @$ch;
   end;
  end;
  $self->htmlSourceList($lst, 'source_items');
  $self->htmlSourceList($lst, 'mix_minus_items', 1);

  table;
   Tr; th colspan => 8, 'Destination configuration'; end;
   Tr;
    th 'Nr.';
    th 'Label';
    th 'Output 1 (left)';
    th 'Output 2 (right)';
    th 'Level';
    th 'Default signal';
    th 'N-1 from';
    th '';
   end;

   for my $d (@$dest) {
     Tr;
      th $d->{number};
      td; _col 'label', $d; end;
      td; _col 'output1', $d, $ch; end;
      td; _col 'output2', $d, $ch; end;
      td; _col 'level', $d; end;
      td; _col 'source', $d, $lst; end;
      td; _col 'mix_minus_source', $d, $lst; end;
      td;
       a href => '/dest?del='.$d->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
     end;
   }

  end;
  br; br;
  a href => '#', onclick => 'return conf_addsrcdest(this, "output_channels", "output")', 'Create new destination';
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, maxlength => 32, minlength => 1 },
    { name => 'level', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'output1', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    { name => 'output2', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    { name => 'source', required => 0, template => 'int' },
    { name => 'mix_minus_source', required => 0, template => 'int' },
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(qw|label level source mix_minus_source|);
  defined $f->{$_} and $f->{$_} =~ /([0-9]+)_([0-9]+)/ and ($set{$_.'_addr = ?, '.$_.'_sub_ch = ?'} = [ $1, $2 ])
    for('output1', 'output2');

  $self->dbExec('UPDATE dest_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  if($f->{field} =~ /(output[12])/) {
    my @l = split /_/, $f->{$f->{field}};
    _col $f->{field}, { number => $f->{item}, $1.'_addr' => $l[0], $1.'_sub_ch' => $l[1] }, _channels $self;
  } else {
    _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
      $f->{field} eq 'source' || $f->{field} eq 'mix_minus_source' ?
        $self->dbAll('SELECT number, label, type, active FROM matrix_sources ORDER BY number') : ();
  }
}


1;
