
all: map

topo.map: topo.map.def topo.map.in
	scripts/genmap topo.map.in topo.map.def > topo.map

views: .views-stamp
.views-stamp: create-views.sql
	psql -f create-views.sql osm
	touch .views-stamp

map:	topo.map .views-stamp
	rm -f testmap.png
	# Weingarten "gailbumber" (Test Flussbreite)
	# shp2img -map_debug 2 -m topo.map -o testmap.png -e 949806.513472 6283582.347211 949959.387528 6283735.221268 -s 256 256 -l default

	# La Gomera (Test Meer)
	# shp2img -map_debug 2 -m topo.map -o testmap.png -e -1931105.082597 3261720.870985 -1926213.112786 3259274.886080 -s 1024 1024 -l default

	# Gipfeltest zoomlevel 14
	# shp2img -map_debug 2 -m topo.map -o testmap.png -e 1433347.154404 6014676.881704 1438239.124214 6019568.851514 -s 512 512 -l default

	# Gipfeltest zoomlevel 13
	# shp2img -map_debug 2 -m topo.map -o testmap.png -e 1433347.154404 6012230.896799 1443131.094024 6022014.836419 -s 512 512 -l default

	# Gipfeltest zoomlevel 12 (Steinernes Meer)
	#shp2img -map_debug 2 -m topo.map -o testmap.png -e 1428455.184593 6007338.926989 1448023.063834 6026906.806230 -s 512 512 -l default
	
	# Lowzoom (7) Grenzen und Co.
	#shp2img -map_debug 2 -m topo.map -o testmap.png -e 626172.135712 6261721.357122 939258.203568 6574807.424978 -s 256 256 -l default
	
	# Lowzoom (6) Grenzen und Co.
	# shp2img -map_debug 2 -m topo.map -o testmap.png -e 626172.135712 6261721.357122 1252344.271424 6887893.492834 -s 256 256 -l default
	
	# Test Hoehenlinien
	shp2img -map_debug 2 -m topo.map -o testmap.png -e 1429766.389046 6033695.311644 1434596.541751 6038257.581461 -s 1024 1024 -l default
		
	display testmap.png
	rm -f testmap.png
	
clean:
	rm -f topo.map .views-stamp
