{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Defines the endpoints listed in the
-- <http://developer.oanda.com/rest-live/rates/ Rates> section of the API.

module OANDA.Rates
       ( InstrumentsArgs (..)
       , instrumentsArgs
       , Instrument (..)
       , instruments
       , Price (..)
       , prices
       , MidpointCandlestick (..)
       , midpointCandles
       , BidAskCandlestick (..)
       , bidaskCandles
       , CandlesArgs (..)
       , candlesArgs
       , CandlesCount (..)
       , DayOfWeek (..)
       , Granularity (..)
       , granularityToDiffTime
       ) where

import           Data.Aeson
import           Data.Char (toLower)
import           Data.Decimal
import           Data.Text (Text, pack)
import           Data.Thyme
import           Data.Thyme.Format.Aeson ()
import qualified Data.Vector as V
import           GHC.Generics (Generic)
import           Network.Wreq (Options)

import           OANDA.Util
import           OANDA.Types


data InstrumentsArgs = InstrumentsArgs
  { instrumentsFields      :: [Text]
  , instrumentsInstruments :: [Text]
  } deriving (Show)

instrumentsArgs :: InstrumentsArgs
instrumentsArgs = InstrumentsArgs ["displayName", "pip", "maxTradeUnits"] []

data Instrument = Instrument
  { instrumentInstrument      :: String
  , instrumentPip             :: Maybe Decimal
  , instrumentMaxTradeUnits   :: Maybe Integer
  , instrumentDisplayName     :: Maybe String
  , instrumentPrecision       :: Maybe Decimal
  , instrumentMaxTrailingStop :: Maybe Decimal
  , instrumentMinTrailingStop :: Maybe Decimal
  , instrumentMarginRate      :: Maybe Decimal
  , instrumentHalted          :: Maybe Bool
  , instrumentInterestRate    :: Maybe Object
  } deriving (Show, Generic)

instance FromJSON Instrument where
  parseJSON = genericParseJSON $ jsonOpts "instrument"

-- | Retrieve a list of instruments from OANDA
instruments :: OandaEnv -> AccountID -> InstrumentsArgs -> IO (V.Vector Instrument)
instruments od (AccountID aid) (InstrumentsArgs fs is) = do
  let url = baseURL od ++ "/v1/instruments"
      opts = constructOpts od [ ("accountId", [pack $ show aid])
                              , ("instruments", is)
                              , ("fields", fs)
                              ]
  jsonResponseArray url opts "instruments"


-- | Retrieve the current prices for a list of instruments.
prices :: OandaEnv -> [InstrumentText] -> Maybe ZonedTime -> IO (V.Vector Price)
prices od is zt =
  do let url = baseURL od ++ "/v1/prices"
         ztOpt = maybe [] (\zt' -> [("since", [pack $ formatTimeRFC3339 zt'])]) zt
         opts = constructOpts od $ ("instruments", is) : ztOpt

     jsonResponseArray url opts "prices"

data Price = Price
  { priceInstrument :: InstrumentText
  , priceTime       :: ZonedTime
  , priceBid        :: Decimal
  , priceAsk        :: Decimal
  } deriving (Show, Generic)

instance FromJSON Price where
  parseJSON = genericParseJSON $ jsonOpts "price"


-- | Retrieve the price history of a single instrument in midpoint candles
midpointCandles :: OandaEnv -> InstrumentText -> CandlesArgs ->
                   IO (V.Vector MidpointCandlestick)
midpointCandles od i args =
  do let (url, opts) = candleOpts od i args "midpoint"
     response <- jsonResponse url opts :: IO MidpointCandlesResponse
     return $ _midcandlesResponseCandles response

-- | Retrieve the price history of a single instrument in bid/ask candles
bidaskCandles :: OandaEnv -> InstrumentText -> CandlesArgs ->
                 IO (V.Vector BidAskCandlestick)
bidaskCandles od i args =
  do let (url, opts) = candleOpts od i args "bidask"
     response <- jsonResponse url opts :: IO BidAskCandlesResponse
     return $ _bidaskResponseCandles response


