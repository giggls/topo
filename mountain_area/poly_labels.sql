/*

generate an arc for labeling a polygon, according to the description
from OSM Wiki
http://wiki.openstreetmap.org/wiki/User:Maxbe/Kartenversuch#Beschriftung_von_Gebirgen

available functions:
arc_from_poly: calculate arc inside polygon
get_circle_center: calculate center of CIRCULARSTRING object
get_angle: calculate angle between two points based on origin
trim_arc: trim ends of arg and create linear interpolation
          using ST_CurveToLine according to the number of
          intervals given as parameter

(c) 2015 Sven Geggus <svn-osm@geggus.net> AGPL3+

*/

CREATE or REPLACE FUNCTION get_circle_center(circularobj geometry) RETURNS geometry AS $$
  DECLARE
    point geometry[3];
    yDelta0 double precision;
    xDelta0 double precision;
    yDelta1 double precision;
    xDelta1 double precision;
    Slope0 double precision;
    Slope1 double precision;
    cx double precision;
    cy double precision;
  BEGIN
    point[0]=ST_PointN(circularobj,1);
    point[1]=ST_PointN(circularobj,2);
    point[2]=ST_PointN(circularobj,3);
    yDelta0 = ST_Y(point[1])-ST_Y(point[0]);
    xDelta0 = ST_X(point[1])-ST_X(point[0]);
    yDelta1 = ST_Y(point[2])-ST_Y(point[1]);
    xDelta1 = ST_X(point[2])-ST_X(point[1]);
    Slope0 = yDelta0/xDelta0;
    Slope1 = yDelta1/xDelta1;

    cx = (Slope0*Slope1*(ST_Y(point[0]) - ST_Y(point[2])) + Slope1*(ST_X(point[0]) + ST_X(point[1]))- Slope0*(ST_X(point[1])+ST_X(point[2])) )/(2* (Slope1-Slope0) );
    cy = -1*(cx - (ST_X(point[0])+ST_X(point[1]))/2)/Slope0 +  (ST_Y(point[0])+ST_Y(point[1]))/2;

    RETURN ST_SetSRID(ST_MakePoint(cx, cy),ST_SRID(circularobj));
  END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;

CREATE or REPLACE FUNCTION get_angle(origin geometry, p0 geometry, p1 geometry) RETURNS double precision AS $$
  DECLARE
    ang1 double precision;
    ang2 double precision;
  BEGIN
    ang1=atan2(ST_Y(p0)-ST_Y(origin), ST_X(p0)-ST_X(origin));
    ang2=atan2(ST_Y(p1)-ST_Y(origin), ST_X(p1)-ST_X(origin));
    -- RAISE NOTICE 'ang1: % ang2: % ang1-ang2: %',(180.0/pi())*ang1,(180.0/pi())*ang2,(180.0/pi())*(ang1-ang2);
    RETURN ang1-ang2;
  END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;

CREATE or REPLACE FUNCTION arc_from_poly(polygon geometry) RETURNS geometry AS $$
  DECLARE
    point geometry;
    -- center point of polygon
    pcenter geometry;
    pcenter_x double precision;
    pcenter_y double precision;
    
    dist double precision;
    north geometry;
    east geometry;
    south geometry;
    west geometry;
    dnorth double precision DEFAULT 0;
    deast double precision DEFAULT 0;
    dsouth double precision DEFAULT 0;
    dwest double precision DEFAULT 0;
    cpoints geometry[];
    -- center point of circle
    center geometry[];
  BEGIN
    pcenter=ST_Centroid(polygon);
    pcenter_x=ST_X(pcenter);
    pcenter_y=ST_Y(pcenter);

    FOR point IN SELECT points.geom FROM ( SELECT (ST_DumpPoints(polygon)).* ) AS points LOOP
      dist=ST_Distance(point,pcenter);

      -- points north of pcenter
      IF (ST_Y(point) >  pcenter_y) THEN
        IF (dist >dnorth) THEN
          dnorth := dist;
          north = point;
        END IF;
      END IF;

      -- points east of pcenter
      IF (ST_X(point) >  pcenter_x) THEN
        IF (dist >deast) THEN
          deast := dist;
          east = point;
        END IF;
      END IF;

      -- points south of pcenter
      IF (ST_Y(point) <  pcenter_y) THEN
        IF (dist >dsouth) THEN
          dsouth := dist;
          south = point;
        END IF;
      END IF;

      -- points west of pcenter
      IF (ST_X(point) <  pcenter_x) THEN
        IF (dist >dwest) THEN
          dwest := dist;
          west = point;
        END IF;
      END IF;
    END LOOP;

    -- RAISE NOTICE 'c: %', ST_astext(pcenter);
    -- RAISE NOTICE 'n: %', ST_astext(north);
    -- RAISE NOTICE 'e: %', ST_astext(east);
    -- RAISE NOTICE 's: %', ST_astext(south);
    -- RAISE NOTICE 'w: %', ST_astext(west);

    -- now check if west <-> east or north <-> south is the longer distance
    cpoints[1]=pcenter;
    IF ((ST_Y(north)-ST_Y(south)) > (ST_X(east)-ST_X(west))) THEN
      -- RAISE NOTICE 'north-south is longest distance % %',ST_astext(north),ST_astext(south);
      cpoints[0]=north;
      cpoints[2]=south;
    ELSE
      -- RAISE NOTICE 'east-west is longest distance';
      cpoints[0]=west;
      cpoints[2]=east;
    END IF;
    
    -- currently there is no such thing as ST_MakeCurveLine
    -- https://trac.osgeo.org/postgis/ticket/1291
    -- Thus we use a workaround as suggested on
    -- http://gis.stackexchange.com/questions/16712/st-makeline-equivalent-for-circularstring-in-postgis
    RETURN ST_GeomFromEWKT(replace(ST_AsEWKT(ST_MakeLine(cpoints)),'LINESTRING','CIRCULARSTRING'));
  END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;

