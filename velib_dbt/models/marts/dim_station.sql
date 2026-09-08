-- Une ligne par station.

select
    station_id,
    station_code,
    nom_station,
    latitude,
    longitude,
    capacite_theorique
from {{ ref('stg_station') }}