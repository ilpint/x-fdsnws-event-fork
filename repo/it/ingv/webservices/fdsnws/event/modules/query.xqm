(:~
 : Query module.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace qu="http://webservices.ingv.it/fdsnws/event/modules/query";
declare namespace ingv='http://webservices.ingv.it/fdsnws/event/1';

import module namespace su='http://webservices.ingv.it/fdsnws/event/modules/util' at 'util.xqm';
import module namespace in='http://webservices.ingv.it/fdsnws/event/modules/index' at 'index.xqm';
import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settings.xqm';
import module namespace lo='http://webservices.ingv.it/fdsnws/utils/log'at '../../utils/log.xqm';


declare copy-namespaces preserve, inherit;
declare default element namespace 'http://quakeml.org/xmlns/bed/1.2';


(:Take en event and prune it for the params:)
declare function qu:build_event_element($QUERY_PARAM as map(*), $event){
            (# db:copynode false #)
            {
                element event {(# db:copynode false #) {$event/@*},
                $event/(* except (
                    if ($QUERY_PARAM("includeallmagnitudes")="false") then *:magnitude,
                    if ($QUERY_PARAM("includeallorigins")="false" )   then *:origin ,
                    if ($QUERY_PARAM("includestationmagnitudes")="false" ) then *:stationMagnitude,
                    if ($QUERY_PARAM("includeamplitudes")="false" ) then *:amplitude,
                    if ($QUERY_PARAM("includearrivals")="false" ) then *:arrival,
                    if ($QUERY_PARAM("includepicks")="false" ) then *:pick
                )
                ),
                (: let $_:= lo:debug("Condition: " || $QUERY_PARAM("includeallmagnitudes") || $QUERY_PARAM("includeallorigins")):)
                (:Removed all origins, put again either the preferred or all:)
                if ($QUERY_PARAM("includeallorigins")="false" ) then
                    for $origin in $event/origin
                        let $preferredOriginID := $event/preferredOriginID/text()
                        (:                    let $_:= lo:debug("$preferredOriginID: " || $preferredOriginID ):)
                    where $origin/@publicID=$preferredOriginID
                    return
                    element origin {
                        (# db:copynode false #){$origin/@*}, $origin/(* except (
                                if($QUERY_PARAM("includearrivals")="false") then  *:arrival)
                            )
                    }
                    else
                        for $origin in $event/origin
                        return
                        element origin {
                            $origin/@*, $origin/(* except (if($QUERY_PARAM("includearrivals")="false"  ) then  *:arrival))
                        }
                ,
                (:If removed all magnitudes, put again the preferred:)
                if ($QUERY_PARAM("includeallmagnitudes")="false") then
                for $magnitude in $event/magnitude
                let $preferredMagnitudeID := $event/preferredMagnitudeID/text()
                (:                    let $_:= lo:debug("preferredMagnitudeID: " || $preferredMagnitudeID ):)
                where $magnitude/@publicID=$preferredMagnitudeID
                return $magnitude
            }
     }
};


declare function qu:query_prune($QUERY_PARAM as map(*)) as node()* {
  let $_ := lo:debug("qu:query_prune() ")

  return (
    (# db:copynode false #) {

    for $event in
    if ($QUERY_PARAM("asofdate-passed")) then
        qu:get_events_asofdate($QUERY_PARAM)
    else
        qu:get_events($QUERY_PARAM)
        /../../../../*:Version[
            @start < xs:dateTime($QUERY_PARAM("asofdate"))
            and (if (exists(@endDate)) then xs:dateTime($QUERY_PARAM("asofdate")) < @endDate else true())
            and xs:dateTime(@start) > xs:dateTime($QUERY_PARAM("updatedafter"))
        ]
        /*:quakeml/*:eventParameters/*:event[
            (if ($QUERY_PARAM('eventtype')='') then true() else $QUERY_PARAM("eventtype") = type/text())
        ]

      let $preferredOriginID := $event/*:preferredOriginID/text()
      let $preferredOrigin := $event/*:origin[@publicID = $preferredOriginID]
      let $preferredOriginTimeValue := $preferredOrigin/*:time/*:value/text()

      let $preferredMagnitudeID := $event/preferredMagnitudeID
      let $preferredMagnitude := $event/magnitude[@publicID = $preferredMagnitudeID]
      let $magnitude := $event/magnitude
      let $magnitudeconstrained := $event/magnitude[type/text() = $QUERY_PARAM("magnitudetype")]

      let $mag_to_check :=
        if ($QUERY_PARAM("magnitudetype") != "") then $magnitudeconstrained
        else if (exists($preferredMagnitude)) then $preferredMagnitude
        else $magnitude

      let $mag_to_check_values := $mag_to_check/mag/value/text()

      order by
        if ($QUERY_PARAM("orderby") = "time") then $preferredOriginTimeValue else () descending,
        if ($QUERY_PARAM("orderby") = "time-asc") then $preferredOriginTimeValue else () ascending,
        if ($QUERY_PARAM("orderby") = "magnitude") then $mag_to_check_values else () descending,
        if ($QUERY_PARAM("orderby") = "magnitude-asc") then $mag_to_check_values else () ascending

      return (# db:copynode false #) { qu:build_event_element($QUERY_PARAM, $event) }
    }
  )
  [
    position() =
      (if (xs:double($QUERY_PARAM("limit")) = xs:double('INF'))
       then xs:int($QUERY_PARAM("offset")) to last()
       else xs:int($QUERY_PARAM("offset")) to (xs:int($QUERY_PARAM("limit")) + xs:int($QUERY_PARAM("offset")) - 1)
      )
  ]
};
(:
  La query estrae le origini necessarie per il formato di testo esteso.
  Esiste una riga per evento
  La preferred origin deve essere quella del BULLETIN_INGV
  Possono esistere due magnitude: quella preferred e quella
  corrispondente alla origin del bollettino
  Prova a gestire anche le Version e il parametro asofdate
  TODO chiamarla quando necessario
  :)

declare function qu:query_extended_text($QUERY_PARAM as map(*)) as node()*{
let $_:=lo:debug("qu:query_extended_text() ")
let $EARTH_RADIUS:=6371.0
let $DEGREE_TO_KM:=111.1949
(: Not only one id but a list of events from params:)

return
(:    if  ($QUERY_PARAM("eventid") ) then:)
(:            ():)
(:        else:)
    (
    (# db:copynode false #) {
for $event in
            if ($QUERY_PARAM("eventid") and $QUERY_PARAM("asofdate-passed")) then
            qu:query_eventid_asofdate($QUERY_PARAM)

        else if ($QUERY_PARAM("eventid")) then
            qu:query_eventid($QUERY_PARAM)

        else if ($QUERY_PARAM("originid") and $QUERY_PARAM("asofdate-passed")) then
            qu:query_originid_asofdate($QUERY_PARAM)

        else if ($QUERY_PARAM("originid")) then
            qu:query_originid($QUERY_PARAM)

        else if ($QUERY_PARAM("asofdate-passed")) then
            qu:get_events_asofdate($QUERY_PARAM)

        else
            qu:get_events($QUERY_PARAM)
            /../../../../*:Version[
                @start < xs:dateTime($QUERY_PARAM("asofdate"))
                and (if (exists(@endDate)) then xs:dateTime($QUERY_PARAM("asofdate")) < @endDate else true())
                and xs:dateTime(@start) > xs:dateTime($QUERY_PARAM("updatedafter"))
            ]
            /*:quakeml/*:eventParameters/*:event[
                (if ($QUERY_PARAM('eventtype')='') then true() else $QUERY_PARAM("eventtype") = type/text())
            ]

    (:        let $_ := lo:debug("event type: " || $event/type/text() || " param: " || $QUERY_PARAM("eventtype") ):)

        let $preferredOriginID := $event/*:preferredOriginID/text()
        let $preferredOrigin := $event/*:origin[@publicID=$preferredOriginID]
        (: let $origin_publicID := $preferredOrigin/@publicID :)
        let $preferredOriginTimeValue := $preferredOrigin/*:time/*:value/text()
        let $preferredMagnitudeID := $event/preferredMagnitudeID
        let $preferredMagnitude := $event/magnitude[@publicID=$preferredMagnitudeID]
        let $preferredOriginID := $event/preferredOriginID
        let $magnitude := $event/magnitude

        let $magnitudeconstrained := $event/magnitude[type/text()=$QUERY_PARAM("magnitudetype")]

        (:TODO change preferred value to check, if magnitudetype different from preferred magnitudetype:)

        let $mag_to_check :=
            if ($QUERY_PARAM("magnitudetype")!="") then $magnitudeconstrained else
            if (exists($preferredMagnitude)) then $preferredMagnitude else $magnitude
        let $mag_to_check_values := $mag_to_check/mag/value/text()
        (:            let $_:=lo:log("magnitude to check " || string-join($mag_to_check_values) || " " || $QUERY_PARAM("maxmag") || " " || $QUERY_PARAM("minmag")):)

        order by
                 if ($QUERY_PARAM("orderby")="time") then $preferredOriginTimeValue  else () descending,
                 if ($QUERY_PARAM("orderby")="time-asc") then $preferredOriginTimeValue else () ascending,
                 if ($QUERY_PARAM("orderby")="magnitude") then $mag_to_check_values else ()  descending,
                 if ($QUERY_PARAM("orderby")="magnitude-asc") then $mag_to_check_values else ()  ascending

        return
            (# db:copynode false #)
            {
                element event {(# db:copynode false #) {$event/@*},

                $event/(* except (
                (: Removing all magnitudes, preferred and related to preferred origin will be placed again in a second step:)
                *:magnitude,
                (: Removing all origins, preferred origin will be placed again in a second step:)
                *:origin ,
                if ($QUERY_PARAM("includestationmagnitudes")="false" ) then *:stationMagnitude,
                if ($QUERY_PARAM("includeamplitudes")="false" ) then *:amplitude,
                if ($QUERY_PARAM("includepicks")="false" ) then *:pick )
                ),

                (:back the preferred origin:)

                for $origin in $event/origin
                let $preferredOriginID := $event/preferredOriginID/text()
                let $_:= lo:debug("$origin_Q: " || $origin/creationInfo/ingv:quality/text() )
                let $arrival:=$origin/arrival
                let $nph_p_used := count($arrival[starts-with(phase, 'P') and timeWeight>0] )
                let $nph_s_used := count($arrival[starts-with(phase, 'S') and timeWeight>0] )
                let $nph_tot := count($arrival )
                let $err_lon_km := ($origin/longitude/uncertainty) * $EARTH_RADIUS * math:cos($origin/latitude/value/text() * 2.0 * math:pi()  div 360.0 ) * 2 * math:pi() div 360.0
                let $err_lat_km := ($origin/latitude/uncertainty) * $EARTH_RADIUS * 2.0 * math:pi() div 360.0
(:                (float(origin['latitude_errors']['uncertainty'])*(ER*2*math.pi))/360. # from degrees to km:)
                let $min_dist_deg := min($arrival/distance )
                let $max_dist_deg := max($arrival/distance )
                let $_:= lo:debug("Count: " || $nph_p_used)
                let $_:= lo:debug("Count: " || $nph_s_used)

                where $origin/@publicID=$preferredOriginID
                return (
                element origin {
                    (# db:copynode false #){$origin/@*}, $origin/(* except ( arrival) )
                }
                , element nph_p_used{$nph_p_used}
                , element nph_s_used{$nph_s_used}
                , element nph_tot_used{$nph_p_used+$nph_s_used}
                , element nph_tot{$nph_tot}
                , element err_lon_km{$err_lon_km}
                , element err_lat_km{$err_lat_km}
                , element min_dist_km{$min_dist_deg * $DEGREE_TO_KM}
                , element max_dist_km{$max_dist_deg * $DEGREE_TO_KM}
                )
                ,

                (: first the magnitude of the preferredorigin:)
                for $magnitude in $event/magnitude
                let $originID := $magnitude/originID/text()
                (:                    let $_:= lo:debug("preferredMagnitudeID: " || $preferredMagnitudeID ):)
                where $originID=$preferredOriginID
                return $magnitude
                ,
               (: then the preferred magnitude, could be the same :)

                for $magnitude in $event/magnitude
                let $preferredMagnitudeID := $event/preferredMagnitudeID/text()
                (:                    let $_:= lo:debug("preferredMagnitudeID: " || $preferredMagnitudeID ):)
                where $magnitude/@publicID=$preferredMagnitudeID
                return $magnitude

            }

     }
     }
    )
    [ position() = (if (xs:double($QUERY_PARAM("limit"))=xs:double('INF'))
                   then
                    xs:int($QUERY_PARAM("offset"))  to last()
                   else
                    xs:int($QUERY_PARAM("offset")) to ( xs:int($QUERY_PARAM("limit")) + xs:int($QUERY_PARAM("offset"))  - xs:int(1))
                    )
    ]
};


declare function qu:query_includeall($QUERY_PARAM as map(*)) as node()* {
  let $_ := lo:debug("query_includeall ")

  return (
    (# db:copynode false #) {
for $event in
    if ($QUERY_PARAM("asofdate-passed")) then
        qu:get_events_asofdate($QUERY_PARAM)
    else
        qu:get_events($QUERY_PARAM)
        /../../../../*:Version[
            @start < xs:dateTime($QUERY_PARAM("asofdate"))
            and (if (exists(@endDate)) then xs:dateTime($QUERY_PARAM("asofdate")) < @endDate else true())
            and xs:dateTime(@start) > xs:dateTime($QUERY_PARAM("updatedafter"))
        ]
        /*:quakeml/*:eventParameters/*:event[
            (if ($QUERY_PARAM('eventtype')='') then true() else $QUERY_PARAM("eventtype") = type/text())
        ]

      let $preferredOriginID := $event/*:preferredOriginID/text()
      let $preferredOrigin := $event/*:origin[@publicID = $preferredOriginID]
      let $preferredOriginTimeValue := $preferredOrigin/*:time/*:value/text()

      let $preferredMagnitudeID := $event/preferredMagnitudeID
      let $preferredMagnitude := $event/magnitude[@publicID = $preferredMagnitudeID]

      let $magnitude := $event/magnitude
      let $magnitudeconstrained := $event/magnitude[type/text() = $QUERY_PARAM("magnitudetype")]

      let $mag_to_check :=
        if ($QUERY_PARAM("magnitudetype") != "") then $magnitudeconstrained
        else if (exists($preferredMagnitude)) then $preferredMagnitude
        else $magnitude

      let $mag_to_check_values := $mag_to_check/mag/value/text()

      order by
        if ($QUERY_PARAM("orderby") = "time") then $preferredOriginTimeValue else () descending,
        if ($QUERY_PARAM("orderby") = "time-asc") then $preferredOriginTimeValue else () ascending,
        if ($QUERY_PARAM("orderby") = "magnitude") then $mag_to_check_values else () descending,
        if ($QUERY_PARAM("orderby") = "magnitude-asc") then $mag_to_check_values else () ascending

      return (# db:copynode false #) { $event }
    }
  )
  [
    position() =
      (if (xs:double($QUERY_PARAM("limit")) = xs:double('INF'))
       then xs:int($QUERY_PARAM("offset")) to last()
       else xs:int($QUERY_PARAM("offset")) to (xs:int($QUERY_PARAM("limit")) + xs:int($QUERY_PARAM("offset")) - 1)
      )
  ]
};

declare function qu:query_includeall_now($QUERY_PARAM  as map(*)) as node()*{
let $_:=lo:debug("query_includeall_now ")

    return (

        for $event in qu:get_events($QUERY_PARAM)
            /../../../../*:Version[@start < xs:dateTime($QUERY_PARAM("asofdate")) and ( if (exists(@endDate)) then xs:dateTime($QUERY_PARAM("asofdate")) < @endDate else true() ) and xs:dateTime(@start) > xs:dateTime($QUERY_PARAM("updatedafter"))]
            /*:quakeml/eventParameters/event[(if ($QUERY_PARAM('eventtype')='') then true() else $QUERY_PARAM("eventtype")=type/text())]

        let $preferredOriginID := $event/*:preferredOriginID/text()
        let $preferredOrigin := $event/*:origin[@publicID=$preferredOriginID]
        (: let $origin_publicID := $preferredOrigin/@publicID :)
        let $preferredOriginTimeValue := $preferredOrigin/*:time/*:value/text()


        let $preferredMagnitudeID := $event/preferredMagnitudeID
        let $preferredMagnitude := $event/magnitude[@publicID=$preferredMagnitudeID]

        let $magnitude := $event/magnitude

        let $magnitudeconstrained := $event/magnitude[type/text()=$QUERY_PARAM("magnitudetype")]

        (:TODO change preferred value to check, if magnitudetype different from preferred magnitudetype:)

        let $mag_to_check :=
            if ($QUERY_PARAM("magnitudetype")!="") then $magnitudeconstrained else
            if (exists($preferredMagnitude)) then $preferredMagnitude else $magnitude
        let $mag_to_check_values := $mag_to_check/mag/value/text()
        (:            let $_:=lo:log("magnitude to check " || string-join($mag_to_check_values) || " " || $QUERY_PARAM("maxmag") || " " || $QUERY_PARAM("minmag")):)
        order by
                 if ($QUERY_PARAM("orderby")="time") then $preferredOriginTimeValue  else () descending,
                 if ($QUERY_PARAM("orderby")="time-asc") then $preferredOriginTimeValue else () ascending,
                 if ($QUERY_PARAM("orderby")="magnitude") then $mag_to_check_values else ()  descending,
                 if ($QUERY_PARAM("orderby")="magnitude-asc") then $mag_to_check_values else ()  ascending

        return $event


    )
    [ position() = (if (xs:double($QUERY_PARAM("limit"))=xs:double('INF'))
       then
        xs:int($QUERY_PARAM("offset"))  to last()
       else
        xs:int($QUERY_PARAM("offset")) to ( xs:int($QUERY_PARAM("limit")) + xs:int($QUERY_PARAM("offset"))  - xs:int(1))
        )
    ]


};

declare function qu:paginate($events as node(),$limit as xs:positiveInteger, $offset as xs:positiveInteger, $QUERY_PARAM  as map(*)) as node()*{
let $_:= lo:debug("qu:paginate limit: " || $limit || " offset: " || $offset )
return
    if ($limit>0 and $offset>0)
        then subsequence($events,$offset, $limit)
        else fn:error(xs:QName('err:nodata'), $QUERY_PARAM("nodata"))

};

(:Take the index from the index-db :)
declare function qu:query_originid($QUERY_PARAM as map(*)) as node()* {
    let $dbinfo := 'index-' || $in:DatabaseNamePrefix
    let $_ := lo:debug(
        "qu:query_originid, looking for event: " || $QUERY_PARAM("originid") ||
        " in " || $dbinfo || " and contributor " || $QUERY_PARAM("contributor")
    )
    let $encoded_originid := $QUERY_PARAM("originid")

    let $database_index :=
        (# db:enforceindex #) {
            (
                for $text in collection($dbinfo)//*:text[
                    @originID = $encoded_originid
                    and string(@vend) = ''
                    and ($QUERY_PARAM("contributor") = "" or @contributor = $QUERY_PARAM("contributor"))
                    and ($QUERY_PARAM("catalog") = "" or @catalog = $QUERY_PARAM("catalog"))
                ]
                return <database name="{ string($text/../@name) }" id="{ string($text/@id) }"/>
            )[1]
        }

    let $_ := lo:debug("qu:query_originid, accessed to index db")

    return
        if (empty($database_index)) then
            ()
        else if ($QUERY_PARAM('format') = 'xml') then
            (# db:copynode false #) { db:get-id($database_index/@name, $database_index/@id) }
        else
            let $event := (# db:copynode false #) { db:get-id($database_index/@name, $database_index/@id) }
            return
                element event {
                    $event/@*,
                    $event/(
                        * except (*:magnitude, *:origin, *:pick)
                    ),

                    (: preferred origin only :)
                    for $origin in $event/*:origin
                    let $preferredOriginID := $event/*:preferredOriginID/text()
                    where $origin/@publicID = $preferredOriginID
                    return
                        element origin {
                            $origin/@*,
                            $origin/(
                                * except (
                                    if ($QUERY_PARAM("includearrivals") = "false")
                                    then *:arrival
                                    else ()
                                )
                            )
                        },

                    (: preferred magnitude only :)
                    for $magnitude in $event/*:magnitude
                    let $preferredMagnitudeID := $event/*:preferredMagnitudeID/text()
                    where $magnitude/@publicID = $preferredMagnitudeID
                    return $magnitude
                }
};


declare function qu:query_originid_asofdate($QUERY_PARAM as map(*)) as node()* {
    try {
        let $_ := lo:debug(
            "qu:query_originid_asofdate, looking for origin: " ||
            $QUERY_PARAM("originid") ||
            " as of " || $QUERY_PARAM("asofdate") ||
            " contributor=" || $QUERY_PARAM("contributor")
        )

        let $asof := xs:dateTime($QUERY_PARAM("asofdate"))
        let $updatedafter := xs:dateTime($QUERY_PARAM("updatedafter"))
        let $originid := $QUERY_PARAM("originid")

        let $matches :=
            for $db in se:get-dbname()
            for $doc in db:get($db)
            let $versions := $doc//*[local-name() = 'Version']
            return
                if (exists($versions)) then
                    for $ver in $versions[
                        xs:dateTime(@start) <= $asof
                        and (
                            if (exists(@endDate))
                            then $asof < xs:dateTime(@endDate)
                            else true()
                        )
                        and xs:dateTime(@start) >= $updatedafter
                    ]
                    for $event in $ver//*:event[*:origin/@publicID = $originid]
                    where (
                        $QUERY_PARAM("contributor") = ""
                        or $event/*:creationInfo/*:agencyID = $QUERY_PARAM("contributor")
                    )
                    return $event
                else
                    for $event in $doc//*:event[*:origin/@publicID = $originid]
                    where (
                        $QUERY_PARAM("contributor") = ""
                        or $event/*:creationInfo/*:agencyID = $QUERY_PARAM("contributor")
                    )
                    return $event

        let $event := head($matches)

        return
            if (empty($event)) then
                ()
            else if (
                $QUERY_PARAM('format') = 'extended_text'
                or $QUERY_PARAM('format') = 'hypo71phs'
                or $QUERY_PARAM('format') = 'phsnll'
            ) then
                $event
            else
                qu:prune_event($event, $QUERY_PARAM)

    } catch err:* {
        ()
    }
};



(: TODO: manage version in this case, requires to ignore dbinfo where only current index is stored:)
(: TODO: verify if has been choose the right algorithm, text output now only for preferred origin and magnitude:)
(: TODO: for extended_text format it is not necessary passing by this function :)
declare function qu:query_eventid($QUERY_PARAM as map(*)) as node()* {
    let $dbinfo := 'index-' || $in:DatabaseNamePrefix
    let $_ := lo:debug(
        "qu:query_eventid, looking for event: " || $QUERY_PARAM("eventid") ||
        " in " || $dbinfo || " and contributor " || $QUERY_PARAM("contributor")
    )
    let $encoded_eventid := $QUERY_PARAM("eventid")

    let $database_index :=
        (# db:enforceindex #) {
            (
                for $text in collection($dbinfo)//*:text[
                    @eventID = $encoded_eventid
                    and string(@vend) = ''
                    and ($QUERY_PARAM("contributor") = "" or @contributor = $QUERY_PARAM("contributor"))
                    and ($QUERY_PARAM("catalog") = "" or @catalog = $QUERY_PARAM("catalog"))
                ]
                return <database name="{ string($text/../@name) }" id="{ string($text/@id) }"/>
            )[1]
        }

    return
        if (empty($database_index)) then
            ()
        else if (
            $QUERY_PARAM('format') = 'extended_text'
            or $QUERY_PARAM('format') = 'hypo71phs'
            or $QUERY_PARAM('format') = 'phsnll'
        ) then
            (# db:copynode false #) { db:get-id($database_index/@name, $database_index/@id) }
        else
            let $event := (# db:copynode false #) { db:get-id($database_index/@name, $database_index/@id) }
            return qu:prune_event($event, $QUERY_PARAM)
};


declare function qu:prune_event($event as node(), $QUERY_PARAM as map(*)) as node()* {
    let $first_pass :=
        element event {
            $event/@*,
            $event/(* except (
                if ($QUERY_PARAM("includeallorigins") = "false")
                    then *:origin[not(@publicID = $event/preferredOriginID/text())]
                    else (),
                if ($QUERY_PARAM("includeallmagnitudes") = "false")
                    then *:magnitude[not(@publicID = $event/preferredMagnitudeID/text())]
                    else (),
                if ($QUERY_PARAM("includestationmagnitudes") = "false")
                    then *:stationMagnitude
                    else (),
                if ($QUERY_PARAM("includeamplitudes") = "false")
                    then *:amplitude
                    else (),
                if ($QUERY_PARAM("includepicks") = "false")
                    then *:pick
                    else ()
            ))
        }
    let $result :=
        if ($QUERY_PARAM("includearrivals") = "false")
        then su:remove-elements($first_pass, 'arrival')
        else $first_pass
    return $result
};


declare function qu:query_eventid_asofdate($QUERY_PARAM as map(*)) as node()* {
    try {
        let $_ := lo:debug(
            "qu:query_eventid_asofdate, looking for event: " ||
            $QUERY_PARAM("eventid") ||
            " as of " || $QUERY_PARAM("asofdate") ||
            " contributor=" || $QUERY_PARAM("contributor") ||
            " catalog=" || $QUERY_PARAM("catalog")
        )

        let $asof := xs:dateTime($QUERY_PARAM("asofdate"))
        let $updatedafter := xs:dateTime($QUERY_PARAM("updatedafter"))
        let $encoded_eventid := $QUERY_PARAM("eventid")

        let $matches :=
            for $db in se:get-dbname()
            let $catalog := su:extract-catalog($db)
(:            let $_:= lo:debug("database catalog:" || $catalog || " query catalog: " || $QUERY_PARAM("catalog")):)
            for $doc in db:get($db)

            let $versions := $doc//*[local-name() = 'Version']

            return
                if (exists($versions)) then
                    for $ver in $versions[
                        xs:dateTime(@start) <= $asof
                        and (
                            if (exists(@endDate))
                            then $asof < xs:dateTime(@endDate)
                            else true()
                        )
                        and xs:dateTime(@start) >= $updatedafter
                    ]
                    let $event := $ver//*:event[
                        @publicID = $encoded_eventid
                        and ($QUERY_PARAM("contributor") = "" or *:creationInfo/*:agencyID = $QUERY_PARAM("contributor"))
                        and (if ($QUERY_PARAM('catalog')='') then true() else $QUERY_PARAM('catalog') = $catalog)
                    ]
                    return $event
                else
                    (: fallback for non-versioned docs :)
                    let $event := $doc//*:event[
                        @publicID = $encoded_eventid
                        and ($QUERY_PARAM("contributor") = "" or *:creationInfo/*:agencyID = $QUERY_PARAM("contributor"))
                        and (if ($QUERY_PARAM('catalog')='') then true() else $QUERY_PARAM('catalog') = $catalog)
                    ]
                    return $event

        let $event := head($matches)

        return
            if (empty($event)) then
                ()
            else if (
                $QUERY_PARAM('format') = 'extended_text'
                or $QUERY_PARAM('format') = 'hypo71phs'
                or $QUERY_PARAM('format') = 'phsnll'
            ) then
                $event
            else
                qu:prune_event($event, $QUERY_PARAM)

    } catch err:* {
        ()
    }
};

declare function qu:lookup_events_by_ids(
  $QUERY_PARAM as map(*),
  $eventids as xs:string*
) as map(*) {
  try {
(:    let $_ := lo:debug("qu:lookup_events_by_ids, looking for events: " || fn:string-join($eventids, ' ')):)
    let $dbinfo := 'index-' || $in:DatabaseNamePrefix

    (: Resolve each requested id to (db name, node id), preserving input order :)
    let $hits :=
(:      (# db:enforceindex #){:)
        for $eid at $pos in $eventids
        let $text :=
          (collection($dbinfo)//*:text[
             @eventID = $eid and
             ($QUERY_PARAM("contributor") = "" or @contributor = $QUERY_PARAM("contributor")) and
             ($QUERY_PARAM("catalog") = "" or @catalog = $QUERY_PARAM("catalog"))
           ])[1]
        where exists($text)
        return <hit pos="{$pos}" eventid="{$eid}"
                    db="{string($text/../@name)}"
                    id="{string($text/@id)}"/>
(:      }:)

    let $found-ids := $hits/@eventid/string()
    let $missing   := $eventids[not(. = $found-ids)]

    (: Fetch events in requested order :)
    let $events :=
      for $h in $hits
      order by xs:integer($h/@pos)
      return (# db:copynode false #){ db:get-id($h/@db, $h/@id) }

    return map {
      "events":  $events,
      "missing": $missing
    }
  } catch err:* {
    map { "events": (), "missing": $eventids }
  }
};


declare function qu:query_magnitudeid($QUERY_PARAM as map(*)) as node()*{

    let $_ := lo:debug("qu:query_magnitudeid: Looking for event with id: " || $QUERY_PARAM("magnitudeid")  )
    return
            for $event in fn:collection(se:get-dbname())
                /*:Version[@start < xs:dateTime($QUERY_PARAM("asofdate")) and ( if (exists(@endDate)) then xs:dateTime($QUERY_PARAM("asofdate")) < @endDate else true() ) and xs:dateTime(@start) > xs:dateTime($QUERY_PARAM("updatedafter"))]
                /*:quakeml/*:eventParameters/*:event/*:magnitude
                [ends-with(@publicID, $QUERY_PARAM("magnitudeid"))]
                /..
(:            let $publicID := $event/@publicID:)
(:            where  ends-with($publicID, $QUERY_PARAM("originid")):)
            return  $event
};

(:TODO move all the executor logic into event.xq:)
declare function qu:get-executor_old() as node()* {
    let $PARAM_GET := su:set_parameter_table_from_GET()
    let $_ := lo:debug("qu:get-executor" )
    let $result:=
        if  ($PARAM_GET('format')='extended_text' ) then
            (# db:copynode false #) { qu:query_extended_text($PARAM_GET) }
        else if ($PARAM_GET('format')='hypo71phs' or $PARAM_GET('format')='phsnll') then
                (# db:copynode false #) {
                qu:query_includeall($PARAM_GET)
                }
        else if ($PARAM_GET("eventid") and $PARAM_GET("asofdate-passed") ) then
          qu:query_eventid_asofdate($PARAM_GET)
        else if ($PARAM_GET("eventid")) then
          qu:query_eventid($PARAM_GET)
        else if ( $PARAM_GET("originid")  and $PARAM_GET("asofdate-passed")) then
            qu:query_originid_asofdate($PARAM_GET)
        else if ($PARAM_GET("originid")) then
            qu:query_originid($PARAM_GET)
        else if ($PARAM_GET("magnitudeid")) then
            (:TODO fix for asofdate :)
            (# db:copynode false #) {qu:query_magnitudeid($PARAM_GET)}

        (:TODO: focalmechanismid:)
        (:text is not possible with multiple origins and magnitudes  :)
        else if (($PARAM_GET('includeallorigins') = 'true' or $PARAM_GET('includeallmagnitudes') = 'true') and $PARAM_GET('format')='text' ) then fn:error(xs:QName('err:parameters'), "text format not compatible with includeall parameters")
        else if ($PARAM_GET('includeallorigins') = 'true' and $PARAM_GET('includeallmagnitudes') = 'true' and $PARAM_GET('includearrivals') = 'true' and $PARAM_GET('includestationmagnitudes') = 'true' and $PARAM_GET('includeamplitudes') = 'true'  and $PARAM_GET('includepicks') and $PARAM_GET('format')='xml' ) then
           (# db:copynode false #) {qu:query_includeall($PARAM_GET)}
        (:TODO use query_database_index only for right cases:)
        else if  ($PARAM_GET('format')='text' ) then
            (# db:copynode false #) { qu:query_database_index($PARAM_GET) }
        else (# db:copynode false #) { qu:query_prune($PARAM_GET) }
    let $_ := if (fn:empty($result))  then fn:error(xs:QName('err:nodata'), $PARAM_GET("nodata"))
    return (# db:enforceindex #) (# db:copynode false #) {$result}
};



declare function qu:get-executor() as node()* {
    let $PARAM_GET := su:set_parameter_table_from_GET()
    let $_ := lo:debug("qu:get-executor")

    let $result :=
        if ($PARAM_GET('format') = 'extended_text') then
            (# db:copynode false #) {
                qu:query_extended_text($PARAM_GET)
            }

        else if ($PARAM_GET('format') = 'hypo71phs' or $PARAM_GET('format') = 'phsnll') then
            (# db:copynode false #) {
                qu:query_includeall($PARAM_GET)
            }

        else if ($PARAM_GET("eventid") and $PARAM_GET("asofdate-passed")) then
            qu:query_eventid_asofdate($PARAM_GET)

        else if ($PARAM_GET("eventid")) then
            qu:query_eventid($PARAM_GET)

        else if ($PARAM_GET("originid") and $PARAM_GET("asofdate-passed")) then
            qu:query_originid_asofdate($PARAM_GET)

        else if ($PARAM_GET("originid")) then
            qu:query_originid($PARAM_GET)

        else if ($PARAM_GET("magnitudeid")) then
            (: TODO: fix for asofdate :)
            (# db:copynode false #) {
                qu:query_magnitudeid($PARAM_GET)
            }

        (: text is not possible with multiple origins and magnitudes :)
        else if (
            ($PARAM_GET('includeallorigins') = 'true' or $PARAM_GET('includeallmagnitudes') = 'true')
            and $PARAM_GET('format') = 'text'
        ) then
            fn:error(xs:QName('err:parameters'), "text format not compatible with includeall parameters")

        else if (
            $PARAM_GET('includeallorigins') = 'true'
            and $PARAM_GET('includeallmagnitudes') = 'true'
            and $PARAM_GET('includearrivals') = 'true'
            and $PARAM_GET('includestationmagnitudes') = 'true'
            and $PARAM_GET('includeamplitudes') = 'true'
            and $PARAM_GET('includepicks')
            and $PARAM_GET('format') = 'xml'
        ) then
            (# db:copynode false #) {
                qu:query_includeall($PARAM_GET)
            }

        (: IMPORTANT: asofdate broad queries must NOT use the current index :)
        else if ($PARAM_GET("asofdate-passed") and $PARAM_GET('format') = 'text') then
            (# db:copynode false #) {
                qu:query_extended_text($PARAM_GET)
            }

        else if ($PARAM_GET("asofdate-passed")) then
            (# db:copynode false #) {
                qu:query_prune($PARAM_GET)
            }

        (: current-only broad text query can still use index :)
        else if ($PARAM_GET('format') = 'text') then
            (# db:copynode false #) {
                qu:query_database_index($PARAM_GET)
            }

        else
            (# db:copynode false #) {
                qu:query_prune($PARAM_GET)
            }

    let $_ := if (fn:empty($result)) then fn:error(xs:QName('err:nodata'), $PARAM_GET("nodata")) else ()

    return (# db:enforceindex #) (# db:copynode false #) { $result }
};
declare function qu:get_allevents() as node()* {
    try {
        let $dbinfo := 'index-' ||  $in:DatabaseNamePrefix
        let $_ := lo:debug("qu:get_allevents, looking for all events: in " || $dbinfo  )
        let $alltext:=  collection($dbinfo)//*:text
        let $events := for $text in $alltext return db:get-id($text/../@name, $text/@id)
        return (# db:enforceindex #){$events}
    }
    catch err:* {
    ()
    }
};


declare function qu:get_events_asofdate($QUERY_PARAM as map(*)) as node()* {

  (# db:copynode false #) {
    let $_ := lo:debug("qu:get_events_asofdate()")
    let $dbnames := se:get-dbnames()
    let $asof := xs:dateTime($QUERY_PARAM("asofdate"))

    (: ---- bbox bounds (support partial bounds) ---- :)
    let $minLatS := string($QUERY_PARAM("minlatitude"))
    let $maxLatS := string($QUERY_PARAM("maxlatitude"))
    let $minLonS := string($QUERY_PARAM("minlongitude"))
    let $maxLonS := string($QUERY_PARAM("maxlongitude"))

    let $minLatOk := in:is-finite($minLatS)
    let $maxLatOk := in:is-finite($maxLatS)
    let $minLonOk := in:is-finite($minLonS)
    let $maxLonOk := in:is-finite($maxLonS)

    let $minLat := if ($minLatOk) then xs:double($minLatS) else 0
    let $maxLat := if ($maxLatOk) then xs:double($maxLatS) else 0
    let $minLon := if ($minLonOk) then xs:double($minLonS) else 0
    let $maxLon := if ($maxLonOk) then xs:double($maxLonS) else 0

    let $crosses180 := ($minLonOk and $maxLonOk and ($minLon > $maxLon))

    (: ---- depth bounds (partial safe) ---- :)
    let $minDepthS := string($QUERY_PARAM("mindepth"))
    let $maxDepthS := string($QUERY_PARAM("maxdepth"))
    let $minDepthOk := in:is-finite($minDepthS)
    let $maxDepthOk := in:is-finite($maxDepthS)
    let $minDepth := if ($minDepthOk) then xs:double($minDepthS) else -1e99
    let $maxDepth := if ($maxDepthOk) then xs:double($maxDepthS) else 1e99

    (: ---- time ---- :)
    let $startT := xs:dateTime($QUERY_PARAM("starttime"))
    let $endT   := xs:dateTime($QUERY_PARAM("endtime"))

    (: ---- radius exact check skip (global default) ---- :)
    let $maxR := xs:double($QUERY_PARAM("maxradius"))
    let $minR := xs:double($QUERY_PARAM("minradius"))
    let $useRad := ($maxR < 180.0 or $minR > 0.0)

 let $cand :=
for $dbname in se:get-dbnames()
for $version in db:get($dbname)//*:Version[
  xs:dateTime(@start) <= $asof
  and (if (exists(@endDate)) then $asof < xs:dateTime(@endDate) else true())
]

let $_ := lo:debug("dbname=" || $dbname || " matching-versions=" || count(
  db:get($dbname)//*:Version[
    xs:dateTime(@start) <= $asof
    and (if (exists(@endDate)) then $asof < xs:dateTime(@endDate) else true())
  ]
))

let $event :=
  ($version/descendant::*[local-name() = 'event']
    [(if ($QUERY_PARAM('eventtype')='') then true() else $QUERY_PARAM("eventtype") = *:type/text())]
  )[1]

let $_ := lo:debug(
  "dbname=" || $dbname ||
  " has-event=" || (if (exists($event)) then "true" else "false")
)

where exists($event)

      let $preferredOriginID := $event/*:preferredOriginID/text()
      let $preferredOrigin :=
        if ($preferredOriginID != '')
        then $event/*:origin[@publicID = $preferredOriginID][1]
        else $event/*:origin[1]

      let $_ := lo:debug(
        "dbname=" || $dbname ||
        " has-origin=" || (if (exists($preferredOrigin)) then "true" else "false")
      )

      where exists($preferredOrigin)

      let $latitude  := xs:double($preferredOrigin/*:latitude/*:value/text())
      let $longitude := xs:double($preferredOrigin/*:longitude/*:value/text())
      let $depthKm   := xs:double($preferredOrigin/*:depth/*:value/text()) div 1000.0
      let $originTime := xs:dateTime($preferredOrigin/*:time/*:value/text())
      let $contributor := string($event/*:creationInfo/*:agencyID)
      let $catalog := su:extract-catalog($dbname)
      let $preferredMagnitudeID := string($event/*:preferredMagnitudeID/text())
      let $preferredMagnitude :=
        if ($preferredMagnitudeID != '')
        then $event/*:magnitude[@publicID = $preferredMagnitudeID][1]
        else $event/*:magnitude[1]
      let $magValues :=
        for $m in
          (
            if (exists($preferredMagnitude))
            then $preferredMagnitude/*:mag/*:value/text()
            else $event/*:magnitude/*:mag/*:value/text()
          )
        let $ms := normalize-space(string($m))
        where $ms != '' and in:is-finite($ms)
        return xs:double($ms)

      let $_ := lo:debug(
        "dbname=" || $dbname ||
        " originTime=" || string($originTime) ||
        " window=[" || string($startT) || "," || string($endT) || "]"
      )

      where
        (
          if ($minLatOk and $maxLatOk)
          then ($latitude > $minLat and $latitude < $maxLat)
          else if ($minLatOk)
          then $latitude > $minLat
          else if ($maxLatOk)
          then $latitude < $maxLat
          else true()
        )
        and
        (
          if ($minLonOk and $maxLonOk)
          then
            if ($crosses180)
            then ($longitude > $minLon or $longitude < $maxLon)
            else ($longitude > $minLon and $longitude < $maxLon)
          else if ($minLonOk)
          then $longitude > $minLon
          else if ($maxLonOk)
          then $longitude < $maxLon
          else true()
        )
        and $depthKm < $maxDepth and $depthKm > $minDepth
        and $originTime > $startT and $originTime < $endT
        and (some $m in $magValues satisfies (xs:double($QUERY_PARAM("maxmag")) > $m and $m > xs:double($QUERY_PARAM("minmag"))))
        and (if ($QUERY_PARAM('contributor')='') then true() else $QUERY_PARAM('contributor') = $contributor)
        and (if ($QUERY_PARAM('catalog')='') then true() else $QUERY_PARAM('catalog') = $catalog)
        and (if (not($useRad)) then true() else su:check_radius($QUERY_PARAM, string($latitude), string($longitude)))


      return $event

    let $_ := lo:debug("cand-count=" || count($cand))
    let $hasAny := exists(subsequence($cand, 1, 1))
    let $_ := lo:debug("hasAny=" || $hasAny)

    return
      if (not($hasAny)) then
        fn:error(xs:QName('err:nodata'), $QUERY_PARAM("nodata"))
      else
        $cand
  }
};

(:A sequence of events matching the parameters, from the index:)
declare function qu:get_events($QUERY_PARAM as map(*)) as node()* {

  (# db:copynode false #) {
    let $_ := lo:debug("qu:get_events()")
    let $dbinfo := 'index-' || $in:DatabaseNamePrefix

    (: ---- bbox bounds (support partial bounds) ---- :)
    let $minLatS := string($QUERY_PARAM("minlatitude"))
    let $maxLatS := string($QUERY_PARAM("maxlatitude"))
    let $minLonS := string($QUERY_PARAM("minlongitude"))
    let $maxLonS := string($QUERY_PARAM("maxlongitude"))

    let $minLatOk := in:is-finite($minLatS)
    let $maxLatOk := in:is-finite($maxLatS)
    let $minLonOk := in:is-finite($minLonS)
    let $maxLonOk := in:is-finite($maxLonS)

    let $minLat := if ($minLatOk) then xs:double($minLatS) else 0
    let $maxLat := if ($maxLatOk) then xs:double($maxLatS) else 0
    let $minLon := if ($minLonOk) then xs:double($minLonS) else 0
    let $maxLon := if ($maxLonOk) then xs:double($maxLonS) else 0

    let $crosses180 := ($minLonOk and $maxLonOk and ($minLon > $maxLon))

    (: ---- depth bounds (partial safe) ---- :)
    let $minDepthS := string($QUERY_PARAM("mindepth"))
    let $maxDepthS := string($QUERY_PARAM("maxdepth"))
    let $minDepthOk := in:is-finite($minDepthS)
    let $maxDepthOk := in:is-finite($maxDepthS)
    let $minDepth := if ($minDepthOk) then xs:double($minDepthS) else -1e99
    let $maxDepth := if ($maxDepthOk) then xs:double($maxDepthS) else  1e99

    (: ---- time ---- :)
    let $startT := xs:dateTime($QUERY_PARAM("starttime"))
    let $endT   := xs:dateTime($QUERY_PARAM("endtime"))

    (: ---- radius exact check skip (global default) ---- :)
    let $maxR := xs:double($QUERY_PARAM("maxradius"))
    let $minR := xs:double($QUERY_PARAM("minradius"))
    let $useRad := ($maxR < 180.0 or $minR > 0.0)

    (: ---- choose cell plan (cell2, else cell1, else none) ---- :)
    let $plan := in:cell-plan($QUERY_PARAM)
    let $useCell := $plan("use")
    let $cellAttr := $plan("attr")
    let $cells := $plan("cells")
    let $_ := if ($useCell) then lo:debug("Using " || $cellAttr) else ()

    (: ---- 1) CHEAP candidate selection only ---- :)
    let $cand :=
      db:get($dbinfo)//*:text[
        (: optional cell prefilter :)
        (not($useCell)
         or (if ($cellAttr = "cell2") then @cell2 = $cells else @cell1 = $cells)
        )

        (: latitude bounds :)
        and (
          if ($minLatOk and $maxLatOk)
          then (xs:double(@latitude) > $minLat and xs:double(@latitude) < $maxLat)
          else if ($minLatOk)
          then xs:double(@latitude) > $minLat
          else if ($maxLatOk)
          then xs:double(@latitude) < $maxLat
          else true()
        )

        (: longitude bounds (antimeridian-safe when both exist) :)
        and (
          if ($minLonOk and $maxLonOk)
          then
            if ($crosses180)
            then (xs:double(@longitude) > $minLon or xs:double(@longitude) < $maxLon)
            else (xs:double(@longitude) > $minLon and xs:double(@longitude) < $maxLon)
          else if ($minLonOk)
          then xs:double(@longitude) > $minLon
          else if ($maxLonOk)
          then xs:double(@longitude) < $maxLon
          else true()
        )

        (: depth :)
        and xs:double(@depth) < $maxDepth and xs:double(@depth) > $minDepth

        (: time :)
        and xs:dateTime(@origintime) > $startT and xs:dateTime(@origintime) < $endT

        and string(@vend) = ''
      ]

    let $hasAny := exists(subsequence($cand, 1, 1))

    let $_ := lo:debug( "hasAny:" || fn:string($hasAny) )

    return
      if (not($hasAny)) then
        fn:error(xs:QName('err:nodata'), $QUERY_PARAM("nodata"))
      else
        (: ---- 2) EXPENSIVE filters + materialization ---- :)
        for $text in $cand
(:        let $_ := lo:debug( "name:" || fn:string($text/../@name) || " - id: " || fn:string($text/@id)):)
        let $latitude := $text/@latitude
        let $longitude := $text/@longitude

        let $magnitude := if (empty($text/@magnitude) or $text/@magnitude="") then $text/@pref_magnitude else $text/@magnitude
        let $id := $text/@id
        let $name := $text/../@name
        let $contributor := $text/@contributor
        let $catalog := $text/@catalog

        where
          (some $C in $magnitude satisfies
            let $c := xs:double($C)
            return (xs:double($QUERY_PARAM("maxmag")) > $c) and ($c > xs:double($QUERY_PARAM("minmag")))
          )
          and (if ($QUERY_PARAM('contributor')='') then true() else $QUERY_PARAM('contributor')=$contributor)
          and (if ($QUERY_PARAM('catalog')='') then true() else $QUERY_PARAM('catalog')=$catalog)
          and (if (not($useRad)) then true() else su:check_radius($QUERY_PARAM, $latitude, $longitude))

        return (# db:copynode false #) { db:get-id($name, $id) }
  }
};



declare function qu:query_database_index($QUERY_PARAM as map(*)) as node()* {

    let $dbinfo := 'index-' || $in:DatabaseNamePrefix
    let $useAsof := $QUERY_PARAM("asofdate-passed")
    let $asof :=
        if ($useAsof)
        then xs:dateTime($QUERY_PARAM("asofdate"))
        else ()

    let $_ := lo:debug(
        "qu:query_database_index, looking for events in " || $dbinfo ||
        " from " || $QUERY_PARAM("starttime") ||
        (if ($useAsof) then " asof " || string($asof) else " current")
    )

    let $rows :=
        if ($useAsof) then
            collection($dbinfo)//*:text
            [ (# db:enforceindex #) { @vstart <= $asof } ]
            [ (# db:enforceindex #) {
                string(@vend) = ''
                or $asof < xs:dateTime(@vend)
              } ]
        else
            collection($dbinfo)//*:text
            [ (# db:enforceindex #) { string(@vend) = '' } ]

    let $unlimited_result :=

        (# db:copynode false #) (# db:enforceindex #) {
            (
                for $text in $rows
                [ (# db:enforceindex #) {
                    if (string(@magnitude) = '')
                    then true()
                    else @magnitude < xs:double($QUERY_PARAM("maxmag")) and @magnitude > xs:double($QUERY_PARAM("minmag"))
                  } ]
                [ (# db:enforceindex #) { @origintime > xs:dateTime($QUERY_PARAM("starttime")) and @origintime < xs:dateTime($QUERY_PARAM("endtime")) } ]
                [ (# db:enforceindex #) { @latitude < xs:double($QUERY_PARAM("maxlatitude")) and @latitude > xs:double($QUERY_PARAM("minlatitude")) } ]
                [ (# db:enforceindex #) { @longitude < xs:double($QUERY_PARAM("maxlongitude")) and @longitude > xs:double($QUERY_PARAM("minlongitude")) } ]
                [ (# db:enforceindex #) { @depth < xs:double($QUERY_PARAM("maxdepth")) and @depth > xs:double($QUERY_PARAM("mindepth")) } ]
                [ (# db:enforceindex #) { if ($QUERY_PARAM('catalog')='') then true() else $QUERY_PARAM('catalog') = @catalog } ]
                [ (# db:enforceindex #) { if ($QUERY_PARAM('contributor')='') then true() else $QUERY_PARAM('contributor') = @contributor } ]
                [ (# db:enforceindex #) { if ($QUERY_PARAM('eventtype')='') then true() else @eventtype = $QUERY_PARAM('eventtype') } ]
                [ (# db:enforceindex #) {
                    if ($QUERY_PARAM("latitude") = $su:defaults("latitude") and $QUERY_PARAM("longitude") = $su:defaults("longitude"))
                    then true()
                    else su:check_radius($QUERY_PARAM, string(@latitude), string(@longitude))
                  } ]

                let $origin_time := $text/@origintime
                let $magnitude :=
                    if (string($text/@magnitude) = '')
                    then $text/@pref_magnitude
                    else $text/@magnitude

                order by
                    if ($QUERY_PARAM("orderby") = "time") then $origin_time else () descending,
                    if ($QUERY_PARAM("orderby") = "time-asc") then $origin_time else () ascending,
                    if ($QUERY_PARAM("orderby") = "magnitude") then $magnitude else () descending,
                    if ($QUERY_PARAM("orderby") = "magnitude-asc") then $magnitude else () ascending

                return (# db:copynode false #) { $text }
            )
        }

    return (# db:copynode false #) {
        if ($QUERY_PARAM("limit") = 'INF' and $QUERY_PARAM("offset") = '1')
        then $unlimited_result
        else fn:subsequence($unlimited_result, xs:double($QUERY_PARAM('offset')), xs:double($QUERY_PARAM('limit')))
    }
};

(:TODO Retire:)
(: Returns all data from the index database:)
declare function qu:query_database_index_text_all($QUERY_PARAM as map(*))  as xs:string+{

    try {
        (

        let $dbinfo := 'index-' ||  $in:DatabaseNamePrefix
        let $_ := lo:debug("qu:query_database_index_text_all, looking for events: in " || $dbinfo || "from" || $QUERY_PARAM("starttime") )
        let $unlimited_result:=

        (# db:copynode false #) (# db:enforceindex #) {
                        (
                        for $text in collection($dbinfo)//*:text
                        let $latitude:=$text/@latitude
                        let $longitude:=$text/@longitude
                        let $depth:=$text/@depth
                        let $origin_time:=$text/@origintime
                        let $eventtype:=$text/@eventtype
                        let $eventID:=$text/@eventID
                        let $originID:=$text/@originID
                        let $version:=$text/@version
                        let $fixed_depth:=$text/@fixed_depth
                        let $origin_Q:=$text/@origin_Q
                        let $rms:=$text/@rms
                        let $gap:=$text/@gap

                        let $nph_tot:=$text/@nph_tot
                        let $nph_tot_used:=$text/@nph_tot_used
                        let $nph_p_used:=$text/@nph_p_used
                        let $nph_s_used:=$text/@nph_s_used
                        let $min_dist_km:=$text/@min_dist_km
                        let $max_dist_km:=$text/@max_dist_km
                        let $err_ot:=$text/@err_ot
                        let $err_lon_km:=$text/@err_lon_km
                        let $err_lat_km:=$text/@err_lat_km
                        let $err_depth_km:=$text/@err_depth_km
                        let $err_h_km:=$text/@err_h_km
                        let $err_z_km:=$text/@err_z_km
                        let $confidence_level:=$text/@confidence_level
                        let $magnitude_id:=$text/@magnitude_id
                        let $magnitude_type:=$text/@magnitude_type
                        let $magnitude:=$text/@magnitude
                        let $magnitude_Q:=$text/@magnitude_Q
                        let $magnitude_err:=$text/@magnitude_err
                        let $magnitude_ncha_used:=$text/@magnitude_ncha_used

                        let $pref_magnitude_id:=$text/@pref_magnitude_id
                        let $pref_magnitude_type:=$text/@pref_magnitude_type
                        let $pref_magnitude:=$text/@pref_magnitude
                        let $pref_magnitude_Q:=$text/@pref_magnitude_Q
                        let $pref_magnitude_err:=$text/@pref_magnitude_err
                        let $pref_magnitude_ncha_used:=$text/@pref_magnitude_ncha_used

                        let $source:=$text/@source

                        where   (if ($QUERY_PARAM('eventtype')='') then true() else $QUERY_PARAM("eventtype")=type/text())
                        order by
                            (: default is descending but it should be like document order in index database          :)
                            if ($QUERY_PARAM("orderby")="time") then $origin_time  else () descending,
                            if ($QUERY_PARAM("orderby")="time-asc") then $origin_time else () ascending,
(:                            if ($QUERY_PARAM("orderby")="magnitude") then $mag_to_check_values else ()  descending,:)
(:                            if ($QUERY_PARAM("orderby")="magnitude-asc") then $mag_to_check_values else ()  ascending:)
                            if ($QUERY_PARAM("orderby")="magnitude") then $magnitude else ()  descending,
                            if ($QUERY_PARAM("orderby")="magnitude-asc") then $magnitude else ()  ascending
                            return (# db:copynode false #)  (# db:enforceindex #){
                                      '&#xA;'
                                      ||substring-after($eventID,'=')||'|'||$eventtype||'|'||substring-after($originID,'=')||'|'||$version
                                      ||'|'||$origin_time||'|'||$longitude||'|'||$latitude||'|'||$depth div 1000||'|'||$fixed_depth
                                      ||'|'||$origin_Q||'|'||$rms||'|'||$gap
                                      ||'|'||$nph_tot||'|'||$nph_tot_used||'|'||$nph_p_used||'|'||$nph_s_used
                                      ||'|'||$min_dist_km||'|'||$max_dist_km
                                      ||'|'||$err_ot||'|'||$err_lon_km||'|'||$err_lat_km||'|'||$err_depth_km||'|'||$err_h_km||'|'||$err_z_km
                                      ||'|'||$confidence_level
                                      ||'|'||substring-after($magnitude_id,'=')||'|'||$magnitude_type||'|'||$magnitude||'|'||$magnitude_Q
                                      ||'|'||$magnitude_err||'|'||$magnitude_ncha_used
                                      ||'|'||substring-after($pref_magnitude_id, '=')||'|'||$pref_magnitude_type||'|'||$pref_magnitude||'|'||$pref_magnitude_Q
                                      ||'|'||$pref_magnitude_err||'|'||$pref_magnitude_ncha_used
                                      ||'|'||$source
                                      }
                                    )
                            }
          return   (# db:copynode false #) {
                   if ($QUERY_PARAM("limit")!='INF' and $QUERY_PARAM("offset")!='1' )
                    then $unlimited_result
                    else fn:subsequence($unlimited_result,xs:double($QUERY_PARAM('offset')), xs:double($QUERY_PARAM('limit')))
                   }
        )
    }
    catch err:* {
    ()
    }


};

(:Looks directly in index database. Does not use Version:)
declare function qu:query_database_index_text_selection($QUERY_PARAM as map(*)) as xs:string+ {

    let $dbinfo := 'index-' || $in:DatabaseNamePrefix
    let $useAsof := $QUERY_PARAM("asofdate-passed")
    let $asof :=
        if ($useAsof)
        then xs:dateTime($QUERY_PARAM("asofdate"))
        else ()

    let $_ := lo:debug(
        "qu:query_database_index_text_selection, looking for events in " || $dbinfo ||
        " from " || $QUERY_PARAM("starttime") ||
        (if ($useAsof) then " asof " || string($asof) else " current")
    )

    let $rows :=
        if ($useAsof) then
            collection($dbinfo)//*:text
            [ (# db:enforceindex #) { @vstart <= $asof } ]
            [ (# db:enforceindex #) {
                string(@vend) = ''
                or $asof < xs:dateTime(@vend)
              } ]
        else
            collection($dbinfo)//*:text
            [ (# db:enforceindex #) { string(@vend) = '' } ]

    let $unlimited_result :=
        (# db:copynode false #) (# db:enforceindex #) {
            (
                for $text in $rows
                [ (# db:enforceindex #) { @origintime > xs:dateTime($QUERY_PARAM("starttime")) and @origintime < xs:dateTime($QUERY_PARAM("endtime")) } ]
                [ (# db:enforceindex #) { @latitude < xs:double($QUERY_PARAM("maxlatitude")) and @latitude > xs:double($QUERY_PARAM("minlatitude")) } ]
                [ (# db:enforceindex #) { @longitude < xs:double($QUERY_PARAM("maxlongitude")) and @longitude > xs:double($QUERY_PARAM("minlongitude")) } ]
                [ (# db:enforceindex #) { @depth < xs:double($QUERY_PARAM("maxdepth")) and @depth > xs:double($QUERY_PARAM("mindepth")) } ]
                [ (# db:enforceindex #) { if ($QUERY_PARAM('catalog')='') then true() else $QUERY_PARAM('catalog') = @catalog } ]
                [ (# db:enforceindex #) { if ($QUERY_PARAM('contributor')='') then true() else $QUERY_PARAM('contributor') = @contributor } ]
                [ (# db:enforceindex #) { if ($QUERY_PARAM('eventtype')='') then true() else $QUERY_PARAM('eventtype') = @eventtype } ]
                [ (# db:enforceindex #) {
                    if ($QUERY_PARAM("latitude") = $su:defaults("latitude") and $QUERY_PARAM("longitude") = $su:defaults("longitude"))
                    then true()
                    else su:check_radius($QUERY_PARAM, string(@latitude), string(@longitude))
                } ]

                let $latitude_s := string($text/@latitude)
                let $longitude_s := string($text/@longitude)

                let $latitude := xs:double($latitude_s)
                let $longitude := xs:double($longitude_s)
                let $depth := xs:double($text/@depth)
                let $origin_time := $text/@origintime

                let $magnitude_attr := string($text/@magnitude)
                let $magnitude_pref := string($text/@pref_magnitude)

                let $mag_to_check_values :=
                    (
                        if ($magnitude_attr = "") then xs:double($magnitude_pref) else xs:double($magnitude_attr),
                        xs:double($magnitude_pref)
                    )

                let $contributor := string($text/@contributor)
                let $catalog := string($text/@catalog)
                let $eventtype := string($text/@eventtype)
                let $eventID := string($text/@eventID)
                let $originID := string($text/@originID)
                let $version := string($text/@version)
                let $fixed_depth := string($text/@fixed_depth)
                let $origin_Q := string($text/@origin_Q)
                let $rms := string($text/@rms)
                let $gap := string($text/@gap)

                let $nph_tot := string($text/@nph_tot)
                let $nph_tot_used := string($text/@nph_tot_used)
                let $nph_p_used := string($text/@nph_p_used)
                let $nph_s_used := string($text/@nph_s_used)
                let $min_dist_km := string($text/@min_dist_km)
                let $max_dist_km := string($text/@max_dist_km)
                let $err_ot := string($text/@err_ot)
                let $err_lon_km := string($text/@err_lon_km)
                let $err_lat_km := string($text/@err_lat_km)
                let $err_depth_km := string($text/@err_depth_km)
                let $err_h_km := string($text/@err_h_km)
                let $err_z_km := string($text/@err_z_km)
                let $confidence_level := string($text/@confidence_level)

                let $magnitude_id := string($text/@magnitude_id)
                let $magnitude_type := string($text/@magnitude_type)
                let $magnitude :=
                    if ($magnitude_attr = "")
                    then xs:double($magnitude_pref)
                    else xs:double($magnitude_attr)
                let $magnitude_Q := string($text/@magnitude_Q)
                let $magnitude_err := string($text/@magnitude_err)
                let $magnitude_ncha_used := string($text/@magnitude_ncha_used)

                let $pref_magnitude_id := string($text/@pref_magnitude_id)
                let $pref_magnitude_type := string($text/@pref_magnitude_type)
                let $pref_magnitude := string($text/@pref_magnitude)
                let $pref_magnitude_Q := string($text/@pref_magnitude_Q)
                let $pref_magnitude_err := string($text/@pref_magnitude_err)
                let $pref_magnitude_ncha_used := string($text/@pref_magnitude_ncha_used)

                let $source := string($text/@source)

                where
                    (if ($QUERY_PARAM('eventtype')='') then true() else $eventtype = $QUERY_PARAM('eventtype'))
                    and
                    (some $C in $mag_to_check_values satisfies
                        (xs:double($QUERY_PARAM("maxmag")) > $C) and ($C > xs:double($QUERY_PARAM("minmag")))
                    )
                    and
                    (if ($QUERY_PARAM('contributor')='') then true() else $QUERY_PARAM('contributor') = $contributor)
                    and
                    (if ($QUERY_PARAM('catalog')='') then true() else $QUERY_PARAM('catalog') = $catalog)
                    and
                    su:check_radius($QUERY_PARAM, $latitude_s, $longitude_s)

                order by
                    if ($QUERY_PARAM("orderby")="time") then $origin_time else () descending,
                    if ($QUERY_PARAM("orderby")="time-asc") then $origin_time else () ascending,
                    if ($QUERY_PARAM("orderby")="magnitude") then $magnitude else () descending,
                    if ($QUERY_PARAM("orderby")="magnitude-asc") then $magnitude else () ascending

                return (# db:copynode false #) (# db:enforceindex #) {
                    '&#xA;'
                    || substring-after($eventID,'=')
                    || '|' || $eventtype
                    || '|' || substring-after($originID,'=')
                    || '|' || $version
                    || '|' || $origin_time
                    || '|' || $longitude
                    || '|' || $latitude
                    || '|' || $depth div 1000
                    || '|' || $fixed_depth
                    || '|' || $origin_Q
                    || '|' || $rms
                    || '|' || $gap
                    || '|' || $nph_tot
                    || '|' || $nph_tot_used
                    || '|' || $nph_p_used
                    || '|' || $nph_s_used
                    || '|' || $min_dist_km
                    || '|' || $max_dist_km
                    || '|' || $err_ot
                    || '|' || $err_lon_km
                    || '|' || $err_lat_km
                    || '|' || $err_depth_km
                    || '|' || $err_h_km
                    || '|' || $err_z_km
                    || '|' || $confidence_level
                    || '|' || substring-after($magnitude_id,'=')
                    || '|' || $magnitude_type
                    || '|' || $magnitude
                    || '|' || $magnitude_Q
                    || '|' || $magnitude_err
                    || '|' || $magnitude_ncha_used
                    || '|' || substring-after($pref_magnitude_id,'=')
                    || '|' || $pref_magnitude_type
                    || '|' || $pref_magnitude
                    || '|' || $pref_magnitude_Q
                    || '|' || $pref_magnitude_err
                    || '|' || $pref_magnitude_ncha_used
                    || '|' || $source
                }
            )
        }

    return (# db:copynode false #) {
        if ($QUERY_PARAM("limit")='INF' and $QUERY_PARAM("offset")='1')
        then $unlimited_result
        else fn:subsequence($unlimited_result, xs:double($QUERY_PARAM('offset')), xs:double($QUERY_PARAM('limit')))
    }
};



(: Here we must always choose the preferred magnitude :)
declare function qu:query_database_index_text($QUERY_PARAM as map(*)) {
(:    try {:)
        let $dbinfo := 'index-' || $in:DatabaseNamePrefix
        let $asof :=
            if ($QUERY_PARAM("asofdate-passed"))
            then xs:dateTime($QUERY_PARAM("asofdate"))
            else current-dateTime()

        let $_ := lo:debug(
            "qu:query_database_index_text, looking for events in " || $dbinfo ||
            " from " || $QUERY_PARAM("starttime") ||
            " asof " || string($asof)
        )

        let $unlimited_result :=
            (# db:copynode false #) (# db:enforceindex #) {
                (
                    for $text in collection($dbinfo)//*:text
                    [
                      (# db:enforceindex #) {
                        if ($QUERY_PARAM("asofdate-passed")) then
                          xs:dateTime(@vstart) <= xs:dateTime($QUERY_PARAM("asofdate"))
                          and (
                            string(@vend) = ''
                            or xs:dateTime($QUERY_PARAM("asofdate")) < xs:dateTime(@vend)
                          )
                        else
                          string(@vend) = ''
                      }
                    ]
                    [ (# db:enforceindex #) { @pref_magnitude < xs:double($QUERY_PARAM("maxmag")) and @pref_magnitude > xs:double($QUERY_PARAM("minmag")) }]
                    [ (# db:enforceindex #) { @origintime > xs:dateTime($QUERY_PARAM("starttime")) and @origintime < xs:dateTime($QUERY_PARAM("endtime")) }]
                    [ (# db:enforceindex #) { @latitude < xs:double($QUERY_PARAM("maxlatitude")) and @latitude > xs:double($QUERY_PARAM("minlatitude")) }]
                    [ (# db:enforceindex #) { @longitude < xs:double($QUERY_PARAM("maxlongitude")) and @longitude > xs:double($QUERY_PARAM("minlongitude")) }]
                    [ (# db:enforceindex #) { @depth < xs:double($QUERY_PARAM("maxdepth")) and @depth > xs:double($QUERY_PARAM("mindepth")) }]

let $latitude_s := string($text/@latitude)
let $longitude_s := string($text/@longitude)

let $latitude := xs:double($latitude_s)
let $longitude := xs:double($longitude_s)
let $depth := xs:double($text/@depth)
let $origin_time := $text/@origintime
let $mag_to_check_values := xs:double($text/@pref_magnitude)
let $contributor := string($text/@contributor)
let $catalog := string($text/@catalog)
let $eventtype := string($text/@eventtype)
let $eventID := string($text/@eventID)
let $author := string($text/@author)
let $contributorID := string($text/@contributorID)
let $pref_magnitude_type := string($text/@pref_magnitude_type)
let $pref_magnitude_author := string($text/@pref_magnitude_author)
let $eventlocationname := string($text/@eventlocationname)

where
    $latitude < xs:double($QUERY_PARAM("maxlatitude")) and $latitude > xs:double($QUERY_PARAM("minlatitude"))
    and
    $longitude < xs:double($QUERY_PARAM("maxlongitude")) and $longitude > xs:double($QUERY_PARAM("minlongitude"))
    and
    $depth < xs:double($QUERY_PARAM("maxdepth")) and $depth > xs:double($QUERY_PARAM("mindepth"))
    and
    $mag_to_check_values < xs:double($QUERY_PARAM("maxmag")) and $mag_to_check_values > xs:double($QUERY_PARAM("minmag"))
    and
    $origin_time > xs:dateTime($QUERY_PARAM("starttime")) and $origin_time < xs:dateTime($QUERY_PARAM("endtime"))
    and
    (if ($QUERY_PARAM('contributor') = '') then true() else $QUERY_PARAM('contributor') = $contributor)
    and
    (if ($QUERY_PARAM('catalog') = '') then true() else $QUERY_PARAM('catalog') = $catalog)
    and
    (if ($QUERY_PARAM('eventtype') = '') then true() else $eventtype = $QUERY_PARAM('eventtype'))
    and
    su:check_radius($QUERY_PARAM, $latitude_s, $longitude_s)

                    order by
                        if ($QUERY_PARAM("orderby") = "time") then $origin_time else () descending,
                        if ($QUERY_PARAM("orderby") = "time-asc") then $origin_time else () ascending,
                        if ($QUERY_PARAM("orderby") = "magnitude") then $mag_to_check_values else () descending,
                        if ($QUERY_PARAM("orderby") = "magnitude-asc") then $mag_to_check_values else () ascending

                    return (# db:copynode false #) {
                        '&#xA;'
                        || $eventID
                        || '|' || $origin_time
                        || '|' || $latitude
                        || '|' || $longitude
                        || '|' || $depth div 1000
                        || '|' || $author
                        || '|' || $catalog
                        || '|' || $contributor
                        || '|' || $contributorID
                        || '|' || $pref_magnitude_type
                        || '|' || $mag_to_check_values
                        || '|' || $pref_magnitude_author
                        || '|' || $eventlocationname
                        || '|' || $eventtype
                    }
                )
            }

        return (# db:copynode false #) {
            if ($QUERY_PARAM("limit") = 'INF' and $QUERY_PARAM("offset") = '1')
            then $unlimited_result
            else fn:subsequence($unlimited_result, xs:double($QUERY_PARAM('offset')), xs:double($QUERY_PARAM('limit')))
        }
(:    }:)
(:    catch err:* {:)
(:        ():)
(:    }:)
};

declare function qu:preview-version() as map(*) {
  in:db-timestamp()
};



declare function qu:preview-year($year as xs:string) as array(*) {

  let $db := 'index-' || $in:DatabaseNamePrefix
  let $_ := lo:debug("qu:preview-year(" || $year  ||" in " ||$db )
  let $y :=
    if (matches($year, '^\d{4}$')) then $year
    else error(xs:QName('err:badrequest'), 'Invalid year')

  let $epoch0 := xs:dateTime("1970-01-01T00:00:00")

  return array {
    for $t in db:get($db)//*:text
    let $origintimeAttr := $t/@origintime
    let $latitudeAttr := $t/@latitude
    let $longitudeAttr := $t/@longitude
    let $idAttr := $t/@id
    let $magnitudeAttr := $t/@magnitude
    let $prefMagnitudeAttr := $t/@pref_magnitude
    let $depthAttr := $t/@depth

    let $origintimeStr := $origintimeAttr
    let $latitudeStr := $latitudeAttr
    let $longitudeStr :=$longitudeAttr
    let $depthStr := $depthAttr
    let $idStr := $idAttr
    let $magnitudeStr := $magnitudeAttr
    let $prefMagnitudeStr :=$prefMagnitudeAttr

    where $origintimeAttr
      and substring($origintimeStr, 1, 4) = $y
      and $latitudeAttr  and $latitudeStr  != ''
      and $longitudeAttr and $longitudeStr != ''
      and $idAttr        and $idStr        != ''
      and $depthStr != ''


    let $id  :=
      try { xs:integer($idStr) } catch * { () }

    let $lat :=
      try { xs:double($latitudeStr) } catch * { () }

    let $lon :=
      try { xs:double($longitudeStr) } catch * { () }

    let $depth :=
          if ($depthStr != '') then
            try { round-half-to-even(xs:double($depthStr) div 1000, 2) } catch * { 0 }
          else 0

    where exists($id) and exists($lat) and exists($lon)

    (: epoch seconds (best-effort) :)
    let $ot :=
      try { xs:dateTime($origintimeStr) } catch * { () }

    let $epoch :=
      if (exists($ot))
      then xs:integer( ($ot - $epoch0) div xs:dayTimeDuration("PT1S") )
      else ()   (: oppure 0, se preferisci :)

    (: magnitude: prefer @pref_magnitude; round to 2 decimals as NUMBER :)
    let $magRaw :=
      if ($prefMagnitudeAttr and normalize-space($prefMagnitudeStr) != '')
      then $prefMagnitudeAttr
      else if ($magnitudeAttr and normalize-space($magnitudeStr) != '')
           then $magnitudeStr
           else ''

    let $mag :=
      if ($magRaw != '') then
        try { round-half-to-even(xs:double($magRaw), 2) } catch * { () }
      else ()

    return
      if (exists($mag) and exists($epoch) and exists($depth)  ) then [$id, $lat, $lon, $epoch, $mag, $depth]
      else ()
  }
};
