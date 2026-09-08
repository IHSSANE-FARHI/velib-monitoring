"""Collecteur GBFS Velib Metropole : un releve d etat toutes les 10 minutes.

Idempotent : l horodatage du releve vient du flux lui-meme (last_updated), pas de
l horloge locale. Combine a la cle primaire (snapshot_ts, station_id) et au
ON CONFLICT DO NOTHING, relancer le job ne cree aucun doublon.
"""

import os
import time
from datetime import datetime, timezone

import psycopg2
import requests
from psycopg2.extras import execute_values

BASE = "https://velib-metropole-opendata.smovengo.cloud/opendata/Velib_Metropole"
STATUS_URL = f"{BASE}/station_status.json"
INFO_URL = f"{BASE}/station_information.json"

DDL = """
CREATE TABLE IF NOT EXISTS raw_station_information (
    station_id    TEXT PRIMARY KEY,
    station_code  TEXT,
    name          TEXT,
    lat           DOUBLE PRECISION,
    lon           DOUBLE PRECISION,
    capacity      INTEGER,
    loaded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw_station_status (
    snapshot_ts         TIMESTAMPTZ NOT NULL,
    station_id          TEXT        NOT NULL,
    num_bikes_mecha     INTEGER,
    num_bikes_ebike     INTEGER,
    num_bikes_total     INTEGER,
    num_docks_available INTEGER,
    is_installed        SMALLINT,
    is_renting          SMALLINT,
    is_returning        SMALLINT,
    last_reported       TIMESTAMPTZ,
    PRIMARY KEY (snapshot_ts, station_id)
);

CREATE INDEX IF NOT EXISTS ix_status_station_ts
    ON raw_station_status (station_id, snapshot_ts);
"""


def fetch(url):
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    return r.json()


def to_utc(epoch):
    if epoch in (None, ""):
        return None
    return datetime.fromtimestamp(int(epoch), tz=timezone.utc)


def split_by_type(station):
    """Velib ventile les velos : [{mechanical: n}, {ebike: n}]."""
    types = station.get("num_bikes_available_types")
    if not isinstance(types, list):
        return None, None
    mecha = ebike = 0
    for item in types:
        if isinstance(item, dict):
            mecha += item.get("mechanical") or 0
            ebike += item.get("ebike") or 0
    return mecha, ebike


def main():
    dsn = os.environ["DATABASE_URL"]

    status = fetch(STATUS_URL)
    info = fetch(INFO_URL)

    snapshot_ts = to_utc(status.get("lastUpdatedOther") or status.get("last_updated"))
    if snapshot_ts is None:
        raise RuntimeError("Le flux ne fournit pas de last_updated exploitable")

    status_rows = []
    for s in status["data"]["stations"]:
        mecha, ebike = split_by_type(s)
        status_rows.append((
            snapshot_ts,
            str(s.get("station_id") or s.get("stationCode")),
            mecha,
            ebike,
            s.get("numBikesAvailable", s.get("num_bikes_available")),
            s.get("numDocksAvailable", s.get("num_docks_available")),
            s.get("is_installed"),
            s.get("is_renting"),
            s.get("is_returning"),
            to_utc(s.get("last_reported")),
        ))

    info_rows = [(
        str(s.get("station_id")),
        s.get("stationCode") or s.get("station_code"),
        s.get("name"),
        s.get("lat"),
        s.get("lon"),
        s.get("capacity"),
    ) for s in info["data"]["stations"]]

    with psycopg2.connect(dsn) as conn:
        with conn.cursor() as cur:
            cur.execute(DDL)

            execute_values(cur, """
                INSERT INTO raw_station_status (
                    snapshot_ts, station_id, num_bikes_mecha, num_bikes_ebike,
                    num_bikes_total, num_docks_available,
                    is_installed, is_renting, is_returning, last_reported)
                VALUES %s
                ON CONFLICT DO NOTHING
            """, status_rows, page_size=5000)
            cur.execute(
                "SELECT count(*) FROM raw_station_status WHERE snapshot_ts = %s",
                (snapshot_ts,))
            inserted = cur.fetchone()[0]

            execute_values(cur, """
                INSERT INTO raw_station_information (
                    station_id, station_code, name, lat, lon, capacity)
                VALUES %s
                ON CONFLICT (station_id) DO UPDATE SET
                    station_code = EXCLUDED.station_code,
                    name         = EXCLUDED.name,
                    lat          = EXCLUDED.lat,
                    lon          = EXCLUDED.lon,
                    capacity     = EXCLUDED.capacity,
                    loaded_at    = now()
            """, info_rows, page_size=5000)

        print(f"releve {snapshot_ts.isoformat()} | "
          f"{len(status_rows)} stations lues | {inserted} lignes en base pour ce releve")


def boucle():
    """Une exÃ©cution GitHub Actions couvre plusieurs heures de collecte.

    GitHub ne garantit pas les crons courts : un `*/10` produit en pratique
    un declenchement toutes les 2 a 4 heures. On demande donc peu de
    declenchements, et chacun collecte longtemps.
    """
    duree = int(os.environ.get("DUREE_MINUTES", "0"))
    intervalle = int(os.environ.get("INTERVALLE_SECONDES", "300"))
    fin = time.time() + duree * 60

    while True:
        try:
            main()
        except Exception as erreur:
            print(f"releve en echec, on reessaie au tour suivant : {erreur}")
        if time.time() + intervalle >= fin:
            break
        time.sleep(intervalle)


if __name__ == "__main__":
    boucle()