CREATE or REPLACE FUNCTION trim_arc(arc geometry, margin double precision, num_segments integer) RETURNS geometry AS $$
  DECLARE
  newarc geometry;
  center geometry;
  angle_end double precision;
  angle_centroid double precision;
  cpoints geometry[];
  BEGIN

    -- return if invalid margin has been given
    IF (margin <0) OR (margin >50) THEN
      RAISE NOTICE 'invalid margin: has to be between 0 and 50';
      RETURN NULL;
    END IF;
    -- margin is given in percent so multiply by 0.01 to get a factor
    margin := 0.01 * margin;

    center = get_circle_center(arc);
    angle_end = get_angle(center,ST_PointN(arc,1),ST_PointN(arc,3));
    -- RAISE NOTICE 'endpoint angle: %',(180.0/pi())*angle_end;
    /* We need to use the corresponding angle in case of different sinage
       and if the absolute value of the center angle is larger than
       the absolute value of the end angle.
       We also need to change signage of the angle in some of those cases
       (see code)
       A valid angle would be Stubaier Alpen -2127978
    */
    angle_centroid = get_angle(center,ST_PointN(arc,1),ST_PointN(arc,2));
    -- RAISE NOTICE 'centroid angle: %',(180.0/pi())*angle_centroid;
    IF (((angle_end < 0) AND (angle_centroid > 0)) OR ((angle_end > 0) AND (angle_centroid < 0))) THEN
      -- e.g. Türnitzer Alpen -2247622
      angle_end=-2*pi()+angle_end;
      -- RAISE NOTICE 'correction (different signage of angles) : %',(180.0/pi())*angle_end;
    ELSE
      IF (abs(angle_centroid) > abs(angle_end)) THEN
        IF (angle_end >0) THEN
          -- e.g. Plessur-Alpen -2505682
          angle_end=-2*pi()+angle_end;
          -- RAISE NOTICE 'correction (|c| > |e| positive values): %',(180.0/pi())*angle_end;
        ELSE
          -- e.g. Bjelašnica -4138017
          angle_end=2*pi()+angle_end;
          -- RAISE NOTICE 'correction (|c| > |e| negative values): %',(180.0/pi())*angle_end;
        END IF;
      END IF;
    END IF;
    -- number of elements for interpolation is based on quarter circle (pi/2)
    -- but we would like to have them based on the angle of our segment
    -- (1-2*margin)*angle_end    
    num_segments=round((num_segments*pi())/((1.0-2.0*margin)*abs(angle_end)*2.0));
    
    angle_end=margin*angle_end;
    cpoints[0]=ST_Rotate(ST_PointN(arc,1),-1*angle_end,ST_X(center),ST_Y(center));
    cpoints[2]=ST_Rotate(ST_PointN(arc,3),angle_end,ST_X(center),ST_Y(center));
    cpoints[1]=ST_PointN(arc,2);
    RETURN ST_CurveToLine(ST_GeomFromEWKT(replace(ST_AsEWKT(ST_MakeLine(cpoints)),'LINESTRING','CIRCULARSTRING')),num_segments);
  END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;

-- CREATE TYPE t_labeled_lines AS (label text,linestring geometry, pseudo_id bigint);

-- examples:
-- select (render_objects_from_polgon).* from (select render_objects_from_polgon(tags->'name',way,osm_id,20) from mountain_area where osm_id=-4138017) f;
-- select (render_objects_from_polgon).label,ST_AsText((render_objects_from_polgon).linestring) from
-- (select render_objects_from_polgon(tags->'name',way,osm_id,20) from mountain_area where osm_id=-4138017) f;

CREATE or REPLACE FUNCTION render_objects_from_polgon(label text, polygon geometry, osm_id bigint, margin double precision)
RETURNS SETOF t_labeled_lines as $$
DECLARE
  linestring geometry;
  len_label integer;
  i integer;
  point geometry;
  lastpoint geometry;
  curline geometry;
  pseudo_id bigint;
BEGIN
  -- RAISE NOTICE 'called for object: %',label;
  len_label = char_length(label);
  linestring = trim_arc(arc_from_poly(polygon),margin,len_label);
  -- shifting this by 20 bits should not conflict with osm-ids for a long time
  pseudo_id=osm_id<<20;
  i = 0;
  FOR point IN SELECT points.geom FROM ( SELECT (ST_DumpPoints(linestring)).* ) AS points LOOP
    IF (i > 0) THEN
      curline = ST_SetSRID(ST_Makeline(lastpoint,point),ST_SRID(polygon));
      RETURN NEXT (substr(label, i, 1), curline, pseudo_id);
    END IF;
    if (i = len_label) THEN
      EXIT;
    END IF;
    i = i + 1;
    pseudo_id =  pseudo_id +1;
    lastpoint = point;
  END LOOP;
  RETURN;
END;
$$ language 'plpgsql' IMMUTABLE;
