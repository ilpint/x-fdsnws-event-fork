(:~
 : Catalogs module.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace cata='http://webservices.ingv.it/fdsnws/event/modules/catalogs';

import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settings.xqm';

declare copy-namespaces no-preserve, inherit;

declare function cata:get_catalogs() as node(){
(:  let $_:= lo:log('cont:get_catalogs()'):)
(:  return:)
  <Catalogs>
  {
  for $catalog in se:get-catalogs()
  return <Catalog>{$catalog}</Catalog>
  }
  </Catalogs>
};

