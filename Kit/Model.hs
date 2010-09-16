module Kit.Model where

  import Text.JSON
  import Control.Applicative
  import System.FilePath.Posix

  data KitSpec = KitSpec {
    specKit :: Kit,
    specConfiguration :: KitConfiguration
  } deriving (Show, Read)

  data KitConfiguration = KitConfiguration {
    kitConfigDependencies :: [Kit],
    sourceDir :: FilePath
  } deriving (Show, Read)

  specDependencies :: KitSpec -> [Kit]
  specDependencies = kitConfigDependencies . specConfiguration

  defaultConfiguration :: KitConfiguration
  defaultConfiguration = KitConfiguration [] "src"

  type Version = String

  data Kit = Kit {
    kitName :: String,
    kitVersion :: Version
  } deriving (Eq, Show, Ord, Read)

  kitFileName :: Kit -> String
  kitFileName k = kitName k ++ "-" ++ kitVersion k

  kitConfigFile :: Kit -> String
  kitConfigFile kit = kitFileName kit </> (kitName kit ++ ".xcconfig")

  instance JSON Kit where
      showJSON kit = makeObj
          [ ("name", showJSON $ kitName kit)
          , ("version", showJSON $ kitVersion kit)
          ]

      readJSON (JSObject obj) = Kit <$> f "name" <*> f "version"
        where f x = mLookup x jsonObjAssoc >>= readJSON
              jsonObjAssoc = fromJSObject obj

  instance JSON KitSpec where
      showJSON spec = makeObj
          [ ("name", showJSON $ kitName kit)
          , ("version", showJSON $ kitVersion kit)
          , ("dependencies", showJSON $ specDependencies spec)
          ]
          where kit = specKit spec

      readJSON (JSObject obj) =
          let myKit = Kit <$> f "name" <*> f "version"
              myConfig = (KitConfiguration <$> f "dependencies" <*> (f "sourceDir" <|> pure "src"))
           in KitSpec <$> myKit <*> myConfig
        where f x = mLookup x jsonObjAssoc >>= readJSON
              jsonObjAssoc = fromJSObject obj

  mLookup :: Monad m => String -> [(String, b)] -> m b
  mLookup a as = maybe (fail $ "No such element: " ++ a) return (lookup a as)
