(:~
 : Application module, wadl customization functions.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsnws-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace ap='http://webservices.ingv.it/fdsnws/event/modules/application';
(: import module namespace ve='http://webservices.ingv.it/fdsnws/event/modules/version'; :)
(: import module namespace lo='http://webservices.ingv.it/fdsnws/utils/log' at '../../utils/log.xqm';:)
(: import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settings.xqm'; :)

import module namespace co='http://webservices.ingv.it/fdsnws/utils/commons' at '../../utils/commons.xqm';
import module namespace sy='http://webservices.ingv.it/fdsnws/event/modules/style' at 'style.xqm';

declare default element namespace 'http://quakeml.org/xmlns/quakeml/1.2';
declare copy-namespaces no-preserve, inherit;

(:~
 : @return xml wadl, personalized using wadl style
:)
declare function ap:get_application_wadl() as node(){
  xslt:transform( fn:doc( $co:repo || '/it/ingv/webservices/fdsnws/event/resources/application-wadl.xml'), $sy:application_wadl_style )
};

(:~
 : @return html root application
:)
declare function ap:get_application_root() as node(){
  xslt:transform( ap:get_application_wadl(), $co:repo || '/it/ingv/webservices/fdsnws/event/resources/wadl.xsl' )
};

(:~
 : @return JSON application
:)
declare function ap:get_application_json() as xs:string{
  json:serialize(json:doc( $co:repo || '/it/ingv/webservices/fdsnws/event/resources/application-Swagger20.json'))
};
