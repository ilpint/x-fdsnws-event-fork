(:~
 : Style module, build output formats.
 :
 : @author   Stefano Pintore
 : @see      https://github.com/INGV/x-fdsnws-event
 : @version  1.0
 :)
xquery version "3.1";
module namespace sy="http://webservices.ingv.it/fdsnws/event/modules/style";
import module namespace se="http://webservices.ingv.it/fdsnws/event/modules/settings" at 'settings.xqm';

declare %public variable $sy:channel_style:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:ingv="http://www.fdsn.org/xml/station/ingv" xmlns:x="http://www.fdsn.org/xml/station/1" version="3.0">

<xsl:strip-space elements="*"/>
<xsl:output method="text" media-type="text/plain" indent="yes"/>

<xsl:template match="ERROR">
    <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="x:FDSNStationXML">
<xsl:text>#Network | Station | location | Channel | Latitude | Longitude | Elevation | Depth | Azimuth | Dip | SensorDescription | Scale | ScaleFreq | ScaleUnits | SampleRate | StartTime | EndTime
</xsl:text>
<!--Matching and sorting for network code-->
    <xsl:apply-templates>
        <xsl:sort select="@code"/>
    </xsl:apply-templates>

</xsl:template>

<!--Matching and sorting for station code-->
<xsl:template match="Network">
    <xsl:apply-templates>
        <xsl:sort select="@code"/>
    </xsl:apply-templates>
</xsl:template>

<!--Matching and sorting for location and channel code-->
<xsl:template match="x:Station">
    <xsl:apply-templates>
        <xsl:sort select="@locationCode"/>
        <xsl:sort select="@code"/>
        <xsl:sort select="@startDate"/>
        <xsl:sort select="@endDate"/>
    </xsl:apply-templates>
</xsl:template>

<xsl:template match="x:Channel">
    <xsl:value-of select="../../@code"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="../@code"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="@locationCode"/>
    <xsl:value-of select="concat('|', @code, '|'  )"/>
    <xsl:value-of select="x:Latitude"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Longitude"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Elevation"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Depth"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Azimuth"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Dip"/>
    <xsl:text>|</xsl:text>
    <xsl:apply-templates select="x:Sensor"/>
    <xsl:text>|</xsl:text>
    <xsl:apply-templates select="x:Response"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:SampleRate"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="@startDate"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="concat(@endDate,'&#xA;')"/>

<!-- Do not indent : next two lines to get newlines -->
<xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="x:Response">
    <xsl:apply-templates select="x:InstrumentSensitivity"/>
</xsl:template>

<xsl:template match="x:InstrumentSensitivity">
    <xsl:value-of select="x:Value"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Frequency"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:InputUnits"/>
</xsl:template>

<xsl:template match="x:Sensor">
<xsl:value-of select="x:Description"/>
</xsl:template>

<!--  Catch all -->
<xsl:template match="text()|@*">
 </xsl:template>

</xsl:stylesheet>
;

declare %public variable $sy:station_style:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:ingv="http://www.fdsn.org/xml/station/ingv" xmlns:x="http://www.fdsn.org/xml/station/1" version="3.0">
<xsl:strip-space elements="*"/>
<xsl:output method="text" media-type="text/plain" indent="yes"/>

<xsl:template match="ERROR">
    <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="x:FDSNStationXML">
<xsl:text>#Network | Station | Latitude | Longitude | Elevation | SiteName | StartTime | EndTime
</xsl:text>
<!--Matching and sorting for network code-->
    <xsl:apply-templates>
        <xsl:sort select="@code"/>
    </xsl:apply-templates>
</xsl:template>

<!--Matching and sorting for station code-->
<xsl:template match="Network">
    <xsl:apply-templates>
        <xsl:sort select="@code"/>
    </xsl:apply-templates>
</xsl:template>

<xsl:template match="x:Station">
    <xsl:value-of select="../@code"/>
    <xsl:value-of select="concat('|', @code, '|'  )"/>
    <xsl:value-of select="x:Latitude"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Longitude"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Elevation"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="x:Site"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="@startDate"/>
    <xsl:text>|</xsl:text>
    <xsl:value-of select="concat(@endDate,'&#xA;')"/>
<!-- Do not indent next two lines to get newlines -->
<xsl:text>
</xsl:text>
    <xsl:apply-templates/>
</xsl:template>

