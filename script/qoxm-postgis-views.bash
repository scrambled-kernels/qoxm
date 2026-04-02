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
		ELSE NULL
	END)::SMALLINT AS "layer",
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
		("q_ro"."code" > 5100) AND ("q_ro"."code" <=5199)
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
	"tw1_po"."geom"
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
	ST_Centroid("tw1_mp"."geom", true) AS "geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" AS "tw1_mp"
 WHERE (
	COALESCE("tw1_mp"."all_tags"->>'amenity', "tw1_po"."all_tags"->>'emergency', "tw1_po"."all_tags"->>'highway', "tw1_mp"."all_tags"->>'historic', "tw1_mp"."all_tags"->>'landuse', "tw1_mp"."all_tags"->>'leisure', "tw1_mp"."all_tags"->>'man_made', "tw1_mp"."all_tags"->>'office', "tw1_mp"."all_tags"->>'shop', "tw1_mp"."all_tags"->>'sport', "tw1_mp"."all_tags"->>'vending') IS NOT NULL
 )
),
"qw_pi" AS (SELECT
	"tw2_px"."osm_id",
	"tw2_px"."osm_way_id",
	"tw2_px"."lastchange",
	("tw2_px"."all_tags"->>'name')::VARCHAR(100) AS "name",
	(CASE
		WHEN ("tw2_px"."all_tags"->>'layer' ~ '^[0-9]+$') THEN "tw2_px"."all_tags"->>'layer'
		ELSE NULL
	END)::SMALLINT AS "layer",
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
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'police') THEN 2001
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'fire_station') THEN 2002
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'post_box') THEN 2004
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'post_office') THEN 2005
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'telephone') THEN 2006
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'library') THEN 2007
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'townhall') THEN 2008
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'courthouse') THEN 2009
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'prison') THEN 2010
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'embassy') OR ("tw2_px"."all_tags"->>'office' = 'diplomatic')) THEN 2011
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'community_centre') THEN 2012
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'nursing_home') THEN 2013
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'arts_centre') THEN 2014
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'grave_yard') OR ("tw2_px"."all_tags"->>'landuse' = 'cemetery')) THEN 2015
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'marketplace') THEN 2016
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND (("tw2_px"."all_tags"->>'recycling:glass' IN ('1', 'true', 'yes')) OR ("tw2_px"."all_tags"->>'recycling:glass_bottles' IN ('1', 'true', 'yes')))) THEN 2031
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND ("tw2_px"."all_tags"->>'recycling:paper' IN ('1', 'true', 'yes'))) THEN 2032
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND ("tw2_px"."all_tags"->>'recycling:clothes' IN ('1', 'true', 'yes'))) THEN 2033
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'recycling') AND ("tw2_px"."all_tags"->>'recycling:scrap_metal' IN ('1', 'true', 'yes'))) THEN 2034
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'recycling') THEN 2030
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'university') THEN 2081
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'school') THEN 2081
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'kindergarten') THEN 2083
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'college') THEN 2084
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'public_building') THEN 2099
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'pharmacy') THEN 2101
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'hospital') THEN 2110
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'clinic') THEN 2111
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'doctors') THEN 2120
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'dentist') THEN 2121
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'veterinary') THEN 2129
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'theatre') THEN 2201
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'nightclub') THEN 2202
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'cinema') THEN 2203
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'park') OR ("tw2_px"."all_tags"->>'leisure' = 'park')) THEN 2204
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'playground') OR ("tw2_px"."all_tags"->>'leisure' = 'playground')) THEN 2205
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'dog_park') OR ("tw2_px"."all_tags"->>'leisure' = 'dog_park')) THEN 2206
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'sports_centre') OR ("tw2_px"."all_tags"->>'leisure' = 'sports_centre')) THEN 2251
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'pitch') OR ("tw2_px"."all_tags"->>'leisure' = 'pitch')) THEN 2252
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'swimming_pool') OR ("tw2_px"."all_tags"->>'leisure' IN ('swimming_pool', 'water_park')) OR ("tw2_px"."all_tags"->>'sport' = 'swimming')) THEN 2253
		WHEN ("tw2_px"."all_tags"->>'sport' = 'tennis') THEN 2254
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'golf_course') OR ("tw2_px"."all_tags"->>'leisure' = 'golf_course')) THEN 2255
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'stadium') OR ("tw2_px"."all_tags"->>'leisure' = 'stadium')) THEN 2256
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'ice_rink') OR ("tw2_px"."all_tags"->>'leisure' = 'ice_rink')) THEN 2257
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'restaurant') THEN 2301
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'fast_food') THEN 2302
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'cafe') THEN 2303
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'pub') THEN 2304
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bar') THEN 2305
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'food_court') THEN 2306
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'biergarten') THEN 2307
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'hotel') OR ("tw2_px"."all_tags"->>'tourism' = 'hotel')) THEN 2401
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'motel') OR ("tw2_px"."all_tags"->>'tourism' = 'motel')) THEN 2402
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'bed_and_breakfast') OR ("tw2_px"."all_tags"->>'tourism' = 'bed_and_breakfast')) THEN 2403
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'guest_house') OR ("tw2_px"."all_tags"->>'tourism' = 'guest_house')) THEN 2404
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'hostel') OR ("tw2_px"."all_tags"->>'tourism' = 'hostel')) THEN 2405
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'chalet') OR ("tw2_px"."all_tags"->>'tourism' = 'chalet')) THEN 2406
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'shelter') OR ("tw2_px"."all_tags"->>'tourism' = 'shelter')) THEN 2421
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'camp_site') OR ("tw2_px"."all_tags"->>'tourism' = 'camp_site')) THEN 2422
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'alpine_hut') OR ("tw2_px"."all_tags"->>'tourism' = 'alpine_hut')) THEN 2423
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'caravan_site') OR ("tw2_px"."all_tags"->>'tourism' = 'caravan_site')) THEN 2424
		WHEN ("tw2_px"."all_tags"->>'shop' = 'supermarket') THEN 2501
		WHEN ("tw2_px"."all_tags"->>'shop' = 'bakery') THEN 2502
		WHEN ("tw2_px"."all_tags"->>'shop' = 'kiosk') THEN 2503
		WHEN ("tw2_px"."all_tags"->>'shop' = 'mall') THEN 2504
		WHEN ("tw2_px"."all_tags"->>'shop' = 'department_store') THEN 2505
		WHEN ("tw2_px"."all_tags"->>'shop' = 'general') THEN 2510
		WHEN ("tw2_px"."all_tags"->>'shop' = 'convenience') THEN 2511
		WHEN ("tw2_px"."all_tags"->>'shop' = 'clothes') THEN 2512
		WHEN ("tw2_px"."all_tags"->>'shop' = 'florist') THEN 2513
		WHEN ("tw2_px"."all_tags"->>'shop' = 'chemist') THEN 2514
		WHEN ("tw2_px"."all_tags"->>'shop' = 'books') THEN 2515
		WHEN ("tw2_px"."all_tags"->>'shop' = 'butcher') THEN 2516
		WHEN ("tw2_px"."all_tags"->>'shop' = 'shoes') THEN 2517
		WHEN (("tw2_px"."all_tags"->>'shop' = 'alcohol') OR ("tw2_px"."all_tags"->>'shop' = 'beverages')) THEN 2518
		WHEN ("tw2_px"."all_tags"->>'shop' = 'optician') THEN 2519
		WHEN ("tw2_px"."all_tags"->>'shop' = 'jewelry') THEN 2520
		WHEN ("tw2_px"."all_tags"->>'shop' = 'gift') THEN 2521
		WHEN ("tw2_px"."all_tags"->>'shop' = 'sports') THEN 2522
		WHEN ("tw2_px"."all_tags"->>'shop' = 'stationery') THEN 2523
		WHEN ("tw2_px"."all_tags"->>'shop' = 'outdoor') THEN 2524
		WHEN ("tw2_px"."all_tags"->>'shop' = 'mobile_phone') THEN 2525
		WHEN ("tw2_px"."all_tags"->>'shop' = 'toys') THEN 2526
		WHEN ("tw2_px"."all_tags"->>'shop' = 'newsagent') THEN 2527
		WHEN ("tw2_px"."all_tags"->>'shop' = 'greengrocer') THEN 2528
		WHEN ("tw2_px"."all_tags"->>'shop' = 'beauty') THEN 2529
		WHEN ("tw2_px"."all_tags"->>'shop' = 'video') THEN 2530
		WHEN ("tw2_px"."all_tags"->>'shop' = 'car') THEN 2541
		WHEN ("tw2_px"."all_tags"->>'shop' = 'bicycle') THEN 2542
		WHEN (("tw2_px"."all_tags"->>'shop' = 'doityourself') OR ("tw2_px"."all_tags"->>'shop' = 'hardware')) THEN 2543
		WHEN ("tw2_px"."all_tags"->>'shop' = 'furniture') THEN 2544
		WHEN ("tw2_px"."all_tags"->>'shop' = 'computer') THEN 2546
		WHEN ("tw2_px"."all_tags"->>'shop' = 'garden_centre') THEN 2547
		WHEN ("tw2_px"."all_tags"->>'shop' = 'hairdresser') THEN 2561
		WHEN ("tw2_px"."all_tags"->>'shop' = 'car_repair') THEN 2562
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'car_rental') THEN 2563
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'car_wash') THEN 2564
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'car_sharing') THEN 2565
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bicycle_rental') THEN 2566
		WHEN ("tw2_px"."all_tags"->>'shop' = 'travel_agency') THEN 2567
		WHEN (("tw2_px"."all_tags"->>'shop' = 'laundry') OR ("tw2_px"."all_tags"->>'shop' = 'dry_cleaning')) THEN 2568
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'vending_machine') OR ("tw2_px"."all_tags"->>'vending' = 'cigarettes')) THEN 2591
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'vending_machine') OR ("tw2_px"."all_tags"->>'vending' = 'parking_tickets')) THEN 2592
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'vending_machine') THEN 2590
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bank') THEN 2601
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'atm') THEN 2602
		WHEN (("tw2_px"."all_tags"->>'tourism' = 'information') AND ("tw2_px"."all_tags"->>'information' = 'map')) THEN 2704
		WHEN (("tw2_px"."all_tags"->>'tourism' = 'information') AND ("tw2_px"."all_tags"->>'information' = 'board')) THEN 2705
		WHEN (("tw2_px"."all_tags"->>'tourism' = 'information') AND ("tw2_px"."all_tags"->>'information' = 'guidepost')) THEN 2706
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'information') THEN 2701
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'attraction') THEN 2721
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'museum') THEN 2722
		WHEN ("tw2_px"."all_tags"->>'historic' = 'monument') THEN 2723
		WHEN ("tw2_px"."all_tags"->>'historic' = 'memorial') THEN 2724
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'artwork') THEN 2725
		WHEN ("tw2_px"."all_tags"->>'historic' = 'castle') THEN 2731
		WHEN ("tw2_px"."all_tags"->>'historic' = 'ruins') THEN 2732
		WHEN ("tw2_px"."all_tags"->>'historic' = 'archaeological_site') THEN 2733
		WHEN ("tw2_px"."all_tags"->>'historic' = 'wayside_cross') THEN 2734
		WHEN ("tw2_px"."all_tags"->>'historic' = 'wayside_shrine') THEN 2735
		WHEN ("tw2_px"."all_tags"->>'historic' = 'battlefield') THEN 2736
		WHEN ("tw2_px"."all_tags"->>'historic' = 'fort') THEN 2737
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'picnic_site') THEN 2741
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'viewpoint') THEN 2742
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'zoo') THEN 2743
		WHEN ("tw2_px"."all_tags"->>'tourism' = 'theme_park') THEN 2744
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'toilets') THEN 2901
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'bench') THEN 2902
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'drinking_water') THEN 2903
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'fountain') THEN 2904
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'hunting_stand') THEN 2905
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'waste_basket') THEN 2906
		WHEN ("tw2_px"."all_tags"->>'amenity' = 'surveillance') THEN 2907
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'emergency_phone') OR ("tw2_px"."all_tags"->>'emergency' = 'phone')) THEN 2921
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'fire_hydrant') OR ("tw2_px"."all_tags"->>'emergency' = 'fire_hydrant')) THEN 2922
		WHEN (("tw2_px"."all_tags"->>'amenity' = 'emergency_access_point') OR ("tw2_px"."all_tags"->>'highway' = 'emergency_access_point')) THEN 2923
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'communication')) THEN 2951
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'water_tower') OR (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'water'))) THEN 2952
		WHEN (("tw2_px"."all_tags"->>'man_made' = 'tower') AND ("tw2_px"."all_tags"->>'tower:type' = 'observation')) THEN 2953
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'tower') THEN 2950
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'windmill') THEN 2954
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'lighthouse') THEN 2955
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'wastewater_plant') THEN 2961
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'water_well') THEN 2962
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'watermill') THEN 2963
		WHEN ("tw2_px"."all_tags"->>'man_made' = 'water_works') THEN 2964
	END)::SMALLINT AS "code",
	"tw2_px"."osmgeomsrc",
	"tw2_px"."geom"
 FROM "qw_mx" AS "tw2_px"
)
SELECT
	"q_px".*,
	ROW_NUMBER() OVER (ORDER BY "q_px"."osm_id" ASC NULLS LAST, "osm_way_id" ASC NULLS LAST) AS "ogc_fid",
	(CASE
		WHEN ("q_px"."code" = 2001) THEN 'police'
		WHEN ("q_px"."code" = 2002) THEN 'fire_station'
		WHEN ("q_px"."code" = 2004) THEN 'post_box'
		WHEN ("q_px"."code" = 2005) THEN 'post_office'
		WHEN ("q_px"."code" = 2006) THEN 'telephone'
		WHEN ("q_px"."code" = 2007) THEN 'library'
		WHEN ("q_px"."code" = 2008) THEN 'town_hall'
		WHEN ("q_px"."code" = 2009) THEN 'courthouse'
		WHEN ("q_px"."code" = 2010) THEN 'prison'
		WHEN ("q_px"."code" = 2011) THEN 'embassy'
		WHEN ("q_px"."code" = 2012) THEN 'community_centre'
		WHEN ("q_px"."code" = 2013) THEN 'nursing_home'
		WHEN ("q_px"."code" = 2014) THEN 'arts_centre'
		WHEN ("q_px"."code" = 2015) THEN 'graveyard'
		WHEN ("q_px"."code" = 2016) THEN 'market_place'
		WHEN ("q_px"."code" = 2030) THEN 'recycling'
		WHEN ("q_px"."code" = 2031) THEN 'recycling_glass'
		WHEN ("q_px"."code" = 2032) THEN 'recycling_paper'
		WHEN ("q_px"."code" = 2033) THEN 'recycling_clothes'
		WHEN ("q_px"."code" = 2034) THEN 'recycling_metal'
		WHEN ("q_px"."code" = 2081) THEN 'university'
		WHEN ("q_px"."code" = 2082) THEN 'school'
		WHEN ("q_px"."code" = 2083) THEN 'kindergarten'
		WHEN ("q_px"."code" = 2084) THEN 'college'
		WHEN ("q_px"."code" = 2099) THEN 'public_building'
		WHEN ("q_px"."code" = 2101) THEN 'pharmacy'
		WHEN ("q_px"."code" = 2110) THEN 'hospital'
		WHEN ("q_px"."code" = 2111) THEN 'clinic'
		WHEN ("q_px"."code" = 2120) THEN 'doctors'
		WHEN ("q_px"."code" = 2121) THEN 'dentist'
		WHEN ("q_px"."code" = 2129) THEN 'veterinary'
		WHEN ("q_px"."code" = 2201) THEN 'theatre'
		WHEN ("q_px"."code" = 2202) THEN 'nightclub'
		WHEN ("q_px"."code" = 2203) THEN 'cinema'
		WHEN ("q_px"."code" = 2204) THEN 'park'
		WHEN ("q_px"."code" = 2205) THEN 'playground'
		WHEN ("q_px"."code" = 2206) THEN 'dog_park'
		WHEN ("q_px"."code" = 2251) THEN 'sports_centre'
		WHEN ("q_px"."code" = 2252) THEN 'pitch'
		WHEN ("q_px"."code" = 2253) THEN 'swimming_pool'
		WHEN ("q_px"."code" = 2254) THEN 'tennis_court'
		WHEN ("q_px"."code" = 2255) THEN 'golf_course'
		WHEN ("q_px"."code" = 2256) THEN 'stadium'
		WHEN ("q_px"."code" = 2257) THEN 'ice_rink'
		WHEN ("q_px"."code" = 2301) THEN 'restaurant'
		WHEN ("q_px"."code" = 2302) THEN 'fast_food'
		WHEN ("q_px"."code" = 2303) THEN 'cafe'
		WHEN ("q_px"."code" = 2304) THEN 'pub'
		WHEN ("q_px"."code" = 2305) THEN 'bar'
		WHEN ("q_px"."code" = 2306) THEN 'food_court'
		WHEN ("q_px"."code" = 2307) THEN 'biergarten'
		WHEN ("q_px"."code" = 2401) THEN 'hotel'
		WHEN ("q_px"."code" = 2402) THEN 'motel'
		WHEN ("q_px"."code" = 2403) THEN 'bed_and_breakfast'
		WHEN ("q_px"."code" = 2404) THEN 'guesthouse'
		WHEN ("q_px"."code" = 2405) THEN 'hostel'
		WHEN ("q_px"."code" = 2406) THEN 'chalet'
		WHEN ("q_px"."code" = 2421) THEN 'shelter'
		WHEN ("q_px"."code" = 2422) THEN 'camp_site'
		WHEN ("q_px"."code" = 2423) THEN 'alpine_hut'
		WHEN ("q_px"."code" = 2424) THEN 'caravan_site'
		WHEN ("q_px"."code" = 2501) THEN 'supermarket'
		WHEN ("q_px"."code" = 2502) THEN 'bakery'
		WHEN ("q_px"."code" = 2503) THEN 'kiosk'
		WHEN ("q_px"."code" = 2504) THEN 'mall'
		WHEN ("q_px"."code" = 2505) THEN 'department_store'
		WHEN ("q_px"."code" = 2510) THEN 'general'
		WHEN ("q_px"."code" = 2511) THEN 'convenience'
		WHEN ("q_px"."code" = 2512) THEN 'clothes'
		WHEN ("q_px"."code" = 2513) THEN 'florist'
		WHEN ("q_px"."code" = 2514) THEN 'chemist'
		WHEN ("q_px"."code" = 2515) THEN 'bookshop'
		WHEN ("q_px"."code" = 2516) THEN 'butcher'
		WHEN ("q_px"."code" = 2517) THEN 'shoe_shop'
		WHEN ("q_px"."code" = 2518) THEN 'beverages'
		WHEN ("q_px"."code" = 2519) THEN 'optician'
		WHEN ("q_px"."code" = 2520) THEN 'jeweller'
		WHEN ("q_px"."code" = 2521) THEN 'gift_shop'
		WHEN ("q_px"."code" = 2522) THEN 'sports_shop'
		WHEN ("q_px"."code" = 2523) THEN 'stationery'
		WHEN ("q_px"."code" = 2524) THEN 'outdoor_shop'
		WHEN ("q_px"."code" = 2525) THEN 'mobile_phone_shop'
		WHEN ("q_px"."code" = 2526) THEN 'toy_shop'
		WHEN ("q_px"."code" = 2527) THEN 'newsagent'
		WHEN ("q_px"."code" = 2528) THEN 'greengrocer'
		WHEN ("q_px"."code" = 2529) THEN 'beauty_shop'
		WHEN ("q_px"."code" = 2530) THEN 'video_shop'
		WHEN ("q_px"."code" = 2541) THEN 'car_dealership'
		WHEN ("q_px"."code" = 2542) THEN 'bicycle_shop'
		WHEN ("q_px"."code" = 2543) THEN 'doityourself'
		WHEN ("q_px"."code" = 2544) THEN 'furniture_shop'
		WHEN ("q_px"."code" = 2546) THEN 'computer_shop'
		WHEN ("q_px"."code" = 2547) THEN 'garden_centre'
		WHEN ("q_px"."code" = 2561) THEN 'hairdresser'
		WHEN ("q_px"."code" = 2562) THEN 'car_repair'
		WHEN ("q_px"."code" = 2563) THEN 'car_rental'
		WHEN ("q_px"."code" = 2564) THEN 'car_wash'
		WHEN ("q_px"."code" = 2565) THEN 'car_sharing'
		WHEN ("q_px"."code" = 2566) THEN 'bicycle_rental'
		WHEN ("q_px"."code" = 2567) THEN 'travel_agent'
		WHEN ("q_px"."code" = 2568) THEN 'laundry'
		WHEN ("q_px"."code" = 2590) THEN 'vending_machine'
		WHEN ("q_px"."code" = 2591) THEN 'vending_cigarette'
		WHEN ("q_px"."code" = 2592) THEN 'vending_parking'
		WHEN ("q_px"."code" = 2601) THEN 'bank'
		WHEN ("q_px"."code" = 2602) THEN 'atm'
		WHEN ("q_px"."code" = 2701) THEN 'tourist_info'
		WHEN ("q_px"."code" = 2704) THEN 'tourist_map'
		WHEN ("q_px"."code" = 2705) THEN 'tourist_board'
		WHEN ("q_px"."code" = 2706) THEN 'tourist_guidepost'
		WHEN ("q_px"."code" = 2721) THEN 'attraction'
		WHEN ("q_px"."code" = 2722) THEN 'museum'
		WHEN ("q_px"."code" = 2723) THEN 'monument'
		WHEN ("q_px"."code" = 2724) THEN 'memorial'
		WHEN ("q_px"."code" = 2725) THEN 'art'
		WHEN ("q_px"."code" = 2731) THEN 'castle'
		WHEN ("q_px"."code" = 2732) THEN 'ruins'
		WHEN ("q_px"."code" = 2733) THEN 'archaeological'
		WHEN ("q_px"."code" = 2734) THEN 'wayside_cross'
		WHEN ("q_px"."code" = 2735) THEN 'wayside_shrine'
		WHEN ("q_px"."code" = 2736) THEN 'battlefield'
		WHEN ("q_px"."code" = 2737) THEN 'fort'
		WHEN ("q_px"."code" = 2741) THEN 'picnic_site'
		WHEN ("q_px"."code" = 2742) THEN 'viewpoint'
		WHEN ("q_px"."code" = 2743) THEN 'zoo'
		WHEN ("q_px"."code" = 2744) THEN 'theme_park'
		WHEN ("q_px"."code" = 2901) THEN 'toilet'
		WHEN ("q_px"."code" = 2902) THEN 'bench'
		WHEN ("q_px"."code" = 2903) THEN 'drinking_water'
		WHEN ("q_px"."code" = 2904) THEN 'fountain'
		WHEN ("q_px"."code" = 2905) THEN 'hunting_stand'
		WHEN ("q_px"."code" = 2906) THEN 'waste_basket'
		WHEN ("q_px"."code" = 2907) THEN 'camera_surveillance'
		WHEN ("q_px"."code" = 2921) THEN 'emergency_phone'
		WHEN ("q_px"."code" = 2922) THEN 'fire_hydrant'
		WHEN ("q_px"."code" = 2923) THEN 'emergency_access'
		WHEN ("q_px"."code" = 2950) THEN 'tower'
		WHEN ("q_px"."code" = 2951) THEN 'tower_comms'
		WHEN ("q_px"."code" = 2952) THEN 'water_tower'
		WHEN ("q_px"."code" = 2953) THEN 'tower_observation'
		WHEN ("q_px"."code" = 2954) THEN 'windmill'
		WHEN ("q_px"."code" = 2955) THEN 'lighthouse'
		WHEN ("q_px"."code" = 2961) THEN 'wastewater_plant'
		WHEN ("q_px"."code" = 2962) THEN 'water_well'
		WHEN ("q_px"."code" = 2963) THEN 'water_mill'
		WHEN ("q_px"."code" = 2964) THEN 'water_works'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
	(CASE
		WHEN ("q_px"."code" BETWEEN 2001 AND 2099) THEN 'public'
		WHEN ("q_px"."code" BETWEEN 2101 AND 2199) THEN 'health'
		WHEN ("q_px"."code" BETWEEN 2201 AND 2299) THEN 'leisure'
		WHEN ("q_px"."code" BETWEEN 2301 AND 2399) THEN 'catering'
		WHEN ("q_px"."code" BETWEEN 2401 AND 2499) THEN 'accommodation'
		WHEN ("q_px"."code" BETWEEN 2501 AND 2599) THEN 'shopping'
		WHEN ("q_px"."code" BETWEEN 2601 AND 2699) THEN 'money'
		WHEN ("q_px"."code" BETWEEN 2701 AND 2799) THEN 'tourism'
		WHEN ("q_px"."code" BETWEEN 2901 AND 2999) THEN 'miscpoi'
		ELSE NULL
	END)::VARCHAR(16) AS "fxcateg",
	true AS "aal"
 FROM "qw_pi" AS "q_px"
 WHERE (
	"q_px"."code" IS NOT NULL
 )
 ORDER BY
	"ogc_fid" ASC;

CREATE UNIQUE INDEX "qoxm_pois_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("ogc_fid" ASC);
CREATE UNIQUE INDEX "qoxm_pois_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("osm_id" ASC);
CREATE UNIQUE INDEX "qoxm_pois_osm_way_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("osm_way_id" ASC);
CREATE INDEX "qoxm_pois_lastchange_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("lastchange" ASC);
CREATE INDEX "qoxm_pois_code_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("code" ASC);
CREATE INDEX "qoxm_pois_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_pois_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_pois" USING "gist" ("geom");

COMMIT;

66846bd11f2b4aa2b22067c21e20a45e
