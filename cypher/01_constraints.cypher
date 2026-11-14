// Garante unicidade e cria índices automaticamente
CREATE CONSTRAINT user_id IF NOT EXISTS FOR (u:User) REQUIRE u.id IS UNIQUE;
CREATE CONSTRAINT song_id IF NOT EXISTS FOR (s:Song) REQUIRE s.id IS UNIQUE;
CREATE CONSTRAINT artist_name IF NOT EXISTS FOR (a:Artist) REQUIRE a.name IS UNIQUE;
CREATE CONSTRAINT genre_name IF NOT EXISTS FOR (g:Genre) REQUIRE g.name IS UNIQUE;
