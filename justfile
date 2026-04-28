up:
  docker compose up -d

down:
  docker compose down

m:
  @echo "Migrating database..."
  @docker exec -it analysis_db psql -U ${DB_USER:-admin} -d ${DB_NAME:-analysis_db} -c "SELECT version();"

tables:
  @echo "Listing tables..."
  @docker exec -it analysis_db psql -U ${DB_USER:-admin} -d ${DB_NAME:-analysis_db} -c "\dt"

logs:
  @echo "Checking database logs..."
  @docker exec -it analysis_db psql -U ${DB_USER:-admin} -d ${DB_NAME:-analysis_db} -c "SELECT * FROM analyses LIMIT 5;"