<!--  Catch all -->
<xsl:template match="text()|@*">
 </xsl:template>

</xsl:stylesheet>;

declare %public variable $sy:network_style:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:ingv="http://www.fdsn.org/xml/station/ingv" xmlns:x="http://www.fdsn.org/xml/station/1" version="3.0">
<xsl:strip-space elements="*"/>
<xsl:output method="text" media-type="text/plain" indent="yes"/>

<xsl:template match="ERROR">
    <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="x:FDSNStationXML">
<xsl:text>#Network | Description | StartTime | EndTime | TotalStations
</xsl:text>

<!--Matching and sorting for network code-->
    <xsl:apply-templates>
        <xsl:sort select="@code"/>
    </xsl:apply-templates>
</xsl:template>
<!-- Match networks elements extracting lines as in Network|Description|StartTime|EndTime|TotalStations  -->
<xsl:template match="x:Network">
    <xsl:value-of select="concat(@code, '|'  )"/>
    <xsl:value-of select="x:Description"/>
    <xsl:value-of select="concat('|', @startDate, '|', @endDate , '|')"/>
    <xsl:value-of select="concat(x:TotalNumberStations,'&#xA;')"/>
<!-- Do not indent next two lines to get newlines -->
<xsl:text>
</xsl:text>
</xsl:template>
<!--  Catch all -->
<xsl:template match="text()|@*">
 </xsl:template>

</xsl:stylesheet>
;


declare %public variable $sy:geojson_style:= ""

;


declare %public variable $sy:event_style:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" version="3.0" xpath-default-namespace="http://quakeml.org/xmlns/bed/1.2">
<xsl:strip-space elements="*"/>
<xsl:output method="text" media-type="text/plain" indent="yes"/>

<xsl:template match="ERROR">
    <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="q:quakeml">
<xsl:text>#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType</xsl:text>
    <xsl:apply-templates select="eventParameters"/>
    <xsl:apply-templates select="eventreducedParameters"/>
</xsl:template>
<!-- Contributor and ContributorID for the case of single contributor-->
<!-- FIXME: The catalog should be in the description of eventParameters -->
<xsl:template match="eventParameters/*">
    <xsl:apply-templates select="event"/>
<xsl:text>&#xa;</xsl:text>
    <xsl:value-of select="concat(@publicID, '|'  )"/>
    <xsl:value-of select="concat(origin/time/value , '|')"/>
    <xsl:value-of select="concat(origin/latitude/value , '|')"/>
    <xsl:value-of select="concat(origin/longitude/value , '|')"/>
    <xsl:value-of select="concat((origin/depth/value div 1000 ), '|')"/>
    <xsl:value-of select="concat(origin/creationInfo/author, '|')"/>
    <xsl:value-of select="concat(@catalog, '|')"/>
    <xsl:value-of select="concat(creationInfo/agencyID, '|')"/>
    <xsl:value-of select="concat(@publicID, '|'  )"/>
    <xsl:value-of select="concat(magnitude/type, '|')"/>
    <xsl:value-of select="concat(magnitude/mag/value, '|')"/>
    <xsl:value-of select="concat(magnitude/creationInfo/author, '|')"/>
    <xsl:value-of select="concat(description/text, '|')"/>
    <xsl:value-of select="type"/>

</xsl:template>
<!-- Only for content reduced coming from index database-->
<xsl:template match="eventParameters/*:eventreduced">
    <xsl:apply-templates select="eventreduced"/>
<xsl:text>&#xa;</xsl:text>
    <xsl:value-of select="concat(@eventID, '|'  )"/>
    <xsl:value-of select="concat(@origintime , '|')"/>
    <xsl:value-of select="concat(@latitude , '|')"/>
    <xsl:value-of select="concat(@longitude , '|')"/>
    <xsl:value-of select="concat((@depth div 1000 ), '|')"/>
    <xsl:value-of select="concat(@author, '|')"/>
    <xsl:value-of select="concat(@catalog, '|')"/>
    <xsl:value-of select="concat(@contributor, '|')"/>
    <xsl:value-of select="concat(@contributorID, '|'  )"/>
    <xsl:value-of select="concat(@magtype, '|')"/>
    <xsl:value-of select="concat(@magnitude, '|')"/>
    <xsl:value-of select="concat(@magauthor, '|')"/>
    <xsl:value-of select="concat(@eventlocationname, '|')"/>
    <xsl:value-of select="@eventtype"/>
