{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
module TimezoneUtil where

import Import
import RIO.Time
import Data.Time.LocalTime.TimeZone.Olson
import Data.Time.LocalTime.TimeZone.Series

type TimeZoneName = FilePath

-- | Gets timezone info from the default Unix location for tzdata
-- we assume /usr/share, but it could also be in /etc:
-- https://hackage.haskell.org/package/timezone-series-0.1.9/docs/Data-Time-LocalTime-TimeZone-Series.html#g:3
getTimeZoneSeries :: TimeZoneName -> IO TimeZoneSeries
getTimeZoneSeries tzName =
    getTimeZoneSeriesFromOlsonFile ("/usr/share/zoneinfo/" <> tzName)

-- | Converts a local time string to UTC, given a timezone
-- e.g.
-- *Main TimezoneUtil> localTimeStringToUTC "America/New_York" "2019-12-25 00:30:00"
-- 2019-12-25 05:30:00 UTC
-- *Main TimezoneUtil> localTimeStringToUTC "America/New_York" "2019-09-25 00:30:00"
-- 2019-09-25 04:30:00 UTC
-- *Main TimezoneUtil> localTimeStringToUTC "America/Tegucigalpa" "2019-09-25 00:30:00"
-- 2019-09-25 06:30:00 UTC
-- *Main TimezoneUtil> localTimeStringToUTC "America/Tegucigalpa" "2019-12-25 00:30:00"
-- 2019-12-25 06:30:00 UTC
localTimeStringToUTC :: TimeZoneName -> String -> IO UTCTime
localTimeStringToUTC tz localTimeStr = do
    series <- getTimeZoneSeries tz
    localTime <- parseTimeM True defaultTimeLocale "%Y-%-m-%-d %T" localTimeStr
    return $ localTimeToUTC' series localTime

toUTC :: TimeZoneName -> LocalTime -> IO UTCTime
toUTC tz localTime = do
    series <- getTimeZoneSeries tz
    return $ localTimeToUTC' series localTime
