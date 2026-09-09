-- Taux de rupture par station et par heure.
--
-- On mesure une PROPORTION DE RELEVES, pas un nombre de minutes : la cadence
-- de collecte est irreguliere (55 % du nominal, mesure), donc une mesure en
-- minutes serait biaisee par les trous d echantillonnage.
--
-- Double perimetre :
--   stg_station_status.est_exploitee  -> drapeaux GBFS, releve par releve
--   dim_station.est_en_exploitation   -> stations jamais approvisionnees

select
    s.station_id,
    date_trunc('hour', s.snapshot_ts)                       as heure,
    count(*)                                                as nb_releves,
    count(distinct s.last_reported)                         as etats_publies,
    round(avg(s.velos_disponibles)::numeric, 2)             as velos_moyen,
    round(avg(s.places_libres)::numeric, 2)                 as places_moyen,
    sum(case when s.est_vide       then 1 else 0 end)       as releves_vide,
    sum(case when s.est_pleine     then 1 else 0 end)       as releves_pleine,
    sum(case when s.est_en_rupture then 1 else 0 end)       as releves_rupture,
    round(100.0 * sum(case when s.est_vide   then 1 else 0 end) / count(*), 2)
                                                            as taux_vide_pct,
    round(100.0 * sum(case when s.est_pleine then 1 else 0 end) / count(*), 2)
                                                            as taux_pleine_pct,
    round(100.0 * sum(case when s.est_en_rupture then 1 else 0 end) / count(*), 2)
                                                            as taux_rupture_pct
from {{ ref('stg_station_status') }} s
join {{ ref('dim_station') }} d using (station_id)
where s.est_exploitee
  and d.est_en_exploitation
group by s.station_id, date_trunc('hour', s.snapshot_ts)