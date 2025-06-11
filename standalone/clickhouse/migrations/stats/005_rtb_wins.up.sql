CREATE TABLE IF NOT EXISTS stats.rtb_wins
( timemark                DateTime
, delay                   UInt64      default 0     -- Delay of preparation of Ads in Nanosecinds (Load picture before display, etc)
, duration                UInt64      default 0     -- Duration in Nanosecond
-- source
, auc_id                  FixedString(16)           -- Internal Auction ID
, impad_id                FixedString(16)           -- Specific ID for paticular ad impression
, source_id               UInt64                    -- Advertisement Source ID
, network                 String                    -- Source Network Name or Domain (Cross sails)
, win_url                 String                    -- Win URL used for RTB confirmation
)
ENGINE = ${RDB_PREFIX}MergeTree
PARTITION BY toYYYYMM(timemark)
ORDER BY (timemark, auc_id, source_id, network)
SETTINGS index_granularity = 8192;