</xsl:template>

<xsl:template match="eventParameters/*:text">
    <xsl:apply-templates select="text"/>
<xsl:text>&#xa;</xsl:text>
    <xsl:value-of select="concat(@eventID, '|'  )"/>
    <xsl:value-of select="concat(@origintime , '|')"/>
    <xsl:value-of select="concat(@latitude , '|')"/>
    <xsl:value-of select="concat(@longitude , '|')"/>
    <xsl:value-of select="concat((@depth div 1000 ), '|')"/>
    <xsl:value-of select="concat(@author, '|')"/>
    <xsl:value-of select="concat(@catalog, '|')"/>
    <xsl:value-of select="concat(@contributor, '|')"/>
    <xsl:value-of select="concat(@contributorID, '|'  )"/>
    <xsl:value-of select="concat(@magtype, '|')"/>
    <xsl:value-of select="concat(@magnitude, '|')"/>
    <xsl:value-of select="concat(@magauthor, '|')"/>
    <xsl:value-of select="concat(@eventlocationname, '|')"/>
    <xsl:value-of select="@eventtype"/>
</xsl:template>

<!--  Catch all -->
<xsl:template match="text()|@*">
</xsl:template>

</xsl:stylesheet>
;


(: <text eventID="smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101" origintime="2023-01-01T00:00:39.090000" originID="smi:webservices.ingv.it/fdsnws/event/1/query?originId=113221021" latitude="42.8138" longitude="13.0685" depth="8300" author="SURVEY-INGV" catalog="INGV" contributor="INGV" contributorID="smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101" magtype="ML" magnitude="0.8" magauthor="SURVEY-INGV" eventlocationname="3 km NW Norcia (PG)" eventtype="earthquake"><id>7952133</id></text> :)

declare %public variable $sy:reduced_event_style:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" version="3.0" xpath-default-namespace="http://quakeml.org/xmlns/bed/1.2">
<xsl:strip-space elements="*"/>
<xsl:output method="text" media-type="text/plain" indent="yes"/>

<xsl:template match="ERROR">
    <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="q:quakeml">
<xsl:text>#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType</xsl:text>
    <xsl:apply-templates select="eventreducedParameters"/>

</xsl:template>
<!-- Contributor and ContributorID for the case of single contributor-->
<!-- FIXME: The catalog should be in the description of eventParameters -->
<xsl:template match="eventreducedParameters/*">
    <xsl:apply-templates select="eventreduced"/>
<xsl:text>&#xa;</xsl:text>
    <xsl:value-of select="concat(@eventID, '|'  )"/>
    <xsl:value-of select="concat(@origintime , '|')"/>
    <xsl:value-of select="concat(@latitude , '|')"/>
    <xsl:value-of select="concat(@longitude , '|')"/>
    <xsl:value-of select="concat((@depth div 1000 ), '|')"/>
    <xsl:value-of select="concat(@author, '|')"/>
    <xsl:value-of select="concat(@catalog, '|')"/>
    <xsl:value-of select="concat(@contributor, '|')"/>
    <xsl:value-of select="concat(@contributorID, '|'  )"/>
    <xsl:value-of select="concat(@magtype, '|')"/>
    <xsl:value-of select="concat(@magnitude, '|')"/>
    <xsl:value-of select="concat(@magauthor, '|')"/>
    <xsl:value-of select="concat(@eventlocationname, '|')"/>
    <xsl:value-of select="@eventtype"/>
</xsl:template>

<!--  Catch all -->
<xsl:template match="text()|@*">
</xsl:template>

</xsl:stylesheet>
;


declare %public variable $sy:reduced_event_style_extended_text:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" version="3.0" xpath-default-namespace="http://quakeml.org/xmlns/bed/1.2">
<xsl:strip-space elements="*"/>
<xsl:output method="text" media-type="text/plain" indent="yes"/>

<xsl:template match="ERROR">
    <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="q:quakeml">
<xsl:text>#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|err_ot|err_lon|err_lat|err_depth|err_h|err_z|nph_tot|nph_tot_used|nph_p_used|nph_s_used|magnitud_id|magnitude_type|magnitude_value|magnitude_err|magnitude_nsta_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_err|pref_magnitude_nsta_used|rms|gap|source</xsl:text>
    <xsl:apply-templates select="eventreducedParameters"/>

