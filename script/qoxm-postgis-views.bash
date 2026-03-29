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
 ORDER BY
	"tw1_li"."osm_id"::BIGINT ASC
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
	"q1w_ro"."all_tags"->>'access' AS "access",
	"q1w_ro"."all_tags"->>'horse' AS "horse",
	"q1w_ro"."all_tags"->>'motor_vehicle' AS "motor_veh",
	"q1w_ro"."all_tags"->>'motorcar' AS "motorcar",
	"q1w_ro"."all_tags"->>'motorcycle' AS "motorcycle",
	"q1w_ro"."all_tags"->>'vehicle' AS "vehicle",
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
 ORDER BY
	"q1w_ro"."osm_id"::BIGINT ASC
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
 FROM "q2w_ro" AS "q_ro"
 WHERE (
		("q_ro"."code" > 5100) AND ("q_ro"."code" <=5199)
);

CREATE UNIQUE INDEX "qoxm_roads_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("id" ASC);
CREATE UNIQUE INDEX "qoxm_roads_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("osm_id" ASC);
CREATE INDEX "qoxm_roads_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_roads_name_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("name" ASC);
CREATE INDEX "qoxm_roads_ref_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_roads" USING "btree" ("ref" ASC);
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
	'R'::CHAR(1) AS "osmgeomsrc",
	"tw1_mp"."geom"
 FROM "${OSM_DATA_TABLES_SCHEMA}"."multipolygons" AS "tw1_mp"
 WHERE (
	("tw1_mp"."all_tags"->>'landuse' IS NOT NULL)
	OR ("tw1_mp"."all_tags"->>'leisure' IS NOT NULL)
	OR ("tw1_mp"."all_tags"->>'natural' IS NOT NULL)
 )
 ORDER BY "tw1_mp"."osm_id"::BIGINT ASC
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
CREATE INDEX "qoxm_landuse_a_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_landuse_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_landuse_a" USING "gist" ("geom");

DROP MATERIALIZED VIEW IF EXISTS "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" CASCADE;

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
	"tw1_mp"."all_tags"->>'name'::VARCHAR(100) AS "name",
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
	ROW_NUMBER() OVER (ORDER BY "q_wa"."osm_id" ASC) AS "id",
	(CASE
		WHEN ("q_wa"."code" = 8200) THEN 'water'
		WHEN ("q_wa"."code" = 8201) THEN 'reservoir'
		WHEN ("q_wa"."code" = 8202) THEN 'river'
		WHEN ("q_wa"."code" = 8203) THEN 'dock'
		WHEN ("q_wa"."code" = 8211) THEN 'glacier'
		WHEN ("q_wa"."code" = 8221) THEN 'wetland'
		ELSE NULL
	END)::VARCHAR(40) AS "fclass",
	NULL AS "aal"
 FROM "qw_wa" AS "q_wa"
 WHERE (
	 "q_wa"."code" IS NOT NULL
);

CREATE UNIQUE INDEX "qoxm_water_a_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("id" ASC);
CREATE UNIQUE INDEX "qoxm_water_a_osm_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("osm_id" ASC);
CREATE UNIQUE INDEX "qoxm_water_a_osm_way_id_uniq" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("osm_way_id" ASC);
CREATE INDEX "qoxm_water_a_fclass_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "btree" ("fclass" ASC);
CREATE INDEX "qoxm_water_a_geom_idx" ON "${OSM_DATA_TABLES_SCHEMA}"."qoxm_water_a" USING "gist" ("geom");

COMMIT;

66846bd11f2b4aa2b22067c21e20a45e
