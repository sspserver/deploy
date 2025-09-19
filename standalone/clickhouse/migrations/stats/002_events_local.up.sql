
-- Money is Number * 1_000_000_000
CREATE TABLE IF NOT EXISTS stats.events_local (
   sign                     Int8        DEFAULT 1
 , timemark                 DateTime
 , datehourmark             DateTime    DEFAULT toStartOfHour(timemark)
 , datemark                 Date        DEFAULT toDate(timemark)
 , delay                    UInt64      DEFAULT 0       -- Delay of preparation of Ads in Nanosecinds (Load picture before display, etc)
 , duration                 UInt64      DEFAULT 0       -- Duration in Nanosecond
 , event                    LowCardinality(String)
 , status                   UInt8                       -- Status: 0 - undefined, 1 - success, 2 - failed, 3 - compromised, 4 - Custom, 5 – Failover
 -- source
 , auc_id                   FixedString(16)             -- Internal Auction ID
 , auc_type                 UInt8                       -- 1 - First Price, 2 - Second Price, 3 - Fixed Price, 0 - DEFAULT (Second Price)
 , imp_id                   FixedString(16)             -- Sub ID of request for paticular impression spot
 , impad_id                 FixedString(16)             -- Specific ID for paticular ad impression
 , extauc_id                String                      -- External Request/Response ID (RTB)
 , extimp_id                String                      -- External Imp ID (RTB)
 , source_id                UInt64                      -- Advertisement Source ID
 , network                  String                      -- Source Network Name or Domain (Cross sails)
 -- State Location
 , platform_type            UInt8                       -- Where displaid? 0 – undefined, 1 – web site, 2 – native app, 3 – game, 4 - Video Player
 , domain                   String                      -- If not web site then "bundle"
 , app_id                   UInt64                      -- application ID (registered in the system)
 , zone_id                  UInt64                      -- application Zone ID
 , format_id                UInt32                      -- Advertisement format ID
 , ad_w                     UInt32                      -- Area Width
 , ad_h                     UInt32                      -- Area Height
 , src_url                  String                      TTL timemark + INTERVAL 7 DAYS -- Advertisement source URL (iframe, image, video, direct)
 , win_url                  String                      TTL timemark + INTERVAL 7 DAYS -- Win URL used for RTB confirmation
 , url                      String                      TTL timemark + INTERVAL 7 DAYS -- Non modified target URL
 -- Money
 , pricing_model            UInt8                       -- Display As CPM/CPC/CPA/CPI
 , purchase_imp_price       UInt64                      -- Money paid to the source
 , purchase_imp_price_f64   Float64                     ALIAS toFloat64(purchase_imp_price) / 1000000000
 , purchase_view_price      UInt64                      -- Money paid to the source
 , purchase_view_price_f64  Float64                     ALIAS toFloat64(purchase_view_price) / 1000000000
 , purchase_click_price     UInt64
 , purchase_click_price_f64 Float64                     ALIAS toFloat64(purchase_click_price) / 1000000000
 , potential_imp_price      UInt64                      -- Additional price which can we have
 , potential_imp_price_f64  Float64                     ALIAS toFloat64(potential_imp_price) / 1000000000
 , potential_view_price     UInt64                      -- Additional price which can we have
 , potential_view_price_f64 Float64                     ALIAS toFloat64(potential_view_price) / 1000000000
 , potential_click_price    UInt64
 , potential_click_price_f64 Float64                    ALIAS toFloat64(potential_click_price) / 1000000000
 , imp_price                UInt64                      -- Price for impression only (for CPM)
 , imp_price_f64            Float64                     ALIAS toFloat64(imp_price) / 1000000000
 , view_price               UInt64                      -- Total price with all expencies per action
 , view_price_f64           Float64                     ALIAS toFloat64(view_price) / 1000000000
 , click_price              UInt64
 , click_price_f64          Float64                     ALIAS toFloat64(click_price) / 1000000000
 -- User IDENTITY
 , ud_id                    String                      -- Unique Device ID (IDFA)
 , uu_id                    FixedString(16)
 , sess_id                  FixedString(16)
 , fingerprint              String
 , etag                     String
 -- Targeting
 , carrier_id               UInt64                      -- Carrier ID
 , country                  FixedString(2)              -- Country Code
 , latitude                 Float64                     TTL timemark + INTERVAL 3 DAYS -- Geo latitude
 , longitude                Float64                     TTL timemark + INTERVAL 3 DAYS -- Geo longitude
 , language                 FixedString(5)              -- en-US
 , ip                       IPv6
 , ref                      String                      TTL timemark + INTERVAL 3 DAYS -- Referal link
 , page_url                 String                      TTL timemark + INTERVAL 3 DAYS -- Page link
 , ua                       String                      TTL timemark + INTERVAL 3 DAYS -- User Agent
 , device_id                UInt32                      -- Device ID
 , device_type              UInt32                      -- Device type 0 - Undefined, 1 - Desktop, etc.
 , os_id                    UInt32                      -- OS ID
 , browser_id               UInt32                      -- Browser ID
 , category_ids             Array(Int32)                -- Categories list
 , adblock                  UInt8
 , private                  UInt8                       -- Private Mode
 , robot                    UInt8                       -- Robot traffic
 , proxy                    UInt8                       -- Proxy traffic
 , backup                   UInt8                       -- Backup Display Type
 , x                        Int32                       -- X - coord of addisplay or click position
 , y                        Int32                       -- Y - coord of addisplay or click position
 , w                        Int32                       -- W - available space
 , h                        Int32                       -- H - available space

 , subid1                   String                      TTL timemark + INTERVAL 30 DAYS
 , subid2                   String                      TTL timemark + INTERVAL 30 DAYS
 , subid3                   String                      TTL timemark + INTERVAL 30 DAYS
 , subid4                   String                      TTL timemark + INTERVAL 30 DAYS
 , subid5                   String                      TTL timemark + INTERVAL 30 DAYS

 , created_at               DateTime    DEFAULT NOW()
)
ENGINE = ${RDB_PREFIX}CollapsingMergeTree(sign)
PARTITION BY toYYYYMM(datemark)
ORDER BY (event, datemark, platform_type, app_id, zone_id, format_id, auc_id, auc_type, impad_id)
SETTINGS index_granularity = 8192;
