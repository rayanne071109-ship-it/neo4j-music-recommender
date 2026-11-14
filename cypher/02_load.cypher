// 1) Usuários
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {id: row.id})
SET u.name = row.name;

// 2) Músicas e gêneros
LOAD CSV WITH HEADERS FROM 'file:///songs.csv' AS row
MERGE (s:Song {id: row.id})
SET s.name = row.name, s.popularity = toInteger(row.popularity)
MERGE (g:Genre {name: row.genre})
MERGE (s)-[:HAS_GENRE]->(g);

// 3) Artistas e autoria (música -> artista)
LOAD CSV WITH HEADERS FROM 'file:///song_artist.csv' AS row
MATCH (s:Song {id: row.track_id})
MERGE (a:Artist {name: row.artist})
MERGE (s)-[:PERFORMED_BY]->(a);

// 4) Escutas (relacionamento com propriedades)
LOAD CSV WITH HEADERS FROM 'file:///listened.csv' AS row
CALL {
  WITH row
  MATCH (u:User {id: row.user_id}), (s:Song {id: row.song_id})
  MERGE (u)-[r:LISTENED]->(s)
  SET r.plays = toInteger(row.plays), r.last_played = date(row.last_played)
} IN TRANSACTIONS OF 1000 ROWS;

// 5) Curtidas
LOAD CSV WITH HEADERS FROM 'file:///liked.csv' AS row
CALL {
  WITH row
  MATCH (u:User {id: row.user_id}), (s:Song {id: row.song_id})
  MERGE (u)-[r:LIKED]->(s)
  SET r.date = date(row.date)
} IN TRANSACTIONS OF 1000 ROWS;

// 6) Seguidores de artistas
LOAD CSV WITH HEADERS FROM 'file:///follows.csv' AS row
CALL {
  WITH row
  MATCH (u:User {id: row.user_id}), (a:Artist {name: row.artist})
  MERGE (u)-[r:FOLLOWS]->(a)
  SET r.since = date(row.since)
} IN TRANSACTIONS OF 1000 ROWS;
