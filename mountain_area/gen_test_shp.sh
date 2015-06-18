#!/bin/bash

rm -f arc?.??? poly.??? cent.???


####### shapefile with raw arcs
ogr2ogr -f 'ESRI Shapefile' -lco ENCODING=UTF-8 arc1.shp PG:dbname=osm -sql "select tags->'name' as name,ST_CurveToLine(arc_from_poly(way),100)  from mountain_area"

####### shapefile with interpolated circle center points
#ogr2ogr -f 'ESRI Shapefile' -lco ENCODING=UTF-8 cent.shp PG:dbname=osm -sql "select tags->'name' as name,ST_CurveToLine(get_circle_center(arc_from_poly(way)),100)  from mountain_area"

####### ####### shapefile with trimmed and segmented arcs
# use this to add angles to shapefile
#ogr2ogr -f 'ESRI Shapefile' -lco ENCODING=UTF-8 arc2.shp PG:dbname=osm -sql "select tags->'name' as name,(TO_CHAR((180/pi())*get_angle(get_circle_center(arc_from_poly(way)),ST_PointN(arc_from_poly(way),1),ST_PointN(arc_from_poly(way),3)),'FM999 (') || TO_CHAR((180/pi())*get_angle(get_circle_center(arc_from_poly(way)),ST_PointN(arc_from_poly(way),1),ST_PointN(arc_from_poly(way),2)),'FM999)')) as winkel,trim_arc(arc_from_poly(way),20,5)  from mountain_area"
# same without angles
ogr2ogr -f 'ESRI Shapefile' -lco ENCODING=UTF-8 arc2.shp PG:dbname=osm -sql "select tags->'name' as name,trim_arc(arc_from_poly(way),20,5)  from mountain_area"

####### ####### shapefile with raw polygons
ogr2ogr -f 'ESRI Shapefile' -lco ENCODING=UTF-8 poly.shp PG:dbname=osm -sql "select tags->'name' as name,ST_CurveToLine(way,100)  from mountain_area"

