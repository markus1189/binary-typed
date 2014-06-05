{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DeriveGeneric #-}

module Mainn (
      Typed

      -- * Construction
      , typed
      , TypeFormat(..)

      -- * Deconstruction
      , erase
) where

import GHC.Generics
import Data.Typeable (Typeable, typeOf)
import qualified Data.Typeable.Internal as TI
import Data.Binary
import Control.Applicative

--import Test.QuickCheck


-- ^ Type information stored alongside a value to be serialized, so that the
--   recipient can do consistency checks. See 'TypeFormat' for more detailed
--   information on the fields.
data TypeInformation = HashedType Fingerprint
                     | ShownType  String
                     | FullType   TypeRep
                     deriving (Eq, Ord, Show, Generic)

instance Binary TypeInformation



-- | A value suitable to be typechecked using the contained 'TypeInformation'.
data Typed a where
      Typed :: Typeable a => TypeInformation -> a -> Typed a

instance Show a => Show (Typed a) where
      show (Typed ty x) = "typed " ++ show format  ++ " (" ++ show x ++ ")"
            where format = case ty of HashedType {} -> Hashed
                                      ShownType  {} -> Shown
                                      FullType   {} -> Full



-- | Determine how the 'TypeInformation' should be created by 'typed'.
data TypeFormat =

        -- | Compare types by their hash values.
        --
        --   * Requires only 8 bytes per serialization.
        --   * Subject to false positive due to hash collisions, although in
        --     practice this should almost never happen
        --     (see "GHC.Fingerprint.Type"for information on hashing).
        --   * Type errors cannot tell the expected type ("Expected X, received
        --     type with hash H")
        Hashed

        -- | Compare 'String' representation of types, obtained by calling
        --   'show' on the 'TypeRep'.
        --
        --   * Data size usually between 'Hashed' and 'Full'.
        --   * All types are unqualified, @Foo.X@ and @Bar.X@ look identical,
        --     thus type collisions (false positives) can happen
        --   * Useful type errors ("expected X, received Y")
      | Shown

        -- | Compare the full representation of a data type.
        --
        --   * Much more verbose than hashes.
        --   * Correct comparison (no false positives).
        --   * Useful type errors ("expected X, received Y").
      | Full

      deriving (Eq, Ord, Show)



-- | Construct a 'Typed' value using the chosen type format.
typed :: Typeable a => TypeFormat -> a -> Typed a
typed format x = Typed typeInformation x where
      ty = typeOf x
      typeInformation = case format of
            Hashed -> HashedType (getFingerprint ty)
            Shown  -> ShownType  (show           ty)
            Full   -> FullType   (getFull        ty)

-- | Extract the value of a 'Typed'.
--
--   The well-typedness of this is ensured by the 'typed' smart constructor and
--   the 'Binary' instance of 'Typed'.
erase :: Typed a -> a
erase (Typed _ x) = x

-- | Typecheck a 'Typed'. The result is either the contained value, or an
--   error message.
typecheck :: Typed a -> Either String a
typecheck (Typed typeInformation x) = case typeInformation of
      HashedType hash
            | expectedHash == hash -> Right x
            | otherwise            -> Left "type error (hash)"
      ShownType str
            | expectedShow == str  -> Right x
            | otherwise            -> Left "type error (shown)"
      FullType full
            | expectedFull == full -> Right x
            | otherwise            -> Left "type error (full)"


      where expectedType = typeOf x
            expectedHash = getFingerprint expectedType
            expectedShow = show           expectedType
            expectedFull = getFull        expectedType



-- | Extract the 'TI.Fingerptint' hash from a 'TI.TypeRep'.
getFingerprint :: TI.TypeRep -> Fingerprint
getFingerprint (TI.TypeRep fp _tycon _args) = Fingerprint fp

-- | 'TI.TypeRep' without the 'TI.Fingerprint'.
data TypeRep = TypeRep TyCon [TypeRep]
      deriving (Eq, Ord, Show, Generic)
instance Binary TypeRep

-- | 'TI.TyCon' without the 'TI.Fingerprint'.
data TyCon = TyCon String String String
      deriving (Eq, Ord, Show, Generic)
instance Binary TyCon

-- | Get (only) the representation of a data type, i.e. strip all hashes.
getFull :: TI.TypeRep -> TypeRep
getFull (TI.TypeRep _fp tycon args) = TypeRep (stripFP tycon)
                                              (map getFull args)
      where stripFP :: TI.TyCon -> TyCon
            stripFP (TI.TyCon _fp a b c) = TyCon a b c

-- | Wrapper around 'TI.Fingerprint' to avoid orphan 'Binary' instance
newtype Fingerprint = Fingerprint TI.Fingerprint
      deriving (Eq, Ord, Show)

instance Binary Fingerprint where
      get = liftA2 (\a b -> Fingerprint (TI.Fingerprint a b)) get get
      put (Fingerprint (TI.Fingerprint a b)) = put a *> put b

instance (Binary a, Typeable a) => Binary (Typed a) where
      get = do result <- get
               case typecheck result of
                     Left err -> fail   err
                     Right _  -> return result
      put (Typed ty value) = put (ty, value)

-- main = do
--       let val = 0 :: Word8
--       print val
--       putStrLn "==================="
--       let enc = encode (Typed val)
--       print enc
--       putStrLn "==================="
--       let dec = decodeOrFail enc :: Either (BSL.ByteString, Get.ByteOffset, String) (BSL.ByteString, Get.ByteOffset, Typed Word8)
--       print dec




-- #############################################################################
-- #############################################################################
-- #############################################################################

-- instance Arbitrary TI.Fingerprint where
--       arbitrary = liftA2 TI.Fingerprint arbitrary arbitrary
--
-- instance Arbitrary TI.TyCon where
--       arbitrary = TI.TyCon <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary
--
-- instance Arbitrary TI.TypeRep where
--       arbitrary = TI.TypeRep <$> arbitrary <*> arbitrary <*> resize 1 arbitrary
--
-- instance (Arbitrary a) => Arbitrary (Typed a) where
--       arbitrary = fmap Typed arbitrary
--
--
-- prop_fingerprint :: TI.Fingerprint -> Bool
-- prop_fingerprint fp = fp == decode (encode fp)
-- prop_tycon :: TI.TyCon -> Bool
-- prop_tycon tc = tc == decode (encode tc)
-- prop_typerep :: TI.TypeRep -> Bool
-- prop_typerep tr = tr == decode (encode tr)
-- prop_typed :: Typed Int -> Bool
-- prop_typed ty = ty == decode (encode ty)
--
--
-- qc = do
--       quickCheck prop_fingerprint
--       quickCheck prop_tycon
--       quickCheck prop_typerep
--       quickCheck prop_typed