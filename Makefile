
all: map

topo.map: topo.map.def topo.map.in
	scripts/genmap topo.map.in topo.map.def > topo.map

views: .views-stamp
.views-stamp: create-views.sql
	psql -f create-views.sql osm
	touch .views-stamp

map:	topo.map .views-stamp
	rm -f testmap.png
	shp2img -map_debug 2 -m topo.map -o testmap.png -e 1443131.094024 6024460.821324 1452915.033645 6034244.760945 -s 1024 1024 -l default
	xv testmap.png
	rm -f testmap.png
	
clean:
	rm -f topo.map .views-stamp
