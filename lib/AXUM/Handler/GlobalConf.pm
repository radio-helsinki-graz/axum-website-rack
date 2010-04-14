
package AXUM::Handler::GlobalConf;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{globalconf} => \&conf,
  qr{ajax/globalconf} => \&ajax,
  qr{ipclock} => \&ipclock,
  qr{setdatetime} => \&setdatetime,
  qr{ajax/tz_lst} => \&timezone_lst,
  qr{ajax/set_tz} => \&set_tz,
  qr{ajax/ip} => \&set_ip,
  qr{ajax/ntp} => \&set_ntp,
);


sub _col {
  my($n, $v) = @_;
  if($n eq 'samplerate') {
    a href => '#', onclick => sprintf('return conf_select("globalconf", 0, "samplerate", %d, this, "samplerates")', $v),
      sprintf '%.1f kHz', $v/1000;
  }
  if($n eq 'ext_clock') {
    a href => '#', onclick => sprintf('return conf_set("globalconf", 0, "ext_clock", %d, this)', $v?0:1),
      $v ? 'On' : 'Off';
  }
  if($n eq 'level_reserve') {
    a href => '#', onclick => sprintf('return conf_select("globalconf", 0, "level_reserve", %d, this, "reslevels")', $v),
      sprintf '%d dB', 10-$v;
  }
  if($n eq 'auto_momentary') {
    a href => '#', onclick => sprintf('return conf_set("globalconf", 0, "auto_momentary", %d, this)', $v?0:1),
      $v ? 'Yes' : 'No';
  }
  if ($n =~ /net_(ip|mask|gw|dns)/) {
    a href => '#', onclick => sprintf('return conf_text("ip", 0, "%s", "%s", this)', $n, $v), $v;
  }
  if ($n eq 'ntp_server') {
    $v = "0.0.0.0" if not $v;
    txt "0.pool.ntp.org\n";
    txt "1.pool.ntp.org\n";
    txt "2.pool.ntp.org\n";
    txt "NMEA GPS on USB (/dev/ttyUSB0)\n";
    a href => '#', onclick => sprintf('return conf_text("ntp", 0, "%s", "%s", this)', $n, $v), ($v eq "0.0.0.0" ? ("optional ntp server") : ($v));
  }
  if ($n eq 'timezone') {
    a href => '#', onclick => sprintf('return conf_tz(this)'), $v ? ($v) : ('Select timezone');
  }
  if ($n eq 'startup_state') {
    a href => '#', onclick => sprintf('return conf_set("globalconf", 0, "startup_state", %d, this)', $v?0:1),
      $v ? 'Backup of last situation' : 'Programmed defaults';
  }
}


sub conf {
  my $self = shift;

  my $conf = $self->dbRow('SELECT samplerate, ext_clock, headroom, level_reserve, auto_momentary, startup_state
                           FROM global_config');

  $self->htmlHeader(page => 'globalconf', title => 'Global configuration');
  div id => 'samplerates', class => 'hidden'; Select;
   option value => $_, sprintf '%.1f kHz', $_/1000 for (32000, 44100, 48000);
  end; end;
  div id => 'reslevels', class => 'hidden'; Select;
   option value => 10-$_, "$_ dB", for (0, 10);
  end; end;
  table;
   Tr; th colspan => 2, 'Global configuration'; end;
   Tr; th 'Samplerate';    td; _col 'samplerate', $conf->{samplerate}; end; end;
   Tr; th 'Extern clock';  td; _col 'ext_clock', $conf->{ext_clock}; end; end;
   Tr; th 'Headroom';      td sprintf '%.1f dB', $conf->{headroom}; end;
   Tr; th 'Fader top level'; td; _col 'level_reserve', $conf->{level_reserve}; end; end;
   Tr; th 'Auto momentary'; td; _col 'auto_momentary', $conf->{auto_momentary}; end; end;
   Tr; th 'Startup state'; td; _col 'startup_state', $conf->{startup_state}; end; end;
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'samplerate', required => 0, enum => [32000, 44100, 48000] },
    { name => 'ext_clock', required => 0, enum => [0,1] },
    { name => 'level_reserve', required => 0, enum => [0,10] },
    { name => 'auto_momentary', required => 0, enum => [0,1] },
    { name => 'startup_state', required => 0, enum => [0,1] },
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?", $f->{$_}), grep defined $f->{$_}, qw|samplerate ext_clock level_reserve startup_state auto_momentary|;
  $self->dbExec('UPDATE global_config !H', \%set) if keys %set;
  _col $f->{field}, $f->{$f->{field}};
}

