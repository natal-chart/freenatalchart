{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Views.Chart (render, renderTestChartPage) where

import Chart.Calculations (findAscendant, findAspectBetweenPlanets, findAspectWithAngle, findSunSign, horoscope, housePosition, isRetrograde, splitDegrees, splitDegreesZodiac)
import Chart.Graphics (renderChart)
import Data.Time.LocalTime.TimeZone.Detect (withTimeZoneDatabase)
import qualified Graphics.Svg as Svg
import Import hiding (for_)
import Lucid
import RIO.Text (pack)
import RIO.Time (LocalTime, defaultTimeLocale, formatTime, parseTimeM)
import SwissEphemeris (LongitudeComponents (..), Planet (..))
import Views.Common
import Text.Printf (printf)

render :: BirthData -> HoroscopeData -> Html ()
render BirthData {..} h@HoroscopeData {..} = html_ $ do
  head_ $ do
    title_ "Your Natal Chart"
    metaCeremony

  body_ $ do
    div_ [id_ "main", class_ "container"] $ do
      -- TODO: add a navbar/header?
      div_ [class_ "p-centered"] $ do
        details_ [id_ "chart", class_ "accordion my-2", open_ ""] $ do
          summary_ [class_ "accordion-header bg-primary"] $ do
            headerIcon
            sectionHeading "Your Natal Chart"
          div_ [class_ "accordion-body"] $ do
            div_ [class_ "my-2"] $ do
              toHtmlRaw $ Svg.renderBS $ renderChart 600 h

        details_ [id_ "at-a-glance", class_ "accordion my-2", open_ ""] $ do
          summary_ [class_ "accordion-header bg-secondary"] $ do
            headerIcon
            sectionHeading "At a Glance"
          div_ [class_ "accordion-body"] $ do
            dl_ [] $ do
              dt_ [] "Place of Birth:"
              dd_ [] $ do
                toHtml $ birthLocation & locationInput
                latLngHtml birthLocation
              -- TODO: include timezone, julian time, delta time n' stuff?
              dt_ [] "Local Time of Birth:"
              dd_ [] (toHtml $ birthLocalTime & formatTime defaultTimeLocale "%Y-%m-%d %l:%M:%S %P")
              dt_ [] "Universal Time:"
              dd_ [] (toHtml $ horoscopeUniversalTime & formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S %Z")
              dt_ [] "Sun Sign:"
              dd_ [] (maybe mempty (toHtml . toText) (findSunSign horoscopePlanetPositions))
              dt_ [] "Ascendant:"
              dd_ [] (maybe mempty (toHtml . toText) (findAscendant horoscopeHouses))

        details_ [id_ "planet-positions", class_ "accordion my-2", open_ ""] $ do
          summary_ [class_ "accordion-header bg-secondary"] $ do
            headerIcon
            sectionHeading $ do
              "Planet Positions"

          div_ [class_ "accordion-body"] $ do
            table_ [class_ "table table-striped table-hover"] $ do
              thead_ [] $ do
                tr_ [] $ do
                  th_ [] "Planet"
                  th_ [] "House"
                  th_ [] "Longitude"
                  th_ [] "Latitude"
                  th_ [] "Speed"
                  th_ [] "Declination"
              tbody_ [] $ do
                forM_ (horoscopePlanetPositions) $ \pp@PlanetPosition {..} -> do
                  tr_ [] $ do
                    td_ $ do
                      asIcon planetName
                      planetLabel planetName
                      if isRetrograde pp then "(r)" else ""

                    td_ $ do
                      housePositionHtml $ housePosition horoscopeHouses planetLng

                    td_ $ do
                      htmlDegreesZodiac planetLng

                    td_ $ do
                      htmlDegreesLatitude planetLat

                    td_ $ do
                      htmlDegrees planetLngSpeed

                    td_ $ do
                      htmlDegreesLatitude $ Latitude planetDeclination

        details_ [id_ "house-cusps", class_ "accordion my-2", open_ ""] $ do
          summary_ [class_ "accordion-header bg-secondary"] $ do
            headerIcon
            sectionHeading "House Cusps"
          div_ [class_ "accordion-body"] $ do
            p_ $ do
              span_ [] "System Used: "
              mark_ $ toHtml $ toText horoscopeSystem
            table_ [class_ "table table-striped table-hover"] $ do
              thead_ [] $ do
                tr_ [] $ do
                  th_ [] "House"
                  th_ [] "Cusp"
                  th_ [] "Declination"
              tbody_ [] $ do
                forM_ (horoscopeHouses) $ \hc@House {..} -> do
                  tr_ [] $ do
                    td_ $ do
                      housePositionHtml (Just hc)
                      houseLabel houseNumber
                    td_ $ do
                      htmlDegreesZodiac houseCusp
                    td_ $ do
                      htmlDegreesLatitude $ Latitude houseDeclination

        details_ [id_ "aspects-summary", class_ "accordion my-2", open_ ""] $ do
          summary_ [class_ "accordion-header bg-secondary"] $ do
            headerIcon
            sectionHeading "Aspects Summary"
          div_ [class_ "accordion-body"] $ do
            table_ [class_ "table table-scroll table-hover"] $ do
              forM_ defaultPlanets $ \rowPlanet -> do
                tr_ [] $ do
                  td_ [] $ do
                    if rowPlanet == Sun
                      then mempty
                      else asIcon rowPlanet
                  forM_ (takeWhile (not . (== rowPlanet) . planetName) horoscopePlanetPositions) $ \PlanetPosition {..} -> do
                    td_ [style_ "border: 1px solid", class_ "text-small"] $ do
                      aspectCell $ findAspectBetweenPlanets horoscopePlanetaryAspects rowPlanet planetName
                  td_ [style_ "border-bottom: 1px solid"] $ do
                    asIcon rowPlanet
              tr_ [] $ do
                td_ [] "AC"
                forM_ (horoscopePlanetPositions) $ \PlanetPosition {..} -> do
                  td_ [style_ "border: 1px solid", class_ "text-small"] $ do
                    aspectCell $ findAspectWithAngle horoscopeAngleAspects planetName I
              tr_ [] $ do
                td_ [] "MC"
                forM_ (horoscopePlanetPositions) $ \PlanetPosition {..} -> do
                  td_ [style_ "border: 1px solid", class_ "text-small"] $ do
                    aspectCell $ findAspectWithAngle horoscopeAngleAspects planetName X

        details_ [id_ "orbs-used", class_ "accordion my-2"] $ do
          summary_ [class_ "accordion-header bg-gray"] $ do
            headerIcon
            sectionHeading "Orbs used"
          div_ [class_ "accordion-body"] $ do
            table_ [class_ "table table-striped table-hover"] $ do
              thead_ [] $ do
                tr_ [] $ do
                  th_ "Aspect"
                  th_ "Angle"
                  th_ "Orb"
              tbody_ [] $ do
                forM_ (majorAspects <> minorAspects) $ \Aspect {..} -> do
                  tr_ [] $ do
                    td_ $ do
                      asIcon aspectName
                      " "
                      toHtml $ toText aspectName
                    td_ $ do
                      toHtml $ toText angle
                    td_ $ do
                      toHtml $ toText maxOrb

    -- the SVG font for all icons.
    -- TODO: path is wrong for server-rendered!
    link_ [rel_ "stylesheet", href_ "static/css/freenatalchart-icons.css"]
    link_ [rel_ "stylesheet", href_ "https://unpkg.com/spectre.css/dist/spectre-icons.min.css"]
    footer_ [class_ "navbar bg-secondary"] $ do
      section_ [class_ "navbar-section"] $ do
        a_ [href_ "/about", class_ "btn btn-link", title_ "tl;dr: we won't sell you anything, or store your data."] "About"
      section_ [class_ "navbar-center"] $ do
        -- TODO: add a lil' icon?
        span_ "Brought to you by a ♑"
      section_ [class_ "navbar-section"] $ do
        a_ [href_ "https://github.com/lfborjas/freenatalchart.xyz", title_ "Made in Haskell with love and a bit of insanity.", class_ "btn btn-link"] "Source Code"
  where
    -- markup helpers
    headerIcon = i_ [class_ "icon icon-arrow-right mr-1"] ""
    sectionHeading = h3_ [class_ "d-inline"]
    -- some data helpers
    splitPlanets :: [LongitudeComponents]
    splitPlanets = map (splitDegreesZodiac . getLongitudeRaw) horoscopePlanetPositions
    splitHouses :: [LongitudeComponents]
    splitHouses = map (splitDegreesZodiac . getLongitudeRaw) horoscopeHouses

-- TODO: where to catch the `MeanApog` to `Lilith` transformation?
asIcon :: Show a => a -> Html ()
asIcon z =
  i_ [class_ ("fnc-" <> shown <> " tooltip"), title_ shown, data_ "tooltip" shown] ""
  where
    shown = toText z

htmlDegreesZodiac :: HasLongitude a => a -> Html ()
htmlDegreesZodiac p =
  abbr_ [title_ (pack . show $ pl)] $ do
    maybe mempty asIcon (split & longitudeZodiacSign)
    toHtml $ (" " <> (toText $ longitudeDegrees split)) <> "° "
    toHtml $ (toText $ longitudeMinutes split) <> "\' "
    toHtml $ (formattedSeconds split) <> "\""
  where
    pl = getLongitudeRaw p
    split = splitDegreesZodiac pl

htmlDegreesLatitude :: Latitude -> Html ()
htmlDegreesLatitude l =
  abbr_ [title_ (pack . show $ l)] $ do
    toHtml $ (toText $ longitudeDegrees split) <> "° "
    toHtml $ (toText $ longitudeMinutes split) <> "\' "
    toHtml $ (formattedSeconds split) <> "\" "
    toHtml direction
  where
    split = splitDegrees $ unLatitude l
    direction :: Text
    direction = if (unLatitude l) < 0 then "S" else "N"

htmlDegrees :: Double -> Html ()
htmlDegrees l =
  abbr_ [title_ (pack . show $ l)] $ do
    toHtml sign
    toHtml $ (toText $ longitudeDegrees split) <> "° "
    toHtml $ (toText $ longitudeMinutes split) <> "\' "
    toHtml $ (formattedSeconds split) <> "\""
  where
    split = splitDegrees l
    sign :: Text
    sign = if l < 0 then "-" else ""

formattedSeconds :: LongitudeComponents -> Text
formattedSeconds LongitudeComponents {..} =
  pack $ printf "%.2f" seconds
  where
    seconds = (fromIntegral longitudeSeconds) + longitudeSecondsFraction

housePositionHtml :: Maybe House -> Html ()
housePositionHtml Nothing = mempty
housePositionHtml (Just House {..}) =
  toHtml . toText . (+ 1) . fromEnum $ houseNumber

planetLabel :: Planet -> Html ()
planetLabel MeanNode = toHtml (" Mean Node" :: Text)
planetLabel MeanApog = toHtml (" Lilith" :: Text)
planetLabel p = toHtml . (" " <>) . toText $ p

houseLabel :: HouseNumber -> Html ()
houseLabel I = toHtml (" (Asc)" :: Text)
houseLabel IV = toHtml (" (IC)" :: Text)
houseLabel VII = toHtml (" (Desc)" :: Text)
houseLabel X = toHtml (" (MC)" :: Text)
houseLabel _ = mempty

aspectCell :: Maybe (HoroscopeAspect a b) -> Html ()
aspectCell Nothing = mempty
aspectCell (Just HoroscopeAspect {..}) =
  span_ [style_ ("color: " <> (aspectColor . temperament $ aspect))] $ do
    asIcon . aspectName $ aspect
    " "
    htmlDegrees orb

aspectColor :: AspectTemperament -> Text
aspectColor Analytical = "red"
aspectColor Synthetic = "blue"
aspectColor Neutral = "green"

latLngHtml :: Location -> Html ()
latLngHtml Location {..} =
  toHtml $ " (" <> lnText <> ", " <> ltText <> ")"
  where
    lnSplit = splitDegrees . unLongitude $ locationLongitude
    lnText = pack $ (show $ longitudeDegrees lnSplit) <> (if locationLongitude > 0 then "e" else "w") <> (show $ longitudeMinutes lnSplit)
    ltSplit = splitDegrees . unLatitude $ locationLatitude
    ltText = pack $ (show $ longitudeDegrees ltSplit) <> (if locationLatitude > 0 then "n" else "s") <> (show $ longitudeMinutes ltSplit)

toText :: Show a => a -> Text
toText = pack . show

renderTestChartPage :: IO ()
renderTestChartPage = do
  ephe <- pure $ "./config"
  withTimeZoneDatabase "./config/timezone21.bin" $ \db -> do
    birthplace <- pure $ Location "Tegucigalpa" (Latitude 14.0839053) (Longitude $ -87.2750137)
    birthtime <- parseTimeM True defaultTimeLocale "%Y-%-m-%-d %T" "1989-01-06 00:30:00" :: IO LocalTime
    let birthdata = BirthData birthplace birthtime
    calculations <- horoscope db ephe birthdata
    renderToFile "test-chart.html" $ render birthdata calculations
