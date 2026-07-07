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
cpx31,eu,eur,2026-04-01,0.0336,20.99
cpx31,eu,eur,2026-06-15,0.0657,40.99
cx33,eu,eur,2026-04-01,0.0104,6.49
cx33,eu,eur,2026-06-15,0.0136,8.49
cpx31,usa,eur,2026-04-01,0.0400,24.99
cpx31,usa,eur,2026-06-15,0.0769,47.99
cx33,usa,eur,2026-04-01,0.0128,7.99
cx33,usa,eur,2026-06-15,0.0160,9.99
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
type,vcpu,ram_gb
cpx31,4,8
cx33,4,8
CSV
}

jun2026_untouched_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CPX31 Cloud Server",,,"1.0000",2026-06-01,2026-06-30,,"Months","bob1",,"€ 20.9900"
"P","CPX31 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","bob1",,"€ 20.9900"
CSV
}

jun2026_post_hike_only_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CPX31 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","bob1",,"€ 20.9900"
CSV
}

jun2026_two_box_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CPX31 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","c1",,"€ 20.9900"
"P","CX33 Cloud Server",,,"1.0000",2026-07-01,2026-07-31,,"Months","x1",,"€ 6.4900"
CSV
}

jun2026_scaleup_assets() {
  mkdir -p "$1/providers/hetzner"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/providers/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx33,eu,eur,2025-10-01,0.0080,4.99
cx33,eu,eur,2026-04-01,0.0104,6.49
cpx32,eu,eur,2025-10-01,0.0224,13.99
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
type,vcpu,ram_gb
cx33,4,8
cpx32,4,8
CSV
}

jun2026_scaleup_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CX33 Cloud Server",,,"1.0000",2026-05-01,2026-05-31,,"Months","b1",,"€ 4.9900"
"P","CPX32 Cloud Server",,,"1.0000",2026-06-01,2026-06-30,,"Months","b1",,"€ 13.9900"
CSV
}

jun2026_mixed_kind_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CPX31 Cloud Server",,,"240",2026-05-01,2026-05-31,,"Hours","m1",,"€ 8.06"
"P","CPX31 Cloud Server",,,"1.0000",2026-06-01,2026-06-30,,"Months","m1",,"€ 20.9900"
CSV
}

jun2026_reprice_assets() {
  mkdir -p "$1/providers/hetzner"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/providers/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx33,eu,eur,2025-10-01,0.0080,4.99
cx33,eu,eur,2026-04-01,0.0104,6.49
cx33,eu,eur,2026-06-15,0.0136,8.49
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
type,vcpu,ram_gb
cx33,4,8
CSV
}

jun2026_across_april_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CX33 Cloud Server",,,"1.0000",2026-03-01,2026-03-31,,"Months","g1",,"€ 4.9900"
"P","CX33 Cloud Server",,,"1.0000",2026-05-01,2026-05-31,,"Months","g1",,"€ 6.4900"
CSV
}

jun2026_resize_assets() {
  mkdir -p "$1/providers/hetzner"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/providers/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx22,eu,eur,2026-04-01,0.0060,3.79
cx33,eu,eur,2026-04-01,0.0104,6.49
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
type,vcpu,ram_gb
cx22,2,4
cx33,4,8
CSV
}

jun2026_resize_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CX22 Cloud Server",,,"1.0000",2026-05-01,2026-05-31,,"Months","b1",,"€ 3.7900"
"P","CX33 Cloud Server",,,"1.0000",2026-06-01,2026-06-30,,"Months","b1",,"€ 6.4900"
CSV
}

jun2026_solo_assets() {
  mkdir -p "$1/providers/hetzner"
  cp "$ROOT/schema.sql" "$ROOT/audit.sql" "$1/"
  cat > "$1/providers/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cpx31,eu,eur,2026-04-01,0.0336,20.99
cpx31,eu,eur,2026-06-15,0.0657,40.99
CSV
  cat > "$1/providers/hetzner/server_types.csv" <<CSV
type,vcpu,ram_gb
cpx31,4,8
CSV
}

jun2026_reacquired_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CPX31 Cloud Server",t1,,"240",2026-04-10,2026-04-20,,"Hours","t1",,"€ 8.06"
"P","CPX31 Cloud Server",t2,,"336",2026-06-16,2026-06-30,,"Hours","t2",,"€ 22.08"
CSV
}

jun2026_ephemeral_invoice() {
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"P","CPX31 Cloud Server",eph,,"336",2026-06-16,2026-06-30,,"Hours","eph",,"€ 22.08"
CSV
}