</xsl:template>
<!-- Contributor and ContributorID for the case of single contributor-->
<!-- FIXME: The catalog should be in the description of eventParameters -->
<xsl:template match="eventreducedParameters/*">
    <xsl:apply-templates select="eventreduced"/>
<xsl:text>&#xa;</xsl:text>
    <xsl:value-of select="concat(@eventID, '|'  )"/>
    <xsl:value-of select="@eventtype"/>
    <xsl:value-of select="concat(origin/@publicID , '|')"/>
    <xsl:value-of select="concat(@origintime , '|')"/>
    <xsl:value-of select="concat(@latitude , '|')"/>
    <xsl:value-of select="concat(@longitude , '|')"/>
    <xsl:value-of select="concat((@depth div 1000 ), '|')"/>
    <xsl:value-of select="concat(@author, '|')"/>
    <xsl:value-of select="concat(@catalog, '|')"/>
    <xsl:value-of select="concat(@contributor, '|')"/>
    <xsl:value-of select="concat(@contributorID, '|'  )"/>
    <xsl:value-of select="concat(@magtype, '|')"/>
    <xsl:value-of select="concat(@magnitude, '|')"/>
    <xsl:value-of select="concat(@magauthor, '|')"/>
    <xsl:value-of select="concat(@eventlocationname, '|')"/>
</xsl:template>

<!--  Catch all -->
<xsl:template match="text()|@*">
</xsl:template>

</xsl:stylesheet>
;


declare %public variable $sy:event_style_extended_text:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" xpath-default-namespace="http://quakeml.org/xmlns/bed/1.2" xmlns:ingv="http://webservices.ingv.it/">
<xsl:strip-space elements="*"/>
<xsl:output method="text" media-type="text/plain" indent="yes"/>

<xsl:template match="ERROR">
    <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="q:quakeml">
<xsl:text>#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source</xsl:text>
    <xsl:apply-templates select="eventParameters"/>
    <!-- <xsl:apply-templates select="eventreducedParameters"/> -->
</xsl:template>
<!-- Contributor and ContributorID for the case of single contributor-->
<!-- FIXME: The catalog should be in the description of eventParameters -->
<xsl:template match="eventParameters/*">
    <xsl:apply-templates select="event"/>
