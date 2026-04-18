#!/bin/bash

# code/fclass mapping based on Geopfabrik's specs:
# OpenStreetMap Data in Layered GIS Format
# Free shapefiles
# version: 2022-04-29
# Frederik Ramm <frederik.ramm@geofabrik.de>
# https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf

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

declare -i\
 GEOM_STORE_SRS=4326

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

DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" CASCADE;

ALTER TABLE "${OSM_DATA_TABLES_SCHEMA}"."lines" ALTER COLUMN "all_tags" TYPE "jsonb" USING ("all_tags"::JSONB);
ALTER TABLE "${OSM_DATA_TABLES_SCHEMA}"."multilinestrings" ALTER COLUMN "all_tags" TYPE "jsonb" USING ("all_tags"::JSONB);
ALTER TABLE "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" ALTER COLUMN "all_tags" TYPE "jsonb" USING ("all_tags"::JSONB);
ALTER TABLE "${OSM_DATA_TABLES_SCHEMA}"."points" ALTER COLUMN "all_tags" TYPE "jsonb" USING ("all_tags"::JSONB);
ALTER TABLE "${OSM_DATA_TABLES_SCHEMA}"."other_relations" ALTER COLUMN "all_tags" TYPE "jsonb" USING ("all_tags"::JSONB);

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
	("tw1_po"."all_tags"->>'name')::VARCHAR(100) AS "name",
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
	'N'::CHAR(1) AS "osmgeomsrc",
	"tw1_po"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."points" AS "tw1_po"
 WHERE (
	("tw1_po"."all_tags"->>'place' IS NOT NULL)
	OR (("tw1_po"."all_tags"->>'area' = 'yes') AND ("tw1_po"."all_tags"->>'name' IS NOT NULL))
 )
 ORDER BY "tw1_po"."osm_id"::BIGINT ASC
)
SELECT
	"q_pl".*,
	ROW_NUMBER() OVER (ORDER BY "q_pl"."osm_id" ASC) AS "ogc_fid",
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
	'place'::VARCHAR(16) AS "fxcateg",
	true AS "aal"
 FROM "qw_pl" AS "q_pl"
 WHERE (
	("q_pl"."code" IS NOT NULL)
	AND ("q_pl"."loc_name" IS NOT NULL)
);

