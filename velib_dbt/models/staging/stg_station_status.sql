-- Etat de chaque station a chaque releve, nettoye et nomme en clair.
-- On y calcule les deux etats qui font perdre une course :
--   station vide  -> aucun velo a prendre
--   station pleine -> aucune place pour rendre

with source as (

    select * from {{ source('velib_raw', 'raw_station_status') }}

),

nettoye as (

    select
        snapshot_ts,
        station_id,
        coalesce(num_bikes_total, 0)     as velos_disponibles,
        coalesce(num_bikes_mecha, 0)     as velos_mecaniques,
        coalesce(num_bikes_ebike, 0)     as velos_electriques,
        coalesce(num_docks_available, 0) as places_libres,
        is_installed = 1                 as est_installee,
        is_renting   = 1                 as accepte_location,
        is_returning = 1                 as accepte_retour,
        last_reported
    from source

)

select
    *,
    velos_disponibles + places_libres           as bornes_actives,
    velos_disponibles = 0                       as est_vide,
    places_libres = 0                           as est_pleine,
    velos_disponibles = 0 or places_libres = 0  as est_en_rupture
from nettoye