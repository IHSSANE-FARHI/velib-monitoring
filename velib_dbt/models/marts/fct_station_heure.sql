-- Taux de rupture par station et par heure.
--
-- On mesure une PROPORTION DE RELEVES, pas un nombre de minutes : la cadence
-- de collecte est irreguliere (GitHub ne garantit pas les crons courts), donc
-- une mesure en minutes serait biaisee. Une proportion reste juste.

select
    station_id,
    date_trunc('hour', snapshot_ts)                       as heure,
    count(*)                                              as nb_releves,
    round(avg(velos_disponibles)::numeric, 2)             as velos_moyen,
    round(avg(places_libres)::numeric, 2)                 as places_moyen,
    sum(case when est_vide       then 1 else 0 end)       as releves_vide,
    sum(case when est_pleine     then 1 else 0 end)       as releves_pleine,
    sum(case when est_en_rupture then 1 else 0 end)       as releves_rupture,
    round(100.0 * sum(case when est_en_rupture then 1 else 0 end) / count(*), 2)
                                                          as taux_rupture_pct
from {{ ref('stg_station_status') }}
where est_installee
group by station_id, date_trunc('hour', snapshot_ts)