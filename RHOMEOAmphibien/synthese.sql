
-- Vue générique pour alimenter la synthèse dans le cadre d'un protocole site-visite-observation
-- 
-- Ce fichier peut être copié dans le dossier du sous-module et renommé en synthese.sql (et au besoin personnalisé)
-- le fichier sera joué à l'installation avec la valeur de module_code qui sera attribué automatiquement
--
--
-- Personalisations possibles
--
--  - ajouter des champs specifiques qui peuvent alimenter la synthese
--      jointure avec les table de complement
--
--  - choisir les valeurs de champs de nomenclatures qui seront propres au modules


-- ce fichier contient une variable :module_code (ou :'module_code')
-- utiliser psql avec l'option -v module_code=<module_code

-- ne pas remplacer cette variable, elle est indispensable pour les scripts d'installations
-- le module pouvant être installé avec un code différent de l'original

DROP VIEW IF EXISTS gn_monitoring.v_synthese_RHOMEOAmphibien;
CREATE VIEW gn_monitoring.v_synthese_RHOMEOAmphibien AS

WITH source AS (

	SELECT

        id_source

    FROM gn_synthese.t_sources
	WHERE name_source = CONCAT('MONITORING_', UPPER('RHOMEOAmphibien'))
	LIMIT 1

), sites AS (

    SELECT

        id_base_site,
        geom AS the_geom_4326,
	    ST_CENTROID(geom) AS the_geom_point,
	    geom_local as the_geom_local

        FROM gn_monitoring.t_base_sites

), visits AS (
    
    SELECT
    
        id_base_visit,
        uuid_base_visit,
        id_module,
        id_base_site,
        id_dataset,
        id_digitiser,

        visit_date_min AS date_min,
	    COALESCE (visit_date_max, visit_date_min) AS date_max,
        comments,

	    --o.observers,
	    --o.ids_observers,

    	id_nomenclature_tech_collect_campanule,
	    id_nomenclature_grp_typ

        FROM gn_monitoring.t_base_visits

), observers AS (
    SELECT
        array_agg(r.id_role) AS ids_observers,
        STRING_AGG(CONCAT(r.nom_role, ' ', prenom_role), ' ; ') AS observers,
        id_base_visit
    FROM gn_monitoring.cor_visit_observer cvo
    JOIN utilisateurs.t_roles r
    ON r.id_role = cvo.id_role
    GROUP BY id_base_visit
)

SELECT
		
        o.uuid_observation AS unique_id_sinp, 
		v.uuid_base_visit AS unique_id_sinp_grp,
		source.id_source,
		o.id_observation AS entity_source_pk_value,
		v.id_dataset,
        ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'St') AS id_nomenclature_geo_object_nature,
		v.id_nomenclature_tech_collect_campanule, --TECHNIQUE_OBS
		--id_nomenclature_bio_status, -- STATUT_BIO
		--id_nomenclature_bio_condition, -- ETA_BIO
		--id_nomenclature_naturalness, -- NATURALITE
		--id_nomenclature_exist_proof, -- PREUVE_EXIST
		--id_nomenclature_valid_status,  --STATUT_VALID
		--id_nomenclature_diffusion_level, -- NIV_PRECIS
		--oc.id_nomenclature_life_stage, -- STADE_VIE
		--id_nomenclature_sex, -- SEXE
 		ref_nomenclatures.get_id_nomenclature('OBJ_DENBR','IND') AS id_nomenclature_obj_count,
 		ref_nomenclatures.get_id_nomenclature('TYP_DENBR', 'Es') AS id_nomenclature_type_count,
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status,
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type,
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'REL') as id_nomenclature_grp_typ, 
    	ref_nomenclatures.get_id_nomenclature('NIV_PRECIS', '4') as id_nomenclature_diffusion_level, -- pas de diffusion pour l'instant (en attente des règles),
 		ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr') AS id_nomenclature_observation_status, 
		CASE WHEN (oc.data->>'nombre_compte') IS NULL THEN SPLIT_PART(REPLACE((oc.data->>'nombre')::text,'> ','')::text,' à ',1)::int
			ELSE (oc.data->>'nombre_compte')::int
		END AS count_min,
		CASE WHEN (oc.data->>'nombre_compte') IS NULL THEN 
			CASE WHEN SPLIT_PART(REPLACE((oc.data->>'nombre')::text,'> ','')::text,' à ',2) = '' THEN 9999
				ELSE SPLIT_PART(REPLACE((oc.data->>'nombre')::text,'> ','')::text,' à ',2)::int
			END
			ELSE (oc.data->>'nombre_compte')::int
		END AS count_max,
		id_observation,    
		t.cd_nom,
    	t.nom_complet AS nom_cite,
		(oc."data"->>'id_nomenclature_life_stage')::integer AS id_nomenclature_life_stage,
		--meta_v_taxref
		--sample_number_proof
		--digital_proofvue
		alt.altitude_min,
		alt.altitude_max,
		s.the_geom_4326,
		s.the_geom_point,
		s.the_geom_local,
		v.date_min,
		v.date_max,
		--validator
		--validation_comment
		obs.observers,
		--determiner
		v.id_digitiser,
		--id_nomenclature_determination_method
		--meta_validation_date
		--meta_create_date,
		--meta_update_date,
		--last_action
		v.id_module,
		v.comments AS comment_context,
		o.comments AS comment_description,
		obs.ids_observers,
		
		-- ## Colonnes complémentaires qui ont leur utilité dans la fonction synthese.import_row_from_table
		v.id_base_site,
		v.id_base_visit

    FROM gn_monitoring.t_observations o 
	JOIN gn_monitoring.t_observation_complements oc USING (id_observation)

    JOIN visits v
        ON v.id_base_visit = o.id_base_visit
    JOIN sites s 
        ON s.id_base_site = v.id_base_site
	JOIN gn_commons.t_modules m 
        ON m.id_module = v.id_module
	JOIN taxonomie.taxref t 
        ON t.cd_nom = o.cd_nom
	JOIN source 
        ON TRUE
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
    
 	LEFT JOIN LATERAL ref_geo.fct_get_altitude_intersection(s.the_geom_local) alt (altitude_min, altitude_max)
        ON TRUE
    WHERE m.module_code = 'RHOMEOAmphibien'
    ;
