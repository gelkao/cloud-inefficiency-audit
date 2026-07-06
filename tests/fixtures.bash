invoice_csv() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"Project test","CX32 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","box1",,"€ 6.3000"
CSV
}

fixture_assets() {
  mkdir -p "$1/providers/hetzner"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/providers/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx33,eu,eur,2025-10-01,0.0080,4.99
cx33,usa,eur,2025-10-01,0.0110,6.99
cax21,eu,eur,2025-10-01,0.0070,3.79
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
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

rounding_assets() {
  mkdir -p "$1/providers/hetzner"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/providers/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx33,eu,eur,2025-10-01,0.0160,10.00
cax21,eu,eur,2025-10-01,0.0090,6.125
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
type,vcpu,ram_gb
cx33,4,8
cax21,4,8
CSV
}

rounding_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CX33 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","b1",,"€ 10.0000"
CSV
}

two_project_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"Project prod","CX33 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","b1",,"€ 4.9900"
"Project dev","CX33 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","b2",,"€ 4.9900"
CSV
}

jun2026_assets() {
  mkdir -p "$1/providers/hetzner"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/providers/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx32,eu,eur,2026-04-01,0.0136,8.49
cx33,eu,eur,2026-04-01,0.0104,6.49
cx33,eu,eur,$2,0.0136,8.49
cpx32,eu,eur,2026-04-01,0.0224,13.99
cpx32,eu,eur,$2,0.0569,35.49
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
type,vcpu,ram_gb
cx32,4,8
cx33,4,8
cpx32,4,8
CSV
}

jun2026_untouched_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CX32 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","b1",,"€ 8.4900"
CSV
}

jun2026_locked_pair_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CX32 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","b_cx32",,"€ 8.4900"
"P","CX33 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","b_cx33",,"€ 6.4900"
CSV
}

jun2026_post_hike_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CPX32 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","b_cpx32",,"€ 35.4900"
CSV
}
