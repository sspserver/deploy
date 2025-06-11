CREATE TABLE IF NOT EXISTS stats.source_state_local (
   datemark           Date
 , id                 UInt64      DEFAULT 0

 , spent              Int64       DEFAULT 0
 , spent_f64          Float64     ALIAS toFloat64(spent) / 1000000000
 , profit             Int64       DEFAULT 0
 , profit_f64         Float64     ALIAS toFloat64(profit) / 1000000000
 , bid_price          Int64       DEFAULT 0 -- Sum of all bid prices on the auction
 , bid_price_f64      Float64     ALIAS toFloat64(bid_price) / 1000000000
 , potential          Int64       DEFAULT 0 -- Sum of all potential prices on the auction
 , potential_f64      Float64     ALIAS toFloat64(potential) / 1000000000

 , imps               UInt64      DEFAULT 0
 , views              UInt64      DEFAULT 0
 , directs            UInt64      DEFAULT 0
 , clicks             UInt64      DEFAULT 0
 , bids               UInt64      DEFAULT 0
 , wins               UInt64      DEFAULT 0
 , skips              UInt64      DEFAULT 0
 , nobids             UInt64      DEFAULT 0
 , errors             UInt64      DEFAULT 0
)
Engine = ${RDB_PREFIX}SummingMergeTree
PARTITION BY toYYYYMM(datemark)
PRIMARY KEY (id, intHash32(id), datemark)
ORDER BY (id, intHash32(id), datemark)
SAMPLE BY intHash32(id);
