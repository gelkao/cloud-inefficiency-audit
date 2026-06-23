invoice_csv() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"Project test","CX32 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","box1",,"€ 6.3000"
CSV
}

fixture_assets() {
  mkdir -p "$1"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/hetzner_prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx33,eu,eur,2025-10-01,0.0080,4.99
cx33,usa,eur,2025-10-01,0.0110,6.99
cax21,eu,eur,2025-10-01,0.0070,3.79
CSV
  cat > "$1/server_types.csv" <<CSV
type,vcpu,ram_gb
cx33,4,8
cax21,4,8
CSV
}

cx33_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CX33 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","b1",,"€ 4.9900"
CSV
}

two_project_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"Project prod","CX33 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","b1",,"€ 4.9900"
"Project dev","CX33 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","b2",,"€ 4.9900"
CSV
}
