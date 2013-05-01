import Criterion.Main
import Criterion.Config
import Control.Exception
import Control.DeepSeq
import Control.Monad.Trans
import qualified Data.ByteString.Char8 as B
import Control.Applicative
import qualified Data.CritBit as C
import qualified Data.Map as Map

main = do
  keys <- B.lines <$> B.readFile "/usr/share/dict/words"
  let kvs = zip keys [(0::Int)..]
  defaultMainWith
    defaultConfig
    (liftIO . evaluate $ rnf [kvs])
    [ bgroup "critbit" [
        bench "fromList" $ whnf C.fromList kvs
      ]
    , bgroup "map" [
        bench "fromList" $ whnf Map.fromList kvs
      ]
    ]