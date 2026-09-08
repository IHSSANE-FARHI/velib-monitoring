-- Dimension station, enrichie d un indicateur d exploitation reelle.
--
-- PIEGE TRAITE ICI : 16 stations affichent 0 velo sur TOUS les releves, avec
-- toutes leurs places libres. Bornes installees, jamais approvisionnees :
-- stations neuves, fermees, ou evenementielles (ex. "Station Tour de France",
-- capacite 204). Elles ne sont pas "en rupture" au sens metier -- personne
-- n enverra un camion -- et les compter fausserait tous les taux.
--
-- Le discriminant n est ni is_installed, ni la capacite, mais la VARIATION :
-- une station exploitee fluctue, une station inactive ne bouge jamais.

with activite as (

    select
        station_id,
        count(*)               as nb_releves,
        max(velos_disponibles) as velos_max_observe,
        max(places_libres)     as places_max_observe
    from {{ ref('stg_station_status') }}
    where est_installee
    group by station_id

)

select
    s.station_id,
    s.station_code,
    s.nom_station,
    s.latitude,
    s.longitude,
    s.capacite_theorique,
    coalesce(a.nb_releves, 0)          as nb_releves,
    coalesce(a.velos_max_observe, 0)   as velos_max_observe,
    coalesce(a.places_max_observe, 0)  as places_max_observe,
    coalesce(a.velos_max_observe, 0) > 0
        and coalesce(a.places_max_observe, 0) > 0 as est_en_exploitation
from {{ ref('stg_station') }} s
left join activite a using (station_id)