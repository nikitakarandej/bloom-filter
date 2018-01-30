{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Main where

import BloomFilter.Hash (Hashable)
import qualified BloomFilter.Easy as B
import Data.Word (Word8, Word32)
import System.Random (Random(..), RandomGen)
import qualified Data.ByteString as Strict
import qualified Data.ByteString.Lazy as Lazy

import Test.QuickCheck


instance Arbitrary Lazy.ByteString where
    arbitrary = Lazy.pack `fmap` arbitrary

instance CoArbitrary Lazy.ByteString where
    coarbitrary = coarbitrary . Lazy.unpack

instance Arbitrary Strict.ByteString where
    arbitrary = Strict.pack `fmap` arbitrary

instance CoArbitrary Strict.ByteString where
    coarbitrary = coarbitrary . Strict.unpack


handyCheck :: Testable a => Int -> a -> IO ()
handyCheck limit =
    quickCheckWith $ stdArgs { maxSuccess = limit }

-- Test case generator
genFalsePositiveRate :: Gen Double
genFalsePositiveRate =
    choose (epsilon, 1 - epsilon)
    where epsilon = 1e-6

-- Use this to filter out values from easyList
(=~>) :: Either a b -> (b -> Bool) -> Bool
-- `either` applies first function if val is Left, otherwise second function
k =~> f = either (const True) f k

-- `element` is generated by quickcheck based on the type signature 
prop_one_present element =
    forAll genFalsePositiveRate $ \errRate ->
        B.easyList errRate [element] =~> \bfilter -> element `B.elem` bfilter

prop_all_present elements =
    forAll genFalsePositiveRate $ \errRate ->
        B.easyList errRate elements =~> \bfilter ->
            all (flip B.elem $ bfilter) elements

prop_suggestions_sane =
    forAll genFalsePositiveRate $ \errRate ->
        forAll (choose (1, fromIntegral maxWord32 `div` 8)) $ \maxCapacity ->
            let size = fst . minimum $ B.suggestSizes maxCapacity errRate
                isSane (numBits, numHashes) =
                    numBits > 0 && numBits < maxBound && numHashes > 0
            -- filter out some inputs for the test case
            in  size < fromIntegral maxWord32 ==>
                    either (const False) isSane $
                        B.suggestParams maxCapacity errRate
        where maxWord32 = maxBound :: Word32


main :: IO ()
main = do
    handyCheck 1000 (prop_one_present :: String -> Property)
    handyCheck 1000 (prop_all_present :: [Lazy.ByteString] -> Property)
    handyCheck 1000 (prop_all_present :: [String] -> Property)
