(:~
 : ingv_bulletin module, utilities and definitions.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsn-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace ib='http://webservices.ingv.it/fdsnws/event/modules/ingv_bulletin';
import module namespace ver='http://webservices.ingv.it/fdsnws/event/modules/version' at 'version.xqm';
import module namespace se='http://webservices.ingv.it/fdsnws/event/modules/settings' at 'settings.xqm';
import module namespace lo='http://webservices.ingv.it/fdsnws/utils/log' at '../../utils/log.xqm';
import module namespace functx = 'http://www.functx.com';
import module namespace map='http://www.w3.org/2005/xpath-functions/map';


declare default element namespace 'http://quakeml.org/xmlns/quakeml/1.2';
declare namespace q = "http://quakeml.org/xmlns/quakeml/1.2";


declare copy-namespaces no-preserve, inherit;

declare %public variable $ib:defaults :=map {
"author":"BULLETIN-INGV"
};

(: ----------------- helpers: padding & formatting ----------------- :)

(:~
 : Right-pad a string with spaces to a fixed width.
 :
 : @param $s    Input string (optional).
 : @param $len  Target length.
 : @return Padded or truncated string of length $len.
 :)
declare function ib:rpad($s as xs:string?, $len as xs:integer) as xs:string {
  let $x := string($s)
  return if (string-length($x) ge $len)
         then substring($x, 1, $len)
         else $x || string-join(for $i in 1 to ($len - string-length($x)) return " ", "")
};

(:~
 : Left-pad a string with a given character to a fixed width.
 :
 : @param $s    Input string (optional).
 : @param $len  Target length.
 : @param $ch   Padding character.
 : @return Padded or truncated string of length $len.
 :)
declare function ib:lpad($s as xs:string?, $len as xs:integer, $ch as xs:string) as xs:string {
  let $x := string($s)
  return if (string-length($x) ge $len)
         then substring($x, 1, $len)
         else string-join(for $i in 1 to ($len - string-length($x)) return $ch, "") || $x
};

(:~
 : Format seconds and fractional seconds as SS.ff (width 5).
 :
 : @param $dt  DateTime to format.
 : @return Seconds of minute, padded to width 5.
 :)
declare function ib:fmt_ssff($dt as xs:dateTime) as xs:string {
  let $sec := xs:decimal(format-dateTime($dt, "[s]")) +
              xs:decimal("0." || format-dateTime($dt, "[f]"))
(:return ib:lpad(format-number($sec, "00.00"), 5, " ")              :)
  return ib:lpad(format-number($sec, "00.00"), 5, " ")
};
(: S seconds referenced to P minute (can be > 60 when minute rolls over) :)
(:~
 : Format S arrival seconds referenced to the P minute.
 :
 : @param $pdt  P pick time.
 : @param $sdt  S pick time.
 : @return Seconds since the P minute (width 5).
 :)
declare function ib:fmt_s_from_p_minute($pdt as xs:dateTime, $sdt as xs:dateTime) as xs:string {
  let $base :=
    xs:dateTime(
      format-dateTime($pdt, "[Y0001]-[M01]-[D01]T[H01]:[m01]:00.00")
    )
  let $secs := xs:decimal( ($sdt - $base) div xs:dayTimeDuration("PT1S") )
  return ib:lpad(format-number($secs, "00.00"), 5, " ")
};

(:~
 : Format datetime as yymmddHHmmSSff (Hypo71 style).
 :
 : @param $dt  DateTime to format.
 : @return Compact datetime string.
 :)
declare function ib:fmt_p_datetime_yyMMddHHmmSSff($dt as xs:dateTime) as xs:string {
  let $yy := format-dateTime($dt, "[Y00]")
  let $mo := format-dateTime($dt, "[M01]")
  let $dd := format-dateTime($dt, "[D01]")
  let $hh := format-dateTime($dt, "[H01]")
  let $mi := format-dateTime($dt, "[m01]")
  let $ss := ib:fmt_ssff($dt)
  return $yy || $mo || $dd || $hh || $mi || $ss
};

(:~
 : Format a decimal value as F5.2 with left padding.
 :
 : @param $x  Value to format.
 : @return Width-5 string, blank if empty.
 :)
declare function ib:fmt_f5_2($x as xs:decimal?) as xs:string {
  if (empty($x)) then "     "
  else ib:lpad(format-number($x, "0.00"), 5, " ")
};

(: seconds-of-minute for S pick: "55.00" (width 5) :)
(:~
 : Format seconds-of-minute for an S pick.
 :
 : @param $dt  DateTime to format.
 : @return Seconds-of-minute string (width 5).
 :)
declare function ib:fmt_sec_of_minute($dt as xs:dateTime) as xs:string {
  ib:fmt_ssff($dt)
};

(:~
 : Format seconds-of-minute as SS.ssss (width 7).
 :
 : @param $dt  DateTime to format.
 : @return Seconds-of-minute string (width 7).
 :)
declare function ib:fmt_sec7_4($dt as xs:dateTime) as xs:string {
  let $sec := xs:decimal(format-dateTime($dt, "[s]")) +
              xs:decimal("0." || format-dateTime($dt, "[f]"))
  return ib:lpad(format-number($sec, "0.0000"), 7, " ")
};

(:~
 : Normalize a number for scientific notation.
 :
 : @param $v    Value to normalize.
 : @param $exp  Current exponent.
 : @return Map with mantissa and exponent.
 :)
declare function ib:norm_exp($v as xs:decimal, $exp as xs:integer) as map(*) {
  let $abs := abs($v)
  return
    if ($v = 0) then map { "mant": xs:decimal(0), "exp": 0 }
    else if ($abs >= 10) then ib:norm_exp($v div 10, $exp + 1)
    else if ($abs < 1) then ib:norm_exp($v * 10, $exp - 1)
    else map { "mant": $v, "exp": $exp }
};

(:~
 : Format a decimal as expFloat*9.2 for NLL output.
 :
 : @param $x  Value to format.
 : @return Width-9 expFloat string, -1.00e+00 if empty.
 :)
declare function ib:fmt_exp9_2($x as xs:decimal?) as xs:string {
  let $v := if (empty($x)) then xs:decimal(-1) else $x
  let $norm := ib:norm_exp($v, 0)
  let $mant := $norm?mant
  let $exp := $norm?exp
  let $mantStr := format-number($mant, "0.00")
  let $expAbs := abs($exp)
  let $expStr := ib:lpad(string($expAbs), 2, "0")
  let $expSign := if ($exp ge 0) then "+" else "-"
  let $s := $mantStr || "e" || $expSign || $expStr
  return ib:lpad($s, 9, " ")
};

(:~
 : Map first-motion polarity to phase code.
 :
 : @param $pol  Polarity string.
 : @return "U" for positive, "D" for negative, blank otherwise.
 :)
declare function ib:first_motion($pol as xs:string?) as xs:string {
  let $p := lower-case(normalize-space(string($pol)))
  return
    if ($p = "positive") then "U"
    else if ($p = "negative") then "D"
    else " "
};


(:~
 : Convert pick uncertainty into weight class.
 :
 : @param $pu  Pick uncertainty.
 : @param $lu  Lower uncertainty.
 : @param $uu  Upper uncertainty.
 : @return Weight code "0".."4" or "8".
 :)
declare function ib:weight_from_pickUncertainty($pu as xs:string?, $lu as xs:string, $uu as xs:string) as xs:string {
  let $w := try { xs:decimal(normalize-space($pu)) } catch * { xs:decimal(normalize-space($lu)) + xs:decimal(normalize-space($uu)) }

  return
    if (empty($w)) then " "
    else if ($w le 0.1)  then "0"
    else if ($w le 0.3)  then "1"
    else if ($w le 0.6)  then "2"
    else if ($w le 1.0)  then "3"
    else if ($w le 3.0)  then "4"
    else "8"
};

(:~
 : Extract pick uncertainty (seconds) from a pick element.
 :
 : @param $pick  Pick element.
 : @return Uncertainty in seconds or empty.
 :)
declare function ib:pick_uncertainty_seconds($pick as element()) as xs:decimal? {
  let $u := normalize-space(string($pick/*:time/*:uncertainty))
  let $lu := normalize-space(string($pick/*:time/*:lowerUncertainty))
  let $uu := normalize-space(string($pick/*:time/*:upperUncertainty))
  let $uval := if ($u != "") then try { xs:decimal($u) } catch * { () } else ()
  let $luval := if ($lu != "") then try { xs:decimal($lu) } catch * { () } else ()
  let $uuval := if ($uu != "") then try { xs:decimal($uu) } catch * { () } else ()
  return
    if (exists($uval)) then $uval
    else if (exists($luval) or exists($uuval)) then
      (if (exists($luval) and exists($uuval)) then $luval + $uuval else ($luval, $uuval)[1])
    else ()
};

(:~
 : Parse a decimal from a string.
 :
 : @param $s  Value string.
 : @return Decimal or empty.
 :)
declare function ib:to_decimal($s as xs:string?) as xs:decimal? {
  let $t := normalize-space(string($s))
  return if ($t = "") then () else try { xs:decimal($t) } catch * { () }
};

(:~
 : Format a number with a fallback for empty values.
 :
 : @param $x        Value to format.
 : @param $pattern  format-number() pattern.
 : @param $fallback Fallback string when value is empty.
 : @return Formatted number or fallback.
 :)
declare function ib:fmt_num($x as xs:decimal?, $pattern as xs:string, $fallback as xs:string) as xs:string {
  if (empty($x)) then $fallback else format-number($x, $pattern)
};


(:~
 : Normalize a location code to two characters.
 :
 : @param $loc  Location code.
 : @return Two-character code or "--" when missing.
 :)
declare function ib:loc2($loc as xs:string?) as xs:string {
  let $x := normalize-space(string($loc))
  return if ($x = "") then "--" else substring($x, 1, 2)
};


(:~
 : Extract numeric id from a publicID or query string.
 :
 : @param $s  ID string.
 : @return Numeric suffix or original string.
 :)
declare function ib:idnum($s as xs:string?) as xs:string {
  let $x := normalize-space(string($s))
  return
    if (matches($x, "eventId=\d+")) then replace($x, ".*eventId=(\d+).*", "$1")
    else if (matches($x, "originId=\d+")) then replace($x, ".*originId=(\d+).*", "$1")
    else if (matches($x, "=(\d+)$")) then replace($x, ".*=(\d+)$", "$1")
    else $x
};

(:~
 : Read arrival time weight as integer for sorting.
 :
 : @param $a  Arrival element.
 : @return Weight as integer, or -999999 if missing.
 :)
declare function ib:tw_int($a as element()?) as xs:integer {
  if (empty($a)) then -999999
  else try { xs:integer(normalize-space(string($a/*:timeWeight))) } catch * { -999999 }
};

(: ----------------- pick/arrival linking ----------------- :)

(:~
 : Build a map from pick publicID to pick element.
 :
 : @param $event  QuakeML event.
 : @return Map of pick IDs to pick elements.
 :)
declare function ib:pick_map($event as element()) as map(*) {
  map:merge(for $p in $event/*:pick return map:entry(string($p/@publicID), $p))
};

(:~
 : Build a station key from a waveformID element.
 :
 : @param $w  waveformID element.
 : @return Key "STA|NET|LOC|CHA".
 :)
declare function ib:station_key_from_waveform($w as element()) as xs:string {
  string-join((
    string($w/@stationCode),
    string($w/@networkCode),
    string($w/@locationCode),
    string($w/@channelCode)
  ), "|")
};

(:~
 : Build a station key from a pick element.
 :
 : @param $p  Pick element.
 : @return Key "STA|NET|LOC|CHA".
 :)
declare function ib:station_key($p as element()) as xs:string {
  ib:station_key_from_waveform($p/*:waveformID)
};

(: ----------------- amplitude / stationMagnitude (Wood–Anderson) ----------------- :)

(:~
 : Build a map from amplitude publicID to amplitude element.
 :
 : @param $event  QuakeML event.
 : @return Map of amplitude IDs to amplitude elements.
 :)
declare function ib:amp_map($event as element()) as map(*) {
  map:merge(
    for $a in $event/*:amplitude
    return map:entry(string($a/@publicID), $a)
  )
};

(:~
 : Resolve a stationMagnitude to Wood-Anderson amplitude metrics.
 :
 : @param $sm       StationMagnitude element.
 : @param $ampById  Map of amplitude IDs to amplitude elements.
 : @return Map with mm_pp and period, or empty if not applicable.
 :)
declare function ib:wa_from_stationMag(
  $sm as element(),
  $ampById as map(*)
) as map(*)? {
  let $ampID := normalize-space(string($sm/*:amplitudeID))
  let $a := $ampById($ampID)
  where exists($a)

  (: --- keep only Wood–Anderson amplitudes (INGV convention) --- :)
  let $atype := lower-case(normalize-space(string($a/*:type)))
  let $cmt   := lower-case(string-join($a/*:comment/*:text, " "))
  let $author := string-join($a/*:creationInfo/*:author, " ")
  where ($author = $ib:defaults('author') ) and( ($atype = "aml") or contains($cmt, "wood-anderson"))

  let $unit := lower-case(normalize-space(string($a/*:unit)))
  let $g := normalize-space(string($a/*:genericAmplitude/*:value))
  let $p := normalize-space(string($a/*:period/*:value))
  let $val := try { xs:decimal($g) } catch * { () }
  let $per := try { xs:decimal($p) } catch * { () }

  (: convert to mm; INGV example shows unit=m then *1000 :)
  let $mm :=
    if (empty($val)) then ()
    else if ($unit = "m") then $val * 1000
    else if ($unit = "mm") then $val
    else $val

  (: INGV: peak-to-peak => *2 :)
  let $mm_pp := if (empty($mm)) then () else $mm * 2

  return map{
    "mm_pp": $mm_pp,
    "period": $per
  }
};


(:~
 : Extract Wood-Anderson amplitude metrics from an amplitude element.
 :
 : @param $amp      Amplitude element.
 : @param $ampById  Map of amplitude IDs to amplitude elements.
 : @return Map with mm_pp and period, or empty if not applicable.
 :)
declare function ib:wa_from_amplitudes(
  $amp as element(),
  $ampById as map(*)
) as map(*)? {

  let $a:=$amp
  let $_:=lo:debug("Chosen amplitudes " || count($amp)  )
  (: --- keep only Wood–Anderson amplitudes (INGV convention) --- :)
  let $atype  := lower-case(normalize-space(string($a/*:type)))
  let $cmt    := lower-case(string-join($a/*:comment/*:text, " "))
  let $author := string-join($a/*:creationInfo/*:author, " ")
  let $_ := lo:debug('Author read: ' || $author || " default: " || $ib:defaults('author')  )
  where ($author = $ib:defaults('author') ) and( ($atype = "aml") or contains($cmt, "wood-anderson"))

  let $unit := lower-case(normalize-space(string($a/*:unit)))
  let $g := normalize-space(string($a/*:genericAmplitude/*:value))
  let $p := normalize-space(string($a/*:period/*:value))
  let $val := try { xs:decimal($g) } catch * { () }
  let $per := try { xs:decimal($p) } catch * { () }

  (: convert to mm; INGV example shows unit=m then *1000 :)
  let $mm :=
    if (empty($val)) then ()
    else if ($unit = "m") then $val * 1000
    else if ($unit = "mm") then $val
    else $val

  (: INGV: peak-to-peak => *2 :)
  let $mm_pp := if (empty($mm)) then () else $mm * 2

  return map{
    "mm_pp": $mm_pp,
    "period": $per
  }
};

(:~
 : Aggregate Wood-Anderson amplitudes for a station and origin.
 :
 : Selects stationMagnitudes for the station, prefers those matching the pick
 : channel family, resolves amplitudes, filters Wood-Anderson (AML) values,
 : and computes mean peak-to-peak amplitude and period for E/N components.
 :
 : @param $event     QuakeML event.
 : @param $originID  Origin publicID.
 : @param $sta       Station code.
 : @param $net       Network code.
 : @param $loc       Location code.
 : @param $pickChan  Pick channel code.
 : @return Map with ampMean, perMean, and byChan (per-channel details).
 :)
declare function ib:wa_station_aggregate(
  $event as element(),
  $originID as xs:string,
  $sta as xs:string,
  $net as xs:string,
  $loc as xs:string,
  $pickChan as xs:string
) as map(*) {
  let $ampById := ib:amp_map($event)
(:  let $_:=lo:debug("ib:wa_station_aggregate: " || $sta || "|" ||   $net || "|" || $loc || "|" || $pickChan  ):)
  (: tutte le stationMagnitude della stazione (per quell’origin) :)
  let $sms :=
    for $sm in $event/*:stationMagnitude
    where normalize-space(string($sm/*:originID)) = $originID
      and normalize-space(string($sm/*:waveformID/@stationCode)) = $sta
      and normalize-space(string($sm/*:waveformID/@networkCode)) = $net
      and normalize-space(string($sm/*:waveformID/@locationCode)) = $loc
    return $sm


  (: --- filtro “famiglia” coerente con il canale pick: HH*, HN*, EH*, ... --- :)
  let $pref2 := substring(normalize-space($pickChan), 1, 2)
  let $accel := ("HN","BN","GN")

  (:Seleziono le stationmagnitudes corrispondenti al picking attenzione esistono anche più di una stationmagnitudes
    che usano la stessa ampiezza:)
  let $smsPref :=functx:distinct-nodes(
    for $sm in $sms
    let $ch := normalize-space(string($sm/*:waveformID/@channelCode))
    where starts-with($ch, $pref2)
    return $sm)

  let $smsAvoid :=functx:distinct-nodes(
    for $sm in $sms
    for $acc in $accel
    let $ch := normalize-space(string($sm/*:waveformID/@channelCode))
    where starts-with($ch, $acc)
    return $sm)

(:  let $_:=lo:debug("Avoid stationmagnitudes " || fn:string-join($smsAvoid/@publicID,' ')  ):)
(:  let $_:=lo:debug("Chosen stationmagnitudes " || fn:string-join($smsPref/@publicID,' ')  ):)
  (:Scelgo corrispondenti a canali piccati, gli altri se non ce ne sono:)

  let $smsUse := if (exists($smsPref)) then $smsPref else $sms

  let $_:= if (exists($smsPref)) then  lo:log("Chosen smspref " ) else  lo:log("Chosen sms ")
(:  let $_:=lo:debug("Chosen amplitudes " || fn:string-join($smsUse/*:amplitudeID/text())):)

  let $ids := fn:distinct-values($smsUse/*:amplitudeID/text())
  let $amps :=
    for $id in $ids
    let $ampid := normalize-space(string($id))
    let $amp := $ampById($ampid)
    where exists($amp)
(:    let $_:=lo:debug("Amplitude calculate average" || $ampid):)
    return $amp

  (:let $_:=lo:debug("Chosen amplitudes " || count($amps) ):)

  let $wa :=
    for $amp in $amps
      let $ch := normalize-space(string($amp/*:waveformID/@channelCode))
      let $cmp := substring($ch, 3, 1)
(:      let $_:=lo:log("Chosen amplitude channel " || fn:string-join($ch)  || " for " || $amp/@publicID ):)
    where $cmp = "E" or $cmp = "N"
    let $m := ib:wa_from_amplitudes($amp, $ampById)
    where exists($m?mm_pp)
    return map{
      "chan": $ch,
      "cmp": $cmp,
      "mm_pp": $m?mm_pp,
      "period": $m?period
    }

  let $idsa := fn:distinct-values($smsAvoid/*:amplitudeID/text())
  (:Refine $ids of accelerometers, removing them if already chosen:)
  let$ids := distinct-values($idsa[not(.=$ids)])

  let $amps :=
    for $id in $ids
    let $ampid := normalize-space(string($id))
    let $amp := $ampById($ampid)
    where exists($amp)
(:    let $_:=lo:debug("Amplitude - no calculate average" || $ampid):)
    return $amp

  let $acc :=
    for $amp in $amps
      let $ch := normalize-space(string($amp/*:waveformID/@channelCode))
      let $cmp := substring($ch, 3, 1)
(:      let $_:=lo:debug("Chosen amplitude component " || fn:string-join($cmp)  || " for " || $amp/@publicID ):)
    where $cmp = "E" or $cmp = "N"
    let $m := ib:wa_from_amplitudes($amp, $ampById)
    where exists($m?mm_pp)
    return map{
      "chan": $ch,
      "cmp": $cmp,
      "mm_pp": $m?mm_pp,
      "period": $m?period
    }

(:  Change this to calculate mean only for velocimeters :)
  let $vals := $wa?mm_pp
  let $pers := $wa?period

  let $ampMean := if (exists($vals)) then avg($vals) else ()
  let $perMean := if (exists($pers)) then avg($pers) else ()

  (:merge $wa and $acc:)
  let $wall := ($wa , $acc )
  return map{
    "ampMean": $ampMean,
    "perMean": $perMean,
    "byChan": $wall
  }
};


(:~
 : Format amplitude or period for 3-character field.
 :
 : @param $x  Value to format.
 : @return 3-character string or blanks.
 :)
declare function ib:fmt3($x as xs:decimal?) as xs:string {
  if (empty($x)) then "   "
  else if ($x lt 10) then format-number($x, "0.0")          (: 0.0 .. 9.9 :)
  else if ($x lt 100) then format-number($x, "00")          (: 10 .. 99 :)
  else format-number(round($x), "000")                      (: 100 .. 999 :)
};

(:~
 : Format amplitude/period block for output line.
 :
 : @param $ampMean  Mean amplitude (mm).
 : @param $perMean  Mean period (s).
 : @return Fixed-width block (6 chars).
 :)
declare function ib:fmt_amp_per_block($ampMean as xs:decimal?, $perMean as xs:decimal?) as xs:string {
  if (empty($ampMean) and empty($perMean)) then ib:rpad("", 6)
  else
    let $a := if (empty($ampMean)) then "   " else ib:fmt3($ampMean)
    let $p := if (empty($perMean)) then "  "  else ib:fmt3($perMean)
    return ib:rpad($a || $p, 6)
};

(:line part after comment with used amplitudes:)
(:~
 : Format tail section listing per-channel amplitudes.
 :
 : @param $waByChan  Sequence of maps with channel and mm_pp.
 : @return Comma-separated channel list or empty string.
 :)
declare function ib:fmt_tail_amplitudes($waByChan as map(*)*) as xs:string {
  let $items :=
    for $m in $waByChan
    let $ch := $m?chan
    let $v := $m?mm_pp
    let $s0 := format-number($v, "0.###")
    let $s  := replace($s0, "\.?0+$", "")
    order by $ch
    return $ch || ":" || $s
  return if (empty($items)) then "" else "," || string-join($items, ",")
};

(: ----------------- build one output line ----------------- :)

(:~
 : Build a single hypo71phs output line for a station.
 :
 : @param $event   QuakeML event.
 : @param $originSeq  Preferred origin sequence.
 : @param $key     Station key "STA|NET|LOC|CHA".
 : @param $pPick   P pick element.
 : @param $pArr    P arrival element (optional).
 : @param $sPick   S pick element (optional).
 : @param $sArr    S arrival element (optional).
 : @return Formatted line string.
 :)
declare function ib:build_line(
  $event as element(),
  $origin as element(),
  $key as xs:string,
  $pPick as element(),
  $pArr  as element()?,
  $sPick as element()?,
  $sArr  as element()?
) as xs:string {

  let $parts := tokenize($key, "\|")
  let $sta := $parts[1]
  let $net := $parts[2]
  let $loc := $parts[3]
  let $cha := $parts[4]

  let $sta4 := ib:rpad(substring($sta,1,4), 4) (:FIXME lpad?:)
  (: 5ª lettera stazione -> colonna 78 :)
  let $sta5 := if (string-length($sta) ge 5) then substring($sta, 5, 1) else " "

  let $comp := substring($cha, 3, 1)

  let $pdt := xs:dateTime($pPick/*:time/*:value)
  let $sdt := if ($sPick) then xs:dateTime($sPick/*:time/*:value) else ()


  let $sField := if (empty($sdt)) then () else ib:fmt_s_from_p_minute($pdt, $sdt)

  let $pW := ib:weight_from_pickUncertainty(string($pPick/*:time/*:uncertainty) , string($pPick/*:time/*:lowerUncertainty), string($pPick/*:time/*:upperUncertainty))
  let $sW := ib:weight_from_pickUncertainty(string($sPick/*:time/*:uncertainty) , string($sPick/*:time/*:lowerUncertainty), string($sPick/*:time/*:upperUncertainty))
  let $fm := ib:first_motion(string($pPick/*:polarity))

  let $originID := normalize-space(string($origin/@publicID))
  (:  :)
  let $waAgg := ib:wa_station_aggregate($event, $originID, $sta, $net, $loc,$cha)
  let $ampBlock := ib:fmt_amp_per_block($waAgg?ampMean, $waAgg?perMean)

  let $afterP := (if ($sField) then (ib:rpad("", 7) || $sField || " S " || $sW || ib:rpad("", 4))
                               else (ib:rpad("", 20) ))

  let $fixed :=
      $sta4
    || " "
    || "P"
    || $fm
    || $pW
    || $comp
    || ib:fmt_p_datetime_yyMMddHHmmSSff($pdt)
    || $afterP

  (: amp/period block next (6 chars), then pad until col ~78 :)
  let $mid := $ampBlock || ib:rpad("", 28)
  (: costruisco a 77 e poi appendo sta5 come colonna 78 :)
  let $fixed77 := ib:rpad($fixed || $mid, 77)
  let $fixed78 := $fixed77 || $sta5

  let $chanNetLoc :=
    substring($cha,1,3) || substring($net,1,2) || ib:loc2($loc)

  let $evid := ib:idnum(string($event/@publicID))
  let $orid := ib:idnum(string($origin/@publicID))
  let $ver  := normalize-space(string(($origin/*:creationInfo/*:version)[1]))

  let $tail :=
    ib:rpad($chanNetLoc, 9) || "  "
    || "EVID:" || $evid
    || ",ORID:" || $orid
    || (if ($ver != "") then ",V:" || $ver else "")
    || ib:fmt_tail_amplitudes($waAgg?byChan)

  return $fixed78 || $tail
};

(:~
 : Build a single NonLinLoc phase record line.
 :
 : @param $phase  Phase name.
 : @param $pick   Pick element.
 : @return Formatted NLL line string.
 :)
declare function ib:build_nll_line(
  $phase as xs:string,
  $pick as element()
) as xs:string {

  let $w := $pick/*:waveformID
  let $sta := normalize-space(string($w/@stationCode))
  let $cha := normalize-space(string($w/@channelCode))

  let $sta6 := ib:rpad(if ($sta != "") then substring($sta, 1, 6) else "?", 6)
  let $instRaw := if ($cha != "") then substring($cha, 1, 2) else "?"
  let $inst4 := ib:rpad($instRaw, 4)
  let $compRaw := if ($cha != "") then substring($cha, string-length($cha), 1) else "?"
  let $comp4 := ib:rpad($compRaw, 4)

  let $onsetVal := lower-case(normalize-space(string($pick/*:onset)))
  let $onset :=
    if ($onsetVal = ("impulsive", "i")) then "i"
    else if ($onsetVal = ("emergent", "e")) then "e"
    else "?"

  let $phase6 := ib:rpad(if ($phase != "") then substring($phase, 1, 6) else "?", 6)
  let $fm0 := ib:first_motion(string($pick/*:polarity))
  let $fm := if ($fm0 = " ") then "?" else $fm0

  let $pdt := xs:dateTime($pick/*:time/*:value)
  let $date := format-dateTime($pdt, "[Y0001][M01][D01]")
  let $hm := format-dateTime($pdt, "[H01][m01]")
  let $sec := ib:fmt_sec7_4($pdt)

  let $err := ib:pick_uncertainty_seconds($pick)

  return string-join((
    $sta6,
    $inst4,
    $comp4,
    $onset,
    $phase6,
    $fm,
    $date,
    $hm,
    $sec,
    "GAU",
    ib:fmt_exp9_2($err),
    ib:fmt_exp9_2(()),
    ib:fmt_exp9_2(()),
    ib:fmt_exp9_2(())
  ), " ")
};

(:~
 : Build a NonLinLoc origin header line.
 :
 : @param $event   QuakeML event.
 : @param $origin  Preferred origin.
 : @return Formatted NLL origin header string.
 :)
declare function ib:build_nll_origin_line(
  $event as element(),
  $originSeq as element()*
) as xs:string {

  let $origin := $originSeq[1]
  let $ot := xs:dateTime($origin/*:time/*:value)
  let $date := format-dateTime($ot, "[Y0001] [M01] [D01]")
  let $time := format-dateTime($ot, "[H01] [m01]")
  let $sec := ib:fmt_sec7_4($ot)

  let $lat := ib:to_decimal($origin/*:latitude/*:value)
  let $latErr := ib:to_decimal($origin/*:latitude/*:uncertainty)
  let $lon := ib:to_decimal($origin/*:longitude/*:value)
  let $lonErr := ib:to_decimal($origin/*:longitude/*:uncertainty)

  let $depM := ib:to_decimal($origin/*:depth/*:value)
  let $dep := if (exists($depM)) then $depM div 1000 else ()
  let $depErrM := ib:to_decimal($origin/*:depth/*:uncertainty)
  let $depErr := if (exists($depErrM)) then $depErrM div 1000 else ()

  let $gap := ib:to_decimal($origin/*:quality/*:azimuthalGap)
  let $rms := ib:to_decimal($origin/*:quality/*:standardError)
  let $nphs := ib:to_decimal($origin/*:quality/*:usedPhaseCount)
  let $minDist := ib:to_decimal($origin/*:quality/*:minimumDistance)*111.0 (:very rough:)
  let $maxDist := ib:to_decimal($origin/*:quality/*:maximumDistance)*111.0

  let $prefMagID := normalize-space(string($event/*:preferredMagnitudeID))
  let $mag := if ($prefMagID != "") then ($event/*:magnitude[@publicID = $prefMagID])[1] else ($event/*:magnitude[1])[1]
  let $magVal := ib:to_decimal($mag/*:mag/*:value)

  let $region :=
    normalize-space(string(( $event/*:description/*:text, $event/*:eventDescription/*:text )[1]))
  let $regionText := if ($region = "") then "?" else $region

  return
    "# INGVWS  OT " || $date || "  " || $time || " " || $sec
    || " Lat " || ib:fmt_num($lat, "0.0000", "-1.0000")
    || " Lat_Err " || ib:fmt_num($latErr, "0.0000", "-1.0000")
    || " Long " || ib:fmt_num($lon, "0.0000", "-1.0000")
    || " Lon_Err " || ib:fmt_num($lonErr, "0.0000", "-1.0000")
    || " Depth " || ib:fmt_num($dep, "0.0", "-1.0")
    || " Dep_Err " || ib:fmt_num($depErr, "0.0", "-1.0")
    || "  QUALITY  GAP " || ib:fmt_num($gap, "0.0", "-1.0")
    || " RMS " || ib:fmt_num($rms, "0.00", "-1.00")
    || " NPHS " || ib:fmt_num($nphs, "0", "-1")
    || " MinDist " || ib:fmt_num($minDist, "0.000", "-1.000")
    || " MaxDist " || ib:fmt_num($maxDist, "0.000", "-1.000")
    || " Magnitude " || ib:fmt_num($magVal, "0.0", "-1.0")
    || " Region " || $regionText
};

(: ----------------- main: q:quakeml -> lines ----------------- :)

(:hypo71phs format:)
(:~
 : Convert QuakeML events to hypo71phs lines.
 :
 : @param $events  Sequence of QuakeML event elements.
 : @return Sequence of formatted lines (including separator).
 :)
declare function ib:qml_to_ingv_phs_lines($events as element()* ) as xs:string* {
  let $_ := lo:debug('qml_to_ingv_phs_lines with ' || count($events) || ' event(s)')
  return
    for $event in $events
    let $prefOriginID := normalize-space(string($event/*:preferredOriginID))
    let $origin := ($event/*:origin[@publicID = $prefOriginID])[1]
    return
      if (empty($event) or empty($origin)) then ()
      else
        let $pmap := ib:pick_map($event) (:pick_id : pick :)
        let $rows_pref :=
          for $a in $origin/*:arrival
          let $pid := normalize-space(string($a/*:pickID))
          let $p := $pmap($pid)
          let $k := ib:station_key($p)
          where exists($p)
          return map{
            "key": $k,
            "phase": upper-case(normalize-space(string($a/*:phase))),
            "arr": $a,
            "pick": $p
          }

        let $lines_pref :=
            for $row in $rows_pref
            group by $k := $row?key
              let $P :=
                  (for $r in $row
                   where fn:starts-with($r?phase ,"P")
                   order by ib:tw_int($r?arr) descending
                   return $r)[1]

              let $S :=
                  (for $r in $row
                   where fn:starts-with($r?phase, "S")
                   order by ib:tw_int($r?arr) descending
                   return $r)[1]

              let $pdt := if (exists($P)) then xs:dateTime($P?pick/*:time/*:value) else ()
            where exists($pdt)
            order by $pdt ascending
            return ib:build_line(
                $event, $origin, $k,
                $P?pick, $P?arr,
                (if (exists($S)) then $S?pick else ()),
                (if (exists($S)) then $S?arr  else ())
            )

        (: Add separator to lines:)
        return ($lines_pref, if (not(empty($lines_pref))) then " ")

};


(:phsnll format:)
(:~
 : Convert QuakeML events to phsnll lines.
 :
 : @param $events  Sequence of QuakeML event elements.
 : @return Sequence of formatted lines (including separator).
 :)
declare function ib:qml_to_phsnll_lines($events as element()* ) as xs:string* {
  let $_ := lo:debug('qml_to_phsnll_lines with ' || count($events) || ' event(s)')
  return
    for $event in $events
    let $prefOriginID := normalize-space(string($event/*:preferredOriginID))
    let $origin := ($event/*:origin[@publicID = $prefOriginID])[1]
    return
      if (empty($event) or empty($origin)) then ()
      else
        let $pmap := ib:pick_map($event) (:pick_id : pick :)
        let $rows :=
          for $a in $origin/*:arrival
          let $pid := normalize-space(string($a/*:pickID))
          let $p := $pmap($pid)
          let $pdt := if (exists($p/*:time/*:value)) then xs:dateTime($p/*:time/*:value) else ()
          where exists($p) and exists($pdt)
          return map{
            "phase": upper-case(normalize-space(string($a/*:phase))),
            "pick": $p,
            "pdt": $pdt
          }

        let $lines :=
          for $row in $rows
          order by $row?pdt ascending
          return ib:build_nll_line($row?phase, $row?pick)

        let $originLine := ib:build_nll_origin_line($event, $origin)
        let $header := "#Station_name Instrument Component P_phase_onset Phase_descriptor First_motion Date Hour_minute Seconds Err_type Err Err_mag Coda_duration Amplitude Period  "

        (: Add separator to lines:)
        return if (empty($lines)) then () else ($header, $originLine, $lines, "")

};
(:
NonLinLoc Phase file format (ASCII, NLLoc obsFileType = NLLOC_OBS)
The NonLinLoc Phase file format is intended to give a comprehensive phase time-pick description that is easy to write and read.
For each event to be located, this file contains one set of records. In each set there is one "arrival-time" record for each phase at each seismic station. The final record of each set is a blank. As many events as desired can be included in one file.
Each record has a fixed format, with a blank space between fields. A field should never be left blank - use a "?" for unused characther fields and a zero or invalid numeric value for numeric fields.
The NonLinLoc Phase file record is identical to the first part of each phase record in the NLLoc Hypocenter-Phase file output by the program NLLoc. Thus the phase list output by NLLoc can be used without modification as time pick observations for other runs of NLLoc.
NonLinLoc phase record:
Fields:
Station name (char*6)
station name or code
Instrument (char*4)
instument identification for the trace for which the time pick corresponds (i.e. SP, BRB, VBB)
Component (char*4)
component identification for the trace for which the time pick corresponds (i.e. Z, N, E, H)
P phase onset (char*1)
description of P phase arrival onset; i, e
Phase descriptor (char*6)
Phase identification (i.e. P, S, PmP)
First Motion (char*1)
first motion direction of P arrival; c, C, u, U = compression; d, D = dilatation; +, -, Z, N; . or ? = not readable.
Date (yyyymmdd) (int*6)
year (with century), month, day
Hour/minute (hhmm) (int*4)
Hour, min
Seconds (float*7.4)
seconds of phase arrival
Err (char*3)
Error/uncertainty type; GAU
ErrMag (expFloat*9.2)
Error/uncertainty magnitude in seconds
Coda duration (expFloat*9.2)
coda duration reading
Amplitude (expFloat*9.2)
Maxumim peak-to-peak amplitude
Period (expFloat*9.2)
Period of amplitude reading
Example:
GRX    ?    ?    ? P      U 19940217 2216   44.9200 GAU  2.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
GRX    ?    ?    ? S      ? 19940217 2216   48.6900 GAU  4.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
CAD    ?    ?    ? P      D 19940217 2216   46.3500 GAU  2.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
CAD    ?    ?    ? S      ? 19940217 2216   50.4000 GAU  4.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
BMT    ?    ?    ? P      U 19940217 2216   47.3500 GAU  2.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
BMT    ?    ?    ? S      ? 19940217 2216   52.8700 GAU  4.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
ESC    ?    ?    ? P      D 19940217 2216   47.4700 GAU  2.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
ESC    ?    ?    ? S      ? 19940217 2216   52.8100 GAU  4.00e-02 -1.00e+00 -1.00e+00 -1.00e+00
BST    ?    ?    ? P      D 19940217 2216   48.0000 GAU  1.00e+05 -1.00e+00 -1.00e+00 -1.00e+00
BST    ?    ?    ? S      ? 19940217 2216   54.6600 GAU  4.00e-02 -1.00e+00 -1.00e+00 -1.00e+00

:)
