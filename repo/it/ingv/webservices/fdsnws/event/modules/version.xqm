(:~
 : Version module.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace ver='http://webservices.ingv.it/fdsnws/event/modules/version';

import module namespace in="http://webservices.ingv.it/fdsnws/event/modules/index" at 'index.xqm';
import module namespace se="http://webservices.ingv.it/fdsnws/event/modules/settings" at 'settings.xqm';
(: import module namespace co="http://webservices.ingv.it/fdsnws/utils/commons" at '../../utils/commons.xqm';
import module namespace ha="http://webservices.ingv.it/fdsnws/utils/handle" at '../../utils/handle.xqm'; :)
import module namespace lo="http://webservices.ingv.it/fdsnws/utils/log" at '../../utils/log.xqm';


(:
Takes care of packaging data in the version element, example:
<Version revision="1" start="2023-12-19T09:30:11.53+01:00" end="">
:)

(:TODO change this to new databases list:)
declare %updating function ver:revision-init(){

  let $start:=current-dateTime()
  (:Version wrap QuakeML :)
  for $doc in  db:get('Event')/quakeml
  return replace node $doc with <Version revision='0' start='{$start}' >{ $doc }</Version>

};

declare %updating function ver:real_put(
    $decoded as node()*,
    $filename as xs:string,
    $dbname as xs:string
) {
    let $currentDB := $dbname
    let $event := $decoded
    let $start := current-dateTime()

    return
        if (not(se:get-history())) then
            let $wrapped := <Version revision='0' start='{$start}'>{ $event }</Version>
            return db:put($currentDB, $wrapped, $filename)

        else
            let $alreadyindb := doc-available($currentDB || "/" || $filename)
            return
                if ($alreadyindb) then
                    let $old_copy := db:get($currentDB, $filename)
                    let $top := $old_copy/Version[1]
                    let $new_revision := xs:decimal($top/@revision) + 1.0
                    let $wrapped := <Version revision='{$new_revision}' start='{$start}'>{ $event }</Version>

                    let $document_copy :=
                        copy $doc := db:get($currentDB, $filename)
                        modify
                        (
                            if (exists($doc/Version[1]) and not(exists($doc/Version[1]/@endDate))) then
                                insert node attribute endDate { $start } into $doc/Version[1]
                            else (),
                            insert node $wrapped before $doc/Version[1]
                        )
                        return $doc

                    return db:put($currentDB, $document_copy, $filename)

                else
                    let $wrapped := <Version revision='0' start='{$start}'>{ $event }</Version>
                    return db:put($currentDB, $wrapped, $filename)
};

declare %updating function ver:hide_event(
    $dbname as xs:string,
    $filename as xs:string,
    $erase as xs:string
) {
    let $start := current-dateTime()
    return
        if (not(se:get-history()) or $erase = 'true') then
            db:delete($dbname, $filename)
        else
            let $doc := db:get($dbname, $filename)
            let $current := $doc/Version[1]
            return
                if (empty($current)) then
                    fn:error(xs:QName('err:nodata'), '204')
                else if (exists($current/@endDate)) then
                    fn:error(xs:QName('err:nodata'), '204')
                else
                    insert node attribute endDate { $start } into $current
};


declare %updating function ver:delete(
    $dbname as xs:string,
    $filename as xs:string,
    $erase as xs:string
) {
    let $available := fn:doc-available($dbname || "/" || $filename)
    return
        if ($available) then
            if (not(se:get-history()) or $erase = 'true') then
                db:delete($dbname, $filename)
            else
                ver:hide_event($dbname, $filename, $erase)
        else
            fn:error(xs:QName('err:nodata'), '204')
};

(: TODO create a function to remove in mass from a given provider :)
declare %updating function  ver:delete_in_mass($dbname as xs:string, $provider as xs:string, $erase as xs:string){
let $_:= lo:debug("delete_in_mass dbname: " || $dbname || " provider: " || $provider || " erase: " || $erase )
return ()
};

(:~ @return true if the QuakeML can be safely put in db
:)
declare function ver:validate_before_put() as xs:boolean{
    true()
};

(:~ @return
:)
declare function ver:get_collections() as xs:string {
    let $dbnames:=se:get-dbnames()
    return string-join( for $i in $dbnames return 'collection("' || $i || '")' , ',')
};

(:~ @return
:)
declare function ver:get_databases_info() as node() {
    in:get-info()
};

(:TODO optimize after EventDBInfo removal:)
(:TODO optimize after EventDBInfo removal:)
declare function ver:get_collections_from_index($index as xs:string) as xs:string {

    let $_:= lo:debug("get_collections_from_index, looking for event with index: " || $index  )

    let $dbnames:= ((# db:enforceindex #) {
             for $dbname in  in:get-dbnames()
                   let $found_index:= index:attributes(   $dbname,  '', true() )/text()[.=$index]
(:let $found_index:= index:attributes(   $dbname,  'publicID', true() )/text()[fn:encode-for-uri(.)=$index]                   :)
                   let $_ := if (not(fn:empty($found_index))) then lo:log("Found in " || $dbname) else lo:log("Not found in " || $dbname)
                   where not(fn:empty($found_index))

                   return $dbname})[1]
    let $_ := lo:log("Names" || fn:string-join($dbnames) )
    return string-join( for $i in $dbnames return 'collection("' || $i || '")' , ',')
};

