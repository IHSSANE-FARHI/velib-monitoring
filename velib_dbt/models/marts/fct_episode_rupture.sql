-- Episodes de rupture : series consecutives de releves ou la station est
-- vide ou pleine. Technique "gaps and islands".
--
-- 1. on marque le releve ou la rupture COMMENCE (en rupture, et pas avant)
-- 2. une somme cumulee de ces marqueurs numerote les episodes
-- 3. un GROUP BY donne debut, fin et duree
--
-- La fin est estimee par le releve SUIVANT : on ne sait pas a quelle minute
-- exacte la rupture a cesse, seulement qu elle avait cesse a ce moment-la.
--
-- Seules les stations reellement exploitees sont retenues (voir dim_station).

with base as (

    select
        s.station_id,
        s.snapshot_ts,
        s.est_en_rupture,
        case when s.est_vide then 'vide'
             when s.est_pleine then 'pleine' end as type_rupture,
        lead(s.snapshot_ts) over (
            partition by s.station_id order by s.snapshot_ts
        ) as releve_suivant
    from {{ ref('stg_station_status') }} s
    join {{ ref('dim_station') }} d using (station_id)
    where s.est_installee
      and d.est_en_exploitation

),

marqueur as (

    select
        *,
        case
            when est_en_rupture
             and coalesce(lag(est_en_rupture) over (
                   partition by station_id order by snapshot_ts), false) = false
            then 1 else 0
        end as debut_episode
    from base

),

numerote as (

    select
        *,
        sum(debut_episode) over (
            partition by station_id order by snapshot_ts
            rows between unbounded preceding and current row
        ) as no_episode
    from marqueur

)

select
    station_id,
    no_episode,
    min(type_rupture)                             as type_rupture,
    min(snapshot_ts)                              as debut,
    max(coalesce(releve_suivant, snapshot_ts))    as fin_estimee,
    count(*)                                      as nb_releves,
    round(extract(epoch from (
        max(coalesce(releve_suivant, snapshot_ts)) - min(snapshot_ts)
    ))::numeric / 60, 1)                          as duree_minutes
from numerote
where est_en_rupture
group by station_id, no_episode