module Main where

import Prelude hiding (map, zip)
import Synk
import Data.Functor.Of (Of(..))
import qualified Streaming.Prelude as S

main :: IO ()
main = S.foldrM (\a m -> print a >> m) $ runSynk $ zip l r

l :: Monad m => Synk 4 (Of Int) m ()
l = yield 1 +> yield 2 +> yield 3 +> yield 4

r :: Synk 4 (Of Int) IO ()
r =  for (yield 1 +> yield 2) $ \i ->
        for (yield 4 +> yield 5) $ \j -> 
            map (\x -> i + j * x) (effect (yield <$> readLn))