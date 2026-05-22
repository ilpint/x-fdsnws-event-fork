xquery version "3.1";
module namespace ha="http://webservices.ingv.it/fdsnws/utils/handle";

declare function ha:handle_to_identifier_type($handle as xs:string){
(:    let $log := log('handle_to_identifier_type ' || $handle):)
    let $token_seq:= fn:tokenize($handle,"/")
    let $type:=fn:upper-case($token_seq[1])
    return if ($type='HANDLE') then $type else fn:error(xs:QName('err:parameters'), 'Identifier request malformed' )

};

declare function ha:handle_to_identifier_value($handle as xs:string){

    let $value:=fn:substring-after($handle,"/")
    let $value:=fn:substring-before($value, "?urlappend")
    return $value

};

declare function ha:handle_to_identifier_version($handle as xs:string){

    let $value:=fn:substring-after($handle,"version=")
    return if (fn:number($value) or $value="" or $value="0") then $value else fn:error(xs:QName('err:parameters'), 'Identifier request malformed' || $value )

};
(:FIXME: should change handle returned?:)
declare function ha:identifier_to_handle( $identifier  as node()?) as xs:string*{
    for $i in $identifier
        let $identifier_station := $i
        let $identifier_type := $identifier_station/@type
        let $identifier_value := if ($identifier_type='HANDLE') then $identifier_station/text()
        let $identifier_version := fn:substring-after($identifier_value[1],'version=')
        let $handle := if ($identifier_type='HANDLE') then $identifier_value[1] else ()
(:        let $log := fn:log("identifier_to_handle HANDLE: " || $handle ):)
    return $handle
};

declare function ha:handle_check_duplicates($identifier, $stacode, $netcode, $netstartDate ){
    for $handle in ha:identifier_to_handle($identifier)
(:        let $log := log('handle_check_duplicates looking for next handle: ' || $handle):)
        let $check:=ha:find_incompatible_station('HANDLE/'||$handle, $stacode, $netcode, $netstartDate)
    return if (not(fn:empty($check))) then fn:error(xs:QName('err:identifier'), 'handle identifier with the same version is in use' ) else true()

};

    (: Search for handle
      1) handle should be only in one file
         a. PID requested with version, exact match, to search in every Version
         b. PID requested without version, exact match in higher Version

      2) when there are multiple results the database was corrupted and should raise an error

    :)