sub ipclock
{
  my $self = shift;
  my @array;

  my ($ip, $mask, $gw, $dns);
  open(FILE, '/etc/conf.d/ip');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ m/^net_ip="(.*)"/ ? ($ip = $1) : ();
    $array[$i] =~ m/^net_mask="(.*)"/ ? ($mask = $1) : ();
    $array[$i] =~ m/^net_gw="(.*)"/ ? ($gw = $1) : ();
    $array[$i] =~ m/^net_dns="(.*)"/ ? ($dns = $1) : ();
  }
  close FILE;

  my $tz;
  open(FILE, '/etc/conf.d/timezone');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ m/^user_timezone="(.*)"/;
    $tz = $1;
  }
  close FILE;

  my $ntp_server = "0.0.0.0";
  open(FILE, '/etc/conf.d/ntp');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ m/^server (.*)/;
    $ntp_server = $1;
  }
  close FILE;

  my $sync_url = 'none';
  my $sync_st = '16';
  my $ntpq = `ntpq -pn`;
  my @lines = split "\n", $ntpq;

  for (@lines)
  {
    if ($_ =~ /^\*(\S+)\s+\S+\s+(\d+).*/)
    {
      $sync_url = $1;
      $sync_st = $2;
    }
  }
  $self->htmlHeader(page => 'ipclock', section => 'timezonde', title => "IP/Clock configuration");

  table;
  Tr; th colspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")'; txt "IP\n"; i "(effective after reboot)"; end; end;
  Tr; th "Address"; td; _col 'net_ip', $ip; end; end;
  Tr; th "Subnet mask:"; td; _col 'net_mask', $mask; end; end;
  Tr; th "Gateway"; td; _col 'net_gw', $gw; end; end;
  Tr; th "DNS server"; td; _col 'net_dns', $dns; end; end;
  Tr class => 'empty'; th colspan => 2; end; end;
  Tr; th colspan => 3, style => 'height: 40px; background: url("/images/table_head_40.png")'; txt "Clock\n"; i "(effective after reboot)"; end; end;
  Tr; th rowspan => 2, style => 'height: 40px; background: url("/images/table_head_40.png")', "Current"; td colspan => 2, `date`;
  Tr; td $sync_url; td "stratum: $sync_st"; end;
  Tr; th "time zone"; td colspan => 2; _col 'timezone', $tz; end;
  Tr; th style => 'height: 100px; background: url("/images/table_head_100.png")', "NTP Servers"; td colspan => 2; _col 'ntp_server', $ntp_server; end;
  Tr;
   th style => 'height: 40px; background: url("/images/table_head_40.png")', "Set date/time";
   td colspan => 2;
    input type=>'Text', name=>'datetime', size=>'25', maxlength=>'25', id=>'datetime', class => 'hidden';
    a href => "javascript: NewCssCal('datetime','yyyymmdd','dropdown',true,24,false)";
     img width=>'16', height=>'16', margin=>'0', alt=>'Pick a date', src=>'images/cal.gif';
    end;
   end;
  end;


  $self->htmlFooter;
}

