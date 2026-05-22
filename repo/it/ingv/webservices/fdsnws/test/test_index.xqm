(:~
 : index test module
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace test_index='http://webservices.ingv.it/fdsnws/test';

import module namespace unit='http://basex.org/modules/unit';
import module namespace in='http://webservices.ingv.it/fdsnws/event/modules/index' at '../event/modules/index.xqm';
(: import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at '../event/modules/settings.xqm'; :)
import module namespace su='http://webservices.ingv.it/fdsnws/event/modules/util' at '../event/modules/util.xqm';
import module namespace db='http://basex.org/modules/db';

(:
README
how to use this tests:
Execute into container: basex -t basex/repo/it/ingv/webservices/fdsnws/event/modules/test_index.xqm
:)

(: ---------------------------------------------------------- :)
(: Variabili di comodo                                         :)
(: ---------------------------------------------------------- :)

declare variable $test_index:prefix    := 'UNIT_';
(: DB eventi di test, es: "EventDB_UNIT-2015-TEST" :)
declare variable $test_index:data-db   := $test_index:prefix || '2015';
declare variable $test_index:data-doc  := 'UNIT-2015.xml';
(: DB index, es: "index-EventDB_" :)
declare variable $test_index:index-db  := $test_index:prefix || $test_index:data-db;
(: Documento index, es: "EventDB_-index.xml" :)
declare variable $test_index:index-doc := $test_index:prefix || '-index.xml';


(: ---------------------------------------------------------- :)
(: SETUP: crea DB eventi di test, skeleton, e index completo   :)
(: ---------------------------------------------------------- :)

declare %unit:before-module %updating function test_index:setup() {
  (
    (: 1) pulizia di sicurezza :)
    if (db:exists($test_index:data-db))  then db:drop($test_index:data-db)  else (),
(:    if (db:exists($test_index:index-db)) then db:drop($test_index:index-db) else (),:)

    (: 2) crea un piccolo DB eventi di test :)
    db:create(
      $test_index:data-db,
      <root>
        <event publicID="smi:test/e1">
          <type>earthquake</type>
          <description><text>Evento 1 di test</text></description>
          <creationInfo><agencyID>UNIT</agencyID></creationInfo>
          <origin publicID="o1">
            <time><value>2020-01-01T00:00:00</value></time>
            <latitude><value>10.0</value></latitude>
            <longitude><value>20.0</value></longitude>
            <depth><value>10000</value></depth>
            <creationInfo>
              <version>1</version>
              <quality>A</quality>
            </creationInfo>
          </origin>
          <preferredOriginID>o1</preferredOriginID>
          <magnitude publicID="m1">
            <originID>o1</originID>
            <type>ML</type>
            <mag><value>3.2</value></mag>
            <creationInfo>
              <mag_quality>good</mag_quality>
              <author>UNIT-MAG</author>
            </creationInfo>
          </magnitude>
          <preferredMagnitudeID>m1</preferredMagnitudeID>
        </event>

        <event publicID="smi:test/e2">
          <type>quarry blast</type>
          <description><text>Evento 2 di test</text></description>
          <creationInfo><agencyID>UNIT</agencyID></creationInfo>
          <origin publicID="o2">
            <time><value>2021-06-01T01:02:03</value></time>
            <latitude><value>15.0</value></latitude>
            <longitude><value>30.0</value></longitude>
            <depth><value>5000</value></depth>
            <creationInfo>
              <version>1</version>
              <quality>B</quality>
            </creationInfo>
          </origin>
          <preferredOriginID>o2</preferredOriginID>
          <magnitude publicID="m2">
            <originID>o2</originID>
            <type>MW</type>
            <mag><value>4.5</value></mag>
            <creationInfo>
              <mag_quality>fair</mag_quality>
              <author>UNIT-MAG</author>
            </creationInfo>
          </magnitude>
          <preferredMagnitudeID>m2</preferredMagnitudeID>
        </event>
      </root>,
      $test_index:data-doc

    ),

    (: 3) costruisce lo skeleton dell'index da db:list() :)
(:    in:index_rebuild_skeleton($test_index:prefix),:)

    (: 4) UNA SOLA chiamata alla pipeline di indicizzazione :)
    in:make_event_index($test_index:prefix,$test_index:data-db)

  )
};

(: ---------------------------------------------------------- :)
(: TEARDOWN: pulizia                                            :)
(: ---------------------------------------------------------- :)

