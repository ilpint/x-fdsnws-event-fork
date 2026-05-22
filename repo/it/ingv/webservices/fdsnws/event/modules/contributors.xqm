(:~
 : Contributors module.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version '3.1';
module namespace cont='http://webservices.ingv.it/fdsnws/event/modules/contributors';

import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settings.xqm';


declare copy-namespaces no-preserve, inherit;

declare function cont:get_contributors() as node() {
(:  let $_:= lo:log('cont:get_contributors()'):)
(:  return:)
  <Contributors>
  {
  for $contributor in se:get-contributors()
  return <Contributor>{$contributor}</Contributor>
  }
  </Contributors>
};
