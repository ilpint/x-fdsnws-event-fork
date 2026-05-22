(:~
 : settings test module
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace test_settings='http://webservices.ingv.it/fdsnws/test/test_settings';

import module namespace se = "http://webservices.ingv.it/fdsnws/event/modules/settings"
    at "../event/modules/settings.xqm";


declare variable $test_settings:settings:= document {
    <settings>
        <agencyID>INGV</agencyID>
        <enable_log>true</enable_log>
        <enable_debug>false</enable_debug>
        <enable_query_log>true</enable_query_log>
        <results_limit>10</results_limit>
        <dbnames>events_db,archive_db</dbnames>
    </settings>
};

declare variable $test_settings:settings2:= document {
    <settings>
        <agencyID>INGV</agencyID>
        <enable_log>true</enable_log>
        <enable_debug>false</enable_debug>
        <enable_query_log>true</enable_query_log>
        <results_limit>10</results_limit>
        <dbnames>archive_db,events_db</dbnames>
    </settings>
};

declare variable $test_settings:saved_settings_document_node := document { se:get_settings()/* };

declare %unit:before-module %updating function test_settings:setup() {
    let $_:=se:set-settings($test_settings:settings)
    (: let $_:=se:set-settings($test_settings:saved_settings_document_node) :)
    
    return ()
};

(: Apparently this is not applied :)

declare %unit:after-module function test_settings:teardown() {
    let $_:=se:set-settings($test_settings:saved_settings_document_node)
    return ()
};

declare %unit:test function test_settings:test_load() {
    let $doc := document {
    <settings>
        <agencyID>INGV</agencyID>
        <enable_log>true</enable_log>
        <results_limit>7</results_limit>
        <dbnames>db1,db2</dbnames>
    </settings>
    }
let $m := se:load_settings_doc($doc)
let $t1 := unit:assert($m('agencyID') = 'INGV', 'load_settings_doc: agencyID')
let $t2 := unit:assert($m('enable_log') = 'true', 'load_settings_doc: enable_log as text')
let $t3 := unit:assert($m('results_limit') = '7', 'load_settings_doc: results_limit')
let $t4 := unit:assert(fn:tokenize($m('dbnames'), ',')[1] = 'db1', 'load_settings_doc: dbnames tokenization')
let $t5 := unit:assert(fn:tokenize($m('dbnames'), ',')[2] = 'db2', 'load_settings_doc: dbnames tokenization 2')
return ( $t1, $t2, $t3, $t4, $t5 )
};

declare %unit:test function test_settings:test_boolean() {
(: Test se:boolean behaviour:)
let $b1 := unit:assert(se:boolean('TRUE') = true(), 'boolean(): TRUE -> true')
let $b2 := unit:assert(se:boolean('false') = false(), 'boolean(): false -> false')
let $b3 := unit:assert(se:boolean('unknown') = false(), 'boolean(): unknown -> false')
let $errTest :=
    try {
        se:invalid_settings('some_bad_key'),
        fn:error(xs:QName('test:fail'), 'se:invalid_settings did not raise')
    } catch * {
        'se:invalid_settings raised as expected'
    }
return ( $b1, $b2, $b3, $errTest )
};


declare %unit:test function test_settings:test_get-dbnames() {

(: let $_:= message("test_get-dbnames") :)
let $b1 := unit:assert(se:get-dbnames()[1] = 'events_db', 'get-dbnames(): first dbname is events_db' )
let $b2 := unit:assert(se:get-dbnames()[2] = 'archive_db', 'get-dbnames(): second dbname is archive_db')
return ( $b1, $b2 )
};

declare %unit:test %updating function test_settings:after() {
    let $_:=se:set-settings($test_settings:saved_settings_document_node)
    let $_:=unit:assert(true(), 'restore saved settings' )
    return ()

};