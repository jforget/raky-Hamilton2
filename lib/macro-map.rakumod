# -*- encoding: utf-8; indent-tabs-mode: nil -*-
#
#
#     Génération de la page HTML détaillant une carte de la base de données Hamilton.db
#     Generating the HTML pages rendering a map from the Hamilton.db database
#     Copyright (C) 2022, 2023 Jean Forget
#
#     Voir la licence dans la documentation incluse ci-dessous.
#     See the license in the embedded documentation below.
#
unit package macro-map;

use Template::Anti :one-off;
use map-gd;
use MIME::Base64;
use messages-list;

sub fill($at, :$lang, :$mapcode, :%map, :@areas, :@borders, :@messages
        ,     :@macro-links
        ,     :@full-links
        ,     :@ico-links
        , Str :$query-string) {
  $at('title')».content(%map<name>);
  $at('h1'   )».content(%map<name>);

  my ($png, Str $imagemap) = map-gd::draw(@areas, @borders, query-string => $query-string);
  $at.at('img').attr(src => "data:image/png;base64," ~ MIME::Base64.encode($png));
  $at.at('a.full-map').attr(href => "/$lang/full-map/$mapcode$query-string");
  $at('map')».content($imagemap);
  $at.at('ul.messages').content(messages-list::render($lang, @messages));

  if %map<fruitless_reason> eq '' {
    $at.at('span.fruitless-reason')».remove;
    $at.at('p.fruitless')».remove;
  }
  else {
    $at.at('span.fruitless-reason').content(%map<fruitless_reason>);
  }

  if @macro-links.elems eq 0 {
    $at.at('p.list-of-macro-paths')».remove;
  }
  else {
    for @macro-links <-> $macro {
      if $macro<bold> {
        $macro<txt> = "<b>{$macro<txt>}</b>";
      }
    }
    my $links = join ' ', @macro-links.map( { "<a href='{$_<link>}'>{$_<txt>}</a>" } );
    $at.at('p.list-of-macro-paths').content($links);
    $at.at('p.empty-list-of-macro-paths')».remove;
  }

  if @full-links.elems eq 0 {
    $at.at('p.list-of-full-paths')».remove;
  }
  else {
    my $links = join ' ', @full-links.map( { "<a href='{$_<link>}'>{$_<txt>}</a>" } );
    $at.at('p.list-of-full-paths').content($links);
    $at.at('p.empty-list-of-full-paths')».remove;
  }

  if @ico-links.elems == 0 {
    $at.at('div.ico')».content('');
  }
  else {
    my $links = join ' ', @ico-links.map( { "<a href='/$lang/region-path/ico/ICO/$_$query-string'>{$_}</a>" } );
    $at.at('p.list-of-ico-paths').content($links);
  }

}

our sub render(Str $lang, Str $map, %map, :@areas, :@borders, :@messages
            ,     :@macro-links
            ,     :@full-links
            ,     :@ico-links
            , Str :$query-string) {
  my &filling = anti-template :source("html/macro-map.$lang.html".IO.slurp), &fill;
  return filling( lang         => $lang
                , mapcode      => $map
                , map          => %map
                , areas        => @areas
                , borders      => @borders
                , messages     => @messages
                , macro-links  => @macro-links
                , full-links   => @full-links
                , ico-links    => @ico-links
                , query-string => $query-string
                );
}


=begin POD

=encoding utf8

=head1 NAME

map-page.rakumod -- utility module to render a map.

=head1 DESCRIPTION

This module  builds the  HTML file  rendering a  map available  in the
Hamilton SQLite database. It is used internally by C<website.raku>.

=head1 COPYRIGHT and LICENSE

Copyright 2022, 2023, Jean Forget, all rights reserved

This program  is published under  the same conditions as  Raku: the
Artistic License version 2.0.

The text of  the licenses is available  in the F<LICENSE-ARTISTIC-2.0>
file in this repository, or you can read them at:

  L<https://raw.githubusercontent.com/Raku/doc/master/LICENSE>

=end POD
