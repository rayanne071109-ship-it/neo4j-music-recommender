import os
import kagglehub
import numpy as np
import pandas as pd

rng = np.random.default_rng(42)  # semente fixa = resultado reproduzível

# 1) Catálogo real do Kaggle
path = kagglehub.dataset_download("maharshipandya/-spotify-tracks-dataset")
df = pd.read_csv(os.path.join(path, "dataset.csv"))
df = df.drop_duplicates("track_id").dropna(subset=["artists", "track_name", "track_genre"])

GENRES = ["rock", "pop", "hip-hop", "jazz", "metal", "samba",
          "sertanejo", "electronic", "classical", "mpb"]

# Segurança: avisa se algum gênero não existir no dataset
existentes = set(df.track_genre.unique())
faltando = [g for g in GENRES if g not in existentes]
if faltando:
    print("ATENÇÃO, gêneros não encontrados:", faltando)
GENRES = [g for g in GENRES if g in existentes]

# Subconjunto leve: até 300 músicas por gênero
df = df[df.track_genre.isin(GENRES)]
df = df.sample(frac=1, random_state=42).groupby("track_genre").head(300)

songs = df[["track_id", "track_name", "popularity", "track_genre"]].rename(
    columns={"track_id": "id", "track_name": "name", "track_genre": "genre"})

# Uma música pode ter vários artistas separados por ";"
sa = df[["track_id", "artists"]].copy()
sa["artist"] = sa["artists"].str.split(";")
sa = sa.explode("artist")[["track_id", "artist"]]
sa["artist"] = sa["artist"].str.strip()
sa = sa.drop_duplicates()

artists = sa[["artist"]].drop_duplicates().rename(columns={"artist": "name"})

# 2) Usuários sintéticos
N_USERS = 300
users = pd.DataFrame({"id": [f"u{i:03d}" for i in range(N_USERS)]})
users["name"] = "Usuario " + users["id"].str[1:]

# Cada usuário tem 1 a 3 gêneros favoritos
fav = {u: rng.choice(GENRES, size=int(rng.integers(1, 4)), replace=False)
       for u in users.id}

# 3) Escutas: 70% das músicas vêm dos gêneros favoritos
by_genre = {g: songs[songs.genre == g].id.values for g in GENRES}
listened, liked = [], []
for u in users.id:
    n = int(rng.integers(30, 81))
    for _ in range(n):
        g = rng.choice(fav[u]) if rng.random() < 0.7 else rng.choice(GENRES)
        sid = rng.choice(by_genre[g])
        plays = int(rng.integers(1, 51))
        day = pd.Timestamp("2026-01-01") + pd.Timedelta(days=int(rng.integers(0, 300)))
        listened.append((u, sid, plays, day.date().isoformat()))
        if rng.random() < 0.3:
            liked.append((u, sid, day.date().isoformat()))

listened = pd.DataFrame(listened, columns=["user_id", "song_id", "plays", "last_played"]
                        ).drop_duplicates(["user_id", "song_id"])
liked = pd.DataFrame(liked, columns=["user_id", "song_id", "date"]
                     ).drop_duplicates(["user_id", "song_id"])

# 4) Follows: artistas das músicas muito ouvidas (>= 25 plays)
heavy = listened[listened.plays >= 25].merge(sa, left_on="song_id", right_on="track_id")
follows = heavy[["user_id", "artist", "last_played"]].drop_duplicates(["user_id", "artist"])
follows = follows.rename(columns={"last_played": "since"})

# 5) Salvar
out = "data/processed/"
songs.to_csv(out + "songs.csv", index=False)
artists.to_csv(out + "artists.csv", index=False)
sa.to_csv(out + "song_artist.csv", index=False)
users.to_csv(out + "users.csv", index=False)
listened.to_csv(out + "listened.csv", index=False)
liked.to_csv(out + "liked.csv", index=False)
follows.to_csv(out + "follows.csv", index=False)

print({k: len(v) for k, v in dict(songs=songs, artists=artists, users=users,
                                  listened=listened, liked=liked, follows=follows).items()})