-- | Utility function for both candle history functions
candleOpts :: OandaEnv -> InstrumentText -> CandlesArgs -> String -> (String, Options)
candleOpts od i (CandlesArgs c g di atz wa) fmt = (url, opts)
  where url   = baseURL od ++ "/v1/candles"
        opts  = constructOpts od $ [ ("instrument", [i])
                                   , ("granularity", [pack $ show g])
                                   , ("candleFormat", [pack fmt])
                                   , ("dailyAlignment", [pack $ show di])
                                   , ("alignmentTimeZone", [pack atz])
                                   , ("weeklyAlignment", [pack $ show wa])
                                   ] ++ countOpts c
        countOpts (Count c') = [("count", [pack $ show c'])]
        countOpts (StartEnd st ed incf) = [ ("start", [pack $ formatTimeRFC3339 st])
                                          , ("end", [pack $ formatTimeRFC3339 ed])
                                          , ("includeFirst", [pack $ map toLower (show incf)])
                                          ]
        countOpts (StartCount st c' incf) = [ ("start", [pack $ formatTimeRFC3339 st])
                                            , ("count", [pack $ show c'])
                                            , ("includeFirst", [pack $ map toLower (show incf)])
                                            ]
        countOpts (EndCount ed c') = [ ("end", [pack $ formatTimeRFC3339 ed])
                                     , ("count", [pack $ show c'])
                                     ]

data MidpointCandlestick = MidpointCandlestick
  { midpointCandlestickTime     :: ZonedTime
  , midpointCandlestickOpenMid  :: Decimal
  , midpointCandlestickHighMid  :: Decimal
  , midpointCandlestickLowMid   :: Decimal
  , midpointCandlestickCloseMid :: Decimal
  , midpointCandlestickVolume   :: Int
  , midpointCandlestickComplete :: Bool
  } deriving (Show, Generic)

instance FromJSON MidpointCandlestick where
  parseJSON = genericParseJSON $ jsonOpts "midpointCandlestick"


data BidAskCandlestick = BidAskCandlestick
  { bidaskCandlestickTime     :: ZonedTime
  , bidaskCandlestickOpenBid  :: Decimal
  , bidaskCandlestickOpenAsk  :: Decimal
  , bidaskCandlestickHighBid  :: Decimal
  , bidaskCandlestickHighAsk  :: Decimal
  , bidaskCandlestickLowBid   :: Decimal
  , bidaskCandlestickLowAsk   :: Decimal
  , bidaskCandlestickCloseBid :: Decimal
  , bidaskCandlestickCloseAsk :: Decimal
  , bidaskCandlestickVolume   :: Int
  , bidaskCandlestickComplete :: Bool
  } deriving (Show, Generic)

instance FromJSON BidAskCandlestick where
  parseJSON = genericParseJSON $ jsonOpts "bidaskCandlestick"

data CandlesArgs = CandlesArgs
  { candlesCount           :: CandlesCount
  , candlesGranularity     :: Granularity
  , candlesDailyAlignment  :: Int
  , candlesAlignmentTZ     :: String
  , candlesWeeklyAlignment :: DayOfWeek
  } deriving (Show)

candlesArgs :: CandlesArgs
candlesArgs = CandlesArgs (Count 500) S5 17 "America/New_York" Friday

data CandlesCount = Count Int
                  | StartEnd
                    { start :: ZonedTime
                    , end :: ZonedTime
                    , includeFirst :: Bool
                    }
                  | StartCount
                    { start :: ZonedTime
                    , count :: Int
                    , includeFirst :: Bool
                    }
                  | EndCount
                    { end :: ZonedTime
                    , count :: Int
                    }
                  deriving (Show)

data DayOfWeek = Monday
               | Tuesday
               | Wednesday
               | Thursday
               | Friday
               | Saturday
               | Sunday
               deriving (Show)

data Granularity = S5 | S10 | S15 | S30
                 | M1 | M2 | M3 | M4 | M5 | M10 | M15 | M30
                 | H1 | H2 | H3 | H4 | H6 | H8 | H12
                 | D
                 | W
                 | M
                 deriving (Show)

-- | Utility function to convert Granularity to NominalDiffTime. __NOTE__: The
-- conversion from month to NominalDiffTime is not correct in general; we just
-- assume 31 days in a month, which is obviously false for 5 months of the
-- year.
granularityToDiffTime :: Granularity -> NominalDiffTime
granularityToDiffTime S5 = fromSeconds' 5
granularityToDiffTime S10 = fromSeconds' 10
granularityToDiffTime S15 = fromSeconds' 15
granularityToDiffTime S30 = fromSeconds' 30
granularityToDiffTime M1 = fromSeconds' $ 1 * 60
granularityToDiffTime M2 = fromSeconds' $ 2 * 60
granularityToDiffTime M3 = fromSeconds' $ 3 * 60
granularityToDiffTime M4 = fromSeconds' $ 4 * 60
granularityToDiffTime M5 = fromSeconds' $ 5 * 60
granularityToDiffTime M10 = fromSeconds' $ 10 * 60
granularityToDiffTime M15 = fromSeconds' $ 15 * 60
granularityToDiffTime M30 = fromSeconds' $ 30 * 60
granularityToDiffTime H1 = fromSeconds' $ 1 * 60 * 60
granularityToDiffTime H2 = fromSeconds' $ 2 * 60 * 60
granularityToDiffTime H3 = fromSeconds' $ 3 * 60 * 60
granularityToDiffTime H4 = fromSeconds' $ 4 * 60 * 60
granularityToDiffTime H6 = fromSeconds' $ 6 * 60 * 60
granularityToDiffTime H8 = fromSeconds' $ 8 * 60 * 60
granularityToDiffTime H12 = fromSeconds' $ 12 * 60 * 60
granularityToDiffTime D = fromSeconds' $ 1 * 60 * 60 * 24
granularityToDiffTime W = fromSeconds' $ 7 * 60 * 60 * 24
granularityToDiffTime M = fromSeconds' $ 31 * 60 * 60 * 24

-- | Utility type for `midpointCandles` function response. Not exported.
data MidpointCandlesResponse = MidpointCandlesResponse
  { _midcandlesResponseInstrument  :: InstrumentText
  , _midcandlesResponseGranularity :: String
  , _midcandlesResponseCandles     :: V.Vector MidpointCandlestick
  } deriving (Show, Generic)


instance FromJSON MidpointCandlesResponse where
  parseJSON = genericParseJSON $ jsonOpts "_midcandlesResponse"


-- | Utility type for `bidaskCandles` function response. Not exported.
data BidAskCandlesResponse = BidAskCandlesResponse
  { _bidaskResponseInstrument  :: InstrumentText
  , _bidaskResponseGranularity :: String
  , _bidaskResponseCandles     :: V.Vector BidAskCandlestick
  } deriving (Show, Generic)


instance FromJSON BidAskCandlesResponse where
  parseJSON = genericParseJSON $ jsonOpts "_bidaskResponse"
