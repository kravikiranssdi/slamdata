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

module SlamData.Workspace.Card.Next.Component
 ( nextCardComponent
 , module SlamData.Workspace.Card.Next.Component.State
 , module SlamData.Workspace.Card.Next.Component.Query
 ) where

import SlamData.Prelude

import Data.Array as Arr
import Data.Lens ((.~), (?~))

import Halogen as H
import Halogen.HTML.Events.Indexed as HE
import Halogen.HTML.Indexed as HH
import Halogen.HTML.Properties.Indexed as HP
import Halogen.HTML.Properties.Indexed.ARIA as ARIA
import Halogen.Themes.Bootstrap3 as B

import SlamData.Effects (Slam)
import SlamData.Workspace.Card.CardType as CT
import SlamData.Workspace.Card.Component as CC
import SlamData.Workspace.Card.Model as Card
import SlamData.Workspace.Card.Next.Component.Query (QueryP, Query(..), _AddCardType)
import SlamData.Workspace.Card.Next.Component.State (State, initialState, _input)
import SlamData.Workspace.Card.Port as Port
import SlamData.Workspace.Card.InsertableCardType as ICT

type NextHTML = H.ComponentHTML QueryP
type NextDSL = H.ComponentDSL State QueryP Slam

nextCardComponent :: CC.CardComponent
nextCardComponent = CC.makeCardComponent
  { cardType: CT.NextAction
  , component: H.component {render, eval}
  , initialState: initialState
  , _State: CC._NextState
  , _Query: CC.makeQueryPrism CC._NextQuery
  }

render :: State → NextHTML
render state =
  HH.ul_ $ map nextButton CT.insertableCardTypes
  where
  cardTitle ∷ CT.CardType → String
  cardTitle cty = "Insert " ⊕ CT.cardName cty ⊕ " card"

  disabledTitle ∷ CT.CardType → String
  disabledTitle cty = CT.cardName cty ⊕ " is unavailable as next action"

  nextButton ∷ CT.CardType → NextHTML
  nextButton cty =
    HH.li_
      [ HH.button
          [ HP.title $ cardTitle cty
          , ARIA.label $ cardTitle cty
          , HE.onClick (HE.input_ (right ∘ AddCard cty))
          , HP.disabled $ not $ takesInput state.input cty
          ]
          [ CT.cardGlyph cty
          , HH.p_ [ HH.text (CT.cardName cty) ]
          ]
      ]


eval :: QueryP ~> NextDSL
eval = coproduct cardEval nextEval

cardEval :: CC.CardEvalQuery ~> NextDSL
cardEval = case _ of
  CC.EvalCard value output next →
    H.modify (_input .~ value.input) $> next
  CC.Save k →
    pure $ k Card.NextAction
  CC.Load _ next →
    pure next
  CC.SetDimensions _ next →
    pure next
  CC.ModelUpdated _ next →
    pure next
  CC.ZoomIn next →
    pure next

takesInput ∷ Maybe Port.Port -> CT.CardType -> Boolean
takesInput input =
  maybe false (ICT.takesInput $ maybe ICT.None ICT.fromPort input) ∘ ICT.fromCardType

nextEval :: Query ~> NextDSL
nextEval (AddCard _ next) = pure next
