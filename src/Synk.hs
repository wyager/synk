module Synk
    ( Synk,
    runSynk,
    empty,
    yields,
    replicates,
    effect,
    wrap,
    concats,
    inspect,
    maps,
    mapsM,
    run,
    zipsWith',
    (+>),
    for,
    yield,
    map,
    zip
    ) where

import Prelude hiding (zip,map)
import qualified Streaming.Internal as S
import qualified Streaming.Prelude as S
import GHC.TypeLits (Nat, KnownNat, natVal, type (+), type (*))
import Data.Proxy (Proxy(..))

newtype Synk (n :: Nat) (f :: * -> *) (m :: * -> *) (r :: *)
    = Synk {runSynk :: S.Stream f m r} deriving (Functor)

empty :: r -> Synk 0 f m r
empty = Synk . S.Return

yields :: (Monad m, Functor f) => f r -> Synk 1 f m r 
yields = Synk . S.yields

replicates :: forall n f m . (KnownNat n, Monad m, Functor f) => f () -> Synk n f m ()
replicates = Synk . S.replicates (fromIntegral $ natVal @n Proxy)

effect :: (Monad m, Functor f) => m (Synk n f m r) -> Synk n f m r
effect = Synk . S.effect . fmap runSynk

wrap :: (Monad m, Functor f) => f (Synk n f m r) -> Synk (n+1) f m r
wrap = Synk . S.wrap . fmap runSynk

concats :: forall i j m f r . (Monad m, Functor f) => Synk i (Synk j f m) m r -> Synk (i*j) f m r
concats = Synk . S.concats . S.maps runSynk . runSynk

inspect :: (Monad m, Functor f) => Synk (n+1) f m r -> m (f (Synk n f m r))
inspect = loop . runSynk where
    loop stream = case stream of
        S.Return _ -> error "Invalid Synk - returned too early"
        S.Effect m -> m >>= loop
        S.Step f -> return (fmap Synk f)

maps :: (Monad m, Functor f) => (forall x . f x -> g x) -> Synk n f m r -> Synk n g m r
maps f = Synk . S.maps f . runSynk

mapsM :: (Monad m, Functor f) => (forall x . f x -> m (g x)) -> Synk n f m r -> Synk n g m r
mapsM f = Synk . S.mapsM f . runSynk

run :: Monad m => Synk n m m r -> m r
run = S.run . runSynk

zipsWith' :: forall n f g h m r. Monad m => (forall x y p. (x -> y -> p) -> f x -> g y -> h p) -> Synk n f m r -> Synk n g m r -> Synk n h m r
zipsWith' f l r = Synk $ S.zipsWith' f (runSynk l) (runSynk r)

(+>) :: (Monad m, Functor f) => Synk i f m r -> Synk j f m r -> Synk (i+j) f m r
a +> b = Synk $ runSynk a >> runSynk b

for :: (Monad m, Functor f) => Synk i (S.Of a) m r -> (a -> Synk j f m x) -> Synk (i*j) f m r
for s f = Synk $ S.for (runSynk s) (runSynk . f)

yield :: Monad m => a -> Synk 1 (S.Of a) m ()
yield = Synk . S.yield 

map :: Monad m => (a -> b) -> Synk n (S.Of a) m r -> Synk n (S.Of b) m r
map f = Synk . S.map f . runSynk

zip :: Monad m => Synk n (S.Of a) m r -> Synk n (S.Of b) m r -> Synk n (S.Of (a, b)) m r
zip l r = Synk $ S.zip (runSynk l) (runSynk r)
