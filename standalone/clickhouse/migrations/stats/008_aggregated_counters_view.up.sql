CREATE MATERIALIZED VIEW IF NOT EXISTS stats.v_aggregated_counters_view TO stats.aggregated_counters_local
  AS SELECT
      timemark AS t
    -- Sources/Targets
    , source_id
    -- Targeting
    , platform_type
    , domain
    , app_id
    , zone_id
    , format_id
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
    , CASE
        WHEN pricing_model = 1 AND status = 1 AND event IN ('view', 'direct') THEN
          potential_view_price * sign
        WHEN pricing_model = 2 AND status IN (0, 1) AND event IN ('click') THEN
          potential_click_price * sign
        ELSE 0
      END AS potential_revenue
    , CASE
        WHEN pricing_model = 1 AND status = 2 AND event IN ('impression', 'direct') THEN
          view_price * sign
        WHEN pricing_model = 2 AND status = 2 AND event IN ('click') THEN
          click_price * sign
        ELSE 0
      END AS failed_revenue
    , CASE
        WHEN pricing_model = 1 AND status = 3 AND event IN ('impression', 'direct') THEN
          view_price * sign
        WHEN pricing_model = 2 AND status = 3 AND event IN ('click') THEN
          click_price * sign
        ELSE 0
      END AS compromised_revenue
    , CASE
        WHEN pricing_model = 1 AND status = 1 AND event IN ('view', 'direct') THEN
          view_price * sign
        WHEN pricing_model = 2 AND status IN (0, 1) AND event IN ('click') THEN
          click_price * sign
        ELSE 0
      END AS revenue

    -- Counters
    , CAST(IF(event = 'impression'               , sign, 0) AS UInt64) AS imps
    , CAST(IF(event = 'impression' AND status = 1, sign, 0) AS UInt64) AS success_imps
    , CAST(IF(event = 'impression' AND status = 2, sign, 0) AS UInt64) AS failed_imps
    , CAST(IF(event = 'impression' AND status = 3, sign, 0) AS UInt64) AS compromised_imps
    -- When display custom advertisement in case if no ads with required conditions
    , CAST(IF(event = 'impression' AND status = 4, sign, 0) AS UInt64) AS custom_imps
    , CAST(IF(event = 'impression' AND backup = 1, sign, 0) AS UInt64) AS backup_imps
    , CAST(IF(event = 'view'                     , sign, 0) AS UInt64) AS views
    , CAST(IF(event = 'view'       AND status = 1, sign, 0) AS UInt64) AS success_views
    , CAST(IF(event = 'view'       AND status = 2, sign, 0) AS UInt64) AS failed_views
    , CAST(IF(event = 'view'       AND status = 3, sign, 0) AS UInt64) AS compromised_views
    , CAST(IF(event = 'view'       AND status = 4, sign, 0) AS UInt64) AS custom_views
    , CAST(IF(event = 'view'       AND backup = 1, sign, 0) AS UInt64) AS backup_views
    , CAST(IF(event = 'direct'                   , sign, 0) AS UInt64) AS directs
    , CAST(IF(event = 'direct'     AND status = 1, sign, 0) AS UInt64) AS success_directs
    , CAST(IF(event = 'direct'     AND status = 2, sign, 0) AS UInt64) AS failed_directs
    , CAST(IF(event = 'direct'     AND status = 3, sign, 0) AS UInt64) AS compromised_directs
    , CAST(IF(event = 'direct'     AND status = 4, sign, 0) AS UInt64) AS custom_directs
    , CAST(IF(event = 'direct'     AND backup = 1, sign, 0) AS UInt64) AS backup_directs
    , CAST(IF(event = 'click'                    , sign, 0) AS UInt64) AS clicks
    , CAST(IF(event = 'click'      AND status = 1, sign, 0) AS UInt64) AS success_clicks
    , CAST(IF(event = 'click'      AND status = 2, sign, 0) AS UInt64) AS failed_clicks
    , CAST(IF(event = 'click'      AND status = 3, sign, 0) AS UInt64) AS compromised_clicks
    , CAST(IF(event = 'click'      AND status = 4, sign, 0) AS UInt64) AS custom_clicks
    , CAST(IF(event = 'click'      AND backup = 1, sign, 0) AS UInt64) AS backup_clicks

    , CAST(IF(event = 'src.bid'                  , sign, 0) AS UInt64) AS bid_requests
    , CAST(IF(event = 'src.win'                  , sign, 0) AS UInt64) AS bid_wins
    , CAST(IF(event = 'src.skip'                 , sign, 0) AS UInt64) AS bid_skips
    , CAST(IF(event = 'src.nobid'                , sign, 0) AS UInt64) AS bid_nobids
    , CAST(IF(event = 'src.fail'                 , sign, 0) AS UInt64) AS bid_errors

    , CAST(IF(adblock > 0, sign, 0) AS UInt64) AS adblocks
    , CAST(IF(private > 0, sign, 0) AS UInt64) AS privates
    , CAST(IF(robot   > 0, sign, 0) AS UInt64) AS robots
    , CAST(IF(backup  > 0, sign, 0) AS UInt64) AS backups
FROM stats.events_local;
