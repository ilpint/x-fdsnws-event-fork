xquery version "3.1";
module namespace lo="http://webservices.ingv.it/fdsnws/utils/log";
import module namespace se="http://webservices.ingv.it/fdsnws/event/modules/settings" at '../event/modules/settings.xqm';

declare function lo:debug($message){
    if (se:get-enable_debug()) then message('debug: ' || $message)
};

declare function lo:log($message){
    if (se:get-enable_log()) then message( $message)
};

declare function lo:query-log($message){
    if (se:get-enable_query_log()) then message( $message )
};
