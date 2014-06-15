{-# LANGUAGE NumDecimals #-}

module HUnit (props) where


import Data.Either

import Data.Binary.Typed

import Test.Tasty
import Test.Tasty.HUnit



-- | The entire HUnit test tree, to be imported qualified
props :: TestTree
props = tree tests where
      tree = testGroup "HUnit"
      tests = [error_coercion]


-- | Test whether encoding an Int and decoding it as Bool produces a type error
error_coercion :: TestTree
error_coercion = tree tests where
      tree = testGroup "Encode Int, decode Bool => Type error"
      tests = [ error_int_bool_hashed
              , error_int_bool_shown
              , error_int_bool_full
              ]

-- | See 'error_coercion'
error_int_bool_hashed :: TestTree
error_int_bool_hashed =
      testCase "Hashed" $

      isLeft (coercion_int_bool Hashed)
      @?
      "No type error when coercing Int to Bool (with hashed type info)"

-- | See 'error_coercion'
error_int_bool_shown :: TestTree
error_int_bool_shown =
      testCase "Shown" $

      isLeft (coercion_int_bool Shown)
      @?
      "No type error when coercing Int to Bool (with shown type info)"

-- | See 'error_coercion'
error_int_bool_full :: TestTree
error_int_bool_full =
      testCase "Full" $

      isLeft (coercion_int_bool Full)
      @?
      "No type error when coercing Int to Bool (with full type info)"

-- | See 'error_coercion'
coercion_int_bool :: TypeFormat -> Either String Bool
coercion_int_bool format = decodeTyped (encodeTyped format (123 :: Int))