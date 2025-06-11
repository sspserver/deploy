CREATE TABLE IF NOT EXISTS stats.aggregated_counters_local (
  t                         DateTime                                            TTL t + INTERVAL 1 DAY
, time5min_mark             DateTime    DEFAULT toStartOfFiveMinutes(t)         TTL time5min_mark  + INTERVAL 3 DAYS
, time15min_mark            DateTime    DEFAULT toStartOfFifteenMinutes(t)      TTL time15min_mark + INTERVAL 10 DAYS
, timehour_mark             DateTime    DEFAULT toStartOfHour(t)                TTL timehour_mark  + INTERVAL 1 MONTH
, datemark                  Date        DEFAULT toDate(t)
, timemark                  DateTime    ALIAS GREATEST(t, time5min_mark, time15min_mark, timehour_mark, toDateTime(datemark))
-- source
, source_id                 UInt64                      -- Advertisement Source ID
-- Targeting
, platform_type             UInt8                       -- Where displaid? 0 – undefined, 1 – web site, 2 – native app, 3 – game, 4 - Targeting
, domain                    String                      -- If not web site then "bundle"
, app_id                    UInt64                      -- application ID (registered in the system)
, zone_id                   UInt64                      -- application Zone ID
, format_id                 UInt32                      -- Advertisement format ID
-- Wide targeting information
, carrier_id                UInt64                      -- Carrier ID
, country                   FixedString(2)              -- Country Code
, latitude                  Float64                     -- Geo latitude
, longitude                 Float64                     -- Geo longitude
, language                  FixedString(5)              -- en-US
, ip                        IPv6
, device_id                 UInt32                      -- Device ID
, device_type               UInt32                      -- Device type 0 - Undefined, 1 - Desktop, etc.
, os_id                     UInt32                      -- OS ID
, browser_id                UInt32                      -- Browser ID
-- Money with target on publisher (FOR SSP SERVICE revenue EQUALS TO source SPEND)
, pricing_model             UInt8                       -- Display As CPM/CPC/CPA/CPI
, potential_revenue         UInt64
, potential_revenue_f64     Float64                     ALIAS toFloat64(potential_revenue) / 1000000000
, failed_revenue            UInt64
, failed_revenue_f64        Float64                     ALIAS toFloat64(failed_revenue) / 1000000000
, compromised_revenue       UInt64
, compromised_revenue_f64   Float64                     ALIAS toFloat64(compromised_revenue) / 1000000000
, revenue                   UInt64
, revenue_f64               Float64                     ALIAS toFloat64(revenue) / 1000000000
-- Counters
, imps                      UInt64
, success_imps              UInt64
, failed_imps               UInt64
, compromised_imps          UInt64
, custom_imps               UInt64
, backup_imps               UInt64
, views                     UInt64
, failed_views              UInt64
, compromised_views         UInt64
, custom_views              UInt64
, backup_views              UInt64
, directs                   UInt64
, success_directs           UInt64
, failed_directs            UInt64
, compromised_directs       UInt64
, custom_directs            UInt64
, backup_directs            UInt64
, clicks                    UInt64
, failed_clicks             UInt64
, compromised_clicks        UInt64
, custom_clicks             UInt64
, backup_clicks             UInt64

, bid_requests             UInt64
, bid_wins                 UInt64
, bid_skips                UInt64
, bid_nobids               UInt64
, bid_errors               UInt64

, adblocks                 UInt64
, privates                 UInt64
, robots                   UInt64
, backups                  UInt64
) ENGINE = ${RDB_PREFIX}SummingMergeTree
PARTITION BY toYYYYMM(datemark)
PRIMARY KEY (datemark, source_id, platform_type, app_id, zone_id, format_id)
ORDER BY (
  datemark
-- source
, source_id
-- Targeting
, platform_type
, app_id
, zone_id
, format_id
, domain
-- Wide targeting information
, carrier_id
, country
, latitude
, longitude
, language
, ip
, device_id
, device_type
, os_id
, browser_id
-- Money
, pricing_model
)
SETTINGS index_granularity = 8192;
