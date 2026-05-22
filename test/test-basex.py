#!/usr/bin/env python
# coding: utf-8


import requests
# noinspection PyUnresolvedReferences
import pytest
import conftest
import difflib
#import xml.etree.ElementTree as ET
#from io import StringIO
import lxml.etree as ET
from xmldiff import main, formatting
# from requests.auth import HTTPBasicAuth
import json

############################################# DATA FOR TEST #############################################


# @pytest.fixture
# def host(request):
#     return request.config.getoption("--host")
#
# @pytest.fixture
# def basicAuth(request):
#     username = request.config.getoption("--user")
#     password = request.config.getoption("--pass")
#     return HTTPBasicAuth(username, password)

### Contains query string, expected response code
testdataxml = [

    ("nodata=404&minmag=0.1&maxmag=3.6&mindepth=8.0&maxdepth=19.9&format=xml&orderby=time-asc&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&includeamplitudes=true&includestationmagnitudes=true&includeall=false&includepicks=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3&&limit=1",200,
     'test/data/expected/001.xml',
     "Query 001"),

    ("nodata=404&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includestationmagnitudes=true&includeamplitudes=true&includepicks=false",200,
     'test/data/expected/002.xml',
     "Query 002 - on eventid  with some includes"),

    (
    "nodata=404&minmag=0.1&maxmag=3.6&mindepth=8.0&maxdepth=19.9&format=xml&orderby=time-asc&includearrivals=true&includeallmagnitudes=true&includeallorigins=true&includeamplitudes=true&includestationmagnitudes=true&minlat=34&maxlat=43&minlon=13&maxlon=14.3&&limit=1",
    200,
    'test/data/expected/003.xml',
    "Query 003"),

    (
        "nodata=404&minmag=0.1&maxmag=3.6&mindepth=8.0&maxdepth=19.9&format=xml&orderby=time-asc&includearrivals=true&includeallmagnitudes=true&includeallorigins=true&includeamplitudes=true&includestationmagnitudes=true&minlat=34&maxlat=43&minlon=13&maxlon=14.3&&limit=2",
        200,
        'test/data/expected/004.xml',
        "Query 004"),

(
        "nodata=404&mindepth=8.0&maxdepth=19.9&format=xml&orderby=time-asc&includearrivals=true&includeallmagnitudes=true&includeallorigins=true&includeamplitudes=true&includestationmagnitudes=true&starttime=2023-01-01&endtime=2023-01-19&limit=2",
        200,
        'test/data/expected/004.xml',
        "Query 005"),

    ("nodata=404&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeamplitudes=true&includestationmagnitudes=true", 200,
     'test/data/expected/002.xml',
     "Query 006 - on eventid including some, some exclusion are default"),

    (
    "nodata=404&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeall=true",
    200,
    'test/data/expected/005.xml',
    "Query 007 - on eventid including all possible optionals output"),

    (
        "nodata=404&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&&includearrivals=true&includepicks=true&includeallmagnitudes=true&includeallorigins=true&includeamplitudes=true&includestationmagnitudes=true",
        200,
        'test/data/expected/005.xml',
        "Query 008 - on eventid including all possible optionals output boring format"),
]

