{-# LANGUAGE BangPatterns, RecordWildCards, ScopedTypeVariables #-}

-- |
-- Module      :  Data.CritBit.Tree
-- Copyright   :  (c) Bryan O'Sullivan 2013
-- License     :  BSD-style
-- Maintainer  :  bos@serpentine.com
-- Stability   :  experimental
-- Portability :  GHC
module Data.CritBit.Tree
    (
    -- * Operators
    -- , (!)
    -- , (\\)

    -- * Query
      null
    , size
    , member
    , notMember
    , lookup
    , findWithDefault
    , lookupGT
    -- , lookupGE

    -- * Construction
    , empty
    , singleton

    -- * Insertion
    , insert
    , insertWith
    , insertWithKey
    -- , insertLookupWithKey

    -- * Deletion
    , delete
    -- , adjust
    -- , adjustWithKey
    , update
    , updateWithKey
    -- , updateLookupWithKey
    , alter

    -- * Combination
    -- ** Union
    , union
    , unionWith
    , unionWithKey
    , unions
    , unionsWith
    , unionL
    , unionR

    -- ** Difference
    -- , difference
    -- , differenceWith
    -- , differenceWithKey

    -- ** Intersection
    -- , intersection
    -- , intersectionWith
    -- , intersectionWithKey

    -- * Traversal
    -- ** Map
    , map
    , mapWithKey
    , traverseWithKey
    , mapAccum
    , mapAccumWithKey
    , mapAccumRWithKey
    , mapKeys
    -- , mapKeysWith
    -- , mapKeysMonotonic

    -- * Folds
    , foldl
    , foldr
    , foldlWithKey
    , foldrWithKey

    -- ** Strict folds
    , foldl'
    , foldr'
    , foldlWithKey'
    , foldrWithKey'

    -- * Conversion
    , elems
    , keys
    , assocs
    -- , keysSet
    -- , fromSet

    -- ** Lists
    , toList
    , fromList
    -- , fromListWith
    -- , fromListWithKey

    -- ** Ordered lists
    , toAscList
    , toDescList
    -- , fromAscList
    -- , fromAscListWith
    -- , fromAscListWithKey
    -- , fromDistinctAscList

    -- * Filter
    , filter
    , filterWithKey
    -- , partition
    -- , partitionWithKey

    -- , mapMaybe
    , mapMaybeWithKey
    -- , mapEither
    -- , mapEitherWithKey

    -- , split
    -- , splitLookup

    -- * Submap
    -- , isSubmapOf
    -- , isSubmapOfBy
    -- , isProperSubmapOf
    -- , isProperSubmapOfBy

    -- -- * Min\/Max
    , findMin
    , findMax
    , deleteMin
    , deleteMax
    , deleteFindMin
    , deleteFindMax
    , updateMin
    , updateMax
    , updateMinWithKey
    , updateMaxWithKey
    , minView
    , maxView
    , minViewWithKey
    , maxViewWithKey
    ) where

import Control.Applicative (Applicative(..), (<$>), (*>), (<|>), pure, liftA2)
import Control.Arrow (second)
import Control.Monad (guard)
import Data.CritBit.Core
import Data.CritBit.Types.Internal
import Data.Maybe (fromMaybe)
import Prelude hiding (foldl, foldr, lookup, null, map, filter)
import qualified Data.List as List

-- | /O(1)/. Is the map empty?
--
-- > null (empty)           == True
-- > null (singleton 1 'a') == False
null :: CritBit k v -> Bool
null (CritBit Empty) = True
null _               = False

-- | /O(1)/. The empty map.
--
-- > empty      == fromList []
-- > size empty == 0
empty :: CritBit k v
empty = CritBit { cbRoot = Empty }

-- | /O(log n)/. Is the key a member of the map?
--
-- > member "a" (fromList [("a",5), ("b",3)]) == True
-- > member "c" (fromList [("a",5), ("b",3)]) == False
--
-- See also 'notMember'.
member :: (CritBitKey k) => k -> CritBit k v -> Bool
member k m = lookupWith False (const True) k m
{-# INLINABLE member #-}

-- | /O(log n)/. Is the key not a member of the map?
--
-- > notMember "a" (fromList [("a",5), ("b",3)]) == False
-- > notMember "c" (fromList [("a",5), ("b",3)]) == True
--
-- See also 'member'.
notMember :: (CritBitKey k) => k -> CritBit k v -> Bool
notMember k m = lookupWith True (const False) k m
{-# INLINE notMember #-}

-- | /O(log n)/. Lookup the value at a key in the map.
--
-- The function will return the corresponding value as @('Just' value)@,
-- or 'Nothing' if the key isn't in the map.
--
-- An example of using @lookup@:
--
-- > {-# LANGUAGE OverloadedStrings #-}
-- > import Data.Text
-- > import Prelude hiding (lookup)
-- > import Data.CritBit.Map.Lazy
-- >
-- > employeeDept, deptCountry, countryCurrency :: CritBit Text Text
-- > employeeDept = fromList [("John","Sales"), ("Bob","IT")]
-- > deptCountry = fromList [("IT","USA"), ("Sales","France")]
-- > countryCurrency = fromList [("USA", "Dollar"), ("France", "Euro")]
-- >
-- > employeeCurrency :: Text -> Maybe Text
-- > employeeCurrency name = do
-- >   dept <- lookup name employeeDept
-- >   country <- lookup dept deptCountry
-- >   lookup country countryCurrency
-- >
-- > main = do
-- >   putStrLn $ "John's currency: " ++ show (employeeCurrency "John")
-- >   putStrLn $ "Pete's currency: " ++ show (employeeCurrency "Pete")
--
-- The output of this program:
--
-- >   John's currency: Just "Euro"
-- >   Pete's currency: Nothing
lookup :: (CritBitKey k) => k -> CritBit k v -> Maybe v
lookup k m = lookupWith Nothing Just k m
{-# INLINABLE lookup #-}

-- | /O(log n)/. Delete a key and its value from the map. When the key
-- is not a member of the map, the original map is returned.
--
-- > delete "a" (fromList [("a",5), ("b",3)]) == singleton "b" 3
-- > delete "c" (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",3)]
-- > delete "a" empty                         == empty
delete :: (CritBitKey k) => k -> CritBit k v -> CritBit k v
delete = updateWithKey (\_k _v -> Nothing)
{-# INLINABLE delete #-}

-- | /O(log n)/. The expression (@'update' f k map@ updates the value @x@
-- at @k@ (if it is in the map). If (@f x@) is 'Nothing', the element is
-- deleted. If it is (@'Just' y@), the key @k@ is bound to the new value @y@.
--
-- > let f x = if x == 5 then Just 50 else Nothing
-- > update f "a" (fromList [("b",3), ("a",5)]) == fromList [("a", 50), ("b",3)]
-- > update f "c" (fromList [("b",3), ("a",5)]) == fromList [("a", 50), ("b",3)]
-- > update f "b" (fromList [("b",3), ("a",5)]) == singleton "a" 5
update :: (CritBitKey k) => (v -> Maybe v) -> k -> CritBit k v -> CritBit k v
update f = updateWithKey (const f)
{-# INLINABLE update #-}

-- | /O(log n)/. Returns the value associated with the given key, or
-- the given default value if the key is not in the map.
--
-- > findWithDefault 1 "x" (fromList [("a",5), ("b",3)]) == 1
-- > findWithDefault 1 "a" (fromList [("a",5), ("b",3)]) == 5
findWithDefault :: (CritBitKey k) =>
                   v -- ^ Default value to return if lookup fails.
                -> k -> CritBit k v -> v
findWithDefault d k m = lookupWith d id k m
{-# INLINABLE findWithDefault #-}

-- | /O(log n)/. Find smallest key greater than the given one and
-- return the corresponding (key, value) pair.
--
-- > lookupGT "aa" (fromList [("a",3), ("b",5)]) == Just ("b",5)
-- > lookupGT "b"  (fromList [("a",3), ("b",5)]) == Nothing
lookupGT :: (CritBitKey k) => k -> CritBit k v -> Maybe (k, v)
lookupGT k (CritBit root) = go root
  where
    go i@(Internal left right _ _)
      | direction k i == 0 = go left
      | otherwise          = go right
    go (Leaf lk lv)        = rewalk root
      where
        finish (Leaf _ _) = case byteCompare k lk of
                              LT -> Just (lk, lv)
                              _ -> Nothing
        finish node
          | calcDirection nob c == 0 = Nothing
          | otherwise                = leftmost Nothing pair node
        rewalk i@(Internal left right byte otherBits)
          | byte > n                     = finish i
          | byte == n && otherBits > nob = finish i
          | direction k i == 0       = case rewalk left of
                                        Nothing -> leftmost Nothing pair right
                                        wat     -> wat
          | otherwise                    = rewalk right
        rewalk i                         = finish i
        (n, nob, c) = followPrefixes k lk
        pair a b = Just (a, b)
    go Empty = Nothing
{-# INLINABLE lookupGT #-}

byteCompare :: (CritBitKey k) => k -> k -> Ordering
byteCompare a b = go 0
  where
    go i = case ba `compare` getByte b i of
             EQ | ba /= 0   -> go (i + 1)
             wat            -> wat
      where ba = getByte a i
{-# INLINABLE byteCompare #-}

-- | /O(n*log n)/. Build a map from a list of key\/value pairs.  If
-- the list contains more than one value for the same key, the last
-- value for the key is retained.
--
-- > fromList [] == empty
-- > fromList [("a",5), ("b",3), ("a",2)] == fromList [("a",2), ("b",3)]
fromList :: (CritBitKey k) => [(k, v)] -> CritBit k v
fromList = List.foldl' (flip (uncurry insert)) empty
{-# INLINABLE fromList #-}

-- | /O(1)/. A map with a single element.
--
-- > singleton "a" 1        == fromList [("a",1)]
singleton :: k -> v -> CritBit k v
singleton k v = CritBit (Leaf k v)
{-# INLINE singleton #-}

-- | /O(n)/. The number of elements in the map.
--
-- > size empty                                  == 0
-- > size (singleton "a" 1)                      == 1
-- > size (fromList [("a",1), ("c",2), ("b",3)]) == 3
size :: CritBit k v -> Int
size (CritBit root) = go root
  where
    go (Internal l r _ _) = go l + go r
    go (Leaf _ _) = 1
    go Empty      = 0

-- | /O(n)/. Fold the values in the map using the given
-- left-associative function, such that
-- @'foldl' f z == 'Prelude.foldl' f z . 'elems'@.
--
-- Examples:
--
-- > elems = reverse . foldl (flip (:)) []
--
-- > foldl (+) 0 (fromList [("a",5), ("bbb",3)]) == 8
foldl :: (a -> v -> a) -> a -> CritBit k v -> a
foldl f z m = foldlWithKeyWith (\_ b -> b) (\a _ v -> f a v) z m
{-# INLINABLE foldl #-}

-- | /O(n)/. A strict version of 'foldl'. Each application of the
-- function is evaluated before using the result in the next
-- application. This function is strict in the starting value.
foldl' :: (a -> v -> a) -> a -> CritBit k v -> a
foldl' f z m = foldlWithKeyWith seq (\a _ v -> f a v) z m
{-# INLINABLE foldl' #-}

-- | /O(n)/. Fold the keys and values in the map using the given
-- left-associative function, such that
-- @'foldlWithKey' f z == 'Prelude.foldl' (\\z' (kx, x) -> f z' kx x) z . 'toAscList'@.
--
-- Examples:
--
-- > keys = reverse . foldlWithKey (\ks k x -> k:ks) []
--
-- > let f result k a = result ++ "(" ++ show k ++ ":" ++ a ++ ")"
-- > foldlWithKey f "Map: " (fromList [("a",5), ("b",3)]) == "Map: (b:3)(a:5)"
foldlWithKey :: (a -> k -> v -> a) -> a -> CritBit k v -> a
foldlWithKey f z m = foldlWithKeyWith (\_ b -> b) f z m
{-# INLINABLE foldlWithKey #-}

-- | /O(n)/. A strict version of 'foldlWithKey'. Each application of
-- the function is evaluated before using the result in the next
-- application. This function is strict in the starting value.
foldlWithKey' :: (a -> k -> v -> a) -> a -> CritBit k v -> a
foldlWithKey' f z m = foldlWithKeyWith seq f z m
{-# INLINABLE foldlWithKey' #-}

foldlWithKeyWith :: (a -> a -> a) -> (a -> k -> v -> a) -> a -> CritBit k v -> a
foldlWithKeyWith maybeSeq f z0 (CritBit root) = go z0 root
  where
    go z (Internal left right _ _) = let z' = go z left
                                     in z' `maybeSeq` go z' right
    go z (Leaf k v)                = f z k v
    go z Empty                     = z
{-# INLINE foldlWithKeyWith #-}

-- | /O(n)/. Fold the values in the map using the given
-- right-associative function, such that
-- @'foldr' f z == 'Prelude.foldr' f z . 'elems'@.
--
-- Example:
--
-- > elems map = foldr (:) [] map
foldr :: (v -> a -> a) -> a -> CritBit k v -> a
foldr f z m = foldrWithKeyWith (\_ b -> b) (\_ v a -> f v a) z m
{-# INLINABLE foldr #-}

-- | /O(n)/. A strict version of 'foldr'. Each application of the
-- function is evaluated before using the result in the next
-- application. This function is strict in the starting value.
foldr' :: (v -> a -> a) -> a -> CritBit k v -> a
foldr' f z m = foldrWithKeyWith seq (\_ v a -> f v a) z m
{-# INLINABLE foldr' #-}

-- | /O(n)/. Fold the keys and values in the map using the given
-- right-associative function, such that
-- @'foldrWithKey' f z == 'Prelude.foldr' ('uncurry' f) z . 'toAscList'@.
--
-- Examples:
--
-- > keys map = foldrWithKey (\k x ks -> k:ks) [] map
--
-- > let f k a result = result ++ "(" ++ show k ++ ":" ++ a ++ ")"
-- > foldrWithKey f "Map: " (fromList [("a",5), ("b",3)]) == "Map: (a:5)(b:3)"
foldrWithKey :: (k -> v -> a -> a) -> a -> CritBit k v -> a
foldrWithKey f z m = foldrWithKeyWith (\_ b -> b) f z m
{-# INLINABLE foldrWithKey #-}

-- | /O(n)/. A strict version of 'foldrWithKey'. Each application of
-- the function is evaluated before using the result in the next
-- application. This function is strict in the starting value.
foldrWithKey' :: (k -> v -> a -> a) -> a -> CritBit k v -> a
foldrWithKey' f z m = foldrWithKeyWith seq f z m
{-# INLINABLE foldrWithKey' #-}

foldrWithKeyWith :: (a -> a -> a) -> (k -> v -> a -> a) -> a -> CritBit k v -> a
foldrWithKeyWith maybeSeq f z0 (CritBit root) = go root z0
  where
    go (Internal left right _ _) z = let z' = go right z
                                     in z' `maybeSeq` go left z'
    go (Leaf k v) z                = f k v z
    go Empty z                     = z
{-# INLINE foldrWithKeyWith #-}

-- | /O(n)/. Return all the elements of the map in ascending order of
-- their keys.
--
-- > elems (fromList [("b",5), ("a",3)]) == [3,5]
-- > elems empty == []
elems :: CritBit k v -> [v]
elems m = foldrWithKey f [] m
  where f _ v vs = v : vs

-- | /O(n)/. An alias for 'toAscList'. Return all key/value pairs in the map in
-- ascending order.
--
-- > assocs (fromList [(5,"a"), (3,"b")]) == [(3,"b"), (5,"a")]
-- > assocs empty == []
assocs :: CritBit k v -> [(k,v)]
assocs m = toAscList m

-- | /O(n)/. Return all keys of the map in ascending order.
--
-- > keys (fromList [("b",5), ("a",3)]) == ["a","b"]
-- > keys empty == []
keys :: CritBit k v -> [k]
keys m = foldrWithKey f [] m
  where f k _ ks = k : ks

unionL :: (CritBitKey k) => CritBit k v -> CritBit k v -> CritBit k v
unionL a b = unionWithKey (\_ x _ -> x) a b
{-# INLINABLE unionL #-}

unionR :: (CritBitKey k) => CritBit k v -> CritBit k v -> CritBit k v
unionR a b = unionWithKey (\_ x _ -> x) b a
{-# INLINABLE unionR #-}

union :: (CritBitKey k) => CritBit k v -> CritBit k v -> CritBit k v
union a b = unionL a b
{-# INLINE union #-}

-- | Union with a combining function.
--
-- > let l = fromList [("a", 5), ("b", 3)]
-- > let r = fromList [("A", 5), ("b", 7)]
-- > unionWith (+) l r == fromList [("A",5),("a",5),("b",10)]
unionWith :: (CritBitKey k) => (v -> v -> v)
          -> CritBit k v -> CritBit k v -> CritBit k v
unionWith f a b = unionWithKey (const f) a b

-- | Union with a combining function.
--
-- > let f key new_value old_value = byteCount key + new_value + old_value
-- > let l = fromList [("a", 5), ("b", 3)]
-- > let r = fromList [("A", 5), ("C", 7)]
-- > unionWithKey f l r == fromList [("A",5),("C",7),("a",5),("b",3)]
unionWithKey :: (CritBitKey k) => (k -> v -> v -> v)
             -> CritBit k v -> CritBit k v -> CritBit k v
unionWithKey f a b = foldlWithKey' (\m k v -> insertWithKey f k v m) b a

unions :: (CritBitKey k) => [CritBit k v] -> CritBit k v
unions cs = List.foldl' union empty cs

unionsWith :: (CritBitKey k) => (v -> v -> v) -> [CritBit k v] -> CritBit k v
unionsWith f cs = List.foldl' (unionWith f) empty cs

-- | /O(n)/. Apply a function to all values.
--
-- > map show (fromList [("b",5), ("a",3)]) == fromList [("b","5"), ("a","3")]
map :: (CritBitKey k) => (v -> w) -> CritBit k v -> CritBit k w
map = fmap

-- | /O(n*log n)/.
-- @mapKeys f@ applies the function @f@ to the keys of the map.
--
-- If @f@ maps multiple keys to the same new key, the new key is
-- associated with the value of the greatest of the original keys.
--
-- > let f = fromString . (++ "1") . show
-- > mapKeys f (fromList [("a", 5), ("b", 3)])            == fromList ([("a1", 5), ("b1", 3)])
-- > mapKeys (\ _ -> "a") (fromList [("a", 5), ("b", 3)]) == singleton "a" 3
mapKeys :: (CritBitKey k1, CritBitKey k2) =>
           (k1 -> k2) -> CritBit k1 v -> CritBit k2 v
mapKeys f = foldrWithKey g empty
  where g k x m = insertWithKey (\_ _ x0 -> x0) (f k) x m

-- | /O(n)/. Convert the map to a list of key/value pairs where the keys are in
-- ascending order.
--
-- > toAscList (fromList [(5,"a"), (3,"b")]) == [(3,"b"), (5,"a")]
toAscList :: CritBit k v -> [(k,v)]
toAscList m = foldrWithKey f [] m
  where f k v vs = (k,v) : vs

-- | /O(n)/. Convert the map to a list of key/value pairs where the keys are in
-- descending order.
--
-- > toDescList (fromList [(5,"a"), (3,"b")]) == [(5,"a"), (3,"b")]
toDescList :: CritBit k v -> [(k,v)]
toDescList m = foldlWithKey f [] m
  where f vs k v = (k,v):vs

-- | /O(n)/. Filter all values that satisfy the predicate.
--
-- > filter (> "a") (fromList [("5","a"), ("3","b")]) == fromList [("3","b")]
-- > filter (> "x") (fromList [("5","a"), ("3","b")]) == empty
-- > filter (< "a") (fromList [("5","a"), ("3","b")]) == empty
filter :: (v -> Bool) -> CritBit k v -> CritBit k v
filter p = filterWithKey (\_ -> p)

-- | /O(n)/. Filter all keys\/values that satisfy the predicate.
--
-- > filterWithKey (\k _ -> k > "4") (fromList [("5","a"), ("3","b")]) == fromList[("5","a")]
filterWithKey :: (k -> v -> Bool) -> CritBit k v -> CritBit k v
filterWithKey p (CritBit root)    = CritBit $ fromMaybe Empty (go root)
  where go i@(Internal l r _ _)   = liftA2 modInternal ml mr <|> (ml <|> mr)
          where modInternal nl nr = i { ileft = nl, iright = nr }
                ml = go l
                mr = go r
        go l@(Leaf k v)           = guard (p k v) *> pure l
        go Empty                  = Nothing
{-# INLINABLE filterWithKey #-}

-- | /O(n)/. Map keys\/values and collect the 'Just' results.
--
-- > let f k v = if k == "a" then Just ("k,v: " ++ show k ++ "," ++ show v) else Nothing
-- > mapMaybeWithKey f (fromList [("a",5), ("b",3)]) == singleton "a" "k,v: \"a\",3"
mapMaybeWithKey :: (k -> v -> Maybe v') -> CritBit k v -> CritBit k v'
mapMaybeWithKey f (CritBit root) = CritBit $ go root
  where
    go i@(Internal l r _ _) =
      case (go l, go r) of
        (m, Empty) -> m
        (Empty, m) -> m
        (m1,   m2) -> i { ileft = m1, iright = m2 }
    go (Leaf k v) = case f k v of
                      Nothing -> Empty
                      Just v' -> Leaf k v'
    go Empty      = Empty

-- | /O(log n)/. The minimal key of the map. Calls 'error' if the map
-- is empty.
--
-- > findMin (fromList [("b",3), ("a",5)]) == ("a",5)
-- > findMin empty                       Error: empty map has no minimal element
findMin :: CritBit k v -> (k,v)
findMin (CritBit root) = leftmost emptyMap (,) root
  where
    emptyMap = error "CritBit.findMin: empty map has no minimal element"
{-# INLINABLE findMin #-}

-- | /O(log n)/. The maximal key of the map. Calls 'error' if the map
-- is empty.
--
-- > findMax empty                       Error: empty map has no minimal element
findMax :: CritBit k v -> (k,v)
findMax (CritBit root) = rightmost emptyMap (,) root
  where
    emptyMap = error "CritBit.findMax: empty map has no maximal element"
{-# INLINABLE findMax #-}

-- | /O(log n)/. Delete the minimal key. Returns an empty map if the
-- map is empty.
--
-- > deleteMin (fromList [("a",5), ("b",3), ("c",7)]) == fromList [("b",3), ("c",7)]
-- > deleteMin empty == empty
deleteMin :: CritBit k v -> CritBit k v
deleteMin m = updateExtremity goLeft (const (const Nothing)) m
{-# INLINABLE deleteMin #-}

-- | /O(log n)/. Delete the maximal key. Returns an empty map if the
-- map is empty.
--
-- > deleteMin (fromList [("a",5), ("b",3), ("c",7)]) == fromList [("a",5), ("b","3")]
-- > deleteMin empty == empty
deleteMax :: CritBit k v -> CritBit k v
deleteMax m = updateExtremity goRight (const (const Nothing)) m
{-# INLINABLE deleteMax #-}

-- | /O(log n)/. Delete and find the minimal element.
--
-- > deleteFindMin (fromList [("a",5), ("b",3), ("c",10)]) == (("a",5), fromList[("b",3), ("c",10)])
-- > deleteFindMin     Error: can not return the minimal element of an empty map
deleteFindMin :: CritBit k v -> ((k, v), CritBit k v)
deleteFindMin (CritBit root)   = let (km, r) = go root in (km, CritBit r)
  where
    go (Internal (Leaf k v) r _ _) = ((k, v), r)
    go i@(Internal left _ _ _)     = (kmin, i { ileft = newLeft })
        where (kmin, newLeft)      = go left
    go (Leaf k v)                  = ((k, v), Empty)
    go _ = error $ "CritBit.deleteFindMin: can not return the minimal element \
                   \of an empty map"
{-# INLINABLE deleteFindMin #-}

-- | /O(log n)/. Delete and find the maximal element.
--
-- > deleteFindMax (fromList [("a",5), ("b",3), ("c",10)]) == (("c",10), fromList[("a",5), ("b",3)])
-- > deleteFindMax     Error: can not return the maximal element of an empty map
deleteFindMax :: CritBit k v -> ((k, v), CritBit k v)
deleteFindMax (CritBit root) = let (km, r) = go root in (km, CritBit r)
  where
    go (Internal l (Leaf k v) _ _) = ((k, v), l)
    go i@(Internal _ right _ _)    = (kmin, i { iright = newRight })
      where (kmin, newRight)       = go right
    go (Leaf k v)                  = ((k, v), Empty)
    go _ = error "CritBit.deleteFindMax: can not return the maximal element \
                  \of an empty map"
{-# INLINABLE deleteFindMax #-}

-- | /O(log n)/. Retrieves the value associated with minimal key of the
-- map, and the map stripped of that element, or 'Nothing' if passed an
-- empty map.
--
-- > minView (fromList [("a",5), ("b",3)]) == Just (5, fromList [("b",3)])
-- > minView empty == Nothing
minView :: CritBit k v -> Maybe (v, CritBit k v)
minView (CritBit Empty) = Nothing
minView m = Just $ first snd $ deleteFindMin m
{-# INLINABLE minView #-}

-- | /O(log n)/. Retrieves the value associated with maximal key of the
-- map, and the map stripped of that element, or 'Nothing' if passed an
--
-- > maxView (fromList [("a",5), ("b",3)]) == Just (3, fromList [("a",5)])
-- > maxView empty == Nothing
maxView :: CritBit k v -> Maybe (v, CritBit k v)
maxView (CritBit Empty) = Nothing
maxView m = Just $ first snd $ deleteFindMax m
{-# INLINABLE maxView #-}

-- | /O(log n)/. Retrieves the minimal (key,value) pair of the map, and
-- the map stripped of that element, or 'Nothing' if passed an empty map.
--
-- > minViewWithKey (fromList [("a",5), ("b",3)]) == Just (("a",5), fromList [("b",3)])
-- > minViewWithKey empty == Nothing
minViewWithKey :: CritBit k v -> Maybe ((k, v), CritBit k v)
minViewWithKey (CritBit Empty) = Nothing
minViewWithKey m = Just $ deleteFindMin m
{-# INLINABLE minViewWithKey #-}

-- | /O(log n)/. Retrieves the maximal (key,value) pair of the map, and
-- the map stripped of that element, or 'Nothing' if passed an empty map.
--
-- > maxViewWithKey (fromList [("a",5), ("b",3)]) == Just (("b",3), fromList [("a",5)])
-- > maxViewWithKey empty == Nothing
maxViewWithKey :: CritBit k v -> Maybe ((k,v), CritBit k v)
maxViewWithKey (CritBit Empty) = Nothing
maxViewWithKey m = Just $ deleteFindMax m
{-# INLINABLE maxViewWithKey #-}

first :: (a -> b) -> (a,c) -> (b,c)
first f (x,y) = (f x, y)
{-# INLINE first #-}

-- | /O(log n)/. Update the value at the minimal key.
--
-- > updateMin (\ a -> Just (a + 7)) (fromList [("a",5), ("b",3)]) == fromList [("a",12), ("b",3)]
-- > updateMin (\ _ -> Nothing)      (fromList [("a",5), ("b",3)]) == fromList [("b",3)]
updateMin :: (v -> Maybe v) -> CritBit k v -> CritBit k v
updateMin f m = updateExtremity goLeft (const f) m
{-# INLINABLE updateMin #-}

-- | /O(log n)/. Update the value at the maximal key.
--
-- > updateMax (\ a -> Just (a + 7)) (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",10)]
-- > updateMax (\ _ -> Nothing)      (fromList [("a",5), ("b",3)]) == fromList [("a",5)]
updateMax :: (v -> Maybe v) -> CritBit k v -> CritBit k v
updateMax f m = updateExtremity goRight (const f) m
{-# INLINABLE updateMax #-}

-- | /O(log n)/. Update the value at the minimal key.
--
-- > updateMinWithKey (\ k a -> Just (length k + a)) (fromList [("a",5), ("b",3)]) == fromList [("a",6), ("b",3)]
-- > updateMinWithKey (\ _ _ -> Nothing)             (fromList [("a",5), ("b",3)]) == fromList [("b",3)]
updateMinWithKey :: (k -> v -> Maybe v) -> CritBit k v -> CritBit k v
updateMinWithKey f m = updateExtremity goLeft f m
{-# INLINABLE updateMinWithKey #-}

-- | /O(log n)/. Update the value at the maximal key.
--
-- > updateMaxWithKey (\ k a -> Just (length k + a)) (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",4)]
-- > updateMaxWithKey (\ _ _ -> Nothing)             (fromList [("a",5), ("b",3)]) == fromList [("a",5)]
updateMaxWithKey :: (k -> v -> Maybe v) -> CritBit k v -> CritBit k v
updateMaxWithKey f m = updateExtremity goRight f m
{-# INLINABLE updateMaxWithKey #-}

updateExtremity :: ((Node k v -> Node k v) -> Node k v -> Node k v)
                -> (k -> v -> Maybe v)
                -> CritBit k v
                -> CritBit k v
updateExtremity dir maybeUpdate (CritBit root) = CritBit $ go root
  where
    go i@(Internal {}) = dir go i
    go (Leaf k v0)     = maybe Empty (Leaf k) (maybeUpdate k v0)
    go _               = root
{-# INLINE updateExtremity #-}

goLeft, goRight :: (Node k v -> Node k v) -> Node k v -> Node k v
goLeft f n = n { ileft = f l }
  where l = ileft n
{-# INLINE goLeft #-}
goRight f n = n { iright = f r }
  where r = iright n
{-# INLINE goRight #-}

-- | /O(log n)/. Insert a new key and value in the map.  If the key is
-- already present in the map, the associated value is replaced with
-- the supplied value. 'insert' is equivalent to @'insertWith'
-- 'const'@.
--
-- > insert "b" 7 (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",7)]
-- > insert "x" 7 (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",3), ("x",7)]
-- > insert "x" 5 empty                         == singleton "x" 5
insert :: (CritBitKey k) => k -> v -> CritBit k v -> CritBit k v
insert = insertWithKey (\_ v _ -> v)
{-# INLINABLE insert #-}

-- | /O(log n)/. Insert with a function, combining new value and old value.
-- @'insertWith' f key value cb@
-- will insert the pair (key, value) into @cb@ if key does
-- not exist in the map. If the key does exist, the function will
-- insert the pair @(key, f new_value old_value)@.
--
-- > insertWith (+) "a" 1 (fromList [("a",5), ("b",3)]) == fromList [("a",6), ("b",3)]
-- > insertWith (+) "c" 7 (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",3), ("c",7)]
-- > insertWith (+) "x" 5 empty                         == singleton "x" 5
--
insertWith :: CritBitKey k => (v -> v -> v) -> k -> v -> CritBit k v -> CritBit k v
insertWith f = insertWithKey (\_ v v' -> f v v')
{-# INLINABLE insertWith #-}

-- | /O(n)/. Apply a function to all values.
--
-- >  let f key x = show key ++ ":" ++ show x
-- >  mapWithKey f (fromList [("a",5), ("b",3)]) == fromList [("a","a:5"), ("b","b:3")]
mapWithKey :: (CritBitKey k) => (k -> v -> w) -> CritBit k v -> CritBit k w
mapWithKey f (CritBit root) = CritBit (go root)
  where
    go i@(Internal l r _ _) = i { ileft = go l, iright = go r }
    go (Leaf k v)           = Leaf k (f k v)
    go  Empty               = Empty
{-# INLINABLE mapWithKey #-}

-- | /O(n)/. The function 'mapAccumRWithKey' threads an accumulating
-- argument through the map in descending order of keys.
mapAccumRWithKey :: (CritBitKey k) => (a -> k -> v -> (a, w)) -> a
                 -> CritBit k v -> (a, CritBit k w)
mapAccumRWithKey f start (CritBit root) = second CritBit (go start root)
  where
    go a i@(Internal l r _ _) = let (a0, r')  = go a r
                                    (a1, l')  = go a0 l
                                in (a1, i { ileft = l', iright = r' })

    go a (Leaf k v)           = let (a0, w) = f a k v in (a0, Leaf k w)
    go a Empty                = (a, Empty)
{-# INLINABLE mapAccumRWithKey #-}

-- | /O(n)/. That is, behaves exactly like a regular 'traverse' except
-- that the traversing function also has access to the key associated
-- with a value.
--
-- > let f key value = show key ++ ":" ++ show value
-- > traverseWithKey (\k v -> if odd v then Just (f k v) else Nothing) (fromList [("a",3), ("b",5)]) == Just (fromList [("a","a:3"), ("b","b:5")])
-- > traverseWithKey (\k v -> if odd v then Just (f k v) else Nothing) (fromList [("c", 2)])           == Nothing
traverseWithKey :: (CritBitKey k, Applicative t)
                => (k -> v -> t w)
                -> CritBit k v
                -> t (CritBit k w)
traverseWithKey f (CritBit root) = fmap CritBit (go root)
  where
    go i@(Internal l r _ _) = let constr l' r' = i { ileft = l', iright = r' }
                              in constr <$> go l <*> go r
    go (Leaf k v)           = (Leaf k) <$> f k v
    go Empty                = pure Empty
{-# INLINABLE traverseWithKey #-}

-- | /O(n)/. The function 'mapAccum' threads an accumulating
-- argument through the map in ascending order of keys.
--
-- > let f a b = (a ++ show b, show b ++ "X")
-- > mapAccum f "Everything: " (fromList [("a",5), ("b",3)]) == ("Everything: 53", fromList [("a","5X"), ("b","3X")])
mapAccum :: (CritBitKey k)
         => (a -> v -> (a, w))
         -> a
         -> CritBit k v
         -> (a, CritBit k w)
mapAccum f = mapAccumWithKey (\a _ v -> f a v)
{-# INLINE mapAccum #-}

-- | /O(n)/. The function 'mapAccumWithKey' threads an accumulating
-- argument through the map in ascending order of keys.
--
-- > let f a k b = (a ++ " " ++ show k ++ "-" ++ show b, show b ++ "X")
-- > mapAccumWithKey f "Everything: " (fromList [("a",5), ("b",3)]) == ("Everything: a-5 b-3", fromList [("a","5X"), ("b","3X")])
mapAccumWithKey :: (CritBitKey k)
                => (a -> k -> v -> (a, w))
                -> a
                -> CritBit k v
                -> (a, CritBit k w)
mapAccumWithKey f start (CritBit root) = second CritBit (go start root)
  where
    go a i@(Internal l r _ _) = let (a0, l')  = go a l
                                    (a1, r')  = go a0 r
                                in (a1, i { ileft = l', iright = r' })

    go a (Leaf k v)           = let (a0, w) = f a k v in (a0, Leaf k w)
    go a Empty                = (a, Empty)
{-# INLINABLE mapAccumWithKey #-}

-- | /O(log n)/. The expression (@'alter' f k map@) alters the value @x@ at @k@, or absence thereof.
-- 'alter' can be used to insert, delete, or update a value in a 'CritBit'.
-- In short : @'lookup' k ('alter' f k m) = f ('lookup' k m)@.
--
-- > let f _ = Nothing
-- > alter f "c" (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",3)]
-- > alter f "a" (fromList [("a",5), ("b",3)]) == fromList [("b",3)]
-- >
-- > let f _ = Just 1
-- > alter f "c" (fromList [("a",5), ("b",3)]) == fromList [("a",5), ("b",3), ("c",1)]
-- > alter f "a" (fromList [(5,"a"), (3,"b")]) == fromList [("a",1), ("b",3)]
alter :: (CritBitKey k, Ord k)
      => (Maybe v -> Maybe v)
      -> k
      -> CritBit k v
      -> CritBit k v
{-# INLINABLE alter #-}
alter f k (CritBit root) = go root
  where
    go Empty = maybe empty (CritBit . Leaf k) $ f Nothing
    go nd@(Internal l r _ _)
      | direction k nd == 0 = go l
      | otherwise           = go r
    go (Leaf lk _)          = rewalk root CritBit
      where
        (n,nob,c)  = followPrefixes k lk

        rewalk i@(Internal left right byte otherBits) cont
          | byte > n           = finish i cont
          | byte == n && otherBits > nob = finish i cont
          | direction k i == 0 = rewalk left $ \new ->
                                 case new of
                                   Empty -> cont right
                                   l     -> cont $! i { ileft = l }
          | otherwise          = rewalk right $ \new ->
                                 case new of
                                   Empty -> cont left
                                   r     -> cont $! i { iright = r }
        rewalk i cont          = finish i cont

        finish (Leaf nk v) cont
          | k == nk   = maybe (cont Empty) (cont . Leaf nk) $ f (Just v)
        finish i cont = maybe (cont i) (cont . ins . Leaf k) $ f Nothing
            where ins leaf
                    | calcDirection nob c == 0 = Internal i leaf n nob
                    | otherwise                = Internal leaf i n nob
