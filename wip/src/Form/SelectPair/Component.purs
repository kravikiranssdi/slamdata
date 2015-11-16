module Form.SelectPair.Component where

import Prelude

import Control.Monad.Aff (Aff())
import Form.Select.Component(Query(..), select)
import Data.Array (null)
import Data.Functor (($>))
import Data.Functor.Coproduct (Coproduct())
import Data.Lens (LensP(), lens, (^.), (.~), (%~), view)
import Data.Maybe (Maybe(..))
import Data.Maybe.Unsafe (fromJust)
import Model.Select
import Halogen
import Halogen.HTML.CSS.Indexed as P
import Halogen.HTML.Indexed as H
import Halogen.HTML.Properties.Indexed as P
import Halogen.HTML.Events.Indexed as E
import Halogen.Themes.Bootstrap3 as B
import Render.CssClasses as Rc
import Utils (stringToInt)

type Slam e = Aff (HalogenEffects e)

type State a =
  { model :: Select a
  , disabled :: Boolean
  }

initialState :: forall a. Select a -> State a
initialState sel =
  { model: sel
  , disabled: false
  }

_model :: forall a r. LensP {model :: a | r} a
_model = lens _.model _{model = _}

_disabled :: forall a r. LensP {disabled :: a | r} a
_disabled = lens _.disabled _{disabled = _}

type StateP a b e =
  InstalledState (State a) (Select b) (Query a) (Query b) (Slam e) Unit

type QueryP a b = Coproduct (Query a) (ChildF Unit (Query b))

type PairConfig a r =
  { disableWhen :: Int -> Boolean
  , defaultWhen :: Int -> Boolean
  , mainState :: Select a
  , classes :: Array H.ClassName
  | r
  }


selectPair
  :: forall a b e r
   . (OptionVal a, OptionVal b)
  => PairConfig b r -> Component (StateP a b e) (QueryP a b) (Slam e)
selectPair config =
  parentComponent' (render config) eval peek

render
  :: forall a b e r
   . (OptionVal a, OptionVal b)
  => PairConfig b r
  -> RenderParent (State a) (Select b) (Query a) (Query b) (Slam e) Unit
render config state = H.div_
  [ H.slot unit \_ -> { component: select config
                      , initialState: config.mainState
                      }


  , H.select [ P.classes ([ B.formControl ] <> config.classes)
               -- `fromJust` is safe here because we know that value are `show`n ints
             , E.onValueChange (E.input (Choose <<< fromJust <<< stringToInt))
             , P.disabled state.disabled
             ]
    (options state.model)
  ]
  where
  options
    :: Select a -> Array (ParentHTML (Select b) (Query a) (Query b) (Slam e) Unit)
  options select = map (option (select ^. _value)) (select ^. _options)

  option
    :: Maybe a -> a -> ParentHTML (Select b) (Query a) (Query b) (Slam e) Unit
  option mbVal opt =
    H.option [ P.value (stringVal opt)
             , P.selected (mbVal == pure opt)
             ]
    [ H.text $ stringVal opt ]

eval
  :: forall a b e
   . (Eq a, Eq b)
  => EvalParent (Query a) (State a) (Select b) (Query a) (Query b) (Slam e) Unit
eval (Choose i next) = modify (_model %~ trySelect i) $> next
eval (SetSelect sel next) = modify (_model .~ sel) $> next
eval (GetValue continue) = map continue $ gets $ view $ _model <<< _value
eval (GetSelect continue) = map continue $ gets $ view _model

peek
  :: forall a b e
   . (OptionVal a, OptionVal b)
  => Peek (ChildF Unit (Query b))
   (State a) (Select b) (Query a) (Query b) (Slam e) Unit
peek (ChildF _ (SetSelect s _)) = modify (_disabled .~ null (s ^. _options))
peek _ = pure unit