sub timezone_lst {
  my $self = shift;

  my %cnames;

  open(FILE, '/usr/share/zoneinfo/iso3166.tab');
  while (<FILE>) {
    next if /^\#/;
    chomp;
    (my $ccode, my $cname) = split("\t");

    push @{ $cnames{$ccode} }, $cname;
  }

  my %categories;
  my %countries;
  my %localarea;
  my %tzcomment;

  open(FILE, '/usr/share/zoneinfo/zone.tab');
  while (<FILE>) {
    next if /^\#/;
    chomp;
    (my $ccode, undef, my $tz, my $comment) = split("\t");
    (my $cat, my $name, my $place) = split /\//, $tz;

    push(@{ $tzcomment{$tz} }, $comment);

    my $add = 1;
    foreach my $i (@{ $localarea{$name}}) {
      if ($i eq $place) {
        $add = 0;
      }
    }
    push(@{ $localarea{$name} }, $place) if ($add == 1);

    $add = 1;
    foreach my $i (@{ $countries{$ccode}}) {
      if ($i eq $name) {
        $add = 0;
      }
    }
    push(@{ $countries{$ccode} }, $name) if ($add == 1);

    $add = 1;
    foreach my $i (@{ $categories{$cat} }) {
      if ($i eq $ccode) {
       $add = 0;
     }
    }
    push(@{ $categories{$cat} }, $ccode) if ($add == 1);
  }

  my %tz_lst;
  my $cnt_continent = 0;
  for my $c (sort keys %categories )
  {
    foreach my $d (@{$categories{$c}}) {
      foreach my $e (@{$countries{$d}}) {
        foreach my $f (@{$localarea{$e}}) {
          my $tz = "$c/$e";
          my $locationname = "$e";
          if ($f) {
            $locationname .= "/$f";
            $tz .= "/$f";
          }
          my $comment = @{$tzcomment{$tz}}[0];

          if (not $comment)
          {
            my @cats;
            for my $k (sort keys %categories) {
              foreach (@{$categories{$k}}) {
                if ($_ eq $d) {
                  my $new_tz = "$k/$e";
                  if ($f) {
                    $new_tz .= "/$f";
                  }
                  if (not $comment)
                  {
                    $comment = @{$tzcomment{$new_tz}}[0];
                    $tz = $new_tz;
                  }
                }
              }
            }
          }
          if ($comment) {
            $tz_lst{$c}{"@{$cnames{$d}}"}{$comment} = $tz;
          } else {
            $tz_lst{$c}{"@{$cnames{$d}}"}{''} = $tz;
          }
        }
      }
    }
  }

  #make continents and oceans
  div id => 'tz_main';
  Select;
  my $cnt_c = 0;
  for (sort keys %tz_lst)
  {
    option value => $cnt_c, "$_";
    $cnt_c++;
  }
  end;
  end;

  #make countries in continents and oceans
  $cnt_c=0;
  for my $c (sort keys %tz_lst)
  {
    div id => "cont_$cnt_c";
    Select;
    my $cnt_d = 0;
    for (sort keys %{$tz_lst{$c}})
    {
      option value => $cnt_d, "$_";
      $cnt_d++;
    }
    end;
    end;
    $cnt_c++;
  }

  #make local area's
  $cnt_c=0;
  for my $c (sort keys %tz_lst)
  {
    my $cnt_d = 0;
    for my $d (sort keys %{$tz_lst{$c}})
    {
      my $size = keys( %{$tz_lst{$c}{$d}});
      {
        div id => "region_$cnt_c/$cnt_d";
         Select;
         for (sort keys %{$tz_lst{$c}{$d}})
         {
          option value => $tz_lst{$c}{$d}{$_}, "$_";
         }
         end;
        end;
      }
      $cnt_d++;
    }
    $cnt_c++;
  }
}

sub set_tz {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'tz', required => 1, 'asciiprint' },
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/conf.d/timezone');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ s/^user_timezone="(.*)"/user_timezone="$f->{tz}"/;
  }
  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/conf.d/timezone');
  print FILE @result;
  close FILE;

  _col 'timezone', $f->{tz};
}

sub set_ip {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'net_ip', required => 0, regex => [ qr/\b(?:\d{1,3}\.){3}\d{1,3}\b/ ], 0},
    { name => 'net_mask', required => 0, regex => [ qr/\b(?:\d{1,3}\.){3}\d{1,3}\b/ ], 0},
    { name => 'net_gw', required => 0, regex => [ qr/\b(?:\d{1,3}\.){3}\d{1,3}\b/ ], 0},
    { name => 'net_dns', required => 0, regex => [ qr/\b(?:\d{1,3}\.){3}\d{1,3}\b/ ], 0},
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/conf.d/ip');
  @array = <FILE>;
  for my $i (0..$#array) {
    if ($f->{$f->{field}}) {
      $array[$i] =~ s/^$f->{field}="(.*)"/$f->{field}="$f->{$f->{field}}"/;
    }
  }
  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/conf.d/ip');
  print FILE @result;
  close FILE;

  _col $f->{field}, $f->{$f->{field}};
}

sub set_ntp {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'ntp_server', required => 1, 'url'},
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/conf.d/ntp');
  @array = <FILE>;
  for my $i (0..$#array) {
    $array[$i] =~ s/^server (.*)/server $f->{ntp_server}/;
  }
  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/conf.d/ntp');
  print FILE @result;
  close FILE;

  _col 'ntp_server', $f->{ntp_server};
}

sub setdatetime {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'date', required => '1', regex => [ qr/\d{4}-\d{2}-\d{2}/ ]},
    { name => 'time', required => '1', regex => [ qr/\d{2}:\d{2}:\d{2}/ ]},
  );
  return 404 if $f->{_err};

  $self->dbExec("UPDATE global_config SET date_time = ?", "$f->{date} $f->{time}");

  $self->resRedirect('/ipclock');
}


1;

