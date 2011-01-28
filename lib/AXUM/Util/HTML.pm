
package AXUM::Util::HTML;

use strict;
use warnings;
use YAWF ':html';
use Exporter 'import';


our @EXPORT = qw| htmlHeader htmlFooter htmlSourceList OEMFullProductName OEMShortProductName |;


sub htmlHeader {
  my($self, %o) = @_;
  html;
   head;
    title $o{title};
    Link href => '/style.css', rel => 'stylesheet', type => 'text/css';
    script type => 'text/javascript', src => '/scripts.js', ' ';
    script type => 'text/javascript', src => '/datetimepicker_css.js', ' ';
   end;
   body;
    div id => $_, '' for (qw| header header_left header_right border_left border_right
      footer footer_left footer_right hinge_top hinge_bottom|);
    div id => 'loading', 'Saving changes, please wait...';

    div id => 'navigate';
     a href => '/', OEMFullProductName();
     lit " &raquo; " if (defined $o{area});
     a href => '/', 'Main menu' if $o{area} eq 'main';
     a href => '/config', 'Console 1-4 configuration' if $o{area} eq 'config';
     a href => '/system', 'System configuration' if $o {area} eq 'system';
     lit " &raquo; " if (defined $o{page});
     if (($o{area} eq 'config') && (defined $o{page})) {
       a href => '/config/ipclock', 'IP/Clock configuration' if $o{page} eq 'ipclock';
       a href => '/config/globalconf', 'Global configuration' if $o{page} eq 'globalconf';
       a href => '/config/buss', 'Buss configuration' if $o{page} eq 'buss';
       a href => '/config/monitorbuss', 'Monitor buss configuration' if $o{page} eq 'monitorbuss';
       a href => '/config/source', 'Source configuration' if $o{page} eq 'source';
       a href => '/config/externsrc', 'Extern source configuration' if $o{page} eq 'externsrc';
       a href => '/config/dest', 'Destination configuration' if $o{page} eq 'dest';
       a href => '/config/talkback', 'Talkback configuration' if $o{page} eq 'talkback';
       a href => '/config/preset', 'Processing presets' if $o{page} eq 'preset';
       a href => '/config/module/assign', 'Module assignment' if $o{page} eq 'moduleassign';
       a href => '/config/module', 'Module configuration' if $o{page} eq 'module';
       a href => '/config/busspreset', 'Mix/monitor buss presets' if $o{page} eq 'busspreset';
       a href => '/config/consolepreset', 'Console presets' if $o{page} eq 'consolepreset';
       a href => '/config/surface', 'Surface configuration' if $o{page} eq 'surface';
       a href => '/config/rack', 'Rack configuration' if $o{page} eq 'rack';
       a href => '/config/sourcepools', 'Source pools' if $o{page} eq 'sourcepools';
       a href => '/config/presetpools', 'Preset pools' if $o{page} eq 'presetpools';
       a href => '/config/users', 'Users' if $o{page} eq 'users';


       if (defined $o{section}) {
         lit " &raquo; ";

         if ($o{page} eq 'preset') {
           my $label = $self->dbRow(q|SELECT label FROM src_preset WHERE number = ?|, $o{section});
           a href => "/config/preset/$o{section}", "Preset '$label->{label}'";
         }
         if ($o{page} eq 'module') {
           a href => "/config/module/$o{section}", "Module $o{section}";
         }
         if ($o{page} eq 'busspreset') {
           my $label = $self->dbRow(q|SELECT label FROM buss_preset WHERE number = ?|, $o{section});
           a href => "/config/busspreset/$o{section}", "Buss preset '$label->{label}'";
         }
         if ($o{page} eq 'surface') {
           my $label = $self->dbRow(q|SELECT name FROM addresses WHERE addr = ?|, oct "0x$o{section}");
           a href => "/config/surface/$o{section}", "Node '$label->{name}'";
         }
         if ($o{page} eq 'rack') {
           my $label = $self->dbRow(q|SELECT name FROM addresses WHERE addr = ?|, oct "0x$o{section}");
           a href => "/config/rack/$o{section}", "Address $o{section}";
         }
       }
     }
     if (($o{area} eq 'system') && (defined $o{page})) {
       a href => '/system/mambanet', 'MambaNet configuration' if $o{page} eq 'mambanet';
       a href => '/system/templates', 'Node templates' if $o{page} eq 'templates';
       a href => '/system/predefined', 'Predefined node configurations' if $o{page} eq 'predefined';
       a href => '/system/functions', 'Functions' if $o{page} eq 'functions';
       a href => '/system/versions', 'Package versions' if $o{page} eq 'versions';
       a href => '/system/password', 'Change web accounts' if $o{page} eq 'password';
       a href => '/system/ssh', 'SSH' if $o{page} eq 'ssh';
     }



    end;
    div id => 'content';
}


sub htmlFooter {
    end; # /div content
   end; # /body
  end; # /html
}


sub htmlSourceList {
  my($self, $lst, $name, $min) = @_;
  div id => $name, class => 'hidden';
   Select;
    my $last = '';
    for (@$lst) {
      next if $min && $_->{type} eq 'n-1';
      if($last ne $_->{type}) {
        end if $last;
        $last = $_->{type};
        optgroup label => $last;
      }
      option value => $_->{number}, !$_->{active} ? (class => 'off') : (), $_->{label}
    }
    end if $last;
   end;
  end;
}

sub OEMFullProductName {
  open my $F, "/var/lib/axum/OEMFullProductName" or die "Couldn't open file /var/lib/axum/OEMFullProductName: $!";
  my $n =  <$F>;
  close FILE;
  $n =~ s/\s+$//;
  return $n;
}

sub OEMShortProductName {
  open my $F, "/var/lib/axum/OEMShortProductName" or die "Couldn't open file /var/lib/axum/OEMFullProductName: $!";
  my $n =  <$F>;
  close FILE;
  $n =~ s/\s+$//;
  return $n;
}


1;
