(:~
 : Settings module.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings';
import module namespace functx = 'http://www.functx.com';
(: import module namespace json='http://basex.org/modules/json'; :)
import module namespace co='http://webservices.ingv.it/fdsnws/utils/commons' at '../../utils/commons.xqm';

declare variable $se:settings_doc := fn:doc( $co:repo || '/it/ingv/webservices/fdsnws/config/settings.xml');
declare variable $se:settings := se:load_settings_doc($se:settings_doc);

declare function se:get_settings() as document-node()?{
    $se:settings_doc
};

declare function se:load_settings_doc($doc_settings as document-node()?) as map(*) {
 map:merge(
 for $elem in $doc_settings/*:settings/*
       return map { $elem/name() : $elem/text() }
     )
};

declare function se:boolean( $param as xs:string ) as xs:boolean {
switch (fn:lower-case($param))
    case 'true'  return true()
    case 'false' return false()
    default return false()
};

declare function se:get-agencyID() as xs:string {
  $se:settings('agencyID')
};


declare function se:get-module() as xs:string{
  $se:settings('module')
};

declare function se:get-history() as xs:boolean{
  se:boolean($se:settings('history'))
};

declare function se:get-enable_log() as xs:boolean{
  se:boolean($se:settings('enable_log'))
};

declare function se:get-enable_debug() as xs:boolean{
    se:boolean($se:settings('enable_debug'))
};

declare function se:get-enable_query_log() as xs:boolean{
  se:boolean($se:settings('enable_query_log'))
};

declare function se:get-enable_handle_check() as xs:boolean{
  se:boolean($se:settings('enable_handle_check'))
};

declare function se:get-publicID_format() as xs:string{
  $se:settings('publicID_format')
};

declare function se:get-results_limit() as xs:int {
  xs:int($se:settings('results_limit'))
};
(:dbnames: names of possible database where is possible to write with PUT:)
declare function se:get-dbnames() as xs:string+{
  fn:tokenize($se:settings('dbnames') , ',')
};

declare function se:get-dbname() as xs:string{
  se:get-dbnames()[1]
};

(:Prefix of the names of databases where is possible to read:)
declare function se:get-database_name_prefix() as xs:string{
  $se:settings('database_name_prefix')
};

declare function se:get-resource-base() as xs:string{
  $se:settings('resource_base')
};

declare function se:get-contributors() as xs:string+{
  fn:tokenize($se:settings('contributors') , ',')
};

declare function se:get-catalogs() as xs:string+{
  fn:tokenize($se:settings('catalogs') , ',')
};

declare function se:get-catalogs_prefix() as xs:string{
  $se:settings('catalogs_prefix')
};

declare function se:invalid_settings($k as xs:string) as empty-sequence() {
fn:error(xs:QName('err:parameters'), 'Cannot apply invalid setting: ' || $k)
};

declare function se:set-settings($body as document-node()?){
  try {

    let $doc:=document{$body}
    let $map := se:load_settings_doc($doc)

    (: let $current:= $se:settings :)
    (: let $log := lo:log('set-settings') :)
    let $_ := (
      for $k in map:keys($map)
        (:        let $log:= message("key " || $k || " " || map:get($map , $k)):)
        let $ok:=
            switch ($k)
               case 'enable_log' return if (map:get($map , $k)=fn:true() or map:get($map , $k)=fn:false() ) then 0 else se:invalid_settings($k)
               case 'enable_debug' return if (map:get($map , $k)=fn:true() or map:get($map , $k)=fn:false() ) then 0 else se:invalid_settings($k)
               case 'enable_query_log' return if (map:get($map , $k)=fn:true() or map:get($map , $k)=fn:false() ) then 0 else se:invalid_settings($k)
               case 'agencyID' return 0
               case 'module' return 0
               case 'history' return if (map:get($map , $k)=fn:true() or map:get($map , $k)=fn:false() ) then 0 else se:invalid_settings($k)
               case 'enable_handle_check' return if (map:get($map , $k)=fn:true() or map:get($map , $k)=fn:false() ) then 0 else se:invalid_settings($k)
               case 'publicID_format' return 0
               case 'database_name_prefix' return 0
               case 'results_limit' return if (functx:is-a-number(map:get($map , $k))) then 0 else se:invalid_settings($k)
               case 'dbnames' return 0
               case 'resource_base' return 0
               case 'contributors' return 0
               case 'catalogs' return 0
               case 'catalogs_prefix' return 0
               default return se:invalid_settings($k)
        return $ok
    )
    return
        (: TODO merge input settings with previous, permits to accept partial input files :)
        file:write($co:repo || '/it/ingv/webservices/fdsnws/config/settings.xml', $doc)
    }
    catch err:FORG0001 {
        fn:error(xs:QName('err:parameters'), 'Cannot apply invalid settings: ' || $err:description)
    }
    catch err:* {
       fn:error(xs:QName('err:parameters'), 'Cannot apply invalid settings!' )
    }

};
