{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module SlamData.Workspace.FormBuilder.Item.Model
  ( Model
  , FieldName(..)
  , initialModel
  , genModel
  , encode
  , decode
  , sanitiseValueFromForm
  , sanitiseValueForForm
  , EqModel(..)
  , runEqModel
  , defaultValueToVarMapValue
  , module SlamData.Workspace.FormBuilder.Item.FieldType
  ) where

import SlamData.Prelude

import Data.Argonaut ((~>), (:=), (.?))
import Data.Argonaut as J
import Data.Json.Extended.Signature as EJS
import Data.Json.Extended.Type as EJT
import Data.Lens (preview)
import Data.String as Str
import SlamData.SqlSquared.Tagged as SqlT
import SlamData.Workspace.Card.Port.VarMap as Port
import SlamData.Workspace.FormBuilder.Item.FieldType (FieldType(..), _FieldTypeDisplayName, allFieldTypes, fieldTypeToInputType)
import SqlSquared as Sql
import Test.StrongCheck.Arbitrary as SC
import Test.StrongCheck.Gen as Gen
import Text.Parsing.Parser as P

newtype FieldName = FieldName String

derive newtype instance eqFieldName :: Eq FieldName
derive newtype instance ordFieldName :: Ord FieldName
derive instance newtypeFieldName :: Newtype FieldName _

instance showFieldName ∷ Show FieldName where
  show (FieldName name) = "(FieldName " <> show name <> ")"

type Model =
  { name ∷ FieldName
  , fieldType ∷ FieldType
  , defaultValue ∷ Maybe String
  }

genModel ∷ Gen.Gen Model
genModel = do
  name ← FieldName <$> SC.arbitrary
  fieldType ← SC.arbitrary
  defaultValue ← SC.arbitrary
  pure { name, fieldType, defaultValue }

newtype EqModel = EqModel Model

runEqModel
  ∷ EqModel
  → Model
runEqModel (EqModel m) =
  m

derive instance eqEqModel ∷ Eq EqModel

initialModel ∷ Model
initialModel =
  { name: FieldName ""
  , fieldType: StringFieldType
  , defaultValue: Nothing
  }

encode
  ∷ Model
  → J.Json
encode st =
  "name" := unwrap st.name
  ~> "fieldType" := st.fieldType
  ~> "defaultValue" := st.defaultValue
  ~> J.jsonEmptyObject

decode
  ∷ J.Json
  → Either String Model
decode =
  J.decodeJson >=> \obj → do
    name ← FieldName <$> obj .? "name"
    fieldType ← obj .? "fieldType"
    defaultValue ← obj .? "defaultValue"
    pure { name, fieldType, defaultValue }

-- | This takes the HTML-produced form values and tweaks the date/time values
-- | to match the acceptable `YYYY-MM-DDTHH:mm:ssZ` / `YYYY-MM-DD` / `HH:mm:ss`
-- | forms.
sanitiseValueFromForm ∷ FieldType → String → String
sanitiseValueFromForm ty s = case ty of
  DateTimeFieldType
    | Str.charAt 10 s ≡ Just ' ' →
        sanitiseValueFromForm ty (Str.take 10 s <> "T" <> Str.drop 11 s)
    | Str.length s ≡ 19 → s <> "Z"
  DateFieldType → Str.take 10 s
  TimeFieldType
    | Str.length s == 5 → s <> ":00"
    | otherwise → Str.take 8 s
  _ → s

-- | This takes values produced by `sanitiseValueFromForm` and formats them back
-- | into values acceptable for populating HTML forms.
sanitiseValueForForm ∷ FieldType → String → String
sanitiseValueForForm ty s = case ty of
  DateTimeFieldType → Str.take 19 s
  DateFieldType → Str.take 10 s
  TimeFieldType → Str.take 8 s
  _ → s

defaultValueToVarMapValue
  ∷ FieldType
  → String
  → Either SqlT.ParseError Port.VarMapValue
defaultValueToVarMapValue ty str =
  map Port.VarMapValue case ty of
    StringFieldType →
      pure $ Sql.string str
    DateTimeFieldType →
      SqlT.datetimeSql str
    DateFieldType →
      SqlT.dateSql str
    TimeFieldType →
      SqlT.timeSql str
    IntervalFieldType →
      SqlT.intervalSql str
    ObjectIdFieldType →
      SqlT.oidSql str
    SqlExprFieldType →
      parseSql str
    SqlIdentifierFieldType →
      pure $ Sql.ident str
    BooleanFieldType → do
      value ← parseSql str
      unless (value `hasType` EJT.Boolean) $
        throwError $ SqlT.ParseError ("Failed to parse " <> show str <> " as a Boolean")
      pure value
    NumericFieldType → do
      value ← parseSql str
      unless (value `hasType` EJT.Decimal || value `hasType` EJT.Integer) $
        throwError $ SqlT.ParseError ("Failed to parse " <> show str <> " as a Number")
      pure value
    ArrayFieldType → do
      value ← parseSql str
      unless (value `hasType` EJT.Array) $
        throwError $ SqlT.ParseError ("Failed to parse " <> show str <> " as an Array")
      pure value
    ObjectFieldType → do
      value ← parseSql str
      unless (value `hasType` EJT.Map) $
        throwError $ SqlT.ParseError ("Failed to parse " <> show str <> " as a Map")
      pure value
  where
    parseSql s = lmap (SqlT.ParseError ∘ P.parseErrorMessage) $ Sql.parse s
    hasType val ty' = maybe false (\ej → EJS.getType ej == ty') (preview Sql._Literal val)
