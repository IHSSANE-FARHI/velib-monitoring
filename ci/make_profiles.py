"""Genere ~/.dbt/profiles.yml a partir du secret DATABASE_URL.

Le mot de passe ne doit jamais etre versionne : on reconstruit le profil
a l execution, depuis le meme secret que celui du collecteur.
"""

import os
import pathlib
from urllib.parse import urlparse

url = urlparse(os.environ["DATABASE_URL"])

profil = f"""velib_dbt:
  target: prod
  outputs:
    prod:
      type: postgres
      host: {url.hostname}
      port: {url.port or 5432}
      user: {url.username}
      pass: {url.password}
      dbname: {url.path.lstrip("/")}
      schema: analytics
      sslmode: require
      threads: 4
"""

dossier = pathlib.Path.home() / ".dbt"
dossier.mkdir(exist_ok=True)
(dossier / "profiles.yml").write_text(profil, encoding="utf-8")
print("profiles.yml genere pour l hote", url.hostname)