CREATE UNIQUE INDEX "qoxm_places_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_places_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "btree" ("osm_id" ASC);
CREATE INDEX "qoxm_places_lastchange_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "btree" ("lastchange");
CREATE INDEX "qoxm_places_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "btree" ("fclass");
CREATE INDEX "qoxm_places_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_places" USING "gist" ("geom");

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" AS
WITH
"q1w_ro" AS (SELECT
	"tw1_li".*,
	(CASE
		WHEN ("tw1_li"."all_tags"->>'highway' = 'construction') THEN "tw1_li"."all_tags"->>'construction'
		ELSE "tw1_li"."all_tags"->>'highway'
	END)::VARCHAR AS "highway_type",
	(CASE
		WHEN ("tw1_li"."all_tags"->>'highway' = 'construction') THEN true
		ELSE false
	END)::BOOLEAN AS "in_construction"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."lines" AS "tw1_li"
 WHERE (
	"tw1_li"."all_tags"->>'highway' IS NOT NULL
 )
),
"q2w_ro" AS (SELECT
	"q1w_ro"."osm_id"::BIGINT,
	"q1w_ro"."osm_timestamp"::TIMESTAMP AS "lastchange",
	(CASE
		WHEN ("q1w_ro"."highway_type" = 'motorway') THEN 5111
		WHEN ("q1w_ro"."highway_type" = 'trunk') THEN 5112
		WHEN ("q1w_ro"."highway_type" = 'primary') THEN 5113
		WHEN ("q1w_ro"."highway_type" = 'secondary') THEN 5114
		WHEN ("q1w_ro"."highway_type" = 'tertiary') THEN 5115
		WHEN ("q1w_ro"."highway_type" = 'unclassified') THEN 5121
		WHEN ("q1w_ro"."highway_type" = 'residential') THEN 5122
		WHEN ("q1w_ro"."highway_type" = 'living_street') THEN 5123
		WHEN ("q1w_ro"."highway_type" = 'pedestrian') THEN 5124
		WHEN ("q1w_ro"."highway_type" = 'busway') THEN 5125
		WHEN ("q1w_ro"."highway_type" = 'motorway_link') THEN 5131
		WHEN ("q1w_ro"."highway_type" = 'trunk_link') THEN 5132
		WHEN ("q1w_ro"."highway_type" = 'primary_link') THEN 5133
		WHEN ("q1w_ro"."highway_type" = 'secondary_link') THEN 5134
		WHEN ("q1w_ro"."highway_type" = 'tertiary_link') THEN 5135
		WHEN ("q1w_ro"."highway_type" = 'service') THEN 5141
		WHEN (("q1w_ro"."highway_type" = 'track') AND ("q1w_ro"."all_tags"->>'tracktype' = 'grade1')) THEN 5143
		WHEN (("q1w_ro"."highway_type" = 'track') AND ("q1w_ro"."all_tags"->>'tracktype' = 'grade2')) THEN 5144
		WHEN (("q1w_ro"."highway_type" = 'track') AND ("q1w_ro"."all_tags"->>'tracktype' = 'grade3')) THEN 5145
		WHEN (("q1w_ro"."highway_type" = 'track') AND ("q1w_ro"."all_tags"->>'tracktype' = 'grade4')) THEN 5146
		WHEN (("q1w_ro"."highway_type" = 'track') AND ("q1w_ro"."all_tags"->>'tracktype' = 'grade5')) THEN 5147
		WHEN ("q1w_ro"."highway_type" = 'track') THEN 5142
		WHEN (("q1w_ro"."highway_type" = 'bridleway') OR (("q1w_ro"."highway_type" = 'path') AND ("q1w_ro"."all_tags"->>'horse' = 'designated'))) THEN 5151
		WHEN (("q1w_ro"."highway_type" = 'cycleway') OR (("q1w_ro"."highway_type" = 'path') AND ("q1w_ro"."all_tags"->>'cycle' = 'designated'))) THEN 5152
		WHEN (("q1w_ro"."highway_type" = 'footway') OR (("q1w_ro"."highway_type" = 'path') AND ("q1w_ro"."all_tags"->>'foot' = 'designated'))) THEN 5153
		WHEN ("q1w_ro"."highway_type" = 'path') THEN 5154
		WHEN ("q1w_ro"."highway_type" = 'steps') THEN 5155
		WHEN ("q1w_ro"."highway_type" = 'ferry') THEN 5160
		WHEN ("q1w_ro"."highway_type" = 'road') THEN 5199
		ELSE NULL
	END)::SMALLINT AS "code",
	"q1w_ro"."in_construction"::BOOLEAN AS "inconstrct",
	("q1w_ro"."all_tags"->>'ref')::VARCHAR(20) AS "ref",
	("q1w_ro"."all_tags"->>'int_ref')::VARCHAR(20) AS "int_ref",
	(CASE
		WHEN ("q1w_ro"."all_tags"->>'lanes' ~ '^[0-9]{3}$') THEN "q1w_ro"."all_tags"->>'lanes'
		ELSE NULL
	END)::SMALLINT AS "lanes",
	("q1w_ro"."all_tags"->>'name')::VARCHAR(100) AS "name",
	("q1w_ro"."all_tags"->>'oneway')::VARCHAR(1) AS "oneway",
	("q1w_ro"."all_tags"->>'toll') AS "toll",
	("q1w_ro"."all_tags"->>'toll:bus') AS "toll_bus",
	("q1w_ro"."all_tags"->>'toll:hgv') AS "toll_hgv",
	SUBSTRING("q1w_ro"."all_tags"->>'charge' FROM '^([0-9]+([.][0-9]{1,3}))([ ].+)?$')::DECIMAL(15, 3) AS "charge_v",
	SUBSTRING("q1w_ro"."all_tags"->>'charge' FROM '^[0-9.]+[ ]+([A-Z]{3})(/.*)?$')::CHAR(3) AS "charge_c",
	(CASE
		WHEN ("q1w_ro"."all_tags"->>'maxspeed' ~ '^[0-9]+$') THEN "q1w_ro"."all_tags"->>'maxspeed'
		ELSE NULL
	END)::SMALLINT AS "maxspeed",
	(CASE
		WHEN ("q1w_ro"."all_tags"->>'minspeed' ~ '^[0-9]+$') THEN "q1w_ro"."all_tags"->>'minspeed'
		ELSE NULL
	END)::SMALLINT AS "minspeed",
	(CASE
		WHEN ("q1w_ro"."all_tags"->>'layer' ~ '^[0-9]+$') THEN "q1w_ro"."all_tags"->>'layer'
		ELSE '0'
	END)::SMALLINT AS "layer",
	("q1w_ro"."all_tags"->>'layer')::VARCHAR AS "layer_v",
	(CASE
		WHEN (("q1w_ro"."all_tags"->>'bridge' IS NOT NULL) AND ("q1w_ro"."all_tags"->>'bridge' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "bridge",
	(CASE
		WHEN (("q1w_ro"."all_tags"->>'bridge' IS NOT NULL) AND ("q1w_ro"."all_tags"->>'bridge' ~ '.+')) THEN LOWER("q1w_ro"."all_tags"->>'bridge')
		ELSE NULL
	END)::VARCHAR(32) AS "bridge_v",
	(CASE
		WHEN (("q1w_ro"."all_tags"->>'tunnel' IS NOT NULL) AND ("q1w_ro"."all_tags"->>'tunnel' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "tunnel",
	(CASE
		WHEN (("q1w_ro"."all_tags"->>'tunnel' IS NOT NULL) AND ("q1w_ro"."all_tags"->>'tunnel' ~ '.+')) THEN LOWER("q1w_ro"."all_tags"->>'tunnel')
		ELSE NULL
	END)::VARCHAR(32) AS "tunnel_v",
	("q1w_ro"."all_tags"->>'surface')::VARCHAR(20) AS "surface",
	("q1w_ro"."all_tags"->>'smoothness')::VARCHAR(32) AS "smoothness",
	(CASE
		WHEN ("q1w_ro"."all_tags"->>'incline' ~ '^-?[0-9]+$') THEN "q1w_ro"."all_tags"->>'incline'
		ELSE NULL
	END)::SMALLINT AS "incline",
	"q1w_ro"."all_tags"->>'lit' AS "lit",
	(CASE
		WHEN ("q1w_ro"."all_tags"->>'width' ~ '^[0-9]+$') THEN "q1w_ro"."all_tags"->>'width'
		ELSE NULL
	END)::SMALLINT AS "width",
	("q1w_ro"."all_tags"->>'access')::VARCHAR(16) AS "access",
	("q1w_ro"."all_tags"->>'horse')::VARCHAR(16) AS "horse",
	("q1w_ro"."all_tags"->>'motor_vehicle')::VARCHAR(16) AS "motor_veh",
	("q1w_ro"."all_tags"->>'motorcar')::VARCHAR(16) AS "motorcar",
	("q1w_ro"."all_tags"->>'motorcycle')::VARCHAR(16) AS "motorcycle",
	("q1w_ro"."all_tags"->>'vehicle') AS "vehicle",
	(CASE
		WHEN ("q1w_ro"."all_tags"->>'motor_vehicle' = 'designated') THEN 'motor'
		WHEN ("q1w_ro"."all_tags"->>'motor_vehicle' = 'yes') THEN 'motor'
		WHEN ("q1w_ro"."all_tags"->>'horse' = 'designated') THEN 'other'
		WHEN ("q1w_ro"."all_tags"->>'bicycle' = 'designated') THEN 'no_motor'
		WHEN ("q1w_ro"."all_tags"->>'foot' = 'designated') THEN 'foot'
		WHEN (("q1w_ro"."all_tags"->>'access' = 'permissive') OR ("q1w_ro"."all_tags"->>'motor_vehicle' = 'permissive')) THEN 'permissive'
		WHEN (("q1w_ro"."all_tags"->>'access' IN ('no', 'forestry', 'agricultural', 'customers', 'disabled', 'employees', 'licence', 'military', 'permit', 'police', 'private', 'residents')) AND ("q1w_ro"."all_tags"->>'foot' NOT IN ('yes', 'designated')) AND ("q1w_ro"."all_tags"->>'bicycle' NOT IN ('yes', 'designated'))) THEN 'none'
		WHEN (("q1w_ro"."all_tags"->>'vehicle' IN ('no', 'forestry', 'agricultural', 'customers', 'disabled', 'employees', 'licence', 'military', 'permit', 'police', 'private', 'residents')) AND ("q1w_ro"."all_tags"->>'foot' NOT IN ('yes', 'designated')) AND ("q1w_ro"."all_tags"->>'bicycle' NOT IN ('yes', 'designated'))) THEN 'foot'
		WHEN ("q1w_ro"."all_tags"->>'motor_vehicle' IN ('no', 'forestry', 'agricultural', 'disabled', 'employees', 'licence', 'military', 'permit', 'police', 'private', 'residents')) THEN 'no_motor'
		WHEN ("q1w_ro"."all_tags"->>'bicycle' = 'yes') THEN 'no_motor'
		WHEN ("q1w_ro"."all_tags"->>'foot' = 'yes') THEN 'foot'
		WHEN ("q1w_ro"."highway_type" = 'bridleway') THEN 'other'
		WHEN ("q1w_ro"."highway_type" = 'busway') THEN 'other'
		WHEN ("q1w_ro"."highway_type" = 'cycleway') THEN 'no_motor'
		WHEN ("q1w_ro"."highway_type" IN ('track', 'path')) THEN 'other'
		WHEN ("q1w_ro"."highway_type" IN ('motorway', 'motorway_link', 'trunk', 'trunk_link', 'primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'unclassified', 'residential', 'living_street')) THEN 'motor'
		ELSE 'other'
	END)::VARCHAR(10) AS "pubaccess",
	'W'::CHAR(1) AS "osmgeomsrc",
	"q1w_ro"."geom"
 FROM "q1w_ro"
 WHERE (
	"q1w_ro"."highway_type" IS NOT NULL
 )
)
SELECT
	"q_ro".*,
	ROW_NUMBER() OVER (ORDER BY "q_ro"."osm_id" ASC) AS "ogc_fid",
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
	'roads'::VARCHAR(16) AS "fxcateg",
	NULL AS "aal"
 FROM "q2w_ro" AS "q_ro"
 WHERE (
		("q_ro"."code" > 5100) AND ("q_ro"."code" <= 5199)
);

CREATE UNIQUE INDEX "qoxm_roads_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_roads_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("osm_id" ASC);
CREATE INDEX "qoxm_roads_lastchange_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("lastchange" ASC);
CREATE INDEX "qoxm_roads_code_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("code" ASC);
CREATE INDEX "qoxm_roads_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_roads_name_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("name" ASC);
CREATE INDEX "qoxm_roads_pubaccess_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("pubaccess" ASC);
CREATE INDEX "qoxm_roads_ref_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("ref" ASC);
CREATE INDEX "qoxm_roads_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "gist" ("geom");

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
	'R'::CHAR(1) AS "osmgeomsrc",
	"tw1_mp"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" AS "tw1_mp"
 WHERE (
	("tw1_mp"."all_tags"->>'landuse' IS NOT NULL)
	OR ("tw1_mp"."all_tags"->>'leisure' IS NOT NULL)
	OR ("tw1_mp"."all_tags"->>'natural' IS NOT NULL)
 )
)
SELECT
	"q_la".*,
	ROW_NUMBER() OVER (ORDER BY "q_la"."osm_way_id" ASC NULLS LAST) AS "ogc_fid",
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
	'landuse'::VARCHAR(16) AS "fxcateg",
	NULL AS "aal"
 FROM "qw_la" AS "q_la"
 WHERE (
		"q_la"."code" IS NOT NULL
);

CREATE UNIQUE INDEX "qoxm_landuse_a_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_landuse_a_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("osm_id" ASC);
CREATE UNIQUE INDEX "qoxm_landuse_a_osm_way_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("osm_way_id" ASC);
CREATE INDEX "qoxm_landuse_a_code_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("code" ASC);
CREATE INDEX "qoxm_landuse_a_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_landuse_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "gist" ("geom");

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" AS
WITH "qw_wa" AS (SELECT
	"tw1_mp"."osm_id"::BIGINT,
	"tw1_mp"."osm_way_id"::BIGINT,
	"tw1_mp"."osm_timestamp"::TIMESTAMP AS "lastchange",
	(CASE
		WHEN (("tw1_mp"."all_tags"->>'natural' = 'water') AND ("tw1_mp"."all_tags"->>'water' NOT IN ('reservoir', 'river'))) THEN 8200
		WHEN (("tw1_mp"."all_tags"->>'landuse' = 'reservoir') OR (("tw1_mp"."all_tags"->>'natural' = 'water') AND ("tw1_mp"."all_tags"->>'water' = 'reservoir'))) THEN 8201
		WHEN (("tw1_mp"."all_tags"->>'waterway' = 'riverbank') OR (("tw1_mp"."all_tags"->>'natural' = 'water') AND ("tw1_mp"."all_tags"->>'water' = 'river'))) THEN 8202
		WHEN ("tw1_mp"."all_tags"->>'waterway' = 'riverbank') THEN 8203
		WHEN ("tw1_mp"."all_tags"->>'natural' = 'glacier') THEN 8211
		WHEN ("tw1_mp"."all_tags"->>'natural' = 'wetland') THEN 8221
		ELSE NULL
	END)::SMALLINT AS "code",
	("tw1_mp"."all_tags"->>'name')::VARCHAR(100) AS "name",
	(CASE
		WHEN ("tw1_mp"."all_tags"->>'name:${OSM_DATA_LANG_CODE,,}' IS NOT NULL) THEN "tw1_mp"."all_tags"->>'name:${OSM_DATA_LANG_CODE,,}'
		ELSE "tw1_mp"."all_tags"->>'name'
	END)::VARCHAR(100) AS "loc_name",
	(CASE
		WHEN ("tw1_mp"."all_tags"->>'name:en' IS NOT NULL) THEN "tw1_mp"."all_tags"->>'name:en}'
		ELSE "tw1_mp"."all_tags"->>'name'
	END)::VARCHAR(100) AS "int_name",
	"tw1_mp"."all_tags"->>'alt_name'::VARCHAR(100) AS "alt_name",
	"tw1_mp"."all_tags"->>'water'::VARCHAR(20) AS "water",
	'R'::CHAR(1) AS "osmgeomsrc",
	"tw1_mp"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" AS "tw1_mp"
 WHERE (
	 ("tw1_mp"."all_tags"->>'natural' IN ('glacier', 'water', 'wetland'))
	 OR ("tw1_mp"."all_tags"->>'waterway' IS NOT NULL)
	 OR ("tw1_mp"."all_tags"->>'water' IS NOT NULL)
 )
 ORDER BY
	"tw1_mp"."osm_id"::BIGINT ASC
)
SELECT
	"q_wa".*,
	ROW_NUMBER() OVER (ORDER BY "q_wa"."osm_way_id" ASC) AS "ogc_fid",
	(CASE
		WHEN ("q_wa"."code" = 8200) THEN 'water'
		WHEN ("q_wa"."code" = 8201) THEN 'reservoir'
		WHEN ("q_wa"."code" = 8202) THEN 'river'
		WHEN ("q_wa"."code" = 8203) THEN 'dock'
		WHEN ("q_wa"."code" = 8211) THEN 'glacier'
		WHEN ("q_wa"."code" = 8221) THEN 'wetland'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
	'water'::VARCHAR(16) AS "fxcateg",
	NULL AS "aal"
 FROM "qw_wa" AS "q_wa"
 WHERE (
	 "q_wa"."code" IS NOT NULL
);

CREATE UNIQUE INDEX "qoxm_water_a_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_water_a_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("osm_id" ASC);
CREATE UNIQUE INDEX "qoxm_water_a_osm_way_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("osm_way_id" ASC);
CREATE INDEX "qoxm_water_a_lastchange_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("lastchange" ASC);
CREATE INDEX "qoxm_water_a_code_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("code" ASC);
CREATE INDEX "qoxm_water_a_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_water_a_name_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("name" ASC);
CREATE INDEX "qoxm_water_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "gist" ("geom");

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" AS
SELECT
	ROW_NUMBER() OVER (ORDER BY "t_bu"."osm_way_id" ASC) AS "ogc_fid",
	"t_bu"."osm_id"::BIGINT,
	"t_bu"."osm_way_id"::BIGINT,
	"t_bu"."osm_timestamp"::TIMESTAMP AS "lastchange",
	1500::SMALLINT AS "code",
	'building'::VARCHAR(40) AS "fclass",
	'buildings'::VARCHAR(16) AS "fxcateg",
	(CASE
		WHEN ("t_bu"."all_tags"->>'building' NOT IN ('building', 'true', 'yes')) THEN "t_bu"."all_tags"->>'building'
		ELSE NULL
	END)::VARCHAR(20) AS "type",
	(CASE
		WHEN ("t_bu"."all_tags"->>'building:use' IS NOT NULL) THEN "t_bu"."all_tags"->>'building:use'
		WHEN ("t_bu"."all_tags"->>'military' IS NOT NULL) THEN 'military'
		WHEN ("t_bu"."all_tags"->>'police' IS NOT NULL) THEN 'police'
		WHEN (("t_bu"."all_tags"->>'education' IN ('college', 'kindergarten', 'school', 'university')) OR ("t_bu"."all_tags"->>'amenity' IN ('childcare', 'college', 'kindergarten', 'preschool', 'school', 'university'))) THEN 'education'
		WHEN (("t_bu"."all_tags"->>'healthcare' IN ('audiologist', 'blood_donation', 'centre', 'clinic', 'dentist', 'dialysis', 'doctor', 'hospice', 'hospital', 'nurse', 'rehabilitation', 'sample_collection', 'true', 'vaccination_centre', 'yes')) OR ("t_bu"."all_tags"->>'amenity' IN ('clinic', 'dentist', 'doctors', 'hospital'))) THEN 'healthcare'
		WHEN ("t_bu"."all_tags"->>'amenity' IS NOT NULL) THEN "t_bu"."all_tags"->>'amenity'
		WHEN ("t_bu"."all_tags"->>'tourism' IS NOT NULL) THEN "t_bu"."all_tags"->>'tourism'
		WHEN ("t_bu"."all_tags"->>'shop' IS NOT NULL) THEN 'shop'
		ELSE NULL
	END)::VARCHAR(128) AS "use",
	(CASE
		WHEN ("t_bu"."all_tags"->>'education' IS NOT NULL) THEN "t_bu"."all_tags"->>'education'
		WHEN ("t_bu"."all_tags"->>'healthcare' IS NOT NULL) THEN "t_bu"."all_tags"->>'healthcare'
		WHEN ("t_bu"."all_tags"->>'shop' IS NOT NULL) THEN "t_bu"."all_tags"->>'shop'
		WHEN ("t_bu"."all_tags"->>'tourism' IS NOT NULL) THEN "t_bu"."all_tags"->>'tourism'
		WHEN ("t_bu"."all_tags"->>'amenity' IS NOT NULL) THEN "t_bu"."all_tags"->>'amenity'
		ELSE NULL
	END)::VARCHAR(128) AS "pubservice",
	"t_bu"."all_tags"->>'building:architecture'::VARCHAR(128) AS "archstyle",
	(CASE
		WHEN (("t_bu"."all_tags"->>'building:flats' ~ '^[0-9]{1,6}$')) THEN "t_bu"."all_tags"->>'building:flats'
		ELSE NULL
	END)::INTEGER AS "flats",
	(CASE
		WHEN (("t_bu"."all_tags"->>'building:levels' ~ '^[0-9]{1,3}$')) THEN "t_bu"."all_tags"->>'building:levels'
		ELSE NULL
	END)::SMALLINT AS "levels",
	(CASE
		WHEN (("t_bu"."all_tags"->>'building:min_level' ~ '^[0-9]{1,3}$')) THEN "t_bu"."all_tags"->>'building:min_level'
		ELSE NULL
	END)::SMALLINT AS "minlevel",
	(CASE
		WHEN (("t_bu"."all_tags"->>'height' ~ '^[0-9]{1,4}(\.[0-9]{1,3})?([[:blank:]]*m([.]|eters))?[[:blank:]]*$')) THEN ROUND(("t_bu"."all_tags"->>'height')::NUMERIC(5, 0), 0)
		WHEN (("t_bu"."all_tags"->>'height' ~ '^[0-9]{1,5}(\.[0-9]{1,3})?[[:blank:]]*(ft|(ft\.)|feet|foots)[[:blank:]]*$')) THEN ROUND(("t_bu"."all_tags"->>'height')::NUMERIC(5, 0) * 0.3048, 0)
		ELSE NULL
	END)::SMALLINT AS "height",
	"t_bu"."all_tags"->>'name'::VARCHAR(100) AS "name",
	NULL AS "aal",
	'W'::CHAR(1) AS "osmgeomsrc",
	"t_bu"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" AS "t_bu"
 WHERE (
	("t_bu"."all_tags"->>'building' IS NOT NULL)
	AND ("t_bu"."all_tags"->>'building' ~ '[A-Za-z0-9]')
 );

CREATE UNIQUE INDEX "qoxm_buildings_a_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_buildings_a_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" USING "btree" ("osm_id" ASC);
CREATE UNIQUE INDEX "qoxm_buildings_a_osm_way_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" USING "btree" ("osm_way_id" ASC);
CREATE INDEX "qoxm_buildings_a_type_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" USING "btree" ("type" ASC);
CREATE INDEX "qoxm_buildings_a_use_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" USING "btree" ("use" ASC);
CREATE INDEX "qoxm_buildings_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_buildings_a" USING "gist" ("geom");

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" AS
WITH "qw_mx" AS (SELECT
	"tw1_po"."osm_id"::BIGINT,
	NULL::BIGINT AS "osm_way_id",
	"tw1_po"."osm_timestamp"::TIMESTAMP AS "lastchange",
	"tw1_po"."all_tags",
	'N'::CHAR(1) AS "osmgeomsrc",
	"tw1_po"."geom"::GEOMETRY("MultiPoint", ${GEOM_STORE_SRS})
 FROM "${OSM_DATA_TABLES_SCHEMA}"."points" AS "tw1_po"
 WHERE (
	COALESCE("tw1_po"."all_tags"->>'amenity', "tw1_po"."all_tags"->>'emergency', "tw1_po"."all_tags"->>'highway', "tw1_po"."all_tags"->>'historic', "tw1_po"."all_tags"->>'leisure', "tw1_po"."all_tags"->>'man_made', "tw1_po"."all_tags"->>'office', "tw1_po"."all_tags"->>'shop', "tw1_po"."all_tags"->>'sport', "tw1_po"."all_tags"->>'tourism', "tw1_po"."all_tags"->>'vending') IS NOT NULL
 )
 UNION ALL
 SELECT
	NULL::BIGINT AS "osm_id",
	"tw1_mp"."osm_way_id"::BIGINT,
	"tw1_mp"."osm_timestamp"::TIMESTAMP AS "lastchange",
	"tw1_mp"."all_tags",
	'W'::CHAR(1) AS "osmgeomsrc",
	ST_Centroid("tw1_mp"."geom", true)::GEOMETRY("MultiPoint", ${GEOM_STORE_SRS}) AS "geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" AS "tw1_mp"
 WHERE (
	COALESCE("tw1_mp"."all_tags"->>'amenity', "tw1_mp"."all_tags"->>'emergency', "tw1_mp"."all_tags"->>'highway', "tw1_mp"."all_tags"->>'historic', "tw1_mp"."all_tags"->>'landuse', "tw1_mp"."all_tags"->>'leisure', "tw1_mp"."all_tags"->>'man_made', "tw1_mp"."all_tags"->>'office', "tw1_mp"."all_tags"->>'shop', "tw1_mp"."all_tags"->>'sport', "tw1_mp"."all_tags"->>'vending') IS NOT NULL
 )
),
"qw_pi" AS (SELECT
	ROW_NUMBER() OVER (ORDER BY "tw2_px"."osm_id" ASC NULLS LAST, "tw2_px"."osm_way_id" ASC NULLS LAST) AS "ogc_fid",
	"tw2_px"."osm_id",
	"tw2_px"."osm_way_id",
	"tw2_px"."lastchange",
	("tw2_px"."all_tags"->>'name')::VARCHAR(100) AS "name",
	("tw2_px"."all_tags"->>'name')::VARCHAR(32) AS "ref",
	("tw2_px"."all_tags"->>'notes')::VARCHAR(256) AS "notes",
	(CASE
		WHEN ("tw2_px"."all_tags"->>'layer' ~ '^[0-9]+$') THEN "tw2_px"."all_tags"->>'layer'
		ELSE '0'
	END)::SMALLINT AS "layer",
	("tw2_px"."all_tags"->>'layer')::VARCHAR AS "layer_v",
	(CASE
		WHEN (("tw2_px"."all_tags"->>'bridge' IS NOT NULL) AND ("tw2_px"."all_tags"->>'bridge' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "bridge",
	(CASE
		WHEN (("tw2_px"."all_tags"->>'bridge' IS NOT NULL) AND ("tw2_px"."all_tags"->>'bridge' ~ '.+')) THEN LOWER("tw2_px"."all_tags"->>'bridge')
		ELSE NULL
	END)::VARCHAR(32) AS "bridge_v",
	(CASE
		WHEN (("tw2_px"."all_tags"->>'tunnel' IS NOT NULL) AND ("tw2_px"."all_tags"->>'tunnel' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "tunnel",
	(CASE
		WHEN (("tw2_px"."all_tags"->>'tunnel' IS NOT NULL) AND ("tw2_px"."all_tags"->>'tunnel' ~ '.+')) THEN LOWER("tw2_px"."all_tags"->>'tunnel')
		ELSE NULL
	END)::VARCHAR(32) AS "tunnel_v",
	LOWER("tw2_px"."all_tags"->>'access')::VARCHAR(16) AS "access",
	(CASE
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'police') THEN '{"qxcode": 502001, "gfcode": 2001, "carto_icon": "5/59/Police-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'fire_station') THEN '{"qxcode": 502002, "gfcode": 2002, "carto_icon": "b/b7/Fire-station-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'post_box') THEN '{"qxcode": 502004, "gfcode": 2004, "carto_icon": "d/d4/Post_box-12.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'post_office') THEN '{"qxcode": 502005, "gfcode": 2005, "carto_icon": "e/e1/Post_office-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'telephone') THEN '{"qxcode": 502006, "gfcode": 2006, "carto_icon": "f/fa/Telephone.16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'library') THEN '{"qxcode": 502007, "gfcode": 2007, "carto_icon": "b/b5/Library-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'townhall') THEN '{"qxcode": 502008, "gfcode": 2008, "carto_icon": "a/a3/Town-hall-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'courthouse') THEN '{"qxcode": 502009, "gfcode": 2009, "carto_icon": "d/db/Courthouse-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'prison') THEN '{"qxcode": 502010, "gfcode": 2010, "carto_icon": "d/d0/Prison-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'embassy') OR ("tw2_px"."all_tags"->>'office' = 'diplomatic')) THEN '{"qxcode": 502011, "gfcode": 2011, "carto_icon": "f/f5/Diplomatic.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'community_centre') THEN '{"qxcode": 502012, "gfcode": 2012, "carto_icon": "0/0b/Community_centre-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' IN ('nursing_home', 'social_facility')) THEN '{"qxcode": 502013, "gfcode": 2013, "carto_icon": "0/0e/Social_facility-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'arts_centre') THEN '{"qxcode": 502014, "gfcode": 2014, "carto_icon": "b/bf/Arts_centre.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'grave_yard') OR ("tw2_px"."all_tags"->>'landuse' = 'cemetery')) THEN '{"qxcode": 502015, "gfcode": 2015, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'marketplace') THEN '{"qxcode": 502016, "gfcode": 2016, "carto_icon": "1/1c/Marketplace-14.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND (("tw2_px"."all_tags"->>'recycling:glass' IN ('1', 'true', 'yes')) OR ("tw2_px"."all_tags"->>'recycling:glass_bottles' IN ('1', 'true', 'yes')))) THEN '{"qxcode": 502031, "gfcode": 2031, "carto_icon": "1/16/Recycling-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND ("tw2_px"."all_tags"->>'recycling:paper' IN ('1', 'true', 'yes'))) THEN '{"qxcode": 502032, "gfcode": 2032, "carto_icon": "1/16/Recycling-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND ("tw2_px"."all_tags"->>'recycling:clothes' IN ('1', 'true', 'yes'))) THEN '{"qxcode": 502033, "gfcode": 2033, "carto_icon": "1/16/Recycling-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND ("tw2_px"."all_tags"->>'recycling:scrap_metal' IN ('1', 'true', 'yes'))) THEN '{"qxcode": 502034, "gfcode": 2034, "carto_icon": "1/16/Recycling-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'recycling') THEN '{"qxcode": 502030, "gfcode": 2030, "carto_icon": "1/16/Recycling-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'university') THEN '{"qxcode": 502081, "gfcode": 2081, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'school') THEN '{"qxcode": 502081, "gfcode": 2081, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'kindergarten') THEN '{"qxcode": 502083, "gfcode": 2083, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'college') THEN '{"qxcode": 502084, "gfcode": 2084, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'public_building') THEN '{"qxcode": 502099, "gfcode": 2099, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'pharmacy') THEN '{"qxcode": 502101, "gfcode": 2101, "carto_icon": "1/1e/Pharmacy-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'hospital') THEN '{"qxcode": 502110, "gfcode": 2110, "carto_icon": "3/33/Hospital-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'clinic') THEN '{"qxcode": 502111, "gfcode": 2111, "carto_icon": "7/71/Doctors-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'doctors') THEN '{"qxcode": 502120, "gfcode": 2120, "carto_icon": "7/71/Doctors-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'dentist') THEN '{"qxcode": 502121, "gfcode": 2121, "carto_icon": "8/86/Dentist-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'veterinary') THEN '{"qxcode": 502129, "gfcode": 2129, "carto_icon": "f/fc/Veterinary-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'theatre') THEN '{"qxcode": 502201, "gfcode": 2201, "carto_icon": "e/eb/Theatre-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'nightclub') THEN '{"qxcode": 502202, "gfcode": 2202, "carto_icon": "e/ee/Nightclub-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'cinema') THEN '{"qxcode": 502203, "gfcode": 2203, "carto_icon": "3/31/Cinema-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'park') OR ("tw2_px"."all_tags"->>'leisure' = 'park')) THEN '{"qxcode": 502204, "gfcode": 2204, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'playground') OR ("tw2_px"."all_tags"->>'leisure' = 'playground')) THEN '{"qxcode": 502205, "gfcode": 2205, "carto_icon": "3/31/Playground-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'dog_park') OR ("tw2_px"."all_tags"->>'leisure' = 'dog_park')) THEN '{"qxcode": 502206, "gfcode": 2206, "carto_icon": "d/da/Dog_park.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'sports_centre') OR ("tw2_px"."all_tags"->>'leisure' = 'sports_centre')) THEN '{"qxcode": 502251, "gfcode": 2251, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'pitch') OR ("tw2_px"."all_tags"->>'leisure' = 'pitch')) THEN '{"qxcode": 502252, "gfcode": 2252, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'swimming_pool') OR ("tw2_px"."all_tags"->>'leisure' IN ('swimming_pool', 'water_park')) OR ("tw2_px"."all_tags"->>'sport' = 'swimming')) THEN '{"qxcode": 502253, "gfcode": 2253, "carto_icon": "c/cb/Swimming-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'sport' = 'tennis') THEN '{"qxcode": 502254, "gfcode": 2254, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'golf_course') OR ("tw2_px"."all_tags"->>'leisure' = 'golf_course')) THEN '{"qxcode": 502255, "gfcode": 2255, "carto_icon": "d/d2/Golf-icon.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'stadium') OR ("tw2_px"."all_tags"->>'leisure' = 'stadium')) THEN '{"qxcode": 502256, "gfcode": 2256, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'ice_rink') OR ("tw2_px"."all_tags"->>'leisure' = 'ice_rink')) THEN '{"qxcode": 502257, "gfcode": 2257, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'restaurant') THEN '{"qxcode": 502301, "gfcode": 2301, "carto_icon": "b/bb/Restaurant-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'fast_food') THEN '{"qxcode": 502302, "gfcode": 2302, "carto_icon": "1/1f/Fast-food-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'cafe') THEN '{"qxcode": 502303, "gfcode": 2303, "carto_icon": "d/da/Cafe-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'pub') THEN '{"qxcode": 502304, "gfcode": 2304, "carto_icon": "5/5d/Pub-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bar') THEN '{"qxcode": 502305, "gfcode": 2305, "carto_icon": "9/94/Bar-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'food_court') THEN '{"qxcode": 502306, "gfcode": 2306, "carto_icon": "b/bb/Restaurant-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'biergarten') THEN '{"qxcode": 502307, "gfcode": 2307, "carto_icon": "e/e1/Biergarten-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'hotel') OR ("tw2_px"."all_tags"->>'tourism' = 'hotel')) THEN '{"qxcode": 502401, "gfcode": 2401, "carto_icon": "c/ca/Hotel-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'motel') OR ("tw2_px"."all_tags"->>'tourism' = 'motel')) THEN '{"qxcode": 502402, "gfcode": 2402, "carto_icon": "1/10/Motel-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'bed_and_breakfast') OR ("tw2_px"."all_tags"->>'tourism' = 'bed_and_breakfast')) THEN '{"qxcode": 502403, "gfcode": 2403, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'guest_house') OR ("tw2_px"."all_tags"->>'tourism' = 'guest_house')) THEN '{"qxcode": 502404, "gfcode": 2404, "carto_icon": "d/dc/Tourism_guest_house.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'hostel') OR ("tw2_px"."all_tags"->>'tourism' = 'hostel')) THEN '{"qxcode": 502405, "gfcode": 2405, "carto_icon": "4/4f/Hostel-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'chalet') OR ("tw2_px"."all_tags"->>'tourism' = 'chalet')) THEN '{"qxcode": 502406, "gfcode": 2406, "carto_icon": "e/e9/Chalet.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'shelter') OR ("tw2_px"."all_tags"->>'tourism' = 'shelter')) THEN '{"qxcode": 502421, "gfcode": 2421, "carto_icon": "f/f8/Shelter-14.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'camp_site') OR ("tw2_px"."all_tags"->>'tourism' = 'camp_site')) THEN '{"qxcode": 502422, "gfcode": 2422, "carto_icon": "e/e4/Camping.16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'alpine_hut') OR ("tw2_px"."all_tags"->>'tourism' = 'alpine_hut')) THEN '{"qxcode": 502423, "gfcode": 2423, "carto_icon": "f/f1/Alpinehut.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'caravan_site') OR ("tw2_px"."all_tags"->>'tourism' = 'caravan_site')) THEN '{"qxcode": 502424, "gfcode": 2424, "carto_icon": "a/a1/Caravan-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'supermarket') THEN '{"qxcode": 502501, "gfcode": 2501, "carto_icon": "7/76/Supermarket-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'bakery') THEN '{"qxcode": 502502, "gfcode": 2502, "carto_icon": "f/fe/Bakery-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'kiosk') THEN '{"qxcode": 502503, "gfcode": 2503, "carto_icon": "b/bf/Newsagent-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'mall') THEN '{"qxcode": 502504, "gfcode": 2504, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'department_store') THEN '{"qxcode": 502505, "gfcode": 2505, "carto_icon": "7/79/Department_store-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'general') THEN '{"qxcode": 502510, "gfcode": 2510, "carto_icon": "c/c4/Shop-other-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'convenience') THEN '{"qxcode": 502511, "gfcode": 2511, "carto_icon": "9/96/Convenience-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'clothes') THEN '{"qxcode": 502512, "gfcode": 2512, "carto_icon": "d/de/Clothes-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'florist') THEN '{"qxcode": 502513, "gfcode": 2513, "carto_icon": "6/69/Florist-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'chemist') THEN '{"qxcode": 502514, "gfcode": 2514, "carto_icon": "3/36/Chemist-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'books') THEN '{"qxcode": 502515, "gfcode": 2515, "carto_icon": "1/18/Books-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'butcher') THEN '{"qxcode": 502516, "gfcode": 2516, "carto_icon": "b/b8/Butcher.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'shoes') THEN '{"qxcode": 502517, "gfcode": 2517, "carto_icon": "3/3b/Shoes-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'shop' = 'alcohol') OR ("tw2_px"."all_tags"->>'shop' = 'beverages')) THEN '{"qxcode": 502518, "gfcode": 2518, "carto_icon": "9/98/Beverages-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'optician') THEN '{"qxcode": 502519, "gfcode": 2519, "carto_icon": "6/60/Optician-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'jewelry') THEN '{"qxcode": 502520, "gfcode": 2520, "carto_icon": "8/8d/Jewellery-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'gift') THEN '{"qxcode": 502521, "gfcode": 2521, "carto_icon": "1/11/Gift-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'sports') THEN '{"qxcode": 502522, "gfcode": 2522, "carto_icon": "d/df/Sports-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'stationery') THEN '{"qxcode": 502523, "gfcode": 2523, "carto_icon": "5/58/Stationery-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'outdoor') THEN '{"qxcode": 502524, "gfcode": 2524, "carto_icon": "7/76/Outdoor-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'mobile_phone') THEN '{"qxcode": 502525, "gfcode": 2525, "carto_icon": "1/19/Mobile-phone-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'toys') THEN '{"qxcode": 502526, "gfcode": 2526, "carto_icon": "6/62/Toys-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'newsagent') THEN '{"qxcode": 502527, "gfcode": 2527, "carto_icon": "b/bf/Newsagent-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'greengrocer') THEN '{"qxcode": 502528, "gfcode": 2528, "carto_icon": "d/d8/Greengrocer-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'beauty') THEN '{"qxcode": 502529, "gfcode": 2529, "carto_icon": "0/06/Beauty-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'video') THEN '{"qxcode": 502530, "gfcode": 2530, "carto_icon": "2/2d/Video-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'car') THEN '{"qxcode": 502541, "gfcode": 2541, "carto_icon": "b/b2/Purple-car.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'bicycle') THEN '{"qxcode": 502542, "gfcode": 2542, "carto_icon": "1/1b/Bicycle-16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'shop' = 'doityourself') OR ("tw2_px"."all_tags"->>'shop' = 'hardware')) THEN '{"qxcode": 502543, "gfcode": 2543, "carto_icon": "c/c3/Doityourself-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'furniture') THEN '{"qxcode": 502544, "gfcode": 2544, "carto_icon": "a/a0/Furniture-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'computer') THEN '{"qxcode": 502546, "gfcode": 2546, "carto_icon": "b/bb/Computer-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'garden_centre') THEN '{"qxcode": 502547, "gfcode": 2547, "carto_icon": "4/48/Garden_centre-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'hairdresser') THEN '{"qxcode": 502561, "gfcode": 2561, "carto_icon": "6/6b/Hairdresser-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'car_repair') THEN '{"qxcode": 502562, "gfcode": 2562, "carto_icon": "2/26/Car_repair-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'car_rental') THEN '{"qxcode": 502563, "gfcode": 2563, "carto_icon": "1/11/Rental-car-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'car_wash') THEN '{"qxcode": 502564, "gfcode": 2564, "carto_icon": "6/65/Car_wash-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'car_sharing') THEN '{"qxcode": 502565, "gfcode": 2565, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bicycle_rental') THEN '{"qxcode": 502566, "gfcode": 2566, "carto_icon": "d/d5/Rental-bicycle-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'shop' = 'travel_agency') THEN '{"qxcode": 502567, "gfcode": 2567, "carto_icon": "b/b1/Travel_agency-14.svg"}'
		WHEN (("tw2_px"."all_tags"->>'shop' = 'laundry') OR ("tw2_px"."all_tags"->>'shop' = 'dry_cleaning')) THEN '{"qxcode": 502568, "gfcode": 2568, "carto_icon": "3/34/Laundry-14.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'vending_machine') OR ("tw2_px"."all_tags"->>'vending' = 'cigarettes')) THEN '{"qxcode": 502591, "gfcode": 2591, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'vending_machine') OR ("tw2_px"."all_tags"->>'vending' = 'parking_tickets')) THEN '{"qxcode": 502592, "gfcode": 2592, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'vending_machine') THEN '{"qxcode": 502590, "gfcode": 2590, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bank') THEN '{"qxcode": 502601, "gfcode": 2601, "carto_icon": "3/3b/Bank-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'atm') THEN '{"qxcode": 502602, "gfcode": 2602, "carto_icon": "f/f9/Atm-14.svg"}'
		WHEN (("tw2_px"."all_tags"->>'tourism' = 'information') AND ("tw2_px"."all_tags"->>'information' = 'map')) THEN '{"qxcode": 502704, "gfcode": 2704, "carto_icon": "c/ca/Map-14.svg"}'
		WHEN (("tw2_px"."all_tags"->>'tourism' = 'information') AND ("tw2_px"."all_tags"->>'information' = 'board')) THEN '{"qxcode": 502705, "gfcode": 2705, "carto_icon": "7/77/Board-14.svg"}'
		WHEN (("tw2_px"."all_tags"->>'tourism' = 'information') AND ("tw2_px"."all_tags"->>'information' = 'guidepost')) THEN '{"qxcode": 502706, "gfcode": 2706, "carto_icon": "d/dc/Guidepost-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'information') THEN '{"qxcode": 502701, "gfcode": 2701, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'attraction') THEN '{"qxcode": 502721, "gfcode": 2721, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'museum') THEN '{"qxcode": 502722, "gfcode": 2722, "carto_icon": "a/a9/Museum-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'monument') THEN '{"qxcode": 502723, "gfcode": 2723, "carto_icon": "9/94/Monument-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'memorial') THEN '{"qxcode": 502724, "gfcode": 2724, "carto_icon": "6/6e/Memorial-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'artwork') THEN '{"qxcode": 502725, "gfcode": 2725, "carto_icon": "1/12/Artwork-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'castle') THEN '{"qxcode": 502731, "gfcode": 2731, "carto_icon": "5/51/Castle-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'ruins') THEN '{"qxcode": 502732, "gfcode": 2732, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'archaeological_site') THEN '{"qxcode": 502733, "gfcode": 2733, "carto_icon": "7/7d/Archaeological-site-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'wayside_cross') THEN '{"qxcode": 502734, "gfcode": 2734, "carto_icon": "2/26/Christian.9.svg"}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'wayside_shrine') THEN '{"qxcode": 502735, "gfcode": 2735, "carto_icon": "1/17/Carto_shrine.svg"}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'battlefield') THEN '{"qxcode": 502736, "gfcode": 2736, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'historic' = 'fort') THEN '{"qxcode": 502737, "gfcode": 2737, "carto_icon": "0/0d/Historic-fort.svg"}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'picnic_site') THEN '{"qxcode": 502741, "gfcode": 2741, "carto_icon": "f/fc/Picnic_site.svg"}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'viewpoint') THEN '{"qxcode": 502742, "gfcode": 2742, "carto_icon": "c/c2/Viewpoint-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'zoo') THEN '{"qxcode": 502743, "gfcode": 2743, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'theme_park') THEN '{"qxcode": 502744, "gfcode": 2744, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'toilets') THEN '{"qxcode": 502901, "gfcode": 2901, "carto_icon": "f/fa/Toilets-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bench') THEN '{"qxcode": 502902, "gfcode": 2902, "carto_icon": "0/0c/Bench-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'drinking_water') THEN '{"qxcode": 502903, "gfcode": 2903, "carto_icon": "0/08/Drinking-water-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'fountain') THEN '{"qxcode": 502904, "gfcode": 2904, "carto_icon": "a/a1/Fountain-14.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'hunting_stand') THEN '{"qxcode": 502905, "gfcode": 2905, "carto_icon": "a/a6/Hunting-stand-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'waste_basket') THEN '{"qxcode": 502906, "gfcode": 2906, "carto_icon": "6/6f/Waste-basket-12.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'surveillance') OR ("tw2_px"."all_tags"->>'man_made' = 'surveillance')) THEN '{"qxcode": 502907, "gfcode": 2907, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'emergency_phone') OR ("tw2_px"."all_tags"->>'emergency' = 'phone')) THEN '{"qxcode": 502921, "gfcode": 2921, "carto_icon": "1/1c/Emergency-phone.16.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'fire_hydrant') OR ("tw2_px"."all_tags"->>'emergency' = 'fire_hydrant')) THEN '{"qxcode": 502922, "gfcode": 2922, "carto_icon": "misc/fire_hydrant.svg"}'
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'emergency_access_point') OR ("tw2_px"."all_tags"->>'highway' = 'emergency_access_point')) THEN '{"qxcode": 502923, "gfcode": 2923, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'communication')) THEN '{"qxcode": 502951, "gfcode": 2951, "carto_icon": "2/25/Mast_communications.svg"}'
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'water_tower') OR (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'water'))) THEN '{"qxcode": 502952, "gfcode": 2952, "carto_icon": null}'
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'observation')) THEN '{"qxcode": 502953, "gfcode": 2953, "carto_icon": "b/b9/Tower_observation.svg"}'
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'cooling')) THEN '{"qxcode": 602950, "gfcode": null, "carto_icon": "b/be/Tower_cooling.svg"}'
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'bell_tower')) THEN '{"qxcode": 602951, "gfcode": null, "carto_icon": "1/1a/Tower_bell_tower.svg"}'
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'lighting')) THEN '{"qxcode": 602952, "gfcode": null, "carto_icon": "3/3d/Tower_lighting.svg"}'
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'tower') THEN '{"qxcode": 502950, "gfcode": 2950, "carto_icon": "0/0d/Tower_freestanding.svg"}'
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'windmill') THEN '{"qxcode": 502954, "gfcode": 2954, "carto_icon": "0/0b/Windmill-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'lighthouse') THEN '{"qxcode": 502955, "gfcode": 2955, "carto_icon": "c/c2/Lighthouse-16.svg"}'
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'wastewater_plant') THEN '{"qxcode": 502961, "gfcode": 2961, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'water_well') THEN '{"qxcode": 502962, "gfcode": 2962, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'watermill') THEN '{"qxcode": 502963, "gfcode": 2963, "carto_icon": null}'
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'water_works') THEN '{"qxcode": 502964, "gfcode": 2964, "carto_icon": null}'
		ELSE NULL
	END)::JSONB AS "codes",
	"tw2_px"."osmgeomsrc",
	"tw2_px"."geom"
 FROM "qw_mx" AS "tw2_px"
)
SELECT
	"q_px"."ogc_fid",
	"q_px"."osm_id",
	"q_px"."osm_way_id",
	"q_px"."lastchange",
	"q_px"."osmgeomsrc",
	"q_px"."geom",
	"q_px"."name",
	"q_px"."ref",
	"q_px"."notes",
	"q_px"."layer",
	"q_px"."layer_v",
	"q_px"."bridge",
	"q_px"."bridge_v",
	"q_px"."tunnel",
	"q_px"."tunnel_v",
	"q_px"."access",
	("q_px"."codes"->>'qxcode')::INTEGER AS "qxcode",
	("q_px"."codes"->>'gfcode')::SMALLINT AS "code",
	("q_px"."codes"->>'carto_icon')::VARCHAR(64) AS "icon",
	(CASE
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502001) THEN 'police'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502002) THEN 'fire_station'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502004) THEN 'post_box'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502005) THEN 'post_office'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502006) THEN 'telephone'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502007) THEN 'library'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502008) THEN 'town_hall'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502009) THEN 'courthouse'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502010) THEN 'prison'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502011) THEN 'embassy'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502012) THEN 'community_centre'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502013) THEN 'nursing_home'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502014) THEN 'arts_centre'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502015) THEN 'graveyard'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502016) THEN 'market_place'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502030) THEN 'recycling'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502031) THEN 'recycling_glass'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502032) THEN 'recycling_paper'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502033) THEN 'recycling_clothes'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502034) THEN 'recycling_metal'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502081) THEN 'university'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502082) THEN 'school'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502083) THEN 'kindergarten'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502084) THEN 'college'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502099) THEN 'public_building'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502101) THEN 'pharmacy'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502110) THEN 'hospital'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502111) THEN 'clinic'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502120) THEN 'doctors'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502121) THEN 'dentist'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502129) THEN 'veterinary'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502201) THEN 'theatre'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502202) THEN 'nightclub'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502203) THEN 'cinema'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502204) THEN 'park'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502205) THEN 'playground'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502206) THEN 'dog_park'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502251) THEN 'sports_centre'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502252) THEN 'pitch'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502253) THEN 'swimming_pool'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502254) THEN 'tennis_court'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502255) THEN 'golf_course'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502256) THEN 'stadium'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502257) THEN 'ice_rink'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502301) THEN 'restaurant'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502302) THEN 'fast_food'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502303) THEN 'cafe'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502304) THEN 'pub'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502305) THEN 'bar'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502306) THEN 'food_court'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502307) THEN 'biergarten'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502401) THEN 'hotel'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502402) THEN 'motel'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502403) THEN 'bed_and_breakfast'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502404) THEN 'guesthouse'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502405) THEN 'hostel'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502406) THEN 'chalet'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502421) THEN 'shelter'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502422) THEN 'camp_site'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502423) THEN 'alpine_hut'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502424) THEN 'caravan_site'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502501) THEN 'supermarket'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502502) THEN 'bakery'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502503) THEN 'kiosk'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502504) THEN 'mall'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502505) THEN 'department_store'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502510) THEN 'general'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502511) THEN 'convenience'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502512) THEN 'clothes'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502513) THEN 'florist'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502514) THEN 'chemist'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502515) THEN 'bookshop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502516) THEN 'butcher'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502517) THEN 'shoe_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502518) THEN 'beverages'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502519) THEN 'optician'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502520) THEN 'jeweller'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502521) THEN 'gift_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502522) THEN 'sports_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502523) THEN 'stationery'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502524) THEN 'outdoor_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502525) THEN 'mobile_phone_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502526) THEN 'toy_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502527) THEN 'newsagent'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502528) THEN 'greengrocer'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502529) THEN 'beauty_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502530) THEN 'video_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502541) THEN 'car_dealership'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502542) THEN 'bicycle_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502543) THEN 'doityourself'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502544) THEN 'furniture_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502546) THEN 'computer_shop'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502547) THEN 'garden_centre'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502561) THEN 'hairdresser'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502562) THEN 'car_repair'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502563) THEN 'car_rental'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502564) THEN 'car_wash'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502565) THEN 'car_sharing'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502566) THEN 'bicycle_rental'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502567) THEN 'travel_agent'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502568) THEN 'laundry'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502590) THEN 'vending_machine'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502591) THEN 'vending_cigarette'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502592) THEN 'vending_parking'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502601) THEN 'bank'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502602) THEN 'atm'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502701) THEN 'tourist_info'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502704) THEN 'tourist_map'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502705) THEN 'tourist_board'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502706) THEN 'tourist_guidepost'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502721) THEN 'attraction'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502722) THEN 'museum'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502723) THEN 'monument'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502724) THEN 'memorial'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502725) THEN 'art'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502731) THEN 'castle'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502732) THEN 'ruins'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502733) THEN 'archaeological'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502734) THEN 'wayside_cross'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502735) THEN 'wayside_shrine'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502736) THEN 'battlefield'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502737) THEN 'fort'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502741) THEN 'picnic_site'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502742) THEN 'viewpoint'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502743) THEN 'zoo'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502744) THEN 'theme_park'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502901) THEN 'toilet'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502902) THEN 'bench'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502903) THEN 'drinking_water'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502904) THEN 'fountain'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502905) THEN 'hunting_stand'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502906) THEN 'waste_basket'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502907) THEN 'camera_surveillance'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502921) THEN 'emergency_phone'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502922) THEN 'fire_hydrant'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502923) THEN 'emergency_access'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502950) THEN 'tower'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502951) THEN 'tower_comms'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502952) THEN 'water_tower'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502953) THEN 'tower_observation'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 602950) THEN 'cooling_tower'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 602951) THEN 'bell_tower'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 602952) THEN 'lighting_tower'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502954) THEN 'windmill'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502955) THEN 'lighthouse'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502961) THEN 'wastewater_plant'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502962) THEN 'water_well'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502963) THEN 'water_mill'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER = 502964) THEN 'water_works'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
	(CASE
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502001 AND 502099) THEN 'public'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502101 AND 502199) THEN 'health'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502201 AND 502299) THEN 'leisure'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502301 AND 502399) THEN 'catering'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502401 AND 502499) THEN 'accommodation'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502501 AND 502599) THEN 'shopping'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502601 AND 502699) THEN 'money'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502701 AND 502799) THEN 'tourism'
		WHEN (("q_px"."codes"->>'qxcode')::INTEGER BETWEEN 502901 AND 502999) THEN 'miscpoi'
		ELSE NULL
	END)::VARCHAR(16) AS "fxcateg"
 FROM "qw_pi" AS "q_px"
 WHERE (
	"q_px"."codes"->>'qxcode' IS NOT NULL
 )
 ORDER BY
	"ogc_fid" ASC;