<xsl:text>&#xa;</xsl:text>
    <!-- <xsl:value-of select="concat(@publicID, '|'  )"/> -->
    <xsl:value-of select="if (@publicID) then concat(substring-after(@publicID,'='), '|') else '|'"/>
    <xsl:value-of select="if (type) then concat(type, '|') else '|'"/>
    <!-- <xsl:value-of select="concat(origin/@publicID , '|')"/> -->
    <xsl:value-of select="if (origin/@publicID) then concat(substring-after(origin/@publicID,'='), '|') else '|'"/>
    <xsl:value-of select="if (origin/creationInfo/version) then concat(origin/creationInfo/version, '|') else '|'"/>
    <xsl:value-of select="if (origin/time/value) then concat(format-dateTime(origin/time/value, '[Y,4]-[M,2]-[D,2]T[H01]:[m01]:[s01].[f1,2]' ) , '|') else '|'"/>
    <xsl:value-of select="if (origin/longitude/value) then concat(origin/longitude/value, '|') else '|'"/>
    <xsl:value-of select="if (origin/latitude/value) then concat(origin/latitude/value, '|') else '|'"/>
    <xsl:value-of select="if (origin/depth/value) then concat((origin/depth/value div 1000 ), '|') else '|'"/>
    <xsl:choose>
        <xsl:when test="origin/depthType = 'from location'">
          <xsl:value-of select="concat('0' , '|')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('1' , '|')"/>
        </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="if (origin/creationInfo/*:quality/text()) then concat(origin/creationInfo/*:quality/text() , '|') else '|'"/>
    <xsl:value-of select="if (origin/quality/standardError) then concat(origin/quality/standardError, '|') else '|'"/>
    <xsl:value-of select="if (origin/quality/azimuthalGap) then concat(format-number(origin/quality/azimuthalGap, '0.0'), '|') else '|'"/>
    <xsl:value-of select="if (nph_tot) then concat(nph_tot, '|') else '|'"/>
    <xsl:value-of select="if (nph_tot_used) then concat(nph_tot_used, '|') else '|'"/>
    <xsl:value-of select="if (nph_p_used) then concat(nph_p_used, '|') else '|'"/>
    <xsl:value-of select="if (nph_s_used) then concat(nph_s_used, '|') else '|'"/>
    <xsl:value-of select="if (min_dist_km/text()) then concat(format-number(min_dist_km ,'0.00') , '|') else '|'"/>
    <xsl:value-of select="if (max_dist_km/text()) then concat(format-number(max_dist_km ,'0.00') , '|') else '|'"/>
    <xsl:value-of select="if (origin/time/uncertainty) then concat(origin/time/uncertainty, '|') else '|' "/>
    <xsl:value-of select="if (err_lon_km/text()) then concat(format-number(err_lon_km/text(), '0.00'), '|') else '|'"/>
    <xsl:value-of select="if (err_lat_km/text()) then concat(format-number(err_lat_km/text(), '0.00'), '|') else '|'"/>
    <xsl:value-of select="if (origin/depth/uncertainty/text()) then concat(format-number((origin/depth/uncertainty/text() div 1000), '0.00'), '|') else '|'"/>
    <xsl:value-of select="if (origin/originUncertainty/horizontalUncertainty/text()) then concat(format-number((origin/originUncertainty/horizontalUncertainty/text() div 1000), '0.00'), '|') else '|'"/>
    <xsl:value-of select="if (origin/depth/uncertainty/text()) then concat(format-number((origin/depth/uncertainty/text() div 1000), '0.00'), '|') else '|'"/>
    <xsl:value-of select="if (origin/originUncertainty/confidenceLevel/text()) then concat(format-number((origin/originUncertainty/confidenceLevel/text() ), '0.0'), '|') else '|'"/>
    <!-- <xsl:value-of select="concat(magnitude[1]/@publicID, '|')"/> -->
    <xsl:value-of select="if (magnitude[1]/@publicID) then concat(substring-after(magnitude[1]/@publicID,'='), '|') else '|'"/>
    <xsl:value-of select="if (magnitude[1]/type) then concat(magnitude[1]/type, '|') else '|'"/>
    <xsl:value-of select="if (magnitude[1]/mag/value) then concat(magnitude[1]/mag/value, '|') else '|'"/>
    <xsl:value-of select="if (magnitude[1]/creationInfo/*:mag_quality/text()) then concat(magnitude[1]/creationInfo/*:mag_quality/text(), '|') else '|'"/>
    <xsl:value-of select="if (magnitude[1]/mag/uncertainty) then concat(magnitude[1]/mag/uncertainty, '|') else '|'"/>
    <xsl:value-of select="if (magnitude[1]/stationCount) then concat(magnitude[1]/stationCount, '|') else '|'"/>
    <!-- <xsl:value-of select="concat(magnitude[2]/@publicID, '|')"/> -->
    <xsl:value-of select="if (magnitude[2]/@publicID) then concat(substring-after(magnitude[2]/@publicID,'='), '|') else '|'"/>
    <xsl:value-of select="if (magnitude[2]/type) then concat(magnitude[2]/type, '|') else '|'"/>
    <xsl:value-of select="if (magnitude[2]/mag/value) then concat(magnitude[2]/mag/value, '|') else '|'"/>
    <xsl:value-of select="if (magnitude[2]/creationInfo/*:mag_quality/text()) then concat(magnitude[2]/creationInfo/*:mag_quality/text(), '|') else '|'"/>
    <xsl:value-of select="if (magnitude[2]/mag/uncertainty) then concat(magnitude[2]/mag/uncertainty, '|') else '|'"/>
    <xsl:value-of select="if (magnitude[2]/stationCount) then concat(magnitude[2]/stationCount, '|') else '|'"/>
    <xsl:value-of select="@publicID"/>
    <!--<xsl:value-of select="substring-before(@publicID,'=')"/>-->

</xsl:template>

<!--  Catch all -->
<xsl:template match="text()|@*">
</xsl:template>

</xsl:stylesheet>
;



declare %public variable $sy:application_wadl_style:=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://wadl.dev.java.net/2009/02"  xmlns:xs="http://www.w3.org/2001/XMLSchema" version="2.0">
<xsl:strip-space elements="*"/>
<xsl:output method="xml" indent="yes"/>

<xsl:template match="*:resources">
<resources base="{se:get-resource-base()}">
    <xsl:apply-templates/>
</resources>
</xsl:template>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
;
