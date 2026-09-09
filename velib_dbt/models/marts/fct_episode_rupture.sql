-- Episodes de rupture : series consecutives de releves ou la station est
-- vide ou pleine. Technique "gaps and islands".
--
-- 1. on marque le releve ou la rupture COMMENCE (en rupture, et pas avant)
-- 2. une somme cumulee de ces marqueurs numerote les episodes
-- 3. un GROUP BY donne debut, fin et duree
--
-- PIEGE TRAITE ICI : "consecutif" signifie "releve suivant", pas "5 minutes
-- plus tard". La collecte a des trous (55 % de couverture mesuree). Une
-- station en rupture avant ET apres un trou de 3 heures produisait UN episode
-- de 3 heures, alors qu elle a peut-etre ete reapprovisionnee entre les deux.
-- C est ce qui gonflait la moyenne (61 min) face a la mediane (18 min), et le
-- maximum a 1042 min.
--
-- Regle : un ecart de plus de SEUIL_MINUTES rompt la continuite et demarre un
-- nouvel episode. Meme regle pour la fin : on ne prolonge pas jusqu au releve
-- suivant s il est trop loin, on credite un intervalle nominal de 5 minutes.

{% set seuil_minutes = 15 %}

with base as (

    select
        s.station_id,
        s.snapshot_ts,
        s.est_en_rupture,
        case when s.est_vide then 'vide'
             when s.est_pleine then 'pleine' end as type_rupture,
        lag(s.snapshot_ts) over (
            partition by s.station_id order by s.snapshot_ts
        ) as releve_precedent,
        lag(s.est_en_rupture) over (
            partition by s.station_id order by s.snapshot_ts
        ) as rupture_precedente,
        lead(s.snapshot_ts) over (
            partition by s.station_id order by s.snapshot_ts
        ) as releve_suivant
    from {{ ref('stg_station_status') }} s
    join {{ ref('dim_station') }} d using (station_id)
    where s.est_exploitee
      and d.est_en_exploitation

),

marqueur as (

    select
        *,
        case
            when est_en_rupture
             and (coalesce(rupture_precedente, false) = false
               or releve_precedent is null
               or snapshot_ts - releve_precedent
                    > interval '{{ seuil_minutes }} minutes')
            then 1 else 0
        end as debut_episode,
        case
            when releve_suivant is null
              or releve_suivant - snapshot_ts
                   > interval '{{ seuil_minutes }} minutes'
            then snapshot_ts + interval '5 minutes'
            else releve_suivant
        end as fin_ligne
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
    min(type_rupture)   as type_rupture,
    min(snapshot_ts)    as debut,
    max(fin_ligne)      as fin_estimee,
    count(*)            as nb_releves,
    round(extract(epoch from (max(fin_ligne) - min(snapshot_ts)))::numeric / 60, 1)
                        as duree_minutes
from numerote
where est_en_rupture
group by station_id, no_episode