### Contains query string, expected response code, expected content
#TODO test http://127.0.0.1:8087/fdsnws/event/1/query?eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeallorigins=true&includeallmagnitudes=true&format=text
testdatatxt = [

(
"nodata=404&format=text&eventtype=explosion",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:ch.ethz.sed/sc20a/Event/2025cdcacd|2025-01-31T00:06:35.345581|46.63163245|8.573055464|-1.46484375|toni@sc20ag|SED|SED|smi:ch.ethz.sed/sc20a/Event/2025cdcacd|MLhc|-0.562906728|toni@sc20ag|Goeschenen UR|explosion","Explosion output"),
(
"nodata=404&minmag=0.1&maxmag=3.6&limit=100&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude-asc&includearrivals=false&includeallmagnitudes=true&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3&end=2023-01-20",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|2023-01-18T08:46:11.870000|34.8393|14.2052|19.8|BULLETIN-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|ML|3.5|BULLETIN-INGV|Malta [Sea]|earthquake","Two events, format text"),
(
"nodata=404&minmag=0.1&maxmag=1.2&maxradius=2&lat=42&lon=13&format=text&orderby=magnitude-asc&includearrivals=false&includeallmagnitudes=true&includeallorigins=false",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","maxradius format text"),

(
"nodata=404&minmag=0.1&maxmag=3.6&limit=100&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3&end=2023-03-21",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|2023-01-18T08:46:11.870000|34.8393|14.2052|19.8|BULLETIN-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|ML|3.5|BULLETIN-INGV|Malta [Sea]|earthquake\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","Two events, order by magnitude format text"),
(
"nodata=404&minmag=0.1&maxmag=3.6&limit=100&mindepth=8.0&maxdepth=19.9&format=text&orderby=time&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341|2023-03-22T21:00:39.650000|42.795|13.123|9.4|BULLETIN-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341|ML|1.3|BULLETIN-INGV|2 km E Norcia (PG)|earthquake\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|2023-01-18T08:46:11.870000|34.8393|14.2052|19.8|BULLETIN-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|ML|3.5|BULLETIN-INGV|Malta [Sea]|earthquake\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","Three events, order by time format text"),
(
"nodata=404&minmag=0.1&maxmag=3.6&offset=3&mindepth=8.0&maxdepth=19.9&format=text&orderby=time&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","No limit but offset, order by time format text"),
(
"nodata=404&minmag=0.1&maxmag=3.6&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude&includearrivals=false&includepicks=false&includeallmagnitudes=false&includeallorigins=true&minlat=34&maxlat=43&minlon=13&maxlon=14.3&limit=1&offset=1",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|2023-01-18T08:46:11.870000|34.8393|14.2052|19.8|BULLETIN-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|ML|3.5|BULLETIN-INGV|Malta [Sea]|earthquake","The first event order by magnitude format text"),
(
"nodata=404&minmag=0.1&maxmag=3.6&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3&limit=1&offset=3",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","The second event order by magnitude format text"),
(
"nodata=404&minmag=0.1&maxmag=3.6&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3&limit=1",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|2023-01-18T08:46:11.870000|34.8393|14.2052|19.8|BULLETIN-INGV|INGV|INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951|ML|3.5|BULLETIN-INGV|Malta [Sea]|earthquake","The first event order by magnitude format text, default offset"),

(
"eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeallorigins=true&includeallmagnitudes=false&format=text&contributor=INGV",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV||INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","Event with more than origin asking right contributor"),

(
"catalog=INGV&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeallorigins=true&includeallmagnitudes=false&format=text",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV||INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","Event with more than origin, asking for catalog"),

(
"catalog=SUCA&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeallorigins=true&includeallmagnitudes=false&format=text",204,
"","Asking for non existent catalog "),

(
"catalog=INGV&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeallorigins=true&includeallmagnitudes=false&format=text",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV||INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","Event with more than origin, asking for catalog"),

(
"eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeallorigins=true&includeallmagnitudes=true&format=text&contributor=INGV&nodata=404",200,
"#EventID|Time|Latitude|Longitude|Depth/Km|Author|Catalog|Contributor|ContributorID|MagType|Magnitude|MagAuthor|EventLocationName|EventType\n\
smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|2023-01-01T00:00:39.090000|42.8138|13.0685|8.3|SURVEY-INGV||INGV|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101|ML|0.8|SURVEY-INGV|3 km NW Norcia (PG)|earthquake","Event found, text format ignores includeallx"),


(
"catalog=INGV&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951&includeallorigins=true&includeallmagnitudes=false&format=extended_text",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.87|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951","Event with more than origin, asking for catalog extended_text"),


(
"nodata=404&format=extended_text&orderby=time-asc&includearrivals=true&includeallmagnitudes=true&includeallorigins=true",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
18583881|earthquake|55046501|100|2018-04-02T13:40:33.880000|-63.0252|-20.5559|552.734|0||1.3964|51.4|0|0|0|0|||||||6.51||68.0|56146251|Mwpd|6.6||0.1|68|56146241|Mwp|6.4||0.2|81|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=18583881\n\
29794751|earthquake|104170521|1000|2022-02-03T22:04:16.670000|16.3548|41.2653|7.1|0|AC|0.37|123.0|59|59|42|17|26.30|150.00|0.2|0.70|0.60|1.10|0.69|1.10|68.0|111725091|ML|2.2|AB|0.3|56|111725091|ML|2.2|AB|0.3|56|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=29794751\n\
33778101|earthquake|113221021|100|2023-01-01T00:00:39.090000|13.0685|42.8138|8.3|0|AD|0.13|195.0|18|11|7|4|4.30|37.29|0.1|0.60|0.40|0.50|0.58|0.50|68.0|121439591|ML|0.8|BB|0.2|6|121439591|ML|0.8|BB|0.2|6|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.870000|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951\n\
34440341|earthquake|121350241|1000|2023-03-22T21:00:39.650000|13.123|42.795|9.4|0|AA|0.22|46.0|57|57|29|28|4.30|79.50|0.04|0.30|0.20|0.20|0.24|0.20|68.0|130623531|ML|1.3|AC|0.4|54|130623531|ML|1.3|AC|0.4|54|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341\n\
37710741|earthquake|125544601|100|2024-02-25T18:59:28.170000|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741\n\
|explosion|||2025-01-31T00:06:35.345581|8.573055464|46.63163245|-1.46484375|||0.07692563465|144.1|0|0|0|0||||38.73|32.89|0.70|0.83|0.70|||MLhc|-0.562906728||0.2189145896|16||MLhc|-0.562906728||0.2189145896|16|smi:ch.ethz.sed/sc20a/Event/2025cdcacd","Sorting by time extended_text"),

(
"nodata=404&format=extended_text&orderby=time-asc&",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
18583881|earthquake|55046501|100|2018-04-02T13:40:33.880000|-63.0252|-20.5559|552.734|0||1.3964|51.4|0|0|0|0|||||||6.51||68.0|56146251|Mwpd|6.6||0.1|68|56146241|Mwp|6.4||0.2|81|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=18583881\n\
29794751|earthquake|104170521|1000|2022-02-03T22:04:16.670000|16.3548|41.2653|7.1|0|AC|0.37|123.0|59|59|42|17|26.30|150.00|0.2|0.70|0.60|1.10|0.69|1.10|68.0|111725091|ML|2.2|AB|0.3|56|111725091|ML|2.2|AB|0.3|56|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=29794751\n\
33778101|earthquake|113221021|100|2023-01-01T00:00:39.090000|13.0685|42.8138|8.3|0|AD|0.13|195.0|18|11|7|4|4.30|37.29|0.1|0.60|0.40|0.50|0.58|0.50|68.0|121439591|ML|0.8|BB|0.2|6|121439591|ML|0.8|BB|0.2|6|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.870000|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951\n\
34440341|earthquake|121350241|1000|2023-03-22T21:00:39.650000|13.123|42.795|9.4|0|AA|0.22|46.0|57|57|29|28|4.30|79.50|0.04|0.30|0.20|0.20|0.24|0.20|68.0|130623531|ML|1.3|AC|0.4|54|130623531|ML|1.3|AC|0.4|54|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341\n\
37710741|earthquake|125544601|100|2024-02-25T18:59:28.170000|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741\n\
|explosion|||2025-01-31T00:06:35.345581|8.573055464|46.63163245|-1.46484375|||0.07692563465|144.1|0|0|0|0||||38.73|32.89|0.70|0.83|0.70|||MLhc|-0.562906728||0.2189145896|16||MLhc|-0.562906728||0.2189145896|16|smi:ch.ethz.sed/sc20a/Event/2025cdcacd","Sorting by time no limits no offset extended_text"),

(
"nodata=404&format=extended_text&orderby=time-asc&&limit=10&offset=1",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
18583881|earthquake|55046501|100|2018-04-02T13:40:33.880000|-63.0252|-20.5559|552.734|0||1.3964|51.4|0|0|0|0|||||||6.51||68.0|56146251|Mwpd|6.6||0.1|68|56146241|Mwp|6.4||0.2|81|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=18583881\n\
29794751|earthquake|104170521|1000|2022-02-03T22:04:16.670000|16.3548|41.2653|7.1|0|AC|0.37|123.0|59|59|42|17|26.30|150.00|0.2|0.70|0.60|1.10|0.69|1.10|68.0|111725091|ML|2.2|AB|0.3|56|111725091|ML|2.2|AB|0.3|56|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=29794751\n\
33778101|earthquake|113221021|100|2023-01-01T00:00:39.090000|13.0685|42.8138|8.3|0|AD|0.13|195.0|18|11|7|4|4.30|37.29|0.1|0.60|0.40|0.50|0.58|0.50|68.0|121439591|ML|0.8|BB|0.2|6|121439591|ML|0.8|BB|0.2|6|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.870000|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951\n\
34440341|earthquake|121350241|1000|2023-03-22T21:00:39.650000|13.123|42.795|9.4|0|AA|0.22|46.0|57|57|29|28|4.30|79.50|0.04|0.30|0.20|0.20|0.24|0.20|68.0|130623531|ML|1.3|AC|0.4|54|130623531|ML|1.3|AC|0.4|54|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341\n\
37710741|earthquake|125544601|100|2024-02-25T18:59:28.170000|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741\n\
|explosion|||2025-01-31T00:06:35.345581|8.573055464|46.63163245|-1.46484375|||0.07692563465|144.1|0|0|0|0||||38.73|32.89|0.70|0.83|0.70|||MLhc|-0.562906728||0.2189145896|16||MLhc|-0.562906728||0.2189145896|16|smi:ch.ethz.sed/sc20a/Event/2025cdcacd","Sorting by time no limits no offsetextended_text"),

(
"nodata=404&format=extended_text&orderby=time-asc&offset=3",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
33778101|earthquake|113221021|100|2023-01-01T00:00:39.090000|13.0685|42.8138|8.3|0|AD|0.13|195.0|18|11|7|4|4.30|37.29|0.1|0.60|0.40|0.50|0.58|0.50|68.0|121439591|ML|0.8|BB|0.2|6|121439591|ML|0.8|BB|0.2|6|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.870000|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951\n\
34440341|earthquake|121350241|1000|2023-03-22T21:00:39.650000|13.123|42.795|9.4|0|AA|0.22|46.0|57|57|29|28|4.30|79.50|0.04|0.30|0.20|0.20|0.24|0.20|68.0|130623531|ML|1.3|AC|0.4|54|130623531|ML|1.3|AC|0.4|54|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341\n\
37710741|earthquake|125544601|100|2024-02-25T18:59:28.170000|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741\n\
|explosion|||2025-01-31T00:06:35.345581|8.573055464|46.63163245|-1.46484375|||0.07692563465|144.1|0|0|0|0||||38.73|32.89|0.70|0.83|0.70|||MLhc|-0.562906728||0.2189145896|16||MLhc|-0.562906728||0.2189145896|16|smi:ch.ethz.sed/sc20a/Event/2025cdcacd","Sorting by time extended_text"),

(
"nodata=404&format=extended_text&orderby=magnitude-asc&includearrivals=true&includeallmagnitudes=true&includeallorigins=true",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
|explosion|||2025-01-31T00:06:35.345581|8.573055464|46.63163245|-1.46484375|||0.07692563465|144.1|0|0|0|0||||38.73|32.89|0.70|0.83|0.70|||MLhc|-0.562906728||0.2189145896|16||MLhc|-0.562906728||0.2189145896|16|smi:ch.ethz.sed/sc20a/Event/2025cdcacd\n\
33778101|earthquake|113221021|100|2023-01-01T00:00:39.090000|13.0685|42.8138|8.3|0|AD|0.13|195.0|18|11|7|4|4.30|37.29|0.1|0.60|0.40|0.50|0.58|0.50|68.0|121439591|ML|0.8|BB|0.2|6|121439591|ML|0.8|BB|0.2|6|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101\n\
34440341|earthquake|121350241|1000|2023-03-22T21:00:39.650000|13.123|42.795|9.4|0|AA|0.22|46.0|57|57|29|28|4.30|79.50|0.04|0.30|0.20|0.20|0.24|0.20|68.0|130623531|ML|1.3|AC|0.4|54|130623531|ML|1.3|AC|0.4|54|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341\n\
29794751|earthquake|104170521|1000|2022-02-03T22:04:16.670000|16.3548|41.2653|7.1|0|AC|0.37|123.0|59|59|42|17|26.30|150.00|0.2|0.70|0.60|1.10|0.69|1.10|68.0|111725091|ML|2.2|AB|0.3|56|111725091|ML|2.2|AB|0.3|56|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=29794751\n\
37710741|earthquake|125544601|100|2024-02-25T18:59:28.170000|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.870000|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951\n\
18583881|earthquake|55046501|100|2018-04-02T13:40:33.880000|-63.0252|-20.5559|552.734|0||1.3964|51.4|0|0|0|0|||||||6.51||68.0|56146251|Mwpd|6.6||0.1|68|56146241|Mwp|6.4||0.2|81|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=18583881","Sorting by mag extended_text"),

(
"format=extended_text",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
|explosion|||2025-01-31T00:06:35.345581|8.573055464|46.63163245|-1.46484375|||0.07692563465|144.1|0|0|0|0||||38.73|32.89|0.70|0.83|0.70|||MLhc|-0.562906728||0.2189145896|16||MLhc|-0.562906728||0.2189145896|16|smi:ch.ethz.sed/sc20a/Event/2025cdcacd\n\
37710741|earthquake|125544601|100|2024-02-25T18:59:28.170000|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741\n\
34440341|earthquake|121350241|1000|2023-03-22T21:00:39.650000|13.123|42.795|9.4|0|AA|0.22|46.0|57|57|29|28|4.30|79.50|0.04|0.30|0.20|0.20|0.24|0.20|68.0|130623531|ML|1.3|AC|0.4|54|130623531|ML|1.3|AC|0.4|54|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.870000|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951\n\
33778101|earthquake|113221021|100|2023-01-01T00:00:39.090000|13.0685|42.8138|8.3|0|AD|0.13|195.0|18|11|7|4|4.30|37.29|0.1|0.60|0.40|0.50|0.58|0.50|68.0|121439591|ML|0.8|BB|0.2|6|121439591|ML|0.8|BB|0.2|6|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101\n\
29794751|earthquake|104170521|1000|2022-02-03T22:04:16.670000|16.3548|41.2653|7.1|0|AC|0.37|123.0|59|59|42|17|26.30|150.00|0.2|0.70|0.60|1.10|0.69|1.10|68.0|111725091|ML|2.2|AB|0.3|56|111725091|ML|2.2|AB|0.3|56|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=29794751\n\
18583881|earthquake|55046501|100|2018-04-02T13:40:33.880000|-63.0252|-20.5559|552.734|0||1.3964|51.4|0|0|0|0|||||||6.51||68.0|56146251|Mwpd|6.6||0.1|68|56146241|Mwp|6.4||0.2|81|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=18583881","Sorting by time desc (default) extended_text"),

(
"format=extended_text&orderby=time-asc",200,
"#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
18583881|earthquake|55046501|100|2018-04-02T13:40:33.880000|-63.0252|-20.5559|552.734|0||1.3964|51.4|0|0|0|0|||||||6.51||68.0|56146251|Mwpd|6.6||0.1|68|56146241|Mwp|6.4||0.2|81|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=18583881\n\
29794751|earthquake|104170521|1000|2022-02-03T22:04:16.670000|16.3548|41.2653|7.1|0|AC|0.37|123.0|59|59|42|17|26.30|150.00|0.2|0.70|0.60|1.10|0.69|1.10|68.0|111725091|ML|2.2|AB|0.3|56|111725091|ML|2.2|AB|0.3|56|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=29794751\n\
33778101|earthquake|113221021|100|2023-01-01T00:00:39.090000|13.0685|42.8138|8.3|0|AD|0.13|195.0|18|11|7|4|4.30|37.29|0.1|0.60|0.40|0.50|0.58|0.50|68.0|121439591|ML|0.8|BB|0.2|6|121439591|ML|0.8|BB|0.2|6|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101\n\
33938951|earthquake|119970261|1000|2023-01-18T08:46:11.870000|14.2052|34.8393|19.8|0|BD|0.25|316.0|33|33|27|6|132.60|447.90|0.42|4.90|2.20|2.20|4.91|2.20|68.0|129084441|ML|3.5|CB|0.2|22|129084441|ML|3.5|CB|0.2|22|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951\n\
34440341|earthquake|121350241|1000|2023-03-22T21:00:39.650000|13.123|42.795|9.4|0|AA|0.22|46.0|57|57|29|28|4.30|79.50|0.04|0.30|0.20|0.20|0.24|0.20|68.0|130623531|ML|1.3|AC|0.4|54|130623531|ML|1.3|AC|0.4|54|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341\n\
37710741|earthquake|125544601|100|2024-02-25T18:59:28.170000|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741\n\
|explosion|||2025-01-31T00:06:35.345581|8.573055464|46.63163245|-1.46484375|||0.07692563465|144.1|0|0|0|0||||38.73|32.89|0.70|0.83|0.70|||MLhc|-0.562906728||0.2189145896|16||MLhc|-0.562906728||0.2189145896|16|smi:ch.ethz.sed/sc20a/Event/2025cdcacd","Sorting by time ascending extended_text"),

(
"catalog=INGV&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=34440341&format=hypo71phs",200,
"NRCA P 0Z230322210042.04       43.20 S 0    8.00.1                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:9.795,HHN:6.13,HNE:9.51,HNN:5.031\n\
SIB3 P 0Z230322210043.33       45.50 S 1                                      EHZ7F--    EVID:34440341,ORID:121350241,V:1000\n\
SIB1 P 0Z230322210043.67       46.30 S 0                                      EHZ7F--    EVID:34440341,ORID:121350241,V:1000\n\
SIB2 P 0Z230322210043.84       46.60 S 0                                      EHZ7F--    EVID:34440341,ORID:121350241,V:1000\n\
MMO1 P 0Z230322210044.19       47.20 S 1                                      EHZIV--    EVID:34440341,ORID:121350241,V:1000\n\
FEMA P 1Z230322210044.28       46.80 S 1                                      HNZIV--    EVID:34440341,ORID:121350241,V:1000\n\
GAVE P 0Z230322210044.62       48.10 S 1    0.70.2                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.804,EHN:0.69,HNE:0.826,HNN:0.263\n\
MTRA P 0Z230322210044.69       48.20 S 2    0.41.0                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.449,EHN:0.323,HNE:0.538,HNN:0.355\n\
LNSS P 1Z230322210044.70       48.00 S 2    0.30.2                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.301,HHN:0.293,HNE:0.27,HNN:0.284\n\
MTCL P 1Z230322210044.80       48.20 S 2                                      HGZIT--    EVID:34440341,ORID:121350241,V:1000\n\
SMA1 P 0Z230322210045.10       48.90 S 1    0.20.5                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.203,EHN:0.182\n\
FDMO P 0Z230322210045.25       49.00 S 1    0.20.2                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.131,HHN:0.204\n\
CESI P 0Z230322210045.68       50.10 S 1                                      HNZIV--    EVID:34440341,ORID:121350241,V:1000\n\
CSP1 P 0Z230322210046.34       51.10 S 1                                      EHZIV--    EVID:34440341,ORID:121350241,V:1000\n\
RM33 P 0Z230322210046.40       51.00 S 1    0.10.6                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.113,EHN:0.081,HNE:2.312,HNN:1.923\n\
GUMA P 0Z230322210046.80       51.90 S 1    0.30.3                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.301,HHN:0.297\n\
CAMP P 1E230322210046.86       51.89 S 2                                      HHEIV--    EVID:34440341,ORID:121350241,V:1000\n\
MF5  P 1N230322210046.88       52.32 S 2                                      EHNIV--    EVID:34440341,ORID:121350241,V:1000\n\
MML1 P 0Z230322210046.89       52.10 S 2    0.10.8                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.124,EHN:0.096,HNE:0.183,HNN:0.305\n\
ARRO P 2Z230322210047.14                    0.11.0                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.07,EHN:0.086\n\
TERO P 1Z230322210047.68       53.90 S 2    0.10.2                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.082,HHN:0.071,HNE:0.226,HNN:0.296\n\
SAP2 P 2E230322210047.69       54.15 S 2                                      EHEIV--    EVID:34440341,ORID:121350241,V:1000\n\
MOMA P 1Z230322210048.26       55.00 S 2    0.10.2                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.092,HHN:0.014,HNE:0.235,HNN:0.313\n\
ASSB P 0Z230322210048.28       54.50 S 2    0.10.1                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.056,HHN:0.054\n\
GIGS P 1Z230322210049.04       56.20 S 2    0.01.0                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.016,HHN:0.012\n\
ATCC P 1Z230322210050.17       58.00 S 2    0.00.2                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.043,EHN:0.054,HNE:0.193,HNN:0.218\n\
EL6  P 1Z230322210050.46       58.50 S 2    0.10.1                            EHZIV--    EVID:34440341,ORID:121350241,V:1000,EHE:0.074,EHN:0.067\n\
SSFR P 2Z230322210053.36       63.58 S 2    0.11.0                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.069,HHN:0.05,HNE:0.296,HNN:0.25\n\
ARVD P 2Z230322210053.95       64.10 S 3    0.00.3                            HHZIV--    EVID:34440341,ORID:121350241,V:1000,HHE:0.021,HHN:0.012\n\
 ","Event in hypo71phs format with accelerometers"),

(
"catalog=INGV&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=29794751&format=hypo71phs",200,
"MRVN PD0Z220203220422.09       25.67 S 1    0.91.0                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.64,HHN:1.065\n\
AMUR P 1Z220203220425.03       30.89 S 2    0.60.2                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.643,HHN:0.506,HNE:0.55,HNN:0.529\n\
CAPA P 1Z220203220425.43       32.19 S 1    0.20.1                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HNE:0.178,HNN:0.152\n\
OT15 P 2Z220203220425.90       32.21 S 2                                      EHZOT--    EVID:29794751,ORID:104170521,V:1000\n\
PALZ P 1Z220203220425.93       32.76 S 2    0.70.6                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.674,HHN:0.658\n\
OT12 PU0Z220203220426.63       33.67 S 1    0.30.9                            EHZOT--    EVID:29794751,ORID:104170521,V:1000,EHE:0.285,EHN:0.284\n\
MSAG P 1Z220203220427.87       37.01 S 2    0.40.8                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.219,HHN:0.563,HNE:0.559,HNN:1.347\n\
OT07 P 1Z220203220428.33       36.55 S 1                                      EHZOT--    EVID:29794751,ORID:104170521,V:1000\n\
ACER P 1Z220203220428.78       37.16 S 2    1.30.4                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:1.93,HHN:0.711,HNE:1.87,HNN:0.729\n\
OT05 P 1Z220203220429.52       40.08 S 1    0.21.2                            EHZOT--    EVID:29794751,ORID:104170521,V:1000,EHE:0.009,EHN:0.453\n\
OT13 P 1Z220203220429.60       39.66 S 2    2.10.8                            EHZOT--    EVID:29794751,ORID:104170521,V:1000,EHE:1.614,EHN:2.64\n\
SGRT P 1Z220203220429.65       40.03 S 1    0.71.0                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.781,HHN:0.639\n\
MIGL P 1Z220203220429.90       39.73 S 2    1.70.6                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:1.173,HHN:2.185\n\
MATE P 1Z220203220430.02       39.37 S 2    0.50.5                            HHZGE--    EVID:29794751,ORID:104170521,V:1000,HHE:0.52,HHN:0.532\n\
OT03 P 1Z220203220430.24       41.14 S 1                                      EHZOT--    EVID:29794751,ORID:104170521,V:1000\n\
OT14 P 1Z220203220430.80       41.67 S 2    1.21.1                            EHZOT--    EVID:29794751,ORID:104170521,V:1000,EHE:1.14,EHN:1.283\n\
NOCI P 1Z220203220431.06       41.46 S 1    0.50.3                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.551,HHN:0.531,HNE:0.524,HNN:0.514\n\
OT04 P 2Z220203220431.06                                                      EHZOT--    EVID:29794751,ORID:104170521,V:1000\n\
SGTA P 3E220203220431.25                                                      HNEIV--    EVID:29794751,ORID:104170521,V:1000\n\
AVG3 P 1Z220203220431.30                                                      HNZIX01    EVID:29794751,ORID:104170521,V:1000\n\
PZUN P 2Z220203220431.72                                                      HNZIV--    EVID:29794751,ORID:104170521,V:1000\n\
APRC P 1Z220203220432.28                                                      HHZIV--    EVID:29794751,ORID:104170521,V:1000\n\
RDM3 P 2Z220203220432.39                                                      HHZIX02    EVID:29794751,ORID:104170521,V:1000\n\
PTRP P 2Z220203220432.76                    0.50.5                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.345,HHN:0.597\n\
PGN3 P 2Z220203220433.01                    0.20.8                            HHZIX02    EVID:29794751,ORID:104170521,V:1000,HHE:0.24,HHN:0.17\n\
OT11 P 3Z220203220433.06                    0.50.4                            EHZOT--    EVID:29794751,ORID:104170521,V:1000,EHE:0.408,EHN:0.526\n\
CLT3 P 2Z220203220433.40                                                      EHZIX02    EVID:29794751,ORID:104170521,V:1000\n\
SCL3 P 2Z220203220433.67                    0.40.8                            EHZIX02    EVID:29794751,ORID:104170521,V:1000,EHE:0.347,EHN:0.414\n\
MRLC P 2Z220203220433.81                    0.40.5                            HNZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.292,HHN:0.544\n\
MASS P 2Z220203220433.88                                                      HHZOT--    EVID:29794751,ORID:104170521,V:1000\n\
CRAC P 2Z220203220434.03                    0.60.6                            EHZIV--    EVID:29794751,ORID:104170521,V:1000,EHE:0.581,EHN:0.673\n\
CAFE P 3Z220203220434.40                                                      HNZIV--    EVID:29794751,ORID:104170521,V:1000\n\
SSB3 P 2Z220203220434.45                                                      HHZIX02    EVID:29794751,ORID:104170521,V:1000\n\
MCEL P 2Z220203220436.21                    0.40.8                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HNE:0.371,HNN:0.33\n\
MELA P 3Z220203220436.39                    0.50.6                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.555,HHN:0.408\n\
TAR1 P 2Z220203220436.40                                                      HHZOT--    EVID:29794751,ORID:104170521,V:1000\n\
MTSN P 1Z220203220436.80                    0.11.0                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.113,HHN:0.124\n\
CDRU P 2Z220203220436.88                                                      HHZIV--    EVID:29794751,ORID:104170521,V:1000\n\
TREM P 2Z220203220437.61                                                      HHZIV--    EVID:29794751,ORID:104170521,V:1000\n\
SIRI P 1Z220203220437.91                    0.10.7                            HHZIV--    EVID:29794751,ORID:104170521,V:1000,HHE:0.135,HHN:0.116\n\
GATE P 3Z220203220438.20                                                      HHZIV--    EVID:29794751,ORID:104170521,V:1000\n\
BSSO P 2Z220203220441.73                                                      HHZIV--    EVID:29794751,ORID:104170521,V:1000\n\
 ","Event in hypo71phs format with only accelerometers amplitudes"),


#format is extended_text
# (
# "catalog=INGV&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=37710741&includeallorigins=true&includeallmagnitudes=false&format=extended_text",200,
# "#event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source\n\
# 37710741|earthquake|125544601|100|2024-02-25T18:59:28.17|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|source","Event with more than origin, asking for catalog extended_text"),

# #event_id|event_type|origin_id|version|ot|lon|lat|depth|fixed_depth|origin_Q|rms|gap|nph_tot|nph_tot_used|nph_p_used|nph_s_used|min_dist_km|max_dist_km|err_ot|err_lon_km|err_lat_km|err_depth_km|err_h_km|err_z_km|confidence_level|magnitud_id|magnitude_type|magnitude_value|magnitude_Q|magnitude_err|magnitude_ncha_used|pref_magnitud_id|pref_magnitude_type|pref_magnitude_value|pref_magnitude_Q|pref_magnitude_err|pref_magnitude_ncha_used|source
# 37710741|earthquake|125544601|100|2024-02-25T18:59:28.17|10.2143|44.6298|10.6|0|AA|0.4|76.0|126|34|23|11|8.30|110.89|0.11|0.70|1.00|0.90|0.93|0.90|68.0|135233531|ML|3.1|AC|0.3|216|135233531|ML|3.1|AC|0.3|216|20240225-185928__37710741__INGV-EVENT.xml
]


testdataerrors =[
(
"nodata=404&migmag=0.1&maxmag=3.6&mincepth=8.0&maxdepth=19.9&format=xml&orderby=time-asc&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3&&limit=1",
400,
'Error 400: Bad request\n\nSyntax Error in Request\n\nUnknown parameter migmag',
"Query 1"),
(
"nodata=404&minmag=0.1&maxmag=3.6&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude&includearrivals=false&includeallmagnitudes=false&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3&limit=0&offset=2",400,
"Error 400: Bad request\n\nSyntax Error in Request\n\n","Limit out of bound"),
(
"catalog=SED&nodata=404&minmag=0.1&maxmag=3.6&limit=100&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude-asc&includearrivals=false&includeallmagnitudes=true&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3",404,
"Error 404 - no matching events found","No events in this catalog"),

(
"contributor=SED&nodata=404&minmag=0.1&maxmag=3.6&limit=100&mindepth=8.0&maxdepth=19.9&format=text&orderby=magnitude-asc&includearrivals=false&includeallmagnitudes=true&includeallorigins=false&minlat=34&maxlat=43&minlon=13&maxlon=14.3",404,
"Error 404 - no matching events found","No events in this catalog"),

(
"eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33778101&includeallorigins=true&includeallmagnitudes=false&format=text&contributor=INGGV&nodata=404",404,
"Error 404 - no matching events found","No event match in this (fake) catalog"),

(
"?catalog=INGV&eventid=smi:webservices.ingv.it/fdsnws/event/1/query?eventId=33938951&includeallorigins=true&includeallmagnitudes=false&format=xml&asofdate=2026-04-1400&nodata=404",400,
"Error 400: Bad request\n\nSyntax Error in Request\n\n","Error in asofdate format"
)

]


testendpoints = [

("/fdsnws/event/1/",200,
'<html xmlns="http://www.w3.org/1999/xhtml" xmlns:wadl="http://wadl.dev.java.net/2009/02" xmlns:xs="http://www.w3.org/2001/XMLSchema">',
"Application root","startswith"),

("/fdsnws/event/1/application.wadl",200,
'<?xml version="1.0" encoding="UTF-8"?>\n\
<application xmlns="http://wadl.dev.java.net/2009/02" xmlns:q="http://quakeml.org/xmlns/quakeml/1.2" xmlns:xs="http://www.w3.org/2001/XMLSchema">',
"application.wadl","startswith"),

("/fdsnws/event/1/contributors", 200,
 '<?xml version="1.0" encoding="UTF-8"?>\n\
<Contributors>',
 "Contributors", "startswith"),

("/fdsnws/event/1/catalogs", 200,
 '<?xml version="1.0" encoding="UTF-8"?>\n\
<Catalogs>',
 "Catalogs", "startswith"),

("/fdsnws/event/1/management/databases_info", 200,
 '<?xml version="1.0" encoding="UTF-8"?>\n\
<databases>',
 "databases_info entry_point", "startswith"),

#
# ("/fdsnws/event/1/swagger.json",200,
# '{"openapi":"3.0.1","info":{"title":"INGV FDSNWS event Web Service Documentation",',
# "application swagger entry point","startswith"),


("/fdsnws/event/1/version/",200,
'1.69.1',"API Version","startswith"),

("/fdsnws/event/1/settings",200,
'<?xml version="1.0" encoding="UTF-8"?>',"Settings in xml","startswith"),

("/fdsnws/event/1/query/version/a=1&b=2",400,
'Error 400: Bad request\n\
\n\
Syntax Error in Request\n\
\n\
Usage details are available from /fdsnws/event/1/\n\
\n\
Request:\n',"Basex do not fail with Intercept Jetty Error 500 parsing parameters in bad paths err:XPST0003 Invalid character (=) in entity name","startswith"),

("/fdsnws/event/1/querry",400,
'Error 400: Bad request\n\
\n\
Syntax Error in Request\n\
\n\
Usage details are available from /fdsnws/event/1/\n\
\n\
Request:\n\
\n',"Intercept Error XPTY0004: The actual cardinality for parameter 1 does not match the cardinality","startswith"),
#
# ##TODO move in XML based test
# ("/fdsnws/event/1/",200,
# '<?xml version="1.0" encoding="UTF-8"?>\n\
# <html xmlns="http://www.w3.org/1999/xhtml" ',
# "application entry point translated from xslt","startswith"),
#

#TODO TEST doppio identifier e gestione errore

]


testdataio = [
# ("provider=INGV&net=*&erase=true","test/data/Station/",200,
# '',
# "DELETE_MULTI" , "DELETE ALL INGV station present in DB [NetCache]"),
(
"20230101-000039__33778101__INGV-EVENT.xml","test/data/EventDB/history/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 1  first version in database"),

(
"20230101-000039__33778101__INGV-EVENT.xml","test/data/EventDB/history/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"DELETE" , "DELETE event 1  all version in database"),

(
"20230101-000039__33778101__INGV-EVENT.xml","test/data/EventDB/history/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 1  first version in database"),

(
"20230101-000039__33778101__INGV-EVENT.xml","test/data/EventDB/history/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"ERASE" , "Erase event 1  all version in database"),

(
"20230101-000039__33778101__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=false",200,
'',
"PUT" , "PUT event 1 second version in database"),

(
"20230118-084611__33938951__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 2 in database"),

(
"20230118-084611__33938951__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 2 in database again"),

(
"20230118-084611__33938951__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"ERASE" , "Erase event 2  all version in database"),

(
"NO-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",204,
'',
"ERASE" , "Erase bogus event in database"),

(
"20230118-084611__33938951__INGV-EVENT.xml","test/data/EventDB/","?dbname=DBFake&catalog=BOH&upindex=true",204,
'',
"ERASE" , "Erase event 2 in fake database must fail"),

(
"20230118-084611__33938951__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 2 in database a second time"),

(
"20180402-134033__18583881__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 3 in database 1"),

(
"20240225-185928__37710741__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 4 in database 1"),

(
"20230322_210057__34440341__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 5 in database 1"),

(
"20220203-220416__29794751__INGV-EVENT.xml","test/data/EventDB/","?dbname=TestDB_1&catalog=INGV&upindex=true",200,
'',
"PUT" , "PUT event 6 in database 1"),

(
"20250131-000645_2025cdcacd__ETHZ-EVENT.xml","test/data/EventDB/","?dbname=TestDB_2&catalog=SED&upindex=true",200,
'',
"PUT" , "PUT one explosion in the second database"),
# TODO add PUT in non-existent database

]

############################################# END DATA FOR TEST #############################################

# function to read configuration
def history():
    filename = 'repo/it/ingv/webservices/fdsnws/config/settings.xml'
    root = ET.parse(filename)
    for history in root.findall('history'):
        print('History value:' + history.text )
    # The last one, should be unique
    return history.text.lower()


#############################################################################################################

@pytest.mark.parametrize(
    "name,path,dbname,expected_status_code,expected_content,action,comment", testdataio
)

def test_io(name,path,dbname,expected_status_code,expected_content,action,comment,host,basicAuth):

    webservicepath="http://"+host+"/fdsnws/event/1/event/"+dbname+"&filename="+name
    #filename="test/data/Station/"+ name
    filename = path + name
    #files = {'file' : (filename, open(filename, 'rb'), 'application/xml')}
    if action == 'PUT':
        print("Inserting: " + name + " in " + webservicepath)
        response = requests.put(url=webservicepath,data=open(filename, 'rb'),headers={"Content-Type":"text/xml"}, auth = basicAuth , allow_redirects=True)
        #for resp in response.history:
        #   print(resp.status_code, resp.url)
    elif action == 'DELETE':
        print("Deleting: " + name + " in " + webservicepath)
        response = requests.delete(url=webservicepath,  auth=basicAuth, allow_redirects=True)
    elif action == 'DELETE_MULTI':
        print("Deleting: " + name + " in " + webservicepath)
        response = requests.delete(url=webservicepath+name, auth=basicAuth)
    elif action == 'ERASE' and history() == 'true':
        print("Erasing: " + name + " in " + webservicepath+'&erase=true')
        response = requests.delete(url=webservicepath+'&erase=true',  auth=basicAuth)
    elif action == 'ERASE' and history() == 'false':
        print("Database does not erase downgrading to delete: " + name + " in " + webservicepath)
        response = requests.delete(url=webservicepath,  auth=basicAuth)

    print("***Expected**")
    print(response.text)
    print("+++Response+++")
    print(response.text)
    print("-----")

    #print(main.diff_texts(ET.tostring(response_tree, encoding=None, method='c14n2'),ET.tostring(expected_content_tree, encoding=None, method='c14n2')))
    #print(ET.canonicalize(response_tree))
    assert response.status_code == expected_status_code

#############################################################################################################


#############################################################################################################

@pytest.mark.parametrize(
    "query,expected_status_code,expected_content,comment", testdataxml
)

def test_eval(query,expected_status_code,expected_content,comment,host):
    print("Requesting: "+"http://"+host+"/fdsnws/event/1/query?" + query)
    response = requests.get( "http://"+host+"/fdsnws/event/1/query?" + query )
    print(response.text)
    response_tree = ET.fromstring(bytes(response.text, encoding='utf-8'))
    #
    # ET.strip_elements(response_tree,'{http://www.fdsn.org/xml/station/1}Created',with_tail=True)
    # ET.strip_elements(response_tree,'{http://www.fdsn.org/xml/station/1}Module',with_tail=True)
    # expected_content_tree = ET.fromstring(bytes(expected_content, encoding='utf-8'))
    with open(expected_content, 'r') as file :
        expected_content_string = file.read()
    expected_content_tree = ET.fromstring(bytes(expected_content_string, encoding='utf-8'))


    # ET.strip_elements(expected_content_tree,'{http://www.fdsn.org/xml/station/1}Created',with_tail=True)
    # ET.strip_elements(expected_content_tree,'{http://www.fdsn.org/xml/station/1}Module',with_tail=True)

    print("***Expected**")
    print(ET.tostring(expected_content_tree, encoding=None, method='c14n2'))
    print("+++Response+++")
    print(ET.tostring(response_tree, encoding=None, method='c14n2'))
    print("-----")
    print(main.diff_texts(ET.tostring(response_tree, encoding=None, method='c14n2'),ET.tostring(expected_content_tree, encoding=None, method='c14n2')))
    #print(ET.canonicalize(response_tree))
    assert response.status_code == expected_status_code
    # ONE TEST WILL FAIL    assert (main.diff_texts(ET.tostring(response_tree, encoding=None, method='c14n2'),ET.tostring(expected_content_tree, encoding=None, method='c14n2'))==[])

    #assert ET.tostring(response_tree) == ET.tostring(expected_content_tree)
    assert (ET.tostring(expected_content_tree, encoding=None, method='c14n2') == ET.tostring(response_tree, encoding=None, method='c14n2'))
    #assert  ET.canonicalize(expected_content_tree) == ET.canonicalize(response_tree) Is the same?
#    assert (ET.tostring(expected_content_tree, encoding=None, method='c14n2') == ET.tostring(response_tree, encoding=None, method='c14n2'))

#    assert (expected_content_tree.getchildren().sort() == response_tree.getchildren().sort())


#############################################################################################################


#############################################################################################################

@pytest.mark.parametrize(
    "query,expected_status_code,expected_content,comment", testdatatxt

)

def test_content(query,expected_status_code,expected_content,comment,host):
    response = requests.get( "http://"+host+"/fdsnws/event/1/query?" + query)
    assert (response.status_code == expected_status_code)
    assert (response.text == expected_content)

#############################################################################################################


#############################################################################################################

@pytest.mark.parametrize(
    "query,expected_status_code,expected_content,comment", testdataerrors

)

def test_errors(query,expected_status_code,expected_content,comment,host):
    response = requests.get( "http://"+host+"/fdsnws/event/1/query?" + query)
    assert (response.status_code == expected_status_code)
#Next assert check for the same string or for the first part if differences in tail
    assert (response.text.startswith(expected_content))

#############################################################################################################






#############################################################################################################

@pytest.mark.parametrize(
    "query,expected_status_code,expected_content,comment,match", testendpoints

)

def test_endpoint(query,expected_status_code,expected_content,comment,match,host):
    response = requests.get( "http://"+host + query)

    print("***Expected***")
    print(expected_content)
    print("+++Response+++")
    print(response.text)

    assert (response.status_code == expected_status_code)
    if match=='matches':
        assert (response.text == expected_content)
    elif match=='startswith':
        assert (response.text.startswith(expected_content))

#############################################################################################################


#############################################################################################################

# @pytest.mark.parametrize(
#     "name,path,expected_status_code,expected_content,action,comment", testidentifiersio
# )
#
# def test_identifiersio(name,path,expected_status_code,expected_content,action,comment,host,basicAuth):
#
#     webservicepath="http://"+host+"/fdsnws/station/1/query?"
#     #filename="test/data/Station/"+ name
#     filename = path + name
#     #files = {'file' : (filename, open(filename, 'rb'), 'application/xml')}
#     if action == 'PUT':
#         print("Inserting: " + name + " in " + webservicepath)
#         response = requests.put(url=webservicepath,data=open(filename, 'rb'),headers={"Content-Type":"application/octet-stream","filename":name}, auth = basicAuth , allow_redirects=True)
#         #for resp in response.history:
#         #   print(resp.status_code, resp.url)
#     elif action == 'DELETE':
#         print("Deleting: " + name + " in " + webservicepath)
#         response = requests.delete(url=webservicepath, headers={"filename" : name}, auth=basicAuth)
#     elif action == 'DELETE_MULTI':
#         print("Deleting: " + name + " in " + webservicepath)
#         response = requests.delete(url=webservicepath+name, auth=basicAuth)
#     elif action == 'ERASE' and history() == 'true':
#         print("Erasing: " + name + " in " + webservicepath+'erase=true')
#         response = requests.delete(url=webservicepath+'erase=true', headers={"filename" : name}, auth=basicAuth)
#     elif action == 'ERASE' and history() == 'false':
#         print("Database does not erase downgrading to delete: " + name + " in " + webservicepath)
#         response = requests.delete(url=webservicepath, headers={"filename" : name}, auth=basicAuth)
#
#     print("***Expected**")
#     print(response.text)
#     print("+++Response+++")
#     print(response.text)
#     print("-----")
#
#     #print(main.diff_texts(ET.tostring(response_tree, encoding=None, method='c14n2'),ET.tostring(expected_content_tree, encoding=None, method='c14n2')))
#     #print(ET.canonicalize(response_tree))
#     assert response.status_code == expected_status_code
#

#############################################################################################################


#############################################################################################################

# @pytest.mark.parametrize(
#     "query,expected_status_code,expected_content,comment,match", testidentifiers
#
# )
#
# def test_identifiers(query,expected_status_code,expected_content,comment,match,host):
#     response = requests.get( "http://"+host + query)
#
#     print("***Expected***")
#     print(expected_content)
#     print("+++Response+++")
#     print(response.text)
#
#     assert (response.status_code == expected_status_code)
#     if match=='matches':
#         assert (response.text == expected_content)
#     elif match=='startswith':
#         assert (response.text.startswith(expected_content))

#############################################################################################################


#############################################################################################################

# @pytest.mark.parametrize(
#     "name,path,expected_status_code,expected_content,action,comment", testidentifiersdupio
# )
#
# def test_identifiersdupio(name,path,expected_status_code,expected_content,action,comment,host,basicAuth):
#
#     webservicepath="http://"+host+"/fdsnws/station/1/query?"
#     #filename="test/data/Station/"+ name
#     filename = path + name
#     #files = {'file' : (filename, open(filename, 'rb'), 'application/xml')}
#     if action == 'PUT':
#         print("Inserting: " + name + " in " + webservicepath)
#         response = requests.put(url=webservicepath,data=open(filename, 'rb'),headers={"Content-Type":"application/octet-stream","filename":name}, auth = basicAuth , allow_redirects=True)
#         #for resp in response.history:
#         #   print(resp.status_code, resp.url)
#     elif action == 'DELETE':
#         print("Deleting: " + name + " in " + webservicepath)
#         response = requests.delete(url=webservicepath, headers={"filename" : name}, auth=basicAuth)
#     elif action == 'DELETE_MULTI':
#         print("Deleting: " + name + " in " + webservicepath)
#         response = requests.delete(url=webservicepath+name, auth=basicAuth)
#     elif action == 'ERASE' and history() == 'true':
#         print("Erasing: " + name + " in " + webservicepath+'erase=true')
#         response = requests.delete(url=webservicepath+'erase=true', headers={"filename" : name}, auth=basicAuth)
#     elif action == 'ERASE' and history() == 'false':
#         print("Database does not erase downgrading to delete: " + name + " in " + webservicepath)
#         response = requests.delete(url=webservicepath, headers={"filename" : name}, auth=HTTPbasicAuth('admin', 'admin'))
#
#     print("***Expected**")
#     print(response.text)
#     print("+++Response+++")
#     print(response.text)
#     print("-----")
#
#     #print(main.diff_texts(ET.tostring(response_tree, encoding=None, method='c14n2'),ET.tostring(expected_content_tree, encoding=None, method='c14n2')))
#     #print(ET.canonicalize(response_tree))
#     assert response.status_code == expected_status_code
#
#############################################################################################################


#############################################################################################################


# @pytest.mark.parametrize(
#     "query,expected_status_code,expected_content,comment,match", testidentifiersdup
#
# )
#
# def test_identifiersdup(query,expected_status_code,expected_content,comment,match,host):
#     response = requests.get( "http://"+host + query)
#
#     print("***Expected***")
#     print(expected_content)
#     print("+++Response+++")
#     print(response.text)
#
#     assert (response.status_code == expected_status_code)
#     if match=='matches':
#         assert (response.text == expected_content)
#     elif match=='startswith':
#         assert (response.text.startswith(expected_content))

############################################################################################################

#### BEWARE TEST ON MINRADIUSKM DISPLAY NO CONTROL ON TEXT SORTING. ####
#### TODO FIX SORTING AND CHANGE TEST ACCORDINLGY                   ####

