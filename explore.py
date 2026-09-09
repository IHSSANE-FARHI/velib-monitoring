"""Requetes d exploration sur les modeles analytics.

Usage : python explore.py
La periode analysee est reglee par DEBUT (collecte a cadence nominale).
"""
import os
import psycopg2
from psycopg2.extras import RealDictCursor

DEBUT = "2026-09-08 12:00+00"
conn = psycopg2.connect(os.environ["DATABASE_URL"], cursor_factory=RealDictCursor)

def q(titre, sql, params=None):
    print("\n" + "=" * 70)
    print(titre)
    print("=" * 70)
    with conn.cursor() as cur:
        cur.execute(sql, params or ())
        for r in cur.fetchall():
            print(dict(r))

q("Couverture reelle de la collecte", """
  select count(distinct snapshot_ts) as releves,
         min(snapshot_ts) as debut,
         max(snapshot_ts) as fin,
         round(extract(epoch from (max(snapshot_ts) - min(snapshot_ts))) / 300.0) as attendus
  from analytics.stg_station_status
  where snapshot_ts >= %s
""", (DEBUT,))

q("Surechantillonnage : releves contre etats publies par la source", """
  select count(*) as releves,
         count(distinct (station_id, last_reported)) as etats_publies,
         round(count(*)::numeric
               / nullif(count(distinct (station_id, last_reported)), 0), 2) as facteur
  from analytics.stg_station_status
  where snapshot_ts >= %s and est_exploitee
""", (DEBUT,))

q("Stations les plus souvent en rupture", """
  select d.nom_station,
         count(*) as heures,
         round(avg(f.taux_rupture_pct), 1) as rupture_pct,
         round(avg(f.taux_vide_pct), 1)    as vide_pct,
         round(avg(f.taux_pleine_pct), 1)  as pleine_pct
  from analytics.fct_station_heure f
  join analytics.dim_station d using (station_id)
  where f.heure >= %s
  group by d.nom_station
  having count(*) >= 10
  order by 3 desc
  limit 15
""", (DEBUT,))

q("Durees d episodes", """
  select type_rupture,
         count(*) as episodes,
         round(avg(duree_minutes), 1) as moyenne,
         round(percentile_cont(0.5) within group (order by duree_minutes)::numeric, 1) as mediane,
         max(duree_minutes) as maxi
  from analytics.fct_episode_rupture
  where debut >= %s
  group by type_rupture order by 1
""", (DEBUT,))

q("Profil horaire : stations vides contre stations pleines", """
  select extract(hour from f.heure) as h,
         count(distinct f.heure) as heures_observees,
         round(avg(f.taux_vide_pct), 2)   as vide_pct,
         round(avg(f.taux_pleine_pct), 2) as pleine_pct
  from analytics.fct_station_heure f
  where f.heure >= %s
  group by 1 order by 1
""", (DEBUT,))

conn.close()