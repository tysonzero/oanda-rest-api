{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Defines types used in the REST API

module OANDA.Types
       ( APIType (..)
       , apiEndpoint
       , AccessToken (..)
       , AccountID (..)
       , Side (..)
       ) where

#if !MIN_VERSION_base(4,8,0)
import           Control.Applicative (pure)
#endif

import           Control.Monad (mzero)
import           Data.Aeson
import           Data.ByteString (ByteString)
import           Data.Text (unpack)
import           GHC.Generics (Generic)

-- | The three endpoint types used in the REST API. See the following link for
-- details: <http://developer.oanda.com/rest-live/development-guide/>
data APIType = Sandbox | Practice | Live

-- | Specifies the endpoints for each `APIType`. These are the base URLs for
-- each API call.
apiEndpoint :: APIType -> String
apiEndpoint Sandbox  = "http://api-sandbox.oanda.com"
apiEndpoint Practice = "https://api-fxpractice.oanda.com"
apiEndpoint Live     = "https://api-fxtrade.oanda.com"

-- | The token given by OANDA used to access the API
newtype AccessToken = AccessToken { unAccessToken :: ByteString }


-- | Integer representing the Account ID of an account
newtype AccountID = AccountID { unAccountID :: Int }

-- | Used when reporting a position in the API
data Side = Buy
          | Sell
          deriving (Show, Generic)

instance FromJSON Side where
  parseJSON (String s) = fmap readSide (pure $ unpack s)
  parseJSON _          = mzero


readSide :: String -> Side
readSide "buy"  = Buy
readSide "sell" = Sell
readSide _      = error "No parse Side"
