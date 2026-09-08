-- Taux de rupture par station et par heure.
--
-- On mesure une PROPORTION DE RELEVES, pas un nombre de minutes : la cadence
-- de collecte est irreguliere, donc une mesure en minutes serait biaisee.
--
-- Seules les stations reellement exploitees sont retenues (voir dim_station).

select
    s.station_id,
    date_trunc('hour', s.snapshot_ts)                       as heure,
    count(*)                                                as nb_releves,
    round(avg(s.velos_disponibles)::numeric, 2)             as velos_moyen,
    round(avg(s.places_libres)::numeric, 2)                 as places_moyen,
    sum(case when s.est_vide       then 1 else 0 end)       as releves_vide,
    sum(case when s.est_pleine     then 1 else 0 end)       as releves_pleine,
    sum(case when s.est_en_rupture then 1 else 0 end)       as releves_rupture,
    round(100.0 * sum(case when s.est_en_rupture then 1 else 0 end) / count(*), 2)
                                                            as taux_rupture_pct
from {{ ref('stg_station_status') }} s
join {{ ref('dim_station') }} d using (station_id)
where s.est_installee
  and d.est_en_exploitation
group by s.station_id, date_trunc('hour', s.snapshot_ts)