CREATE UNIQUE INDEX "qoxm_pois_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_pois_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("osm_id" ASC);
CREATE UNIQUE INDEX "qoxm_pois_osm_way_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("osm_way_id" ASC);
CREATE INDEX "qoxm_pois_lastchange_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("lastchange" ASC);
CREATE INDEX "qoxm_pois_code_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("code" ASC);
CREATE INDEX "qoxm_pois_qxcode_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("qxcode" ASC);
CREATE INDEX "qoxm_pois_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_pois_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "gist" ("geom");

CREATE MATERIALIZED VIEW "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" AS
WITH
"q1w_rl" AS (SELECT
	"tw1_li".*,
	(CASE
		WHEN ("tw1_li"."all_tags"->>'aerialway' = 'proposed') THEN JSONB_BUILD_OBJECT('class', 'aerialway', 'type', "tw1_li"."all_tags"->>'proposed', 'status', 'proposed')
		WHEN ("tw1_li"."all_tags"->>'railway' = 'proposed') THEN JSONB_BUILD_OBJECT('class', 'railway', 'type', "tw1_li"."all_tags"->>'proposed', 'status', 'proposed')
		WHEN ("tw1_li"."all_tags"->>'aerialway' = 'construction') THEN JSONB_BUILD_OBJECT('class', 'aerialway', 'type', "tw1_li"."all_tags"->>'aerialway', 'status', 'aerialway')
		WHEN ("tw1_li"."all_tags"->>'railway' = 'construction') THEN JSONB_BUILD_OBJECT('class', 'railway', 'type', "tw1_li"."all_tags"->>'construction', 'status', 'construction')
		WHEN (("tw1_li"."all_tags"->>'aerialway' = 'abandoned') OR ("tw1_li"."all_tags"->>'abandoned:aerialway' IS NOT NULL)) THEN JSONB_BUILD_OBJECT('class', 'aerialway', 'type', "tw1_li"."all_tags"->>'abandoned:aerialway', 'status', 'abandoned')
		WHEN (("tw1_li"."all_tags"->>'railway' = 'abandoned') OR ("tw1_li"."all_tags"->>'abandoned:railway' IS NOT NULL)) THEN JSONB_BUILD_OBJECT('class', 'railway', 'type', "tw1_li"."all_tags"->>'abandoned:railway', 'status', 'abandoned')
		WHEN (("tw1_li"."all_tags"->>'aerialway' = 'disused') OR ("tw1_li"."all_tags"->>'disused:aerialway' IS NOT NULL)) THEN JSONB_BUILD_OBJECT('class', 'aerialway', 'type', "tw1_li"."all_tags"->>'disused:aerialway', 'status', 'disused')
		WHEN (("tw1_li"."all_tags"->>'railway' = 'disused') OR ("tw1_li"."all_tags"->>'disused:railway' IS NOT NULL)) THEN JSONB_BUILD_OBJECT('class', 'railway', 'type', "tw1_li"."all_tags"->>'disused:railway', 'status', 'disused')
		WHEN ("tw1_li"."all_tags"->>'aerialway' IS NOT NULL) THEN JSONB_BUILD_OBJECT('class', 'aerialway', 'type', "tw1_li"."all_tags"->>'railway', 'status', 'operational')
		WHEN ("tw1_li"."all_tags"->>'railway' IS NOT NULL) THEN JSONB_BUILD_OBJECT('class', 'railway', 'type', "tw1_li"."all_tags"->>'railway', 'status', 'operational')
		-- obliterated/dismantled/razed lines are not present
		ELSE NULL
	END) AS "_way_data_key"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."lines" AS "tw1_li"
 WHERE (
	("tw1_li"."all_tags"->>'railway' IS NOT NULL)
	OR ("tw1_li"."all_tags"->>'aerialway' IS NOT NULL)
 )
),
"q2w_rl" AS (SELECT
	ROW_NUMBER() OVER (ORDER BY "q1w_rl"."osm_id" ASC) AS "ogc_fid",
	"q1w_rl"."osm_id"::BIGINT,
	"q1w_rl"."osm_timestamp"::TIMESTAMP AS "lastchange",
	(CASE
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND ("q1w_rl"."_way_data_key"->>'type' = 'light_rail')) THEN '{"qxcode": 506102, "gfcode": 6102}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND ("q1w_rl"."_way_data_key"->>'type' = 'subway')) THEN '{"qxcode": 506103, "gfcode": 6103}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND ("q1w_rl"."_way_data_key"->>'type' = 'tram')) THEN '{"qxcode": 506104, "gfcode": 6104}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND ("q1w_rl"."_way_data_key"->>'type' = 'monorail')) THEN '{"qxcode": 506105, "gfcode": 6105}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND ("q1w_rl"."_way_data_key"->>'type' = 'narrow_gauge')) THEN '{"qxcode": 506106, "gfcode": 6106}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND ("q1w_rl"."_way_data_key"->>'type' = 'miniature')) THEN '{"qxcode": 506107, "gfcode": 6107}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND (("q1w_rl"."_way_data_key"->>'type' = 'funicular') OR (("q1w_rl"."_way_data_key"->>'type' = 'rail') AND ("q1w_rl"."all_tags"->>'traction' = 'funicular')))) THEN '{"qxcode": 506108, "gfcode": 6108}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND (("q1w_rl"."_way_data_key"->>'type' = 'rack') OR (("q1w_rl"."_way_data_key"->>'type' = 'rail') AND ("q1w_rl"."all_tags"->>'traction' = 'rack')) OR (("q1w_rl"."_way_data_key"->>'type' = 'rail') AND ("q1w_rl"."all_tags"->>'rack' IN ('1', 'true', 'yes'))))) THEN '{"qxcode": 506109, "gfcode": 6109}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'railway') AND ("q1w_rl"."_way_data_key"->>'type' IN ('rail', 'yes'))) THEN '{"qxcode": 506101, "gfcode": 6101}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'aerialway') AND ("q1w_rl"."_way_data_key"->>'type' = 'drag_lift')) THEN '{"qxcode": 506111, "gfcode": 6111}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'aerialway') AND ("q1w_rl"."_way_data_key"->>'type' IN ('chair_lift', 'high_speed_chair_lift'))) THEN '{"qxcode": 506112, "gfcode": 6112}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'aerialway') AND ("q1w_rl"."_way_data_key"->>'type' = 'cable_car')) THEN '{"qxcode": 506113, "gfcode": 6113}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'aerialway') AND ("q1w_rl"."_way_data_key"->>'type' = 'gondola')) THEN '{"qxcode": 506114, "gfcode": 6114}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'aerialway') AND ("q1w_rl"."_way_data_key"->>'type' = 'goods')) THEN '{"qxcode": 506115, "gfcode": 6115}'
		WHEN (("q1w_rl"."_way_data_key"->>'class' = 'aerialway') AND ("q1w_rl"."_way_data_key"->>'type' IN ('platter', 't-bar', 'j-bar', 'magic_carpet', 'zip_line', 'rope_tow', 'mixed_lif'))) THEN '{"qxcode": 506119, "gfcode": 6119}'
		ELSE NULL
	END)::JSONB AS "codes",
	"q1w_rl"."_way_data_key"->>'status' AS "lcstatus",
	-- "q1w_rl"."in_construction"::BOOLEAN AS "inconstrct",
	("q1w_rl"."all_tags"->>'name')::VARCHAR(100) AS "name",
	("q1w_rl"."all_tags"->>'ref')::VARCHAR(20) AS "ref",
	("q1w_rl"."all_tags"->>'int_ref')::VARCHAR(20) AS "int_ref",
	("q1w_rl"."all_tags"->>'railway:track_ref')::VARCHAR(20) AS "track_ref",
	(CASE
		WHEN ("q1w_rl"."all_tags"->>'electrified' IN ('1', 'contact_line', 'rail', 'true', 'yes')) THEN true
		WHEN ("q1w_rl"."all_tags"->>'electrified' IN ('0', 'false', 'no')) THEN false
		ELSE NULL
	END)::BOOLEAN AS "electr",
	"q1w_rl"."all_tags"->>'electrified'::VARCHAR(16) AS "electr_v",
	(CASE
		WHEN ("q1w_rl"."all_tags"->>'gauge' ~ '^[0-9]{1,5}$') THEN "q1w_rl"."all_tags"->>'gauge'
		ELSE NULL
	END)::SMALLINT AS "gauge",
	(CASE
		WHEN ("q1w_rl"."all_tags"->>'maxspeed' ~ '^[0-9]{1,5}$') THEN "q1w_rl"."all_tags"->>'maxspeed'
		ELSE NULL
	END)::SMALLINT AS "maxspeed",
	(CASE
		WHEN ("q1w_rl"."all_tags"->>'layer' ~ '^[0]+|(-?[1-9]{1,5})$') THEN "q1w_rl"."all_tags"->>'layer'
		ELSE '0'
	END)::SMALLINT AS "layer",
	("q1w_rl"."all_tags"->>'layer')::VARCHAR AS "layer_v",
	(CASE
		WHEN (("q1w_rl"."all_tags"->>'bridge' IS NOT NULL) AND ("q1w_rl"."all_tags"->>'bridge' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "bridge",
	(CASE
		WHEN (("q1w_rl"."all_tags"->>'bridge' IS NOT NULL) AND ("q1w_rl"."all_tags"->>'bridge' ~ '.+')) THEN LOWER("q1w_rl"."all_tags"->>'bridge')
		ELSE NULL
	END)::VARCHAR(32) AS "bridge_v",
	(CASE
		WHEN (("q1w_rl"."all_tags"->>'tunnel' IS NOT NULL) AND ("q1w_rl"."all_tags"->>'tunnel' ~ '.+')) THEN 1
		ELSE 0
	END)::SMALLINT AS "tunnel",
	(CASE
		WHEN (("q1w_rl"."all_tags"->>'tunnel' IS NOT NULL) AND ("q1w_rl"."all_tags"->>'tunnel' ~ '.+')) THEN LOWER("q1w_rl"."all_tags"->>'tunnel')
		ELSE NULL
	END)::VARCHAR(32) AS "tunnel_v",
	'W'::CHAR(1) AS "osmgeomsrc",
	"q1w_rl"."geom"
 FROM "q1w_rl"
 WHERE (
	"q1w_rl"."_way_data_key" IS NOT NULL
 )
)
SELECT
	"q_rl"."ogc_fid",
	"q_rl"."osm_id",
	"q_rl"."lcstatus",
	-- "q_rl"."inconstrct",
	"q_rl"."name",
	"q_rl"."ref",
	"q_rl"."int_ref",
	"q_rl"."track_ref",
	"q_rl"."electr",
	"q_rl"."electr_v",
	"q_rl"."gauge",
	"q_rl"."maxspeed",
	"q_rl"."layer",
	"q_rl"."layer_v",
	"q_rl"."bridge",
	"q_rl"."bridge_v",
	"q_rl"."tunnel",
	"q_rl"."tunnel_v",
	("q_rl"."codes"->>'qxcode')::INTEGER AS "qxcode",
	("q_rl"."codes"->>'gfcode')::SMALLINT AS "code",
	(CASE
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506101) THEN 'rail'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506102) THEN 'light_rail'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506103) THEN 'subway'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506104) THEN 'tram'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506105) THEN 'monorail'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506106) THEN 'narrow_gauge'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506107) THEN 'miniature'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506108) THEN 'funicular'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506109) THEN 'rack'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506111) THEN 'drag_lift'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506112) THEN 'chair_lift'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506113) THEN 'cable_car'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506114) THEN 'gondola'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506115) THEN 'goods'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506119) THEN 'other_lift'
		WHEN (("q_rl"."codes"->>'qxcode')::INTEGER = 506199) THEN 'other_rail'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
	'railways'::VARCHAR(16) AS "fxcateg",
	"q_rl"."lastchange",
	"q_rl"."osmgeomsrc",
	"q_rl"."geom"
 FROM "q2w_rl" AS "q_rl"
 WHERE (
		(("q_rl"."codes"->>'qxcode')::INTEGER > 506100) AND (("q_rl"."codes"->>'qxcode')::INTEGER <= 506199)
);

CREATE UNIQUE INDEX "qoxm_railways_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_railways_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "btree" ("osm_id" ASC);
CREATE INDEX "qoxm_railways_lastchange_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "btree" ("lastchange" ASC);
CREATE INDEX "qoxm_railways_code_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "btree" ("code" ASC);
CREATE INDEX "qoxm_railways_qxcode_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "btree" ("qxcode" ASC);
CREATE INDEX "qoxm_railways_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_railways_lcstatus_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "btree" ("lcstatus" ASC);
CREATE INDEX "qoxm_railways_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_railways" USING "gist" ("geom");

COMMIT;

66846bd11f2b4aa2b22067c21e20a45e
