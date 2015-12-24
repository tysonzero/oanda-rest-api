{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Defines the endpoints listed in the
-- <http://developer.oanda.com/rest-live/positions/ Positions> section of the
-- API.

module OANDA.Positions
       ( Position (..)
       , openPositions
       ) where

import           Data.Aeson
import qualified Data.Vector as V
import           GHC.Generics (Generic)

import           OANDA.Util
import           OANDA.Types

openPositions :: APIType -> AccountID -> AccessToken -> IO (V.Vector Position)
openPositions apit (AccountID aid) t =
  do let url = apiEndpoint apit ++ "/v1/accounts/" ++ show aid ++ "/positions"
         opts = constructOpts t []
     jsonResponseArray url opts "positions"

data Position = Position
  { positionInstrument :: String
  , positionUnits      :: Int
  , positionSide       :: Side
  , positionAvgPrice   :: Double
  } deriving (Show, Generic)

instance FromJSON Position where
  parseJSON = genericParseJSON $ jsonOpts "position"
