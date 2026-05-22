(:~
 : Util module, utilities and definitions.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace su='http://webservices.ingv.it/fdsnws/event/modules/util';
import module namespace ver='http://webservices.ingv.it/fdsnws/event/modules/version' at 'version.xqm';
import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settings.xqm';
import module namespace ib='http://webservices.ingv.it/fdsnws/event/modules/ingv_bulletin' at 'ingv_bulletin.xqm';
import module namespace lo='http://webservices.ingv.it/fdsnws/utils/log' at '../../utils/log.xqm';
import module namespace functx = 'http://www.functx.com';
import module namespace map='http://www.w3.org/2005/xpath-functions/map';

(: import module namespace co='http://webservices.ingv.it/fdsnws/utils/commons'at '../../utils/commons.xqm'; :)

declare default element namespace 'http://quakeml.org/xmlns/quakeml/1.2';
declare namespace q = "http://quakeml.org/xmlns/quakeml/1.2";


declare copy-namespaces no-preserve, inherit;

(:limit 0 = no limit:)
declare %public variable $su:defaults :=map {
    "nodata"             : "204",
    "latitude"           : "0",
    "longitude"          : "0",
    "lat"           : "0",
    "lon"           : "0",
    "minradius"          : "0",
    "maxradius"          : "180",
    "minradiuskm"        : "0",
    "maxradiuskm"        : "20037.5",
    "format"             : "xml",
    "minlatitude"        : '-INF',
    "maxlatitude"        : 'INF',
    "minlongitude"       : '-INF',
    "maxlongitude"       :  'INF',
    "mindepth"           :  '-INF',
    "maxdepth"           :  'INF',
    "minmagnitude"       :  '-INF',
    "minmag"             :  '-INF',
    "maxmagnitude"       :  'INF',
    "maxmag"             :  'INF',
    "magnitudetype"      :  "",
    "eventtype"          :  "",
    "includeallorigins"  :  "false",
    "includeallmagnitudes" : "false",
    "includearrivals"    : "false",
    "includestationmagnitudes"    : "false",
    "includeamplitudes"  : "false",
    "includepicks"       : "false",
    "includeall"         : "false",
    "eventid"            : "",
    "originid"           : "",
    "magnitudeid"        : "",
    "focalmechanismid"   : "",
    "limit"              : 'INF',
    "offset"             : "1",
    "orderby"            : "time",
    "catalog"            : "",
    "contributor"        : "",
    "starttime"          : "0001-01-01T00:00:00",
    "endtime"            : "10001-01-01T00:00:00",
    "start"          : "0001-01-01T00:00:00",
    "end"            : "10001-01-01T00:00:00",
    "updatedafter"       : "0001-01-01T00:00:00",
    "asofdate"             : "10001-01-01T00:00:00"
};



declare % public variable $su:incompatible_params := map {
    "start": "starttime",
    "end" : "endtime",
    "minlat" : "minlatitude",
    "maxlat" : "maxlatitude",
    "minlon" : "minlongitude",
    "maxlon" : "maxlongitude",
    "lat" : "latitude",
    "lon" : "longitude",
    "minradius" : "minradiuskm",
    "maxradius" : "maxradiuskm",
    "minmagnitude" : "minmag",
    "maxmagnitude" : "maxmag"

};

declare % public variable $su:exclusive_params := map {
    "eventid" : ("originid","magnitudeid","focalmechanismid","start","starttime","end","endtime","minlat","minlatitude","maxlat","maxlatitude","minlon","minlongitude","maxlon","maxlongitude","lat","latitude","lon","longitude","minradius","minradiuskm","maxradius","maxradiuskm","minmagnitude","minmag","maxmagnitude","maxmag"),
    "originid" : ("eventid","magnitudeid","focalmechanismid","start","starttime","end","endtime","minlat","minlatitude","maxlat","maxlatitude","minlon","minlongitude","maxlon","maxlongitude","lat","latitude","lon","longitude","minradius","minradiuskm","maxradius","maxradiuskm","minmagnitude","minmag","maxmagnitude","maxmag"),
    "magnitudeid" : ("originid","eventid","focalmechanismid","start","starttime","end","endtime","minlat","minlatitude","maxlat","maxlatitude","minlon","minlongitude","maxlon","maxlongitude","lat","latitude","lon","longitude","minradius","minradiuskm","maxradius","maxradiuskm","minmagnitude","minmag","maxmagnitude","maxmag"),
    "focalmechanismid" : ("originid","magnitudeid","eventid","start","starttime","end","endtime","minlat","minlatitude","maxlat","maxlatitude","minlon","minlongitude","maxlon","maxlongitude","lat","latitude","lon","longitude","minradius","minradiuskm","maxradius","maxradiuskm","minmagnitude","minmag","maxmagnitude","maxmag"),
    "updatedafter" : ("asofdate")
};

(:
Extract presumable publicID part from the ResourceReference
(smi|quakeml):[\w\d][\w\d\-\.\*\(\)_~']{2,}/[\w\d\-\.\*\(\)_~']
[\w\d\-\.\*\(\)\+\?_~'=,;#/&]*

eventID
IPGP: smi:org.gfz-potsdam.de/geofon/ovsg2023nmisqn
authority_id: org.gfz-potsdam.de

ETHZ: smi:ch.ethz.sed/event/ecos09/GROUP_PEGASOS/1117.00000

INGV: smi:webservices.ingv.it/fdsnws/event/1/query?eventId=41983202
authority_id: webservices.ingv.it

:)

declare function su:get_publicID($ResourceReference as xs:string*) as xs:string* {
switch (se:get-publicID_format())
case 'standard'
    return $ResourceReference
case 'ingv'
    return $ResourceReference
default
    return $ResourceReference
};

declare function su:setputdata($body) as xs:string* {

    let $content-type := request:header("Content-Type")
    let $ret :=
(:        if ($content-type = "application/x-www-form-urlencoded") then:)
(:            :)(: application/x-www-form-urlencoded in ObsPy Client try to catch:)
(:            :)(:TODO code and test for Obspy Client:)
(:            let $parameters := request:parameter-names():)
(:            let $l := for $p in $parameters return util:log("info", $p || "--" || request:get-parameter($p, "None")):)
(:            let $ret := "level=" || request:parameter("level", "None"):)
(:            let $log := log("info: Received" || $ret):)
(:            return $ret:)
(:        :)(:   Works with pytest requests    :)
(:        else :)
        if ($content-type = "application/octet-stream") then
            bin:decode-string($body)
        else
            (:Works when no header is set:
             i.e when removed specifying in location section of default.conf
             nginx proxy_set_header       Content-Type "";:)
            $body
    (: let $l:=(for $i in $ret return util:log("info", $i)) :)

(:" || string-join($ret)) else ():)
    return $ret
};


(:~
 :  Adjust datetime strings to fdsn standard format YYYY-MM-DDThh:mm:ss.d if possible
 :)
declare function su:time_adjust( $mydatetime as xs:string ) as xs:string {
    try {
        let $interpreted_datetime :=
        if ((matches($mydatetime,"..-..-..T..:..:..*"))) then
        $mydatetime
        else
            if (matches($mydatetime,"..-..-..")) then
                $mydatetime||"T"||"00:00:00.0"
            else
            fn:error(xs:QName('err:parameters'), "Wrong dateTime format")
        let $tentative := xs:dateTime($interpreted_datetime)
        return $interpreted_datetime
    }
    catch * {
        fn:error(xs:QName('err:parameters'), 'Wrong datetime format')
    }

};

(:~ Throws an exception when parameters are out of bounds
 : :)
declare function su:check_param_errors($parameters as map(*)) as item()+  {
try {
let $_ := lo:debug('check_param_errors()')

return
(su:is_mapped($parameters,'nodata',('204','404'))),
(su:is_bounded($parameters,'latitude',-90.0,90.0)), (su:is_bounded($parameters,'minlatitude',-90.0,90.0)), (su:is_bounded($parameters,'maxlatitude',-90.0,90.0)),
(su:is_bounded($parameters,'longitude', -180.0, 180.0)), (su:is_bounded($parameters,'minlongitude', -180.0, 180.0)), (su:is_bounded($parameters,'maxlongitude', -180.0, 180.0)),
(su:is_bounded($parameters,'minradius', 0.0, 180.0)), (su:is_bounded($parameters,'maxradius', 0.0, 180.0)),
(su:is_bounded($parameters,'minradiuskm', 0.0, 20037.5)), (su:is_bounded($parameters,'maxradiuskm', 0.0, 20037.5)),
(su:is_bounded($parameters,'mindepth', -10000.0, 6731000.0)), (su:is_bounded($parameters,'maxdepth', -10000.0, 6731000.0)),
(su:is_bounded($parameters,'minmagnitude', -100.0, 100.0)), (su:is_bounded($parameters,'maxmagnitude', -100.0, 100.0)),
(su:is_mapped($parameters,'format',('text','xml','extended_text','hypo71phs','phsnll'))),(su:is_mapped($parameters,'includeallorigins',('true','false'))),
(su:is_mapped($parameters,'includeallmagnitudes',('true','false'))),(su:is_mapped($parameters,'includearrivals',('true','false'))),
(su:is_mapped($parameters,'includestationmagnitudes',('true','false'))),(su:is_mapped($parameters,'includeamplitudes',('true','false'))),
(su:is_mapped($parameters,'includepicks',('true','false'))),(su:is_mapped($parameters,'includeall',('true','false'))),
(su:is_mapped($parameters,'orderby',('time','time-asc','magnitude','magnitude-asc'))),
(su:is_bounded($parameters,'limit', 1, xs:double('INF'))),
(su:is_bounded($parameters,'offset', 1, xs:double('INF')))


}
catch  err:parameters {
  fn:error(xs:QName('err:parameters'), $err:description)
}
catch  * {
  fn:error(xs:QName('err:parameters'), 'Unexpected error parsing parameters')
}

};


declare function su:is_mapped($parameters as map(*), $key as xs:string, $sequence as xs:anyAtomicType*) as empty-sequence(){
if (not (functx:is-value-in-sequence($parameters($key) , $sequence ))) then fn:error(xs:QName('err:parameters'), 'parameter not in domain [' || fn:string-join($sequence,',') || ']: ' ||  $key  ||'='||$parameters($key))
};

declare function su:is_bounded($parameters as map(*) , $key as xs:string, $min as xs:double, $max as xs:double) as xs:boolean{
(:let $log := lo:debug("is_bounded() " ||  $parameters($key) || " " || $min || " " || $max ) return:)
if (xs:double($parameters($key)) = xs:double('INF') or xs:double($parameters($key)) = xs:double('-INF') )
then true()
else
    if (xs:double($parameters($key)) < xs:double($min) or xs:double($parameters($key)) > xs:double($max) ) then fn:error(xs:QName('err:parameters'), 'parameter not in domain [' || $min || ',' || $max || ']: ' ||  $key ||'='||$parameters($key) ) else true()
};


declare function su:sanitize ($input as xs:string) as xs:string
{
  let $output:=translate( $input, "|", "-")
  return $output
};

(:~ Throws an exception when bogus alias or params multiplicity is detected in GET requests
 : :)
declare function su:check_param_abuse() as empty-sequence(){
    let $param_names := request:parameter-names()
    let $_ := lo:debug("check_param_abuse" || fn:string-join($param_names))
    let $_ :=
            for $name in $param_names
                let $_ := lo:debug("checking parameter: " || $name || "=" || request:parameter($name, ""))
                let $alias := map:get($su:incompatible_params, $name)
                (: error if current parameter alias is found in param_names :)
                let $countbogus:= if (empty($alias) or empty(index-of($param_names, $alias))) then () else fn:error(xs:QName('err:parameters'), 'Check ' || $alias || ' and ' || $name || ' parameter' )
                let $param := request:parameter($name, "")

                (: error if parameter multiplicity :)
                let $_ := if (count($param)>1) then fn:error(xs:QName('err:parameters'), 'Multiplicity in parameter ' || $name ) else ()
                let $_ := if ($param='') then fn:error(xs:QName('err:parameters'), 'Check ' || $name || " parameter, found ''" ) else ()
                let $_ := if (matches($name,"^minlatitude$|^minlat$|^maxlatitude$|^maxlat$|^minlongitude$|^minlon$|^maxlongitude$|^maxlon$|^minmagnitude$|^minmag$|^maxmagnitude$|^maxmag$|^starttime$|^start$|^endtime$|^end$|^updatedafter$|^latitude$|^lat$|^longitude$|^lon$|^maxradius$|^minradius$|^maxradiuskm$|^minradiuskm$|^maxdepth$|^mindepth$|^magnitudetype$|^eventtype$|^includeallorigins$|^includeallmagnitudes$|^includearrivals$|^includestationmagnitudes$|^includeamplitudes$|^includepicks$|^includeall$|^eventid$|^limit$|^offset$|^orderby$|^catalog$|^contributor$|^nodata$|^format$|^asofdate$|^originid$|^magnitudeid$|^focalmechanismid$"
                                            )) then ()
                                else fn:error(xs:QName('err:parameters'), 'Unknown parameter ' || $name )

            return $countbogus
    return ()
};

declare function su:check_param_incompatibility() as empty-sequence() {
    let $param_names := request:parameter-names()
    let $_ :=
            for $name in $param_names
(:                let $log:=lo:log("Error: reading: " || $name ):)
                let $incompatible := map:get($su:exclusive_params,$name)
(:                let $try := if ($param_names=$incompatible) then lo:log("Error: reading: " || $name || fn:string-join($incompatible,' ')) else ():)
                let $_ := if ($param_names=$incompatible) then fn:error(xs:QName('err:parameters'), 'Check ' || $name || " compatibility with other parameters" ) else ()
            return $name
    return ()
};

(:~ @return true if all reducing output parameters are still defaults
:)
declare function su:check_param_use($map as item()* ) as xs:boolean {
    let $params_to_exclude:=('nodata','format','eventtype','asofdate','asofdate-passed','post_size_correct',
                            'focalmechanismid','minlat','maxlat','maxradiuskm','minradiuskm','minlon','maxlon','updatedafter',
                            'starttime','start','endtime','end','limit')
    (: let $param_names := request:parameter-names() :)
    let $map_cleaned := map:remove($map,$params_to_exclude)
    let $default_cleaned := map:remove($su:defaults,$params_to_exclude)
    let $equal:=fn:deep-equal($default_cleaned,$map_cleaned)

(:    let $result:=fn:deep-equal($map_cleaned,$default_cleaned):)

(:    let $D:= sum:)
(:            (for $key in map:keys($default_cleaned):)
(:                        let $C:= map:get($default_cleaned,$key):)
(:                        let $M:= map:get($map_cleaned,$key):)
(:        let $log:=if ($C!=$M) then lo:log($key ||" C:  " || $C || " M: " || $M):)
(:                        return if ($C=$M) then 0 else 1):)
(:    let $log:=lo:log("Somma:  " || $D):)
    return $equal
};

(:~ Map the GET request params in su:parameters_table  :)
declare function su:set_parameter_table_from_GET() as map(*) {

try {
let $_:= lo:debug("set_parameter_table_from_GET:" || "Assigning parameters " )

(:check against parameters abuse:)
(: let $start:=current-dateTime() :)

let $_ := su:check_param_abuse()
let $_ := su:check_param_incompatibility()
let $nodata := request:parameter("nodata", $su:defaults("nodata"))
let $orderby:= request:parameter("orderby", $su:defaults("orderby"))

let $eventype := request:parameter("eventtype", $su:defaults("eventtype"))
let $magnitudetype := request:parameter("magnitudetype", $su:defaults("magnitudetype"))

(:includeall switch each include to true:)
let $includeall := fn:lower-case(request:parameter("includeall", $su:defaults("includeall")))
let $includeallorigins := if ($includeall='true') then 'true' else  fn:lower-case(request:parameter("includeallorigins", $su:defaults("includeallorigins")))
let $includeallmagnitudes := if ($includeall='true') then 'true' else fn:lower-case(request:parameter("includeallmagnitudes", $su:defaults("includeallmagnitudes")))
let $includearrivals := if ($includeall='true') then 'true' else fn:lower-case(request:parameter("includearrivals", $su:defaults("includearrivals")))
let $includestationmagnitudes := if ($includeall='true') then 'true' else fn:lower-case(request:parameter("includestationmagnitudes", $su:defaults("includestationmagnitudes")))
let $includeamplitudes := if ($includeall='true') then 'true' else fn:lower-case(request:parameter("includeamplitudes", $su:defaults("includeamplitudes")))
let $includepicks := if ($includeall='true') then 'true' else fn:lower-case(request:parameter("includepicks", $su:defaults("includepicks")))



let $eventid := request:parameter("eventid", $su:defaults("eventid"))
let $originid := request:parameter("originid", $su:defaults("originid"))
let $magnitudeid := request:parameter("magnitudeid", $su:defaults("magnitudeid"))
let $focalmechanismid := request:parameter("focalmechanismid", $su:defaults("focalmechanismid"))

let $limit := request:parameter("limit", $su:defaults("limit"))
let $offset := request:parameter("offset", $su:defaults("offset"))
let $catalog := request:parameter("catalog", $su:defaults("catalog"))
let $contributor := request:parameter("contributor", $su:defaults("contributor"))

let $p-updatedafter := request:parameter("updatedafter",'default' )
let $is-updatedafter-passed := if ($p-updatedafter='default') then false() else true()

let $updatedafter_s := if ($is-updatedafter-passed) then $p-updatedafter else $su:defaults("updatedafter")
let $updatedafter:= try { xs:dateTime(su:time_adjust($updatedafter_s))}
                    catch err:* {fn:error(xs:QName('err:parameters'), 'Wrong format for updatedafter value' )}

let $p-asofdate := request:parameter("asofdate", 'default')
let $is-asofdate-passed :=  if ($p-asofdate='default') then false() else true()
let $asofdate := try { if ($is-asofdate-passed) then xs:dateTime(su:time_adjust($p-asofdate)) else xs:dateTime(su:time_adjust($su:defaults("asofdate")))}
                                               catch err:* {fn:error(xs:QName('err:parameters'), 'Wrong format for asofdate value' )}


(: No readings if no parameters:)
let $minradius := request:parameter("minradius", ())
let $maxradius := request:parameter("maxradius", ())

(: No readings if no parameters:)
let $minradiuskm := request:parameter("minradiuskm", ())
let $maxradiuskm := request:parameter("maxradiuskm", ())

let $mindepth := request:parameter("mindepth", ())
let $maxdepth := request:parameter("maxdepth", ())


let $format := request:parameter("format",$su:defaults("format"))

let $minlatitude1 := request:parameter("minlatitude",())
let $minlat := request:parameter("minlat",())
let $maxlatitude1 := request:parameter("maxlatitude", ())
let $maxlat := request:parameter("maxlat", ())
let $minlongitude1 := request:parameter("minlongitude",())
let $minlon := request:parameter("minlon",())
let $maxlongitude1 := request:parameter("maxlon", ())
let $maxlon := request:parameter("maxlongitude", ())

let $minmagnitude1 := request:parameter("minmagnitude",())
let $minmag := request:parameter("minmag",())
let $maxmagnitude1 := request:parameter("maxmagnitude",())
let $maxmag := request:parameter("maxmag",())

let $starttime1 := request:parameter("starttime", ())
let $start := request:parameter("start", ())
let $endtime1 := request:parameter("endtime", ())
let $end := request:parameter("end", ())
let $latitude1 := request:parameter("latitude",())
let $lat := request:parameter("lat",())
let $longitude1 := request:parameter("longitude", ())
let $lon := request:parameter("lon", ())

let $latitude:=if (exists($lat)) then $lat else if (exists($latitude1)) then $latitude1 else $su:defaults("latitude")
let $lat:=$latitude
let $longitude:=if (exists($lon)) then $lon else if (exists($longitude1)) then $longitude1 else$su:defaults("longitude")
let $lon:=$longitude
(:Se abbiamo minradiuskm allora calcolare minradius con la proporzione e sostituire il valore in minradius con quello calcolato:)
let $minradius := if (exists($minradius)) then xs:decimal($minradius) else if (exists($minradiuskm)) then xs:decimal($minradiuskm) * 180.0 div xs:decimal($su:defaults("maxradiuskm")) else $su:defaults("minradius")
let $maxradius := if (exists($maxradius)) then xs:decimal($maxradius) else if (exists($maxradiuskm)) then xs:decimal($maxradiuskm) * 180.0 div xs:decimal($su:defaults("maxradiuskm")) else $su:defaults("maxradius")
(:In QuakeML files depth is in meters:)
let $mindepth:=if (exists($mindepth)) then $mindepth * 1000.0 else $su:defaults("mindepth")
let $maxdepth:=if (exists($maxdepth)) then $maxdepth * 1000.0 else $su:defaults("maxdepth")

let $minlatitude:=if (exists($minlat)) then $minlat else if (exists($minlatitude1)) then $minlatitude1 else $su:defaults("minlatitude")
let $minlat:=$minlatitude
let $maxlatitude:=if (exists($maxlat)) then $maxlat else if (exists($maxlatitude1)) then $maxlatitude1 else $su:defaults("maxlatitude")
let $maxlat:=$maxlatitude
let $minlongitude:=if (exists($minlon)) then $minlon else if (exists($minlongitude1)) then $minlongitude1 else $su:defaults("minlongitude")
let $minlon:=$minlongitude
let $maxlongitude:=if (exists($maxlon)) then $maxlon else if (exists($maxlongitude1)) then $maxlongitude1 else $su:defaults("maxlongitude")
let $maxlon:=$maxlongitude

let $minmagnitude:=if (exists($minmag)) then $minmag else if (exists($minmagnitude1)) then $minmagnitude1 else $su:defaults("minmagnitude")
let $minmag:=$minmagnitude
let $maxmagnitude:=if (exists($maxmag)) then $maxmag else if (exists($maxmagnitude1)) then $maxmagnitude1 else $su:defaults("maxmagnitude")
let $maxmag:=$maxmagnitude


let $starttime:= try {if (exists($start)) then xs:dateTime(su:time_adjust($start)) else
                      if (exists($starttime1)) then xs:dateTime(su:time_adjust($starttime1)) else xs:dateTime($su:defaults("starttime"))} catch err:* {fn:error(xs:QName('err:parameters'), 'Wrong format for starttime value' )}
let $start:=$starttime
let $endtime  := try {if (exists($end)) then xs:dateTime(su:time_adjust($end)) else
                      if (exists($endtime1)) then xs:dateTime(su:time_adjust($endtime1)) else xs:dateTime($su:defaults("endtime"))} catch err:* {fn:error(xs:QName('err:parameters'), 'Wrong format for endtime value' )}
let $end:=$endtime

(:Enforce intra parameters standard rules : ex. text output set includeallorigins, includellmagnitudes, includearrivals to true ignoring passed parameters:)
let $includeallorigins:= if ($format='text' or $format='extended_text') then 'false' else $includeallorigins
let $includeallmagnitudes:= if ($format='text'or $format='extended_text') then 'false' else $includeallmagnitudes
let $includearrivals:= if ($format='text'or $format='extended_text') then 'false' else $includearrivals

(:TODO move this check after, if it is necessary force limit TODO add TEST:)
let $limit:= if ($includeallorigins = 'true' and $includeallmagnitudes = 'true' and $includearrivals = 'true' and $format='xml' )
            then
                ( if (xs:double($limit)=xs:double('INF')) then se:get-results_limit() else xs:int(min( ($limit,se:get-results_limit()))))
            else $limit

let $result := map {
    "eventtype" : $eventype,
    "magnitudetype" : $magnitudetype,
    "includeallorigins"  :  $includeallorigins,
    "includeallmagnitudes" : $includeallmagnitudes,
    "includearrivals"    : $includearrivals,
    "includestationmagnitudes": $includestationmagnitudes,
    "includeamplitudes"  : $includeamplitudes,
    "includepicks": $includepicks,
    "includeall"  : $includeall,
    "eventid"            : $eventid,
    "originid"           : $originid,
    "magnitudeid"        : $magnitudeid,
    "focalmechanismid"   : $focalmechanismid,
    "limit"              : $limit,
    "offset"             : $offset,
    "catalog"            : $catalog,
    "contributor"        : $contributor,
    "format" : $format,
    "maxradius" : $maxradius,
    "minradius" : $minradius,
    "longitude" : $longitude,
    "lon" : $lon,
    "latitude" : $latitude,
    "lat" : $lat,
    "endtime" : $endtime,
    "end" : $end,
    "starttime" : $starttime,
    "start" : $start,
    "updatedafter" : $updatedafter,
    "asofdate" : $asofdate,
    "maxlongitude" : $maxlongitude,
    "maxlon" : $maxlon,
    "minlongitude" : $minlongitude,
    "minlon" : $minlon,
    "maxlatitude" : $maxlatitude,
    "maxlat" : $maxlat,
    "minlatitude" : $minlatitude,
    "minlat" : $minlat,
    "mindepth" : $mindepth,
    "maxdepth" : $maxdepth,
    "maxmagnitude" : $maxmagnitude,
    "maxmag" : $maxmag,
    "minmagnitude" : $minmagnitude,
    "minmag" : $minmag,
    "orderby": $orderby,
    "nodata" :$nodata,
    "asofdate-passed" :$is-asofdate-passed,
    "post_size_correct" : "true"
}
(:let $log:= for $key in map:keys($result):)
(:            let $log:=lo:debug($key || " " ||$result($key)):)
(:            return ():)
let $_ := su:check_param_errors($result)
return $result
}
catch  err:parameters {
  fn:error(xs:QName('err:parameters'), $err:description)
}
(:catch  * {:)
(:  fn:error(xs:QName('err:parameters'), 'Unexpected error parsing parameters'):)
(:}:)
};

(:~ Remove recursively elements with given $remove-names and its children
 :
 : @param $input element tree
 : @param $remove-names name of elements to remove
 : :)
declare function su:remove-elements($input as element(), $remove-names as xs:string*) as element() {
   element {node-name($input) }
      {$input/@*,
       for $child in $input/node()[name(.)!=$remove-names]
          return
             if ($child instance of element())
                then su:remove-elements($child, $remove-names)
                else $child
      }
};


(:~ Remove recursively elements with given $remove-names and its children, works on sequences
 :
 : @param $input element tree
 : @param $remove-names name of elements to remove
 : :)
declare function su:remove-multi($in as element()*, $remove-names as xs:string*) as element()* {
    for $input in $in
    return
        element { node-name($input) } {
            $input/@*,
            for $child in $input/node()[not(name(.) = $remove-names)]
            (: for $child in $input/node()[name(.)!=$remove-names] Fails :) return
                if ($child instance of element()) then
                    su:remove-elements($child, $remove-names)
                else
                    $child
        }
};


(:~
 : @param $Latitude1 Latitude of Point 1
 : @param $Longitude1 Longitude of Point 1
 : @param $Latitude2 Latitude of Point 2
 : @param $Longitude2 Longitude of Point 2
 : @return the distance in degrees between Point 1 with coordinates ($Latitude1,$Longitude1)
 : and Point 2 with coordinates ($Latitude2,$Longitude2)
 : :)
declare function su:distance($Latitude1 as xs:string*, $Longitude1 as xs:string*, $Latitude2 as xs:string*,
                                      $Longitude2 as xs:string*)
as xs:decimal
{
    (: In radians :)
    (: BEWARE multiple station periods give multiple coordinates TODO better management  :)
(:    let $log  := lo:log("ERROR reading distance" || fn:string-join($Latitude1)):)
    let $lat1 := xs:decimal($Latitude1[1]) * (math:pi() div 180.0)
    let $lon1 := xs:decimal($Longitude1[1]) * (math:pi() div 180.0)
    let $lat2 := xs:decimal($Latitude2[1]) * (math:pi() div 180.0)
    let $lon2 := xs:decimal($Longitude2[1]) * (math:pi() div 180.0)
    (: Distance in km R*fi , d = 6371 * arccos[ (sin(lat1) * sin(lat2)) + cos(lat1) * cos(lat2) * cos(long2 – long1) ]
    Spherical Law of Cosines, TODO change with
     : :) let $d :=
        180.0 div math:pi() * math:acos(math:sin($lat1) * math:sin($lat2) + math:cos($lat1) * math:cos($lat2) *
                                            math:cos($lon2 - $lon1))
    return xs:decimal($d)
};

declare function su:check_radius( $parameter as map(*) , $Latitude1 as xs:string*, $Longitude1 as xs:string* ) as xs:boolean
{
    some $QUERY_PARAM in $parameter
    satisfies
    (
        $QUERY_PARAM("latitude")  = $su:defaults("latitude")  and
        $QUERY_PARAM("longitude") = $su:defaults("longitude") and
        $QUERY_PARAM("maxradius") = $su:defaults("maxradius") and
        $QUERY_PARAM("minradius") = $su:defaults("minradius")
    )
    or
    (
        su:distance($Latitude1, $Longitude1, $QUERY_PARAM("latitude"), $QUERY_PARAM("longitude")) < xs:decimal($QUERY_PARAM("maxradius")) and
        su:distance($Latitude1, $Longitude1, $QUERY_PARAM("latitude"), $QUERY_PARAM("longitude")) > xs:decimal($QUERY_PARAM("minradius"))
    )
};

(:declare function su:open(){:)
(:  db:get(se:get-dbname(),'/')/Version/FDSNStationXML//Network:)
(:};:)

(:TODO modify or delete it:)
declare %updating function su:revision-init(){

  let $start:=current-dateTime()

  (:Version wrap FDSNStationXML :)
  for $doc in  db:get(se:get-dbname())/FDSNStationXML
  return replace node $doc with <Version revision='0' start='{$start}' >{ $doc }</Version>

};

(: Section for PUT:)

(: No need for recursion to translate units, modify update:)


(:mimics functx:remove-attributes-deep:)
declare function su:change-dates-deep
  ( $nodes as node()* ,
    $names as xs:string* )  as node()* {

   for $node in $nodes
   return if ($node instance of element())
          then  element { node-name($node)}
                {
                    (:RAN    css30:netType nor a valid attribute name           :)
                    try {
(:                    let $log:= if (matches(node-name($node), "Network")) then util:log("info", "Examining " || node-name($node)) else ():)
                    for $attribute in $node/@*

                    let $found-attribute-name := name($attribute)
                    let $found-attribute-value := string($attribute)
                    return
                       if ($found-attribute-name = $names )
                       then attribute {$found-attribute-name} { fn:adjust-dateTime-to-timezone(xs:dateTime($found-attribute-value),())}
                       else attribute {$found-attribute-name} {$found-attribute-value}
                    }
                    catch err:* {
                        $node/@*
                    }
                    ,  su:change-dates-deep($node/node(), $names)

                }
          else if ($node instance of document-node())
          then su:change-dates-deep($node/node(), $names)
          else $node
 } ;


declare %updating function su:put($body as node()*, $dbname as xs:string  ,$catalog as xs:string, $filename as xs:string)
{
(:    let $log:=lo:log("Request to insert " || $filename || " in " || $dbname ):)
    (:In decoded the data passed in request body :)
(:    let $decoded := fn:serialize($body):)

    ver:real_put($body ,$filename, su:combine-dbname($dbname, $catalog))

};


declare function su:combine-dbname($dbname as xs:string, $catalog as xs:string) as xs:string{
  $dbname || se:get-catalogs_prefix() || $catalog
};

declare function su:extract-catalog($dbname as xs:string) as xs:string{
fn:substring-after($dbname,se:get-catalogs_prefix())
};

declare %updating function su:delete($dbname as xs:string ,$catalog as xs:string,$filename as xs:string,$erase as xs:string){
   ver:delete( su:combine-dbname($dbname, $catalog), $filename, $erase)
};

declare function su:get-parameter($m as map(*), $k as xs:string) as xs:string+
{
(:      let $p:= util:log("error", "looking for " || $k || " = " || $m($k) ) :)
(:      return:)
      if ( empty($m($k))  ) then  "EMPTY" else  $m($k)
};

(:TODO simplify or skip with configuration:)
declare function su:build_namespaces($node as node())as attribute()*{
    let $_:=lo:debug( 'build_namespaces' )
    for $element in $node/*
(:         let $log:=lo:debug("Element text "  || $element/text() ):)
         let $namespaces :=   (
            for $pref in in-scope-prefixes($element)
                return if ($pref!='' and $pref!='xsi' and $pref != "xml" ) then
                        namespace {$pref} { fn:namespace-uri-for-prefix($pref,$element) })
    return $namespaces
};

declare function su:build_attributes($node as node()?) as attribute()* {

    let $attributes:= (
        for $attr in $node/@*

         let $attribute := (
         attribute {name($attr)} {$attr}
         )
(:         let $l := log('Attribute name ' || name($attr) || ' value ' || $attr ):)
         return $attribute
        )
(:    let $namespaces:= su:build_namespaces($node):)
    return
(:    $namespaces, :)
    $attributes

};
