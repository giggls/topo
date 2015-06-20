DROP VIEW IF EXISTS topo_view_osm_polygon;
CREATE VIEW topo_view_osm_polygon as select
osm_id,
"natural" as nature,
tags->'barrier' as barrier,
tags->'public_transport' as public_transport,
landuse,
military,
place,
waterway,
tags->'sport' as sport,
highway,
tags->'two_sided' as twoside,
railway,
tags->'name' as name,
tags->'short_name' as shortname,
leisure,
amenity,
aeroway,
tags->'wood' as wood,
tags->'ruins' as ruins,
tags->'abandoned' as abandoned,
building,
tourism,
power,
tags->'generator:source' as generator_source,
tags->'ref' as ref,
tags->'region:type' as region_type,
z_order,
man_made,
CAST(way_area as float) as area,
way
from planet_osm_polygon;
grant select on topo_view_osm_polygon to public;

DROP VIEW IF EXISTS topo_view_osm_area;
CREATE VIEW topo_view_osm_area as select
osm_id,
"natural" as nature,
tags->'public_transport' as public_transport,
landuse,
military,
place,
waterway,
tags->'sport' as sport,
highway,
railway,
tags->'name' as name,
tags->'short_name' as shortname,
leisure,
amenity,
aeroway,
tags->'wood' as wood,
tags->'ruins' as ruins,
tags->'abandoned' as abandoned,
tourism,
power,
tags->'ref' as ref,
tags->'region:type' as region_type,
z_order,
CAST(way_area as float) as area,
way
from planet_osm_polygon where building is null;
grant select on topo_view_osm_area to public;

DROP VIEW IF EXISTS topo_view_osm_line;
CREATE VIEW topo_view_osm_line as select
way,osm_id,waterway,highway,tags->'two_sided' as twoside,tags->'ref' as ref,tags->'name' as name,tags->'short_name' as shortname,leisure,tags->'sport' as sport ,tags->'bridge' as bridge,tags->'tunnel' as tunnel,
railway,aeroway,z_order,man_made,tags->'layer' as layer,tags->'surface' as surface,tags->'tracktype' as tracktype,
aerialway,power,route,tags->'oneway' as oneway,tags->'motorcar' as motorcar,tags->'access' as access,tags->'bicycle' as bike,
tags->'trail_visibility' as trail_visibility,tags->'foot' as foot,tags->'vehicle' as vehicle,tags->'motor_vehicle' as motor_vehicle,
tags->'stream' as stream,tags->'stream:type' as streamtype,tags->'intermittent' as intermittent,tags->'sac_scale' as sac_scale,tags->'ruins' as ruins,
tags->'public_transport' as public_transport,"natural" as nature,tags->'barrier' as barrier,width,boundary,tags->'admin_level' as admin_level from planet_osm_line;
grant select on topo_view_osm_line to public;

DROP VIEW IF EXISTS topo_view_osm_poi;
CREATE VIEW topo_view_osm_poi as select
way,osm_id,historic,tourism,ele,
coalesce(tags->'name'||'|'||trim(trailing ',' from replace(TO_CHAR(ele,'FM9999D99'), '.', ',')),tags->'name',trim(trailing ',' from replace(TO_CHAR(ele,'FM9999D99'), '.', ','))) as elename,
place,tags->'name' as name,tags->'short_name' as shortname,amenity,tags->'religion' as religion,
tags->'population' as population,landuse,military,aeroway,tags->'service' as service,railway,tags->'sport' as sport,
leisure,tags->'addr:housenumber' as housenumber, "natural" as nature,tags->'barrier' as barrier,tags->'access' as access,tags->'bicycle' as bike,tags->'foot' as foot,
tags->'information' as information,tags->'ruins' as ruins from planet_osm_point;
grant select on topo_view_osm_poi to public;

DROP VIEW IF EXISTS topo_view_osm_roads;
CREATE VIEW topo_view_osm_roads as select
way,osm_id,highway,waterway,aerialway,tags->'ref' as ref,tags->'name' as name,tags->'short_name' as shortname,tags->'bridge' as bridge,tags->'tunnel' as tunnel,railway,z_order,boundary,tags->'admin_level' as admin_level from planet_osm_roads;
grant select on topo_view_osm_roads to public;

DROP VIEW IF EXISTS topo_view_osm_peak;
CREATE VIEW topo_view_osm_peak as SELECT
   poi.osm_id,
   poi.tags->'name' as name,
   poi.ele,
   coalesce(poi.tags->'name'||'|'||trim(trailing ',' from replace(TO_CHAR(ele,'FM9999D99'), '.', ',')),poi.tags->'name',trim(trailing ',' from replace(TO_CHAR(poi.ele,'FM9999D99'), '.', ','))) as elename,
   poi.way,
   COALESCE(ST_DISTANCE(poi.way, (SELECT geom FROM contours WHERE (contours.height>=(10*ROUND(poi.ele/10.0)) AND st_dwithin(contours.geom,poi.way,50000)) ORDER BY geom <-> poi.way LIMIT 1)),50000) as dominanz
FROM
   planet_osm_point poi
WHERE
   poi."natural" = 'peak' AND
   poi.ele is not NULL;

grant select on topo_view_osm_peak to public;
