// Q1: artistas de rock mais ouvidos (exemplo do enunciado)
MATCH (:User)-[l:LISTENED]->(s:Song)-[:HAS_GENRE]->(:Genre {name:'rock'}),
      (s)-[:PERFORMED_BY]->(a:Artist)
RETURN a.name AS artista, sum(l.plays) AS total_plays
ORDER BY total_plays DESC LIMIT 10;

// Q2: recomendar artistas para o usuário u001 com base em quem ouve as mesmas músicas
MATCH (me:User {id:'u001'})-[:LISTENED]->(:Song)<-[:LISTENED]-(outro:User)
WHERE outro <> me
WITH me, outro, count(*) AS em_comum
ORDER BY em_comum DESC LIMIT 30
MATCH (outro)-[:LISTENED]->(:Song)-[:PERFORMED_BY]->(a:Artist)
WHERE NOT (me)-[:FOLLOWS]->(a)
RETURN a.name AS recomendado, count(DISTINCT outro) AS afinidade
ORDER BY afinidade DESC LIMIT 10;

// Q3: filtragem colaborativa de músicas (via curtidas)
MATCH (me:User {id:'u001'})-[:LIKED]->(s:Song)<-[:LIKED]-(vizinho:User)
WITH me, vizinho, count(s) AS em_comum
ORDER BY em_comum DESC LIMIT 20
MATCH (vizinho)-[:LIKED]->(rec:Song)
WHERE NOT (me)-[:LISTENED]->(rec)
RETURN rec.name AS musica, count(DISTINCT vizinho) AS votos, rec.popularity AS popularidade
ORDER BY votos DESC, popularidade DESC LIMIT 10;

// Q4: músicas novas dentro dos 2 gêneros mais ouvidos do usuário
MATCH (me:User {id:'u001'})-[l:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
WITH me, g, sum(l.plays) AS peso ORDER BY peso DESC LIMIT 2
MATCH (g)<-[:HAS_GENRE]-(s:Song)
WHERE NOT (me)-[:LISTENED]->(s)
RETURN g.name AS genero, s.name AS musica, s.popularity AS popularidade
ORDER BY popularidade DESC LIMIT 10;

// Q5: gêneros preferidos do usuário u001 (top 3)
MATCH (:User {id:'u001'})-[l:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
RETURN g.name AS genero, sum(l.plays) AS plays
ORDER BY plays DESC LIMIT 3;

// Q6: caminho mais curto entre dois gêneros
MATCH p = shortestPath((:Genre {name:'rock'})-[*..8]-(:Genre {name:'jazz'}))
RETURN p;
