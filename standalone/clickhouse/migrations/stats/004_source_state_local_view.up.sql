CREATE MATERIALIZED VIEW IF NOT EXISTS stats.v_source_state_local TO stats.source_state_local
  AS SELECT
    toDate(datemark) AS datemark
  , source_id AS id
  , SUM(CASE
      WHEN pricing_model = 1 AND status = 1 AND event IN ('impression', 'direct') THEN
        purchase_view_price
      ELSE 0
    END) AS spent
  , SUM(CASE
      WHEN pricing_model = 1 AND status = 1 AND event IN ('impression', 'direct') THEN 
        view_price
      WHEN pricing_model = 2 AND status IN (0, 1) AND event IN ('click') THEN
        click_price
      ELSE 0
    END) AS profit
  , SUM(CASE
      WHEN pricing_model = 1 AND status = 1 AND event = 'ap.bid' THEN
        purchase_view_price
      ELSE 0
    END) AS bid_price
  , SUM(CAST(CASE WHEN event = 'impression' AND status IN (0, 1) THEN sign ELSE 0 END AS UInt64)) AS imps
  , SUM(CAST(CASE WHEN event = 'view'       AND status IN (0, 1) THEN sign ELSE 0 END AS UInt64)) AS views
  , SUM(CAST(CASE WHEN event = 'direct'     AND status IN (0, 1) THEN sign ELSE 0 END AS UInt64)) AS directs
  , SUM(CAST(CASE WHEN event = 'click'      AND status IN (0, 1) THEN sign ELSE 0 END AS UInt64)) AS clicks
  , SUM(CAST(CASE WHEN event = 'src.win'                         THEN sign ELSE 0 END AS UInt64)) AS wins
  , SUM(CAST(CASE WHEN event = 'src.bid'                         THEN sign ELSE 0 END AS UInt64)) AS bids
  , SUM(CAST(CASE WHEN event = 'src.skip'   AND status IN (0, 1) THEN sign ELSE 0 END AS UInt64)) AS skips
  , SUM(CAST(CASE WHEN event = 'src.nobid'  AND status IN (0, 1) THEN sign ELSE 0 END AS UInt64)) AS nobids
  , SUM(CAST(CASE WHEN event = 'src.fail'                        THEN sign ELSE 0 END AS UInt64)) AS errors
  FROM stats.events_local
  GROUP BY datemark, id;
