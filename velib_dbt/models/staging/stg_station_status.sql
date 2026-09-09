-- Etat de chaque station a chaque releve, nettoye et nomme en clair.
--
-- PIEGE 1 : une station hors service affiche 0 velo ET 0 place. Elle coche
-- donc a la fois "vide" et "pleine", en permanence, et ferait apparaitre un
-- taux de rupture de 100 % sans qu aucun usager soit gene. Le discriminant :
-- une vraie station pleine a des velos, une vraie station vide a des places.
--
-- PIEGE 2 : le flux publie deux drapeaux, is_renting et is_returning, qui
-- disent directement si la station loue et recoit. 23 stations les ont a 0.
-- Mesure : "Gare du Stade" affiche 0 velo / 20 places sur 149 releves
-- consecutifs, n a emis qu UNE fois en 22 heures (last_reported constant,
-- retard moyen 762 minutes) et porte is_renting = 0, is_returning = 0.
-- Elle occupait la premiere place du classement des ruptures.
--
-- Ces drapeaux sont juges RELEVE PAR RELEVE, et c est essentiel : une station
-- peut sortir du service en milieu de journee. Un critere calcule par jour ne
-- voit pas ce basculement -- c est l erreur que faisait le modele precedent.

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
    velos_disponibles + places_libres > 0       as est_en_service,
    est_installee
        and accepte_location
        and accepte_retour
        and velos_disponibles + places_libres > 0   as est_exploitee,
    velos_disponibles = 0                       as est_vide,
    places_libres = 0                           as est_pleine,
    velos_disponibles = 0 or places_libres = 0  as est_en_rupture
from nettoye