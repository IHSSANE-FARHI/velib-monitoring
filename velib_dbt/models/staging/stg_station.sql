-- Caracteristiques des stations. Une ligne par station.

select
    station_id,
    station_code,
    trim(name)  as nom_station,
    lat         as latitude,
    lon         as longitude,
    capacity    as capacite_theorique,
    loaded_at   as maj_le
from {{ source('velib_raw', 'raw_station_information') }}