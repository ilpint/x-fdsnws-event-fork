(:~
 : Index module.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version '3.1';
module namespace in='http://webservices.ingv.it/fdsnws/event/modules/index';
import module namespace co='http://webservices.ingv.it/fdsnws/utils/commons' at '../../utils/commons.xqm';
import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settings.xqm';
import module namespace su='http://webservices.ingv.it/fdsnws/event/modules/util' at 'util.xqm';
import module namespace lo='http://webservices.ingv.it/fdsnws/utils/log'at '../../utils/log.xqm';
import module namespace xq = 'http://basex.org/modules/xquery';

declare variable $in:DatabaseNamePrefix := se:get-database_name_prefix();

(: max <text> rows to insert per batch :)
declare variable $in:TextBatchSize := 1000;

(:-------------------------------------------------------------:)
(: Micro-transaction helper: run update:apply(f, [arg]) safely :)
(: usato da index_ensure_doc / index_ensure_containers / stats  :)
(:-------------------------------------------------------------:)
declare %updating function in:apply(
  $fun as function(*),
  $arg as item()
) as empty-sequence() {
  xq:eval-update(
    'declare variable $f external; declare variable $a external;
     update:apply($f, [$a])',
    map { 'f': $fun, 'a': $arg }
  )
};

(:-------------------------------------------------------------:)
(: Assicura che esista il DB di index e il file prefix-index.xml :)
(: root = <databases/>                                         :)
(:-------------------------------------------------------------:)
declare %updating function in:index_ensure_doc() {
  in:index_ensure_doc($in:DatabaseNamePrefix)
};

declare %updating function in:index_ensure_doc($prefix as xs:string) {
  let $target   := 'index-' || $prefix,
      $indexdoc := $prefix || '-index.xml'
  return in:apply(
    %updating function($m as map(*)) as empty-sequence() {
      let $t := $m?target,
          $p := $m?indexdoc
(:      let $skeleton:= in:index_template_database():)
      return
        if (db:exists($t)) then
          ( if (not(doc-available($t || '/' || $p))) then
              db:add($t, <databases/>, $p)
            else ()
          )
        else
          db:create($t, <databases/>, $p)
    },
    map { 'target': $target, 'indexdoc': $indexdoc }
  )
};

(:-------------------------------------------------------------:)
(: Assicura che esista un <database name='...'/> per ogni sorgente :)
(: nel file prefix-index.xml                                   :)
(:-------------------------------------------------------------:)
declare %updating function in:index_ensure_containers($prefix as xs:string) {
  let $target   := 'index-' || $prefix,
      $indexdoc := $prefix || '-index.xml',
      $src      := db:list()[matches(., '^' || $prefix)]
  return (
    for $db in $src
    return in:apply(
      %updating function($m as map(*)) as empty-sequence() {
        let $t    := $m?target,
            $p    := $m?indexdoc,
            $name := $m?name,
            $doc  := doc($t || '/' || $p),
            $root := $doc/databases,
            $c    := $root/database[normalize-space(@name) = $name][1]
        return
          if (exists($c)) then ()
          else insert node
            <database name='{$name}'
                      starttime='' endtime=''
                      minlatitude='' maxlatitude=''
                      minlongitude='' maxlongitude=''
                      eventcount='0'/>
          as last into $root
      },
      map { 'target': $target, 'indexdoc': $indexdoc, 'name': $db }
    )
  )
};

(: Return all Version nodes contained in a stored document/item :)
declare function in:version-nodes($doc as item()) as element()* {
  $doc/descendant-or-self::*[local-name() = 'Version']
};

(: Return the Version nodes to index for a single stored document/item.
 : This temporal index stores one <text> row per indexed Version, not only
 : the currently-open one. Callers can later filter by @vstart/@vend. :)
declare function in:indexable-versions-from-doc($doc as item()) as element()* {
  for $version in in:version-nodes($doc)
  let $event := ($version/descendant::*[local-name() = 'event'])[1]
  where exists($event)
  return $version
};

(: Return all Version nodes to index for a database. :)
declare function in:indexable-versions($db as xs:string) as element()* {
  for $path in db:list($db)
  let $doc := db:get($db, $path)
  return in:indexable-versions-from-doc($doc)
};


(: As multiple origins, multiple magnitudes and arrivals cannot be represented in the text format, service
implementations should ignore the ‘includeallorigins’, ‘includeallmagnitudes’ and ‘includearrivals’
parameters when the text output has been selected.
Takes into account preferred and origin magnitude only for extended_text
 :)
declare %updating function in:index_populate_full($prefix as xs:string) {

  let $EARTH_RADIUS := 6371.0,
      $DEGREE_TO_KM := 111.1949,
      $target   := 'index-' || $prefix,
      $indexdoc := $prefix || '-index.xml',
      $src      := db:list()[matches(., '^' || $prefix)]

  return
    for $db in $src
    return
      let $doc       := doc($target || '/' || $indexdoc),
          $root      := $doc/databases,
          $container := $root/database[normalize-space(@name) = $db][1],
(:          $events    := db:get($db)//*:event,:)
          $versions := in:indexable-versions($db),
          $rowCount   := count($versions),
          $batchSize := $in:TextBatchSize
      return
        if (empty($container)) then
          ()
        else
          (
            (: 1) elimina eventuali vecchi <text> per questo DB :)
            delete nodes $container/text,

            (: 2) inserisci i nuovi <text> a batch :)
            for $start in 1 to $rowCount
            where (($start - 1) mod $batchSize) = 0
            let $versionsBatch := subsequence($versions, $start, $batchSize)
            return
              for $versionNode in $versionsBatch
              let $event := ($versionNode/descendant::*[local-name() = 'event'])[1]
              let $revision := string($versionNode/@revision)
              let $vstart := string($versionNode/@start)
              let $vend := string($versionNode/@endDate)
              let $evID := string($event/@publicID)
              let $evType := string($event/*:type)
              let $evLocName := string(($event/*:description/*:text)[1])
              let $contributor := string($event/*:creationInfo/*:agencyID)

              (: preferred origin :)
              let $prefOriginID := string($event/*:preferredOriginID)
              let $prefOrigin := ($event/*:origin[@publicID=$prefOriginID], $event/*:origin)[1]
              let $originID := string($prefOrigin/@publicID)
              let $ot       := co:toggle-z(string($prefOrigin/*:time/*:value), false())
              let $err_ot    := string($prefOrigin/*:time/*:uncertainty)
              let $lat      := string($prefOrigin/*:latitude/*:value)
              let $lon      := string($prefOrigin/*:longitude/*:value)

              (: ---- cells ---- :)
              let $cell :=
                if ($lat and $lon)
                then in:cell-id(xs:double($lat), xs:double($lon), $in:CELL1_STEP)
                else ''

              let $cell2 :=
                if ($lat and $lon)
                then in:cell-id(xs:double($lat), xs:double($lon), $in:CELL2_STEP)
                else ''

              let $depth_m  := string($prefOrigin/*:depth/*:value)
              let $depthType:= string($prefOrigin/*:depthType)
              let $oVer     := string($prefOrigin/*:creationInfo/*:version)
              let $oQual    := string($prefOrigin/*:creationInfo/*:quality)
              let $rms      := string($prefOrigin/*:quality/*:standardError)
              let $gap      := string($prefOrigin/*:quality/*:azimuthalGap)
              let $horizUnc_m := string($prefOrigin/*:originUncertainty/*:horizontalUncertainty)
              let $confLevel  := string($prefOrigin/*:originUncertainty/*:confidenceLevel)
              let $depthUnc_m := string($prefOrigin/*:depth/*:uncertainty)

              let $arrival:=$prefOrigin/*:arrival
              let $nph_p_used := count($arrival[starts-with(*:phase, 'P') and *:timeWeight>0] )
              let $nph_s_used := count($arrival[starts-with(*:phase, 'S') and *:timeWeight>0] )
              let $nph_tot := count($arrival )
              let $err_lon_km := ($prefOrigin/*:longitude/*:uncertainty) * $EARTH_RADIUS * math:cos($prefOrigin/*:latitude/*:value/text() * 2.0 * math:pi()  div 360.0 ) * 2 * math:pi() div 360.0
              let $err_lat_km := ($prefOrigin/*:latitude/*:uncertainty) * $EARTH_RADIUS * 2.0 * math:pi() div 360.0
              let $nph_tot_used := $nph_p_used+$nph_s_used

              (: optional counters/distances/errors :)
              let $min_dist_km := min($arrival/*:distance ) * $DEGREE_TO_KM
              let $max_dist_km := max($arrival/*:distance ) * $DEGREE_TO_KM

              (: magnitudes :)
              let $prefMagID := string($event/*:preferredMagnitudeID)
              let $magB := ($event/*:magnitude[@publicID=$prefMagID])
              let $magA := if (empty($event/*:magnitude[*:originID/text()=$originID]))
                          then ($event/*:magnitude[@publicID=$prefMagID])
                          else ($event/*:magnitude[*:originID/text()=$originID])[1]

              let $magA_id  := string($magA/@publicID)
              let $magA_type:= string($magA/*:type)
              let $magA_val := string($magA/*:mag/*:value)
              let $magA_unc := string($magA/*:mag/*:uncertainty)
              let $magA_sc  := string($magA/*:stationCount)
              let $magA_q   := string($magA/*:creationInfo/*:mag_quality)

              let $magB_id  := string(($magB/@publicID)[1])
              let $magB_type:= string(($magB/*:type)[1])
              let $magB_val := string(($magB/*:mag/*:value)[1])
              let $magB_unc := string(($magB/*:mag/*:uncertainty)[1])
              let $magB_sc  := string(($magB/*:stationCount)[1])
              let $magB_q   := string(($magB/*:creationInfo/*:mag_quality)[1])
              let $magB_author := string(($magB/*:creationInfo/*:author)[1])

              let $originAuthor := string($prefOrigin/*:creationInfo/*:author)

              let $new :=
                <text
                  eventID='{ $evID }'
                  origintime='{ $ot }'
                  originID='{ $originID }'
                  latitude='{ $lat }'
                  longitude='{ $lon }'
                  cell1='{ $cell }'
                  cell2='{ $cell2 }'
                  depth='{ $depth_m }'
                  author='{ $originAuthor }'
                  catalog='{ su:extract-catalog($db) }'
                  contributor='{ $contributor }'
                  contributorID='{ $evID }'

                  magnitude_type='{ $magA_type }'
                  magtype='{ $magA_type }'
                  magnitude='{ $magA_val }'

                  eventlocationname='{ $evLocName }'
                  eventtype='{ $evType }'
                  version='{ $oVer }'
                  revision='{ $revision }'
                  vstart='{ $vstart }'
                  vend='{ $vend }'
                  fixed_depth='{ if ($depthType = 'from location') then '0'
                                 else if ($depthType) then '1' else '' }'
                  origin_Q='{ $oQual }'
                  rms='{ $rms }'
                  gap='{ if ($gap) then format-number(xs:decimal($gap), '0.0') else '' }'
                  nph_tot='{ $nph_tot }'
                  nph_tot_used='{ $nph_tot_used }'
                  nph_p_used='{ $nph_p_used }'
                  nph_s_used='{ $nph_s_used }'
                  min_dist_km='{ if ($min_dist_km) then format-number(xs:decimal($min_dist_km), '0.00') else '' }'
                  max_dist_km='{ if ($max_dist_km) then format-number(xs:decimal($max_dist_km), '0.00') else '' }'
                  err_ot='{ $err_ot }'
                  err_lon_km='{ if ($err_lon_km) then format-number( xs:decimal($err_lon_km), '0.00') else ''}'
                  err_lat_km='{ if ($err_lat_km) then format-number( xs:decimal($err_lat_km), '0.00') else  ''}'
                  err_depth_km='{ if ($depthUnc_m) then format-number(xs:decimal($depthUnc_m) div 1000, '0.00') else '' }'
                  err_h_km='{ if ($horizUnc_m) then format-number(xs:decimal($horizUnc_m) div 1000, '0.00') else '' }'
                  err_z_km='{ if ($depthUnc_m) then format-number(xs:decimal($depthUnc_m) div 1000, '0.00') else '' }'
                  confidence_level='{ if ($confLevel) then format-number(xs:decimal($confLevel), '0.0') else '' }'
                  magnitude_id='{ $magA_id }'
                  magnitude_Q='{ $magA_q }'
                  magnitude_err='{ $magA_unc }'
                  magnitude_ncha_used='{ $magA_sc }'
                  pref_magnitude_id='{ $magB_id }'
                  pref_magnitude_type='{ $magB_type }'
                  pref_magnitude='{ $magB_val }'
                  pref_magnitude_Q='{ $magB_q }'
                  pref_magnitude_err='{ $magB_unc }'
                  pref_magnitude_ncha_used='{ $magB_sc }'
                  pref_magnitude_author='{ $magB_author }'
                  source='{ $evID }'
                  id='{db:node-id($event)}'
                >
                </text>

              return insert node $new as last into $container,

            (: 3) aggiorna eventcount :)
            replace value of node $container/@eventcount
              with string($rowCount)
          )
};

(:-------------------------------------------------------------:)
(: Ricalcola per-DB start/end times e bounding box             :)
(:-------------------------------------------------------------:)
declare %updating function in:index_refresh_stats($prefix as xs:string) {
  let $target   := 'index-' || $prefix,
      $indexdoc := $prefix || '-index.xml'
  return in:apply(
    %updating function($m as map(*)) as empty-sequence() {
      let $t   := $m?target,
          $p   := $m?indexdoc,
          $doc := doc($t || '/' || $p)
      return
        for $d in $doc/databases/database
        let $times :=
          for $s in $d/text/@origintime/string()
          let $dt := try { xs:dateTime($s) } catch * { () }
          where exists($dt)
          return $dt
        let $lats :=
          for $s in $d/text/@latitude/string()
          where normalize-space($s) != ''
          return try { xs:decimal($s) } catch * { () }
        let $lons :=
          for $s in $d/text/@longitude/string()
          where normalize-space($s) != ''
          return try { xs:decimal($s) } catch * { () }
        return (
          if (exists($times)) then (
            replace value of node $d/@starttime with string(min($times)),
            replace value of node $d/@endtime   with string(max($times))
          ) else (),
          if (exists($lats)) then (
            replace value of node $d/@minlatitude with string(min($lats)),
            replace value of node $d/@maxlatitude with string(max($lats))
          ) else (),
          if (exists($lons)) then (
            replace value of node $d/@minlongitude with string(min($lons)),
            replace value of node $d/@maxlongitude with string(max($lons))
          ) else ()
        )
    },
    map { 'target': $target, 'indexdoc': $indexdoc }
  )
};


(:-------------------------------------------------------------:)
(: Entry point unico                                           :)
(:-------------------------------------------------------------:)
declare %updating function in:make_event_index($prefix as xs:string, $dbnames as xs:string) {

  let $target   := 'index-'||$prefix,
      $indexdoc := $prefix || '-index.xml',
      $template := in:index_template_database($dbnames)
  return
  if (not(doc-available($target || '/' || $indexdoc))) then
  db:create($target, $template, $indexdoc)
  else
  (
    in:index_ensure_doc($prefix),
    in:index_ensure_containers($prefix),
    in:index_populate_full($prefix),
    in:index_refresh_stats($prefix)
  )
};


declare %updating function in:make_event_index() {
  in:make_event_index($in:DatabaseNamePrefix,'')
};


declare %updating function in:prepare_event_index() {
in:prepare_event_index($in:DatabaseNamePrefix)
};

declare %updating function in:prepare_event_index($prefix as xs:string) {

  let $target   := 'index-' || $prefix,
      $indexdoc := $prefix || '-index.xml',
      $template := in:index_template_database($prefix)
  return
  if (not(doc-available($target || '/' || $indexdoc))) then
  db:create($target, $template, $indexdoc)

};

(: --- small info utilities (unchanged) --- :)
declare function in:get-databases_info() as node() { 'index-' ||  $in:DatabaseNamePrefix };

declare function in:get-dbnames() as node() {
  for $db in collection('index-' ||  $in:DatabaseNamePrefix)//*:database
  return $db/@name
};

declare function in:get-info() as node() {
  <databases>{
    for $db in collection('index-' ||  $in:DatabaseNamePrefix)//*:database
    return element database { $db/@*,  $db/(* except ( *:text)) }
  }</databases>
};


(:-------------------------------------------------------------:
 : Registra (una tantum) un nuovo database sorgente
 : - $db: nome completo del DB, es. 'EventDB_2025-CTL-BSI'
 : - se esiste già un <database name='...'>, non fa nulla
 : - se manca, lo aggiunge con attributi vuoti/eventcount=0
 :-------------------------------------------------------------:)
declare %updating function in:index_register_database(
  $db as xs:string
) {
  let $target   := 'index-' || $in:DatabaseNamePrefix,
      $indexdoc := $in:DatabaseNamePrefix || '-index.xml'
  return (
    (: 1) Assicura che esista il DB di index e il file index :)
    if (db:exists($target)) then
      if (doc-available($target || '/' || $indexdoc)) then
        ()
      else
        db:add($target, <databases/>, $indexdoc)
    else
      db:create($target, <databases/>, $indexdoc),

    (: 2) Aggiungi lo skeleton per questo solo DB se manca :)
    let $doc  := doc($target || '/' || $indexdoc),
        $root := $doc/databases,
        $existing := $root/database[normalize-space(@name) = $db][1]
    return
      if (exists($existing)) then
        ()
      else
        insert node
          <database name='{$db}'
                    starttime='' endtime=''
                    minlatitude='' maxlatitude=''
                    minlongitude='' maxlongitude=''
                    eventcount='0'/>
        as last into $root
  )
};

declare function in:index_template_database($external as xs:string) as node()* {
let $dbnames := if ($external='') then se:get-dbnames() else $external
return
<databases> {
for $db in $dbnames
return
         <database name='{$db}'
                    starttime='' endtime=''
                    minlatitude='' maxlatitude=''
                    minlongitude='' maxlongitude=''
                    eventcount='0'/>
}
</databases>
};


declare %updating function in:index_rebuild_skeleton() {
  in:index_rebuild_skeleton($in:DatabaseNamePrefix)
};

declare %updating function in:index_rebuild_skeleton($prefix as xs:string) {
  let $target   := 'index-' || $prefix,
      $indexdoc := $prefix || '-index.xml',
      $src      := db:list()[matches(., '^' || $prefix)]
  let $doc :=
    <databases>{
      for $db in $src
      order by $db
      return
        <database name='{$db}'
                  starttime='' endtime=''
                  minlatitude='' maxlatitude=''
                  minlongitude='' maxlongitude=''
                  eventcount='0'/>
    }</databases>
  return
    if (db:exists($target)) then (
      if (doc-available($target || '/' || $indexdoc)) then
        db:delete($target, $indexdoc)
      else (),
      db:add($target, $doc, $indexdoc)
    )
    else
      db:create($target, $doc, $indexdoc)
};

(:::::::::::::::::: bucket definition and functions :::::::::::::::::::::)

(: degrees grid step :)
(:declare variable $in:CELL_STEP as xs:double := 0.25;:)

declare function in:cell-id($lat as xs:double, $lon as xs:double, $step as xs:double) as xs:string {
  let $latc := max((-90.0, min((90.0, $lat))))
  (: normalize lon to [-180, 180) :)
  let $lon0 := $lon
  let $lonN := $lon0 - 360.0 * floor(($lon0 + 180.0) div 360.0)
  let $lonc := max((-180.0, min((180.0, $lonN))))
  let $iy := xs:integer(floor( ($latc + 90.0) div $step ))
  let $ix := xs:integer(floor( ($lonc + 180.0) div $step ))
  return concat("c_", $iy, "_", $ix)
};

(: Return cells for a bbox; supports antimeridian crossing by splitting lon range :)

(: Convert radius to degrees delta for a bbox cover.
   - If radius is given in degrees: use directly.
   - If radius in km: convert using ~111.1949 km/deg and lon scaling by cos(lat).
 :)
declare function in:bbox-for-radius(
  $centerLat as xs:double,
  $centerLon as xs:double,
  $radiusDeg as xs:double?
) as map(*) {
  let $r := if (exists($radiusDeg)) then $radiusDeg else 0.0
  return map{
    "minLat": $centerLat - $r,
    "maxLat": $centerLat + $r,
    "minLon": $centerLon - $r,
    "maxLon": $centerLon + $r
  }
};

declare function in:bbox-for-radius-km(
  $centerLat as xs:double,
  $centerLon as xs:double,
  $radiusKm as xs:double?
) as map(*) {
  let $rkm := if (exists($radiusKm)) then $radiusKm else 0.0
  let $degPerKm := 1.0 div 111.1949
  let $dLat := $rkm * $degPerKm
  let $cosLat := max((0.000001, math:cos($centerLat * math:pi() div 180.0)))
  let $dLon := $rkm * $degPerKm div $cosLat
  return map{
    "minLat": $centerLat - $dLat,
    "maxLat": $centerLat + $dLat,
    "minLon": $centerLon - $dLon,
    "maxLon": $centerLon + $dLon
  }
};

(: Single entry point:
   - If QUERY_PARAM contains a circle/annulus max radius (deg or km), build covering bbox from max radius.
   - Else use bbox params (min/max lat/lon).
   Then return cells (antimeridian-safe).
 :)
declare function in:cells-from-query($Q as map(*), $step as xs:double) as xs:string* {
  let $cLat := in:get-first-num($Q, ("latitude","lat"))
  let $cLon := in:get-first-num($Q, ("longitude","lon"))
  let $maxR := in:get-first-num($Q, ("maxradius")) (: degrees :)

  return
    if (exists($cLat) and exists($cLon) and exists($maxR) and $maxR > 0) then
      (: circle/annulus prefilter by covering bbox (degrees) :)
      in:cells-for-bbox-wrap(
        $cLat - $maxR, $cLon - $maxR,
        $cLat + $maxR, $cLon + $maxR,
        $step
      )
    else
      (: bbox query :)
      let $minLat := in:get-first-num($Q, ("minlatitude","minlat"))
      let $maxLat := in:get-first-num($Q, ("maxlatitude","maxlat"))
      let $minLon := in:get-first-num($Q, ("minlongitude","minlon"))
      let $maxLon := in:get-first-num($Q, ("maxlongitude","maxlon"))
      return in:cells-for-bbox-wrap($minLat, $minLon, $maxLat, $maxLon, $step)
};



declare function in:_get-str($m as map(*), $k as xs:string) as xs:string? {
  if (map:contains($m, $k)) then normalize-space(string($m($k))) else ()
};

declare function in:get-first-num($m as map(*), $keys as xs:string*) as xs:double? {
  let $v :=
    head(
      for $k in $keys
      let $s := in:_get-str($m, $k)
      where exists($s) and $s ne ''
      return $s
    )
  return if (exists($v)) then xs:double($v) else ()
};

declare function in:get-first-dt($m as map(*), $keys as xs:string*) as xs:dateTime? {
  let $v :=
    head(
      for $k in $keys
      let $s := in:_get-str($m, $k)
      where exists($s) and $s ne ''
      return $s
    )
  return if (exists($v)) then xs:dateTime($v) else ()
};


declare function in:cells-from-query-canonical($Q as map(*), $step as xs:double) as xs:string* {
  (: radius (degrees) :)
  let $maxRstr := normalize-space(string($Q("maxradius")))
  let $useRadius := in:is-finite($maxRstr) and $maxRstr ne '' and xs:double($maxRstr) > 0
  let $maxR := if ($useRadius) then xs:double($maxRstr) else 0.0

  (: global radius (default maxradius=180) -> disable cell prefilter :)
  let $radiusIsGlobal := $useRadius and $maxR >= 180.0

  (: bbox bounds (support partial bounds) :)
  let $minLatS := string($Q("minlatitude"))
  let $maxLatS := string($Q("maxlatitude"))
  let $minLonS := string($Q("minlongitude"))
  let $maxLonS := string($Q("maxlongitude"))

  let $minLatOk := in:is-finite($minLatS)
  let $maxLatOk := in:is-finite($maxLatS)
  let $minLonOk := in:is-finite($minLonS)
  let $maxLonOk := in:is-finite($maxLonS)

  (: only use bbox->cells when bbox is fully finite; partial bbox could explode to half-world :)
  let $bboxFullyFinite := $minLatOk and $maxLatOk and $minLonOk and $maxLonOk

  return
    if ($useRadius and not($radiusIsGlobal)) then
      let $cLat := xs:double($Q("latitude"))
      let $cLon := xs:double($Q("longitude"))
      return in:cells-for-bbox-wrap(
        $cLat - $maxR, $cLon - $maxR,
        $cLat + $maxR, $cLon + $maxR,
        $step
      )
    else if ($bboxFullyFinite) then
      in:cells-for-bbox-wrap(
        xs:double($minLatS), xs:double($minLonS),
        xs:double($maxLatS), xs:double($maxLonS),
        $step
      )
    else
      ()  (: disable cell prefilter :)
};

(: =========================
 :  Cell parameters
 : ========================= :)
declare variable $in:CELL1_STEP as xs:double := 1.0;    (: coarse :)
declare variable $in:CELL2_STEP as xs:double := 0.25;   (: fine :)
declare variable $in:MAX_CELLS_FOR_PREFILTER as xs:integer := 600;  (: soglia per scegliere livello :)
declare variable $in:GLOBAL_RADIUS_DEG as xs:double := 180.0;

(: =========================
 :  Helpers
 : ========================= :)
declare function in:is-finite($s as xs:string?) as xs:boolean {
  let $t := upper-case(normalize-space(string($s)))
  return not($t = ('', 'INF', '+INF', '-INF', 'NAN'))
};

declare function in:norm-lon($lon as xs:double) as xs:double {
  (: normalize to [-180,180], keeping 180 as 180 :)
  if ($lon = 180.0) then 180.0
  else $lon - 360.0 * floor(($lon + 180.0) div 360.0)
};

declare function in:cells-for-bbox-wrap(
  $minLat as xs:double, $minLon as xs:double,
  $maxLat as xs:double, $maxLon as xs:double,
  $step   as xs:double
) as xs:string* {

  let $minLat2 := max((-90.0, min((90.0, min(($minLat, $maxLat))))))
  let $maxLat2 := max((-90.0, min((90.0, max(($minLat, $maxLat))))))

  let $minLonN := in:norm-lon($minLon)
  let $maxLonN := in:norm-lon($maxLon)

  let $iyMin := xs:integer(floor( ($minLat2 + 90.0) div $step ))
  let $iyMax := xs:integer(floor( ($maxLat2 + 90.0) div $step ))

  let $xCellsTotal := xs:integer(floor(360.0 div $step))

  return
    if ($minLonN <= $maxLonN) then
      let $ixMin := xs:integer(floor( ($minLonN + 180.0) div $step ))
      let $ixMax :=
        if ($maxLonN = 180.0)
        then $xCellsTotal - 1
        else xs:integer(floor( ($maxLonN + 180.0) div $step ))
      return
        for $iy in $iyMin to $iyMax
        for $ix in $ixMin to $ixMax
        return concat("c_", $iy, "_", $ix)
    else
      (: wrap: [minLon..180] U [-180..maxLon] :)
      let $cellsA :=
        let $ixMin := xs:integer(floor( ($minLonN + 180.0) div $step ))
        let $ixMax := $xCellsTotal - 1
        return
          for $iy in $iyMin to $iyMax
          for $ix in $ixMin to $ixMax
          return concat("c_", $iy, "_", $ix)
      let $cellsB :=
        let $ixMin := 0
        let $ixMax := xs:integer(floor( ($maxLonN + 180.0) div $step ))
        return
          for $iy in $iyMin to $iyMax
          for $ix in $ixMin to $ixMax
          return concat("c_", $iy, "_", $ix)
      return ($cellsA, $cellsB)
};

(: Decide bbox covering for cell computation:
   - If radius is active and not global: use circle covering bbox
   - Else if bbox fully finite: use bbox
   - Else: no cells
 :)
declare function in:covering-bbox-from-query($Q as map(*)) as map(*) {
  let $maxRstr := normalize-space(string($Q("maxradius")))
  let $useRadius :=
    in:is-finite($maxRstr) and $maxRstr ne '' and xs:double($maxRstr) > 0 and xs:double($maxRstr) < $in:GLOBAL_RADIUS_DEG

  let $minLatS := string($Q("minlatitude"))
  let $maxLatS := string($Q("maxlatitude"))
  let $minLonS := string($Q("minlongitude"))
  let $maxLonS := string($Q("maxlongitude"))
  let $bboxFullyFinite :=
    in:is-finite($minLatS) and in:is-finite($maxLatS) and in:is-finite($minLonS) and in:is-finite($maxLonS)

  return
    if ($useRadius) then
      let $cLat := xs:double($Q("latitude"))
      let $cLon := xs:double($Q("longitude"))
      let $maxR := xs:double($maxRstr)
      return map{
        "mode":"radius",
        "minLat": $cLat - $maxR,
        "maxLat": $cLat + $maxR,
        "minLon": $cLon - $maxR,
        "maxLon": $cLon + $maxR
      }
    else if ($bboxFullyFinite) then
      map{
        "mode":"bbox",
        "minLat": xs:double($minLatS),
        "maxLat": xs:double($maxLatS),
        "minLon": xs:double($minLonS),
        "maxLon": xs:double($maxLonS)
      }
    else
      map{ "mode":"none" }
};

(: Main decision:
   returns map { "use": xs:boolean, "attr": "cell1|cell2", "cells": xs:string* }
 :)
declare function in:cell-plan($Q as map(*)) as map(*) {
  let $bb := in:covering-bbox-from-query($Q)
  return
    if ($bb("mode") = "none") then
      let $_:= lo:debug("mode = none") return
      map{ "use": false(), "attr": "", "cells": () }
    else
      let $cells2 := in:cells-for-bbox-wrap($bb("minLat"), $bb("minLon"), $bb("maxLat"), $bb("maxLon"), $in:CELL2_STEP)
      let $n2 := count(subsequence($cells2, 1, $in:MAX_CELLS_FOR_PREFILTER + 1))
      return
        if ($n2 > 0 and $n2 <= $in:MAX_CELLS_FOR_PREFILTER) then
          map{ "use": true(), "attr": "cell2", "cells": $cells2 }
        else
          let $cells1 := in:cells-for-bbox-wrap($bb("minLat"), $bb("minLon"), $bb("maxLat"), $bb("maxLon"), $in:CELL1_STEP)
          let $n1 := count(subsequence($cells1, 1, $in:MAX_CELLS_FOR_PREFILTER + 1))
          return
            if ($n1 > 0 and $n1 <= $in:MAX_CELLS_FOR_PREFILTER) then
              let $_:= lo:debug("use = true(), attr = cell1, cells= "||fn:string-join($cells1)) return
              map{ "use": true(), "attr": "cell1", "cells": $cells1 }
            else
              map{ "use": false(), "attr": "", "cells": () }
};


declare function in:db-timestamp() as map(*) {
  let $db := 'index-' || $in:DatabaseNamePrefix
  let $dateTime := xs:dateTime(db:property($db, 'timestamp'))
(:  let $dateTime:= fn:current-dateTime():)
  let $utc := adjust-dateTime-to-timezone($dateTime, xs:dayTimeDuration('PT0S'))
  let $dayZero := xs:dateTime('1970-01-01T00:00:00Z')
  let $ts := xs:integer(( $utc - $dayZero ) div xs:dayTimeDuration('PT1S'))
  return map {
    "database" : $db,
    "timestamp" : $ts
  }
};