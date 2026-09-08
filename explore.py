import os
import psycopg2

REQUETES = [
    ("STATIONS LES PLUS SOUVENT EN RUPTURE", """
        select d.nom_station,
               count(*) as heures_observees,
               round(avg(f.taux_rupture_pct), 1) as taux_moyen_pct
        from analytics.fct_station_heure f
        join analytics.dim_station d using (station_id)
        group by d.nom_station
        having count(*) >= 20
        order by taux_moyen_pct desc
        limit 15
    """),
    ("EPISODES PAR TYPE", """
        select type_rupture,
               count(*) as nb_episodes,
               round(avg(duree_minutes), 1) as duree_moyenne_min,
               max(duree_minutes) as duree_max_min
        from analytics.fct_episode_rupture
        group by type_rupture
    """),
    ("TAUX DE RUPTURE PAR HEURE DE LA JOURNEE", """
        select extract(hour from heure) as heure_du_jour,
               count(*) as observations,
               round(avg(taux_rupture_pct), 2) as taux_moyen_pct
        from analytics.fct_station_heure
        group by 1
        order by 1
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