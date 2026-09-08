import os
import psycopg2

REQUETES = [
    ("PROFIL DES STATIONS TOUJOURS EN RUPTURE", """
        select d.nom_station,
               d.capacite_theorique,
               min(s.velos_disponibles) as velos_min,
               max(s.velos_disponibles) as velos_max,
               min(s.places_libres)     as places_min,
               max(s.places_libres)     as places_max,
               bool_and(s.est_vide)     as toujours_vide,
               bool_and(s.est_pleine)   as toujours_pleine,
               count(*)                 as nb_releves
        from analytics.stg_station_status s
        join analytics.dim_station d using (station_id)
        where s.est_installee
        group by d.nom_station, d.capacite_theorique
        having bool_and(s.est_en_rupture)
        order by nb_releves desc
        limit 20
    """),
    ("COMBIEN DE STATIONS TOUJOURS EN RUPTURE AU TOTAL", """
        select count(*) as nb_stations
        from (
            select station_id
            from analytics.stg_station_status
            where est_installee
            group by station_id
            having bool_and(est_en_rupture)
        ) t
    """),
    ("DISTRIBUTION DE places_libres SUR TOUT LE JEU", """
        select case when places_libres = 0 then '0'
                    when places_libres between 1 and 3 then '1-3'
                    when places_libres between 4 and 10 then '4-10'
                    else '11 et +' end as tranche_places,
               count(*) as nb_releves,
               round(100.0 * count(*) / sum(count(*)) over (), 1) as part_pct
        from analytics.stg_station_status
        where est_installee
        group by 1
        order by 1
    """),
    ("CAPACITE THEORIQUE : VALEURS SUSPECTES", """
        select capacite_theorique, count(*) as nb_stations
        from analytics.dim_station
        group by capacite_theorique
        order by capacite_theorique
        limit 10
    """),
]

with psycopg2.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        for titre, sql in REQUETES:
            cur.execute(sql)
            colonnes = [c[0] for c in cur.description]
            print("\n=== " + titre + " ===")
            print(" | ".join(colonnes))
            for ligne in cur.fetchall():
                print(" | ".join(str(v) for v in ligne))