declare %unit:after-module %updating function test_index:teardown() {
  (
    if (db:exists($test_index:data-db))  then db:drop($test_index:data-db)  else ()
(:    ,:)
(:    if (db:exists($test_index:index-db)) then db:drop($test_index:index-db) else ():)
  )
};

declare %unit:test %updating function test_index:database-index-re-created() {
in:make_event_index($test_index:prefix,$test_index:data-db)
};
declare %unit:test %updating function test_index:database-index-refreshed() {
in:index_refresh_stats($test_index:prefix)
};
(: ---------------------------------------------------------- :)
(: TEST 1: esistenza del container <database>                  :)
(: ---------------------------------------------------------- :)

declare %unit:test function test_index:database-container-created() {
  let $doc := doc('index-' ||$test_index:prefix || '/' || $test_index:index-doc)
  let $db  := $doc/databases/database[@name = $test_index:data-db]
  return unit:assert(
    exists($db),
    concat("Manca il nodo <database> per ", $test_index:data-db)
  )
};

(: ---------------------------------------------------------- :)
(: TEST 2: numero di <text> e @eventcount coerenti            :)
(: ---------------------------------------------------------- :)

declare %unit:test function test_index:eventcount-matches-text-count() {
  let $doc := doc('index-' ||$test_index:prefix || '/' || $test_index:index-doc)
  let $db  := $doc/databases/database[@name = $test_index:data-db]
  return (
    unit:assert(
      exists($db),
      "Nodo <database> non trovato nell'indice"
    ),
    unit:assert-equals(
      count($db/text),
      2,
      "L'indice deve contenere 2 elementi <text> per il DB di test"
    ),
    unit:assert-equals(
      xs:int($db/@eventcount),
      2,
      "@eventcount deve essere 2"
    )
  )
};

(: ---------------------------------------------------------- :)
(: TEST 3: starttime/endtime e bounding box                   :)
(: ---------------------------------------------------------- :)

declare %unit:test function test_index:stats-time-and-bbox() {
  let $doc := doc('index-' ||$test_index:prefix ||  '/' || $test_index:index-doc)
  let $db  := $doc/databases/database[@name = $test_index:data-db]
  return
  (    unit:assert(
      exists($db),
      "Nodo <database> non trovato nell'indice"
    ),

    unit:assert-equals(      xs:dateTime($db/@starttime),
      xs:dateTime("2020-01-01T00:00:00"),
      "starttime non corrisponde al primo evento"
    ),
    unit:assert-equals(      xs:dateTime($db/@endtime),
      xs:dateTime("2021-06-01T01:02:03"),
      "endtime non corrisponde all'ultimo evento"
    ),

    unit:assert-equals(      xs:decimal($db/@minlatitude),
      xs:decimal("10.0"),
      "minlatitude atteso 10.0"
    ),
    unit:assert-equals(       xs:decimal($db/@maxlatitude),
      xs:decimal("15.0"),
      "maxlatitude atteso 15.0"
    ),
    unit:assert-equals(       xs:decimal($db/@minlongitude),
      xs:decimal("20.0"),
      "minlongitude atteso 20.0"
    ),
    unit:assert-equals(       xs:decimal($db/@maxlongitude),
      xs:decimal("30.0"),
      "maxlongitude atteso 30.0"
    )
  )
};

(: ---------------------------------------------------------- :)
(: TEST 4: qualche campo chiave del <text>                    :)
(: ---------------------------------------------------------- :)

declare %unit:test function test_index:text-row-basic-fields() {
  let $doc   := doc('index-' ||$test_index:prefix || '/' || $test_index:index-doc)
  let $db    := $doc/databases/database[@name = $test_index:data-db]
  let $row1  := $db/text[@eventID = "smi:test/e1"][1]
  let $row2  := $db/text[@eventID = "smi:test/e2"][1]
  return
  (    unit:assert(       exists($row1) and exists($row2),
      "Righe <text> per gli eventi di test mancanti"
    ),
    unit:assert-equals(      string($row1/@eventlocationname),
      "Evento 1 di test",
      "eventlocationname (row1) inatteso"
    ),
    unit:assert-equals(      string($row2/@eventtype),
      "quarry blast",
      "eventtype (row2) inatteso"
    ),
    unit:assert-equals(      string($row1/@catalog),
      su:extract-catalog($test_index:data-db),
      "catalog (row1) non coerente con il nome del DB"
    )
  )
};
