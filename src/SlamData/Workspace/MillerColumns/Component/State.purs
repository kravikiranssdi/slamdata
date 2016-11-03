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

module SlamData.Workspace.MillerColumns.Component.State where

import SlamData.Prelude

import Data.List (List(..))

import DOM.HTML.Types (HTMLElement)

import Halogen as H

import SlamData.Monad (Slam)
import SlamData.Workspace.MillerColumns.Component.Query (Query, ChildQuery)

type State a i =
  { element ∷ Maybe HTMLElement
  , columns ∷ Array (Tuple i (List a))
  , selected ∷ List i
  , cycle ∷ Int
  }

type State' a i s f = H.ParentState (State a i) s (Query i) (ChildQuery i f) Slam i

initialState ∷ ∀ a i. State a i
initialState =
  { element: Nothing
  , columns: []
  , selected: Nil
  , cycle: 0
  }
