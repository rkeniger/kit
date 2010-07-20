module Kit.XCode.XCConfig where

  import Kit.Util

  import qualified Data.Map as M
  import Data.Maybe
  import Data.Either
  import Data.List
  
  import Data.String.Utils

  type XCCSetting = (String, String)
  type XCCInclude = String
                    
  data XCConfig = XCC { configName :: String, configSettings :: M.Map String String, configIncludes :: [XCCInclude] } deriving (Eq, Show)
  
  includeStart = "#include "
  
  parseLine :: String -> Maybe (Either XCCSetting XCCInclude)
  parseLine l | includeStart `isPrefixOf` l = Just . Right . fromJust $ stripPrefix includeStart l
  parseLine l | "=" `isInfixOf` l = fmap (Left) $ breakAround '=' l
    where breakAround a xs = let (q,r) = break (a ==) xs in nonEmptyPair (strip q, strip $ drop 1 r)
          nonEmptyPair ([], _) = Nothing
          nonEmptyPair (_, []) = Nothing
          nonEmptyPair a@_ = Just a
  parseLine _ = Nothing
  
  settingToString :: XCCSetting -> String
  settingToString (a, b) = a ++ " = " ++ b
  
  includeToString :: XCCInclude -> String
  includeToString a = includeStart ++ a
  
  -- TODO incorporate the config name
  configToString :: XCConfig -> String
  configToString (XCC _ settings includes) = stringJoin "\n" $ (map includeToString includes) ++ (map settingToString $ M.toList settings)
                  
  fileContentsToXCC :: String -> String -> XCConfig
  fileContentsToXCC name content = let ls = lines content
                                       (settings, includes) = partitionEithers (ls >>= (maybeToList . parseLine))
                                    in XCC name (M.fromList settings) includes

  configAsMap :: XCConfig -> M.Map String [(String, String)]
  configAsMap (XCC name settings _) = M.map (return . (,) name) settings
  
  multiConfig :: String -> [XCConfig] -> XCConfig
  multiConfig name configs = XCC name settings includes
    where includes = configs >>= configIncludes
          settingsWithName = foldl (M.unionWith (++)) M.empty (map configAsMap configs)
          aggregateSettings = M.mapWithKey f settingsWithName
            where f key namesAndValues = stringJoin " " $ map ((\x -> "$(" ++ x ++ "_" ++ key ++ ")") . fst) namesAndValues
          individualSettings = M.fromList $ concatMap f $ M.toList settingsWithName
            where f (key, namesAndValues) = map (g key) namesAndValues
                  g key (n, v) = (n ++ "_" ++ key, v)
          settings = M.union aggregateSettings individualSettings
  