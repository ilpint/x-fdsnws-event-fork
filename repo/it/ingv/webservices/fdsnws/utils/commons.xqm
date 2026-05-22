xquery version "3.1";
module namespace co="http://webservices.ingv.it/fdsnws/utils/commons";
import module namespace Session = 'http://basex.org/modules/session';
(: import module namespace lo="http://webservices.ingv.it/fdsnws/station/modules/log"; :)
declare namespace ingv="https://raw.githubusercontent.com/FDSN/StationXML/master/fdsn-station.xsd";

(:
Commonalities
:)

declare variable $co:repo := '/srv/basex/repo';


declare function co:version() as xs:string {
  '1.1.60'
};

declare function co:authorize() as node()? {
  (: let $user := Session:get('id') :)

  let $header := request:header( 'Authorization',   ''  )
(:  let $log:=lo:log('checked auth '|| $header):)
  let $tokens := fn:tokenize($header)
  let $b64:= $tokens[2]
(:  let $log:=lo:log('parsed b64 '|| $b64):)
  let $userpass := bin:decode-string(xs:base64Binary($b64),'UTF-8')
(:  let $log:=lo:log('parsed auth '|| $userpass):)
  let $up:= fn:tokenize($userpass,':')
  let $name := $up[1]
  let $pass := $up[2]
  (: let $log:=lo:log('username: ' || fn:substring($name, 1,1) || '***' || ' password: ****') :)
  let $ok :=
    try {
    user:check($name, $pass)
  } catch * {
    (: login fails: no session info is set :)
    fn:error(xs:QName('err:unauthorized'), 'Failed authentication'  )
  }

  return if ($ok) then  ()
};

(: Toggle only the trailing Z; preserve fractional seconds exactly :)
declare function co:toggle-z(
  $lexical as xs:string,
  $want-z  as xs:boolean
) as xs:string {
  let $no-tz := replace($lexical, '(Z|[+\-]\d{2}:\d{2})$', '')
  return if ($want-z) then concat($no-tz, 'Z') else $no-tz
};
