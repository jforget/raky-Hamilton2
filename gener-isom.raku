#!/usr/bin/env perl6
# -*- encoding: utf-8; indent-tabs-mode: nil -*-
#
#     Génération des isométries pour le jeu icosien
#     Generating isometries for the icosian game
#
#     Voir la licence dans la documentation incluse ci-dessous.
#     See the license in the embedded documentation below.
#

use v6;
use lib 'lib';
use DBIish;
use db-conf-sql;
use access-sql;

my $dbh = DBIish.connect('SQLite', database => dbname());

my $sto-isom = $dbh.prepare(q:to/SQL/);
insert into Isometries (map, isometry, transform, length, recipr, involution)
       values          (?  , ?,        ?,         ?,      ?,      ?)
SQL

my $sto-path = $dbh.prepare(q:to/SQL/);
insert into Isom_Path (map, canonical_num, num, isometry, recipr)
       values         (?  , ?,             ?,   ?,        ?)
SQL

sub maj-isometries(Str $map, %trans) {

  $dbh.execute("begin transaction");
  $dbh.execute('delete from Isometries where map = ?', $map);
  $dbh.execute('delete from Isom_Path  where map = ?', $map);
  $dbh.execute("commit");

  my @elem-isom = %trans.keys.grep( * ne 'Id');
  my Str $before = %trans<Id>;

  my @before;
  my %before; # Gives the 0..^20 index of a letter
  my %after;  # hash of array: for an isometry, gives the array of index after the isometry has been applied
  my %recipr;

for $before.comb.kv -> $i, $c {
  @before[$i] = $c;
  %before{$c} = $i;
}
  for @elem-isom -> $isom {
    for %trans{$isom}.comb.kv -> $i, $c {
      %after{$isom}[%before{$c}] = $i;
    }
  }

multi sub transform(Str $isom where * eq 'Id') {
  return $before;
}

multi sub transform(Str $isom where * ~~ /^ @elem-isom * $/) {
  my @list = @before;
  for $isom.comb -> $iso {
    @list[ |%after{$iso} ] = |@list;
  }
  return @list.join;
}

multi sub infix:<↣> (Str $string, Str $isom where * eq 'Id') {
  return $string;
}

multi sub infix:<↣> (Str $string, Str $isom where * ~~ /^ @elem-isom * $/) {
  my Str $resul = $string.trans($before => %trans{$isom});
  return $resul;
}

  my %seen = %trans.invert;

  my @to-do = @elem-isom;

  $dbh.execute("begin transaction");
  $sto-isom.execute($map, 'Id', $before      , 0, $before     , -1);
  for @elem-isom -> $isom {
    %recipr{$isom} = $before.trans( %trans{$isom} => $before);
    $sto-isom.execute($map, $isom, %trans{$isom}, 1, %recipr{$isom}, -1);
  }

while @to-do.elems > 0 {
  my Str $old-isom = @to-do.shift;
  for @elem-isom -> Str $next-isom {
    my Str $new-isom  = $old-isom ~ $next-isom;
    my Str $new-trans = transform($new-isom);
    if %seen{$new-trans} {
      say join(' ', $new-trans, "duplicate", $new-isom, %seen{$new-trans});
    }
    else {
      %seen{$new-trans} = $new-isom;
      %trans{$new-isom} = $new-trans;
      my Str $recipr = $before.trans($new-trans => $before);
      $sto-isom.execute($map, $new-isom, $new-trans, $new-isom.chars, $recipr, -1);
      @to-do.push($new-isom);
    }
  }
}

$dbh.execute("commit");
$dbh.execute("begin transaction");

my $sth-canonical-paths = $dbh.execute(q:to/SQL/);
select   num, path
from     Region_Paths
where    map = 'ico'
and      path like 'B → C → D → %'
order by num
SQL
my @canonical-paths = $sth-canonical-paths.allrows(:array-of-hash);

my $sth-actual = $dbh.prepare(q:to/SQL/);
select   num
from     Region_Paths
where    map  = 'ico'
and      path = ?
SQL

my $sth-isometries = $dbh.execute(q:to/SQL/);
select   isometry, transform, recipr
from     Isometries
where    map = 'ico'
SQL

for $sth-isometries.allrows(:array-of-hash) -> $isometry-rec {
  for @canonical-paths -> $canon-rec {
    my @actual-path = $sth-actual.execute($canon-rec<path> ↣ $isometry-rec<isometry>).row();
    $sto-path.execute($map, $canon-rec<num>, @actual-path[0], $isometry-rec<isometry>, $isometry-rec<recipr>);
  }
}
$dbh.execute(q:to/SQL/, $map);
update Maps
set    with_isom = 1
where  map = ?
SQL
$dbh.execute("commit");

}
maj-isometries('ico', %( 'Id' => "BCDFGHJKLMNPQRSTVWXZ"
                       , 'λ'  => "GBCDFKLMNPQZXWRSTVJH"
                       , 'κ'  => "PCBZQRWXHGFDMLKJVTSN"
                       , 'ɩ'  => "CBGFDMLKJHXZQRWVTSNP"
                       ) );
maj-isometries('PL4', %( 'Id' => "ABCD"
                       , 'κ'  => "ACDB"
                       , 'ɩ'  => "BACD"
                       ) );

=begin POD

=encoding utf8

=head1 NAME

gener-isom.raku -- generating the isometries for the icosian game

=head1 DESCRIPTION

This programme  generates the isometries for the icosian game
and the relations between canonical paths and other paths.

=head1 USAGE

  raku gener-isom.raku

=head1 PARAMETERS

None.

=head1 OTHER ELEMENTS

=head2 Database Configuration

The   filename  of   the  SQLite   database  is   hard-coded  in   the
F<lib/db-conf-sql.rakumod> file.  Be sure to update  this value before
running the F<gener1.raku> programme.

=head1 COPYRIGHT and LICENSE

Copyright (C) 2023, 2024 Jean Forget, all rights reserved

This programme  is published  under the same  conditions as  Raku: the
Artistic License version 2.0.

The text of  the licenses is available  in the F<LICENSE-ARTISTIC-2.0>
file in this repository, or you can read them at:

  L<https://raw.githubusercontent.com/Raku/doc/master/LICENSE>

=end POD
