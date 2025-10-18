#!/bin/bash

# not set on shebang line anymore - to avoid ignoring the options on interpreted (bash -- '/path/to/file.bash') call
set -e -u

function _proc_cmdline() {
	local\
	 TEMP_SET_OPTION
	while [ ${#} -gt 0 ]; do
		if [[ "${1}" =~ ^--[A-Z][0-9A-Z_]{0,31}=\([^$=\;]*\)$ ]]; then
			TEMP_SET_OPTION="${1#--}"
			declare -a -g "${TEMP_SET_OPTION}"
		elif [[ "${1}" =~ ^--[A-Z][0-9A-Z_]{0,31}(\[[a-z0-9_]{1,32}\])=([^$]{0,255})$ ]]; then
			TEMP_SET_OPTION="${1#--}"
			declare -A -g "${TEMP_SET_OPTION}"
		elif [[ "${1}" =~ ^--[A-Z][0-9A-Z_]{0,31}=([^$]{0,255})$ ]]; then
			TEMP_SET_OPTION="${1#--}"
			declare -g "${TEMP_SET_OPTION}"
		else
			echo "ERROR: Invalid option: '${1}'" >&2
			exit 1
		fi
		shift 1
	done
}

declare\
 OSM_DATA_COUNTRY_CODE=''

_proc_cmdline "${@}"

declare\
 OSM_DATA_LANG_CODE="${OSM_DATA_COUNTRY_CODE}"\
 OSM_DATA_TABLES_SCHEMA="qoxm${OSM_DATA_COUNTY_CODE:+_country_${OSM_DATA_COUNTRY_CODE,,}}_$(date +'%Y%M%D')"

_proc_cmdline "${@}"

exec /usr/bin/cat -- <<66846bd11f2b4aa2b22067c21e20a45e
\\set ON_ERROR_ROLLBACK true
\\set ON_ERROR_STOP true
\\timing on

BEGIN TRANSACTION;

DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" CASCADE;

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" AS
WITH "qw_pl" AS (SELECT
	"tw1_po"."osm_id"::BIGINT,
	"tw1_po"."osm_timestamp"::TIMESTAMP AS "lastchange",
	(CASE
		WHEN (
		 ("tw1_po"."all_tags"->>'place' = 'city')
		 AND (
		  ("tw1_po"."all_tags"->>'is_capital' = 'country')
		  OR ("tw1_po"."all_tags"->>'admin_level' = '2')
		  OR (("tw1_po"."all_tags"->>'capital' = 'yes') AND ("tw1_po"."all_tags"->>'admin_level' IS NULL))
		 )
		) THEN 1005
		WHEN ("tw1_po"."all_tags"->>'place' = 'city') THEN 1001
		WHEN ("tw1_po"."all_tags"->>'place' = 'town') THEN 1002
		WHEN ("tw1_po"."all_tags"->>'place' = 'village') THEN 1003
		WHEN ("tw1_po"."all_tags"->>'place' = 'hamlet') THEN 1004
		WHEN ("tw1_po"."all_tags"->>'place' = 'suburb') THEN 1010
		WHEN ("tw1_po"."all_tags"->>'place' = 'island') THEN 1020
		WHEN ("tw1_po"."all_tags"->>'place' = 'farm') THEN 1030
		WHEN ("tw1_po"."all_tags"->>'place' = 'isolated_dwelling') THEN 1031
		WHEN ("tw1_po"."all_tags"->>'place' = 'region') THEN 1040
		WHEN ("tw1_po"."all_tags"->>'place' = 'county') THEN 1041
		WHEN ("tw1_po"."all_tags"->>'place' = 'locality') THEN 1050
		WHEN (("tw1_po"."all_tags"->>'area' = 'yes') AND ("tw1_po"."all_tags"->>'name' IS NOT NULL)) THEN 1099
		ELSE NULL
	END)::SMALLINT AS "code",
	"tw1_po"."all_tags"->>'name'::VARCHAR(100) AS "name",
	(CASE
		WHEN ("tw1_po"."all_tags"->>'name:${OSM_DATA_LANG_CODE,,}' IS NOT NULL) THEN "tw1_po"."all_tags"->>'name:${OSM_DATA_LANG_CODE,,}'
		ELSE "tw1_po"."all_tags"->>'name'
	END)::VARCHAR(100) AS "loc_name",
	(CASE
		WHEN ("tw1_po"."all_tags"->>'name:en' IS NOT NULL) THEN "tw1_po"."all_tags"->>'name:en}'
		ELSE "tw1_po"."all_tags"->>'name'
	END)::VARCHAR(100) AS "int_name",
	(CASE
		WHEN ("tw1_po"."all_tags"->>'population' ~ '^[0-9]+$') THEN "tw1_po"."all_tags"->>'population'
		ELSE NULL
	END)::INT4 AS "population",
	'N'::CHAR(1) AS "osm_geomtype",
	"tw1_po"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."points" AS "tw1_po"
 WHERE (
	("tw1_po"."all_tags"->>'place' IS NOT NULL)
	OR (("tw1_po"."all_tags"->>'area' = 'yes') AND ("tw1_po"."all_tags"->>'name' IS NOT NULL))
 )
 ORDER BY "tw1_po"."osm_id" ASC
)
SELECT
	"q_pl".*,
	ROW_NUMBER() OVER (ORDER BY "q_pl"."osm_id" ASC) AS "id",
	(CASE
		WHEN ("q_pl"."code" = 1001) THEN 'city'
		WHEN ("q_pl"."code" = 1002) THEN 'town'
		WHEN ("q_pl"."code" = 1003) THEN 'village'
		WHEN ("q_pl"."code" = 1004) THEN 'hamlet'
		WHEN ("q_pl"."code" = 1005) THEN 'national_capital'
		WHEN ("q_pl"."code" = 1010) THEN 'suburb'
		WHEN ("q_pl"."code" = 1020) THEN 'island'
		WHEN ("q_pl"."code" = 1030) THEN 'farm'
		WHEN ("q_pl"."code" = 1031) THEN 'isolated_dwelling'
		WHEN ("q_pl"."code" = 1040) THEN 'region'
		WHEN ("q_pl"."code" = 1041) THEN 'county'
		WHEN ("q_pl"."code" = 1050) THEN 'locality'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
--	'places' AS "gfstd_layer_name",
	true AS "aal"
 FROM "qw_pl" AS "q_pl"
 WHERE (
	("q_pl"."code" IS NOT NULL)
	AND ("q_pl"."loc_name" IS NOT NULL)
);

CREATE UNIQUE INDEX "qoxm_places_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "btree" ("id" ASC);
CREATE UNIQUE INDEX "qoxm_places_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "btree" ("osm_id" ASC);
CREATE INDEX "qoxm_places_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "gist" ("geom");

DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" CASCADE;

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" AS
WITH "qw_ro" AS (SELECT
	"tw1_li"."osm_id"::BIGINT,
	"tw1_li"."osm_timestamp"::TIMESTAMP AS "lastchange",
	(CASE
		WHEN ("tw1_li"."all_tags"->>'highway' = 'motorway') THEN 5111
		WHEN ("tw1_li"."all_tags"->>'highway' = 'trunk') THEN 5112
		WHEN ("tw1_li"."all_tags"->>'highway' = 'primary') THEN 5113
		WHEN ("tw1_li"."all_tags"->>'highway' = 'secondary') THEN 5114
		WHEN ("tw1_li"."all_tags"->>'highway' = 'tertiary') THEN 5115
		WHEN ("tw1_li"."all_tags"->>'highway' = 'unclassified') THEN 5121
		WHEN ("tw1_li"."all_tags"->>'highway' = 'residential') THEN 5122
		WHEN ("tw1_li"."all_tags"->>'highway' = 'living_street') THEN 5123
		WHEN ("tw1_li"."all_tags"->>'highway' = 'pedestrian') THEN 5124
		WHEN ("tw1_li"."all_tags"->>'highway' = 'busway') THEN 5125
		WHEN ("tw1_li"."all_tags"->>'highway' = 'motorway_link') THEN 5131
		WHEN ("tw1_li"."all_tags"->>'highway' = 'trunk_link') THEN 5132
		WHEN ("tw1_li"."all_tags"->>'highway' = 'primary_link') THEN 5133
		WHEN ("tw1_li"."all_tags"->>'highway' = 'secondary_link') THEN 5134
		WHEN ("tw1_li"."all_tags"->>'highway' = 'tertiary_link') THEN 5135
		WHEN ("tw1_li"."all_tags"->>'highway' = 'service') THEN 5141
		WHEN (("tw1_li"."all_tags"->>'highway' = 'track') AND ("tw1_li"."all_tags"->>'tracktype' = 'grade1')) THEN 5143
		WHEN (("tw1_li"."all_tags"->>'highway' = 'track') AND ("tw1_li"."all_tags"->>'tracktype' = 'grade2')) THEN 5144
		WHEN (("tw1_li"."all_tags"->>'highway' = 'track') AND ("tw1_li"."all_tags"->>'tracktype' = 'grade3')) THEN 5145
		WHEN (("tw1_li"."all_tags"->>'highway' = 'track') AND ("tw1_li"."all_tags"->>'tracktype' = 'grade4')) THEN 5146
		WHEN (("tw1_li"."all_tags"->>'highway' = 'track') AND ("tw1_li"."all_tags"->>'tracktype' = 'grade5')) THEN 5147
		WHEN ("tw1_li"."all_tags"->>'highway' = 'track') THEN 5142
		WHEN (("tw1_li"."all_tags"->>'highway' = 'bridleway') OR (("tw1_li"."all_tags"->>'highway' = 'path') AND ("tw1_li"."all_tags"->>'horse' = 'designated'))) THEN 5151
		WHEN (("tw1_li"."all_tags"->>'highway' = 'cycleway') OR (("tw1_li"."all_tags"->>'highway' = 'path') AND ("tw1_li"."all_tags"->>'cycle' = 'designated'))) THEN 5152
		WHEN (("tw1_li"."all_tags"->>'highway' = 'footway') OR (("tw1_li"."all_tags"->>'highway' = 'path') AND ("tw1_li"."all_tags"->>'foot' = 'designated'))) THEN 5153
		WHEN ("tw1_li"."all_tags"->>'highway' = 'path') THEN 5154
		WHEN ("tw1_li"."all_tags"->>'highway' = 'steps') THEN 5155
		WHEN ("tw1_li"."all_tags"->>'highway' = 'ferry') THEN 5160
		WHEN ("tw1_li"."all_tags"->>'highway' = 'road') THEN 5199
		ELSE NULL
	END)::SMALLINT AS "code",
	("tw1_li"."all_tags"->>'ref')::VARCHAR(20) AS "ref",
	("tw1_li"."all_tags"->>'int_ref')::VARCHAR(20) AS "int_ref",
	("tw1_li"."all_tags"->>'oneway')::VARCHAR(1) AS "oneway",
	("tw1_li"."all_tags"->>'toll') AS "toll",
	("tw1_li"."all_tags"->>'toll:bus') AS "toll_bus",
	("tw1_li"."all_tags"->>'toll:hgv') AS "toll_hgv",
	SUBSTRING("tw1_li"."all_tags"->>'charge' FROM '^([0-9]+([.][0-9]{1,3}))([ ].+)?$')::DECIMAL(15, 3) AS "charge_value",
	SUBSTRING("tw1_li"."all_tags"->>'charge' FROM '^[0-9.]+[ ]+([A-Z]{3})(/.*)?$')::CHAR(3) AS "charge_curr",
	(CASE
		WHEN ("tw1_li"."all_tags"->>'maxspeed' ~ '^[0-9]+$') THEN "tw1_li"."all_tags"->>'maxspeed'
		ELSE NULL
	END)::SMALLINT AS "maxspeed",
	(CASE
		WHEN ("tw1_li"."all_tags"->>'minspeed' ~ '^[0-9]+$') THEN "tw1_li"."all_tags"->>'minspeed'
		ELSE NULL
	END)::SMALLINT AS "minspeed",
	(CASE
		WHEN ("tw1_li"."all_tags"->>'layer' ~ '^[0-9]+$') THEN "tw1_li"."all_tags"->>'layer'
		ELSE NULL
	END)::SMALLINT AS "layer",
	(CASE
		WHEN (("tw1_li"."all_tags"->>'bridge' IS NOT NULL) AND ("tw1_li"."all_tags"->>'bridge' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "bridge",
	(CASE
		WHEN (("tw1_li"."all_tags"->>'bridge' IS NOT NULL) AND ("tw1_li"."all_tags"->>'bridge' ~ '.+')) THEN LOWER("tw1_li"."all_tags"->>'bridge')
		ELSE NULL
	END)::VARCHAR(32) AS "bridge_value",
	(CASE
		WHEN (("tw1_li"."all_tags"->>'tunnel' IS NOT NULL) AND ("tw1_li"."all_tags"->>'tunnel' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "tunnel",
	(CASE
		WHEN (("tw1_li"."all_tags"->>'tunnel' IS NOT NULL) AND ("tw1_li"."all_tags"->>'tunnel' ~ '.+')) THEN LOWER("tw1_li"."all_tags"->>'tunnel')
		ELSE NULL
	END)::VARCHAR(32) AS "tunnel_value",
	("tw1_li"."all_tags"->>'surface')::VARCHAR(20) AS "surface",
	("tw1_li"."all_tags"->>'smoothness')::VARCHAR(32) AS "smoothness",
	"tw1_li"."all_tags"->>'lit' AS "lit",
	(CASE
		WHEN ("tw1_li"."all_tags"->>'width' ~ '^[0-9]+$') THEN "tw1_li"."all_tags"->>'width'
		ELSE NULL
	END)::SMALLINT AS "width",
	"tw1_li"."all_tags"->>'access' AS "access",
	"tw1_li"."all_tags"->>'horse' AS "horse",
	"tw1_li"."all_tags"->>'motor_vehicle' AS "motor_vehicle",
	"tw1_li"."all_tags"->>'motorcar' AS "motorcar",
	"tw1_li"."all_tags"->>'motorcycle' AS "motorcycle",
	"tw1_li"."all_tags"->>'vehicle' AS "vehicle",
	'W'::CHAR(1) AS "osm_geomtype",
	"tw1_li"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."lines" AS "tw1_li"
 WHERE (
	"tw1_li"."all_tags"->>'highway' IS NOT NULL
 )
 ORDER BY
	"tw1_li"."osm_id" ASC
)
SELECT
	"q_ro".*,
	ROW_NUMBER() OVER (ORDER BY "q_ro"."osm_id" ASC) AS "id",
	(CASE
		WHEN ("q_ro"."code" = 5111) THEN 'motorway'
		WHEN ("q_ro"."code" = 5112) THEN 'trunk'
		WHEN ("q_ro"."code" = 5113) THEN 'primary'
		WHEN ("q_ro"."code" = 5114) THEN 'secondary'
		WHEN ("q_ro"."code" = 5115) THEN 'tertiary'
		WHEN ("q_ro"."code" = 5121) THEN 'unclassified'
		WHEN ("q_ro"."code" = 5122) THEN 'residential'
		WHEN ("q_ro"."code" = 5123) THEN 'living_street'
		WHEN ("q_ro"."code" = 5124) THEN 'pedestrian'
		WHEN ("q_ro"."code" = 5125) THEN 'busway'
		WHEN ("q_ro"."code" = 5131) THEN 'motorway_link'
		WHEN ("q_ro"."code" = 5132) THEN 'trunk_link'
		WHEN ("q_ro"."code" = 5133) THEN 'primary_link'
		WHEN ("q_ro"."code" = 5134) THEN 'secondary_link'
		WHEN ("q_ro"."code" = 5135) THEN 'tertiary_link'
		WHEN ("q_ro"."code" = 5141) THEN 'service'
		WHEN ("q_ro"."code" = 5143) THEN 'track_grade1'
		WHEN ("q_ro"."code" = 5144) THEN 'track_grade2'
		WHEN ("q_ro"."code" = 5145) THEN 'track_grade3'
		WHEN ("q_ro"."code" = 5146) THEN 'track_grade4'
		WHEN ("q_ro"."code" = 5147) THEN 'track_grade5'
		WHEN ("q_ro"."code" = 5142) THEN 'track'
		WHEN ("q_ro"."code" = 5151) THEN 'bridleway'
		WHEN ("q_ro"."code" = 5152) THEN 'cycleway'
		WHEN ("q_ro"."code" = 5153) THEN 'footway'
		WHEN ("q_ro"."code" = 5154) THEN 'path'
		WHEN ("q_ro"."code" = 5155) THEN 'steps'
		WHEN ("q_ro"."code" = 5160) THEN 'ferry'
		WHEN ("q_ro"."code" = 5199) THEN 'unknown'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
	NULL AS "aal"
 FROM "qw_ro" AS "q_ro"
 WHERE (
		("q_ro"."code" > 5100) AND ("q_ro"."code" <=5199)
);

CREATE UNIQUE INDEX "qoxm_roads_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("id" ASC);
CREATE UNIQUE INDEX "qoxm_roads_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("osm_id" ASC);
CREATE INDEX "qoxm_roads_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "gist" ("geom");

DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" CASCADE;

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" AS
WITH "qw_la" AS (SELECT
	"tw1_mp"."osm_id"::BIGINT,
	"tw1_mp"."osm_way_id"::BIGINT,
	"tw1_mp"."osm_timestamp"::TIMESTAMP AS "lastchange",
	(CASE
		WHEN (("tw1_mp"."all_tags"->>'landuse' = 'forest') OR ("tw1_mp"."all_tags"->>'natural' = 'wood')) THEN 7201
		WHEN (("tw1_mp"."all_tags"->>'landuse' = 'park') OR ("tw1_mp"."all_tags"->>'leisure' = 'park') OR ("tw1_mp"."all_tags"->>'leisure' = 'common')) THEN 7202
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'residential') THEN 7203
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'industrial') THEN 7204
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'cemetery') THEN 7206
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'allotments') THEN 7207
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'meadow') THEN 7208
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'commercial') THEN 7209
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'nature_reserve') THEN 7210
		WHEN (("tw1_mp"."all_tags"->>'landuse' = 'recreation_ground') OR ("tw1_mp"."all_tags"->>'leisure' = 'recreation_ground')) THEN 7211
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'retail') THEN 7212
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'military') THEN 7213
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'quarry') THEN 7214
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'orchard') THEN 7215
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'vineyard') THEN 7216
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'scrub') THEN 7217
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'grass') THEN 7218
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'heath') THEN 7219
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'national_park') THEN 7220
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'basin') THEN 7221
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'village_green') THEN 7222
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'plant_nursery') THEN 7223
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'brownfield') THEN 7224
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'greenfield') THEN 7225
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'construction') THEN 7226
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'railway') THEN 7227
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'farmland') THEN 7228
		WHEN ("tw1_mp"."all_tags"->>'landuse' = 'farmyard') THEN 7229
		-- extensions
		WHEN ("tw1_mp"."all_tags"->>'natural' = 'grassland') THEN 7208
		WHEN ("tw1_mp"."all_tags"->>'natural' = 'scrub') THEN 7217
		WHEN ("tw1_mp"."all_tags"->>'natural' = 'heath') THEN 7219
		ELSE NULL
	END)::SMALLINT AS "code",
	'R'::CHAR(1) AS "osm_geomtype",
	"tw1_mp"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" AS "tw1_mp"
 WHERE (
	("tw1_mp"."all_tags"->>'landuse' IS NOT NULL)
	OR ("tw1_mp"."all_tags"->>'leisure' IS NOT NULL)
	OR ("tw1_mp"."all_tags"->>'natural' IS NOT NULL)
 )
 ORDER BY "tw1_mp"."osm_id" ASC
)
SELECT
	"q_la".*,
	ROW_NUMBER() OVER (ORDER BY "q_la"."osm_id" ASC) AS "id",
	(CASE
		WHEN ("q_la"."code" = 7201) THEN 'forest'
		WHEN ("q_la"."code" = 7202) THEN 'park'
		WHEN ("q_la"."code" = 7203) THEN 'residential'
		WHEN ("q_la"."code" = 7204) THEN 'industrial'
		WHEN ("q_la"."code" = 7206) THEN 'cemetery'
		WHEN ("q_la"."code" = 7207) THEN 'allotments'
		WHEN ("q_la"."code" = 7208) THEN 'meadow'
		WHEN ("q_la"."code" = 7209) THEN 'commercial'
		WHEN ("q_la"."code" = 7210) THEN 'nature_reserve'
		WHEN ("q_la"."code" = 7211) THEN 'recreation_ground'
		WHEN ("q_la"."code" = 7212) THEN 'retail'
		WHEN ("q_la"."code" = 7213) THEN 'military'
		WHEN ("q_la"."code" = 7214) THEN 'quarry'
		WHEN ("q_la"."code" = 7215) THEN 'orchard'
		WHEN ("q_la"."code" = 7216) THEN 'vineyard'
		WHEN ("q_la"."code" = 7217) THEN 'scrub'
		WHEN ("q_la"."code" = 7218) THEN 'grass'
		WHEN ("q_la"."code" = 7219) THEN 'heath'
		WHEN ("q_la"."code" = 7220) THEN 'national_park'
		WHEN ("q_la"."code" = 7221) THEN 'basin'
		WHEN ("q_la"."code" = 7222) THEN 'village_green'
		WHEN ("q_la"."code" = 7223) THEN 'plant_nursery'
		WHEN ("q_la"."code" = 7224) THEN 'brownfield'
		WHEN ("q_la"."code" = 7225) THEN 'greenfield'
		WHEN ("q_la"."code" = 7226) THEN 'construction'
		WHEN ("q_la"."code" = 7227) THEN 'railway'
		WHEN ("q_la"."code" = 7228) THEN 'farmland'
		WHEN ("q_la"."code" = 7229) THEN 'farmyard'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
--	'landuse' AS "gfstd_layer_name",
	NULL AS "aal"
 FROM "qw_la" AS "q_la"
 WHERE (
		"q_la"."code" IS NOT NULL
);

CREATE UNIQUE INDEX "qoxm_landuse_a_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("id" ASC);
CREATE UNIQUE INDEX "qoxm_landuse_a_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("osm_id" ASC);
CREATE UNIQUE INDEX "qoxm_landuse_a_osm_way_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("osm_way_id" ASC);
CREATE INDEX "qoxm_landuse_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "gist" ("geom");

COMMIT;
66846bd11f2b4aa2b22067c21e20a45e
