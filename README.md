# 🎵 Sistema de Recomendação de Músicas com Neo4j

Projeto do Desafio de Projeto da DIO sobre banco de dados em grafos. Modela usuários, músicas, artistas e gêneros como um grafo no **Neo4j** e usa consultas **Cypher** para gerar recomendações personalizadas.

## 📌 Contexto do problema

Uma plataforma de streaming quer identificar padrões de escuta e sugerir novas faixas e artistas aos usuários. O sistema precisa:

- representar usuários, músicas, artistas e gêneros como **nós**;
- representar interações (ouvir, curtir, seguir) como **relacionamentos com propriedades**;
- gerar recomendações com **consultas Cypher** baseadas em conexões do grafo.

## 🕸️ Por que grafos?

- As relações são naturalmente **N:N**: um usuário ouve várias músicas, uma música tem vários ouvintes e pode ter mais de um artista (neste projeto há 4.316 relações `PERFORMED_BY` para 2.932 músicas).
- Recomendar é **percorrer caminhos**: "usuários que ouvem o que eu ouço → o que mais eles ouvem". Em SQL isso viraria vários JOINs encadeados; em Cypher é um único padrão de caminho.
- As interações carregam dados (`plays`, `last_played`, `since`), e o Neo4j guarda propriedades diretamente nos relacionamentos.

## 📦 Dataset

