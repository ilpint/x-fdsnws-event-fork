(:~
 : Management module.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version '3.1';
module namespace ma='http://webservices.ingv.it/fdsnws/event/modules/management';
(: import module namespace functx = 'http://www.functx.com'; :)
(: import module namespace co='http://webservices.ingv.it/fdsnws/utils/commons' at '../../utils/commons.xqm'; :)
(: import module namespace lo='http://webservices.ingv.it/fdsnws/utils/log' at '../../utils/log.xqm'; :)
(: import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settingx.xqm'; :)
import module namespace in='http://webservices.ingv.it/fdsnws/event/modules/index' at 'index.xqm';


declare %updating function ma:make_event_index(){
(:    try {:)
        in:make_event_index()
(:    }:)
(:    catch err:* {:)
(:       fn:error(xs:QName('err:parameters'), 'Cannot create eventID index'):)
(:    }:)

(:  in:index_reset(),:)
(:  in:index_populate():)
};