declare function ha:query_station_by_handle($handle as xs:string) as element()*{
(:    let $log :=fn:log("query_station_by_handle Passed: " || $handle):)
    let $type:= ha:handle_to_identifier_type($handle)
    let $value:= ha:handle_to_identifier_value($handle)
    let $idversion:=ha:handle_to_identifier_version($handle)
    let $idtext:= fn:substring-after($handle,fn:lower-case($type)||"/")
(:    let $log :=fn:log("Queried: type=" || $type || " value=" || $value  || " version=" || $idversion):)
(:    let $log :=fn:log("Read: idtext=" || $idtext):)
    let $result:= if ($idversion!="") then (
        let $collection := db:get("Station-db",'/')/*:Version/*:FDSNStationXML
(:        let $log :=fn:log("Looking with no limits for version " || $idversion):)
        for $doc in $collection
            let $identifierstation := $doc//*:Station/*:Identifier
            let $identifiertype := $identifierstation/@type
            let $identifiervalue := $identifierstation/text()
            let $identifierversion := fn:substring-after($identifiervalue[1],'version=')
(:            let $log := fn:log("Type: "||$identifiertype[1] || " value: " || $identifiervalue[1] || " v: " || $identifierversion[1]):)
        where ($type=$identifiertype) and ( $identifiervalue = $idtext )
        order by $doc/../Version/@revision descending
        return $doc
    )
    else (
        (:looking in Version[1] for the latest version:)
        let $collection := db:get("Station-db",'/')/*:Version[1]/*:FDSNStationXML/*:Network/*:Station/*:Identifier[matches(., $value)]/../../..
(:        let $log :=fn:log("Looking for version" || $idversion):)
        for $doc in $collection
            let $identifierstation := $doc//*:Station/*:Identifier
            let $identifiertype := $identifierstation/@type
            let $identifiervalue := $identifierstation/text()
            let $identifierversion := fn:substring-after($identifiervalue[1],'version=')
(:            let $log := fn:log("Type: "||$identifiertype[1] || " value: " || $identifiervalue[1] || " v: " || $identifierversion[1]):)
        where ($type=$identifiertype)
        order by $doc/../Version/@revision descending
        return $doc
    )
    return if ( count($result)> 1 ) then
        fn:error(xs:QName('err:inconsistency'), 'Check database for duplicate handles in:

        ' ||

        $result[1]//*:Station[1]/@code || " " || $result[1]//*:Station[1]/*:Identifier[1] || '
        ' ||

        $result[2]//*:Station[1]/@code || " " || $result[2]//*:Station[1]/*:Identifier[1]
      )
    else $result
};

declare function ha:find_incompatible_station_by_handle($handle as xs:string) as element()*{
(:    let $log :=fn:log("check_station_by_handle Passed: " || $handle):)
    let $type:= ha:handle_to_identifier_type($handle)
    let $value:= ha:handle_to_identifier_value($handle)
    let $idversion:=ha:handle_to_identifier_version($handle)
    let $idtext:= fn:substring-after($handle,fn:lower-case($type)||"/")
(:    let $log :=fn:log("Queried: type=" || $type || " value=" || $value  || " version=" || $idversion):)
(:    let $log :=fn:log("Read: idtext=" || $idtext):)
    let $result:= if ($idversion!="") then (
        let $collection := db:get("Station-db",'/')/*:Version/*:FDSNStationXML
(:        let $log :=fn:log("Looking with no limits for version " || $idversion):)
        for $doc in $collection
            let $identifierstation := $doc//*:Station/*:Identifier
            let $identifiertype := $identifierstation/@type
            let $identifiervalue := $identifierstation/text()
            let $identifierversion := fn:substring-after($identifiervalue[1],'version=')
(:            let $log := fn:log("Type: "||$identifiertype[1] || " value: " || $identifiervalue[1] || " v: " || $identifierversion[1]):)
        where ( ($identifiervalue[1] = $value || '?urlappend=%3Fversion=' || $idversion) or ( fn:starts-with($identifiervalue[1],$value) and $identifierversion[1]>$idversion))
        return $doc
    )
    return if ( count($result)> 0 ) then
        fn:error(xs:QName('err:identifier'), 'handle identifier already in use' )
    else $result
};

declare function ha:find_incompatible_station($handle as xs:string, $stacode as xs:string, $netcode as xs:string , $netstartDate as xs:dateTime) as element()*{
(:    let $log :=fn:log("check_station_by_handle Passed: " || $handle):)
    let $type:= ha:handle_to_identifier_type($handle)
    let $value:= ha:handle_to_identifier_value($handle)
    let $idversion:=ha:handle_to_identifier_version($handle)
    let $idtext:= fn:substring-after($handle,fn:lower-case($type)||"/")
(:    let $log :=fn:log("Queried: type=" || $type || " value=" || $value  || " version=" || $idversion):)
(:    let $log :=fn:log("Read: idtext=" || $idtext):)
    let $handle-in-use:= if ($idversion!="") then (
        let $collection := db:get("Station-db",'/')/*:Version/*:FDSNStationXML
(:        let $log :=fn:log("Looking with no limits for version " || $idversion):)
        for $doc in $collection
            for $station_doc in $doc//*:Station
                let $identifierstation := $station_doc/*:Identifier
                let $code_station := $station_doc/@code
                let $code_net := $station_doc/../@code
                let $startDate_net := $station_doc/../@startDate
                let $sta_open := not(if ($station_doc/@endDate and $station_doc/@endDate < current-dateTime() ) then fn:true() else fn:false())
(:                let $log := log('station ' || $code_station || $sta_open):)
                let $identifiertype := $identifierstation/@type
                let $identifiervalue := $identifierstation/text()
                let $identifierversion := fn:substring-after($identifiervalue[1],'version=')
(:                let $log := fn:log("Type: "||$identifiertype[1] || " value: " || $identifiervalue[1] || " v: " || $identifierversion[1]):)
        where (
                (: same handle-version :)
                ($identifiervalue[1] = $value || '?urlappend=%3Fversion=' || $idversion)
                or
                (: new handle does not increase version :)
                ( fn:starts-with($identifiervalue[1],$value) and $identifierversion[1]>=$idversion)
                or
                (: same handle in another open station:)
                 (( fn:starts-with($identifiervalue[1],$value ) and $identifierversion[1]<$idversion) and
                 (($code_station!=$stacode or $code_net!=$netcode or $startDate_net!=$netstartDate) and
                 $sta_open ))
              )
        return $doc
    )
    let $tuple-in-use:= if ($idversion!="") then (
        let $collection := db:get("Station-db",'/')/*:Version/*:FDSNStationXML
(:        let $log :=fn:log("Looking with no limits for version " || $idversion):)
        for $doc in $collection
            for $network in $doc/*:Network
                for $station in $network/*:Station
                    let $net_code := $network/@code
                    let $sta_code := $station/@code
                    let $net_startDate := $network/@startDate
                    let $identifierstation := $station/*:Identifier
                    let $identifiertype := $identifierstation/@type
                    let $identifiervalue := $identifierstation/text()
                    let $identifierversion := fn:substring-after($identifiervalue[1],'version=')
(:                    let $log := fn:log("Type: "||$identifiertype[1] || " value: " || $identifiervalue[1] || " v: " || $identifierversion[1]):)
                where ( $net_code=$netcode and $sta_code=$stacode and $net_startDate=$netstartDate and not((fn:starts-with($identifiervalue[1],$value) and $identifiertype=$type)) )
        return $doc
    )
    return
        if ( count($handle-in-use)> 0 ) then
            fn:error(xs:QName('err:identifier'), 'handle identifier already in use' )
        else
            if ( count($tuple-in-use)> 0 ) then
                fn:error(xs:QName('err:identifier'), 'different handle identifier is used by station ' || $stacode )
            else
            $handle-in-use
};