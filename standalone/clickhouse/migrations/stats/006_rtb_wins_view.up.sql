CREATE MATERIALIZED VIEW IF NOT EXISTS stats.v_rtb_wins TO stats.rtb_wins
  AS SELECT
    toDate(datemark) AS datemark
  , delay
  , duration
  , auc_id
  , impad_id
  , source_id
  , network
  , win_url
  FROM stats.events_local
  WHERE event IN ('src.win');