| Parte | Origem |
|---|---|
| Catálogo (músicas, artistas, gêneros) | [Spotify Tracks Dataset](https://www.kaggle.com/datasets/maharshipandya/-spotify-tracks-dataset) (Kaggle). Confira a licença na página do dataset. |
| Usuários e interações | **Sintéticos**, gerados por `scripts/01_prepare_data.py` com semente fixa (`seed 42`), então o resultado é reproduzível |

**Por que sintéticos?** O dataset do Kaggle não tem usuários. Para simular comportamento realista, cada usuário recebe de 1 a 3 gêneros favoritos, e 70% das suas escutas vêm desses gêneros. Isso cria "vizinhanças" de gosto que as recomendações conseguem explorar.

**Subconjunto usado:** 10 gêneros (rock, pop, hip-hop, jazz, metal, samba, sertanejo, electronic, classical, mpb), até 300 músicas por gênero.

| Entidade | Quantidade |
|---|---|
| User | 300 |
| Song | 2.932 |
| Artist | 1.712 |
| Genre | 10 |
| LISTENED | 15.666 |
| LIKED | 4.858 |
| FOLLOWS | 10.418 |
| HAS_GENRE | 2.932 |
| PERFORMED_BY | 4.316 |

## 🧩 Modelo do grafo

![Schema no Neo4j](modelo/Captura%20de%20tela%20em%202026-11-13%2021-15-26.png)

**Nós**

- `User {id, name}`
- `Song {id, name, popularity}`
- `Artist {name}`
- `Genre {name}`

**Relacionamentos**

- `(User)-[:LISTENED {plays, last_played}]->(Song)`
- `(User)-[:LIKED {date}]->(Song)`
- `(User)-[:FOLLOWS {since}]->(Artist)`
- `(Song)-[:PERFORMED_BY]->(Artist)`
- `(Song)-[:HAS_GENRE]->(Genre)`

## 🗂️ Estrutura do repositório

```
neo4j-music-recommender/
├── README.md
├── data/processed/      # CSVs gerados (amostra usada na carga)
├── scripts/
│   ├── 00_download.py   # teste de download do dataset
│   └── 01_prepare_data.py
├── cypher/
│   ├── 01_constraints.cypher
│   ├── 02_load.cypher
│   └── 03_queries.cypher
├── modelo/              # imagens do modelo
└── imagens/             # prints das queries
```

## ▶️ Como executar

**Ambiente usado:** Neo4j 2026.10.2 instalado via `apt` no Linux Mint, Python 3 com ambiente virtual.

```bash
# 1. Clonar e preparar o ambiente Python
git clone https://github.com/rayanne071109-ship-it/neo4j-music-recommender.git
cd neo4j-music-recommender
python3 -m venv .venv
source .venv/bin/activate
pip install kagglehub pandas numpy

# 2. Baixar o dataset e gerar os CSVs em data/processed/
python scripts/01_prepare_data.py

# 3. Iniciar o Neo4j e copiar os CSVs para a pasta de importação
sudo systemctl start neo4j
sudo cp data/processed/*.csv /var/lib/neo4j/import/
sudo chown neo4j:neo4j /var/lib/neo4j/import/*.csv

# 4. Criar constraints e carregar os dados
cypher-shell -u neo4j -p 'SUA_SENHA' -f cypher/01_constraints.cypher
cypher-shell -u neo4j -p 'SUA_SENHA' -f cypher/02_load.cypher
```

Depois, abra o Neo4j Browser em http://localhost:7474 e rode as consultas de `cypher/03_queries.cypher`, **uma por vez**.

> Em outras instalações, a pasta `import` pode ser diferente. Confira com `grep -i import /etc/neo4j/neo4j.conf`.

**Validação da carga**

```cypher
MATCH (n) RETURN labels(n) AS tipo, count(*) AS total;
MATCH ()-[r]->() RETURN type(r) AS relacao, count(*) AS total ORDER BY total DESC;
```


## 🔍 Perguntas de negócio e resultados

### Q1. Quais são os artistas de rock mais ouvidos?

```cypher
MATCH (:User)-[l:LISTENED]->(s:Song)-[:HAS_GENRE]->(:Genre {name:'rock'}),
      (s)-[:PERFORMED_BY]->(a:Artist)
RETURN a.name AS artista, sum(l.plays) AS total_plays
ORDER BY total_plays DESC LIMIT 10;
```

![Q1](imagens/Captura%20de%20tela%20em%202026-11-13%2021-19-24.png)

### Q2. Que artistas recomendar para um usuário, com base em quem ouve as mesmas músicas?

Busca os 30 usuários mais parecidos (mais músicas em comum) e sugere os artistas que eles ouvem e que o usuário ainda não segue.

```cypher
MATCH (me:User {id:'u001'})-[:LISTENED]->(:Song)<-[:LISTENED]-(outro:User)
WHERE outro <> me
WITH me, outro, count(*) AS em_comum
ORDER BY em_comum DESC LIMIT 30
MATCH (outro)-[:LISTENED]->(:Song)-[:PERFORMED_BY]->(a:Artist)
WHERE NOT (me)-[:FOLLOWS]->(a)
RETURN a.name AS recomendado, count(DISTINCT outro) AS afinidade
ORDER BY afinidade DESC LIMIT 10;
```

![Q2](imagens/Captura%20de%20tela%20em%202026-11-13%2021-19-57.png)

### Q3. Que músicas recomendar usando curtidas de usuários parecidos? (filtragem colaborativa)

```cypher
MATCH (me:User {id:'u001'})-[:LIKED]->(s:Song)<-[:LIKED]-(vizinho:User)
WITH me, vizinho, count(s) AS em_comum
ORDER BY em_comum DESC LIMIT 20
MATCH (vizinho)-[:LIKED]->(rec:Song)
WHERE NOT (me)-[:LISTENED]->(rec)
RETURN rec.name AS musica, count(DISTINCT vizinho) AS votos, rec.popularity AS popularidade
ORDER BY votos DESC, popularidade DESC LIMIT 10;
```


### Q4. Que músicas novas existem nos gêneros favoritos do usuário?

```cypher
MATCH (me:User {id:'u001'})-[l:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
WITH me, g, sum(l.plays) AS peso ORDER BY peso DESC LIMIT 2
MATCH (g)<-[:HAS_GENRE]-(s:Song)
WHERE NOT (me)-[:LISTENED]->(s)
RETURN g.name AS genero, s.name AS musica, s.popularity AS popularidade
ORDER BY popularidade DESC LIMIT 10;
```


### Q5. Quais são os gêneros preferidos de um usuário?

```cypher
MATCH (:User {id:'u001'})-[l:LISTENED]->(:Song)-[:HAS_GENRE]->(g:Genre)
RETURN g.name AS genero, sum(l.plays) AS plays
ORDER BY plays DESC LIMIT 3;
```


### Q6. Como dois gêneros se conectam no grafo?

```cypher
MATCH p = shortestPath((:Genre {name:'rock'})-[*..8]-(:Genre {name:'jazz'}))
RETURN p;
```


## 🩹 Troubleshooting (dificuldades e soluções)

| Problema | Causa | Solução |
|---|---|---|
| `Comando 'import' não encontrado` e `erro de sintaxe próximo ao token inesperado '('` | Código Python colado direto no terminal (bash) | Salvar o código em um arquivo `.py` e rodar com `python arquivo.py` |
| `NameError` ao listar arquivos do download | Faltava `import os` no script | Adicionar o `import os` |
| `Não foi possível obter a trava /var/lib/dpkg/lock-frontend` | Outro processo do apt já estava rodando | Esperar o processo terminar antes de repetir a instalação |
| `O dpkg foi interrompido` e `docker.service does not exist` | A instalação anterior foi interrompida e o pacote não chegou a ser instalado | `sudo dpkg --configure -a` seguido de `sudo apt --fix-broken install` |
| Docker não era indispensável | O repositório do Neo4j já estava configurado e o serviço instalado via apt | Seguir com o Neo4j nativo, copiando os CSVs para `/var/lib/neo4j/import` |
| Cursor piscando sem resposta | Comando do Linux digitado dentro do `cypher-shell` (prompt `neo4j@neo4j>`), que só aceita Cypher terminado em `;` | `Ctrl+C`, `:exit` e voltar ao terminal normal |
| Consulta de contagem retornava 0 linhas | A carga ainda não tinha sido executada | Rodar `01_constraints.cypher` e `02_load.cypher` e validar as contagens |
| Tipos errados após `LOAD CSV` | O `LOAD CSV` lê tudo como texto | Converter com `toInteger()` e `date()` |
| Carga lenta ou pesada | Muitas linhas em uma única transação | `CALL { ... } IN TRANSACTIONS OF 1000 ROWS` |
| Músicas com vários artistas | A coluna `artists` vem separada por `;` | `split` + `explode` no pandas e relacionamento N:N no grafo |

## 🚀 Próximos passos

- Usar o plugin **Graph Data Science** (Node Similarity, Louvain) para similaridade de usuários e detecção de comunidades.
- Comparar o desempenho das consultas com `PROFILE`.
- Substituir os usuários sintéticos por dados reais de escuta (por exemplo, Last.fm).
- Expor as recomendações em uma interface (Streamlit).

## 👩‍💻 Autora

**Rayanne da Silva Rosa Fernandes**
LinkedIn: [rayannerosacloud](https://www.linkedin.com/in/rayannerosacloud) · GitHub: [rayanne071109-ship-it](https://github.com/rayanne071109-ship-it)
