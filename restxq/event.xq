(:~
 : Event module, restxq entry
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace event = 'http://webservices.ingv.it/fdsnws/event';
import module namespace session = 'http://basex.org/modules/session';
import module namespace bin = 'http://expath.org/ns/binary';
import module namespace su='http://webservices.ingv.it/fdsnws/event/modules/util' at '../repo/it/ingv/webservices/fdsnws/event/modules/util.xqm';
import module namespace qu='http://webservices.ingv.it/fdsnws/event/modules/query' at '../repo/it/ingv/webservices/fdsnws/event/modules/query.xqm';
import module namespace sy='http://webservices.ingv.it/fdsnws/event/modules/style' at '../repo/it/ingv/webservices/fdsnws/event/modules/style.xqm';
import module namespace ver='http://webservices.ingv.it/fdsnws/event/modules/version' at '../repo/it/ingv/webservices/fdsnws/event/modules/version.xqm';
import module namespace co='http://webservices.ingv.it/fdsnws/utils/commons' at '../repo/it/ingv/webservices/fdsnws/utils/commons.xqm';
import module namespace ha='http://webservices.ingv.it/fdsnws/utils/handle' at '../repo/it/ingv/webservices/fdsnws/utils/handle.xqm';
import module namespace lo='http://webservices.ingv.it/fdsnws/utils/log' at '../repo/it/ingv/webservices/fdsnws/utils/log.xqm';
import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at '../repo/it/ingv/webservices/fdsnws/event/modules/settings.xqm';
import module namespace ma='http://webservices.ingv.it/fdsnws/event/modules/management' at '../repo/it/ingv/webservices/fdsnws/event/modules/management.xqm';
import module namespace ap='http://webservices.ingv.it/fdsnws/event/modules/application' at '../repo/it/ingv/webservices/fdsnws/event/modules/application.xqm';
import module namespace cont='http://webservices.ingv.it/fdsnws/event/modules/contributors' at '../repo/it/ingv/webservices/fdsnws/event/modules/contributors.xqm';
import module namespace cata='http://webservices.ingv.it/fdsnws/event/modules/catalogs' at '../repo/it/ingv/webservices/fdsnws/event/modules/catalogs.xqm';
import module namespace ib='http://webservices.ingv.it/fdsnws/event/modules/ingv_bulletin' at '../repo/it/ingv/webservices/fdsnws/event/modules/ingv_bulletin.xqm';

import module namespace json='http://basex.org/modules/json';
declare copy-namespaces preserve, inherit;
declare default element namespace 'http://quakeml.org/xmlns/bed/1.2';
declare namespace q='http://quakeml.org/xmlns/quakeml/1.2';

declare %public variable  $event:entrypoint:='/fdsnws/event/1/';

(::::::::::::::::::::::::::::::::::::::::::::::::Permissions:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::)

(:~
 : Permissions: Admin area.
 : Checks if the current user has admin permissions; if not, throws error.
 : @param $perm  map with permission data
 :)
declare
  %perm:check('fdsnws/event/1', '{$perm}')
  %rest:PUT
  %rest:DELETE

  function event:check-event($perm) as node()* {
    try {

      let $user_pass := bin:decode-string(xs:base64Binary(fn:tokenize($perm('authorization'))[2]),'UTF-8')
      let $up := fn:tokenize($user_pass,':')
      let $user := $up[1]
      let $password := $up[2]
      (:      let $log := lo:log('user:password " || $user_pass  || ' user: ' || $user || ' password:' || $password || ' user permission: ' || user:list-details($user)/@permission || ' $perm?allow ' || $perm?allow ):)
      let $check := user:check($user,$password)

      where user:list-details($user)/@permission = $perm?allow
      return ()
    }
    catch user:* {
       let $log := lo:log($err:description)
       return
       fn:error(xs:QName('err:unauthorized'), 'Access denied' )
    }
};

declare
  %perm:check('fdsnws/event/1/management/eventindex', '{$perm}')
  %rest:GET
  function event:check-management($perm) as empty-sequence() {
    try {

      let $user_pass := bin:decode-string(xs:base64Binary(fn:tokenize($perm('authorization'))[2]),'UTF-8')
      let $up := fn:tokenize($user_pass,':')
      let $user := $up[1]
      let $password := $up[2]
      (:      let $log := lo:log("user:password " || $user_pass  || ' user: ' || $user || ' password:' || $password || ' user permission: ' || user:list-details($user)/@permission || ' $perm?allow ' || $perm?allow ):)
      let $_ := user:check($user,$password)

      where user:list-details($user)/@permission = $perm?allow
      return ()
    }
    catch user:* {
       let $_ := lo:log($err:description)
       return
       fn:error(xs:QName('err:unauthorized'), 'Access denied' )
    }
    catch err:* {
       let $_ := lo:log($err:description)
       return
       fn:error(xs:QName('err:unauthorized'), 'Access denied' )
    }

};

(::::::::::::::::::::::::::::::::::::::::::::::::Permissions End:::::::::::::::::::::::::::::::::::::::::::::::::::::::)

declare
  %rest:path("fdsnws/event/1/version")
  %rest:GET
  %output:method("text")
function event:version() {
  '1.69.1'
};

declare
  %rest:path("fdsnws/event/1")
  %rest:GET
  %output:method("xml")
function event:get-application-root() {
            <rest:response>
            <output:serialization-parameters>
              <output:media-type value='text/html'/>
              <output:indent value='true'/>
              <output:version value='1.0'/>
              <output:omit-xml-declaration value='yes'/>
              </output:serialization-parameters>
            </rest:response>,
  ap:get_application_root()
};


declare
  %rest:path("fdsnws/event/1/application.wadl")
  %output:method("xml")
  %rest:GET
function event:application-wadl() {
            <rest:response>
            <output:serialization-parameters>
              <output:media-type value='application/xml'/>
              <output:indent value='true'/>
              <output:version value='1.0'/>
              <output:omit-xml-declaration value='no'/>
              </output:serialization-parameters>
            </rest:response>,
  ap:get_application_wadl()
};

declare
  %rest:path("fdsnws/event/1/application.json")
  %rest:produces("application/json")
  %rest:GET
function event:application-json() {
  <rest:response>
    <output:serialization-parameters>
       <output:media-type value='application/json'/>
    </output:serialization-parameters>
  </rest:response>,
  ap:get_application_json()
};

declare
  %rest:path("fdsnws/event/1/contributors")
  %output:method("xml")
  %rest:GET
function event:contributors() {
            <rest:response>
            <output:serialization-parameters>
              <output:media-type value='application/xml'/>
              <output:indent value='true'/>
              <output:version value='1.0'/>
              <output:omit-xml-declaration value='no'/>
              </output:serialization-parameters>
            </rest:response>,
  cont:get_contributors()
};

declare
  %rest:path("fdsnws/event/1/catalogs")
  %output:method("xml")
  %rest:GET
function event:catalogs() {
            <rest:response>
            <output:serialization-parameters>
              <output:media-type value='application/xml'/>
              <output:indent value='true'/>
              <output:version value='1.0'/>
              <output:omit-xml-declaration value='no'/>
              </output:serialization-parameters>
            </rest:response>,
  cata:get_catalogs()
};


(: primary path for PUT:)
(:Optionally manage database index updates after put:)
declare
  %rest:path("fdsnws/event/1/event")
  %rest:query-param("dbname", "{$dbname}",'')
  %rest:query-param("catalog", "{$catalog}",'')
  %rest:query-param("filename", "{$filename}",'')
  %rest:query-param("upindex", "{$upindex}",'true')
  %rest:PUT("{$body}")
  %rest:consumes("application/xml")
  %rest:consumes("text/xml")
  %perm:allow("admin")
  %updating
function event:insert($body as node()*, $dbname as xs:string, $catalog as xs:string, $filename as xs:string, $upindex as xs:string) {
  (
  if ($upindex='true') then
  (
  su:put($body,$dbname,$catalog,$filename),
  update:output(
    <rest:response>
     <http:response status="303">
    <http:header name="Location" value="/fdsnws/event/1/management/eventindex"/>
  </http:response>
</rest:response>)
)
else
  su:put($body,$dbname,$catalog,$filename)
  )
};

(: primary path for DELETE:)
(:Optionally manage database index updates after put:)
declare
  %rest:path("fdsnws/event/1/event")
  %rest:query-param("dbname", "{$dbname}",'')
  %rest:query-param("catalog", "{$catalog}",'')
  %rest:query-param("filename", "{$filename}",'')
  %rest:query-param("erase", "{$erase}",'false')
  %rest:query-param("upindex", "{$upindex}",'true')
  %rest:DELETE
  %perm:allow("admin")
  %updating
function event:delete($dbname as xs:string, $catalog as xs:string, $filename as xs:string, $erase as xs:string, $upindex as xs:string) {
  (
  if ($upindex='true') then
  (
  su:delete($dbname,$catalog,$filename,$erase),
  update:output(
    <rest:response>
        <http:response status="303">
         <http:header name="Location" value="/fdsnws/event/1/management/eventindex"/>
        </http:response>
    </rest:response>)
 )
else
  su:delete($dbname,$catalog,$filename,$erase)
  )
};

(:Catch all for syntax errors:)
declare
  %rest:path("fdsnws/event/1/{$something=.+}")
  %rest:produces("application/xml")
  %rest:GET
function event:other($something){
 fn:error(xs:QName('err:parameters'), '' )
};


(: primary path for GET, not all explicit query parameters are needed here:)
declare
  %rest:path("fdsnws/event/1/query")
  %rest:query-param("magnitudetype", "{$magnitudetype}", '')
  %rest:query-param("eventid", "{$eventid}",'')
  %rest:query-param("format", "{$format}",'xml')
  %rest:query-param("nodata", "{$nodata}",'204')
  %rest:query-param("asofdate", "{$asofdate}",'0001-01-01T00:00:00')
  %rest:produces("application/xml", "text/xml")
  %rest:GET
function event:query(
  $magnitudetype as xs:string,
  $eventid as xs:string,
  $format as xs:string,
  $nodata as xs:string,
  $asofdate  as xs:string ) {

    switch ($format)
       case "xml"
         return (
            (# db:copynode false #) {
            <rest:response>
            <output:serialization-parameters>
              <output:media-type value='application/xml'/>
              <output:indent value='no'/>
              <output:version value='1.0'/>
              <output:omit-xml-declaration value='no'/>
              </output:serialization-parameters>
            </rest:response>,
            <q:quakeml xmlns="http://quakeml.org/xmlns/bed/1.2" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" xmlns:ingv="http://webservices.ingv.it/fdsnws/event/1">
            <eventParameters publicID="smi:webservices.ingv.it/fdsnws/event/1/query">
                  {(# db:copynode false #) {qu:get-executor()}}
            </eventParameters>
            </q:quakeml>

            }
       )
       case "text" return
       (

        if ($eventid or $magnitudetype )
        then(
                (: Can't use only index database for results :)
                (# db:copynode false #)
                {
                    <rest:response>
                        <output:serialization-parameters>
                        <output:media-type value='text/plain'/>
                        </output:serialization-parameters>
                    </rest:response>,
                    let $style:= $sy:event_style

                    return xslt:transform-text(   element quakeml {
                    (:                         su:build_namespaces((# db:copynode false #){$result}),:)

                    <q:quakeml xmlns="http://quakeml.org/xmlns/bed/1.2" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" xmlns:ingv="http://webservices.ingv.it/fdsnws/event/1">
                    <eventParameters publicID="smi:webservices.ingv.it/fdsnws/event/1/query">
                    (# db:copynode false #) {qu:get-executor()}
                    </eventParameters>
                    </q:quakeml>

                    }, $style)
                }
            )
        else
            (
                <rest:response>
                    <output:serialization-parameters>
                    <output:media-type value='text/plain'/>
                    <output:method value='text'/>
                    <output:indent value='yes'/>
                    <output:item-separator value='&#xA;'/>
                    </output:serialization-parameters>
                </rest:response>,
                let $PARAM_GET := su:set_parameter_table_from_GET()
                 (:let $log := lo:log("Now getting results"):)
                 let $result:=(# db:copynode false #) {qu:query_database_index_text($PARAM_GET)}
                 (:let $log := lo:log("Now checking results"):)
                 let $check :=  if (fn:empty($result))  then fn:error(xs:QName('err:nodata'), $PARAM_GET("nodata"))
                 return
                 (# db:copynode false #) {
                 "#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType",
                 $result
                 }
              )

        )
       case "extended_text" return
       (
        (: Forced to use first case, can't use only index database for results :)
        if ( $eventid or $magnitudetype or ( $asofdate!="0001-01-01T00:00:00" ))
        then (

                (# db:copynode false #)
                {
                    <rest:response>
                        <output:serialization-parameters>
                        <output:media-type value='text/plain'/>
                        </output:serialization-parameters>
                    </rest:response>,
                    let $style:= $sy:event_style_extended_text

                    return xslt:transform-text(   element quakeml {
                    (:                         su:build_namespaces((# db:copynode false #){$result}),:)

                    <q:quakeml xmlns="http://quakeml.org/xmlns/bed/1.2" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" xmlns:ingv="http://webservices.ingv.it/fdsnws/event/1">
                    <eventParameters publicID="smi:webservices.ingv.it/fdsnws/event/1/query">
                    (# db:copynode false #) {qu:get-executor()}
                    </eventParameters>
                    </q:quakeml>

                    }, $style)
                }

        )
        else
             (
             (: Use database index for all necessary data :)
                <rest:response>
                    <output:serialization-parameters>
                    <output:media-type value='text/plain'/>
                    <output:method value='text'/>
                    <output:indent value='yes'/>
                    <output:item-separator value='&#xA;'/>
                    </output:serialization-parameters>
                </rest:response>,
                    let $PARAM_GET := su:set_parameter_table_from_GET()

                    let $result:=(# db:copynode false #) {qu:query_database_index_text_selection($PARAM_GET)}

                    let $check :=  if (fn:empty($result))  then fn:error(xs:QName('err:nodata'), $PARAM_GET("nodata"))
                    return
                         (# db:copynode false #) {
                             "#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source",
                             $result
                         }
              )

        )
       case "hypo71phs" return
       (
        (: Forced to use first case, can't use only index database for results :)
        if ( $eventid or $magnitudetype or ( $asofdate!="0001-01-01T00:00:00" ))
        then (
                    <rest:response>
                        <output:serialization-parameters>
                        <output:media-type value='text/plain'/>
                        </output:serialization-parameters>
                    </rest:response>,
                    string-join(ib:qml_to_ingv_phs_lines( qu:query_eventid( su:set_parameter_table_from_GET())), '&#10;')
        )
        else
        (
                        <rest:response>
                        <output:serialization-parameters>
                        <output:media-type value='text/plain'/>
                        </output:serialization-parameters>
                    </rest:response>,
                    string-join(ib:qml_to_ingv_phs_lines( qu:get-executor()), '&#10;')

        )

        )
       case "phsnll" return
       (
        (: Forced to use first case, can't use only index database for results :)
        if ( $eventid or $magnitudetype or ( $asofdate!="0001-01-01T00:00:00" ))
        then (
                    <rest:response>
                        <output:serialization-parameters>
                        <output:media-type value='text/plain'/>
                        </output:serialization-parameters>
                    </rest:response>,
                    string-join(ib:qml_to_phsnll_lines( qu:query_eventid( su:set_parameter_table_from_GET())), '&#10;')
        )
        else
        (
                        <rest:response>
                        <output:serialization-parameters>
                        <output:media-type value='text/plain'/>
                        </output:serialization-parameters>
                    </rest:response>,
                    string-join(ib:qml_to_phsnll_lines( qu:get-executor()), '&#10;')

        )

        )
        default return ( fn:error(xs:QName('err:parameters'), 'Unknown format type'  ))
};

declare
  %rest:path("fdsnws/event/1/query")
  %rest:POST("{$body}")
  %rest:consumes("application/json")
  %input:json("format=xquery,lax=yes")
  %rest:query-param("includeallorigins", "{$includeallorigins}", "false")
  %rest:query-param("includeallmagnitudes", "{$includeallmagnitudes}", "false")
  %rest:query-param("includearrivals", "{$includearrivals}", "false")
  %rest:query-param("includepicks", "{$includepicks}", "false")
  %rest:query-param("includeall", "{$includeall}", "false")
  %rest:query-param("format", "{$format}", "xml")
  %rest:query-param("nodata", "{$nodata}", "204")
  %rest:query-param("asofdate", "{$asofdate}", "0001-01-01T00:00:00")
  %rest:produces("application/xml", "text/plain")
function event:query-post(
  $body as item()?,
  $includeallorigins as xs:string,
  $includeallmagnitudes as xs:string,
  $includearrivals as xs:string,
  $includepicks as xs:string,
  $includeall as xs:string,
  $format as xs:string,
  $nodata as xs:string,
  $asofdate as xs:string
) {
  (: body -> map(*) con %input:json format=xquery :)
  let $ids-body :=
    if ($body instance of map(*) and exists($body?eventid)) then
      $body?eventid?* ! normalize-space(string(.))
    else ()

  (: rimozione duplicati preservando l’ordine :)
  let $ids :=
    fold-left($ids-body, (), function($acc, $id) {
      if ($id = "" or $id = $acc) then $acc else ($acc, $id)
    })

  return
    if (empty($ids)) then fn:error(xs:QName("err:nodata"), "No eventid values in JSON body.")
    else (

      (:   build QUERY_PARAM map for downstream :)
      let $QP := map{
        "includeallorigins":    $includeallorigins,
        "includeallmagnitudes": $includeallmagnitudes,
        "includearrivals":      $includearrivals,
        "includepicks":         $includepicks,
        "includeall":           $includeall,
        "format":               $format,
        "nodata":               $nodata,
        "asofdate":             $asofdate,
        "catalog":              "",
        "contributor":          ""
      }
      (:    TODO check PARAMS :)
      return
        if (empty($ids)) then (
          <rest:response>
            <http:response status="{ xs:integer($nodata) }">
              <http:header name="X-Requested-Count" value="0"/>
              <http:header name="X-Returned-Count"  value="0"/>
              <http:header name="X-Missing-Count"   value="0"/>
            </http:response>
          </rest:response>,
          ()
    )
    else
      let $res     := qu:lookup_events_by_ids($QP, $ids)
      let $events  := $res?events
      let $missing := $res?missing

      let $hdr :=
        <rest:response>
          <http:response status="{ if (empty($events)) then xs:integer($nodata) else 200 }">
            <http:header name="X-Requested-Count" value="{ count($ids) }"/>
            <http:header name="X-Returned-Count"  value="{ count($events) }"/>
            <http:header name="X-Missing-Count"   value="{ count($missing) }"/>
            {
              if (exists($missing))
              then <http:header name="X-Missing-EventIds" value="{ " No more than 3 ids are shown: " || string-join($missing[1 to 3], ',') }"/>
              else ()
            }
          </http:response>
        </rest:response>

      return (

        if (empty($events)) then ()
        else

            switch ($format)
            case "xml"
              return (

                (# db:copynode false #) {
                <rest:response>
                <output:serialization-parameters>
                  <output:media-type value='application/xml'/>
                  <output:indent value='no'/>
                  <output:version value='1.0'/>
                  <output:omit-xml-declaration value='no'/>
                  </output:serialization-parameters>
                </rest:response>,
                <q:quakeml xmlns="http://quakeml.org/xmlns/bed/1.2" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" xmlns:ingv="http://webservices.ingv.it/fdsnws/event/1">
                <eventParameters publicID="smi:webservices.ingv.it/fdsnws/event/1/query">
                      {(# db:copynode false #) {$events}}
                </eventParameters>
                </q:quakeml>

            }

              )
            case "text"
               return (
                (: TODO change events, there must not be multiplicity in origins and magnitudes lookup_events_by_ids() must to check and return accordingly:)
                (# db:copynode false #)
                {
                    <rest:response>
                        <output:serialization-parameters>
                        <output:media-type value='text/plain'/>
                        </output:serialization-parameters>
                    </rest:response>,
                    let $style:= $sy:event_style

                    return xslt:transform-text(   element quakeml {

                    <q:quakeml xmlns="http://quakeml.org/xmlns/bed/1.2" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" xmlns:ingv="http://webservices.ingv.it/fdsnws/event/1">
                    <eventParameters publicID="smi:webservices.ingv.it/fdsnws/event/1/query">
                    (# db:copynode false #) {$events}
                    </eventParameters>
                    </q:quakeml>

                    }, $style)
                }
            )
            case "extended_text" (:TODO:)
                return ()
            case "hypo71phs"
                return
                ($hdr,
                string-join(ib:qml_to_ingv_phs_lines( $events), '&#10;')
                )
            case "phsnll"
                return
                ($hdr,
                string-join(ib:qml_to_phsnll_lines( $events), '&#10;')
                )
            default return ()

     ))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::Preview::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::)
declare
  %rest:path("fdsnws/event/1/preview/version")
  %rest:produces("application/json")
  %rest:GET
function event:get-preview-version() {
  <rest:response>
    <output:serialization-parameters>
    <output:media-type value='application/json'/>
    </output:serialization-parameters>
  </rest:response>,
    let $request-uri := request:path()||'?'||request:query()
    return qu:preview-version()
};


declare
  %rest:GET
  %rest:path("/fdsnws/event/1/preview/year/{$year}")
  %rest:produces("application/json")
function event:preview-year($year as xs:string)  {
  <rest:response>
    <output:serialization-parameters>
    <output:media-type value='application/json'/>
    </output:serialization-parameters>
  </rest:response>,
  qu:preview-year($year)
};

(:::::::::::::::::::::::::::::::::::::::::::::::END Preview::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::)
(::::::::::::::::::::::::::::::::::::::::::::::::::Settings::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::)

(: primary path for settings PUT:)
(:TODO manage 404 with error in PUT query:)
declare
  %rest:path("fdsnws/event/1/settings")
  %rest:produces("application/xml")
  %rest:PUT("{$body}")
  %perm:allow("user")
function event:put-settings($body) {
    let $request-uri := request:path()||'?'||request:query()
    return se:set-settings($body)
};

declare
  %rest:path("fdsnws/event/1/settings")
  %rest:GET
  %output:method("xml")
function event:get-settings() {
  <rest:response>
    <output:serialization-parameters>
    <output:media-type value='application/xml'/>
    <output:indent value='no'/>
    <output:version value='1.0'/>
    <output:omit-xml-declaration value='no'/>
    </output:serialization-parameters>
  </rest:response>,
  se:get_settings()
};

declare
  %rest:path("fdsnws/event/1/settings/xml")
  %rest:GET
  %output:method("xml")
function event:get-settings-xml() {
  <rest:response>
    <output:serialization-parameters>
    <output:media-type value='application/xml'/>
    </output:serialization-parameters>
  </rest:response>,
  $se:settings_doc
};

declare
  %rest:path("fdsnws/event/1/test/xml")
  %rest:query-param("starttime", "{$starttime}",'0001-01-01T00:00:00')
  %rest:query-param("endtime", "{$endtime}", '10001-01-01T00:00:00')
  %rest:query-param("start", "{$start}",'0001-01-01T00:00:00')
  %rest:query-param("end", "{$end}", '10001-01-01T00:00:00')
  %rest:query-param("minlatitude", "{$minlatitude}",'-90.0')
  %rest:query-param("maxlatitude", "{$maxlatitude}",'90.0')
  %rest:query-param("minlon", "{$minlongitude}",'-180')
  %rest:query-param("maxlongitude", "{$maxlongitude}",'180')
  %rest:query-param("minlat", "{$minlat}",'-90.0')
  %rest:query-param("maxlat", "{$maxlat}",'90.0')
  %rest:query-param("minlon", "{$minlon}",'-180')
  %rest:query-param("maxlon", "{$maxlon}",'180')
  %rest:query-param("latitude", "{$latitude}",'0')
  %rest:query-param("longitude", "{$longitude}",'0')
  %rest:query-param("lat", "{$lat}",'0')
  %rest:query-param("lon", "{$lon}",'0')
  %rest:query-param("minradius", "{$minradius}",'0')
  %rest:query-param("maxradius", "{$maxradius}",'180')
  %rest:query-param("minradiuskm", "{$minradiuskm}",'0')
  %rest:query-param("maxradiuskm", "{$maxradiuskm}",'20037.5')
  %rest:query-param("mindepth", "{$mindepth}",'0.0')
  %rest:query-param("maxdepth", "{$maxdepth}",'6371.0')
  %rest:query-param("minmagnitude", "{$minmagnitude}", '-100')
  %rest:query-param("minmag", "{$minmag}", '-100')
  %rest:query-param("maxmagnitude", "{$maxmagnitude}", '100')
  %rest:query-param("maxmag", "{$maxmag}", '100')
  %rest:query-param("eventtype", "{$eventtype}", '')
  %rest:query-param("magnitudetype", "{$magnitudetype}", '')
  %rest:query-param("includeallorigins", "{$includeallorigins}", 'FALSE')
  %rest:query-param("includeallmagnitudes", "{$includeallmagnitudes}", 'FALSE')
  %rest:query-param("includearrivals", "{$includearrivals}", 'FALSE')
  %rest:query-param("eventid", "{$eventid}",'')
  %rest:query-param("limit", "{$limit}",'')
  %rest:query-param("offset", "{$offset}",'1')
  %rest:query-param("orderby", "{$orderby}",'time')
  %rest:query-param("catalog", "{$catalog}",'')
  %rest:query-param("contributor", "{$contributor}",'')
  %rest:query-param("updatdafter", "{$updatedafter}",'')
  %rest:query-param("format", "{$format}",'xml')
  %rest:query-param("nodata", "{$nodata}",'204')
  %rest:produces("application/xml", "text/xml")
  %rest:GET
  %output:method("xml")
function event:get-database-xml(
  $starttime as xs:string, $endtime as xs:string, $start as xs:string, $end as xs:string, $minlatitude as xs:string,
  $maxlatitude as xs:string, $minlongitude as xs:string, $maxlongitude as xs:string, $minlat as xs:string, $maxlat as xs:string,
  $minlon as xs:string, $maxlon as xs:string, $latitude as xs:string, $longitude as xs:string, $lat as xs:string, $lon as xs:string,
  $minradius as xs:string, $maxradius as xs:string, $minradiuskm as xs:string, $maxradiuskm as xs:string,
  $mindepth as xs:string, $maxdepth as xs:string, $minmagnitude as xs:string, $minmag as xs:string,
  $maxmagnitude as xs:string, $maxmag as xs:string, $eventtype as xs:string, $magnitudetype as xs:string, $includeallorigins as xs:string,
  $includeallmagnitudes as xs:string, $includearrivals as xs:string, $eventid as xs:string,
  $limit as xs:string, $offset as xs:string, $orderby as xs:string, $catalog as xs:string,  $contributor as xs:string,
  $updatedafter as xs:string, $format as xs:string, $nodata as xs:string
  ) {

    switch ($format)
       case "xml"
         return (

              <rest:response>
                <output:serialization-parameters>
                <output:media-type value='application/xml'/>
                  <output:omit-xml-declaration value='no'/>
                </output:serialization-parameters>
              </rest:response>
              ,
              let $PARAM_GET := su:set_parameter_table_from_GET()
              return
              qu:query_database_index($PARAM_GET)  )
         case "text" return
       (
                <rest:response>
                    <output:serialization-parameters>
                    <output:media-type value='text/plain'/>
                    <output:method value='text'/>
                    <output:indent value='yes'/>
                    <output:item-separator value='&#xA;'/>
                    </output:serialization-parameters>
               </rest:response>,

               let $PARAM_GET := su:set_parameter_table_from_GET()

(: TODO: Alternative way to build directly text output avoiding XSLT transformation :)
            return
                 (# db:copynode false #) {
                 "#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType&#xA;",
                 qu:query_database_index_text($PARAM_GET)
                 }
)
default return ( fn:error(xs:QName('err:parameters'), 'Unknown format type'  ))
};




(::::::::::::::::::::::::::::::::::::::::::::::End Settings::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::)

(:::::::::::::::::::::::::::::::::::::::::::::::Management:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::)

declare
  %updating
  %rest:path("fdsnws/event/1/management/eventindex")
  %rest:GET
  %rest:PUT
  %rest:DELETE
  %perm:allow("admin")
  %output:method("text")

function event:get-eventindex() {
  ma:make_event_index()
};

declare
  %rest:path("fdsnws/event/1/management/databases_info")
  %output:method("xml")
function event:databases_info() {
    <rest:response>
    <output:serialization-parameters>
      <output:media-type value='application/xml'/>
      <output:indent value='true'/>
      <output:version value='1.0'/>
      <output:omit-xml-declaration value='no'/>
      </output:serialization-parameters>
    </rest:response>,
    ver:get_databases_info()
};

(:::::::::::::::::::::::::::::::::::::::::::::::End Management:::::::::::::::::::::::::::::::::::::::::::::::::::::::::)

(:::::::::::::::::::::::::::::::::::::::::::Errors management::::::::::::::::::::::::::::::::::::::::::::::::::::::::::)

declare
  %output:method("text")
  %rest:error("err:nodata")
  %rest:error-param("description", "{$parameter}")
function event:nodata-error($parameter) {
   let $request-uri := request:path()||'?'||request:query()
   let $http_response := if ($parameter='404') then <http:response status="404"/> else <http:response status="204"/>
    return
    (
      <rest:response>
    <output:serialization-parameters>
      <output:media-type value='text/plain'/>
      <output:indent value='no'/>
    </output:serialization-parameters>
    {$http_response}
  </rest:response>,
'Error 404 - no matching events found

Usage details are available from' || $event:entrypoint ||'

Request:

' || $request-uri ||
'

Request Submitted: ' || adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('-PT0H')) || '

Service ver: ' || co:version()
    )

};


declare
  %output:method("text")
  %rest:error("err:parameters")
  %rest:error-param("description", "{$parameter}")
function event:parameters-error($parameter) {
let $request-uri := request:path()||'?'||request:query()
let $message:=
'Error 400: Bad request

Syntax Error in Request

'
let $message :=  if ($parameter!='') then $message || $parameter || '&#10;&#10;' else $message

return (
  <rest:response>
    <output:serialization-parameters>
      <output:media-type value='text/plain'/>
      <output:indent value='no'/>
    </output:serialization-parameters>
    <http:response status="400"></http:response>
   </rest:response>,
$message||
'Usage details are available from ' || $event:entrypoint ||'

Request:

' || $request-uri ||
'

Request Submitted: ' || adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('-PT0H')) || '

Service ver: ' || co:version()
)

};


declare
  %output:method("text")
  %rest:error("err:unauthorized")
  %rest:error-param("description", "{$parameter}")
function event:unauthorized-error($parameter) {
let $request-uri := request:path()||'?'||request:query()
return (
  <rest:response>
    <output:serialization-parameters>
      <output:media-type value='text/plain'/>
      <output:indent value='no'/>
    </output:serialization-parameters>
    <http:response status="401"></http:response>
   </rest:response>,

'Error 401: Unauthorized

' || $parameter ||'

Usage details are available from ' || $event:entrypoint ||'

Request:

' || $request-uri ||
'

Request Submitted: ' || adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('-PT0H')) || '

Service ver: ' || co:version()
)

};


declare
  %output:method("text")
  %rest:error("err:identifier")
  %rest:error-param("description", "{$parameter}")
function event:identifier-error($parameter) {
let $request-uri := request:path()||'?'||request:query()
return (
  <rest:response>
    <output:serialization-parameters>
      <output:media-type value='text/plain'/>
      <output:indent value='no'/>
    </output:serialization-parameters>
    <http:response status="409"></http:response>
   </rest:response>,

'Error 409: Conflict

' || $parameter ||'

Usage details are available from ' || $event:entrypoint || '

Request:

' || $request-uri ||
'

Request Submitted: ' || adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('-PT0H')) || '

Service ver: ' || co:version()
)

};


(:TODO function for duplicates in db error:)
declare
  %output:method("text")
  %rest:error("err:inconsistency")
  %rest:error-param("description", "{$parameter}")
function event:inconsistency-error($parameter) {
let $request-uri := request:path()||'?'||request:query()
return (
  <rest:response>
    <output:serialization-parameters>
      <output:media-type value='text/plain'/>
      <output:indent value='no'/>
    </output:serialization-parameters>
    <http:response status="500"></http:response>
   </rest:response>,

'Error 500: Internal server error

' || $parameter ||'

Usage details are available from ' || $event:entrypoint || '

Request:

' || $request-uri ||
'

Request Submitted: ' || adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('-PT0H')) || '

Service ver: ' || co:version()
)

};

(:::::::::::::::::::::::::::::::::::::::::::::::::::End Errors management::::::::::::::::::::::::::::::::::::::::::::::)